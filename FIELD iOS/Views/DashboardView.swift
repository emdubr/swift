import MapKit
import SwiftUI
import OSLog

// Map-first mobile counterpart to the web console. The visible map is real
// MapKit or an imported local MapLibre pack, never decorative/synthetic tiles.
// Camera position changes only in response to explicit user commands.
struct DashboardView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var sensor: SensorService
    @EnvironmentObject private var mesh: MeshService
    @EnvironmentObject private var track: TrackRecorder
    @EnvironmentObject private var checkIn: CheckInService

    @State private var homeCamera: MapCameraPosition = .automatic
    @State private var satellite = true
    @State private var showReadiness = false
    @State private var showDiagnostics = false
    @State private var offlineStyleURL: URL?
    @State private var offlineMapError: String?
    @State private var offlineCenter: CLLocationCoordinate2D?
    @State private var offlineZoom = 10.0
    @State private var offlineCameraCommand: OfflineCameraCommand?

    private var activePack: MapPack? { state.mapPacks.first(where: \.active) }
    private var activePackID: String { activePack?.id.uuidString ?? "none" }
    private var displayingLocalMap: Bool { state.settings.offlineMode && offlineStyleURL != nil }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                VStack(spacing: 0) {
                    // Keep the web command rail visible while the rest can
                    // scroll on compact iPhones. The bottom dock is in actual
                    // layout, NOT a safe-area overlay that clips off-screen.
                    commandHeader
                    statusStrip
                    safetyTicker
                    ScrollView {
                        VStack(spacing: 0) {
                            terrainWorkspace(height: max(250, min(465, viewport.size.height * 0.44)))
                            priorityAndLocation
                            routeSummary
                            utilityTray
                        }
                    }
                    .scrollIndicators(.hidden)
                    commandDock
                }
                .padding(.horizontal, 7)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(FieldTheme.background.ignoresSafeArea())
            }
            .toolbar(.hidden, for: .navigationBar)
            // Home supplies the web-console's own compact module dock.
            // Other tabs keep their existing, accessible native tab bar.
            .toolbar(.hidden, for: .tabBar)
            .navigationDestination(for: AppModule.self) { ModuleDestination(module: $0) }
            .onAppear {
                Logger(subsystem: "com.fieldos.native", category: "render")
                    .notice("FIELD_WEB_CONSOLE_DASHBOARD_VISIBLE")
            }
            .task(id: activePackID) {
                offlineStyleURL = nil
                offlineMapError = nil
                guard let pack = activePack else { return }
                do {
                    let url = try await MapPackService.shared.localStyle(for: pack)
                    let archive = try await MapPackService.shared.url(for: pack)
                    let metadata = try PMTilesStyle.descriptor(fileURL: archive)
                    offlineCenter = CLLocationCoordinate2D(
                        latitude: metadata.centerLatitude,
                        longitude: metadata.centerLongitude
                    )
                    offlineZoom = Double(max(metadata.minZoom, min(metadata.maxZoom,
                        metadata.centerZoom == 0 ? 10 : metadata.centerZoom)))
                    offlineStyleURL = url
                } catch {
                    offlineMapError = "Local map unavailable: \(error.localizedDescription)"
                }
            }
        }
    }

    private var commandHeader: some View {
        HStack(spacing: 12) {
            Button { state.selectedTab = .more } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 41, height: 44)
            }
            .accessibilityLabel("Open field modules")
            Spacer(minLength: 0)
            Text("FIELD / OS")
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .tracking(3.2)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                state.settings.offlineMode.toggle()
                state.persist()
            } label: {
                Text(state.settings.offlineMode ? "OFFLINE" : "LOCAL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .padding(.horizontal, 9)
                    .frame(height: 29)
                    .overlay(Rectangle().stroke(
                        state.settings.offlineMode ? FieldTheme.amber : FieldTheme.accent,
                        lineWidth: 1
                    ))
            }
            .accessibilityLabel(state.settings.offlineMode ? "Disable offline mode" : "Enable offline mode")
            .frame(minWidth: 70)
        }
        .foregroundStyle(FieldTheme.text)
        .padding(.horizontal, 8)
        .frame(height: 49)
        .background(FieldTheme.panel)
        .overlay(Rectangle().stroke(FieldTheme.border.opacity(0.9), lineWidth: 1))
    }

    private var statusStrip: some View {
        HStack(spacing: 0) {
            statusCell("location.north.line.fill", "GNSS", gpsValue, gpsTone)
            statusDivider
            statusCell("dot.radiowaves.left.and.right", "MESH", meshValue,
                       mesh.linkState == .connected ? FieldTheme.accent : FieldTheme.amber)
            statusDivider
            statusCell("battery.75percent", "PHONE", batteryText, FieldTheme.accent)
            statusDivider
            statusCell("square.stack.3d.up", "MAPS",
                       activePack == nil ? "NO PACK" : (state.settings.offlineMode ? "LOCAL" : "READY"),
                       activePack == nil ? FieldTheme.amber : FieldTheme.accent)
        }
        .frame(height: 63)
        .background(FieldTheme.panel)
        .overlay(Rectangle().stroke(FieldTheme.border.opacity(0.9), lineWidth: 1))
    }

    private var statusDivider: some View {
        Rectangle().fill(FieldTheme.border)
            .frame(width: 1, height: 34)
    }

    private func statusCell(_ symbol: String, _ heading: String, _ value: String, _ tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FieldTheme.accent)
                Text(heading)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(FieldTheme.dim)
            }
            HStack(spacing: 4) {
                Circle().fill(tone).frame(width: 5, height: 5)
                Text(value)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(FieldTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.73)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    private var safetyTicker: some View {
        HStack(spacing: 6) {
            Circle().fill(gpsTone).frame(width: 5, height: 5)
            Text(gpsValue == "FIX" ? "LIVE GPS FIX  //  MAP AND SENSOR DATA ARE DEVICE-SOURCED"
                 : "GPS NOT VERIFIED  //  DO NOT RELY ON POSITION UNTIL A FIX IS AVAILABLE")
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 0)
            Text("WGS84")
        }
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .tracking(0.1)
        .foregroundStyle(FieldTheme.dim)
        .padding(.horizontal, 8)
        .frame(height: 25)
    }

    private func terrainWorkspace(height: CGFloat) -> some View {
        ZStack {
            terrainCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(colors: [FieldTheme.background.opacity(0.48), .clear,
                                    .clear, FieldTheme.background.opacity(0.86)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "mountain.2.fill")
                        .foregroundStyle(FieldTheme.accent)
                    Text("TERRAIN MAP  //  FIELD GRID")
                        .foregroundStyle(FieldTheme.text)
                    Spacer(minLength: 2)
                    Text(displayingLocalMap ? "LOCAL PMTILES" :
                         state.settings.offlineMode ? "NO LOCAL MAP" : "APPLE MAPKIT")
                        .foregroundStyle(displayingLocalMap ? FieldTheme.accent : FieldTheme.amber)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 37)
                .background(FieldTheme.panel.opacity(0.95))
                .overlay(alignment: .bottom) { FieldTheme.border.frame(height: 1) }

                HStack(alignment: .top) {
                    Button {
                        if displayingLocalMap {
                            state.selectedTab = .map
                        } else if !state.settings.offlineMode {
                            satellite.toggle()
                        } else {
                            state.selectedTab = .map
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.3.layers.3d")
                            Text(displayingLocalMap ? "LOCAL" :
                                 state.settings.offlineMode ? "IMPORT MAP" :
                                 (satellite ? "SATELLITE" : "STANDARD"))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(FieldTheme.panel.opacity(0.95))
                        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                    }
                    .accessibilityLabel("Change terrain map layers")
                    Spacer(minLength: 8)
                    VStack(spacing: 1) {
                        mapTool("location.north.fill", "Center on current GPS fix",
                                disabled: location.location == nil) { centerOnUser() }
                        Rectangle().fill(FieldTheme.border).frame(height: 1)
                        mapTool("point.topleft.down.to.point.bottomright.curvepath",
                                "Fit loaded route", disabled: state.activeRoute == nil) { fitRoute() }
                        Rectangle().fill(FieldTheme.border).frame(height: 1)
                        mapTool("square.stack.3d.up", "Open full map and map layers") {
                            state.selectedTab = .map
                        }
                    }
                    .frame(width: 43)
                    .fixedSize(horizontal: true, vertical: true)
                    .background(FieldTheme.panel.opacity(0.96))
                    .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                }
                .padding(9)
                Spacer(minLength: 0)
                HStack {
                    Label(gpsValue == "FIX" ? "CURRENT FIX" : "MAP VIEW · NO VERIFIED GPS",
                          systemImage: gpsValue == "FIX" ? "location.fill" : "location.slash")
                    Spacer(minLength: 4)
                    Button { state.selectedTab = .map } label: {
                        HStack(spacing: 4) {
                            Text("EXPAND MAP")
                            Image(systemName: "arrow.up.right")
                        }
                        .foregroundStyle(FieldTheme.accent)
                    }
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(FieldTheme.text)
                .padding(.horizontal, 9)
                .frame(height: 35)
                .background(FieldTheme.panel.opacity(0.96))
            }
        }
        .frame(height: height)
        .clipped()
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
    }

    @ViewBuilder private var terrainCanvas: some View {
        if state.settings.offlineMode, let offlineStyleURL {
            OfflineMapLibreView(
                styleURL: offlineStyleURL,
                initialCenter: location.location?.coordinate
                    ?? state.activeRoute?.points.first?.coordinate
                    ?? offlineCenter
                    ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                initialZoom: offlineZoom,
                route: state.activeRoute,
                waypoints: state.waypoints,
                command: offlineCameraCommand
            )
        } else if state.settings.offlineMode {
            ZStack {
                FieldTheme.panelRaised
                VStack(spacing: 11) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.title2)
                        .foregroundStyle(FieldTheme.amber)
                    Text("OFFLINE MAP NOT READY")
                        .font(.system(.headline, design: .monospaced))
                    Text(offlineMapError ?? "Import a map pack before navigating without network access.")
                        .font(.caption.monospaced())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FieldTheme.dim)
                    Button("OPEN MAP MANAGER") { state.selectedTab = .map }
                        .font(.caption.bold().monospaced())
                        .foregroundStyle(FieldTheme.accent)
                }
                .padding(24)
            }
        } else {
            Map(position: $homeCamera) {
                UserAnnotation()
                if let route = state.activeRoute, route.points.count > 1 {
                    MapPolyline(coordinates: route.points.map(\.coordinate))
                        .stroke(FieldTheme.accent, lineWidth: 4)
                }
                ForEach(state.waypoints) { waypoint in
                    Annotation(waypoint.name, coordinate: waypoint.point.coordinate) {
                        Image(systemName: waypoint.kind == .base ? "house.circle.fill" : "mappin.circle.fill")
                            .font(.title2)
                            .foregroundStyle(waypoint.kind == .hazard ? FieldTheme.danger : FieldTheme.amber)
                    }
                }
            }
            .mapStyle(satellite ? .imagery(elevation: .realistic) :
                      .standard(elevation: .realistic, emphasis: .muted))
            .accessibilityLabel("Interactive live map. Expand for offline map management.")
        }
    }

    private func mapTool(_ symbol: String, _ label: String,
                         disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(disabled ? FieldTheme.dim : FieldTheme.accent)
                .frame(width: 43, height: 43)
        }
        .frame(width: 43, height: 43)
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func centerOnUser() {
        guard let fix = location.location, fix.horizontalAccuracy >= 0 else { return }
        offlineCameraCommand = OfflineCameraCommand(coordinate: fix.coordinate, zoom: 14)
        homeCamera = .region(MKCoordinateRegion(
            center: fix.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        ))
    }

    private func fitRoute() {
        guard let points = state.activeRoute?.points, !points.isEmpty,
              let minLat = points.map(\.latitude).min(), let maxLat = points.map(\.latitude).max(),
              let minLon = points.map(\.longitude).min(), let maxLon = points.map(\.longitude).max()
        else { return }
        let coordinate = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                                longitude: (minLon + maxLon) / 2)
        let latSpan = max(0.015, (maxLat - minLat) * 1.4)
        let lonSpan = max(0.015, (maxLon - minLon) * 1.4)
        offlineCameraCommand = OfflineCameraCommand(coordinate: coordinate,
                                                    zoom: max(3, 15 - log2(latSpan / 0.015)))
        homeCamera = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        ))
    }

    private var priorityAndLocation: some View {
        HStack(alignment: .top, spacing: 0) {
            let item = priority
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.tone)
                    .frame(width: 27, height: 27)
                    .background(item.tone.opacity(0.13))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("WHAT MATTERS NOW")
                            .foregroundStyle(FieldTheme.dim)
                        Spacer(minLength: 1)
                        Text(item.category).foregroundStyle(item.tone)
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FieldTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.detail)
                        .font(.system(size: 10))
                        .foregroundStyle(FieldTheme.dim)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(FieldTheme.border).frame(width: 1)
            VStack(alignment: .leading, spacing: 7) {
                Text("POSITION // WGS84")
                    .foregroundStyle(FieldTheme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(latitudeText)
                Text(longitudeText)
                Text("ALT " + altitudeText)
                Text(accuracyText)
                    .foregroundStyle(gpsTone)
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(FieldTheme.text)
            .padding(9)
            .frame(width: 125, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 89, alignment: .top)
        .background(FieldTheme.panel)
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
    }

    private var routeSummary: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(FieldTheme.accent)
                Text("ROUTE SUMMARY")
                    .foregroundStyle(FieldTheme.text)
                Spacer(minLength: 2)
                Text(state.activeRoute == nil ? "NO ROUTE" : "ROUTE LOADED")
                    .foregroundStyle(FieldTheme.dim)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(.horizontal, 10)
            .frame(height: 34)
            Rectangle().fill(FieldTheme.border).frame(height: 1)
            HStack(spacing: 3) {
                routeMetric("DISTANCE", distanceValue)
                routeMetric("ASCENT", ascentValue)
                routeMetric("EST. TIME", etaValue)
                Button { state.selectedTab = .route } label: {
                    HStack(spacing: 2) {
                        Text("PLAN")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(FieldTheme.accent)
                    .frame(width: 65, height: 39)
                    .overlay(Rectangle().stroke(FieldTheme.accent, lineWidth: 1))
                }
                .accessibilityLabel("Open route planner")
                .padding(.trailing, 6)
            }
            .padding(.vertical, 8)
        }
        .background(FieldTheme.panel)
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
        .padding(.top, 6)
    }

    private func routeMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(FieldTheme.dim)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(FieldTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }

    private var utilityTray: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Text("FIELD MODULES")
                    .foregroundStyle(FieldTheme.accent)
                Spacer()
                Text("DEVICE DATA ONLY // VERIFY BEFORE DEPARTURE")
                    .foregroundStyle(FieldTheme.dim)
            }
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .padding(.top, 11)
            HStack(spacing: 7) {
                NavigationLink(value: AppModule.returnFunctions) {
                    utilityLink("arrow.uturn.backward", "RETURN TRAIL")
                }
                NavigationLink(value: AppModule.emergency) {
                    utilityLink("cross.circle", "SOS TOOLS", FieldTheme.danger)
                }
            }
            DisclosureGroup(isExpanded: $showReadiness) {
                ReadinessView(embedded: true).padding(.top, 9)
            } label: {
                HStack {
                    Text("PREFLIGHT CHECKLIST")
                    Spacer()
                    Text("\(state.readiness.completedCount)/\(state.readiness.totalCount)")
                        .foregroundStyle(FieldTheme.accent)
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .padding(10)
            .background(FieldTheme.panel)
            .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
            DisclosureGroup(isExpanded: $showDiagnostics) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("GNSS: " + gpsValue, systemImage: "location")
                    Label("MESH: " + meshValue, systemImage: "dot.radiowaves.left.and.right")
                    Label("MAP PACKS: \(state.mapPacks.count)", systemImage: "square.stack.3d.up")
                    Label("TRACK: " + track.state.rawValue, systemImage: "figure.hiking")
                }
                .padding(.top, 9)
            } label: {
                Text("SENSORS / DIAGNOSTICS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .padding(10)
            .background(FieldTheme.panel)
            .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
        }
        .tint(FieldTheme.accent)
        .foregroundStyle(FieldTheme.text)
        .buttonStyle(.plain)
    }

    private func utilityLink(_ symbol: String, _ title: String,
                             _ tone: Color = FieldTheme.accent) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(tone)
            .frame(maxWidth: .infinity, minHeight: 39)
            .background(FieldTheme.panel)
            .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
    }

    private var commandDock: some View {
        HStack(spacing: 4) {
            dockButton("point.topleft.down.to.point.bottomright.curvepath", "ROUTE") {
                state.selectedTab = .route
            }
            dockButton("location.north.fill", "NAVIGATE") {
                state.selectedTab = .map
            }
            dockButton("dot.radiowaves.left.and.right", "COMMS") {
                state.selectedTab = .comms
            }
            dockButton("square.grid.2x2", "TOOLS") {
                state.selectedTab = .more
            }
        }
        .padding(.horizontal, 7)
        .padding(.top, 5)
        .padding(.bottom, 3)
        .background(FieldTheme.background.opacity(0.995))
        .overlay(alignment: .top) { FieldTheme.border.frame(height: 1) }
    }

    private func dockButton(_ symbol: String, _ title: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(FieldTheme.accent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                LinearGradient(
                    colors: [FieldTheme.panelRaised.opacity(0.72), FieldTheme.panel],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(Rectangle().stroke(FieldTheme.border.opacity(0.92), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open " + title.lowercased())
    }

    private var gpsValue: String {
        guard let fix = location.location, fix.horizontalAccuracy >= 0 else { return "SEARCHING" }
        return Date().timeIntervalSince(fix.timestamp) > 120 ? "STALE" : "FIX"
    }
    private var gpsTone: Color {
        switch gpsValue {
        case "FIX": FieldTheme.accent
        case "STALE": FieldTheme.danger
        default: FieldTheme.amber
        }
    }
    private var meshValue: String {
        switch mesh.linkState {
        case .connected: "LINKED"
        case .scanning: "SCANNING"
        case .connecting, .syncing: "SYNCING"
        default: "IDLE"
        }
    }
    private var batteryText: String {
        sensor.snapshot.batteryPercent.map { "\($0)%" } ?? "--"
    }
    private var latitudeText: String {
        guard let fix = location.location, fix.horizontalAccuracy >= 0 else { return "LAT --" }
        return String(format: "LAT %.4f", fix.coordinate.latitude)
    }
    private var longitudeText: String {
        guard let fix = location.location, fix.horizontalAccuracy >= 0 else { return "LON --" }
        return String(format: "LON %.4f", fix.coordinate.longitude)
    }
    private var altitudeText: String {
        guard let fix = location.location, fix.horizontalAccuracy >= 0 else { return "--" }
        return "\(Int(fix.altitude * 3.28084)) FT"
    }
    private var accuracyText: String {
        guard let fix = location.location, fix.horizontalAccuracy >= 0 else { return "NO FIX" }
        return gpsValue == "STALE" ? "STALE FIX" : "±\(Int(fix.horizontalAccuracy)) M"
    }
    private var distanceValue: String {
        guard let route = state.activeRoute else { return "-- MI" }
        return String(format: "%.2f MI", RouteEngine.metrics(for: route).distanceMiles)
    }
    private var ascentValue: String {
        guard let route = state.activeRoute else { return "-- FT" }
        return String(format: "%.0f FT", RouteEngine.metrics(for: route).ascentFeet)
    }
    private var etaValue: String {
        guard let route = state.activeRoute else { return "--" }
        return RouteEngine.metrics(for: route).estimatedSeconds.fieldDuration
    }

    private struct PriorityItem {
        let severity: Int
        let category: String
        let title: String
        let detail: String
        let tone: Color
        let symbol: String
    }

    private var priority: PriorityItem {
        var alerts: [PriorityItem] = []
        if let fix = location.location, fix.horizontalAccuracy >= 0 {
            if Date().timeIntervalSince(fix.timestamp) > 180 {
                alerts.append(.init(severity: 100, category: "POSITION", title: "GPS position is stale",
                                    detail: "Your last known location is old. Verify it before following route guidance.",
                                    tone: FieldTheme.danger, symbol: "location.slash"))
            }
            if let route = state.activeRoute,
               let progress = RouteEngine.progress(on: route, from: fix) {
                let feet = progress.nearest.distanceMeters * 3.28084
                if feet > 300 {
                    alerts.append(.init(severity: 95, category: "NAVIGATION", title: "Far from the route",
                                        detail: String(format: "Your last fix is approximately %.0f ft from the route.", feet),
                                        tone: FieldTheme.danger, symbol: "point.topleft.down.to.point.bottomright.curvepath"))
                } else if feet > 100 {
                    alerts.append(.init(severity: 82, category: "NAVIGATION", title: "Check your route",
                                        detail: String(format: "Your last fix is approximately %.0f ft off the route.", feet),
                                        tone: FieldTheme.amber, symbol: "point.topleft.down.to.point.bottomright.curvepath"))
                }
            }
            if let remaining = SunService.window(for: fix.coordinate).daylightRemaining(),
               remaining < 3600 {
                alerts.append(.init(severity: 76, category: "DAYLIGHT", title: "Sunset approaching",
                                    detail: "Calculated sunset in approximately \(Int(remaining / 60)) minutes. Verify conditions.",
                                    tone: FieldTheme.amber, symbol: "sunset"))
            }
        } else {
            alerts.append(.init(severity: 55, category: "LOCATION", title: "Waiting for GPS",
                                detail: "Grant location permission to enable navigation and position tracking.",
                                tone: FieldTheme.amber, symbol: "location"))
        }
        if let battery = sensor.snapshot.batteryPercent {
            if battery <= 15 {
                alerts.append(.init(severity: 92, category: "POWER", title: "Critical battery",
                                    detail: "Phone battery is \(battery)%. Preserve navigation and communication power.",
                                    tone: FieldTheme.danger, symbol: "battery.25percent"))
            } else if battery <= 25 {
                alerts.append(.init(severity: 72, category: "POWER", title: "Low battery",
                                    detail: "Phone battery is \(battery)%. Consider power-saving measures.",
                                    tone: FieldTheme.amber, symbol: "battery.25percent"))
            }
        }
        if let due = checkIn.nextDue {
            let remaining = due.timeIntervalSinceNow
            if remaining < 0 {
                alerts.append(.init(severity: 88, category: "CHECK-IN", title: "Check-in overdue",
                                    detail: "Scheduled check-in time has passed.",
                                    tone: FieldTheme.danger, symbol: "bell.badge"))
            } else if remaining < 600 {
                alerts.append(.init(severity: 68, category: "CHECK-IN", title: "Check-in soon",
                                    detail: "Check-in due in about \(max(1, Int(remaining / 60))) minutes.",
                                    tone: FieldTheme.amber, symbol: "bell"))
            }
        }
        if !state.readiness.routeChecked {
            alerts.append(.init(severity: 40, category: "PREFLIGHT", title: "Review your planned route",
                                detail: "Load a route and confirm it before departure.",
                                tone: FieldTheme.amber, symbol: "list.bullet.clipboard"))
        }
        if !state.readiness.offlineMapChecked {
            alerts.append(.init(severity: 35, category: "PREFLIGHT", title: "Verify offline coverage",
                                detail: "Import and test an offline basemap for your trip.",
                                tone: FieldTheme.amber, symbol: "square.stack.3d.up"))
        }
        return alerts.max(by: { $0.severity < $1.severity }) ??
            .init(severity: 0, category: "PREFLIGHT", title: "Checklist complete",
                  detail: "Continue monitoring the actual weather, route and equipment.",
                  tone: FieldTheme.accent, symbol: "checkmark.shield")
    }
}
