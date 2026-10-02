import Foundation
import CoreLocation

@main struct TrailNetworkTests {
    static func main() throws {
        let geo = Data("""
        {"type":"FeatureCollection","features":[
          {"type":"Feature","properties":{"name":"Ridge Trail"},
            "geometry":{"type":"LineString","coordinates":[[-73,44,100],[-72,44,200]]}}
        ]}
        """.utf8)
        let network = try TrailNetworkService.parseGeoJSON(data: geo, sourceName: "sample.geojson")
        assert(network.nodes.count == 2 && network.edges.count == 1)
        let snapped = TrailNetworkService.snap(
            RoutePoint(latitude: 44.001, longitude: -72.5), network: network)
        assert(snapped != nil)
        assert(abs(snapped!.latitude - 44) < 0.002)
        assert(abs(snapped!.longitude + 72.5) < 0.002)
        assert(snapped!.elevation != nil && abs(snapped!.elevation! - 150) < 1)
        let route = try TrailNetworkService.route(
            from: RoutePoint(latitude: 44, longitude: -72.25),
            to: RoutePoint(latitude: 44, longitude: -72.75), network: network)
        assert(route.points.count == 2) // shortest path directly along the same edge
        assert(abs(route.points[0].longitude + 72.25) < 0.002)
        assert(abs(route.points[1].longitude + 72.75) < 0.002)
        let length = RouteEngine.metrics(for: route).distanceMeters
        assert(length > 30_000 && length < 50_000)

        let connected = Data("""
        {"type":"FeatureCollection","features":[
          {"type":"Feature","geometry":{"type":"LineString",
            "coordinates":[[-73,44],[-72.5,44],[-72.5,44.5]]}}
        ]}
        """.utf8)
        let junction = try TrailNetworkService.parseGeoJSON(data: connected, sourceName: "connected")
        let path = try TrailNetworkService.route(
            from: RoutePoint(latitude: 44, longitude: -72.9),
            to: RoutePoint(latitude: 44.4, longitude: -72.5), network: junction)
        assert(path.points.count >= 3)
        assert(abs(path.points[0].longitude + 72.9) < 0.002)
        assert(abs(path.points[path.points.count - 1].latitude - 44.4) < 0.002)

        let disconnected = Data("""
        {"type":"FeatureCollection","features":[
          {"type":"Feature","geometry":{"type":"LineString","coordinates":[[-73,44],[-72,44]]}},
          {"type":"Feature","geometry":{"type":"LineString","coordinates":[[-75,44],[-74,44]]}}
        ]}
        """.utf8)
        let islands = try TrailNetworkService.parseGeoJSON(data: disconnected, sourceName: "disconnected")
        do {
            _ = try TrailNetworkService.route(
                from: RoutePoint(latitude: 44, longitude: -72.5),
                to: RoutePoint(latitude: 44, longitude: -74.5), network: islands)
            fatalError("Disconnected trail networks were incorrectly connected")
        } catch TrailNetworkError.noRoute {}
        do {
            _ = try TrailNetworkService.route(
                from: RoutePoint(latitude: 40, longitude: -72.5),
                to: RoutePoint(latitude: 44, longitude: -72.5), network: islands)
            fatalError("Distant route point incorrectly snapped to an unrelated trail")
        } catch TrailNetworkError.tooFarFromTrail {}

        let invalid = Data("""
        {"type":"FeatureCollection","features":[{"type":"Feature",
          "geometry":{"type":"LineString","coordinates":[[400,44],[-72,44]]}}]}
        """.utf8)
        do {
            _ = try TrailNetworkService.parseGeoJSON(data: invalid, sourceName: "bad")
            fatalError("Out-of-bounds coordinates accepted")
        } catch TrailNetworkError.noTrails {}
        print("PASS: continuous trail-segment snap, same-edge and multi-edge A*, disconnected trails, distance rejection, invalid GeoJSON")
    }
}
