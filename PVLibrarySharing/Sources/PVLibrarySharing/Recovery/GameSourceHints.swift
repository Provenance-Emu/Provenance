//
//  GameSourceHints.swift
//  PVLibrarySharing
//
//  Which library a game was last copied from, so recovery asks it first.
//

import Foundation

public struct GameSourceHint: Sendable, Equatable, Codable {
    public var app: PeerApp
    /// The peer's id, or a content server's URL string.
    public var sourceIdentity: String
    public var remoteItemID: String
    public var files: [MissingGameFile]
    /// The remote MD5 when the file on disk is a different version from the one imported.
    public var standInMD5: String?

    public init(app: PeerApp, sourceIdentity: String, remoteItemID: String, files: [MissingGameFile], standInMD5: String?) {
        self.app = app
        self.sourceIdentity = sourceIdentity
        self.remoteItemID = remoteItemID
        self.files = files
        self.standInMD5 = standInMD5
    }
}

/// A JSON file of hints by game MD5. Only an optimisation: tvOS may purge it with the
/// library, and a missing or unreadable file is an empty store.
public actor GameSourceHints {
    public static let fileName = "game-source-hints.json"

    private let fileURL: URL
    private var hints: [String: GameSourceHint]?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func hint(forMD5 md5: String) -> GameSourceHint? {
        loaded()[md5.uppercased()]
    }

    public func record(_ hint: GameSourceHint, forMD5 md5: String) {
        var all = loaded()
        all[md5.uppercased()] = hint
        save(all)
    }

    public func remove(md5: String) {
        var all = loaded()
        guard all.removeValue(forKey: md5.uppercased()) != nil else { return }
        save(all)
    }

    private func loaded() -> [String: GameSourceHint] {
        if let hints { return hints }
        let read = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode([String: GameSourceHint].self, from: $0) }
        hints = read ?? [:]
        return read ?? [:]
    }

    private func save(_ all: [String: GameSourceHint]) {
        hints = all
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(all).write(to: fileURL, options: .atomic)
    }
}
