import CoreLocation
import SwiftUI

struct ExternalCommsView: View {
    @EnvironmentObject private var bridge: PeripheralBridgeService
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var state: AppState
    @AppStorage("field-bridge-service") private var gattService = ""
    @AppStorage("field-bridge-notify") private var gattNotify = ""
    @State private var handoffNote = ""
    @State private var sosMode = false

    private var packet: String {
        let fix: FieldHandoff.Fix? = location.location.map {
            .init(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude,
                  accuracyMeters: $0.horizontalAccuracy, obtainedAt: $0.timestamp)
        }
        return FieldHandoff.message(fix: fix, purpose: sosMode ? "SOS" : "CHECK-IN", note: handoffNote)
    }
    var body: some View {
        Form {
            Section("Manual satellite / external app handoff") {
                Toggle("Assistance request (SOS text)", isOn: $sosMode)
                TextField("Optional note", text: $handoffNote, axis: .vertical)
                Text(packet).font(.caption.monospaced()).textSelection(.enabled)
                ShareLink(item: packet, subject: Text(sosMode ? "FIELD/OS SOS handoff" : "FIELD/OS check-in")) {
                    Label("Open share sheet for another communicator", systemImage: "square.and.arrow.up")
                }
                Text("This opens a share sheet. It cannot transmit through a satellite modem or guarantee that another app sends the message. Verify delivery independently.")
                    .font(.caption).foregroundStyle(FieldTheme.amber)
                if sosMode {
                    Text("For an immediate emergency, use your phone's own Emergency SOS/calling features or a dedicated communicator; FIELD/OS cannot trigger Apple's satellite SOS API.")
                        .font(.caption).foregroundStyle(FieldTheme.danger)
                }
            }
            Section("TAP V2 generic BLE receive-only bridge") {
                Text("Use exact 128-bit UUIDs documented by your own firmware. This receives raw notifications for protocol development. It does not decode sensor or satellite data.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Custom service UUID", text: $gattService).textInputAutocapitalization(.never)
                    .font(.caption.monospaced())
                TextField("Notify characteristic UUID", text: $gattNotify).textInputAutocapitalization(.never)
                    .font(.caption.monospaced())
                HStack {
                    Button(bridge.state == .scanning ? "Stop scan" : "Scan configured service") {
                        if bridge.state == .scanning { bridge.stopScan() }
                        else { bridge.scan(service: gattService, notificationCharacteristic: gattNotify) }
                    }
                    .disabled(bridge.state != .scanning && (!PeripheralBridgeService.valid128(gattService) || !PeripheralBridgeService.valid128(gattNotify)))
                    Spacer()
                    Text(bridge.state.rawValue).font(.caption.monospaced())
                }
                ForEach(bridge.discovered, id: \.id) { peripheral in
                    Button("\(peripheral.name) (RSSI \(peripheral.rssi) dBm) — Connect") {
                        bridge.connect(peripheral.id)
                    }
                }
                if bridge.state == .connected { Button("Disconnect", role: .destructive) { bridge.disconnect() } }
                Text(bridge.note).font(.caption).foregroundStyle(.secondary)
                LabeledContent("Received frames", value: "\(bridge.receivedFrames)")
                if let last = bridge.lastFrameAt {
                    Text("Last raw frame: \(last.formatted(date: .abbreviated, time: .standard)); \(bridge.lastFrameLength) bytes")
                        .font(.caption)
                    Text(bridge.lastFrameHex).font(.caption2.monospaced()).textSelection(.enabled)
                }
            }
        }.navigationTitle("External Communications")
    }
}
