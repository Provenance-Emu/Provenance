//
//  MissingGameRestorer.swift
//  PVLibrarySharing
//
//  Puts a verified copy from staging into the holes a library game has. Never overwrites.
//

import Foundation

/// A file of the game and where the library expects it.
public struct RestoreTarget: Sendable, Equatable {
    public var file: MissingGameFile
    public var url: URL

    public init(file: MissingGameFile, url: URL) {
        self.file = file
        self.url = url
    }
}

public struct RestoreResult: Sendable, Equatable {
    /// Targets that were missing and now hold the staged file.
    public var restored: [URL]
    /// Targets that already had a file, before or during the restore. They were left alone.
    public var alreadyPresent: [URL]
}

public enum MissingGameRestoreError: Error, Equatable, LocalizedError {
    /// A missing file of the game has no counterpart in the copy.
    case fileSetMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .fileSetMismatch(let name):
            return "The copy does not include “\(name)”."
        }
    }
}

public enum MissingGameRestorer {
    static let temporaryPrefix = ".recovering-"

    /// Moves each staged file to its target when nothing is there.
    ///
    /// An exact copy pairs staged files with targets by name, ignoring case. A stand-in for a
    /// one-file game puts its one file at the target whatever it is called, so the library's
    /// record of the path stays true. Throws before moving anything when a missing target has
    /// no staged file.
    public static func restore(
        _ pulled: PulledGame,
        to targets: [RestoreTarget],
        kind: RecoveryMatchKind,
        staging: LibraryStaging,
        fileManager: FileManager = .default
    ) throws -> RestoreResult {
        try restore(pulled, to: targets, kind: kind, staging: staging, fileManager: fileManager, beforePlacing: nil)
    }

    static func restore(
        _ pulled: PulledGame,
        to targets: [RestoreTarget],
        kind: RecoveryMatchKind,
        staging: LibraryStaging,
        fileManager: FileManager,
        beforePlacing: ((URL) -> Void)?
    ) throws -> RestoreResult {
        var staged: [String: URL] = [:]
        for url in pulled.gameFiles { staged[url.lastPathComponent.lowercased()] = url }
        let onlyFile = kind == .standIn && targets.count == 1 && pulled.gameFiles.count == 1 ? pulled.gameFiles.first : nil

        var result = RestoreResult(restored: [], alreadyPresent: [])
        var moves: [(source: URL, target: URL)] = []
        for target in targets {
            if fileManager.fileExists(atPath: target.url.path) {
                result.alreadyPresent.append(target.url)
            } else if let source = staged[target.file.name.lowercased()] ?? onlyFile {
                moves.append((source, target.url))
            } else {
                throw MissingGameRestoreError.fileSetMismatch(target.file.name)
            }
        }

        for move in moves {
            let folder = move.target.deletingLastPathComponent()
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            // Two steps, so a half-written file never sits at the game's path. The second is a
            // rename that fails when something is there.
            let temporary = folder.appendingPathComponent(temporaryPrefix + UUID().uuidString)
            try fileManager.moveItem(at: move.source, to: temporary)
            beforePlacing?(move.target)
            do {
                try fileManager.moveItem(at: temporary, to: move.target)
                result.restored.append(move.target)
            } catch {
                try? fileManager.removeItem(at: temporary)
                guard fileManager.fileExists(atPath: move.target.path) else { throw error }
                result.alreadyPresent.append(move.target)
            }
        }
        staging.markHandedOff(pulled.folder)
        return result
    }
}
