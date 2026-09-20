import Foundation

/// Bump when a persisted model changes in a way old files can't decode (e.g. a new non-optional field).
/// Files written with another version are quarantined and the data is reseeded.
enum PersistenceConfig {
    static let schemaVersion = 1
}

struct PersistedEnvelope<Value: Codable>: Codable {
    var schemaVersion: Int
    var savedAt: Date
    var value: Value
}

enum PersistenceError: Error, Equatable {
    case schemaMismatch(found: Int, expected: Int)
}

/// Where the fake backend keeps its state between launches.
protocol DocumentStore: Sendable {
    /// Returns nil when there is nothing saved, or when the file was unreadable / from another schema version
    /// (in which case it is quarantined as `<name>.corrupt` and the caller reseeds).
    func load<T: Codable>(_ type: T.Type, name: String) -> T?
    func save<T: Codable>(_ value: T, name: String) throws
    func remove(name: String)
    func removeAll()
}

/// Photo URLs are absolute `file://` paths into the app bundle or container, which change between installs and
/// updates. Before writing, the bundle and Documents prefixes become `bundle://` / `docs://`; on load they are
/// mapped back to the current locations.
struct URLRebaser: Sendable {
    let bundlePrefix: String
    let documentsPrefix: String

    static let bundleToken = "bundle://"
    static let documentsToken = "docs://"

    init(bundleURL: URL = Bundle.main.bundleURL,
         documentsURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.bundlePrefix = Self.directoryPrefix(bundleURL)
        self.documentsPrefix = Self.directoryPrefix(documentsURL)
    }

    init(bundlePrefix: String, documentsPrefix: String) {
        self.bundlePrefix = bundlePrefix
        self.documentsPrefix = documentsPrefix
    }

    func portable(_ json: String) -> String {
        json.replacingOccurrences(of: bundlePrefix, with: Self.bundleToken)
            .replacingOccurrences(of: documentsPrefix, with: Self.documentsToken)
    }

    func resolved(_ json: String) -> String {
        json.replacingOccurrences(of: Self.bundleToken, with: bundlePrefix)
            .replacingOccurrences(of: Self.documentsToken, with: documentsPrefix)
    }

    private static func directoryPrefix(_ url: URL) -> String {
        let string = url.absoluteString
        return string.hasSuffix("/") ? string : string + "/"
    }
}

private struct EnvelopeHeader: Decodable { var schemaVersion: Int }

/// JSON encoding shared by every store: envelope + ISO dates + portable URLs.
struct PersistenceCodec: Sendable {
    var rebaser = URLRebaser()

    func encode<T: Codable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(PersistedEnvelope(schemaVersion: PersistenceConfig.schemaVersion, savedAt: .now, value: value))
        guard let text = String(data: data, encoding: .utf8) else { return data }
        return Data(rebaser.portable(text).utf8)
    }

    func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        let text = String(decoding: data, as: UTF8.self)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Read the version first so a newer/older file fails cleanly instead of with a confusing key error.
        let resolved = Data(rebaser.resolved(text).utf8)
        let header = try decoder.decode(EnvelopeHeader.self, from: resolved)
        guard header.schemaVersion == PersistenceConfig.schemaVersion else {
            throw PersistenceError.schemaMismatch(found: header.schemaVersion, expected: PersistenceConfig.schemaVersion)
        }
        return try decoder.decode(PersistedEnvelope<T>.self, from: resolved).value
    }
}

// MARK: - JSON files (Application Support)

final class JSONDocumentStore: DocumentStore, @unchecked Sendable {
    private let directory: URL
    private let codec: PersistenceCodec
    private let lock = NSLock()

    init(directory: URL? = nil, codec: PersistenceCodec = PersistenceCodec()) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("heal", isDirectory: true)
        self.directory = base
        self.codec = codec
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    private func url(_ name: String) -> URL { directory.appendingPathComponent("\(name).json") }

    func load<T: Codable>(_ type: T.Type, name: String) -> T? {
        lock.lock(); defer { lock.unlock() }
        let file = url(name)
        guard let data = try? Data(contentsOf: file) else { return nil }
        do {
            return try codec.decode(type, from: data)
        } catch {
            let quarantine = directory.appendingPathComponent("\(name).corrupt.json")
            try? FileManager.default.removeItem(at: quarantine)
            try? FileManager.default.moveItem(at: file, to: quarantine)
            return nil
        }
    }

    func save<T: Codable>(_ value: T, name: String) throws {
        lock.lock(); defer { lock.unlock() }
        try codec.encode(value).write(to: url(name), options: .atomic)
    }

    func remove(name: String) {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: url(name))
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" { try? FileManager.default.removeItem(at: file) }
    }
}

// MARK: - In memory (tests, previews)

final class InMemoryDocumentStore: DocumentStore, @unchecked Sendable {
    private var files: [String: Data] = [:]
    private(set) var quarantined: [String] = []
    private let codec: PersistenceCodec
    private let lock = NSLock()

    init(codec: PersistenceCodec = PersistenceCodec()) { self.codec = codec }

    func load<T: Codable>(_ type: T.Type, name: String) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let data = files[name] else { return nil }
        do {
            return try codec.decode(type, from: data)
        } catch {
            files[name] = nil
            quarantined.append(name)
            return nil
        }
    }

    func save<T: Codable>(_ value: T, name: String) throws {
        let data = try codec.encode(value)
        lock.lock(); defer { lock.unlock() }
        files[name] = data
    }

    /// Test hook: overwrite a file with raw bytes (corrupt / old-schema simulation).
    func writeRaw(_ data: Data, name: String) {
        lock.lock(); defer { lock.unlock() }
        files[name] = data
    }

    func remove(name: String) {
        lock.lock(); defer { lock.unlock() }
        files[name] = nil
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        files.removeAll()
    }
}
