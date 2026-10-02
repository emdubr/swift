import Foundation

struct POIImportService {
    static func parse(data: Data, sourceName: String) throws -> [OfflinePOI] {
        let object = try JSONSerialization.jsonObject(with: data)
        var output: [OfflinePOI] = []

        if let root = object as? [String: Any],
           (root["type"] as? String)?.lowercased() == "featurecollection",
           let features = root["features"] as? [[String: Any]] {
            for feature in features {
                guard let geometry = feature["geometry"] as? [String: Any],
                      (geometry["type"] as? String)?.lowercased() == "point",
                      let coords = geometry["coordinates"] as? [Double], coords.count >= 2 else { continue }
                let props = feature["properties"] as? [String: Any] ?? [:]
                let name = (props["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let category = (props["category"] as? String) ?? (props["type"] as? String) ?? "POI"
                let poi = OfflinePOI(name: (name?.isEmpty == false ? name! : "Imported POI"),
                                     category: category,
                                     point: RoutePoint(latitude: coords[1], longitude: coords[0]),
                                     source: sourceName)
                if abs(poi.point.latitude) <= 90 && abs(poi.point.longitude) <= 180 { output.append(poi) }
            }
        } else if let rows = object as? [[String: Any]] {
            for row in rows {
                let lat = (row["latitude"] as? NSNumber)?.doubleValue ?? (row["lat"] as? NSNumber)?.doubleValue
                let lon = (row["longitude"] as? NSNumber)?.doubleValue ?? (row["lon"] as? NSNumber)?.doubleValue
                guard let lat, let lon, abs(lat) <= 90, abs(lon) <= 180 else { continue }
                let name = (row["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let category = (row["category"] as? String) ?? "POI"
                output.append(OfflinePOI(name: (name?.isEmpty == false ? name! : "Imported POI"),
                                         category: category,
                                         point: RoutePoint(latitude: lat, longitude: lon),
                                         source: sourceName))
            }
        }

        if output.isEmpty {
            throw NSError(domain: "FIELD.POI", code: 1, userInfo: [NSLocalizedDescriptionKey: "No valid point features were found in the selected JSON/GeoJSON file."])
        }
        return Array(output.prefix(5_000))
    }
}
