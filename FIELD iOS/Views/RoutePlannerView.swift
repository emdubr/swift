import MapKit
import SwiftUI
import UniformTypeIdentifiers

struct RoutePlannerView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @State private var draft = FieldRoute()
    // Consistent example hiking-region viewport until a GPS fix, saved route
    // or the user's own map data selects an actual location.
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 44.17, longitude: -73.91),
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )
    )
    @State private var importing = false
    @State private var importError: String?
    @State private var undoStack: [FieldRoute] = []
    @State private var redoStack: [FieldRoute] = []
    @State private var exporting = false
    @State private var didInitializeDraft = false
    @State private var editorExpanded = true
    @State private var elevationExpanded = false
    @State private var riskExpanded = false

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                VStack(spacing: 0) {
                    SecondaryConsoleTitle(
                        title: "ROUTE WORKSTATION",
                        status: "\(draft.points.count) POINTS / DRAFT",
                        symbol: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                    routeMap
                        // Keep the editor visible even on short iPhones and in landscape.
                        .frame(height: max(205, min(345, viewport.size.height * 0.40)))
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    quickMetrics
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                    ScrollView {
                        VStack(spacing: 9) {
                            DisclosureGroup(isExpanded: $editorExpanded) {
                                routeEditor
                                    .padding(.top, 8)
                            } label: {
                                consoleDisclosure("ROUTE EDITOR", detail: "\(draft.points.count) WAYPOINTS")
                            }
                            .padding(9)
                            .background(FieldTheme.panel)
                            .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))

                            DisclosureGroup(isExpanded: $elevationExpanded) {
                                metricsPanel.padding(.top, 8)
                            } label: {
                                consoleDisclosure("ELEVATION + TERRAIN", detail: "PROFILE")
                            }
                            .padding(9)
                            .background(FieldTheme.panel)
                            .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))

                            DisclosureGroup(isExpanded: $riskExpanded) {
                                terrainRiskPanel.padding(.top, 8)
                            } label: {
                                consoleDisclosure("TERRAIN RISKS", detail: "REVIEW")
                            }
                            .padding(9)
                            .background(FieldTheme.panel)
                            .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                            actionPanel
                        }
                        .padding(.horizontal, 8)
                        // Editor and import controls must scroll fully above the
                        // always-visible save bar, even on small iPhone screens.
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                }
                .background(FieldTheme.background.ignoresSafeArea())
                .safeAreaInset(edge: .bottom, spacing: 0) { editorDock }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                // A retained tab must not discard an unsaved mobile draft
                // every time someone switches over to the map and back.
                guard !didInitializeDraft else { return }
                didInitializeDraft = true
                if let active = state.activeRoute {
                    draft = active
                    undoStack = []
                    redoStack = []
                }
            }
            .fileExporter(isPresented: $exporting, document: GPXDocument(xml: GPXService.export(route: draft)),
                          contentType: UTType(filenameExtension: "gpx") ?? .xml,
                          defaultFilename: draft.name.replacingOccurrences(of: "/", with: "-") + ".gpx") { result in
                if case let .failure(error) = result { importError = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml, .json], allowsMultipleSelection: false) { result in
                importFile(result)
            }
            .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) { importError = nil }
            } message: { Text(importError ?? "Unknown error") }
        }
    }

    private func consoleDisclosure(_ title: String, detail: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(FieldTheme.accent)
            Text(title)
                .foregroundStyle(FieldTheme.text)
            Spacer(minLength: 3)
            Text(detail)
                .foregroundStyle(FieldTheme.dim)
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var routeMap: some View {
        MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()
                if draft.points.count >= 2 {
                    MapPolyline(coordinates: draft.points.map(\.coordinate)).stroke(FieldTheme.accent, lineWidth: 5)
                }
                ForEach(Array(draft.points.enumerated()), id: \.element.id) { index, point in
                    Annotation("\(index + 1)", coordinate: point.coordinate) {
                        Text("\(index + 1)").font(.caption2.bold()).foregroundStyle(.black)
                            .frame(width: 24, height: 24).background(FieldTheme.accent, in: Circle())
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls { MapCompass(); MapScaleView() }
            .onTapGesture { screenPoint in
                if let coordinate = proxy.convert(screenPoint, from: .local) {
                    addPoint(RoutePoint(latitude: coordinate.latitude, longitude: coordinate.longitude))
                }
            }
        }
        .clipped()
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
        .overlay(alignment: .topLeading) {
            Text("TAP MAP TO ADD WAYPOINTS  //  DRAG TO PAN")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(FieldTheme.text)
                .padding(8)
                .background(FieldTheme.panel.opacity(0.94))
                .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                .padding(8)
                .allowsHitTesting(false)
        }
    }

    // One low-height telemetry strip rather than three tall cards. On compact
    // iPhones the route editor now starts immediately below the live map.
    private var quickMetrics: some View {
        let metrics = RouteEngine.metrics(for: draft)
        return HStack(spacing: 0) {
            compactRouteMetric("DISTANCE", String(format: "%.2f MI", metrics.distanceMiles))
            Rectangle().fill(FieldTheme.border).frame(width: 1, height: 34)
            compactRouteMetric("ASCENT", String(format: "%.0f FT", metrics.ascentFeet))
            Rectangle().fill(FieldTheme.border).frame(width: 1, height: 34)
            compactRouteMetric("ETA", metrics.estimatedSeconds.fieldDuration)
        }
        .frame(height: 54)
        .background(FieldTheme.panel)
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func compactRouteMetric(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(FieldTheme.dim)
            Text(value).font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(FieldTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
    }

    // Primary controls remain reachable while the user pans or taps the map.
    // safeAreaInset places them above (not on top of) the system tab bar.
    private var editorDock: some View {
        HStack(spacing: 9) {
            Button { undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 44, height: 44)
                    .background(FieldTheme.panelRaised, in: Rectangle())
            }
            .disabled(undoStack.isEmpty)
            .accessibilityLabel("Undo route edit")

            Button { redo() } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 44, height: 44)
                    .background(FieldTheme.panelRaised, in: Rectangle())
            }
            .disabled(redoStack.isEmpty)
            .accessibilityLabel("Redo route edit")

            Button {
                state.saveRoute(draft)
            } label: {
                Label("SAVE ROUTE", systemImage: "square.and.arrow.down")
                    .font(.caption.bold().monospaced())
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(FieldTheme.background)
                    .background(FieldTheme.accent, in: Rectangle())
            }
            .accessibilityHint("Save the current draft as the active route")
        }
        .buttonStyle(.plain)
        .tint(FieldTheme.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(FieldTheme.background)
        .overlay(alignment: .top) {
            Rectangle().fill(FieldTheme.border).frame(height: 1)
        }
    }

    private var routeEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldHeader(title: "Route definition", subtitle: "\(draft.points.count) POINTS")
            TextField("Route name", text: $draft.name).textFieldStyle(.plain).padding(9).background(FieldTheme.panelRaised)
            Picker("Terrain", selection: $draft.terrain) {
                ForEach(TerrainType.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu)
            TextField("Notes", text: $draft.notes, axis: .vertical).textFieldStyle(.plain).padding(9).background(FieldTheme.panelRaised)
            Button("ADD CURRENT GPS POINT") { addCurrentLocation() }
                .disabled(location.location == nil || draft.points.count >= GPXService.maxPoints)
                .buttonStyle(SecondaryConsoleButton())
            HStack {
                Button("REVERSE") { mutate { $0.points.reverse() } }.disabled(draft.points.count < 2)
                Button("CLEAR", role: .destructive) { mutate { $0.points.removeAll() } }.disabled(draft.points.isEmpty)
            }.buttonStyle(SecondaryConsoleButton())
            if state.trailNetwork != nil {
                HStack {
                    Button("SNAP POINTS") { snapDraftToTrails() }
                    Button("ROUTE FIRST → LAST") { routeFirstToLast() }.disabled(draft.points.count < 2)
                }.buttonStyle(SecondaryConsoleButton())
                Text("OFFLINE TRAIL GRAPH ACTIVE // routing does not require network access")
                    .font(.caption2.bold().monospaced()).foregroundStyle(FieldTheme.accent)
            }
        }.fieldPanel()
    }

    private var metricsPanel: some View {
        let m = RouteEngine.metrics(for: draft)
        return VStack(alignment: .leading, spacing: 9) {
            FieldHeader(title: "Elevation & terrain", subtitle: m.difficulty.rawValue)
            HStack(spacing: 8) {
                MetricTile(label: "Max grade", value: String(format: "%.0f%%", m.maxGradePercent))
                MetricTile(label: "Terrain", value: draft.terrain.rawValue)
            }
            ElevationProfileView(route: draft)
            Text(state.trailNetwork == nil ? "Native geometry, distance, bearing, elevation gain, grade, ETA, difficulty and GPX are active. Import a Trail GeoJSON network under Offline Maps to enable local trail snapping/routing." : "Native geometry plus offline trail-network snapping and A* routing are active on-device.")
                .font(.caption).foregroundStyle(FieldTheme.dim)
        }.fieldPanel()
    }


    private var terrainRiskPanel: some View {
        let report = RouteEngine.terrainRisk(for: draft, savedWaypoints: state.waypoints)
        return VStack(alignment: .leading, spacing: 9) {
            FieldHeader(title: "Terrain risk", subtitle: "CONFIDENCE \(report.confidence)%")
            ForEach(report.flags) { flag in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(flag.severity.label).font(.caption2.bold().monospaced()).foregroundStyle(flag.severity >= .warning ? FieldTheme.amber : FieldTheme.dim)
                        Text(flag.title).font(.caption.bold().monospaced())
                    }
                    Text(flag.detail).font(.caption).foregroundStyle(FieldTheme.dim)
                    Text(flag.evidence).font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim.opacity(0.8))
                }
                .padding(.vertical, 3)
            }
            Text("Automated screening only. FIELD/OS cannot verify current trail, water, cliff, avalanche, weather, or surface conditions from route geometry alone.")
                .font(.caption2).foregroundStyle(FieldTheme.amber)
        }.fieldPanel()
    }

    private var actionPanel: some View {
        VStack(spacing: 10) {
            Button("IMPORT GPX") { importing = true }
                .buttonStyle(SecondaryConsoleButton())
            if draft.points.count >= 2 {
                Button("EXPORT .GPX FILE") { exporting = true }
                    .buttonStyle(SecondaryConsoleButton())
            }
        }.fieldPanel()
    }

    private func addCurrentLocation() {
        guard let current = location.location else { return }
        addPoint(RoutePoint(location: current))
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get(); guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > GPXService.maxBytes {
                throw GPXImportError.oversized
            }
            let data = try Data(contentsOf: url)
            guard data.count <= GPXService.maxBytes else { throw GPXImportError.oversized }
            let imported: FieldRoute
            if url.pathExtension.lowercased() == "json" {
                let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
                imported = try decoder.decode(FieldRoute.self, from: data)
                guard imported.points.count <= GPXService.maxPoints,
                      imported.points.allSatisfy({ $0.latitude.isFinite && $0.longitude.isFinite &&
                          abs($0.latitude) <= 90 && abs($0.longitude) <= 180 && ($0.elevation?.isFinite ?? true) }) else {
                    throw NSError(domain: "FIELD.Route", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Imported route has too many points or invalid coordinates."])
                }
            } else {
                imported = try GPXService().parse(data: data, name: url.deletingPathExtension().lastPathComponent)
            }
            rememberEdit()
            draft = imported
        } catch { importError = error.localizedDescription }
    }

    private func snapDraftToTrails() {
        guard let network = state.trailNetwork else { return }
        let snapped = draft.points.map { TrailNetworkService.snap($0, network: network) ?? $0 }
        if snapped != draft.points { mutate { $0.points = snapped } }
    }

    private func routeFirstToLast() {
        guard let network = state.trailNetwork, let first = draft.points.first, let last = draft.points.last else { return }
        do {
            var routed = try TrailNetworkService.route(from: first, to: last, network: network)
            routed.id = draft.id; routed.name = draft.name; routed.notes = draft.notes; routed.terrain = draft.terrain
            rememberEdit()
            draft = routed
            draft.updatedAt = .now
        } catch { importError = error.localizedDescription }
    }

    private func addPoint(_ point: RoutePoint) {
        guard draft.points.count < GPXService.maxPoints else {
            importError = "Route editor supports at most 20,000 points."
            return
        }
        mutate { $0.points.append(point) }
    }

    private func rememberEdit() {
        undoStack.append(draft)
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func mutate(_ change: (inout FieldRoute) -> Void) {
        rememberEdit()
        change(&draft)
        draft.updatedAt = .now
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(draft)
        draft = previous
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(draft)
        draft = next
    }
}

private struct GPXDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "gpx") ?? .xml, .xml] }
    var xml: String

    init(xml: String) { self.xml = xml }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let xml = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        self.xml = xml
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(xml.utf8))
    }
}
