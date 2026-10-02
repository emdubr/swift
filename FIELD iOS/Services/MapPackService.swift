import Foundation

enum MapPackValidationError: LocalizedError {
    case invalidHeader, oversized
    var errorDescription: String? {
        switch self {
        case .invalidHeader: return "Expected a valid PMTiles v3 header (not a renamed or unsupported map)."
        case .oversized: return "Map pack exceeds the supported file size."
        }
    }
}

actor MapPackService {
    static let shared = MapPackService()
    private let fileManager = FileManager.default

    private func directory() throws -> URL {
        let root = try fileManager.url(for: .applicationSupportDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: true)
        let dir = root.appendingPathComponent("FIELDOS/MapPacks", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func importPack(from source: URL) throws -> MapPack {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        // PMTiles v3: the first seven bytes are ASCII 'PMTiles' + version 3.
        // Validate the PMTiles v3 header before copying to sandboxed device storage.
        let reader = try FileHandle(forReadingFrom: source)
        defer { try? reader.close() }
        let header = try reader.read(upToCount: 127) ?? Data()
        let attrs = try fileManager.attributesOfItem(atPath: source.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        _ = try PMTilesStyle.inspect(header, totalBytes: size)
        let safeName = "\(UUID().uuidString)-\(source.lastPathComponent)"
        let destination = try directory().appendingPathComponent(safeName)
        try fileManager.copyItem(at: source, to: destination)
        return MapPack(originalName: source.lastPathComponent,
                       localFilename: safeName,
                       sizeBytes: size)
    }

    func localStyle(for pack: MapPack) throws -> URL {
        let packURL = try url(for: pack)
        let descriptor = try PMTilesStyle.descriptor(fileURL: packURL)
        let data = try PMTilesStyle.styleData(packURL: packURL, tileType: descriptor.tileType, layers: pack.sourceLayers ?? [])
        let destination = try directory().appendingPathComponent("style-\(pack.id.uuidString).json")
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func remove(_ pack: MapPack) throws {
        let styleURL = try directory().appendingPathComponent("style-\(pack.id.uuidString).json")
        if fileManager.fileExists(atPath: styleURL.path) { try fileManager.removeItem(at: styleURL) }
        let url = try directory().appendingPathComponent(pack.localFilename)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
    }

    func url(for pack: MapPack) throws -> URL {
        try directory().appendingPathComponent(pack.localFilename)
    }
}
