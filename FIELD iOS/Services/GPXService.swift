import Foundation

final class GPXService: NSObject, XMLParserDelegate {
    private var points: [RoutePoint] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentElevation: Double?
    private var captureElevation = false
    private var textBuffer = ""

    static func export(route: FieldRoute) -> String {
        let escapedName = route.name
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let pts = route.points.map { point in
            let ele = point.elevation.map { "<ele>\($0)</ele>" } ?? ""
            return "<trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\">\(ele)</trkpt>"
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="FIELD/OS iOS" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><name>\(escapedName)</name><trkseg>
        \(pts)
          </trkseg></trk>
        </gpx>
        """
    }

    func parse(data: Data, name: String = "Imported GPX") throws -> FieldRoute {
        points = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), points.count >= 2 else {
            throw NSError(domain: "FIELD.GPX", code: 1, userInfo: [NSLocalizedDescriptionKey: parser.parserError?.localizedDescription ?? "No valid GPX track points were found."])
        }
        return FieldRoute(name: name, points: points, updatedAt: .now)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "trkpt" || elementName == "rtept" {
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLon = attributeDict["lon"].flatMap(Double.init)
            currentElevation = nil
        } else if elementName == "ele" {
            captureElevation = true
            textBuffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if captureElevation { textBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "ele" {
            currentElevation = Double(textBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
            captureElevation = false
        } else if elementName == "trkpt" || elementName == "rtept" {
            if let lat = currentLat, let lon = currentLon, abs(lat) <= 90, abs(lon) <= 180 {
                points.append(RoutePoint(latitude: lat, longitude: lon, elevation: currentElevation))
            }
            currentLat = nil; currentLon = nil; currentElevation = nil
        }
    }
}
