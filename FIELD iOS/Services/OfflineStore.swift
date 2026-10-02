import Foundation

actor OfflineStore {
    static let shared = OfflineStore()
    private let fileManager = FileManager.default

    private func rootDirectory() throws -> URL {
        let root = try fileManager.url(for: .applicationSupportDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: true)
        let directory = root.appendingPathComponent("FIELDOS", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func save<T: Encodable>(_ value: T, named name: String) throws {
        let url = try rootDirectory().appendingPathComponent(name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, named name: String) throws -> T? {
        let url = try rootDirectory().appendingPathComponent(name)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    func delete(named name: String) throws {
        let url = try rootDirectory().appendingPathComponent(name)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
    }

    func exportSnapshot<T: Encodable>(_ value: T, prefix: String) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(Int(Date().timeIntervalSince1970)).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: tmp, options: .atomic)
        return tmp
    }
}
