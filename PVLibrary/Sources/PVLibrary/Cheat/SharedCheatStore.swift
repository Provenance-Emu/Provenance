/// App Group-backed persistent store for shared cheat codes.
///
/// Writes a JSON file into the `group.org.provenance-emu.provenance` App Group
/// container so that cheat codes saved in the main Provenance app can be read
/// by the companion app, extensions, and vice-versa.
///
/// All reads and writes are serialised through the actor to prevent data races
/// when multiple targets access the store concurrently.
///
/// ## Usage
/// ```swift
/// let store = SharedCheatStore()
/// try await store.add(SharedCheatEntry(
///     name: "Infinite Lives",
///     code: "9999-5EC0",
///     format: "Game Genie",
///     systemName: "Super Nintendo",
///     gameName: "Super Mario World"
/// ))
/// let all = try await store.loadAll()
/// ```

import Foundation

// MARK: - SharedCheatEntry

/// A cheat code that can be shared across apps in the Provenance App Group.
public struct SharedCheatEntry: Codable, Identifiable, Sendable, Equatable {
    /// Stable UUID; persisted across saves.
    public let id: UUID
    /// Human-readable name (e.g. "Infinite Lives").
    public let name: String
    /// The raw cheat code string (e.g. "9999-5EC0", "04000000 0000270F").
    public let code: String
    /// Format identifier (e.g. "Game Genie", "GameShark", "Action Replay").
    public let format: String
    /// Friendly system name (e.g. "Super Nintendo", "PlayStation").
    public let systemName: String
    /// The game this cheat is associated with.
    public let gameName: String
    /// ISO 8601 date the entry was added.
    public let addedDate: Date

    public init(
        id: UUID = UUID(),
        name: String,
        code: String,
        format: String,
        systemName: String,
        gameName: String,
        addedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.format = format
        self.systemName = systemName
        self.gameName = gameName
        self.addedDate = addedDate
    }
}

// MARK: - QR URL encoding

extension SharedCheatEntry {
    /// The `provenance-cheat://` URL that encodes this entry's data for QR code generation.
    ///
    /// Format: `provenance-cheat://v1?name=…&code=…&format=…&system=…&game=…`
    public var qrURLString: String {
        var comps = URLComponents()
        comps.scheme = "provenance-cheat"
        comps.host = "v1"
        comps.queryItems = [
            URLQueryItem(name: "name",   value: name),
            URLQueryItem(name: "code",   value: code),
            URLQueryItem(name: "format", value: format),
            URLQueryItem(name: "system", value: systemName),
            URLQueryItem(name: "game",   value: gameName),
        ]
        return comps.url?.absoluteString ?? "provenance-cheat://v1?code=\(code)"
    }

    /// Attempts to parse a `provenance-cheat://v1` URL back into a `SharedCheatEntry`.
    ///
    /// - Parameter urlString: A string previously produced by ``qrURLString``.
    /// - Returns: A new entry, or `nil` if the URL is malformed or missing required fields.
    public static func from(qrURLString urlString: String) -> SharedCheatEntry? {
        guard
            let url = URL(string: urlString),
            url.scheme == "provenance-cheat",
            url.host == "v1",
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let items = comps.queryItems
        else { return nil }

        func value(for key: String) -> String? {
            items.first(where: { $0.name == key })?.value
        }

        guard
            let code   = value(for: "code"),
            let format = value(for: "format"),
            let system = value(for: "system"),
            let game   = value(for: "game")
        else { return nil }

        return SharedCheatEntry(
            name:       value(for: "name") ?? code,
            code:       code,
            format:     format,
            systemName: system,
            gameName:   game
        )
    }
}

// MARK: - SharedCheatStore

/// Actor-isolated, App Group-backed cheat code repository.
public actor SharedCheatStore {

    // MARK: - Constants

    /// The primary App Group shared by all Provenance targets.
    public static let appGroupIdentifier = "group.org.provenance-emu.provenance"

    /// JSON file name within the App Group container.
    static let fileName = "shared-cheats.json"

    // MARK: - Private state

    private let fileURL: URL?
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    // MARK: - Init

    /// Initialise with the standard App Group container.
    ///
    /// - Parameter groupIdentifier: Override the App Group ID (useful in tests).
    public init(groupIdentifier: String = SharedCheatStore.appGroupIdentifier) {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) {
            self.fileURL = containerURL.appendingPathComponent(SharedCheatStore.fileName)
        } else {
            // App Group not available (e.g. simulator without entitlements) — store is a no-op.
            self.fileURL = nil
        }
    }

    /// Initialise with an explicit file URL (useful for testing without App Group entitlements).
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    // MARK: - Public API

    /// Load all cheat entries from the shared container.
    ///
    /// Returns an empty array if the file does not yet exist.
    /// - Throws: `DecodingError` if the file is present but corrupt.
    public func loadAll() throws -> [SharedCheatEntry] {
        guard let url = fileURL else { return [] }
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try decoder.decode([SharedCheatEntry].self, from: data)
    }

    /// Append a new cheat entry, deduplicating by ID.
    ///
    /// If an entry with the same `id` already exists it is replaced.
    /// - Throws: `DecodingError` if the existing file is corrupt; `EncodingError` / write error if the file cannot be updated.
    public func add(_ entry: SharedCheatEntry) throws {
        var entries = try loadAll()
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        try save(entries)
    }

    /// Remove a cheat entry by its UUID.
    ///
    /// - Throws: `DecodingError` if the existing file is corrupt; `EncodingError` / write error if the file cannot be updated.
    public func remove(id: UUID) throws {
        var entries = try loadAll()
        entries.removeAll { $0.id == id }
        try save(entries)
    }

    /// Replace all stored cheats with the provided array.
    ///
    /// - Throws: `EncodingError` / write error if the file cannot be saved.
    public func replaceAll(with entries: [SharedCheatEntry]) throws {
        try save(entries)
    }

    // MARK: - Private helpers

    private func save(_ entries: [SharedCheatEntry]) throws {
        guard let url = fileURL else { return }
        let data = try encoder.encode(entries)
        try data.write(to: url, options: .atomic)
    }
}
