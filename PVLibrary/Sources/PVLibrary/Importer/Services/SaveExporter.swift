//
//  SaveExporter.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Exports and imports per-game saves (battery saves + save states) as a .pvsave bundle.
//  Schema v2 adds per-save metadata and Realm registration on import.
//  Part of issue #3554 (enhanced .pvsave bundle format + Realm registration on import).
//

import Foundation
import ZipArchive
import PVFileSystem
import PVLogging
import PVRealm
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

/// Exports and imports per-game saves (battery saves + save states) as a `.pvsave` bundle.
///
/// Export bundles have the layout:
/// ```
/// <Title>-saves.pvsave          (zip-format archive with .pvsave extension)
///   manifest.json               (schema v2)
///   battery/  — battery save files for this ROM
///   states/   — .svs save state files (and .jpg screenshots)
/// ```
///
/// Backward compatibility: import also accepts old `.zip` schema v1 bundles.
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
///   a game MD5 to a `PVGame` without caller-side Realm access.
///   Tracked in: https://github.com/Provenance-Emu/Provenance/issues/3409
public final class SaveExporter: @unchecked Sendable {

    public static let shared = SaveExporter()
    private init() {}

    // MARK: - Export

    /// Exports saves for a game to a `.pvsave` archive in the temp directory.
    ///
    /// - Parameter game: A `PVGame` object (frozen or live; frozen internally if not already).
    /// - Returns: URL of the created `.pvsave` file. Caller is responsible for sharing and then calling `cleanupExport(at:)`.
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

        // Snapshot save-state URLs before leaving Realm context (frozen object access is safe
        // across threads, but iterating the live List is not).
        struct SaveStateSnapshot {
            let fileURL: URL?
            let imageURL: URL?
            let date: Date
            let isAutosave: Bool
            let userDescription: String?
            let coreIdentifier: String?
        }
        let saveStateSnapshots: [SaveStateSnapshot] = frozenGame.saveStates.map { state in
            SaveStateSnapshot(
                fileURL: state.file?.url,
                imageURL: state.image?.url,
                date: state.date,
                isAutosave: state.isAutosave,
                userDescription: state.userDescription,
                coreIdentifier: state.core?.identifier
            )
        }

        let hasAnySave = saveStateSnapshots.contains(where: {
            guard let url = $0.fileURL else { return false }
            return fm.fileExists(atPath: url.path)
        })
        // Guard against nil romURL: Paths.batterySavesPath(forROM: nil) falls back to a shared
        // ".../Battery States/NULL" directory that could contain unrelated games' saves.
        let batterySavesDir: URL? = romURL.map { Paths.batterySavesPath(forROM: $0) }
        let hasBatterySaves: Bool = {
            guard let dir = batterySavesDir else { return false }
            guard fm.fileExists(atPath: dir.path) else { return false }
            let visibleFiles = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            return visibleFiles?.isEmpty == false
        }()

        guard hasAnySave || hasBatterySaves else {
            throw SaveExportError.noSavesFound
        }

