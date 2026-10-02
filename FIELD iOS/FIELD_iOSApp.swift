import SwiftUI

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
        .onAppear { print("FIELD_BOOT_PROBE_VISIBLE") }
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

    var body: some Scene {
        WindowGroup {
            if startupProbe {
                FieldStartupProbeView()
                    .preferredColorScheme(.dark)
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
                    .onAppear { print("FIELD_BOOT_ROOT_VISIBLE") }
                    .task {
                        print("FIELD_BOOT_LOADING_LOCAL_DATA")
                        await appState.load()
                        if previewMap { appState.selectedTab = .map }
                        print("FIELD_BOOT_LOCAL_DATA_READY")
                        // Let the first SwiftUI frame render before initiating permissions
                        // or the motion pipeline. These aren't required for launch.
                        await Task.yield()
                        locationService.requestAuthorization()
                        sensorService.start()
                        print("FIELD_BOOT_HARDWARE_REQUESTED")
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
