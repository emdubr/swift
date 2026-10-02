import CoreLocation
import Foundation

struct RouteEngine {
    static func metrics(for route: FieldRoute, paceKPH: Double = 4.4) -> RouteMetrics {
        let points = route.points
        guard points.count >= 2 else { return RouteMetrics() }
        var distance = 0.0
        var ascent = 0.0
        var descent = 0.0
        var maxGrade = 0.0

        for pair in zip(points, points.dropFirst()) {
            let horizontal = distanceMeters(pair.0, pair.1)
            distance += horizontal
            if let a = pair.0.elevation, let b = pair.1.elevation {
                let delta = b - a
                if delta > 0 { ascent += delta } else { descent += abs(delta) }
                if horizontal > 2 {
                    maxGrade = max(maxGrade, abs(delta / horizontal) * 100)
                }
            }
        }

        let baseHours = (distance / 1000) / max(1.0, paceKPH)
        let climbHours = ascent / 600.0
        let terrainMultiplier: Double
        switch route.terrain {
        case .maintained: terrainMultiplier = 1.0
        case .rough: terrainMultiplier = 1.12
        case .offTrail: terrainMultiplier = 1.35
        case .snow: terrainMultiplier = 1.45
        }
        let hours = (baseHours + climbHours) * terrainMultiplier
        let difficulty = classify(distanceMeters: distance, ascentMeters: ascent, maxGrade: maxGrade, terrain: route.terrain)
        return RouteMetrics(distanceMeters: distance,
                            ascentMeters: ascent,
                            descentMeters: descent,
                            maxGradePercent: maxGrade,
                            estimatedSeconds: hours * 3600,
                            difficulty: difficulty)
    }

    static func classify(distanceMeters: Double, ascentMeters: Double, maxGrade: Double, terrain: TerrainType) -> RouteDifficulty {
        var score = 0
        if distanceMeters > 8000 { score += 1 }
        if distanceMeters > 16000 { score += 1 }
        if ascentMeters > 600 { score += 1 }
        if ascentMeters > 1200 { score += 1 }
        if maxGrade > 20 { score += 1 }
        if maxGrade > 35 { score += 1 }
        if terrain == .offTrail || terrain == .snow { score += 1 }
        switch score {
        case 0...1: return .easy
        case 2...3: return .moderate
        case 4...5: return .hard
        default: return .extreme
        }
    }

