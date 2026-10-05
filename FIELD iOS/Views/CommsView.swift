import MapKit
import SwiftUI

struct CommsView: View {
    enum SectionTab: String, CaseIterable, Identifiable {
        case chat = "LORA CHAT", map = "MESH MAP", inbox = "INBOX"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .map: return "point.3.connected.trianglepath.dotted"
            case .inbox: return "tray"
            }
        }
    }

    @EnvironmentObject private var mesh: MeshService
    @State private var tab: SectionTab = .chat
    // Preserve unsent text and recipient while switching Chat / Mesh Map / Inbox.
    @State private var chatDraft = ""
    @State private var chatDestination: UInt32? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SecondaryConsoleTitle(
                    title: "COMMS / MESH",
                    status: mesh.linkState == .connected ? "RADIO LINKED" : "RADIO NOT LINKED",
                    symbol: "dot.radiowaves.left.and.right"
                )
                HStack(spacing: 4) {
                    ForEach(SectionTab.allCases) { item in
                        Button {
                            tab = item
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 12, weight: .medium))
                                Text(item.rawValue)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(tab == item ? FieldTheme.background : FieldTheme.accent)
                            .frame(maxWidth: .infinity, minHeight: 39)
                            .background(tab == item ? FieldTheme.accent : FieldTheme.panel)
                            .overlay(Rectangle().stroke(
                                tab == item ? FieldTheme.accent : FieldTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(tab == item ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)

                HStack(spacing: 8) {
                    Circle()
                        .fill(mesh.linkState == .connected ? FieldTheme.accent : FieldTheme.amber)
                        .frame(width: 6, height: 6)
                    Text(mesh.linkState.rawValue.uppercased())
                    Text(" // ")
                        .foregroundStyle(FieldTheme.dim)
                    Text(mesh.transportNote)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 1)
                    Button(mesh.linkState == .scanning ? "STOP" : "SCAN") {
                        if mesh.linkState == .scanning { mesh.stopScan() }
                        else { mesh.scan() }
                    }
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(FieldTheme.accent)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .overlay(Rectangle().stroke(FieldTheme.accent.opacity(0.7), lineWidth: 1))
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(FieldTheme.text)
                .padding(.horizontal, 10)
                .frame(height: 39)
                .background(FieldTheme.panelRaised)
                .overlay(alignment: .bottom) { FieldTheme.border.frame(height: 1) }

                Group {
                    switch tab {
                    case .chat: LoRaChatView(draft: $chatDraft, destination: $chatDestination)
                    case .map: MeshMapView()
                    case .inbox: UnifiedInboxView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(FieldTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct LoRaChatView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var mesh: MeshService
    @Binding var draft: String
    @Binding var destination: UInt32?

    private var pending: Int {
        state.messages.filter { $0.outgoing && ($0.status == .queued || $0.status == .failed) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Text("RADIO MESSAGES")
                    .foregroundStyle(FieldTheme.text)
                Spacer(minLength: 3)
                Text("\(state.messages.count) LOGGED  //  \(pending) PENDING")
                    .foregroundStyle(FieldTheme.dim)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(.horizontal, 12)
            .frame(height: 39)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if state.messages.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundStyle(FieldTheme.dim)
                            Text("NO RADIO MESSAGES")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(FieldTheme.text)
                            Text("Pair a Meshtastic radio or queue an offline message below. Queued does not mean delivered.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(FieldTheme.dim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 27)
                        .overlay(Rectangle().stroke(FieldTheme.border.opacity(0.55), lineWidth: 1))
                    } else {
                        ForEach(state.messages.sorted(by: { $0.createdAt < $1.createdAt })) { message in
                            HStack(spacing: 0) {
                                if message.outgoing { Spacer(minLength: 35) }
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(message.outgoing ? "OUTGOING" : "INCOMING")
                                        Spacer(minLength: 4)
                                        Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                                    }
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(FieldTheme.dim)
                                    Text(message.text)
                                        .font(.system(size: 13))
                                        .foregroundStyle(FieldTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(message.destination.map { String(format: "!%08X", $0) } ?? message.channel)  //  \(message.status.label.uppercased())")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(message.status == .failed ? FieldTheme.amber : FieldTheme.accent)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .padding(10)
                                .background(message.outgoing ? FieldTheme.panelRaised : FieldTheme.panel)
                                .overlay(Rectangle().stroke(
                                    message.outgoing ? FieldTheme.accent.opacity(0.48) : FieldTheme.border, lineWidth: 1))
                                if !message.outgoing { Spacer(minLength: 35) }
                            }
                        }
                    }
                }
                .padding(10)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FieldTheme.background)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("DESTINATION")
                        .foregroundStyle(FieldTheme.dim)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Menu {
                        Button("BROADCAST / CHANNEL") { destination = nil }
                        ForEach(mesh.meshNodes) { node in
                            Button("DIRECT: \(node.name)") { destination = node.id }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(destination == nil ? "BROADCAST" : "DIRECT NODE")
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(FieldTheme.accent)
                        .padding(.horizontal, 9)
                        .frame(height: 34)
                        .background(FieldTheme.panelRaised)
                        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                    }
                    .accessibilityLabel(destination == nil ? "Broadcast to channel" : "Direct radio recipient")
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .frame(height: 36)

                HStack(alignment: .bottom, spacing: 6) {
                    TextField("WRITE RADIO MESSAGE", text: $draft, axis: .vertical)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1...3)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .foregroundStyle(FieldTheme.text)
                        .tint(FieldTheme.accent)
                        .background(FieldTheme.panelRaised)
                        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                    Button("QUEUE") {
                        state.queueMessage(draft, destination: destination)
                        draft = ""
                    }
                    .buttonStyle(SecondaryConsoleButton(emphasized: true))
                    .frame(width: 77)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || Data(draft.trimmingCharacters(in: .whitespacesAndNewlines).utf8).count > 200)
                }
                if Data(draft.utf8).count > 200 {
                    Text("OVER RADIO LIMIT: 200 UTF-8 BYTES")
                        .foregroundStyle(FieldTheme.amber)
                        .font(.caption2.monospaced())
                }
                HStack(spacing: 7) {
                    Button("SEND NEXT QUEUED") { state.sendNextQueued(using: mesh) }
                        .buttonStyle(SecondaryConsoleButton())
                        .disabled(mesh.linkState != .connected || pending == 0)
                    Text("\(pending) IN QUEUE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(FieldTheme.dim)
                        .frame(width: 97)
                }
                Text("RADIO QUEUE ACCEPTANCE IS NOT VERIFIED RF DELIVERY")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(FieldTheme.amber)
                    .lineLimit(2)
            }
            .padding(9)
            .background(FieldTheme.panel)
            .overlay(alignment: .top) { FieldTheme.border.frame(height: 1) }
        }
    }
}

private struct MeshMapView: View {
    @EnvironmentObject private var mesh: MeshService
    @State private var camera: MapCameraPosition = .automatic
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Map(position: $camera) {
                    ForEach(mesh.meshNodes) { node in
                        if let point = node.location {
                            Annotation(node.name, coordinate: point.coordinate) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.title3)
                                    .foregroundStyle(FieldTheme.accent)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls { MapCompass(); MapScaleView() }
                Text("CACHED RADIO POSITIONS  //  NOT LIVE GPS")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(FieldTheme.amber)
                    .padding(9)
                    .background(FieldTheme.panel.opacity(0.96))
                    .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                    .padding(9)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            SecondaryConsolePanel(title: "Radio node database", detail: "\(mesh.meshNodes.count) NODES") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        if mesh.meshNodes.isEmpty {
                            Text("No decoded radio positions. Cached nodes appear after a radio sync.")
                                .font(.caption.monospaced())
                                .foregroundStyle(FieldTheme.dim)
                        }
                        ForEach(mesh.meshNodes) { node in
                            Button {
                                // Selecting a cached position moves ONLY the
                                // map camera. It is never treated as live GPS.
                                if let coordinate = node.location?.coordinate {
                                    camera = .region(MKCoordinateRegion(
                                        center: coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.02,
                                                               longitudeDelta: 0.02)
                                    ))
                                }
                            } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(node.name.uppercased())
                                        .foregroundStyle(FieldTheme.text)
                                    Spacer()
                                    Text(node.lastHeard.formatted(date: .omitted, time: .shortened))
                                        .foregroundStyle(FieldTheme.dim)
                                }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                HStack(spacing: 8) {
                                    if let battery = node.batteryPercent {
                                        Text(battery > 100 ? "POWERED" : "BAT \(battery)%")
                                    }
                                    if let channel = node.channelUtilization {
                                        Text(String(format: "AIR %.1f%%", channel))
                                    }
                                    if let temp = node.temperatureC {
                                        Text(String(format: "TEMP %.1f°C", temp))
                                    }
                                }
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(FieldTheme.dim)
                            }
                            .padding(8)
                            .background(FieldTheme.panelRaised)
                            .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(node.location == nil)
                            .accessibilityHint(node.location == nil
                                ? "No cached node position available"
                                : "Center map on this last-reported radio position")
                        }
                        ForEach(mesh.peers) { peer in
                            Button { mesh.connect(to: peer.id) } label: {
                                HStack {
                                    Text(peer.name)
                                    Spacer()
                                    Text("BLE \(peer.rssi) dBm")
                                    if peer.connected { Image(systemName: "checkmark.link") }
                                }
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(FieldTheme.accent)
                                .padding(9)
                                .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Bluetooth RSSI is not LoRa RF signal strength")
                        }
                    }
                }
                .frame(maxHeight: 135)
            }
        }
        .background(FieldTheme.background)
    }
}

