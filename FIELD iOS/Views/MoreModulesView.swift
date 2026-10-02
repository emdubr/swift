import SwiftUI

struct MoreModulesView: View {
    @State private var search = ""
    var body: some View {
        NavigationStack {
            List(filtered) { module in
                NavigationLink(value: module) {
                    ModuleRow(title: module.rawValue, symbol: module.symbol, subtitle: subtitle(module))
                }
            }
            .navigationTitle("Field Modules")
            .searchable(text: $search, prompt: "Find a module")
            .navigationDestination(for: AppModule.self) { ModuleDestination(module: $0) }
        }
    }

    private var filtered: [AppModule] {
        search.isEmpty ? AppModule.allCases : AppModule.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(search) || subtitle($0).localizedCaseInsensitiveContains(search) }
    }
    private func subtitle(_ m: AppModule) -> String {
        switch m {
        case .navigation: return "GPS, heading, off-route guidance"
        case .returnFunctions: return "Nearest route intercept and base bearing"
        case .waypoints: return "Local points, base, water, hazards"
        case .track: return "Breadcrumb recording and save-to-route"
        case .trip: return "Start, turnaround, check-ins, emergency note"
        case .mission: return "Objectives and group-expedition settings"
        case .guide: return "Offline backcountry reference"
        case .weather: return "Weather state and provider integration"
        case .sensors: return "GPS, barometer, device sensor stream"
        case .log: return "Scratchpad, events, timestamped position marks"
        case .system: return "Preflight, recovery, offline settings"
        case .power: return "Battery and low-power status"
        case .emergency: return "Emergency call and local SOS packet"
        case .lost: return "Lost-mode decision support"
        case .offlineMaps: return "On-device PMTiles, trails and POI import"
        case .utilities: return "DMS, distance/bearing, marks, sharing"
        case .externalComms: return "TAP V2 GATT diagnostic bridge and manual satellite handoff"
        }
    }
}

struct ModuleDestination: View {
    var module: AppModule
    @ViewBuilder var body: some View {
        switch module {
        case .navigation: NavigationCenterView()
        case .returnFunctions: ReturnFunctionsView()
        case .waypoints: WaypointsView()
        case .track: TrackRecorderView()
        case .trip: TripPlanView()
        case .mission: MissionView()
        case .guide: FieldGuideView()
        case .weather: WeatherView()
        case .sensors: SensorsView()
        case .log: FieldLogView()
        case .system: SystemView()
        case .power: PowerView()
        case .emergency: EmergencyView()
        case .lost: LostModeView()
        case .offlineMaps: OfflineMapsView()
        case .utilities: FieldUtilitiesView()
        case .externalComms: ExternalCommsView()
        }
    }
}
