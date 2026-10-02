import CoreBluetooth
import Foundation

// Configurable read-only GATT instrumentation for custom TAP V2 peripheral firmware.
// This receives RAW characteristic frames; an independently specified firmware protocol
// is required before any received bytes can be presented as trusted measurements.
@MainActor
final class PeripheralBridgeService: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum BridgeState: String { case idle = "IDLE", scanning = "SCANNING", connecting = "CONNECTING", connected = "CONNECTED", unavailable = "UNAVAILABLE", error = "ERROR" }
    @Published private(set) var state: BridgeState = .idle
    @Published private(set) var note = "Enter your device's documented service and notification UUIDs."
    struct Device: Identifiable {
        let id: UUID
        let name: String
        let rssi: Int
    }
    @Published private(set) var discovered: [Device] = []
    @Published private(set) var receivedFrames = 0
    @Published private(set) var lastFrameHex = "—"
    @Published private(set) var lastFrameAt: Date?
    @Published private(set) var lastFrameLength = 0
    // Only create a BLE manager after the hardware diagnostics screen requests a scan.
    private var central: CBCentralManager?
    private var wantsScan = false
    private var expectedService: CBUUID?
    private var expectedCharacteristic: CBUUID?
    private var devices: [UUID: CBPeripheral] = [:]
    private var active: CBPeripheral?

    override init() { super.init() }

    private func ensureCentral() -> CBCentralManager {
        if let central { return central }
        let instance = CBCentralManager(delegate: self, queue: nil)
        central = instance
        return instance
    }

    private func beginScan(using manager: CBCentralManager) {
        guard wantsScan, manager.state == .poweredOn, let expectedService else { return }
        devices = [:]; discovered = []; state = .scanning
        manager.scanForPeripherals(withServices: [expectedService],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        note = "Scanning only for configured service…"
    }

    static func valid128(_ value: String) -> Bool { UUID(uuidString: value.trimmingCharacters(in: .whitespacesAndNewlines)) != nil }

    func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        if manager.state == .poweredOn {
            if wantsScan { beginScan(using: manager) }
            else if state == .unavailable { state = .idle; note = "Ready for configured GATT service scan" }
        } else if manager.state == .poweredOff || manager.state == .unauthorized || manager.state == .unsupported {
            state = .unavailable
            note = "Bluetooth is unavailable. Enable it and rescan."
        }
    }
    func scan(service: String, notificationCharacteristic: String) {
        guard Self.valid128(service), Self.valid128(notificationCharacteristic) else {
            state = .error; note = "Enter exact 128-bit UUIDs from device firmware documentation."; return
        }
        expectedService = CBUUID(string: service)
        expectedCharacteristic = CBUUID(string: notificationCharacteristic)
        wantsScan = true
        let manager = ensureCentral()
        if manager.state == .poweredOn { beginScan(using: manager) }
        else { state = .idle; note = "Initializing Bluetooth; scan starts when it is ready." }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard let self, self.wantsScan else { return }
            self.stopScan()
        }
    }
    func stopScan() {
        wantsScan = false
        central?.stopScan()
        if state == .scanning { state = .idle }
    }
    func connect(_ id: UUID) {
        guard let peripheral = devices[id], let central else { return }
        stopScan(); active = peripheral; peripheral.delegate = self
        state = .connecting
        central.connect(peripheral)
    }
    func disconnect() { if let active { central?.cancelPeripheralConnection(active) } }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        devices[peripheral.identifier] = peripheral
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unnamed BLE device"
        let row = Device(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let i = discovered.firstIndex(where: { $0.id == row.id }) { discovered[i] = row }
        else { discovered.append(row) }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        state = .connecting; note = "Discovering configured characteristics…"
        if let expectedService { peripheral.discoverServices([expectedService]) }
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .error; note = error?.localizedDescription ?? "GATT connection failed"
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if active?.identifier == peripheral.identifier { active = nil; state = .idle }
        note = error?.localizedDescription ?? "Peripheral disconnected"
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { state = .error; note = error.localizedDescription; return }
        guard let service = peripheral.services?.first(where: { $0.uuid == expectedService }),
              let expectedCharacteristic else { state = .error; note = "Configured service not found"; return }
        peripheral.discoverCharacteristics([expectedCharacteristic], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { state = .error; note = error.localizedDescription; return }
        guard let ch = service.characteristics?.first(where: { $0.uuid == expectedCharacteristic }) else {
            state = .error; note = "Notification characteristic not found"; return
        }
        guard ch.properties.contains(.notify) || ch.properties.contains(.indicate) else {
            state = .error; note = "Characteristic has no notify/indicate property"; return
        }
        peripheral.setNotifyValue(true, for: ch)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error { state = .error; note = error.localizedDescription; return }
        if characteristic.isNotifying {
            state = .connected; note = "Receiving RAW GATT bytes only. No sensor protocol has been verified."
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { note = error.localizedDescription; return }
        guard characteristic.uuid == expectedCharacteristic, let data = characteristic.value else { return }
        receivedFrames += 1
        lastFrameAt = .now
        lastFrameLength = data.count
        lastFrameHex = data.prefix(128).map { String(format: "%02X", $0) }.joined(separator: " ") + (data.count > 128 ? " …" : "")
    }
}
