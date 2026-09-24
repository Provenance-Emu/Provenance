//
//  LibraryIndex.swift
//  PVLibrarySnapshot
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  File-based, Realm-free index of the whole library for the Quick Look
//  extensions. Two JSON files in the App Group container, keyed by bare ROM
//  filename and bare save-state filename. Written by the host app
//  (WidgetDataWriter+Realm), read by PVQuickLookSupport.
//

import Foundation

public struct LibraryIndexGame: Codable, Sendable, Equatable {
    public let filename: String
    public let title: String
    public let systemName: String?
    public let systemIdentifier: String?
    public let developer: String?
    public let publishDate: String?
    public let genre: String?
    public let gameDescription: String?
    public let playCount: Int
    public let isFavorite: Bool
    /// Raw `PVMediaCache` key (the artwork URL string). `ArtworkResolver` hashes it.
    public let artworkKey: String?

    public init(filename: String, title: String, systemName: String?, systemIdentifier: String?,
                developer: String?, publishDate: String?, genre: String?, gameDescription: String?,
                playCount: Int, isFavorite: Bool, artworkKey: String?) {
        self.filename = filename
        self.title = title
        self.systemName = systemName
        self.systemIdentifier = systemIdentifier
        self.developer = developer
        self.publishDate = publishDate
        self.genre = genre
        self.gameDescription = gameDescription
        self.playCount = playCount
        self.isFavorite = isFavorite
        self.artworkKey = artworkKey
    }
}

public struct LibraryIndexSaveState: Codable, Sendable, Equatable {
    public let filename: String
    /// Path of the screenshot relative to the App Group container.
    public let imageRelativePath: String

    public init(filename: String, imageRelativePath: String) {
        self.filename = filename
        self.imageRelativePath = imageRelativePath
    }
}

public enum LibraryIndexPaths {
    public static let directory = "Library/Caches/LibraryIndex"
    public static let games = directory + "/games-by-filename.json"
    public static let saveStates = directory + "/savestates-by-filename.json"
}

public struct LibraryIndexWriter {
    private let containerURL: URL?

    public init(containerURL: URL? = LibrarySnapshotAppGroup.containerURL) {
        self.containerURL = containerURL
    }

    /// Atomic (temp file + rename). Returns false when the group is unavailable.
    @discardableResult
    public func write(games: [LibraryIndexGame], saveStates: [LibraryIndexSaveState]) -> Bool {
        guard let containerURL else { return false }
        var gamesByName: [String: LibraryIndexGame] = [:]
        for g in games where gamesByName[g.filename] == nil { gamesByName[g.filename] = g }
        var savesByName: [String: String] = [:]
        for s in saveStates where savesByName[s.filename] == nil { savesByName[s.filename] = s.imageRelativePath }

        let dir = containerURL.appendingPathComponent(LibraryIndexPaths.directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            try encoder.encode(gamesByName).write(to: containerURL.appendingPathComponent(LibraryIndexPaths.games), options: .atomic)
            try encoder.encode(savesByName).write(to: containerURL.appendingPathComponent(LibraryIndexPaths.saveStates), options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

/// Decodes lazily and once per instance. Create one per extension request.
public final class LibraryIndexReader: @unchecked Sendable {
    private let containerURL: URL?
    private lazy var games: [String: LibraryIndexGame] = load(LibraryIndexPaths.games) ?? [:]
    private lazy var saves: [String: String] = load(LibraryIndexPaths.saveStates) ?? [:]

    public init(containerURL: URL? = LibrarySnapshotAppGroup.containerURL) {
        self.containerURL = containerURL
    }

    public func game(forROMFilename filename: String) -> LibraryIndexGame? {
        guard !filename.isEmpty else { return nil }
        return games[filename]
    }

    public func saveStateImageURL(forFilename filename: String) -> URL? {
        guard !filename.isEmpty, let containerURL, let rel = saves[filename] else { return nil }
        return containerURL.appendingPathComponent(rel)
    }

    private func load<T: Decodable>(_ relativePath: String) -> T? {
        guard let containerURL,
              let data = try? Data(contentsOf: containerURL.appendingPathComponent(relativePath)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
