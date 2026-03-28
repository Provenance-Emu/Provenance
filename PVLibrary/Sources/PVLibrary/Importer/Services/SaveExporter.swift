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
/// `@unchecked Sendable` is safe here: `SaveExporter` has no mutable stored properties —
/// it is a stateless singleton whose methods operate only on task-local values and parameters.
///
/// - TODO: Conform to `SaveBundleExporting` and `SaveBundleImporting` (defined in
///   `SaveImportExportProtocols.swift`) once a Realm lookup helper is available to resolve
///   a game MD5 to a `PVGame` without caller-side Realm access. See issue #3552.
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
        // Guard against nil romURL: Paths.batterySavesPath(forROM: nil) falls back to a shared
        // ".../Battery States/NULL" directory that could contain unrelated games' saves.
        let batterySavesDir: URL? = romURL.map { Paths.batterySavesPath(forROM: $0) }
        let hasBatterySaves: Bool = {
            guard let dir = batterySavesDir else { return false }
            return fm.fileExists(atPath: dir.path)
                && ((try? fm.contentsOfDirectory(atPath: dir.path))?.isEmpty == false)
        }()

        guard hasAnySave || hasBatterySaves else {
            throw SaveExportError.noSavesFound
        }

        // Create staging directory (UUID suffix ensures uniqueness for concurrent exports)
        let stagingDir = fm.temporaryDirectory
            .appendingPathComponent("PVSaveExport_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: stagingDir) }

        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        // Build per-save-state index for the v2 manifest
        let stateISO = ISO8601DateFormatter()
        let stateEntries: [SaveBundleManifestV2.SaveStateEntry] = frozenGame.saveStates.compactMap { state in
            guard let fileURL = state.file?.url,
                  fm.fileExists(atPath: fileURL.path) else { return nil }
            return SaveBundleManifestV2.SaveStateEntry(
                filename: fileURL.lastPathComponent,
                screenshotFilename: state.image?.url?.lastPathComponent,
                date: stateISO.string(from: state.date),
                isAutosave: state.isAutosave,
                userDescription: state.userDescription,
                coreIdentifier: state.core?.identifier
            )
        }

        // Build battery saves index
        let batteryEntries: [SaveBundleManifestV2.BatterySaveEntry]? = {
            guard let dir = batterySavesDir,
                  let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return nil }
            return files.map { filename in
                let fileURL = dir.appendingPathComponent(filename)
                let size = (try? fm.attributesOfItem(atPath: fileURL.path))?[.size] as? Int
                return SaveBundleManifestV2.BatterySaveEntry(filename: filename, sizeBytes: size)
            }
        }()

        // Write manifest.json using schema v2
        let isoDate = ISO8601DateFormatter().string(from: Date())
        let manifest = SaveBundleManifestV2(
            gameMD5: md5,
            gameTitle: gameTitle,
            systemIdentifier: systemID,
            exportDate: isoDate,
            batterySaves: batteryEntries,
            saveStates: stateEntries.isEmpty ? nil : stateEntries
        )
        let manifestData = try manifest.jsonData()
        try manifestData.write(to: stagingDir.appendingPathComponent("manifest.json"))

        // Track how many save files are actually copied so we can error if nothing ends up in the zip.
        var filesCopied = 0

        // Copy battery saves (batterySavesDir is non-nil only when romURL was valid)
        if let srcBatteryDir = batterySavesDir, hasBatterySaves {
            let destBattery = stagingDir.appendingPathComponent("battery", isDirectory: true)
            do {
                try fm.copyItem(at: srcBatteryDir, to: destBattery)
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
    /// **File-restore only:** This method copies save files to their expected locations on disk
    /// but does **not** register `PVSaveState` objects in Realm. Imported save states will not
    /// appear in the UI until a library re-scan or app relaunch. See issue #3409 for follow-up.
    ///
    /// - Parameters:
    ///   - zipURL: URL of the `.zip` export bundle.
    ///   - game: The game to restore saves for. Must have an associated ROM file URL, and the
    ///     bundle's manifest MD5 must match `game.md5Hash`.
    /// - Throws: `SaveExportError.gameMismatch` if the MD5 doesn't match,
    ///   or `SaveExportError.invalidBundle` if the game has no ROM file path.
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
        // Defense-in-depth: verify no extracted entry escaped tempDir.
        try validateNoBundleEscape(in: tempDir)

        // Read and validate manifest
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw SaveExportError.invalidBundle("Archive is missing manifest.json.")
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest: SaveBundleManifestV2
        do {
            manifest = try SaveBundleManifestV2.parse(from: manifestData)
        } catch let parseError as SaveBundleManifestParseError {
            throw SaveExportError.invalidBundle(parseError.localizedDescription)
        }

        guard !manifest.gameMD5.isEmpty else {
            throw SaveExportError.invalidBundle("manifest.json missing game MD5.")
        }

        guard manifest.gameMD5.lowercased() == frozenGame.md5Hash.lowercased() else {
            WLOG("SaveExporter: MD5 mismatch — bundle '\(manifest.gameMD5)' != game '\(frozenGame.md5Hash)'")
            throw SaveExportError.gameMismatch
        }

        // Guard: Paths.batterySavesPath(forROM: nil) and saveStatePath(forROM: nil) both fall
        // back to a shared ".../NULL" directory. Importing there would overwrite unrelated saves.
        guard let romURL = frozenGame.file?.url else {
            throw SaveExportError.invalidBundle("Cannot import saves — game has no associated ROM file path.")
        }

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

    // MARK: - Manifest Inspection

    /// Reads the `manifest.json` embedded in a save-export bundle and returns
    /// the MD5 hash of the game the bundle belongs to.
    ///
    /// Implementation note: the entire zip archive is extracted to a temporary directory,
    /// `manifest.json` is read and parsed, and then the temporary directory is removed.
    /// For large save bundles this may be relatively expensive in terms of I/O and disk space.
    ///
    /// - Parameter zipURL: URL of the `.zip` save-export bundle.
    /// - Returns: The lowercase MD5 hash string from the manifest, or `nil` if the
    ///   archive is not a valid save-export bundle (e.g. missing manifest, wrong format).
    public func gameMD5(inBundleAt zipURL: URL) -> String? {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("PVManifestPeek_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempDir) }

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            guard SSZipArchive.unzipFile(atPath: zipURL.path, toDestination: tempDir.path) else {
                return nil
            }
            // Defense-in-depth: verify no extracted entry escaped tempDir via symlinks or traversal paths.
            try validateNoBundleEscape(in: tempDir)
            let manifestURL = tempDir.appendingPathComponent("manifest.json")
            // Guard against path traversal: ensure the manifest URL resolves inside tempDir.
            let tempDirResolved = tempDir.resolvingSymlinksInPath().path
            let manifestResolved = manifestURL.resolvingSymlinksInPath().path
            guard manifestResolved.hasPrefix(tempDirResolved + "/"),
                  fm.fileExists(atPath: manifestURL.path),
                  let data = try? Data(contentsOf: manifestURL),
                  let parsed = try? SaveBundleManifestV2.parse(from: data),
                  !parsed.gameMD5.isEmpty else {
                return nil
            }
            return parsed.gameMD5.lowercased()
        } catch {
            WLOG("SaveExporter: failed to read bundle manifest: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    /// Validates that every file/symlink extracted into `directory` resolves to a path
    /// within that directory, guarding against Zip Slip / path traversal in untrusted archives.
    ///
    /// - Throws: `SaveExportError.invalidBundle` if any entry resolves outside `directory`.
    private func validateNoBundleEscape(in directory: URL) throws {
        let resolvedBase = directory.resolvingSymlinksInPath().path
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: directory,
                                              includingPropertiesForKeys: [.isSymbolicLinkKey],
                                              options: [.skipsPackageDescendants]) else { return }
        for case let fileURL as URL in enumerator {
            let realPath = fileURL.resolvingSymlinksInPath().path
            guard realPath == resolvedBase || realPath.hasPrefix(resolvedBase + "/") else {
                throw SaveExportError.invalidBundle("Archive contains a path traversal entry: \(fileURL.lastPathComponent)")
            }
        }
    }

    // MARK: - SRAM-Only Export

    /// Exports only the battery/SRAM save file(s) for a game.
    ///
    /// Produces a single bare `.srm` file if exactly one battery save exists,
    /// or a `.zip` archive containing all battery files (e.g. `.sav` + `.rtc`) if multiple.
    ///
    /// - Parameter game: A `PVGame` object (frozen or live).
    /// - Returns: URL of the exported file (temporary — caller must clean up).
    /// - Throws: `SaveExportError.noSavesFound` if no battery saves exist,
    ///   `SaveExportError.invalidBundle` if the game has no ROM path.
    public func exportSRAM(for game: PVGame) async throws -> URL {
        let frozenGame = game.isFrozen ? game : game.freeze()
        return try await Task.detached(priority: .userInitiated) {
            try self.performSRAMExport(frozenGame: frozenGame)
        }.value
    }

    private func performSRAMExport(frozenGame: PVGame) throws -> URL {
        guard !frozenGame.isInvalidated else {
            throw SaveExportError.invalidBundle("Game object is no longer valid.")
        }
        guard let romURL = frozenGame.file?.url else {
            throw SaveExportError.invalidBundle("Game has no associated ROM file — cannot locate battery saves.")
        }

        let fm = FileManager.default
        let batteryDir = Paths.batterySavesPath(forROM: romURL)
        guard fm.fileExists(atPath: batteryDir.path),
              let items = try? fm.contentsOfDirectory(atPath: batteryDir.path),
              !items.isEmpty else {
            throw SaveExportError.noSavesFound
        }

        let gameTitle = frozenGame.title
        let sanitized = gameTitle
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "-_ ")).inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
        let safeTitle = sanitized.isEmpty ? frozenGame.md5Hash : sanitized
        let timestamp = Int(Date().timeIntervalSince1970)

        // Single file — export bare (no zip wrapper)
        if items.count == 1, let filename = items.first {
            let srcURL = batteryDir.appendingPathComponent(filename)
            let ext = srcURL.pathExtension
            let destURL = fm.temporaryDirectory
                .appendingPathComponent("\(safeTitle)-battery-\(timestamp).\(ext)")
            try? fm.removeItem(at: destURL)
            try fm.copyItem(at: srcURL, to: destURL)
            ILOG("SaveExporter: SRAM export (single) → \(destURL.lastPathComponent)")
            return destURL
        }

        // Multiple files — zip them together
        let stagingDir = fm.temporaryDirectory
            .appendingPathComponent("PVSRAMExport_\(timestamp)_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: stagingDir) }
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        for item in items {
            let src = batteryDir.appendingPathComponent(item)
            let dest = stagingDir.appendingPathComponent(item)
            try fm.copyItem(at: src, to: dest)
        }

        let zipURL = fm.temporaryDirectory.appendingPathComponent("\(safeTitle)-battery-\(timestamp).zip")
        try? fm.removeItem(at: zipURL)
        guard SSZipArchive.createZipFile(atPath: zipURL.path, withContentsOfDirectory: stagingDir.path) else {
            throw SaveExportError.zipCreationFailed
        }
        ILOG("SaveExporter: SRAM export (multi) → \(zipURL.lastPathComponent)")
        return zipURL
    }

    // MARK: - SRAM-Only Import

    /// Imports a raw battery/SRAM file (`.sav`, `.srm`, `.ram`, `.rtc`) for a game.
    ///
    /// Copies the file to the game's battery saves directory.
    /// Does not modify Realm — battery saves are picked up automatically at next emulator launch.
    ///
    /// - Parameters:
    ///   - sramURL: URL of the SRAM file to import.
    ///   - game: The game to associate the save with. Must have an associated ROM file.
    /// - Throws: `SaveExportError.invalidBundle` if the game has no ROM path.
    public func importSRAM(from sramURL: URL, for game: PVGame) async throws {
        let frozenGame = game.isFrozen ? game : game.freeze()
        try await Task.detached(priority: .userInitiated) {
            try self.performSRAMImport(sramURL: sramURL, frozenGame: frozenGame)
        }.value
    }

    private func performSRAMImport(sramURL: URL, frozenGame: PVGame) throws {
        guard !frozenGame.isInvalidated else {
            throw SaveExportError.invalidBundle("Game object is no longer valid.")
        }
        guard let romURL = frozenGame.file?.url else {
            throw SaveExportError.invalidBundle("Cannot import battery save — game has no associated ROM file path.")
        }

        let fm = FileManager.default
        let destDir = Paths.batterySavesPath(forROM: romURL)
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        let destURL = destDir.appendingPathComponent(sramURL.lastPathComponent)
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        try fm.copyItem(at: sramURL, to: destURL)
        ILOG("SaveExporter: SRAM import → \(destURL.path)")
    }

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
