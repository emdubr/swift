import SwiftUI

struct MoreModulesView: View {
    @EnvironmentObject private var state: AppState
    @State private var search = ""
    @State private var selectedGroup = "ALL"
    // Two tiles in portrait; flexible extra columns on wider iPhones/iPads.
    private let columns = [GridItem(.adaptive(minimum: 142, maximum: 195), spacing: 8)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SecondaryConsoleTitle(title: "FIELD MODULES", status: "TOOLS / LOCAL", symbol: "square.grid.2x2")
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FieldTheme.accent)
                    TextField("SEARCH MODULES", text: $search)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(FieldTheme.text)
                        .tint(FieldTheme.accent)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .accessibilityLabel("Clear module search")
                    }
                }
                .padding(.horizontal, 11)
                .frame(height: 44)
                .background(FieldTheme.panelRaised)
                .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

                // Quick group jump stays visible while module tiles scroll.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["ALL"] + moduleGroups.map(\.title), id: \.self) { group in
                            Button {
                                selectedGroup = group
                            } label: {
                                Text(group)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 35)
                                    .foregroundStyle(selectedGroup == group
                                        ? FieldTheme.background : FieldTheme.accent)
                                    .background(selectedGroup == group
                                        ? FieldTheme.accent : FieldTheme.panel)
                                    .overlay(Rectangle().stroke(
                                        selectedGroup == group
                                            ? FieldTheme.accent : FieldTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedGroup == group ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 13) {
                        SecondaryConsolePanel(title: "Field readiness", detail: "ON DEVICE") {
                            HStack(spacing: 6) {
                                readinessStat("CHECKLIST", "\(state.readiness.completedCount)/\(state.readiness.totalCount)")
                                Rectangle().fill(FieldTheme.border).frame(width: 1)
                                readinessStat("LOCAL MAPS", "\(state.mapPacks.count)")
                                Rectangle().fill(FieldTheme.border).frame(width: 1)
                                readinessStat("WAYPOINTS", "\(state.waypoints.count)")
                            }
                            .frame(height: 36)
                        }

                        ForEach(moduleGroups.filter { selectedGroup == "ALL" || $0.title == selectedGroup }, id: \.title) { group in
                            let shown = group.modules.filter { matches($0) }
                            if !shown.isEmpty {
                                VStack(alignment: .leading, spacing: 7) {
                                    FieldHeader(title: group.title, subtitle: "\(shown.count) MODULES")
                                        .padding(.horizontal, 2)
                                    LazyVGrid(columns: columns, spacing: 8) {
                                        ForEach(shown) { module in
                                            NavigationLink(value: module) {
                                                moduleTile(module)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        if moduleGroups.filter({ selectedGroup == "ALL" || $0.title == selectedGroup })
                            .allSatisfy({ $0.modules.allSatisfy { !matches($0) } }) {
                            SecondaryConsolePanel(title: "Search") {
                                Text("No matching on-device modules.")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(FieldTheme.dim)
                            }
                        }
                        Text("FIELD / OS  //  NATIVE LOCAL MODULES")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(FieldTheme.dim)
                            .padding(.bottom, 9)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(FieldTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppModule.self) { ModuleDestination(module: $0) }
        }
    }

    private var moduleGroups: [(title: String, modules: [AppModule])] {
        [
            ("NAVIGATION & TRIPS", [.navigation, .returnFunctions, .waypoints, .track, .trip, .mission]),
            ("FIELD INTELLIGENCE", [.weather, .sensors, .guide, .log, .power]),
            ("MAPS & SYSTEM", [.offlineMaps, .system, .externalComms, .utilities]),
            ("SAFETY", [.emergency, .lost])
        ]
    }

    private func matches(_ module: AppModule) -> Bool {
        search.isEmpty || module.rawValue.localizedCaseInsensitiveContains(search)
            || subtitle(module).localizedCaseInsensitiveContains(search)
    }

    private func readinessStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, design: .monospaced))
                .foregroundStyle(FieldTheme.dim)
            Text(value).font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(FieldTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func moduleTile(_ module: AppModule) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: module.symbol)
                    .font(.system(size: 21))
                    .foregroundStyle(module == .emergency ? FieldTheme.amber : FieldTheme.accent)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FieldTheme.dim)
            }
            Spacer(minLength: 1)
            Text(module.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(FieldTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text(subtitle(module))
                .font(.system(size: 9))
                .foregroundStyle(FieldTheme.dim)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 27, alignment: .top)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .topLeading)
        .background(FieldTheme.panel)
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
        case .externalComms: return "TAP V2 bridge and manual satellite handoff"
        }
    }
}

struct ModuleDestination: View {
    var module: AppModule
    @ViewBuilder var body: some View {
        Group {
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
        .background(FieldTheme.background)
        .scrollContentBackground(.hidden)
        .tint(FieldTheme.accent)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(FieldTheme.panel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
