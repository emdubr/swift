import Foundation
@main struct MessageMigrationTests {
    static func main() throws {
        let decoder = JSONDecoder()
        let original = try decoder.decode(FieldMessage.self, from: Data(#"{"text":"legacy message","status":"queued"}"#.utf8))
        assert(original.text == "legacy message" && original.status == .queued)
        assert(original.destination == nil && original.packetID == nil)
        let modern = FieldMessage(channel: "PRIMARY", text: "direct message", packetID: 23,
                                  destination: 0x12345678, lastError: "test")
        let restored = try decoder.decode(FieldMessage.self, from: JSONEncoder().encode(modern))
        assert(restored == modern && restored.destination == 0x12345678)
        assert(MessageStatus.radioAccepted.label.contains("UNCONFIRMED"))
        print("PASS: old message JSON migration, direct-target roundtrip, unverified delivery label")
    }
}
