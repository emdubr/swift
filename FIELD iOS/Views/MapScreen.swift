import MapKit
import SwiftUI

// Pre-resolve edges once per map render instead of scanning the whole node
// array twice per segment on every camera gesture (previously O(E * V)).
private struct VisibleTrailSegment: Identifiable {
    var id: UUID
    var start: CLLocationCoordinate2D
    var end: CLLocationCoordinate2D
}

struct MapScreen: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var locationService: LocationService
    @State private var position: MapCameraPosition = .automatic
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var mapMode = 0
    @State private var showingOffline = true
    @State private var offlineStyleURL: URL?
    @State private var styleGeneration = UUID()
    @State private var offlinePackCenter: CLLocationCoordinate2D?
    @State private var offlineInitialZoom: Double = 12
    @State private var offlineMapError: String?
    @State private var offlineCameraCommand: OfflineCameraCommand?
    private var activePack: MapPack? { state.mapPacks.first(where: \.active) }
    private var usingOffline: Bool { showingOffline && offlineStyleURL != nil }
    private var activeStyleID: String {
        guard let activePack else { return "none" }
        return activePack.id.uuidString + "/" + (activePack.sourceLayers ?? []).joined(separator: ",")
    }

    private var visibleTrailSegments: [VisibleTrailSegment] {
        guard let network = state.trailNetwork,
              network.edges.count <= 1800 else { return [] }
        let nodes = Dictionary(network.nodes.map { ($0.id, $0.point.coordinate) },
                               uniquingKeysWith: { first, _ in first })
        return network.edges.compactMap { edge in
            guard let start = nodes[edge.from], let end = nodes[edge.to] else { return nil }
            return VisibleTrailSegment(id: edge.id, start: start, end: end)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if usingOffline, let offlineStyleURL {
                    OfflineMapLibreView(styleURL: offlineStyleURL,
                                        initialCenter: locationService.location?.coordinate
                                            ?? state.activeRoute?.points.first?.coordinate
                                            ?? offlinePackCenter
                                            ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                        initialZoom: offlineInitialZoom,
                                        route: state.activeRoute,
                                        waypoints: state.waypoints, command: offlineCameraCommand)
                        .id(styleGeneration)
                } else {
                Map(position: $position) {
                    UserAnnotation()
                    ForEach(visibleTrailSegments) { segment in
                        MapPolyline(coordinates: [segment.start, segment.end])
                            .stroke(FieldTheme.dim.opacity(0.55), lineWidth: 2)
                    }
                    if let route = state.activeRoute, route.points.count >= 2 {
                        MapPolyline(coordinates: route.points.map(\.coordinate))
                            .stroke(FieldTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    ForEach(state.waypoints) { waypoint in
                        Annotation(waypoint.name, coordinate: waypoint.point.coordinate) {
                            Image(systemName: waypoint.kind == .base ? "house.circle.fill" : "mappin.circle.fill")
                                .font(.title2).foregroundStyle(waypoint.kind == .hazard ? FieldTheme.danger : FieldTheme.amber)
                        }
                    }
                }
                .mapStyle(mapMode == 1 ? .imagery(elevation: .realistic) : .standard(elevation: .realistic, emphasis: .muted))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapUserLocationButton()
                    MapPitchToggle()
                }
                }

                VStack {
                    mapSourceLabel
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .allowsHitTesting(false)

                VStack(spacing: 9) {
                    if showSearch { searchResults }
                    if usingOffline {
                        Text("LOCAL PMTILES // NO NETWORK TILES")
                            .font(.caption2.bold().monospaced()).padding(8)
                            .background(.regularMaterial, in: Capsule())
                    } else if state.settings.offlineMode {
                        Text("NO OFFLINE BASEMAP DISPLAYED — DO NOT RELY ON MAPKIT WITHOUT NETWORK")
                            .font(.caption2.bold()).foregroundStyle(FieldTheme.amber).padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    if let offlineMapError { Text(offlineMapError).font(.caption2).foregroundStyle(FieldTheme.danger) }
                    mapToolDock
                    mapHUD
                }.padding()
            }
            .navigationTitle("TERRAIN MAP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSearch.toggle() } label: {
                        Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                            .frame(width: 44, height: 42)
                    }
                    .accessibilityLabel(showSearch ? "Close map search" : "Search offline places and waypoints")
                }
            }
            .searchable(text: $searchText, isPresented: $showSearch, prompt: "Offline places / waypoints")
            .task(id: activeStyleID) {
                offlineStyleURL = nil
                offlineMapError = nil
                guard let pack = activePack else { return }
                do {
                    let url = try await MapPackService.shared.localStyle(for: pack)
                    let archive = try await MapPackService.shared.url(for: pack)
                    let descriptor = try PMTilesStyle.descriptor(fileURL: archive)
                    offlinePackCenter = CLLocationCoordinate2D(latitude: descriptor.centerLatitude,
                                                               longitude: descriptor.centerLongitude)
                    offlineInitialZoom = Double(max(descriptor.minZoom,
                                                    min(descriptor.maxZoom, descriptor.centerZoom == 0
                                                        ? min(descriptor.maxZoom, 12) : descriptor.centerZoom)))
                    offlineStyleURL = url
                    styleGeneration = UUID()
                }
                catch { offlineMapError = "Offline map unavailable: \(error.localizedDescription)" }
            }
        }
    }

    private var mapSourceLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(usingOffline ? FieldTheme.accent : FieldTheme.amber)
                .frame(width: 6, height: 6)
            Text(usingOffline ? "LOCAL PMTILES" : "APPLE MAPKIT")
                .font(.caption2.bold().monospaced())
                .tracking(0.8)
                .foregroundStyle(FieldTheme.text)
            Spacer(minLength: 5)
            Text(state.activeRoute == nil ? "NO ROUTE" : "ROUTE LOADED")
                .font(.caption2.monospaced())
                .foregroundStyle(FieldTheme.dim)
        }
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(FieldTheme.panel.opacity(0.95), in: Capsule())
        .overlay(Capsule().stroke(FieldTheme.border.opacity(0.7)))
    }

    // Floating native controls stay above the tab bar, without blocking
    // map gestures. GPS never auto-centers the camera after the user pans.
    private var mapToolDock: some View {
        HStack(spacing: 10) {
            mapTool(symbol: "location.north.line.fill", name: "Center on GPS",
                    disabled: locationService.location == nil) { centerOnUser() }
            mapTool(symbol: "point.topleft.down.to.point.bottomright.curvepath",
                    name: "Fit active route", disabled: state.activeRoute == nil) { fitRoute() }
            mapTool(symbol: offlineStyleURL == nil ? "square.3.layers.3d" : "square.stack.3d.up",
                    name: offlineStyleURL != nil
                        ? (showingOffline ? "Use online map" : "Use offline map")
                        : (mapMode == 0 ? "Use satellite imagery" : "Use standard map")) {
                if offlineStyleURL != nil {
                    showingOffline.toggle()
                } else {
                    mapMode = mapMode == 0 ? 1 : 0
                }
            }
        }
        .padding(7)
        .background(FieldTheme.panel.opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(FieldTheme.border.opacity(0.82), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func mapTool(symbol: String, name: String, disabled: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(disabled ? FieldTheme.dim : FieldTheme.accent)
                .frame(width: 46, height: 46)
                .background(FieldTheme.panelRaised.opacity(0.85),
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(disabled)
        .accessibilityLabel(name)
    }

    private var mapHUD: some View {
        HStack(spacing: 9) {
            Image(systemName: locationService.location == nil ? "location.slash" : "location.fill")
                .foregroundStyle(locationService.location == nil ? FieldTheme.amber : FieldTheme.accent)
            Text(gpsText)
                .foregroundStyle(FieldTheme.text)
            Spacer(minLength: 4)
            if let route = state.activeRoute {
                let metrics = RouteEngine.metrics(for: route)
                Text(String(format: "%.1f MI", metrics.distanceMiles))
                    .foregroundStyle(FieldTheme.accent)
            }
            Text(altitudeText)
                .foregroundStyle(FieldTheme.dim)
        }
        .font(.caption.bold().monospaced())
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(FieldTheme.panel.opacity(0.97), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(FieldTheme.border.opacity(0.82), lineWidth: 1)
        }
    }

    private var searchResults: some View {
        let results = FieldSearchService.search(searchText, waypoints: state.waypoints, pois: state.offlinePOIs)
        return VStack(spacing: 0) {
            if results.isEmpty {
                Text(searchText.isEmpty ? "Search local waypoints and imported POIs." : "No local matches.")
                    .font(.caption).foregroundStyle(.secondary).padding()
            } else {
                ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                    Button {
                        offlineCameraCommand = OfflineCameraCommand(coordinate: item.point.coordinate, zoom: 14)
                        position = .region(MKCoordinateRegion(center: item.point.coordinate,
                                                              span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                        showSearch = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading) { Text(item.name); Text(item.subtitle).font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Image(systemName: "scope")
                        }.padding(10)
                    }.buttonStyle(.plain)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxHeight: 230)
    }

    private func centerOnUser() {
        guard let c = locationService.location?.coordinate else { return }
        offlineCameraCommand = OfflineCameraCommand(coordinate: c, zoom: 14)
        position = .region(MKCoordinateRegion(center: c, span: .init(latitudeDelta: 0.015, longitudeDelta: 0.015)))
    }

    private func fitRoute() {
        guard let points = state.activeRoute?.points, !points.isEmpty else { centerOnUser(); return }
        let lats = points.map(\.latitude), lons = points.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat)/2, longitude: (minLon + maxLon)/2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.01, (maxLat - minLat) * 1.35), longitudeDelta: max(0.01, (maxLon - minLon) * 1.35))
        offlineCameraCommand = OfflineCameraCommand(coordinate: center, zoom: max(4, 15 - log2(max(0.01, span.latitudeDelta) / 0.01)))
        position = .region(MKCoordinateRegion(center: center, span: span))
    }

    private var gpsText: String { locationService.location == nil ? "GPS SEARCH" : "GPS LOCK" }
    private var altitudeText: String {
        guard let altitude = locationService.location?.altitude else { return "ALT --" }
        return "ALT \(Int(altitude * 3.28084))FT"
    }
}
