//
//  SaveExporter.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Exports and imports per-game saves (battery saves + save states) as a zip bundle.
//  Part of issue #3409 (per-game save export/import).
//

import Foundation
import ZipArchive
import PVFileSystem
import PVLogging
import RealmSwift

// MARK: - SaveExportError

public enum SaveExportError: LocalizedError {
    case noSavesFound
    case zipCreationFailed
    case invalidBundle(String)
    case gameMismatch

    public var errorDescription: String? {
        switch self {
        case .noSavesFound:
            return "No saves found for this game."
        case .zipCreationFailed:
            return "Failed to create save export archive."
        case .invalidBundle(let reason):
            return "Invalid save bundle: \(reason)"
        case .gameMismatch:
            return "The selected save bundle belongs to a different game (MD5 mismatch)."
        }
    }
}

// MARK: - SaveExporter

/// Exports and imports per-game saves (battery saves + save states) as a zip bundle.
///
/// Export bundles have the layout:
/// ```
/// <Title>-saves.zip
///   manifest.json
///   battery/  — battery save files for this ROM
///   states/   — save state files (and screenshots)
/// ```
///
/// Usage:
/// ```swift
/// let url = try await SaveExporter.shared.exportSaves(for: game)
/// // share url, then:
/// SaveExporter.shared.cleanupExport(at: url)
/// ```
public final class SaveExporter: @unchecked Sendable {

    public static let shared = SaveExporter()
    private init() {}

    // MARK: - Export

    /// Exports saves for a game to a zip archive in the temp directory.
    ///
    /// - Parameter game: A `PVGame` object (frozen or live; frozen internally if not already).
    /// - Returns: URL of the created zip file. Caller is responsible for sharing and then calling `cleanupExport(at:)`.
    public func exportSaves(for game: PVGame) async throws -> URL {
        let frozenGame = game.isFrozen ? game : game.freeze()

        return try await Task.detached(priority: .userInitiated) {
            try self.performExport(frozenGame: frozenGame)
        }.value
    }

