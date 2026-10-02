import SwiftUI

struct ReturnFunctionsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                routeMonitor
                returnToTrail
                returnToBase
                bailoutPanel
                breadcrumbInfo
            }.padding(14)
        }.background(FieldTheme.background).navigationTitle("Return Functions")
    }

    private var routeMonitor: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldHeader(title: "Route watch")
            if let route = state.activeRoute, let current = location.location, let progress = RouteEngine.progress(on: route, from: current) {
                let offFeet = progress.nearest.distanceMeters * 3.28084
                HStack(spacing: 8) {
                    MetricTile(label: "PROGRESS", value: String(format: "%.0f%%", progress.progressFraction * 100))
                    MetricTile(label: "REMAIN", value: String(format: "%.2f mi", progress.remainingMeters / 1609.344))
                    MetricTile(label: "ETA", value: progress.estimatedRemainingSeconds.fieldDuration)
                }
                HStack {
                    Text(offFeet > 300 ? "ROUTE DEVIATION" : offFeet > 100 ? "OFF ROUTE" : "ON ROUTE")
                        .font(.caption.bold().monospaced())
                        .foregroundStyle(offFeet > 100 ? FieldTheme.amber : FieldTheme.accent)
                    Spacer()
                    Text(offFeet < 528 ? "\(Int(offFeet)) ft" : String(format: "%.2f mi", offFeet / 5280)).font(.caption.monospaced())
                }
            } else { Text("A live position and active route are required.").foregroundStyle(FieldTheme.dim) }
        }.fieldPanel()
    }

    private var returnToTrail: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldHeader(title: "Return to trail")
            if let route = state.activeRoute, let current = location.location, let nearest = RouteEngine.nearestPoint(on: route, to: current) {
                HStack(spacing: 8) {
                    MetricTile(label: "Distance", value: String(format: "%.2f mi", nearest.distanceMeters / 1609.344))
                    MetricTile(label: "Bearing", value: String(format: "%.0f° %@", nearest.bearingDegrees, RouteEngine.cardinal(nearest.bearingDegrees)))
                    MetricTile(label: "Intercept", value: "LEG \(nearest.segmentIndex + 1)")
                }
                Text("Guidance points to the nearest point on the saved route polyline. It does not assume a safe off-trail path between you and that intercept.")
                    .font(.caption).foregroundStyle(FieldTheme.amber)
            } else { Text("A live position and active route are required.").foregroundStyle(FieldTheme.dim) }
        }.fieldPanel()
    }

    private var returnToBase: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldHeader(title: "Return to base")
            if let current = location.location, let base = basePoint {
                let from = RoutePoint(location: current)
                let d = RouteEngine.distanceMeters(from, base)
                let b = RouteEngine.bearingDegrees(from: from, to: base)
                HStack(spacing: 8) {
                    MetricTile(label: "Distance", value: String(format: "%.2f mi", d / 1609.344))
                    MetricTile(label: "Bearing", value: String(format: "%.0f° %@", b, RouteEngine.cardinal(b)))
                }
                Text("Straight-line bearing only. Follow known safe routes and terrain rather than blindly following the arrow.")
                    .font(.caption).foregroundStyle(FieldTheme.amber)
            } else { Text("Add a Base waypoint or activate a route.").foregroundStyle(FieldTheme.dim) }
        }.fieldPanel()
    }

    private var bailoutPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldHeader(title: "Saved bailout candidates", subtitle: "STRAIGHT-LINE SCREENING")
            if let current = location.location {
                let candidates = RouteEngine.bailoutCandidates(from: current, waypoints: state.waypoints)
                if candidates.isEmpty { Text("Save Base, Camp, Junction, or Bailout waypoints to build a local exit list.").font(.footnote).foregroundStyle(FieldTheme.dim) }
                ForEach(candidates) { candidate in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.waypoint.name).font(.caption.bold().monospaced())
                            Text(candidate.waypoint.kind.rawValue.uppercased()).font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.2f mi", candidate.distanceMeters / 1609.344)).font(.caption.bold().monospaced())
                            Text(String(format: "%.0f° %@", candidate.bearingDegrees, RouteEngine.cardinal(candidate.bearingDegrees))).font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim)
                        }
                    }
                    Divider().opacity(0.25)
                }
                Text("Ranking is geometric only and does not confirm route access, terrain passability, road status, or current conditions.").font(.caption2).foregroundStyle(FieldTheme.amber)
            } else { Text("Acquire a GPS fix to rank saved exits.").font(.footnote).foregroundStyle(FieldTheme.dim) }
        }.fieldPanel()
    }

    private var breadcrumbInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldHeader(title: "Breadcrumb")
            Text("Use Track Recorder before leaving the trailhead. A recorded track can be saved as a route and followed back even when the original route is unavailable.")
                .font(.footnote).foregroundStyle(FieldTheme.dim)
        }.fieldPanel()
    }

    private var basePoint: RoutePoint? {
        state.waypoints.first(where: { $0.kind == .base })?.point ?? state.activeRoute?.points.first
    }
}
