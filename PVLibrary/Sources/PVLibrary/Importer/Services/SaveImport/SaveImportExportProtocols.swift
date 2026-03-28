//
//  SaveImportExportProtocols.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-27.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Core protocols and value types for save import/export.
//  Part of issue #3552 (save import/export protocols foundation).
//

import Foundation

// MARK: - SaveFileCategory

/// Categories of save files that can be imported or exported.
public enum SaveFileCategory: String, CaseIterable, Codable, Sendable {
    /// Battery-backed SRAM — persistent in-game memory (`.sav`, `.srm`, `.ram`, `.dsv`).
    case sram
    /// Emulator save state — full CPU/RAM snapshot (`.svs`, `.state`, `.dvsave`, `.ppst`).
    case saveState
    /// Real-time clock data (`.rtc`).
    case rtc

    /// File extensions that map to this category (across all known emulators).
    public static let sramExtensions: Set<String>      = ["sav", "srm", "ram", "dsv"]
    public static let saveStateExtensions: Set<String> = [
        "svs", "state", "dvsave", "ppst",
        // RetroArch numbered save slots (state0–state9)
        "state0", "state1", "state2", "state3", "state4",
        "state5", "state6", "state7", "state8", "state9"
    ]
    public static let rtcExtensions: Set<String>       = ["rtc"]

    /// Infer the category from a file extension.
    public static func infer(fromExtension ext: String) -> SaveFileCategory {
        let lower = ext.lowercased()
        if saveStateExtensions.contains(lower) { return .saveState }
        if rtcExtensions.contains(lower)       { return .rtc }
        return .sram  // default — covers .sav/.srm/.ram and unknowns
    }
}

// MARK: - ExternalSaveFile

/// Represents a save file discovered from an external source (another emulator or manual import).
public struct ExternalSaveFile: Sendable {
    /// Location of the file (may be in a temporary directory — copy before use).
    public let url: URL
    /// Category of this save.
    public let category: SaveFileCategory
    /// The emulator that produced this file, if known.
    public let sourceEmulator: KnownEmulator?
    /// Best-guess ROM base name this save belongs to (filename without extension and region codes).
    public let romBasename: String
    /// File modification date.
    public let modifiedAt: Date

    public init(
        url: URL,
        category: SaveFileCategory,
        sourceEmulator: KnownEmulator?,
        romBasename: String,
        modifiedAt: Date
    ) {
        self.url = url
        self.category = category
        self.sourceEmulator = sourceEmulator
        self.romBasename = romBasename
        self.modifiedAt = modifiedAt
    }
}

// MARK: - SaveImportResult

/// Result returned after a successful save import operation.
public struct SaveImportResult: Sendable {
    /// Whether a battery/SRAM file was restored.
    public let sramRestored: Bool
    /// Number of save-state files registered in the library.
    public let statesRestored: Int
    /// Non-fatal warnings encountered during import (e.g. a file that could not be restored).
    public let warnings: [String]

    public init(sramRestored: Bool, statesRestored: Int, warnings: [String] = []) {
        self.sramRestored = sramRestored
        self.statesRestored = statesRestored
        self.warnings = warnings
    }
}

// MARK: - SaveExportResult

/// Result returned after a successful save export operation.
public struct SaveExportResult: Sendable {
    /// URL of the exported bundle (temporary — caller must share before app terminates or call `cleanupExport(at:)`).
    public let bundleURL: URL
    /// Whether battery/SRAM files were included.
    public let sramIncluded: Bool
    /// Number of save-state snapshots included.
    public let statesIncluded: Int

    public init(bundleURL: URL, sramIncluded: Bool, statesIncluded: Int) {
        self.bundleURL = bundleURL
        self.sramIncluded = sramIncluded
        self.statesIncluded = statesIncluded
    }
}

// MARK: - SaveBundleExporting

/// Implemented by services that can package game saves into a portable bundle.
public protocol SaveBundleExporting: Sendable {
    /// Export all saves (battery + save states) for a game to a bundle file.
    ///
    /// - Parameter gameID: The ROM MD5 hash (Realm primary key for `PVGame`).
    /// - Returns: A `SaveExportResult` containing the URL of the bundle and summary stats.
    /// - Throws: `SaveExportError` variants if no saves exist or archiving fails.
    func exportSaves(forGameID gameID: String) async throws -> SaveExportResult

    /// Export only the battery/SRAM save file(s) for a game.
    ///
    /// Produces a single file (preserving the original extension) if there is exactly one
    /// battery save, or a `.zip` archive if there are multiple (e.g. a `.sav` and a `.rtc`).
    ///
    /// - Parameter gameID: The ROM MD5 hash.
    /// - Returns: URL of the exported file (temporary — caller must clean up).
    func exportSRAM(forGameID gameID: String) async throws -> URL

    /// Removes a previously exported file from the temporary directory.
    func cleanupExport(at url: URL)
}

// MARK: - SaveBundleImporting

/// Implemented by services that can restore game saves from a portable bundle.
public protocol SaveBundleImporting: Sendable {
    /// Import saves from a bundle (`.pvsave` / `.zip`) for a specific game.
    ///
    /// - Parameters:
    ///   - bundleURL: URL of the bundle file.
    ///   - gameID: The ROM MD5 hash. Must match the bundle's manifest; throws `gameMismatch` otherwise.
    /// - Returns: A `SaveImportResult` summarising what was restored.
    func importSaves(from bundleURL: URL, forGameID gameID: String) async throws -> SaveImportResult

    /// Import a raw battery/SRAM file (`.sav`, `.srm`, `.ram`) for a specific game.
    ///
    /// - Parameters:
    ///   - sramURL: URL of the SRAM file.
    ///   - gameID: The ROM MD5 hash.
    func importSRAM(from sramURL: URL, forGameID gameID: String) async throws
}

// MARK: - SaveMatchConfidence

/// How confidently a save file was matched to a game in the library.
public enum SaveMatchConfidence: Int, Comparable, Sendable {
    /// MD5 of ROM matched the bundle manifest exactly.
    case exact    = 3
    /// Filename matched a game title (after stripping region/version info).
    case probable = 2
    /// No automatic match — user must select the game manually.
    case manual   = 1

    public static func < (lhs: SaveMatchConfidence, rhs: SaveMatchConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - SaveGameMatch

/// A candidate game match for an imported save file.
public struct SaveGameMatch: Sendable {
    /// MD5 of the matched game (Realm primary key).
    public let gameID: String
    /// Display title of the matched game.
    public let gameTitle: String
    /// How well this save file matches the game.
    public let confidence: SaveMatchConfidence

    public init(gameID: String, gameTitle: String, confidence: SaveMatchConfidence) {
        self.gameID = gameID
        self.gameTitle = gameTitle
        self.confidence = confidence
    }
}
