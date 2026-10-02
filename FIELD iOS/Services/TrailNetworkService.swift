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
    case invalidGeoJSON, noTrails, noRoute, tooFarFromTrail, oversized
    var errorDescription: String? {
        switch self {
        case .invalidGeoJSON: return "The file is not supported GeoJSON."
        case .noTrails: return "No valid LineString trail geometry was found."
        case .noRoute: return "No connected trail route exists between those points."
        case .tooFarFromTrail: return "Start or finish is more than 500 m from imported trails. Move route points closer."
        case .oversized: return "Trail network is too large. Import a smaller regional GeoJSON file."
        }
    }
}

struct TrailNetworkService {
    private struct Projection {
        var edgeIndex: Int
        var point: RoutePoint
        var fraction: Double
        var distanceMeters: Double
    }
    private static let maxImportBytes = 25 * 1024 * 1024
    private static let maxEdges = 150_000

    static func parseGeoJSON(data: Data, sourceName: String) throws -> TrailNetwork {
        guard data.count <= maxImportBytes else { throw TrailNetworkError.oversized }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TrailNetworkError.invalidGeoJSON
        }
        let features: [[String: Any]]
        if root["type"] as? String == "FeatureCollection" {
            features = root["features"] as? [[String: Any]] ?? []
        } else if root["type"] as? String == "Feature" {
            features = [root]
        } else {
            throw TrailNetworkError.invalidGeoJSON
        }

