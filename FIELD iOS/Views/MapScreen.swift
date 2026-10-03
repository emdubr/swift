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
    // This is an example hiking-region viewport until the user selects GPS,
    // a route or an imported pack; never present it as live device position.
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 44.17, longitude: -73.91),
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )
    )
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
                            .stroke(FieldTheme.accent.opacity(0.8), lineWidth: 2.4)
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
                .mapStyle(mapMode == 1 ? .imagery(elevation: .realistic) : .standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    // GPS and layer switching are in our compact floating dock.
                }
                }

                VStack(spacing: 0) {
                    SecondaryConsoleTitle(
                        title: "TERRAIN WORKSPACE",
                        status: usingOffline ? "LOCAL PMTILES" : "LIVE MAP",
                        symbol: "map"
                    )
                    HStack(spacing: 7) {
                        mapSourceLabel
                        Spacer(minLength: 4)
                        Button {
                            showSearch.toggle()
                        } label: {
                            Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(FieldTheme.accent)
                                .frame(width: 42, height: 38)
                                .background(FieldTheme.panel.opacity(0.97))
                                .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                        }
                        .accessibilityLabel(showSearch ? "Close map search" : "Search offline places and waypoints")
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 7)
                    if showSearch {
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(FieldTheme.accent)
                                TextField("SEARCH LOCAL PLACES / WAYPOINTS", text: $searchText)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(FieldTheme.text)
                                    .tint(FieldTheme.accent)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            .padding(9)
                            searchResults
                        }
                        .background(FieldTheme.panel.opacity(0.985))
                        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                        .padding(.horizontal, 8)
                        .padding(.top, 5)
                    }
                    Spacer(minLength: 0)
                }

                VStack(spacing: 9) {
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
            .toolbar(.hidden, for: .navigationBar)
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
            Text(usingOffline ? "LOCAL HIKING PACK" : (mapMode == 0 ? "HIKING RELIEF" : "SATELLITE"))
                .font(.caption2.bold().monospaced())
                .tracking(0.8)
                .foregroundStyle(FieldTheme.text)
            if state.activeRoute != nil {
                Text("• ROUTE")
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(FieldTheme.accent)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(FieldTheme.panel.opacity(0.96))
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Floating native controls stay above the tab bar, without blocking
    // map gestures. GPS never auto-centers the camera after the user pans.
    private var mapToolDock: some View {
        HStack(spacing: 10) {
            mapTool(symbol: "location.north.line.fill", name: "Center on GPS",
                    disabled: locationService.location == nil) { centerOnUser() }
            if state.activeRoute != nil {
                mapTool(symbol: "point.topleft.down.to.point.bottomright.curvepath",
                        name: "Fit active route") { fitRoute() }
            }
            mapTool(symbol: offlineStyleURL == nil ? "square.3.layers.3d" : "square.stack.3d.up",
                    name: offlineStyleURL != nil
                        ? (showingOffline ? "Use online map" : "Use offline map")
                        : (mapMode == 0 ? "Use satellite imagery" : "Use hiking relief map")) {
                if offlineStyleURL != nil {
                    showingOffline.toggle()
                } else {
                    mapMode = mapMode == 0 ? 1 : 0
                }
            }
        }
        .padding(7)
        .background(FieldTheme.panel.opacity(0.97))
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func mapTool(symbol: String, name: String, disabled: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(disabled ? FieldTheme.dim : FieldTheme.accent)
                .frame(width: 42, height: 42)
                .background(FieldTheme.panelRaised.opacity(0.9))
                .overlay(Rectangle().stroke(FieldTheme.border.opacity(0.75), lineWidth: 1))
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
        .frame(maxWidth: .infinity, minHeight: 39)
        .background(FieldTheme.panel.opacity(0.97))
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
    }

    private var searchResults: some View {
        let results = FieldSearchService.search(searchText, waypoints: state.waypoints, pois: state.offlinePOIs)
        return VStack(spacing: 0) {
            if results.isEmpty {
                Text(searchText.isEmpty ? "Search local waypoints and imported POIs." : "No local matches.")
                    .font(.caption.monospaced()).foregroundStyle(FieldTheme.dim).padding()
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
        .background(FieldTheme.panel)
        .frame(maxHeight: 205)
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