private struct UnifiedInboxView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                SecondaryConsolePanel(title: "Unified inbox", detail: "\(state.messages.count) LOGGED") {
                    Text("LOCAL MESSAGE LOG  //  STATUS MAY NOT INDICATE DELIVERY")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(FieldTheme.dim)
                }
                if state.messages.isEmpty {
                    SecondaryConsolePanel(title: "No messages") {
                        Text("Incoming and queued outgoing radio traffic will appear here.")
                            .font(.caption.monospaced())
                            .foregroundStyle(FieldTheme.dim)
                    }
                }
                ForEach(state.messages.sorted(by: { $0.createdAt > $1.createdAt })) { message in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(message.outgoing ? "OUTGOING" : "INCOMING")
                                .foregroundStyle(FieldTheme.accent)
                            Spacer()
                            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(FieldTheme.dim)
                        }
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        Text(message.text)
                            .font(.system(size: 12))
                            .foregroundStyle(FieldTheme.text)
                        Text("\(message.channel)  //  \(message.transport ?? "LOCAL")  //  \(message.status.label)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(FieldTheme.dim)
                        if let error = message.lastError {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(FieldTheme.amber)
                        }
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FieldTheme.panel)
                    .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
                }
            }
            .padding(10)
        }
        .background(FieldTheme.background)
    }
}