        var nodes: [TrailNode] = []
        var edges: [TrailEdge] = []
        var lookup: [String: Int] = [:]
        func valid(_ coords: [Double]) -> Bool {
            coords.count >= 2 && coords[0].isFinite && coords[1].isFinite &&
            abs(coords[0]) <= 180 && abs(coords[1]) <= 90 &&
            (coords.count <= 2 || coords[2].isFinite)
        }
        func nodeID(_ point: RoutePoint) -> Int {
            let key = String(format: "%.5f,%.5f", point.latitude, point.longitude)
            if let id = lookup[key] {
                if nodes[id].point.elevation == nil, let e = point.elevation {
                    nodes[id].point.elevation = e
                }
                return id
            }
            let id = nodes.count
            nodes.append(TrailNode(id: id, point: point))
            lookup[key] = id
            return id
        }
        func addLine(_ coords: [[Double]], name: String) throws {
            guard coords.count > 1 else { return }
            for (c0, c1) in zip(coords, coords.dropFirst()) {
                guard valid(c0), valid(c1) else { continue }
                let a = RoutePoint(latitude: c0[1], longitude: c0[0],
                                   elevation: c0.count > 2 ? c0[2] : nil)
                let b = RoutePoint(latitude: c1[1], longitude: c1[0],
                                   elevation: c1.count > 2 ? c1[2] : nil)
                let distance = RouteEngine.distanceMeters(a, b)
                guard distance.isFinite && distance > 0.5 else { continue }
                guard edges.count < maxEdges else { throw TrailNetworkError.oversized }
                let from = nodeID(a), to = nodeID(b)
                if from != to { edges.append(TrailEdge(from: from, to: to, name: name,
                                                        distanceMeters: distance)) }
            }
        }

        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { continue }
            let properties = feature["properties"] as? [String: Any]
            let name = (properties?["name"] as? String) ??
                (properties?["ref"] as? String) ?? "Trail"
            if type == "LineString", let coords = geometry["coordinates"] as? [[Double]] {
                try addLine(coords, name: name)
            } else if type == "MultiLineString",
                      let lines = geometry["coordinates"] as? [[[Double]]] {
                for line in lines { try addLine(line, name: name) }
            }
        }
        guard !edges.isEmpty else { throw TrailNetworkError.noTrails }
        return TrailNetwork(name: "OFFLINE TRAILS", nodes: nodes, edges: edges,
                            importedAt: .now, sourceName: sourceName)
    }

    private static func nodeLookup(_ network: TrailNetwork) -> [Int: RoutePoint] {
        network.nodes.reduce(into: [:]) { result, node in result[node.id] = node.point }
    }

    private static func nearestEdge(_ point: RoutePoint, network: TrailNetwork,
                                    nodes: [Int: RoutePoint]) -> Projection? {
        guard point.latitude.isFinite, point.longitude.isFinite,
              abs(point.latitude) <= 90, abs(point.longitude) <= 180 else { return nil }
        let latScale = 111_132.92
        let lonScale = max(0.01, abs(111_412.84 * cos(point.latitude * .pi / 180)))
        func deltaLongitude(_ a: Double, _ b: Double) -> Double {
            var difference = a - b
            if difference > 180 { difference -= 360 }
            if difference < -180 { difference += 360 }
            return difference
        }

        var best: Projection?
        for (index, edge) in network.edges.enumerated() {
            guard let a = nodes[edge.from], let b = nodes[edge.to],
                  edge.distanceMeters.isFinite, edge.distanceMeters > 0 else { continue }
            let ax = deltaLongitude(a.longitude, point.longitude) * lonScale
            let ay = (a.latitude - point.latitude) * latScale
            let bx = deltaLongitude(b.longitude, point.longitude) * lonScale
            let by = (b.latitude - point.latitude) * latScale
            let dx = bx - ax, dy = by - ay
            let lengthSquared = dx * dx + dy * dy
            guard lengthSquared > 0 && lengthSquared.isFinite else { continue }
            let t = min(1, max(0, -(ax * dx + ay * dy) / lengthSquared))
            let latitude = point.latitude + (ay + t * dy) / latScale
            let rawLongitude = point.longitude + (ax + t * dx) / lonScale
            let longitude = rawLongitude > 180 ? rawLongitude - 360 :
                (rawLongitude < -180 ? rawLongitude + 360 : rawLongitude)
            let elevation = a.elevation.flatMap { e0 in
                b.elevation.map { e1 in e0 + t * (e1 - e0) }
            }
            let projected = RoutePoint(latitude: latitude, longitude: longitude,
                                       elevation: elevation)
            let distance = RouteEngine.distanceMeters(point, projected)
            if distance.isFinite && (best == nil || distance < best!.distanceMeters) {
                best = Projection(edgeIndex: index, point: projected, fraction: t,
                                  distanceMeters: distance)
            }
        }
        return best
    }

    static func nearestNode(to point: RoutePoint, network: TrailNetwork,
                            maxDistanceMeters: Double = 2500) -> TrailNode? {
        network.nodes.min(by: {
            RouteEngine.distanceMeters($0.point, point) < RouteEngine.distanceMeters($1.point, point)
        }).flatMap {
            RouteEngine.distanceMeters($0.point, point) <= maxDistanceMeters ? $0 : nil
        }
    }

    /// Project onto a trail segment instead of jumping to the nearest graph vertex.
    static func snap(_ point: RoutePoint, network: TrailNetwork,
                     maxDistanceMeters: Double = 250) -> RoutePoint? {
        let result = nearestEdge(point, network: network, nodes: nodeLookup(network))
        return result.flatMap { $0.distanceMeters <= maxDistanceMeters ? $0.point : nil }
    }

    /// A* over offline trail edges with two virtual snapped start/end nodes.
    /// Crossing trails connect only where imported GeoJSON shares graph vertices.
    static func route(from start: RoutePoint, to end: RoutePoint,
                      network: TrailNetwork) throws -> FieldRoute {
        let nodes = nodeLookup(network)
        guard let first = nearestEdge(start, network: network, nodes: nodes),
              let last = nearestEdge(end, network: network, nodes: nodes) else {
            throw TrailNetworkError.noRoute
        }
        guard first.distanceMeters <= 500 && last.distanceMeters <= 500 else {
            throw TrailNetworkError.tooFarFromTrail
        }
        let startID = -1, endID = -2
        var points = nodes
        points[startID] = first.point
        points[endID] = last.point
        var adjacency: [Int: [(Int, Double)]] = [:]
        func link(_ a: Int, _ b: Int, _ distance: Double) {
            guard distance.isFinite && distance >= 0 else { return }
            adjacency[a, default: []].append((b, distance))
            adjacency[b, default: []].append((a, distance))
        }
        for edge in network.edges where nodes[edge.from] != nil && nodes[edge.to] != nil {
            link(edge.from, edge.to, edge.distanceMeters)
        }
        let firstEdge = network.edges[first.edgeIndex]
        link(startID, firstEdge.from, firstEdge.distanceMeters * first.fraction)
        link(startID, firstEdge.to, firstEdge.distanceMeters * (1 - first.fraction))
        let lastEdge = network.edges[last.edgeIndex]
        link(endID, lastEdge.from, lastEdge.distanceMeters * last.fraction)
        link(endID, lastEdge.to, lastEdge.distanceMeters * (1 - last.fraction))
        if first.edgeIndex == last.edgeIndex {
            link(startID, endID, firstEdge.distanceMeters * abs(first.fraction - last.fraction))
        }

        func heuristic(_ id: Int) -> Double {
            guard let p = points[id] else { return 0 }
            return RouteEngine.distanceMeters(p, last.point)
        }
        // A binary heap keeps repeated route searches responsive on large regional graphs.
        var heap: [(node: Int, priority: Double)] = []
        func enqueue(_ node: Int, _ priority: Double) {
            heap.append((node, priority))
            var i = heap.count - 1
            while i > 0 {
                let parent = (i - 1) / 2
                if heap[parent].priority <= heap[i].priority { break }
                heap.swapAt(parent, i)
                i = parent
            }
        }
        func dequeue() -> (node: Int, priority: Double)? {
            guard !heap.isEmpty else { return nil }
            if heap.count == 1 { return heap.removeLast() }
            let first = heap[0]
            heap[0] = heap.removeLast()
            var i = 0
            while true {
                let left = i * 2 + 1, right = left + 1
                guard left < heap.count else { break }
                let smallest = right < heap.count && heap[right].priority < heap[left].priority ?
                    right : left
                if heap[i].priority <= heap[smallest].priority { break }
                heap.swapAt(i, smallest)
                i = smallest
            }
            return first
        }

        var cameFrom: [Int: Int] = [:]
        var g: [Int: Double] = [startID: 0]
        var f: [Int: Double] = [startID: heuristic(startID)]
        var visited: Set<Int> = []
        enqueue(startID, f[startID]!)
        while let next = dequeue() {
            let current = next.node
            if next.priority > (f[current] ?? .greatestFiniteMagnitude) + 0.001 ||
                visited.contains(current) { continue }
            if current == endID {
                var routeIDs = [current], cursor = current
                while let parent = cameFrom[cursor] { routeIDs.append(parent); cursor = parent }
                routeIDs.reverse()
                let routePoints = routeIDs.compactMap { points[$0] }
                return FieldRoute(name: "OFFLINE TRAIL ROUTE", points: routePoints,
                                  anchors: [start, end], terrain: .maintained)
            }
            visited.insert(current)
            for (neighbor, cost) in adjacency[current, default: []] where !visited.contains(neighbor) {
                let tentative = (g[current] ?? .greatestFiniteMagnitude) + cost
                if tentative < (g[neighbor] ?? .greatestFiniteMagnitude) {
                    cameFrom[neighbor] = current
                    g[neighbor] = tentative
                    let priority = tentative + heuristic(neighbor)
                    f[neighbor] = priority
                    enqueue(neighbor, priority)
                }
            }
        }
        throw TrailNetworkError.noRoute
    }
}
