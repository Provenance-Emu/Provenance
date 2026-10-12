//
//  LibraryMoveTypes.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Value types shared by the move engine, its journal and its callers.
//  Spec: docs/superpowers/specs/2026-10-11-library-storage-locations-design.md ("Moving between locations").
//

import Foundation

/// Names the move engine treats specially. Which folders move is decided by the caller
/// (see `LibraryMovePlanner.topLevelEntries(at:)`), not by a fixed list.
public enum LibraryMoveFolders {
    /// Folders whose files are MD5-verified after copying (size alone for the rest).
    public static let md5Verified: Set<String> = ["ROMs", "BIOS"]

    /// What a picked folder holds (the shared layout contract: `ROMs/<system id>/`, `BIOS/`, `System/<console>/`).
    public static let shared: [String] = ["ROMs", "BIOS", "System"]

    /// What a picked folder holds in addition when `PickedLibraryFolder.includesSaves` is on (D10).
    public static let saves: [String] = ["Battery States", "Save States", "Screenshots", "Cheats", "Patches"]

    /// `true` when the partial path's first component is one of `shared`.
    public static func isShared(partialPath: String) -> Bool {
        let trimmed = partialPath.hasPrefix("/") ? String(partialPath.dropFirst()) : partialPath
        guard let top = trimmed.split(separator: "/", maxSplits: 1).first else { return false }
        return shared.contains(String(top))
    }

    /// Where the loser of a name clash goes: the destination's own file (copy phase) or the incoming file (post-switch sweep).
    public static let conflicts = "Conflicts"

    /// Prefix of the keys, in the App Group's shared defaults, under which each app (by bundle id) records the
    /// `LibraryLocation` it last launched on.
    public static let variantLocationKeyPrefix = "libraryLocation."

    /// Top-level names the planner never moves, whatever the folder list says.
    static let neverMoved: Set<String> = ["move-journal.json"]
    static let realmMarker = ".realm"
}

/// What to move. Roots are passed in so the engine can be tested against temp directories.
public struct LibraryMoveRequest: Sendable, Equatable {
    public let source: LibraryLocation
    public let destination: LibraryLocation
    public let sourceRoot: URL
    public let destinationRoot: URL
    /// Top-level names (folders, or loose files) under the roots.
    public let folders: [String]
    /// Leave the source files in place after the switch ("Keep a copy in the old location").
    public let keepCopy: Bool
    /// The picked folder being left (`source == .pickedFolder`); lets a resume after the switch re-resolve it.
    public let sourceFolder: PickedLibraryFolder?
    /// The picked folder being moved to (`destination == .pickedFolder`); stored by the switch.
    public let destinationFolder: PickedLibraryFolder?
    /// Phase 4: journal `ROMs/` and `BIOS/` files that already exist in the destination under another name instead of copying them.
    public let deduplicateByMD5: Bool

    public init(source: LibraryLocation, destination: LibraryLocation, sourceRoot: URL, destinationRoot: URL, folders: [String], keepCopy: Bool,
                sourceFolder: PickedLibraryFolder? = nil, destinationFolder: PickedLibraryFolder? = nil, deduplicateByMD5: Bool = false) {
        self.source = source
        self.destination = destination
        self.sourceRoot = sourceRoot
        self.destinationRoot = destinationRoot
        self.folders = folders
        self.keepCopy = keepCopy
        self.sourceFolder = sourceFolder
        self.destinationFolder = destinationFolder
        self.deduplicateByMD5 = deduplicateByMD5
    }
}

/// Where a move is. Persisted in the journal, so the raw values are a contract.
public enum LibraryMovePhase: String, Codable, Sendable {
    /// Files are being copied and verified. Cancel rolls back.
    case copying
    /// The settings name the destination; it applies at the next launch. Sources are still intact.
    case switched
    /// The launch after the switch: delta sweep, then delete journaled sources.
    case cleaning
}

public struct LibraryMoveProgress: Sendable, Equatable {
    public let phase: LibraryMovePhase
    public let filesDone: Int
    public let filesTotal: Int
    public let bytesDone: Int64
    public let bytesTotal: Int64
    public let currentPath: String?

    public init(phase: LibraryMovePhase, filesDone: Int, filesTotal: Int, bytesDone: Int64, bytesTotal: Int64, currentPath: String? = nil) {
        self.phase = phase
        self.filesDone = filesDone
        self.filesTotal = filesTotal
        self.bytesDone = bytesDone
        self.bytesTotal = bytesTotal
        self.currentPath = currentPath
    }

    public var fraction: Double {
        bytesTotal > 0 ? Double(bytesDone) / Double(bytesTotal) : (filesTotal > 0 ? Double(filesDone) / Double(filesTotal) : 1)
    }
}

public enum LibraryMoveOutcome: Sendable, Equatable {
    /// Copy verified and the setting written; the new location applies at the next launch.
    case switched
    /// The post-switch cleanup finished and the journal is gone.
    case cleanedUp
    /// Cancelled before the switch; the destination was rolled back.
    case cancelled
}

public enum LibraryMoveError: Error, Equatable, LocalizedError {
    case unsupportedMove(from: LibraryLocation, to: LibraryLocation)
    case rootUnavailable(LibraryLocation)
    case insufficientSpace(required: Int64, available: Int64)
    case verificationFailed(relativePath: String)
    case moveInProgress

    public var errorDescription: String? {
        switch self {
        case .unsupportedMove(let from, let to): return "Moving the library from \(from.rawValue) to \(to.rawValue) is not supported yet."
        case .rootUnavailable(let location): return "The \(location.rawValue) folder is not available."
        case .insufficientSpace(let required, let available): return "Not enough free space: \(required) bytes needed, \(available) available."
        case .verificationFailed(let path): return "\(path) did not copy correctly."
        case .moveInProgress: return "A library move is already running."
        }
    }
}
