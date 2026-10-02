import SwiftUI

struct EmergencyView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @State private var confirmingSOS = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    FieldHeader(title: "Emergency / SOS", subtitle: "LOCAL PREP")
                    if let loc = location.location {
                        Text(String(format: "POSITION %.5f, %.5f // ±%.0fm", loc.coordinate.latitude, loc.coordinate.longitude, loc.horizontalAccuracy))
                            .font(.headline.monospaced())
                    } else { Text("NO CURRENT POSITION FIX").foregroundStyle(FieldTheme.amber) }
                    Text("This build can prepare and queue an SOS packet, but it does not claim to transmit through satellite or Meshtastic until a real transport confirms delivery.")
                        .font(.footnote).foregroundStyle(FieldTheme.amber)
                }.fieldPanel()
                if let url = URL(string: "tel://911") {
                    Link(destination: url) { Label("CALL 911", systemImage: "phone.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).tint(FieldTheme.danger)
                }
                NavigationLink(destination: ExternalCommsView()) {
                    Label("SHARE VIA EXTERNAL COMMUNICATOR (MANUAL)", systemImage: "square.and.arrow.up")
                }.buttonStyle(.bordered)
                Button("PREPARE SOS PACKET") { confirmingSOS = true }
                    .buttonStyle(.borderedProminent).tint(FieldTheme.danger)
            }.padding(14)
        }.background(FieldTheme.background).navigationTitle("Emergency")
        .confirmationDialog("Queue an SOS message locally?", isPresented: $confirmingSOS, titleVisibility: .visible) {
            Button("Queue SOS", role: .destructive) { queueSOS() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func queueSOS() {
        var text = "SOS // ASSISTANCE REQUESTED"
        if let loc = location.location { text += String(format: " // POS %.5f, %.5f // ACC ±%.0fm", loc.coordinate.latitude, loc.coordinate.longitude, loc.horizontalAccuracy) }
        state.queueMessage(text, channel: "SOS")
        state.log("SOS", "SOS packet prepared locally", point: location.location.map(RoutePoint.init(location:)))
    }
}

struct LostModeView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    FieldHeader(title: "Lost mode", subtitle: "STOP / THINK")
                    Text("Avoid making the situation worse. Confirm your last known position, check the active route and recorded breadcrumb, protect yourself from exposure, and use a communications method before committing to unknown terrain.")
                        .foregroundStyle(FieldTheme.text)
                }.fieldPanel()
                NavigationLink(value: AppModule.returnFunctions) { Label("OPEN RETURN FUNCTIONS", systemImage: "arrow.uturn.backward.circle") }.buttonStyle(TerminalButtonStyle())
                NavigationLink(value: AppModule.emergency) { Label("OPEN EMERGENCY", systemImage: "sos.circle") }.buttonStyle(TerminalButtonStyle())
            }.padding(14)
        }.background(FieldTheme.background).navigationTitle("Lost Mode")
    }
}
