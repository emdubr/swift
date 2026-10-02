import Foundation

// PMTiles v3: https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md
// MapLibre 6.10+ reads local PMTiles archives via pmtiles://file://.
// This helper never makes network requests. Only raster imagery and vector tiles are selected;
// a standalone DEM archive is not a complete basemap and is deliberately not mislabeled.
enum PMTilesStyle {
    enum StyleError: LocalizedError {
        case invalidHeader, unsupportedType, unsafeArchive, missingFile
        var errorDescription: String? {
            switch self {
            case .invalidHeader: return "PMTiles v3 header is invalid."
            case .unsupportedType: return "This tile type is not currently supported by FIELD/OS."
            case .unsafeArchive: return "PMTiles archive has invalid offsets or zoom bounds."
            case .missingFile: return "The imported PMTiles file is missing."
            }
        }
    }
    struct Descriptor: Equatable {
        let tileType: UInt8
        let minZoom: UInt8
        let maxZoom: UInt8
        let centerZoom: UInt8
        let centerLatitude: Double
        let centerLongitude: Double
        var isVector: Bool { tileType == 1 || tileType == 6 }
    }
    static func inspect(_ header: Data, totalBytes: Int64) throws -> Descriptor {
        guard header.count == 127, header.prefix(7) == Data("PMTiles".utf8), header[7] == 3 else { throw StyleError.invalidHeader }
        func u64(_ n: Int) -> UInt64 {
            (0..<8).reduce(UInt64(0)) { $0 | (UInt64(header[n+$1]) << (8*$1)) }
        }
        let rootOff = u64(8), rootLen = u64(16), metaOff = u64(24), metaLen = u64(32)
        let leafOff = u64(40), leafLen = u64(48), tileOff = u64(56), tileLen = u64(64)
        guard totalBytes >= 127, totalBytes <= 16 * 1024 * 1024 * 1024 else { throw StyleError.unsafeArchive }
        let size = UInt64(totalBytes)
        for (offset, len) in [(rootOff, rootLen), (metaOff, metaLen), (leafOff, leafLen), (tileOff, tileLen)] {
            guard offset <= size, len <= size - offset else { throw StyleError.unsafeArchive }
        }
        guard rootOff >= 127, rootLen > 0, rootOff + rootLen <= 16384,
              [UInt8(1), 2, 3, 4, 5, 6].contains(header[99]),
              [UInt8(1), 2].contains(header[97]), // none or gzip are supported by MapLibre
              [UInt8(1), 2].contains(header[98]),
              header[100] <= header[101], header[101] <= 22, header[118] <= 22 else { throw StyleError.unsupportedType }
        func i32(_ n: Int) -> Int32 {
            let v = (0..<4).reduce(UInt32(0)) { $0 | (UInt32(header[n+$1]) << (8*$1)) }
            return Int32(bitPattern: v)
        }
        let lon = Double(i32(119)) / 10_000_000, lat = Double(i32(123)) / 10_000_000
        guard (-90...90).contains(lat), (-180...180).contains(lon) else { throw StyleError.unsafeArchive }
        return Descriptor(tileType: header[99], minZoom: header[100], maxZoom: header[101], centerZoom: header[118], centerLatitude: lat, centerLongitude: lon)
    }
    static func descriptor(fileURL: URL) throws -> Descriptor {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw StyleError.missingFile }
        let size = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber
        let reader = try FileHandle(forReadingFrom: fileURL)
        defer { try? reader.close() }
        return try inspect(reader.read(upToCount: 127) ?? Data(), totalBytes: size?.int64Value ?? 0)
    }
    // Source-layer IDs vary by tile publisher. FIELD/OS allows the user to override
    // them, and also tries common OSM identifiers. Unknown layers are harmless.
    static let commonLayers = ["water", "waterway", "landcover", "landuse", "park", "building", "transportation", "transportation_name", "road", "roads", "trail", "trails", "contour", "contours", "mountain_peak", "boundary", "place"]
    static func style(packURL: URL, tileType: UInt8, layers: [String] = []) -> [String: Any] {
        let uri = "pmtiles://" + packURL.absoluteString
        let vector = tileType == 1 || tileType == 6
        var result: [String: Any] = [
            "version": 8, "name": "FIELD/OS LOCAL PMTILES",
            "sources": ["field-local": vector ? ["type": "vector", "url": uri] : ["type": "raster", "url": uri, "tileSize": 256]],
            "layers": [["id": "field-background", "type": "background", "paint": ["background-color": "#d5decf"]]]
        ]
        if !vector {
            result["layers"] = [
                ["id": "field-background", "type": "background", "paint": ["background-color": "#d5decf"]],
                ["id": "field-raster", "type": "raster", "source": "field-local"]
            ] as [[String: Any]]
            return result
        }
        var display: [[String: Any]] = result["layers"] as! [[String: Any]]
        let sources = Array(Set(commonLayers + layers.filter { !$0.isEmpty && $0.count < 120 })).sorted()
        for source in sources {
            let low = source.lowercased()
            let isWater = low.contains("water")
            let isRoad = low.contains("road") || low.contains("transport") || low.contains("trail") || low.contains("contour") || low.contains("boundary")
            let isBuilding = low.contains("building")
            let isPlace = low.contains("place")
            let type = isRoad || isWater && low.contains("way") ? "line" : isPlace ? "circle" : "fill"
            let paint: [String: Any]
            if type == "line" {
                paint = ["line-color": isWater ? "#6a9eb4" : "#ae8146", "line-width": ["interpolate", ["linear"], ["zoom"], 7, 0.7, 14, 2.5]]
            } else if type == "circle" {
                paint = ["circle-radius": 2.0, "circle-color": "#495b49"]
            } else {
                paint = ["fill-color": isWater ? "#92bdd1" : isBuilding ? "#9eaa99" : "#b4c4a6", "fill-opacity": isWater ? 0.95 : 0.55]
            }
            display.append(["id": "field-\(source)", "type": type, "source": "field-local", "source-layer": source, "paint": paint])
        }
        result["layers"] = display
        return result
    }
    static func styleData(packURL: URL, tileType: UInt8, layers: [String] = []) throws -> Data {
        try JSONSerialization.data(withJSONObject: style(packURL: packURL, tileType: tileType, layers: layers), options: [.sortedKeys])
    }
}
