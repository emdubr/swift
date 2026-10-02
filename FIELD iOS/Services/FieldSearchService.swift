import Foundation

struct FieldSearchService {
    static func search(_ query: String, waypoints: [Waypoint], pois: [OfflinePOI]) -> [(name: String, subtitle: String, point: RoutePoint)] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        var results: [(String, String, RoutePoint)] = []
        for waypoint in waypoints where waypoint.name.lowercased().contains(q) || waypoint.kind.rawValue.lowercased().contains(q) {
            results.append((waypoint.name, waypoint.kind.rawValue, waypoint.point))
        }
        for poi in pois where poi.name.lowercased().contains(q) || poi.category.lowercased().contains(q) {
            results.append((poi.name, poi.category, poi.point))
        }
        return Array(results.prefix(50))
    }
}
