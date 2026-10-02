import SwiftUI

@main
struct FIELD_iOSApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var locationService = LocationService()
    @StateObject private var trackRecorder = TrackRecorder()
    @StateObject private var meshService = MeshService()
    @StateObject private var sensorService = SensorService()
    @StateObject private var checkInService = CheckInService()
    @StateObject private var peripheralBridge = PeripheralBridgeService()

    var body: some Scene {
        WindowGroup {
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
                .task {
                    await appState.load()
                    locationService.requestAuthorization()
                    sensorService.start()
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
