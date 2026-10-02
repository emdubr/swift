import Foundation

// Minimal, bounded PhoneAPI subset. Wire fields follow meshtastic/protobufs/meshtastic/mesh.proto.
// Unknown fields are skipped; never interpret encrypted payloads as plaintext.
// This is NOT an implementation of administration, encryption, channels or satellite transport.
enum MeshtasticCodec {
    enum CodecError: Error, Equatable { case malformed, oversized, invalidText }
    enum Event: Equatable {
        case text(sender: UInt32, packetID: UInt32, channel: UInt32, value: String)
        case position(node: UInt32, latitude: Double, longitude: Double, altitude: Int?)
        case nodeName(node: UInt32, value: String)
        case deviceMetrics(node: UInt32, batteryPercent: UInt32?, voltage: Float?, channelPercent: Float?, airtimePercent: Float?)
        case environmentMetrics(node: UInt32, temperatureC: Float?, humidityPercent: Float?, pressureHPa: Float?)
        case configComplete(UInt32)
        case queueResult(packetID: UInt32, error: Int32)
        case routingResult(packetID: UInt32, error: Int32)
    }
    private enum WireValue { case varint(UInt64), bytes(Data), fixed32(UInt32), fixed64(UInt64) }
    private struct Field { let number: Int; let value: WireValue }

