import CoreMotion
import Foundation
import UIKit

@MainActor
final class SensorService: ObservableObject {
    private let altimeter = CMAltimeter()
    @Published private(set) var snapshot = SensorSnapshot()

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshDeviceState()
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                Task { @MainActor in
                    self.snapshot.timestamp = .now
                    self.snapshot.relativeAltitudeMeters = data.relativeAltitude.doubleValue
                    self.snapshot.pressureKPa = data.pressure.doubleValue
                    self.refreshDeviceState()
                }
            }
        }
    }

    func stop() { altimeter.stopRelativeAltitudeUpdates() }

    func refreshDeviceState() {
        let level = UIDevice.current.batteryLevel
        snapshot.batteryPercent = level >= 0 ? Int((level * 100).rounded()) : nil
        snapshot.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}