        // Create staging directory (UUID suffix ensures uniqueness for concurrent exports)
        let stagingDir = fm.temporaryDirectory
            .appendingPathComponent("PVSaveExport_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: stagingDir) }

        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let iso8601 = ISO8601DateFormatter()

        // Build battery saves index (skip hidden files such as .DS_Store)
        let batteryEntries: [SaveBundleManifestV2.BatterySaveEntry]? = {
            guard let dir = batterySavesDir,
                  let fileURLs = try? fm.contentsOfDirectory(
                      at: dir, includingPropertiesForKeys: [.fileSizeKey],
                      options: .skipsHiddenFiles) else { return nil }
            return fileURLs.map { fileURL in
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                return SaveBundleManifestV2.BatterySaveEntry(
                    filename: fileURL.lastPathComponent, sizeBytes: size)
            }
        }()

        // Track how many save files are actually copied so we can error if nothing ends up in the zip.
        var filesCopied = 0
        var stateEntries: [SaveBundleManifestV2.SaveStateEntry] = []

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

        // Copy save state files and build the v2 manifest index in a single pass.
        if hasAnySave {
            let statesDir = stagingDir.appendingPathComponent("states", isDirectory: true)
            try fm.createDirectory(at: statesDir, withIntermediateDirectories: true)

            for snapshot in saveStateSnapshots {
                guard let src = snapshot.fileURL, fm.fileExists(atPath: src.path) else { continue }

                let dest = statesDir.appendingPathComponent(src.lastPathComponent)
                do {
                    try fm.copyItem(at: src, to: dest)
                    filesCopied += 1

                    // Attempt screenshot copy first so screenshotFilename in the manifest only
                    // references a file that was actually placed in the bundle.
                    var copiedScreenshotFilename: String?
                    if let imgSrc = snapshot.imageURL, fm.fileExists(atPath: imgSrc.path) {
                        let imgDest = statesDir.appendingPathComponent(imgSrc.lastPathComponent)
                        do {
                            try fm.copyItem(at: imgSrc, to: imgDest)
                            copiedScreenshotFilename = imgSrc.lastPathComponent
                        } catch {
                            WLOG("SaveExporter: failed to copy save state screenshot \(imgSrc.lastPathComponent): \(error.localizedDescription)")
                        }
                    }

                    // Only add a manifest entry for successfully copied states.
                    stateEntries.append(SaveBundleManifestV2.SaveStateEntry(
                        filename: src.lastPathComponent,
                        screenshotFilename: copiedScreenshotFilename,
                        date: iso8601.string(from: snapshot.date),
                        isAutosave: snapshot.isAutosave,
                        userDescription: snapshot.userDescription,
                        coreIdentifier: snapshot.coreIdentifier
                    ))
                } catch {
                    WLOG("SaveExporter: failed to copy save state \(src.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        // Write manifest.json using schema v2
        let isoDate = iso8601.string(from: Date())
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

        // If every copy failed the zip would contain only manifest.json — treat as no saves
        guard filesCopied > 0 else {
            throw SaveExportError.noSavesFound
        }

        // Create .pvsave archive (zip format, .pvsave extension)
        let sanitizedTitle = gameTitle
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "-_ ")).inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
        let safeTitle = sanitizedTitle.isEmpty ? md5 : sanitizedTitle
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuidFragment = UUID().uuidString.prefix(8)
        let pvsaveURL = fm.temporaryDirectory.appendingPathComponent("\(safeTitle)-saves-\(timestamp)-\(uuidFragment).pvsave")

        // Remove stale file if present
        try? fm.removeItem(at: pvsaveURL)

        let success = SSZipArchive.createZipFile(atPath: pvsaveURL.path, withContentsOfDirectory: stagingDir.path)
        guard success else {
            throw SaveExportError.zipCreationFailed
        }

        ILOG("SaveExporter: created export at \(pvsaveURL.path)")
        return pvsaveURL
    }

    /// Removes a previously created export bundle from the temporary directory.
    public func cleanupExport(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Import

    /// Imports saves from a `.pvsave` bundle (or legacy `.zip` v1 bundle) and registers
    /// imported save states in Realm so they appear in the UI immediately.
    ///
    /// Accepts:
    /// - Schema v2 `.pvsave` bundles (produced by this exporter)
    /// - Schema v1 `.zip` bundles (backward compatibility)
    ///
    /// For v2 bundles each `.svs` file is registered as a `PVSaveState` in Realm using
    /// per-save metadata from the manifest.  For v1 bundles, files are restored to disk
    /// only (no Realm registration — requires a library re-scan to surface in UI).
    ///
    /// - Parameters:
    ///   - zipURL: URL of the `.pvsave` or `.zip` export bundle.
    ///   - game: The game to restore saves for. Must have an associated ROM file URL, and the
    ///     bundle's manifest MD5 must match `game.md5Hash`.
    /// - Throws: `SaveExportError.gameMismatch` if the MD5 doesn't match,
    ///   or `SaveExportError.invalidBundle` if the game has no ROM file path.
    public func importSaves(from zipURL: URL, for game: PVGame) async throws {
        let frozenGame = game.isFrozen ? game : game.freeze()
        let gameID = frozenGame.md5Hash

        try await Task.detached(priority: .userInitiated) {
            try self.performImport(zipURL: zipURL, frozenGame: frozenGame)
        }.value

        // Realm registration is performed on the main actor after files are restored.
        // We re-fetch the game from Realm (thawed) to ensure a live reference.
        await registerImportedSaveStates(for: gameID, bundleURL: zipURL)
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

        // Restore save state files to disk
        let srcStates = tempDir.appendingPathComponent("states", isDirectory: true)
        if fm.fileExists(atPath: srcStates.path) {
            let destStates = Paths.saveStatePath(forROM: romURL)
            try fm.createDirectory(at: destStates, withIntermediateDirectories: true)
            let stateFiles = (try? fm.contentsOfDirectory(
                at: srcStates, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                .map(\.lastPathComponent)) ?? []
            for fileName in stateFiles {
                guard SaveBundleManifestV2.isSafeFilename(fileName) else {
                    WLOG("SaveExporter: skipping unsafe filename in states/: \(fileName)")
                    continue
                }
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

        ILOG("SaveExporter: file restore complete for game '\(frozenGame.title)'")
    }

    // MARK: - Realm Registration on Import

    /// Registers imported `.svs` files as `PVSaveState` objects in Realm.
    ///
    /// For v2 bundles, uses per-save metadata from the manifest.
    /// For v1 bundles or when the manifest is unavailable, falls back to a
    /// filesystem scan via `RomDatabase.recoverSaveStates(forPath:)`.
    @MainActor
    private func registerImportedSaveStates(for gameMD5: String, bundleURL: URL) async {
        do {
            let realm = try await Realm(configuration: RealmConfiguration.realmConfig)
            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: gameMD5) else {
                WLOG("SaveExporter: cannot register imported saves — game not found for MD5 \(gameMD5)")
                return
            }

            // Attempt to peek at the bundle manifest for v2 per-save entries
            let entries = savedEntriesFromBundle(at: bundleURL)

            if !entries.isEmpty {
                let romURL: URL? = game.file?.url
                guard let romURL else {
                    WLOG("SaveExporter: cannot register imported saves — game has no ROM URL")
                    return
                }
                let destStates = Paths.saveStatePath(forROM: romURL)
                let fm = FileManager.default

                for entry in entries {
                    let svsURL = destStates.appendingPathComponent(entry.filename)
                    guard fm.fileExists(atPath: svsURL.path) else {
                        WLOG("SaveExporter: imported .svs not found at \(svsURL.path), skipping registration")
                        continue
                    }

                    guard let coreID = entry.coreIdentifier,
                          let core = realm.object(ofType: PVCore.self, forPrimaryKey: coreID) else {
                        WLOG("SaveExporter: core '\(entry.coreIdentifier ?? "nil")' not installed, skipping Realm registration for \(entry.filename)")
                        continue
                    }

                    // Skip if already registered (same file path)
                    let alreadyRegistered = game.saveStates.contains(where: {
                        $0.file?.url?.lastPathComponent == entry.filename
                    })
                    if alreadyRegistered {
                        DLOG("SaveExporter: save '\(entry.filename)' already in Realm, skipping")
                        continue
                    }

                    let saveFile = PVFile(withURL: svsURL, relativeRoot: .iCloud)

                    var imageFile: PVImageFile?
                    if let imgName = entry.screenshotFilename {
                        let imgURL = destStates.appendingPathComponent(imgName)
                        if fm.fileExists(atPath: imgURL.path) {
                            imageFile = PVImageFile(withURL: imgURL)
                        }
                    }

                    let date: Date
                    if let dateStr = entry.date, let parsed = ISO8601DateFormatter().date(from: dateStr) {
                        date = parsed
                    } else {
                        date = Date()
                    }

                    let saveState = PVSaveState(
                        withGame: game,
                        core: core,
                        file: saveFile,
                        date: date,
                        image: imageFile,
                        isAutosave: entry.isAutosave ?? false,
                        userDescription: entry.userDescription
                    )

                    try realm.write {
                        realm.add(saveState)
                    }
                    NotificationCenter.default.post(
                        name: .PVSaveStateSaved,
                        object: nil,
                        userInfo: ["saveStateID": saveState.id]
                    )
                    ILOG("SaveExporter: registered imported save '\(entry.filename)' in Realm as \(saveState.id)")
                }
            } else {
                // v1 bundle or empty saves array — fall back to filesystem scan
                if let romFileURL = game.file?.url {
                    let saveStatePath = Paths.saveStatePath(forROM: romFileURL)
                    ILOG("SaveExporter: v1 bundle — triggering save state recovery for \(saveStatePath.path)")
                    RomDatabase.sharedInstance.recoverSaveStates(forPath: saveStatePath)
                }
            }
        } catch {
            ELOG("SaveExporter: Realm registration failed — \(error.localizedDescription)")
        }
    }

    /// Extracts `SaveBundleManifestV2.SaveStateEntry` records from a v2 bundle manifest
    /// without fully extracting the archive.
    ///
    /// Returns an empty array if the bundle is v1 or lacks a `saveStates` array.
    private func savedEntriesFromBundle(at url: URL) -> [SaveBundleManifestV2.SaveStateEntry] {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("PVManifestPeek_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempDir) }

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            guard SSZipArchive.unzipFile(atPath: url.path, toDestination: tempDir.path) else {
                return []
            }
            try validateNoBundleEscape(in: tempDir)

            let manifestURL = tempDir.appendingPathComponent("manifest.json")
            guard fm.fileExists(atPath: manifestURL.path),
                  let data = try? Data(contentsOf: manifestURL) else {
                return []
            }

            if let v2 = try? SaveBundleManifestV2.parse(from: data), v2.schemaVersion == 2 {
                return v2.saveStates ?? []
            }
            return []
        } catch {
            WLOG("SaveExporter: failed to peek bundle manifest: \(error)")
            return []
        }
    }

    // MARK: - Manifest Inspection

    /// Reads the `manifest.json` embedded in a save-export bundle and returns
    /// the MD5 hash of the game the bundle belongs to.
    ///
    /// Accepts both v1 `.zip` and v2 `.pvsave` bundles.
    ///
    /// - Parameter zipURL: URL of the `.pvsave` or `.zip` save-export bundle.
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
            guard fm.fileExists(atPath: manifestURL.path),
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
    func validateNoBundleEscape(in directory: URL) throws {
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
              let items = try? fm.contentsOfDirectory(
                  at: batteryDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                  .map(\.lastPathComponent),
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
        // Directory creation failure is fatal — we cannot restore without a destination.
        do {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            throw SaveExportError.invalidBundle("Failed to create restore directory: \(error.localizedDescription)")
        }

        // Skip hidden files (e.g. .DS_Store) when restoring
        let items = (try? fm.contentsOfDirectory(
            at: source, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .map(\.lastPathComponent)) ?? []
        for item in items {
            guard SaveBundleManifestV2.isSafeFilename(item) else {
                WLOG("SaveExporter: skipping unsafe filename in battery/: \(item)")
                continue
            }
            let src = source.appendingPathComponent(item)
            let dest = destination.appendingPathComponent(item)
            if fm.fileExists(atPath: dest.path) {
                try? fm.removeItem(at: dest)
            }
            do {
                try fm.copyItem(at: src, to: dest)
            } catch {
                WLOG("SaveExporter: failed to restore \(item): \(error.localizedDescription)")
            }
        }
    }
}
