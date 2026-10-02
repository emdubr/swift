import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        TabView(selection: $state.selectedTab) {
            DashboardView()
                .tag(AppTab.home)
                .tabItem { Label(AppTab.home.rawValue, systemImage: AppTab.home.symbol) }
            MapScreen()
                .tag(AppTab.map)
                .tabItem { Label(AppTab.map.rawValue, systemImage: AppTab.map.symbol) }
            RoutePlannerView()
                .tag(AppTab.route)
                .tabItem { Label(AppTab.route.rawValue, systemImage: AppTab.route.symbol) }
            CommsView()
                .tag(AppTab.comms)
                .tabItem { Label(AppTab.comms.rawValue, systemImage: AppTab.comms.symbol) }
            MoreModulesView()
                .tag(AppTab.more)
                .tabItem { Label(AppTab.more.rawValue, systemImage: AppTab.more.symbol) }
        }
        .background(FieldTheme.background.ignoresSafeArea())
        // FIELD_iOSApp owns the single location -> track recorder subscription.
        .onChange(of: state.settings.highAccuracyGPS) { _, value in
            locationService.setHighAccuracy(value)
        }
    }
}
