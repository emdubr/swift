import CoreLocation
import Foundation

struct TrailNode: Codable, Hashable, Identifiable {
    var id: Int
    var point: RoutePoint
}

struct TrailEdge: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var from: Int
    var to: Int
    var name: String
    var distanceMeters: Double
}

struct TrailNetwork: Codable, Equatable {
    var name: String = "OFFLINE TRAILS"
    var nodes: [TrailNode] = []
    var edges: [TrailEdge] = []
    var importedAt: Date = .now
    var sourceName: String = ""
    var isEmpty: Bool { nodes.isEmpty || edges.isEmpty }
}

enum TrailNetworkError: LocalizedError {
    case invalidGeoJSON, noTrails, noRoute
    var errorDescription: String? {
        switch self {
        case .invalidGeoJSON: return "The file is not supported GeoJSON."
        case .noTrails: return "No LineString trail geometry was found."
        case .noRoute: return "No connected trail route exists between those points."
        }
    }
}

struct TrailNetworkService {
    static func parseGeoJSON(data: Data, sourceName: String) throws -> TrailNetwork {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TrailNetworkError.invalidGeoJSON }
        let features: [[String: Any]]
        if root["type"] as? String == "FeatureCollection" { features = root["features"] as? [[String: Any]] ?? [] }
        else if root["type"] as? String == "Feature" { features = [root] }
        else { throw TrailNetworkError.invalidGeoJSON }

        var nodes: [TrailNode] = []
        var edges: [TrailEdge] = []
        var nodeLookup: [String: Int] = [:]

        func key(_ lat: Double, _ lon: Double) -> String { String(format: "%.5f,%.5f", lat, lon) }
        func nodeID(lat: Double, lon: Double) -> Int {
            let k = key(lat, lon)
            if let existing = nodeLookup[k] { return existing }
            let id = nodes.count
            nodes.append(TrailNode(id: id, point: RoutePoint(latitude: lat, longitude: lon)))
            nodeLookup[k] = id
            return id
        }
        func addLine(_ coords: [[Double]], name: String) {
            guard coords.count > 1 else { return }
            for pair in zip(coords, coords.dropFirst()) where pair.0.count >= 2 && pair.1.count >= 2 {
                let a = RoutePoint(latitude: pair.0[1], longitude: pair.0[0], elevation: pair.0.count > 2 ? pair.0[2] : nil)
                let b = RoutePoint(latitude: pair.1[1], longitude: pair.1[0], elevation: pair.1.count > 2 ? pair.1[2] : nil)
                let from = nodeID(lat: a.latitude, lon: a.longitude), to = nodeID(lat: b.latitude, lon: b.longitude)
                let d = RouteEngine.distanceMeters(a, b)
                if d > 0.5 { edges.append(TrailEdge(from: from, to: to, name: name, distanceMeters: d)) }
            }
        }

        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any], let type = geometry["type"] as? String else { continue }
            let properties = feature["properties"] as? [String: Any]
            let name = (properties?["name"] as? String) ?? (properties?["ref"] as? String) ?? "Trail"
            if type == "LineString", let coords = geometry["coordinates"] as? [[Double]] { addLine(coords, name: name) }
            if type == "MultiLineString", let lines = geometry["coordinates"] as? [[[Double]]] { for line in lines { addLine(line, name: name) } }
        }
        guard !edges.isEmpty else { throw TrailNetworkError.noTrails }
        return TrailNetwork(name: "OFFLINE TRAILS", nodes: nodes, edges: edges, importedAt: .now, sourceName: sourceName)
    }

    static func nearestNode(to point: RoutePoint, network: TrailNetwork, maxDistanceMeters: Double = 2500) -> TrailNode? {
        network.nodes.min(by: { RouteEngine.distanceMeters($0.point, point) < RouteEngine.distanceMeters($1.point, point) })
            .flatMap { RouteEngine.distanceMeters($0.point, point) <= maxDistanceMeters ? $0 : nil }
    }

    static func snap(_ point: RoutePoint, network: TrailNetwork, maxDistanceMeters: Double = 250) -> RoutePoint? {
        nearestNode(to: point, network: network, maxDistanceMeters: maxDistanceMeters)?.point
    }

    static func route(from start: RoutePoint, to end: RoutePoint, network: TrailNetwork) throws -> FieldRoute {
        guard let startNode = nearestNode(to: start, network: network), let endNode = nearestNode(to: end, network: network) else { throw TrailNetworkError.noRoute }
        var adjacency: [Int: [(Int, Double)]] = [:]
        for edge in network.edges {
            adjacency[edge.from, default: []].append((edge.to, edge.distanceMeters))
            adjacency[edge.to, default: []].append((edge.from, edge.distanceMeters))
        }
        var open: Set<Int> = [startNode.id], cameFrom: [Int: Int] = [:]
        var g: [Int: Double] = [startNode.id: 0], f: [Int: Double] = [startNode.id: heuristic(startNode.id, endNode.id, network)]
        while !open.isEmpty {
            let current = open.min { (f[$0] ?? .greatestFiniteMagnitude) < (f[$1] ?? .greatestFiniteMagnitude) }!
            if current == endNode.id {
                var ids = [current], cursor = current
                while let previous = cameFrom[cursor] { ids.append(previous); cursor = previous }
                ids.reverse()
                let points = ids.compactMap { id in network.nodes.first(where: { $0.id == id })?.point }
                return FieldRoute(name: "OFFLINE TRAIL ROUTE", points: points, anchors: [start, end], terrain: .maintained)
            }
            open.remove(current)
            for (neighbor, cost) in adjacency[current, default: []] {
                let tentative = (g[current] ?? .greatestFiniteMagnitude) + cost
                if tentative < (g[neighbor] ?? .greatestFiniteMagnitude) {
                    cameFrom[neighbor] = current; g[neighbor] = tentative
                    f[neighbor] = tentative + heuristic(neighbor, endNode.id, network); open.insert(neighbor)
                }
            }
        }
        throw TrailNetworkError.noRoute
    }

    private static func heuristic(_ a: Int, _ b: Int, _ network: TrailNetwork) -> Double {
        guard let pa = network.nodes.first(where: { $0.id == a })?.point, let pb = network.nodes.first(where: { $0.id == b })?.point else { return 0 }
        return RouteEngine.distanceMeters(pa, pb)
    }
}
