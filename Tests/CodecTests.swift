import Foundation

@main struct CodecTests {
    static func main() throws {
        func tryResult(_ data: Data) -> MeshtasticCodec.Event? { try? MeshtasticCodec.decode(data).first }
        func vi(_ n: UInt64) -> Data { var n=n; var d=Data(); repeat { var b=UInt8(n&127); n >>= 7; if n != 0 { b |= 128 }; d.append(b) } while n != 0; return d }
        func tag(_ id: Int, _ wire: Int) -> Data { vi(UInt64(id*8+wire)) }
        func v(_ id: Int, _ n: UInt64) -> Data { tag(id,0)+vi(n) }
        func b(_ id: Int, _ raw: Data) -> Data { tag(id,2)+vi(UInt64(raw.count))+raw }
        func f(_ id: Int, _ n: UInt32) -> Data { tag(id,5)+Data((0..<4).map { UInt8((n >> (8*$0)) & 255) }) }
        let message = "Trail clear"
        let inner = v(1, 1)+b(2, Data(message.utf8))
        let packet = f(1, 123)+f(6, 567)+b(4,inner)
        let decoded = try MeshtasticCodec.decode(b(2,packet))
        assert(decoded == [.text(sender:123, packetID:567, channel:0, value:message)])
        let pos = f(1, UInt32(bitPattern: Int32(444759000)))+f(2, UInt32(bitPattern: Int32(-732121000)))+v(3, 150)
        let positioned = try MeshtasticCodec.decode(b(2, f(1, 5)+b(4,v(1,3)+b(2,pos))))
        guard case .position(let node, let lat, let lon, let altitude) = positioned[0] else { fatalError("position event") }
        assert(node==5 && abs(lat-44.4759)<0.00001 && abs(lon+73.2121)<0.00001 && altitude==150)
        let handshake = try MeshtasticCodec.decode(v(7,69420)); assert(handshake == [.configComplete(69420)])
        let invalid: [Data] = [Data([0xff]), Data([0x12,0xff]), Data(repeating: 0, count: 65537), Data([0x0e])]
        for d in invalid { do { _ = try MeshtasticCodec.decode(d); fatalError("invalid accepted") } catch MeshtasticCodec.CodecError.malformed {} catch MeshtasticCodec.CodecError.oversized {} }
        let namedNode = b(4, v(1, 7) + b(2, b(2, Data("RIDGE".utf8))) + b(3, pos))
        let nodeEvents = try MeshtasticCodec.decode(namedNode)
        assert(nodeEvents.contains(.nodeName(node: 7, value: "RIDGE")))
        assert(nodeEvents.count == 2)
        let routing = b(2, f(1, 55) + b(4, v(1, 5) + b(2, v(3, 0)) + f(6, 345)))
        assert(tryResult(routing) == .routingResult(packetID: 345, error: 0))
        let failedRouting = b(2, f(1, 55) + b(4, v(1, 5) + b(2, v(3, 1)) + f(6, 345)))
        assert(tryResult(failedRouting) == .routingResult(packetID: 345, error: 1))
        func fl(_ n: Int, _ value: Float) -> Data { f(n, value.bitPattern) }
        let metrics = b(2, f(1, 93) + b(4, v(1, 67) + b(2, b(2,
            v(1, 76) + fl(2, 3.86) + fl(3, 12.5) + fl(4, 3.5)) + b(3,
            fl(1, 12.5) + fl(2, 85) + fl(3, 990.5)))))
        let telemetry = try MeshtasticCodec.decode(metrics)
        assert(telemetry.contains(.deviceMetrics(node: 93, batteryPercent: 76, voltage: 3.86, channelPercent: 12.5, airtimePercent: 3.5)))
        assert(telemetry.contains(.environmentMetrics(node: 93, temperatureC: 12.5, humidityPercent: 85, pressureHPa: 990.5)))
        assert(tryResult(b(11, v(1, 3)+v(4, 345))) == .queueResult(packetID:345, error:3))
        let encodedDirect = try MeshtasticCodec.textPacket("Private", packetID: 222, destination: 0x1234ABCD)
        assert(encodedDirect.range(of: f(2, 0x1234ABCD)) != nil)
        assert(encodedDirect.range(of: v(10, 1)) != nil)
        let encoded = try MeshtasticCodec.textPacket("HELLO",packetID:345)
        assert(encoded.first == 0x0a && encoded.contains(0x22) && !encoded.isEmpty)
        for _ in 0..<10000 { let count = Int.random(in: 0...90); let data=Data((0..<count).map { _ in UInt8.random(in: 0...255) }); _ = try? MeshtasticCodec.decode(data) }
        print("PASS: text, position, NodeInfo, handshake, radio queue/routing receipts (including errors), device/environment telemetry, broadcast/direct encode, corrupt frames, 10,000 fuzz frames")
    }
}