    static func distanceMeters(_ a: RoutePoint, _ b: RoutePoint) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    static func bearingDegrees(from a: RoutePoint, to b: RoutePoint) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let raw = atan2(y, x) * 180 / .pi
        return (raw + 360).truncatingRemainder(dividingBy: 360)
    }

    static func cardinal(_ degrees: Double) -> String {
        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees + 22.5) / 45.0) % 8
        return names[index]
    }

    static func nearestPoint(on route: FieldRoute, to location: CLLocation) -> NearestRouteResult? {
        guard route.points.count >= 2 else { return nil }
        let query = RoutePoint(location: location)
        var best: NearestRouteResult?
        for i in 0..<(route.points.count - 1) {
            let candidate = projectedPoint(query, onto: route.points[i], route.points[i + 1])
            let distance = distanceMeters(query, candidate)
            if best == nil || distance < best!.distanceMeters {
                best = NearestRouteResult(point: candidate,
                                          segmentIndex: i,
                                          distanceMeters: distance,
                                          bearingDegrees: bearingDegrees(from: query, to: candidate))
            }
        }
        return best
    }

    private static func projectedPoint(_ p: RoutePoint, onto a: RoutePoint, _ b: RoutePoint) -> RoutePoint {
        let lat0 = p.latitude * .pi / 180
        let metersPerDegLat = 111_132.92
        let metersPerDegLon = 111_412.84 * cos(lat0)
        func xy(_ q: RoutePoint) -> (Double, Double) {
            ((q.longitude - p.longitude) * metersPerDegLon,
             (q.latitude - p.latitude) * metersPerDegLat)
        }
        let av = xy(a), bv = xy(b)
        let dx = bv.0 - av.0, dy = bv.1 - av.1
        let denom = dx * dx + dy * dy
        let t = denom > 0 ? max(0, min(1, (-(av.0) * dx + -(av.1) * dy) / denom)) : 0
        let x = av.0 + t * dx, y = av.1 + t * dy
        let lon = p.longitude + x / metersPerDegLon
        let lat = p.latitude + y / metersPerDegLat
        let elevation: Double?
        if let ea = a.elevation, let eb = b.elevation { elevation = ea + t * (eb - ea) } else { elevation = nil }
        return RoutePoint(latitude: lat, longitude: lon, elevation: elevation)
    }

    static func progress(on route: FieldRoute, from location: CLLocation, paceKPH: Double = 4.4) -> RouteProgress? {
        guard let nearest = nearestPoint(on: route, to: location) else { return nil }
        let total = metrics(for: route, paceKPH: paceKPH).distanceMeters
        let traveled = min(total, max(0, routeDistanceAlong(route, throughSegment: nearest.segmentIndex, to: nearest.point)))
        let remaining = max(0, total - traveled)
        let metersPerSecond = max(0.35, paceKPH * 1000 / 3600)
        return RouteProgress(nearest: nearest, traveledMeters: traveled, remainingMeters: remaining, totalMeters: total, progressFraction: total > 0 ? traveled / total : 0, estimatedRemainingSeconds: remaining / metersPerSecond)
    }

    static func terrainRisk(for route: FieldRoute, savedWaypoints: [Waypoint] = []) -> TerrainRiskReport {
        let metrics = metrics(for: route)
        var flags: [TerrainRiskFlag] = []
        func add(_ id: String, _ severity: TerrainRiskSeverity, _ title: String, _ detail: String, _ evidence: String) {
            flags.append(.init(id: id, severity: severity, title: title, detail: detail, evidence: evidence))
        }
        if metrics.maxGradePercent >= 35 {
            add("grade-high", .high, "VERY STEEP GRADE", String(format: "Route geometry reaches approximately %.0f%% grade between stored elevation points.", metrics.maxGradePercent), "ROUTE ELEVATION")
        } else if metrics.maxGradePercent >= 20 {
            add("grade-warning", .warning, "STEEP GRADE", String(format: "Route geometry reaches approximately %.0f%% grade between stored elevation points.", metrics.maxGradePercent), "ROUTE ELEVATION")
        }
        if metrics.ascentMeters >= 1200 {
            add("ascent-high", .high, "MAJOR ASCENT", String(format: "Approximately %.0f ft of climbing is stored for this route.", metrics.ascentFeet), "ROUTE ELEVATION")
        } else if metrics.ascentMeters >= 600 {
            add("ascent-warning", .warning, "SIGNIFICANT ASCENT", String(format: "Approximately %.0f ft of climbing is stored for this route.", metrics.ascentFeet), "ROUTE ELEVATION")
        }
        if route.terrain == .offTrail { add("offtrail", .warning, "OFF-TRAIL TRAVEL", "Route is marked off trail. Navigation and terrain uncertainty are higher.", "ROUTE SETTING") }
        if route.terrain == .snow { add("snow", .warning, "SNOW / WINTER TERRAIN", "Route is marked for snow or winter travel; surface and avalanche conditions are not inferred by FIELD/OS.", "ROUTE SETTING") }
        let exitRefs = savedWaypoints.filter { [.base, .camp, .junction, .bailout].contains($0.kind) }
        if metrics.distanceMiles >= 8 && exitRefs.count < 2 { add("few-bailouts", .warning, "LIMITED SAVED BAILOUT REFERENCES", "Long route has fewer than two saved Base/Camp/Junction/Bailout references.", "LOCAL WAYPOINTS") }
        let elevCount = route.points.filter { $0.elevation != nil }.count
        let confidence = min(100, (route.points.count >= 2 ? 35 : 0) + (elevCount >= 2 ? 45 : 0) + (!savedWaypoints.isEmpty ? 20 : 0))
        if elevCount < 2 { add("elevation-gap", .info, "ELEVATION SCREENING LIMITED", "Stored route points do not contain enough elevation data to screen slope reliably.", "DATA GAP") }
        if flags.isEmpty { add("none", .info, "NO AUTOMATED FLAGS", "No supported local thresholds were triggered. This is not a declaration that terrain is safe.", "SCREENING ONLY") }
        flags.sort { $0.severity > $1.severity }
        return TerrainRiskReport(confidence: confidence, flags: flags)
    }

    static func bailoutCandidates(from location: CLLocation, waypoints: [Waypoint], limit: Int = 8) -> [BailoutCandidate] {
        let origin = RoutePoint(location: location)
        return waypoints
            .filter { [.base, .camp, .junction, .bailout].contains($0.kind) }
            .map { wp in BailoutCandidate(waypoint: wp, distanceMeters: distanceMeters(origin, wp.point), bearingDegrees: bearingDegrees(from: origin, to: wp.point)) }
            .sorted { $0.distanceMeters < $1.distanceMeters }
            .prefix(max(1, limit))
            .map { $0 }
    }

    static func routeDistanceAlong(_ route: FieldRoute, throughSegment segmentIndex: Int, to point: RoutePoint) -> Double {
        guard route.points.count >= 2 else { return 0 }
        var total = 0.0
        if segmentIndex > 0 {
            for i in 0..<min(segmentIndex, route.points.count - 1) {
                total += distanceMeters(route.points[i], route.points[i + 1])
            }
        }
        if segmentIndex < route.points.count { total += distanceMeters(route.points[segmentIndex], point) }
        return total
    }
}
