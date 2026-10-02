import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var locationService: LocationService
    // Construct MapKit, offline tiles and BLE screens only after first selection.
    // Keep previously visited tabs alive so navigation/camera state survives switching.
    @State private var activatedTabs: Set<AppTab> = [.home]

    var body: some View {
        TabView(selection: $state.selectedTab) {
            DashboardView()
                .tag(AppTab.home)
                .tabItem { Label(AppTab.home.rawValue, systemImage: AppTab.home.symbol) }
            Group {
                if activatedTabs.contains(.map) || state.selectedTab == .map {
                    MapScreen()
                } else {
                    Color.clear
                }
            }
                .tag(AppTab.map)
                .tabItem { Label(AppTab.map.rawValue, systemImage: AppTab.map.symbol) }
            Group {
                if activatedTabs.contains(.route) || state.selectedTab == .route {
                    RoutePlannerView()
                } else {
                    Color.clear
                }
            }
                .tag(AppTab.route)
                .tabItem { Label(AppTab.route.rawValue, systemImage: AppTab.route.symbol) }
            Group {
                if activatedTabs.contains(.comms) || state.selectedTab == .comms {
                    CommsView()
                } else {
                    Color.clear
                }
            }
                .tag(AppTab.comms)
                .tabItem { Label(AppTab.comms.rawValue, systemImage: AppTab.comms.symbol) }
            Group {
                if activatedTabs.contains(.more) || state.selectedTab == .more {
                    MoreModulesView()
                } else {
                    Color.clear
                }
            }
                .tag(AppTab.more)
                .tabItem { Label(AppTab.more.rawValue, systemImage: AppTab.more.symbol) }
        }
        .tint(FieldTheme.accent)
        .toolbarBackground(FieldTheme.panel, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(FieldTheme.background.ignoresSafeArea())
        // FIELD_iOSApp owns the single location -> track recorder subscription.
        .onChange(of: state.selectedTab) { _, next in
            activatedTabs.insert(next)
        }
        .onChange(of: state.settings.highAccuracyGPS) { _, value in
            locationService.setHighAccuracy(value)
        }
    }
}
