import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var activeRoute: FieldRoute?
    @Published var savedRoutes: [FieldRoute] = []
    @Published var waypoints: [Waypoint] = []
    @Published var tripPlan = TripPlan()
    @Published var mission = MissionPlan()
    @Published var messages: [FieldMessage] = []
    @Published var fieldLog: [FieldLogEntry] = []
    @Published var offlinePOIs: [OfflinePOI] = []
    @Published var readiness = ReadinessState()
    @Published var settings = FieldSettings()
    @Published var scratchpad = ""
    @Published var weather = WeatherSnapshot()
    @Published var mapPacks: [MapPack] = []
    @Published var trailNetwork: TrailNetwork?
    @Published var lastSavedAt: Date?
    @Published var lastSaveError: String?
    @Published var lastRecoveryStatus = "Not needed"
    private var saveGeneration = 0

    private let store = OfflineStore.shared

    func load() async {
        var loaded: AppSnapshot? = try? await store.load(AppSnapshot.self, named: "field-state.json")
        if loaded == nil, let recovery: AppSnapshot = try? await store.load(AppSnapshot.self, named: "field-recovery.json") {
            loaded = recovery
            lastRecoveryStatus = "Restored data from recovery snapshot"
        }
        if let snapshot = loaded {
            activeRoute = snapshot.activeRoute
            savedRoutes = snapshot.savedRoutes
            waypoints = snapshot.waypoints
            tripPlan = snapshot.tripPlan
            mission = snapshot.mission
            messages = snapshot.messages.map { message in
                var m = message
                // An interrupted BLE write is never safely assumed transmitted after a restart.
                if m.status == .sending { m.status = .queued; m.packetID = nil }
                return m
            }
            fieldLog = snapshot.log
            offlinePOIs = snapshot.pois
            readiness = snapshot.readiness
            settings = snapshot.settings
            scratchpad = snapshot.scratchpad
            weather = snapshot.weather
            mapPacks = snapshot.mapPacks
            trailNetwork = snapshot.trailNetwork
            if lastRecoveryStatus == "Restored data from recovery snapshot" { persist() }
        }
    }

    func snapshot() -> AppSnapshot {
        AppSnapshot(activeRoute: activeRoute,
                    savedRoutes: savedRoutes,
                    waypoints: waypoints,
                    tripPlan: tripPlan,
                    mission: mission,
                    messages: messages,
                    log: fieldLog,
                    pois: offlinePOIs,
                    readiness: readiness,
                    settings: settings,
                    scratchpad: scratchpad,
                    weather: weather.source.hasPrefix("Apple Weather") ? WeatherSnapshot() : weather,
                    mapPacks: mapPacks,
                    trailNetwork: trailNetwork)
    }

    func persist() {
        let snapshot = snapshot()
        saveGeneration += 1
        let generation = saveGeneration
        Task { @MainActor in
            guard generation == saveGeneration else { return }
            do {
                try await store.save(snapshot, named: "field-state.json")
                if snapshot.settings.autoRecoverySnapshots {
                    try await store.save(snapshot, named: "field-recovery.json")
                }
                if generation == saveGeneration { lastSavedAt = .now; lastSaveError = nil }
            } catch {
                lastSaveError = "Could not save local data: \(error.localizedDescription)"
            }
        }
    }

    func addWaypoint(_ waypoint: Waypoint) {
        waypoints.append(waypoint)
        fieldLog.append(.init(category: "WAYPOINT", text: "Added \(waypoint.name)", point: waypoint.point))
        persist()
    }

    func saveRoute(_ route: FieldRoute) {
        activeRoute = route
        if let index = savedRoutes.firstIndex(where: { $0.id == route.id }) {
            savedRoutes[index] = route
        } else {
            savedRoutes.append(route)
        }
        readiness.routeChecked = route.points.count >= 2
        fieldLog.append(.init(category: "ROUTE", text: "Saved \(route.name)"))
        persist()
    }

    func queueMessage(_ text: String, channel: String = "PRIMARY", destination: UInt32? = nil) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard Data(clean.utf8).count <= 200 else {
            lastSaveError = "Meshtastic text limit: 200 UTF-8 bytes. Split this message."
            return
        }
        messages.append(FieldMessage(channel: channel, text: clean, destination: destination))
        fieldLog.append(.init(category: "COMMS", text: "Queued message on \(channel)"))
        persist()
    }

    func sendNextQueued(using mesh: MeshService) {
        guard let i = messages.firstIndex(where: { $0.outgoing && ($0.status == .queued || $0.status == .failed) && Data($0.text.utf8).count <= 200 }) else { return }
        let packetID = UInt32.random(in: 1...UInt32.max)
        if mesh.sendText(messages[i].text, packetID: packetID, destination: messages[i].destination) {
            messages[i].packetID = packetID
            messages[i].status = .sending
            messages[i].transport = "MESHTASTIC BLE"
            messages[i].lastError = nil
            persist()
        }
    }

    func applyReceipt(_ receipt: MeshService.RadioReceipt) {
        guard let i = messages.firstIndex(where: { $0.outgoing && $0.packetID == receipt.packetID }) else { return }
        switch receipt.kind {
        case .accepted: messages[i].status = .radioAccepted
        case .routingAcknowledged: messages[i].status = .routingAcknowledged
        case .failed(let error): messages[i].status = .failed; messages[i].lastError = error
        }
        persist()
    }

    func receiveMeshEvent(_ event: MeshtasticCodec.Event) {
        guard case .text(let sender, let id, let channel, let value) = event else { return }
        let identity = String(format: "!%08X", sender)
        guard !messages.contains(where: { !$0.outgoing && $0.sender == identity && $0.packetID == id && id != 0 }) else { return }
        messages.append(FieldMessage(channel: "CH \(channel)", sender: identity, text: value,
                                     outgoing: false, status: .received, transport: "MESHTASTIC BLE", packetID: id))
        if messages.count > 500 { messages.removeFirst(messages.count-500) }
        persist()
    }

    func log(_ category: String, _ text: String, point: RoutePoint? = nil) {
        fieldLog.append(.init(category: category, text: text, point: point))
        if fieldLog.count > 500 { fieldLog.removeFirst(fieldLog.count - 500) }
        persist()
    }

    func clearLocalData() async {
        let oldPacks = mapPacks
        saveGeneration += 1 // Invalidates pending asynchronous saves.
        activeRoute = nil
        savedRoutes = []
        waypoints = []
        messages = []
        fieldLog = []
        offlinePOIs = []
        mapPacks = []
        trailNetwork = nil
        readiness = ReadinessState()
        scratchpad = ""
        tripPlan = TripPlan(); mission = MissionPlan(); settings = FieldSettings(); weather = WeatherSnapshot()
        for pack in oldPacks { try? await MapPackService.shared.remove(pack) }
        try? await store.delete(named: "field-state.json")
        try? await store.delete(named: "field-recovery.json")
        lastSavedAt = nil; lastSaveError = nil; lastRecoveryStatus = "Cleared"
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case map = "Map"
    case route = "Route"
    case comms = "Comms"
    case more = "More"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: return "house"
        case .map: return "map"
        case .route: return "point.topleft.down.to.point.bottomright.curvepath"
        case .comms: return "dot.radiowaves.left.and.right"
        case .more: return "square.grid.2x2"
        }
    }
}