    private func performExport(frozenGame: PVGame) throws -> URL {
        guard !frozenGame.isInvalidated else {
            throw SaveExportError.invalidBundle("Game object is no longer valid.")
        }

        let fm = FileManager.default
        let gameTitle = frozenGame.title
        let md5 = frozenGame.md5Hash
        let systemID = frozenGame.systemIdentifier
        let romURL = frozenGame.file?.url

        // Collect save states snapshot before we leave Realm context
        let saveStateSnapshots: [(fileURL: URL?, imageURL: URL?)] = frozenGame.saveStates.map { state in
            (fileURL: state.file?.url, imageURL: state.image?.url)
        }

        let hasAnySave = saveStateSnapshots.contains(where: {
            guard let url = $0.fileURL else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        })
        let batterySavesDir = Paths.batterySavesPath(forROM: romURL)
        let hasBatterySaves = fm.fileExists(atPath: batterySavesDir.path)
            && ((try? fm.contentsOfDirectory(atPath: batterySavesDir.path))?.isEmpty == false)

        guard hasAnySave || hasBatterySaves else {
            throw SaveExportError.noSavesFound
        }

        // Create staging directory (UUID suffix ensures uniqueness for concurrent exports)
        let stagingDir = fm.temporaryDirectory
            .appendingPathComponent("PVSaveExport_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: stagingDir) }

        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        // Write manifest.json
        let isoDate = ISO8601DateFormatter().string(from: Date())
        let manifestDict: [String: String] = [
            "schemaVersion": "1",
            "game": md5,
            "title": gameTitle,
            "system": systemID,
            "exportDate": isoDate
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifestDict, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: stagingDir.appendingPathComponent("manifest.json"))

        // Track how many save files are actually copied so we can error if nothing ends up in the zip.
        var filesCopied = 0

        // Copy battery saves
        if hasBatterySaves {
            let destBattery = stagingDir.appendingPathComponent("battery", isDirectory: true)
            do {
                try fm.copyItem(at: batterySavesDir, to: destBattery)
                filesCopied += 1
            } catch {
                WLOG("SaveExporter: failed to copy battery saves: \(error.localizedDescription)")
            }
        }

        // Copy save state files
        if hasAnySave {
            let statesDir = stagingDir.appendingPathComponent("states", isDirectory: true)
            try fm.createDirectory(at: statesDir, withIntermediateDirectories: true)

            for snapshot in saveStateSnapshots {
                if let src = snapshot.fileURL, fm.fileExists(atPath: src.path) {
                    let dest = statesDir.appendingPathComponent(src.lastPathComponent)
                    do {
                        try fm.copyItem(at: src, to: dest)
                        filesCopied += 1
                    } catch {
                        WLOG("SaveExporter: failed to copy save state \(src.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                if let imgSrc = snapshot.imageURL, fm.fileExists(atPath: imgSrc.path) {
                    let imgDest = statesDir.appendingPathComponent(imgSrc.lastPathComponent)
                    do {
                        try fm.copyItem(at: imgSrc, to: imgDest)
                    } catch {
                        WLOG("SaveExporter: failed to copy save state screenshot \(imgSrc.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
        }

        // If every copy failed the zip would contain only manifest.json — treat as no saves
        guard filesCopied > 0 else {
            throw SaveExportError.noSavesFound
        }

        // Create zip
        let sanitizedTitle = gameTitle
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "-_ ")).inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
        let safeTitle = sanitizedTitle.isEmpty ? md5 : sanitizedTitle
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuidFragment = UUID().uuidString.prefix(8)
        let zipURL = fm.temporaryDirectory.appendingPathComponent("\(safeTitle)-saves-\(timestamp)-\(uuidFragment).zip")

        // Remove stale zip if present
        try? fm.removeItem(at: zipURL)

        let success = SSZipArchive.createZipFile(atPath: zipURL.path, withContentsOfDirectory: stagingDir.path)
        guard success else {
            throw SaveExportError.zipCreationFailed
        }

        ILOG("SaveExporter: created export at \(zipURL.path)")
        return zipURL
    }

    /// Removes a previously created export zip from the temporary directory.
    public func cleanupExport(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Import

    /// Imports saves from a zip bundle previously created by `exportSaves(for:)`.
    ///
    /// - Parameters:
    ///   - zipURL: URL of the `.zip` export bundle.
    ///   - game: The game to restore saves for. The bundle's manifest MD5 must match `game.md5Hash`.
    /// - Throws: `SaveExportError.gameMismatch` if the MD5 doesn't match.
    public func importSaves(from zipURL: URL, for game: PVGame) async throws {
        let frozenGame = game.isFrozen ? game : game.freeze()

        try await Task.detached(priority: .userInitiated) {
            try self.performImport(zipURL: zipURL, frozenGame: frozenGame)
        }.value
    }

    private func performImport(zipURL: URL, frozenGame: PVGame) throws {
        guard !frozenGame.isInvalidated else {
            throw SaveExportError.invalidBundle("Game object is no longer valid.")
        }

        let fm = FileManager.default
        // UUID suffix ensures uniqueness for concurrent or rapid-successive imports
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("PVSaveImport_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempDir) }

        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        guard SSZipArchive.unzipFile(atPath: zipURL.path, toDestination: tempDir.path) else {
            throw SaveExportError.invalidBundle("Failed to extract archive.")
        }

        // Read and validate manifest
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw SaveExportError.invalidBundle("Archive is missing manifest.json.")
        }

        let manifestData = try Data(contentsOf: manifestURL)
        guard let manifestDict = try JSONSerialization.jsonObject(with: manifestData) as? [String: String] else {
            throw SaveExportError.invalidBundle("manifest.json has unexpected format.")
        }

        guard let bundleMD5 = manifestDict["game"], !bundleMD5.isEmpty else {
            throw SaveExportError.invalidBundle("manifest.json missing 'game' field.")
        }

        guard bundleMD5.lowercased() == frozenGame.md5Hash.lowercased() else {
            WLOG("SaveExporter: MD5 mismatch — bundle '\(bundleMD5)' != game '\(frozenGame.md5Hash)'")
            throw SaveExportError.gameMismatch
        }

        let romURL = frozenGame.file?.url

        // Restore battery saves
        let srcBattery = tempDir.appendingPathComponent("battery", isDirectory: true)
        if fm.fileExists(atPath: srcBattery.path) {
            let destBattery = Paths.batterySavesPath(forROM: romURL)
            try restoreDirectory(from: srcBattery, to: destBattery)
        }

        // Restore save state files to disk.
        // NOTE: This does not register PVSaveState objects in Realm. Imported states will
        // only appear in the UI after a full library re-scan or app relaunch. A future
        // follow-up should call RomDatabase save-state registration helpers here.
        // See: https://github.com/Provenance-Emu/Provenance/issues/3409
        let srcStates = tempDir.appendingPathComponent("states", isDirectory: true)
        if fm.fileExists(atPath: srcStates.path) {
            let destStates = Paths.saveStatePath(forROM: romURL)
            // Ensure destination directory exists before copying individual files
            try fm.createDirectory(at: destStates, withIntermediateDirectories: true)
            let stateFiles = (try? fm.contentsOfDirectory(atPath: srcStates.path)) ?? []
            for fileName in stateFiles {
                let src = srcStates.appendingPathComponent(fileName)
                let dest = destStates.appendingPathComponent(fileName)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }
                do {
                    try fm.copyItem(at: src, to: dest)
                } catch {
                    WLOG("SaveExporter: failed to restore \(fileName): \(error.localizedDescription)")
                }
            }
        }

        ILOG("SaveExporter: import complete for game '\(frozenGame.title)'")
    }

    // MARK: - Helpers

    private func restoreDirectory(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            let items = (try? fm.contentsOfDirectory(atPath: source.path)) ?? []
            for item in items {
                let src = source.appendingPathComponent(item)
                let dest = destination.appendingPathComponent(item)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }
                try fm.copyItem(at: src, to: dest)
            }
        } catch {
            throw SaveExportError.invalidBundle("Failed to restore directory: \(error.localizedDescription)")
        }
    }
}
