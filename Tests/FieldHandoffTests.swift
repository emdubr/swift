import Foundation

@main struct FieldHandoffTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let recent = FieldHandoff.Fix(latitude: 44.4759, longitude: -73.2121, accuracyMeters: 7,
                                      obtainedAt: now.addingTimeInterval(-50))
        let message = FieldHandoff.message(fix: recent, now: now, purpose: "SOS", note: "Blue tent")
        assert(message.contains("ASSISTANCE REQUESTED") && message.contains("44.475900"))
        assert(message.contains("POSITION RECENT") && message.contains("NOT TRANSMITTED") == false)
        assert(message.contains("NO MESSAGE HAS BEEN TRANSMITTED"))
        let stale = FieldHandoff.Fix(latitude: 44.4759, longitude: -73.2121, accuracyMeters: 7,
                                     obtainedAt: now.addingTimeInterval(-1_000))
        assert(FieldHandoff.message(fix: stale, now: now).contains("POSITION STALE"))
        let broken = FieldHandoff.Fix(latitude: 999, longitude: 2, accuracyMeters: -1, obtainedAt: now)
        assert(FieldHandoff.message(fix: broken, now: now).contains("POSITION UNKNOWN"))
        assert(FieldHandoff.message(fix: nil, now: now, purpose: "CHECK-IN").contains("CHECK-IN"))
        print("PASS: manual check-in/SOS formatting, recent/stale/invalid GPS distinction, no fake delivery")
    }
}
