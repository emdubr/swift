import CoreLocation
import SwiftUI

struct NavigationCenterView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var sensor: SensorService
    @EnvironmentObject private var checkIns: CheckInService

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                compassPanel
                returnPanel
                daylightPanel
                checkInPanel
            }.padding(14)
        }
        .background(FieldTheme.background)
        .navigationTitle("Navigation")
        .task { await checkIns.refreshAuthorization() }
    }

    private var compassPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldHeader(title: "Navigation core", subtitle: location.location == nil ? "SEARCHING" : "LIVE")
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(FieldTheme.border, lineWidth: 2)
                    ForEach(0..<12, id: \.self) { tick in
                        Capsule().fill(tick % 3 == 0 ? FieldTheme.accent : FieldTheme.dim)
                            .frame(width: 2, height: tick % 3 == 0 ? 14 : 8)
                            .offset(y: -58).rotationEffect(.degrees(Double(tick) * 30))
                    }
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 54)).foregroundStyle(FieldTheme.accent)
                        .rotationEffect(.degrees(-(location.headingDegrees ?? 0)))
                    Text(cardinal).font(.caption.bold().monospaced()).offset(y: 38)
                }.frame(width: 138, height: 138)
                VStack(alignment: .leading, spacing: 9) {
                    MetricLine(label: "HEADING", value: location.headingDegrees.map { String(format: "%03.0f°", $0) } ?? "---")
                    MetricLine(label: "SPEED", value: location.speedMPH.map { String(format: "%.1f mph", $0) } ?? "--")
                    MetricLine(label: "ALT", value: location.location.map { "\(Int($0.altitude * 3.28084)) ft" } ?? "--")
                    MetricLine(label: "ACC", value: location.location.map { "±\(Int(max(0,$0.horizontalAccuracy)))m" } ?? "--")
                }
            }
        }.fieldPanel()
    }

    private var returnPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldHeader(title: "Route recovery")
            if let current = location.location, let route = state.activeRoute, let result = RouteEngine.nearestPoint(on: route, to: current) {
                HStack(spacing: 8) {
                    MetricTile(label: "To route", value: String(format: "%.2f mi", result.distanceMeters / 1609.344))
                    MetricTile(label: "Bearing", value: String(format: "%03.0f°", result.bearingDegrees))
                }
            } else { Text("A live fix and active route are required.").font(.footnote).foregroundStyle(FieldTheme.dim) }
            NavigationLink("OPEN RETURN FUNCTIONS", value: AppModule.returnFunctions).buttonStyle(TerminalButtonStyle())
        }.fieldPanel()
    }

    private var daylightPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldHeader(title: "Daylight", subtitle: "LOCAL SOLAR CALC")
            if let coordinate = location.location?.coordinate {
                let window = SunService.window(for: coordinate)
                HStack(spacing: 8) {
                    MetricTile(label: "Sunrise", value: window.sunrise?.formatted(date: .omitted, time: .shortened) ?? "--")
                    MetricTile(label: "Sunset", value: window.sunset?.formatted(date: .omitted, time: .shortened) ?? "--")
                }
                Text(daylightText(window)).font(.caption.monospaced()).foregroundStyle(FieldTheme.amber)
            } else { Text("Waiting for location.").font(.footnote).foregroundStyle(FieldTheme.dim) }
        }.fieldPanel()
    }

    private var checkInPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldHeader(title: "Check-in", subtitle: checkIns.nextDue?.formatted(date: .omitted, time: .shortened) ?? "NOT ARMED")
            Text("Uses an iPhone local notification. Delivery over mesh/satellite remains separate and is never assumed.").font(.caption).foregroundStyle(FieldTheme.dim)
            HStack {
                Button("ARM \(state.tripPlan.checkInIntervalMinutes) MIN") { Task { await checkIns.schedule(plan: state.tripPlan) } }
                Button("CANCEL") { checkIns.cancel() }
            }.buttonStyle(TerminalButtonStyle())
        }.fieldPanel()
    }

    private var cardinal: String {
        let h = location.headingDegrees ?? 0
        return ["N","NE","E","SE","S","SW","W","NW"][Int((h + 22.5) / 45) % 8]
    }
    private func daylightText(_ window: SolarWindow) -> String {
        guard let sunset = window.sunset else { return "Solar event unavailable for this location/date." }
        if sunset <= .now { return "SUNSET HAS PASSED" }
        let remaining = sunset.timeIntervalSinceNow
        return "DAYLIGHT REMAINING // \(remaining.fieldDuration)"
    }
}

private struct MetricLine: View {
    let label: String; let value: String
    var body: some View { HStack { Text(label).foregroundStyle(FieldTheme.dim); Spacer(); Text(value).foregroundStyle(FieldTheme.text) }.font(.caption.bold().monospaced()) }
}
