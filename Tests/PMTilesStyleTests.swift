import Foundation

@main struct PMTilesStyleTests {
    static func main() throws {
        func u64(_ data: inout Data, at index: Int, _ value: UInt64) {
            for i in 0..<8 { data[index+i] = UInt8(truncatingIfNeeded: value >> (i*8)) }
        }
        var valid = Data(repeating: 0, count: 127)
        valid.replaceSubrange(0..<7, with: Data("PMTiles".utf8))
        valid[7] = 3; valid[97] = 1; valid[98] = 1; valid[99] = 1
        valid[100] = 0; valid[101] = 14
        u64(&valid, at: 8, 127); u64(&valid, at: 16, 2)
        u64(&valid, at: 24, 129); u64(&valid, at: 32, 0)
        u64(&valid, at: 40, 129); u64(&valid, at: 48, 0)
        u64(&valid, at: 56, 129); u64(&valid, at: 64, 0)
        let d = try PMTilesStyle.inspect(valid, totalBytes: 129)
        assert(d.isVector && d.maxZoom == 14)
        let pack = URL(fileURLWithPath: "/private/var/mobile/Containers/Data/Application/test/Map Packs/test.pmtiles")
        let bytes = try PMTilesStyle.styleData(packURL: pack, tileType: 1, layers: ["hiking_trails"])
        let json = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        let sources = json["sources"] as! [String: [String: Any]]
        let location = sources["field-local"]!["url"] as! String
        assert(location.hasPrefix("pmtiles://file:///"))
        assert(!location.contains("https"))
        let layers = json["layers"] as! [[String: Any]]
        assert(layers.contains { ($0["source-layer"] as? String) == "hiking_trails" })
        let raster = try PMTilesStyle.styleData(packURL: pack, tileType: 2)
        let rasterJSON = try JSONSerialization.jsonObject(with: raster) as! [String: Any]
        assert((rasterJSON["layers"] as! [[String: Any]]).contains { ($0["type"] as? String) == "raster" })
        var bad = valid; bad[0] = 0
        do { _ = try PMTilesStyle.inspect(bad, totalBytes: 129); fatalError("bad magic accepted") }
        catch PMTilesStyle.StyleError.invalidHeader {}
        bad = valid; u64(&bad, at: 56, UInt64.max)
        do { _ = try PMTilesStyle.inspect(bad, totalBytes: 129); fatalError("bad bounds accepted") }
        catch PMTilesStyle.StyleError.unsafeArchive {}
        bad = valid; bad[99] = 42
        do { _ = try PMTilesStyle.inspect(bad, totalBytes: 129); fatalError("bad tile type accepted") }
        catch PMTilesStyle.StyleError.unsupportedType {}
        bad = valid; bad[101] = 55
        do { _ = try PMTilesStyle.inspect(bad, totalBytes: 129); fatalError("bad zoom accepted") }
        catch PMTilesStyle.StyleError.unsupportedType {}
        print("PASS: PMTiles header bounds/version/type/zoom rejection, local raster and vector style generation")
    }
}
