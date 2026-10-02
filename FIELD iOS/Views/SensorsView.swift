import SwiftUI

struct SensorsView: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var sensor: SensorService
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    FieldHeader(title: "Phone sensors", subtitle: "LIVE")
                    HStack(spacing: 8) {
                        MetricTile(label: "GNSS", value: location.location == nil ? "SEARCH" : "FIX")
                        MetricTile(label: "Accuracy", value: location.location.map { String(format: "±%.0fm", $0.horizontalAccuracy) } ?? "--")
                        MetricTile(label: "Heading", value: location.heading.map { String(format: "%.0f°", $0.trueHeading >= 0 ? $0.trueHeading : $0.magneticHeading) } ?? "--")
                    }
                    HStack(spacing: 8) {
                        MetricTile(label: "GPS altitude", value: location.location.map { String(format: "%.0fft", $0.altitude * 3.28084) } ?? "--")
                        MetricTile(label: "Baro Δ", value: sensor.snapshot.relativeAltitudeMeters.map { String(format: "%+.1fm", $0) } ?? "--")
                        MetricTile(label: "Pressure", value: sensor.snapshot.pressureKPa.map { String(format: "%.1fkPa", $0) } ?? "--")
                    }
                }.fieldPanel()
                Text("External TAP V2 environmental sensors will feed the same snapshot model when the device protocol is connected.")
                    .font(.footnote).foregroundStyle(FieldTheme.dim).fieldPanel()
            }.padding(14)
        }.background(FieldTheme.background).navigationTitle("Sensors")
    }
}
