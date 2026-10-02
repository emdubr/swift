import Foundation

// Transport-neutral operator handoff text. No satellite claim or background delivery.
// This is intentionally safe to copy into an external communicator's own app.
enum FieldHandoff {
    struct Fix: Equatable {
        let latitude: Double
        let longitude: Double
        let accuracyMeters: Double
        let obtainedAt: Date
        var valid: Bool {
            latitude.isFinite && longitude.isFinite && accuracyMeters.isFinite &&
            (-90...90).contains(latitude) && (-180...180).contains(longitude) && accuracyMeters >= 0
        }
    }
    static func message(fix: Fix?, now: Date = .now, purpose: String = "CHECK-IN", note: String = "") -> String {
        let kind = purpose == "SOS" ? "SOS / ASSISTANCE REQUESTED" : "FIELD CHECK-IN"
        var lines = ["FIELD/OS // \(kind)",
                     "TIME UTC: \(ISO8601DateFormatter().string(from: now))"]
        if let fix, fix.valid {
            let age = now.timeIntervalSince(fix.obtainedAt)
            if age < -30 || age > 300 {
                lines.append("POSITION STALE / DO NOT ASSUME CURRENT")
            } else { lines.append("POSITION RECENT (<5 MIN); NOT INDEPENDENTLY VERIFIED") }
            lines.append(String(format: "WGS84: %.6f, %.6f; GPS ±%.0f m", fix.latitude, fix.longitude, fix.accuracyMeters))
            lines.append("GPS FIX UTC: \(ISO8601DateFormatter().string(from: fix.obtainedAt))")
        } else {
            lines.append("POSITION UNKNOWN — SEND YOUR VERIFIED POSITION")
        }
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty { lines.append("NOTE: " + String(normalized.prefix(300))) }
        lines.append("MANUAL HANDOFF ONLY; NO MESSAGE HAS BEEN TRANSMITTED BY FIELD/OS")
        return lines.joined(separator: "\n")
    }
}
