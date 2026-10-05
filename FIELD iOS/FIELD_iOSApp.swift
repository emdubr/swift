import SwiftUI
import OSLog

// A deliberately minimal path for cloud simulator runtime checks. It creates no
// hardware managers and does not read previous app state. If this view will not
// launch, troubleshoot signing/dynamic frameworks/simulator before native UI.
private struct FieldStartupProbeView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 38))
            Text("FIELD / OS")
                .font(.largeTitle.bold().monospaced())
            Text("NATIVE STARTUP CHECK")
                .font(.headline.monospaced())
            Text("SwiftUI process is alive")
                .font(.caption.monospaced())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundStyle(Color.green)
        .accessibilityIdentifier("field-native-startup-check")
        .onAppear { Logger(subsystem: "com.fieldos.native", category: "boot").notice("FIELD_BOOT_PROBE_VISIBLE") }
    }
}

@main
struct FIELD_iOSApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var locationService = LocationService()
    @StateObject private var trackRecorder = TrackRecorder()
    @StateObject private var meshService = MeshService()
    @StateObject private var sensorService = SensorService()
    @StateObject private var checkInService = CheckInService()
    @StateObject private var peripheralBridge = PeripheralBridgeService()

    // Only the CI runner opts into this with a launch argument. It never replaces
    // the normal app launched from an iPhone's Home Screen.
    private let startupProbe = ProcessInfo.processInfo.arguments.contains("-FIELDStartupProbe")
    // Cloud screenshot-only navigation. Never alters production launch behavior.
    private let previewMap = ProcessInfo.processInfo.arguments.contains("-FIELDPreviewMap")
    private let previewRoute = ProcessInfo.processInfo.arguments.contains("-FIELDPreviewRoute")
    private let previewComms = ProcessInfo.processInfo.arguments.contains("-FIELDPreviewComms")
    private let previewTools = ProcessInfo.processInfo.arguments.contains("-FIELDPreviewTools")
    // Real Tools submodule screenshots; these arguments are never set on iPhone.
    private let previewModule: AppModule? = ProcessInfo.processInfo.arguments.contains("-FIELDPreviewSensors")
        ? .sensors : ProcessInfo.processInfo.arguments.contains("-FIELDPreviewWeather")
        ? .weather : ProcessInfo.processInfo.arguments.contains("-FIELDPreviewMission")
        ? .mission : nil
    // CI screenshot-only: render genuine native views but avoid emulator-only sensor startup.
    private let renderOnly = ProcessInfo.processInfo.arguments.contains("-FIELDRenderOnly")
    // Diagnostic only. Same real DashboardView, without TabView / RootView
    // so the smoke test can tell a dashboard problem from tab-host startup.
    private let isolateDashboard = ProcessInfo.processInfo.arguments.contains("-FIELDIsolatedDashboard")

    var body: some Scene {
        WindowGroup {
            if startupProbe {
                FieldStartupProbeView()
                    .preferredColorScheme(.dark)
            } else if isolateDashboard {
                DashboardView()
                    .environmentObject(appState)
                    .environmentObject(locationService)
                    .environmentObject(trackRecorder)
                    .environmentObject(meshService)
                    .environmentObject(sensorService)
                    .environmentObject(checkInService)
                    .environmentObject(peripheralBridge)
                    .preferredColorScheme(.dark)
                    .onAppear { Logger(subsystem: "com.fieldos.native", category: "boot").notice("FIELD_DIAGNOSTIC_ISOLATED_DASHBOARD_VISIBLE") }
            } else if let previewModule {
                NavigationStack {
                    ModuleDestination(module: previewModule)
                }
                .environmentObject(appState)
                .environmentObject(locationService)
                .environmentObject(trackRecorder)
                .environmentObject(meshService)
                .environmentObject(sensorService)
                .environmentObject(checkInService)
                .environmentObject(peripheralBridge)
                .preferredColorScheme(.dark)
                .tint(FieldTheme.accent)
            } else {
                RootView()
                    .environmentObject(appState)
                    .environmentObject(locationService)
                    .environmentObject(trackRecorder)
                    .environmentObject(meshService)
                    .environmentObject(sensorService)
                    .environmentObject(checkInService)
                    .environmentObject(peripheralBridge)
                    .preferredColorScheme(.dark)
                    .tint(FieldTheme.accent)
                    .onAppear { Logger(subsystem: "com.fieldos.native", category: "boot").notice("FIELD_BOOT_ROOT_VISIBLE") }
                    .task {
                        Logger(subsystem: "com.fieldos.native", category: "boot").notice("FIELD_BOOT_LOADING_LOCAL_DATA")
                        // Clean screenshot CI has no user data to restore. Avoid a
                        // filesystem handoff competing with the first animation.
                        // Normal on-device launch ALWAYS loads the saved state.
                        if !renderOnly {
                            await appState.load()
                        }
                        if previewMap { appState.selectedTab = .map }
                        if previewRoute { appState.selectedTab = .route }
                        if previewComms { appState.selectedTab = .comms }
                        if previewTools { appState.selectedTab = .more }
                        Logger(subsystem: "com.fieldos.native", category: "boot").notice("FIELD_BOOT_LOCAL_DATA_READY")
                        // Let the first SwiftUI frame render before initiating permissions
                        // or the motion pipeline. These aren't required for launch.
                        await Task.yield()
                        if !renderOnly {
                            locationService.requestAuthorization()
                            sensorService.start()
                            Logger(subsystem: "com.fieldos.native", category: "boot").notice("FIELD_BOOT_HARDWARE_REQUESTED")
                        } else {
                            Logger(subsystem: "com.fieldos.native", category: "boot").notice("FIELD_BOOT_SCREENSHOT_ONLY_NO_HARDWARE")
                        }
                    }
                    .onReceive(meshService.$latestEvent) { delivery in
                        if let delivery { appState.receiveMeshEvent(delivery.value) }
                    }
                    .onReceive(meshService.$latestReceipt) { receipt in
                        if let receipt { appState.applyReceipt(receipt) }
                    }
                    .onReceive(locationService.$location) { location in
                        if let location { trackRecorder.ingest(location) }
                    }
            }
        }
    }
}
