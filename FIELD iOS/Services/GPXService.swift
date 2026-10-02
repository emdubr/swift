import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum GPXImportError: LocalizedError {
    case oversized, tooManyPoints, missingPoints
    var errorDescription: String? {
        switch self {
        case .oversized: return "GPX file is larger than the 10 MB import limit."
        case .tooManyPoints: return "GPX exceeds 20,000 track points. Simplify the track before importing."
        case .missingPoints: return "GPX must contain at least two valid track or route points."
        }
    }
}

final class GPXService: NSObject, XMLParserDelegate {
    static let maxBytes = 10 * 1024 * 1024
    static let maxPoints = 20_000

    private var points: [RoutePoint] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentElevation: Double?
    private var captureElevation = false
    private var textBuffer = ""
    private var importError: GPXImportError?

    static func export(route: FieldRoute) -> String {
        let escapedName = route.name
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let pts = route.points.compactMap { point -> String? in
            guard point.latitude.isFinite, point.longitude.isFinite,
                  abs(point.latitude) <= 90, abs(point.longitude) <= 180 else { return nil }
            let ele = point.elevation.flatMap { $0.isFinite ? "<ele>\($0)</ele>" : nil } ?? ""
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
        guard data.count <= Self.maxBytes else { throw GPXImportError.oversized }
        // The same parser instance may be reused for multiple imports.
        points = []
        currentLat = nil; currentLon = nil; currentElevation = nil
        captureElevation = false; textBuffer = ""; importError = nil
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        let parsed = parser.parse()
        if let importError { throw importError }
        guard parsed else {
            throw NSError(domain: "FIELD.GPX", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: parser.parserError?.localizedDescription ?? "Invalid GPX XML."])
        }
        guard points.count >= 2 else { throw GPXImportError.missingPoints }
        return FieldRoute(name: name, points: points, updatedAt: .now)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let element = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if element == "trkpt" || element == "rtept" {
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLon = attributeDict["lon"].flatMap(Double.init)
            currentElevation = nil
        } else if element == "ele", currentLat != nil, currentLon != nil {
            captureElevation = true
            textBuffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if captureElevation && textBuffer.count < 128 {
            textBuffer += String(string.prefix(128 - textBuffer.count))
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let element = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if element == "ele" {
            if captureElevation {
                let elevation = Double(textBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
                currentElevation = elevation.flatMap { $0.isFinite ? $0 : nil }
            }
            captureElevation = false
        } else if element == "trkpt" || element == "rtept" {
            if let lat = currentLat, let lon = currentLon,
               lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180 {
                if points.count >= Self.maxPoints {
                    importError = .tooManyPoints
                    parser.abortParsing()
                    return
                }
                points.append(RoutePoint(latitude: lat, longitude: lon, elevation: currentElevation))
            }
            currentLat = nil; currentLon = nil; currentElevation = nil; captureElevation = false
        }
    }
}
