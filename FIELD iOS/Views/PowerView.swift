import SwiftUI

struct PowerView: View {
    @EnvironmentObject private var sensor: SensorService
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    FieldHeader(title: "Power")
                    HStack(spacing: 8) {
                        MetricTile(label: "iPhone", value: sensor.snapshot.batteryPercent.map { "\($0)%" } ?? "--")
                        MetricTile(label: "Mode", value: sensor.snapshot.lowPowerMode ? "LOW POWER" : "NORMAL", tone: sensor.snapshot.lowPowerMode ? FieldTheme.amber : FieldTheme.accent)
                    }
                    Button("REFRESH") { sensor.refreshDeviceState() }.buttonStyle(TerminalButtonStyle())
                }.fieldPanel()
                Text("FIELD/OS reduces GPS accuracy only when you choose to. iOS ultimately controls background scheduling and radio power behavior.")
                    .font(.footnote).foregroundStyle(FieldTheme.dim).fieldPanel()
            }.padding(14)
        }.background(FieldTheme.background).navigationTitle("Power")
    }
}
