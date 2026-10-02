import SwiftUI

struct FieldNavigationView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                compassPanel
                positionPanel
                nextRoutePanel
            }.padding(14)
        }.background(FieldTheme.background).navigationTitle("Navigation")
    }

    private var compassPanel: some View {
        VStack(spacing: 10) {
            FieldHeader(title: "Compass", subtitle: location.heading == nil ? "NO HEADING" : "DEVICE")
            ZStack {
                Circle().stroke(FieldTheme.border, lineWidth: 2)
                ForEach(0..<12, id: \.self) { i in
                    Rectangle().fill(FieldTheme.dim).frame(width: 2, height: i % 3 == 0 ? 14 : 8)
                        .offset(y: -92).rotationEffect(.degrees(Double(i) * 30))
                }
                Text("N").offset(y: -68).foregroundStyle(FieldTheme.accent).font(.headline.bold())
                Image(systemName: "location.north.fill")
                    .font(.system(size: 74)).foregroundStyle(FieldTheme.accent)
                    .rotationEffect(.degrees(-(location.heading?.trueHeading ?? location.heading?.magneticHeading ?? 0)))
            }.frame(width: 210, height: 210)
            Text(headingText).font(.title2.bold().monospaced()).foregroundStyle(FieldTheme.text)
        }.fieldPanel()
    }

    private var positionPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldHeader(title: "Position")
            if let loc = location.location {
                HStack(spacing: 8) {
                    MetricTile(label: "Latitude", value: String(format: "%.5f", loc.coordinate.latitude))
                    MetricTile(label: "Longitude", value: String(format: "%.5f", loc.coordinate.longitude))
                }
                HStack(spacing: 8) {
                    MetricTile(label: "Accuracy", value: String(format: "±%.0fm", loc.horizontalAccuracy))
                    MetricTile(label: "Altitude", value: String(format: "%.0fft", loc.altitude * 3.28084))
                    MetricTile(label: "Speed", value: loc.speed >= 0 ? String(format: "%.1f mph", loc.speed * 2.23694) : "--")
                }
            } else { Text("Waiting for a location fix.").foregroundStyle(FieldTheme.dim) }
        }.fieldPanel()
    }

    private var nextRoutePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldHeader(title: "Route guidance")
            if let route = state.activeRoute, let current = location.location, let nearest = RouteEngine.nearestPoint(on: route, to: current) {
                HStack(spacing: 8) {
                    MetricTile(label: "Off route", value: String(format: "%.0f ft", nearest.distanceMeters * 3.28084), tone: nearest.distanceMeters > 80 ? FieldTheme.amber : FieldTheme.accent)
                    MetricTile(label: "Intercept", value: "LEG \(nearest.segmentIndex + 1)")
                    MetricTile(label: "Bearing", value: String(format: "%.0f° %@", nearest.bearingDegrees, RouteEngine.cardinal(nearest.bearingDegrees)))
                }
            } else { Text("Activate a route for trail-intercept guidance.").foregroundStyle(FieldTheme.dim) }
        }.fieldPanel()
    }

    private var headingText: String {
        guard let h = location.heading else { return "---°" }
        let v = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        return String(format: "%.0f° %@", v, RouteEngine.cardinal(v))
    }
}
