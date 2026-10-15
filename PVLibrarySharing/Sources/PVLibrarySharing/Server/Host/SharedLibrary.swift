//
//  SharedLibrary.swift
//  PVLibrarySharing
//
//  What Provenance offers when it serves its library (spec §3.6).
//

import CryptoKit
import Foundation
import PVSystems

/// One file of a shared game.
public struct SharedFile: Sendable, Hashable {
    public var url: URL
    /// Path relative to the game's own folder ("Game.gdi", "track01.bin",
    /// "disc/track.bin"). The dialect turns it into the peer's layout.
    public var relativePath: String
    public var size: Int64

    public init(url: URL, relativePath: String, size: Int64) {
        self.url = url
        self.relativePath = relativePath
        self.size = size
    }

    public var fileName: String { (relativePath as NSString).lastPathComponent }
}

/// A game Provenance shares. ROM or disc image plus siblings only: no BIOS,
/// no saves, no states (spec §3.6).
public struct SharedGame: Sendable, Hashable, Identifiable {
    /// `PVGame.md5Hash` (Provenance's primary key).
    public var id: String
    public var title: String
    public var system: SystemIdentifier
    /// The library's MD5, sent lower-case for the peer's "In your library"
    /// badge. Best effort: for CD sets it's the index file's hash (§3.4).
    public var md5: String?
    /// GameCube/Wii game id ("GMSE01") when known; feeds iCube's stable key.
    public var serial: String?
    /// The primary file first, then its related files.
    public var files: [SharedFile]
    public var hasArtwork: Bool

    public init(
        id: String,
        title: String,
        system: SystemIdentifier,
        md5: String?,
        serial: String? = nil,
        files: [SharedFile],
        hasArtwork: Bool
    ) {
        self.id = id
        self.title = title
        self.system = system
        self.md5 = md5?.lowercased()
        self.serial = serial
        self.files = files
        self.hasArtwork = hasArtwork
    }

    public var sizeBytes: Int64 { files.reduce(0) { $0 + $1.size } }
    public var primaryFile: SharedFile? { files.first }
}

/// The app's side of serving: Realm and artwork live there, not here.
public protocol SharedLibraryProviding: Sendable {
    /// Games the owner shares right now: excluded games and systems are
    /// already left out. Called per catalogue request, so keep it cheap.
    func sharedGames() async -> [SharedGame]
    /// Cover art bytes (PNG or JPEG), or nil.
    func artwork(forGameId id: String) async -> Data?
}

/// Who is serving, as both peers' `SourceDevice` describes it.
public struct HostDevice: Sendable, Equatable {
    public var name: String
    /// "iOS" or "tvOS".
    public var platform: String
    public var appVersion: String

    public init(name: String, platform: String, appVersion: String) {
        self.name = name
        self.platform = platform
        self.appVersion = appVersion
    }
}

/// SHA-256 of shared files, computed on first pull and cached by
/// `(path, size, mtime)` so a re-pull doesn't re-read a gigabyte image
/// (spec §3.5, "Hashing"). Persisted as JSON when given a file.
public actor FileHashCache {
    private struct Key: Hashable, Codable {
        var path: String
        var size: Int64
        var modified: TimeInterval
    }

    private struct Entry: Codable {
        var key: Key
        var sha256: String
    }

    private let storeURL: URL?
    private var entries: [Key: String] = [:]
    private var loaded = false

    public init(storeURL: URL? = nil) {
        self.storeURL = storeURL
    }

    /// The lower-case hex SHA-256 of `url`.
    public func sha256(of url: URL) throws -> String {
        loadIfNeeded()
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let key = Key(
            path: url.standardizedFileURL.path,
            size: (attributes[.size] as? NSNumber)?.int64Value ?? 0,
            modified: (attributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0
        )
        if let cached = entries[key] { return cached }
        let hash = try FileSHA256.hex(of: url)
        entries = entries.filter { $0.key.path != key.path }
        entries[key] = hash
        save()
        return hash
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let storeURL, let data = try? Data(contentsOf: storeURL),
              let stored = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        for entry in stored { entries[entry.key] = entry.sha256 }
    }

    private func save() {
        guard let storeURL else { return }
        let stored = entries.map { Entry(key: $0.key, sha256: $0.value) }
        let folder = storeURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? JSONEncoder().encode(stored).write(to: storeURL, options: .atomic)
    }
}

/// Random tokens and digests shared by the dialect servers.
enum ServerTokens {
    /// 32 random bytes, base64url: a library bearer token.
    static func mint() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// A 32-byte auth nonce, as both peers make it.
    static func nonce() -> Data {
        Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
    }

    /// A 6-digit pairing code, zero-padded.
    static func pairingCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }

    static func digest(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The token of an `Authorization: Bearer <token>` header (scheme case-insensitive).
    static func bearer(_ header: String?) -> String? {
        guard let header else { return nil }
        let trimmed = header.trimmingCharacters(in: .whitespaces)
        let prefix = "bearer "
        guard trimmed.count > prefix.count, trimmed.prefix(prefix.count).lowercased() == prefix else { return nil }
        let token = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return token.isEmpty ? nil : token
    }
}
