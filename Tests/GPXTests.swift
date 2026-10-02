import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// Lightweight route models allow GPX parser tests on Linux and macOS without the iOS SDK.
struct RoutePoint {
    var latitude: Double
    var longitude: Double
    var elevation: Double?
}
struct FieldRoute {
    var name: String
    var points: [RoutePoint]
    var updatedAt: Date
}

@main struct GPXTests {
    static func main() throws {
        let service = GPXService()
        let xml = Data("""
        <?xml version="1.0"?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1">
          <trk><trkseg>
            <trkpt lat="44.4759" lon="-73.2121"><ele>123.5</ele></trkpt>
            <trkpt lat="44.4800" lon="-73.2100"><ele>NaN</ele></trkpt>
            <trkpt lat="91" lon="-73"/><trkpt lat="inf" lon="7"/>
          </trkseg></trk>
        </gpx>
        """.utf8)
        let route = try service.parse(data: xml, name: "Ridge & River")
        assert(route.points.count == 2)
        assert(route.points[0].elevation == 123.5)
        assert(route.points[1].elevation == nil)
        let exported = GPXService.export(route: route)
        assert(exported.contains("Ridge &amp; River"))
        assert(!exported.contains("<ele>nan</ele>"))
        let repeated = try service.parse(data: xml)
        assert(repeated.points.count == 2) // parser state is cleared on reuse

        let routePoints = Data("""
        <gpx><rte><rtept lat="40" lon="-72"/><rtept lat="41" lon="-73"/></rte></gpx>
        """.utf8)
        let parsedRoutePoints = try service.parse(data: routePoints)
        assert(parsedRoutePoints.points.count == 2)
        do {
            _ = try service.parse(data: Data(repeating: 65, count: GPXService.maxBytes + 1))
            fatalError("Oversize GPX accepted")
        } catch GPXImportError.oversized {}
        do {
            _ = try service.parse(data: Data("<gpx><trkpt lat=\"91\" lon=\"3\"/></gpx>".utf8))
            fatalError("Invalid GPX accepted")
        } catch GPXImportError.missingPoints {}
        let many = "<gpx><trk><trkseg>" +
            String(repeating: "<trkpt lat=\"44\" lon=\"-73\"/>", count: GPXService.maxPoints + 1) +
            "</trkseg></trk></gpx>"
        do {
            _ = try service.parse(data: Data(many.utf8))
            fatalError("Too many points accepted")
        } catch GPXImportError.tooManyPoints {}
        print("PASS: GPX round-trip/XML escaping, finite coordinate/elevation checks, parser reuse, 10 MB and 20,000-point limits")
    }
}
