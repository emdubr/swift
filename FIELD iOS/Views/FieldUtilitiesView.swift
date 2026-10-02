import SwiftUI

struct FieldUtilitiesView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @State private var targetLat = ""
    @State private var targetLon = ""

    var body: some View {
        List {
            Section("Current position") {
                if let fix = location.location {
                    LabeledContent("Decimal", value: String(format: "%.6f, %.6f", fix.coordinate.latitude, fix.coordinate.longitude))
                    LabeledContent("DMS", value: dms(fix.coordinate.latitude, latitude: true) + "  " + dms(fix.coordinate.longitude, latitude: false))
                    LabeledContent("Accuracy", value: fix.horizontalAccuracy >= 0 ? String(format: "±%.0f m", fix.horizontalAccuracy) : "—")
                    Button("Save Timestamped Position Mark") {
                        state.log("MARK", "Timestamped position mark", point: RoutePoint(location: fix))
                    }
                } else { Text("Waiting for a GPS fix.").foregroundStyle(.secondary) }
            }
            Section("Point distance / bearing") {
                TextField("Target latitude", text: $targetLat).keyboardType(.numbersAndPunctuation)
                TextField("Target longitude", text: $targetLon).keyboardType(.numbersAndPunctuation)
                if let result = calculation {
                    LabeledContent("Distance", value: result.distance < 1609.344 ? String(format: "%.0f m", result.distance) : String(format: "%.2f mi", result.distance / 1609.344))
                    LabeledContent("Bearing", value: String(format: "%.0f° %@", result.bearing, RouteEngine.cardinal(result.bearing)))
                }
            }
            Section("Location card") {
                if let fix = location.location {
                    let text = String(format: "FIELD/OS POSITION\n%.6f, %.6f\nALT %.0f m\nACC ±%.0f m\n%@", fix.coordinate.latitude, fix.coordinate.longitude, fix.altitude, max(0, fix.horizontalAccuracy), Date().formatted())
                    Text(text).font(.caption.monospaced()).textSelection(.enabled)
                    ShareLink(item: text) { Label("Share Location Card", systemImage: "square.and.arrow.up") }
                }
            }
            Section("Scratchpad") {
                TextEditor(text: $state.scratchpad).frame(minHeight: 120)
                Button("Save Offline Scratchpad") { state.persist() }
            }
        }.navigationTitle("Field Utilities")
    }

    private var calculation: (distance: Double, bearing: Double)? {
        guard let fix = location.location, let lat = Double(targetLat), let lon = Double(targetLon), abs(lat) <= 90, abs(lon) <= 180 else { return nil }
        let a = RoutePoint(location: fix), b = RoutePoint(latitude: lat, longitude: lon)
        return (RouteEngine.distanceMeters(a, b), RouteEngine.bearingDegrees(from: a, to: b))
    }

    private func dms(_ value: Double, latitude: Bool) -> String {
        let absolute = abs(value), degrees = Int(absolute), minutesFloat = (absolute - Double(degrees)) * 60, minutes = Int(minutesFloat), seconds = (minutesFloat - Double(minutes)) * 60
        let hemi = latitude ? (value >= 0 ? "N" : "S") : (value >= 0 ? "E" : "W")
        return String(format: "%d° %d′ %.1f″ %@", degrees, minutes, seconds, hemi)
    }
}
