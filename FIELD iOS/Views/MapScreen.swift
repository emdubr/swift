import MapKit
import SwiftUI

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
                    if let network = state.trailNetwork, network.edges.count <= 1800 {
                        ForEach(network.edges) { edge in
                            if let a = network.nodes.first(where: { $0.id == edge.from }), let b = network.nodes.first(where: { $0.id == edge.to }) {
                                MapPolyline(coordinates: [a.point.coordinate, b.point.coordinate])
                                    .stroke(FieldTheme.dim.opacity(0.55), lineWidth: 2)
                            }
                        }
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

                VStack(spacing: 8) {
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
                    mapHUD
                }.padding()
            }
            .navigationTitle("Terrain Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if offlineStyleURL != nil {
                        Button { showingOffline.toggle() } label: {
                            Label(showingOffline ? "Local map" : "Use offline map", systemImage: "square.stack.3d.up")
                        }
                    }
                    if !usingOffline {
                        Button { mapMode = mapMode == 0 ? 1 : 0 } label: { Image(systemName: mapMode == 0 ? "map" : "globe.americas.fill") }
                    }
                    Button { showSearch.toggle() } label: { Image(systemName: "magnifyingglass") }
                    Button { centerOnUser() } label: { Image(systemName: "location.fill") }
                    Button { fitRoute() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
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

    private var mapHUD: some View {
        HStack(spacing: 12) {
            Label(gpsText, systemImage: "location.fill")
            Spacer()
            if let route = state.activeRoute {
                let m = RouteEngine.metrics(for: route)
                Text(String(format: "%.1f MI", m.distanceMiles))
            }
            Text(altitudeText)
        }
        .font(.caption.bold().monospaced())
        .foregroundStyle(FieldTheme.text)
        .padding(11)
        .background(.ultraThinMaterial, in: Capsule())
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