    // Limit both overall frames and individual fields so corrupt radio bytes don't blow memory.
    private static func fields(_ data: Data) throws -> [Field] {
        guard data.count <= 65_536 else { throw CodecError.oversized }
        let bytes = [UInt8](data); var i = 0; var result: [Field] = []
        func varint() throws -> UInt64 {
            var result: UInt64 = 0
            for n in 0..<10 {
                guard i < bytes.count else { throw CodecError.malformed }
                let byte = bytes[i]; i += 1
                if n == 9 && byte > 1 { throw CodecError.malformed }
                result |= UInt64(byte & 0x7f) << (n * 7)
                if byte & 0x80 == 0 { return result }
            }
            throw CodecError.malformed
        }
        while i < bytes.count {
            let key = try varint(); let number = Int(key >> 3); let wire = key & 7
            guard number > 0, number <= 536_870_911, result.count < 2048 else { throw CodecError.malformed }
            let value: WireValue
            switch wire {
            case 0: value = .varint(try varint())
            case 1:
                guard bytes.count - i >= 8 else { throw CodecError.malformed }
                var v: UInt64 = 0
                for n in 0..<8 { v |= UInt64(bytes[i+n]) << (8*n) }; i += 8
                value = .fixed64(v)
            case 2:
                let rawCount = try varint()
                guard rawCount <= UInt64(bytes.count - i) else { throw CodecError.malformed }
                let size = Int(rawCount)
                value = .bytes(Data(bytes[i..<(i+size)])); i += size
            case 5:
                guard bytes.count - i >= 4 else { throw CodecError.malformed }
                var v: UInt32 = 0
                for n in 0..<4 { v |= UInt32(bytes[i+n]) << (8*n) }; i += 4
                value = .fixed32(v)
            default: throw CodecError.malformed
            }
            result.append(Field(number: number, value: value))
        }
        return result
    }
    private static func unsigned(_ data: [Field], _ key: Int) -> UInt64? {
        for f in data.reversed() where f.number == key { if case .varint(let v) = f.value { return v } }
        return nil
    }
    private static func fixed(_ data: [Field], _ key: Int) -> UInt32? {
        for f in data.reversed() where f.number == key { if case .fixed32(let v) = f.value { return v } }
        return nil
    }
    private static func float32(_ data: [Field], _ key: Int) -> Float? {
        guard let bits = fixed(data, key) else { return nil }
        let value = Float(bitPattern: bits)
        return value.isFinite ? value : nil
    }
    private static func telemetry(_ raw: Data, node: UInt32) throws -> [Event] {
        let t = try fields(raw)
        var events: [Event] = []
        if let device = blob(t, 2) {
            let m = try fields(device)
            let level = unsigned(m, 1).flatMap { $0 <= 255 ? UInt32($0) : nil }
            let voltage = float32(m, 2).flatMap { (0...30).contains($0) ? $0 : nil }
            let channel = float32(m, 3).flatMap { (0...100).contains($0) ? $0 : nil }
            let airtime = float32(m, 4).flatMap { (0...100).contains($0) ? $0 : nil }
            if level != nil || voltage != nil || channel != nil || airtime != nil {
                events.append(.deviceMetrics(node: node, batteryPercent: level,
                                             voltage: voltage, channelPercent: channel, airtimePercent: airtime))
            }
        }
        if let environment = blob(t, 3) {
            let m = try fields(environment)
            let temperature = float32(m, 1).flatMap { (-100...100).contains($0) ? $0 : nil }
            let humidity = float32(m, 2).flatMap { (0...100).contains($0) ? $0 : nil }
            let pressure = float32(m, 3).flatMap { (300...1200).contains($0) ? $0 : nil }
            if temperature != nil || humidity != nil || pressure != nil {
                events.append(.environmentMetrics(node: node, temperatureC: temperature,
                                                  humidityPercent: humidity, pressureHPa: pressure))
            }
        }
        return events
    }
    private static func blob(_ data: [Field], _ key: Int) -> Data? {
        for f in data.reversed() where f.number == key { if case .bytes(let v) = f.value { return v } }
        return nil
    }
    private static func position(_ raw: Data, node: UInt32) throws -> Event? {
        let p = try fields(raw)
        guard let lat = fixed(p, 1), let lon = fixed(p, 2) else { return nil }
        let latitude = Double(Int32(bitPattern: lat)) * 1e-7
        let longitude = Double(Int32(bitPattern: lon)) * 1e-7
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        let altitude = unsigned(p, 3).map { Int(Int32(bitPattern: UInt32(truncatingIfNeeded: $0))) }
        return .position(node: node, latitude: latitude, longitude: longitude, altitude: altitude)
    }
    private static func name(_ fields: [Field]) -> String? {
        guard let raw = blob(fields, 2), raw.count <= 256 else { return nil }
        return String(data: raw, encoding: .utf8)
    }
    // The output is a *subset* of messages we understand. Silently skip unknown events.
    static func decode(_ envelope: Data) throws -> [Event] {
        let radio = try fields(envelope); var events: [Event] = []
        for f in radio {
            switch (f.number, f.value) {
            case (2, .bytes(let raw)):
                let packet = try fields(raw)
                let from = fixed(packet, 1) ?? 0
                let packetID = fixed(packet, 6) ?? 0
                let channel = UInt32(unsigned(packet, 3) ?? 0)
                guard let decoded = blob(packet, 4) else { continue }
                let application = try fields(decoded)
                let port = unsigned(application, 1) ?? 0
                let payload = blob(application, 2) ?? Data()
                switch port {
                case 1:
                    guard payload.count <= 240, let message = String(data: payload, encoding: .utf8) else { continue }
                    events.append(.text(sender: from, packetID: packetID, channel: channel, value: message))
                case 3:
                    if let event = try position(payload, node: from) { events.append(event) }
                case 4:
                    if let nodeName = name(try fields(payload)) { events.append(.nodeName(node: from, value: nodeName)) }
                case 67:
                    events.append(contentsOf: try telemetry(payload, node: from))
                case 5:
                    // Routing.error_reason=3 and Data.request_id=6 (fixed32). A routing ACK
                    // is not equivalent to proof of end-to-end message delivery.
                    if let request = fixed(application, 6), request != 0 {
                        let routing = try fields(payload)
                        let error = Int32(truncatingIfNeeded: unsigned(routing, 3) ?? 0)
                        events.append(.routingResult(packetID: request, error: error))
                    }
                default: break
                }
            case (4, .bytes(let raw)):
                // NodeInfo.num=1, NodeInfo.user=2. Ignore node entries without a name.
                let info = try fields(raw)
                if let num = unsigned(info, 1) {
                    let node = UInt32(truncatingIfNeeded: num)
                    if let user = blob(info, 2), let nodeName = name(try fields(user)) {
                        events.append(.nodeName(node: node, value: nodeName))
                    }
                    if let pos = blob(info, 3), let event = try position(pos, node: node) { events.append(event) }
                }
            case (7, .varint(let nonce)):
                events.append(.configComplete(UInt32(truncatingIfNeeded: nonce)))
            case (11, .bytes(let raw)):
                let queue = try fields(raw)
                if let id = unsigned(queue, 4) {
                    let error = Int32(truncatingIfNeeded: unsigned(queue, 1) ?? 0)
                    events.append(.queueResult(packetID: UInt32(truncatingIfNeeded: id), error: error))
                }
            default: break
            }
        }
        return events
    }
    private static func varint(_ input: UInt64) -> Data {
        var value = input; var out = Data()
        repeat { var octet = UInt8(value & 127); value >>= 7; if value > 0 { octet |= 128 }; out.append(octet) } while value > 0
        return out
    }
    private static func tag(_ number: Int, _ wire: Int) -> Data { varint(UInt64(number * 8 + wire)) }
    private static func field(_ number: Int, _ value: UInt64) -> Data { var result = tag(number, 0); result.append(varint(value)); return result }
    private static func field(_ number: Int, bytes: Data) -> Data {
        var result = tag(number, 2); result.append(varint(UInt64(bytes.count))); result.append(bytes); return result
    }
    private static func fixedField(_ number: Int, _ value: UInt32) -> Data {
        var result = tag(number, 5); for i in 0..<4 { result.append(UInt8((value >> (8*i)) & 255)) }; return result
    }
    static func wantConfig(_ nonce: UInt32) -> Data { field(3, UInt64(nonce)) }
    static func textPacket(_ message: String, packetID: UInt32, channel: UInt32 = 0,
                           destination: UInt32 = .max) throws -> Data {
        let bytes = Data(message.utf8)
        guard !bytes.isEmpty, bytes.count <= 200, packetID != 0 else { throw CodecError.invalidText }
        var application = field(1, 1) // PortNum.TEXT_MESSAGE_APP
        application.append(field(2, bytes: bytes))
        var packet = fixedField(2, destination) // 0xFFFFFFFF broadcasts on the channel
        if channel != 0 { packet.append(field(3, UInt64(channel))) }
        packet.append(field(4, bytes: application))
        packet.append(fixedField(6, packetID))
        packet.append(field(9, 3)) // hop limit
        if destination != UInt32.max { packet.append(field(10, 1)) } // request routing ACK for direct sends
        return field(1, bytes: packet) // ToRadio.packet
    }
}
