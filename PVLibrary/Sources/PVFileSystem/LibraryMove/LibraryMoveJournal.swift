//
//  LibraryMoveJournal.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  `move-journal.json`: which files of a move are done, so an interrupted move resumes on the
//  next launch and cleanup deletes only what was copied. Lives in the app's own Application
//  Support directory (never the App Group). Entries are keyed by path relative to the root
//  because app container paths change across app updates; roots are re-derived at resume.
//

import Foundation
import PVLogging

public struct LibraryMoveJournal: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public struct Entry: Codable, Sendable, Equatable {
        public enum State: String, Codable, Sendable {
            /// Copied to the destination and verified.
            case copied
            /// The destination already had an identical file; nothing was copied.
            case identical
            /// The destination had a different file; the incoming copy went to `destinationPath` under `Conflicts/`.
            case conflict
        }

        /// Size of the source file when it was copied.
        public var size: Int64
        public var md5: String?
        /// Modification date of the source file when it was copied. The post-switch delta sweep compares size and this.
        public var modified: Date?
        public var state: State
        /// Relative to the destination root. Set for `.conflict`, otherwise the key is the destination path.
        public var destinationPath: String?

        public init(size: Int64, md5: String?, modified: Date?, state: State, destinationPath: String?) {
            self.size = size
            self.md5 = md5
            self.modified = modified
            self.state = state
            self.destinationPath = destinationPath
        }
    }

    public var version: Int
    public var id: UUID
    public var source: LibraryLocation
    public var destination: LibraryLocation
    public var folders: [String]
    public var keepCopy: Bool
    public var phase: LibraryMovePhase
    public var createdAt: Date
    public var updatedAt: Date
    /// Relative source path → what happened to it.
    public var entries: [String: Entry]

    public init(request: LibraryMoveRequest, now: Date = Date()) {
        version = Self.currentVersion
        id = UUID()
        source = request.source
        destination = request.destination
        folders = request.folders
        keepCopy = request.keepCopy
        phase = .copying
        createdAt = now
        updatedAt = now
        entries = [:]
    }
}

extension LibraryLocation: Codable {}

/// Loads and saves the one journal. Atomic writes; a journal that can't be decoded is deleted.
public struct LibraryMoveJournalStore: Sendable {
    public static let fileName = "move-journal.json"
    static let directoryName = "LibraryMove"

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `<Application Support>/LibraryMove/move-journal.json` in this app's container.
    public static func defaultURL(fileManager: FileManager = .default) throws -> URL {
        let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return support.appendingPathComponent(directoryName, isDirectory: true).appendingPathComponent(fileName, isDirectory: false)
    }

    public func load() -> LibraryMoveJournal? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let journal = try? decoder.decode(LibraryMoveJournal.self, from: data), journal.version <= LibraryMoveJournal.currentVersion {
            return journal
        }
        WLOG("LibraryMove: discarding unreadable journal at \(url.path)")
        try? delete()
        return nil
    }

    public func save(_ journal: LibraryMoveJournal) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(journal).write(to: url, options: .atomic)
    }

    public func delete() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