enum AppModule: String, CaseIterable, Identifiable {
    case navigation = "Navigation Center"
    case returnFunctions = "Return to Trail / Base"
    case waypoints = "Waypoints"
    case track = "Track Recorder"
    case trip = "Trip Plan"
    case mission = "Mission Mode"
    case guide = "Field Guide"
    case weather = "Weather Intelligence"
    case sensors = "Sensors"
    case log = "Field Log"
    case system = "System"
    case power = "Power"
    case emergency = "Emergency / SOS"
    case lost = "Lost Mode"
    case offlineMaps = "Offline Maps / POIs"
    case utilities = "Field Utilities"
    case externalComms = "External Communications"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .navigation: return "location.north.line"
        case .returnFunctions: return "arrow.uturn.backward.circle"
        case .waypoints: return "mappin.and.ellipse"
        case .track: return "figure.hiking"
        case .trip: return "calendar"
        case .mission: return "scope"
        case .guide: return "book.closed"
        case .weather: return "cloud.sun"
        case .sensors: return "waveform.path.ecg"
        case .log: return "text.book.closed"
        case .system: return "gearshape"
        case .power: return "battery.75percent"
        case .emergency: return "sos.circle"
        case .lost: return "questionmark.diamond"
        case .offlineMaps: return "square.stack.3d.up"
        case .utilities: return "ruler"
        case .externalComms: return "antenna.radiowaves.left.and.right"
        }
    }
}
