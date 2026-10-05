import SwiftUI

// On-device measurements: missing readings stay explicitly unavailable.
struct SensorsView: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var sensor: SensorService

    var body: some View {
        VStack(spacing: 0) {
            SecondaryConsoleTitle(title: "SENSOR STATION",
                                  status: location.location == nil ? "AWAITING GNSS" : "DEVICE FIX",
                                  symbol: "waveform.path.ecg")
            ScrollView {
                VStack(spacing: 10) {
                    SecondaryConsolePanel(title: "Position receiver", detail: "PHONE GNSS") {
                        VStack(spacing: 7) {
                            HStack(spacing: 7) {
                                MetricTile(label: "GNSS", value: location.location == nil ? "SEARCH" : "FIX",
                                           tone: location.location == nil ? FieldTheme.amber : FieldTheme.accent)
                                MetricTile(label: "ACCURACY",
                                           value: location.location.map { String(format: "±%.0f m", $0.horizontalAccuracy) } ?? "--")
                                MetricTile(label: "HEADING", value: location.heading.map {
                                    String(format: "%.0f°", $0.trueHeading >= 0 ? $0.trueHeading : $0.magneticHeading)
                                } ?? "--")
                            }
                            HStack(spacing: 7) {
                                MetricTile(label: "GPS ALT",
                                           value: location.location.map {
                                               String(format: "%.0f ft", $0.altitude * 3.28084)
                                           } ?? "--")
                                MetricTile(label: "BARO Δ",
                                           value: sensor.snapshot.relativeAltitudeMeters.map {
                                               String(format: "%+.1f m", $0)
                                           } ?? "--")
                                MetricTile(label: "PRESSURE", value: sensor.snapshot.pressureKPa.map {
                                    String(format: "%.1f kPa", $0)
                                } ?? "--")
                            }
                        }
                    }
                    SecondaryConsolePanel(title: "External telemetry", detail: "BRIDGE STATUS") {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(FieldTheme.amber)
                            Text("TAP V2 environmental telemetry appears when the external device protocol is connected. No external readings are simulated.")
                                .font(.caption.monospaced())
                                .foregroundStyle(FieldTheme.dim)
                        }
                    }
                    Text("Use live readings only after confirming permissions and sensor availability.")
                        .font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim)
                }
                .padding(10)
            }
        }
        .background(FieldTheme.background.ignoresSafeArea())
        // Keep the compact iOS back affordance when opened from Tools.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
