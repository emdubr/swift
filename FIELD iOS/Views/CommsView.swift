import MapKit
import SwiftUI

struct CommsView: View {
    enum SectionTab: String, CaseIterable, Identifiable { case chat = "LoRa Chat", map = "Mesh Map", inbox = "Inbox"; var id: String { rawValue } }
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var mesh: MeshService
    @State private var tab: SectionTab = .chat

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Comms", selection: $tab) { ForEach(SectionTab.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).padding()
                Group {
                    switch tab {
                    case .chat: LoRaChatView()
                    case .map: MeshMapView()
                    case .inbox: UnifiedInboxView()
                    }
                }
            }
            .background(FieldTheme.background)
            .navigationTitle("Comms / Mesh")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(mesh.linkState == .scanning ? "STOP" : "SCAN") { mesh.linkState == .scanning ? mesh.stopScan() : mesh.scan() }
                }
            }
        }
    }
}

private struct LoRaChatView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var mesh: MeshService
    @State private var draft = ""
    @State private var destination: UInt32? = nil
    var body: some View {
        VStack(spacing: 8) {
            HStack { StatusPill(text: mesh.linkState.rawValue, tone: mesh.linkState == .connected ? FieldTheme.accent : FieldTheme.amber); Spacer(); Text(mesh.transportNote).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }.padding(.horizontal)
            List(state.messages.sorted(by: { $0.createdAt < $1.createdAt })) { message in
                HStack { if message.outgoing { Spacer() }; VStack(alignment: .leading) { Text(message.text); Text("\(message.destination.map { String(format: "!%08X", $0) } ?? message.channel) // \(message.status.label)").font(.caption2).foregroundStyle(.secondary) }; if !message.outgoing { Spacer() } }
            }.listStyle(.plain)
            Picker("Recipient", selection: $destination) {
                Text("Broadcast to channel").tag(nil as UInt32?)
                ForEach(mesh.meshNodes) { node in
                    Text("Direct: \(node.name)").tag(Optional(node.id))
                }
            }.padding(.horizontal)
            HStack {
                TextField("Message (200 UTF-8 bytes max)", text: $draft, axis: .vertical).textFieldStyle(.roundedBorder)
                Button("QUEUE") { state.queueMessage(draft, destination: destination); draft = "" }.buttonStyle(.borderedProminent).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Data(draft.trimmingCharacters(in: .whitespacesAndNewlines).utf8).count > 200)
            }.padding()
            if Data(draft.utf8).count > 200 { Text("Message is too long for this radio profile. Split it into shorter messages.").font(.caption).foregroundStyle(FieldTheme.amber) }
            HStack {
                Button("SEND NEXT QUEUED") { state.sendNextQueued(using: mesh) }
                    .buttonStyle(.borderedProminent)
                    .disabled(mesh.linkState != .connected || !state.messages.contains(where: { $0.outgoing && ($0.status == .queued || $0.status == .failed) }))
                Spacer()
                Text("\(state.messages.filter { $0.outgoing && ($0.status == .queued || $0.status == .failed) }.count) pending")
                    .font(.caption.monospaced())
            }.padding(.horizontal)
            Text("BLE write and radio-queue acceptance are not end-to-end delivery. An actual Meshtastic device is required to verify RF behavior.")
                .font(.caption2).foregroundStyle(FieldTheme.amber).padding(.horizontal).padding(.bottom, 8)
        }
    }
}

private struct MeshMapView: View {
    @EnvironmentObject private var mesh: MeshService
    @State private var camera: MapCameraPosition = .automatic
    var body: some View {
        VStack(spacing: 8) {
            Map(position: $camera) {
                ForEach(mesh.meshNodes) { node in
                    if let point = node.location {
                        Annotation(node.name, coordinate: point.coordinate) {
                            Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(FieldTheme.accent)
                        }
                    }
                }
            }.mapControls { MapCompass(); MapScaleView() }
            Text("Mesh positions may come from the radio's cached NodeDB and are NOT verified live positions.")
                .font(.caption2).foregroundStyle(FieldTheme.amber).padding(.horizontal)
            List {
                Section("Decoded mesh nodes") {
                    if mesh.meshNodes.isEmpty { Text("No decoded node positions yet").foregroundStyle(.secondary) }
                    ForEach(mesh.meshNodes) { node in
                        VStack(alignment: .leading) {
                            Text(node.name)
                            Text("Received by phone \(node.lastHeard.formatted(date: .omitted, time: .shortened)); may be cached radio data")
                                .font(.caption).foregroundStyle(.secondary)
                            if let battery = node.batteryPercent {
                                Text(battery > 100 ? "RADIO: POWERED" : "RADIO BATTERY: \(battery)%")
                                    .font(.caption.monospaced())
                            }
                            if let channel = node.channelUtilization {
                                Text(String(format: "CHANNEL UTILIZATION %.1f%%", channel)).font(.caption.monospaced())
                            }
                            if let temp = node.temperatureC {
                                Text(String(format: "REMOTE SENSOR %.1f°C", temp)).font(.caption.monospaced())
                            }
                            if let pressure = node.pressureHPa {
                                Text(String(format: "REMOTE PRESSURE %.1f hPa", pressure)).font(.caption.monospaced())
                            }
                        }
                    }
                }
                Section("Nearby Bluetooth radios") {
                    ForEach(mesh.peers) { peer in
                        Button { mesh.connect(to: peer.id) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(peer.name)
                                    Text("BLE RSSI \(peer.rssi) dBm; not mesh signal strength")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if peer.connected { StatusPill(text: "LINK") }
                            }
                        }
                    }
                }
            }.listStyle(.plain).frame(maxHeight: 260)
        }
    }
}

private struct UnifiedInboxView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        List(state.messages.sorted(by: { $0.createdAt > $1.createdAt })) { message in
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(message.outgoing ? "OUTGOING" : "INCOMING").font(.caption2.bold()); Spacer(); Text(message.createdAt.formatted(date: .omitted, time: .shortened)).font(.caption2) }
                Text(message.text)
                Text("\(message.channel) // \(message.transport ?? "LOCAL") // \(message.status.label)")
                if let error = message.lastError { Text(error).font(.caption2).foregroundStyle(FieldTheme.amber) }
            }
        }.listStyle(.plain)
    }
}
