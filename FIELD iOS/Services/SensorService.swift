import CoreMotion
import Foundation
import UIKit

@MainActor
final class SensorService: ObservableObject {
    // CMAltimeter is optional and only created after the app has shown its UI.
    // The iOS Simulator doesn't provide a real barometer; don't initialize it there.
    private var altimeter: CMAltimeter?
    @Published private(set) var snapshot = SensorSnapshot()

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshDeviceState()
        #if !targetEnvironment(simulator)
        guard altimeter == nil, CMAltimeter.isRelativeAltitudeAvailable() else { return }
        let service = CMAltimeter()
        altimeter = service
        service.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            Task { @MainActor in
                self.snapshot.timestamp = .now
                self.snapshot.relativeAltitudeMeters = data.relativeAltitude.doubleValue
                self.snapshot.pressureKPa = data.pressure.doubleValue
                self.refreshDeviceState()
            }
        }
        #endif
    }

    func stop() {
        altimeter?.stopRelativeAltitudeUpdates()
        altimeter = nil
    }

    func refreshDeviceState() {
        let level = UIDevice.current.batteryLevel
        snapshot.batteryPercent = level >= 0 ? Int((level * 100).rounded()) : nil
        snapshot.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}
