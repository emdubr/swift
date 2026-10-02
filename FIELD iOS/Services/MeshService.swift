import CoreBluetooth
import Foundation

@MainActor
final class MeshService: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum LinkState: String { case unavailable = "UNAVAILABLE", idle = "IDLE", scanning = "SCANNING", connecting = "CONNECTING", connected = "CONNECTED", syncing = "SYNCING" }

    static let meshServiceUUID = CBUUID(string: "6BA1B218-15A8-461F-9FA8-5DCAE273EAFD")
    static let fromRadioUUID = CBUUID(string: "2C55E69E-4993-11ED-B878-0242AC120002")
    static let toRadioUUID = CBUUID(string: "F75C76D2-129E-4DAD-A1DD-7866124401E7")
    static let fromNumUUID = CBUUID(string: "ED9DA18C-A800-4F66-A670-AA7547E34453")

    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var linkState: LinkState = .idle
    @Published private(set) var peers: [MeshPeer] = []
    @Published private(set) var connectedPeerID: UUID?
    @Published private(set) var transportNote = "Ready to scan for Meshtastic BLE radios."
    @Published private(set) var receivedEnvelopeCount = 0
    @Published private(set) var lastRawEnvelopeSize = 0
    @Published private(set) var latestEvent: EventDelivery?
    @Published private(set) var latestReceipt: RadioReceipt?
    @Published private(set) var meshNodes: [MeshNode] = []
    @Published private(set) var decodedCount = 0
    @Published private(set) var decodeFailures = 0
    struct EventDelivery { let id = UUID(); let value: MeshtasticCodec.Event }
    struct RadioReceipt {
        enum Kind { case accepted, failed(String), routingAcknowledged }
        let packetID: UInt32
        let kind: Kind
    }
    private let handshakeNonce: UInt32 = 69420
    private var activePacketID: UInt32?
    private var recentPackets: [String] = []

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var fromRadio: CBCharacteristic?
    private var toRadio: CBCharacteristic?
    private var fromNum: CBCharacteristic?

    override init() { super.init(); central = CBCentralManager(delegate: self, queue: nil) }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state != .poweredOn { linkState = .unavailable; resetTransport() }
        else if linkState == .unavailable { linkState = .idle }
    }

    func scan() {
        guard central.state == .poweredOn else { linkState = .unavailable; return }
        peers = []; peripherals = [:]; linkState = .scanning
        central.scanForPeripherals(withServices: [Self.meshServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        transportNote = "Scanning for Meshtastic service…"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10)); if self.linkState == .scanning { self.stopScan() }
        }
    }

    func stopScan() { central.stopScan(); if linkState == .scanning { linkState = .idle }; if peers.isEmpty { transportNote = "No Meshtastic BLE radios found." } }

    func connect(to id: UUID) {
        guard let peripheral = peripherals[id] else { return }
        stopScan(); linkState = .connecting; peripheral.delegate = self; central.connect(peripheral)
    }

    func sendText(_ text: String, packetID: UInt32, destination: UInt32? = nil) -> Bool {
        guard linkState == .connected, activePacketID == nil,
              let id = connectedPeerID, let radio = peripherals[id], let toRadio else { return false }
        guard let payload = try? MeshtasticCodec.textPacket(text, packetID: packetID, destination: destination ?? .max) else { return false }
        activePacketID = packetID
        radio.writeValue(payload, for: toRadio, type: .withResponse)
        return true
    }

    func disconnect() {
        if let id = connectedPeerID, let peripheral = peripherals[id] { central.cancelPeripheralConnection(peripheral) }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? "Meshtastic \(peripheral.identifier.uuidString.prefix(6))"
        let peer = MeshPeer(id: peripheral.identifier, name: name, rssi: RSSI.intValue, lastHeard: .now)
        peripherals[peripheral.identifier] = peripheral
        if let i = peers.firstIndex(where: { $0.id == peer.id }) { peers[i] = peer } else { peers.append(peer) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeerID = peripheral.identifier; linkState = .syncing
        if let i = peers.firstIndex(where: { $0.id == peripheral.identifier }) { peers[i].connected = true }
        transportNote = "Meshtastic service connected; discovering PhoneAPI characteristics…"
        peripheral.discoverServices([Self.meshServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { linkState = .idle; transportNote = error?.localizedDescription ?? "Connection failed." }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeerID == peripheral.identifier { connectedPeerID = nil }
        resetTransport(); linkState = .idle
        if let i = peers.firstIndex(where: { $0.id == peripheral.identifier }) { peers[i].connected = false }
        transportNote = error?.localizedDescription ?? "Meshtastic radio disconnected."
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { transportNote = error.localizedDescription; return }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.meshServiceUUID }) else { transportNote = "Meshtastic service missing after connect."; return }
        peripheral.discoverCharacteristics([Self.fromRadioUUID, Self.toRadioUUID, Self.fromNumUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { transportNote = error.localizedDescription; return }
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case Self.fromRadioUUID: fromRadio = characteristic
            case Self.toRadioUUID: toRadio = characteristic
            case Self.fromNumUUID: fromNum = characteristic
            default: break
            }
        }
        guard fromRadio != nil, toRadio != nil, fromNum != nil else { transportNote = "Meshtastic PhoneAPI characteristics incomplete."; return }
        peripheral.setNotifyValue(true, for: fromNum!)
        linkState = .syncing
        transportNote = "PhoneAPI BLE transport ready. Waiting for config handshake…"
        sendWantConfig(handshakeNonce, peripheral: peripheral)
        drainFromRadio(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { transportNote = error.localizedDescription; return }
        if characteristic.uuid == Self.fromNumUUID { drainFromRadio(peripheral); return }
        if characteristic.uuid == Self.fromRadioUUID {
            let data = characteristic.value ?? Data()
            guard !data.isEmpty else { return }
            receivedEnvelopeCount += 1; lastRawEnvelopeSize = data.count
            do {
                for event in try MeshtasticCodec.decode(data) {
                    decodedCount += 1
                    process(event)
                    latestEvent = EventDelivery(value: event)
                }
            } catch {
                decodeFailures += 1
                transportNote = "Rejected malformed PhoneAPI frame (\(decodeFailures) errors)."
            }
            // Reading advances FromRadio's FIFO; continue until the radio returns empty.
            drainFromRadio(peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.toRadioUUID else { return }
        if let packetID = activePacketID {
            activePacketID = nil
            if let error {
                latestReceipt = RadioReceipt(packetID: packetID, kind: .failed(error.localizedDescription))
                transportNote = "BLE write failed: \(error.localizedDescription)"
            } else {
                latestReceipt = RadioReceipt(packetID: packetID, kind: .accepted)
                transportNote = "Packet written to radio; mesh delivery unconfirmed."
            }
        } else if let error { transportNote = "Configuration write failed: \(error.localizedDescription)" }
    }

    private func resetTransport() {
        if let packetID = activePacketID {
            latestReceipt = RadioReceipt(packetID: packetID, kind: .failed("Radio disconnected before BLE write confirmation"))
        }
        activePacketID = nil; fromRadio = nil; toRadio = nil; fromNum = nil
    }

    private func process(_ event: MeshtasticCodec.Event) {
        switch event {
        case .configComplete(let id):
            if id == handshakeNonce { linkState = .connected; transportNote = "Meshtastic config synced. Text and position decoding active." }
        case .position(let node, let lat, let lon, let altitude):
            var item = meshNodes.first(where: { $0.id == node }) ?? MeshNode(id: node, name: String(format: "!%08X", node))
            item.location = RoutePoint(latitude: lat, longitude: lon, elevation: altitude.map(Double.init))
            item.lastHeard = .now
            upsertNode(item)
        case .nodeName(let node, let name):
            var item = meshNodes.first(where: { $0.id == node }) ?? MeshNode(id: node, name: name)
            item.name = name; item.lastHeard = .now; upsertNode(item)
        case .deviceMetrics(let node, let battery, let voltage, let channel, let airtime):
            var item = meshNodes.first(where: { $0.id == node }) ?? MeshNode(id: node, name: String(format: "!%08X", node))
            item.batteryPercent = battery; item.voltage = voltage
            item.channelUtilization = channel; item.airtimeUtilization = airtime
            item.lastHeard = .now; upsertNode(item)
        case .environmentMetrics(let node, let temperature, let humidity, let pressure):
            var item = meshNodes.first(where: { $0.id == node }) ?? MeshNode(id: node, name: String(format: "!%08X", node))
            item.temperatureC = temperature; item.humidity = humidity; item.pressureHPa = pressure
            item.lastHeard = .now; upsertNode(item)
        case .text(let sender, let id, _, _):
            let key = "\(sender):\(id)"
            if id != 0 {
                if recentPackets.contains(key) { return }
                recentPackets.append(key)
                if recentPackets.count > 300 { recentPackets.removeFirst(recentPackets.count-300) }
            }
        case .queueResult(let id, let error):
            if error != 0 { latestReceipt = RadioReceipt(packetID: id, kind: .failed("Radio queue error \(error)")) }
        case .routingResult(let id, let error):
            if error == 0 { latestReceipt = RadioReceipt(packetID: id, kind: .routingAcknowledged) }
            else { latestReceipt = RadioReceipt(packetID: id, kind: .failed("Routing error \(error)")) }
        }
    }
    private func upsertNode(_ item: MeshNode) {
        if let i = meshNodes.firstIndex(where: { $0.id == item.id }) { meshNodes[i] = item }
        else { meshNodes.append(item) }
    }

    private func drainFromRadio(_ peripheral: CBPeripheral) { if let fromRadio { peripheral.readValue(for: fromRadio) } }

    private func sendWantConfig(_ nonce: UInt32, peripheral: CBPeripheral) {
        guard let toRadio else { return }
        peripheral.writeValue(MeshtasticCodec.wantConfig(nonce), for: toRadio, type: .withResponse)
    }
}
