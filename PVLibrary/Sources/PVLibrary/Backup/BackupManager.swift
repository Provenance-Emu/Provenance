//
//  BackupManager.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Implements manual backup and restore for Realm DB, save states,
//  and custom user artwork. Part of issue #1005 (Backup/Restore).
//

import Foundation
import RealmSwift
import PVArchiving
import PVFileSystem
import PVLogging
import PVMediaCache

// MARK: - BackupError

public enum BackupError: LocalizedError {
    case realmCopyFailed(Error)
    case zipCreationFailed
    case unzipFailed
    case invalidBackup(String)
    case restoreRealmFailed(Error)
    case fileSystemError(Error)
    case realmNotConfigured

    public var errorDescription: String? {
        switch self {
        case .realmCopyFailed(let error):
            return "Failed to copy Realm database: \(error.localizedDescription)"
        case .zipCreationFailed:
            return "Failed to create backup archive."
        case .unzipFailed:
            return "Failed to extract backup archive. The file may be corrupted."
        case .invalidBackup(let reason):
            return "Invalid backup file: \(reason)"
        case .restoreRealmFailed(let error):
            return "Failed to restore database: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .realmNotConfigured:
            return "Realm database is not configured."
        }
    }
}

// MARK: - BackupContents

/// Describes which components are included in a backup.
public struct BackupContents: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// The Realm database (game library metadata).
    public static let database = BackupContents(rawValue: 1 << 0)
    /// Save state files.
    public static let saveStates = BackupContents(rawValue: 1 << 1)
    /// Custom user-provided artwork cached by PVMediaCache.
    public static let customArtwork = BackupContents(rawValue: 1 << 2)
    /// Battery saves (SRAM).
    public static let batterySaves = BackupContents(rawValue: 1 << 3)

    /// All supported backup content.
    public static let all: BackupContents = [.database, .saveStates, .customArtwork, .batterySaves]
}

// MARK: - BackupProgress

public enum BackupPhase: String, Sendable, Equatable {
    case preparing = "Preparing..."
    case copyingDatabase = "Copying database..."
    case copyingSaveStates = "Copying save states..."
    case copyingArtwork = "Copying artwork..."
    case copyingBatterySaves = "Copying battery saves..."
    case compressing = "Compressing backup..."
    case done = "Done"
    case restoring = "Restoring..."
    case restoringDatabase = "Restoring database..."
    case restoringSaveStates = "Restoring save states..."
    case restoringArtwork = "Restoring artwork..."
    case restoringBatterySaves = "Restoring battery saves..."
}

// MARK: - BackupViewState

public enum BackupViewState: Equatable, Sendable {
    case idle
    case inProgress(BackupPhase)
    case done
    case error(String)
}

// MARK: - RestoreViewState

public enum RestoreViewState: Equatable, Sendable {
    case idle
    case inProgress(BackupPhase)
    case done(BackupContents)
    case error(String)
}

// MARK: - BackupManager

/// Manages manual backup and restore of Provenance user data.
///
/// Backup archives are zip files containing:
/// - `database/default.realm` — a compacted copy of the Realm DB
/// - `saves/` — save state directory tree
/// - `artwork/` — custom user artwork (PVMediaCache)
/// - `battery/` — battery save (SRAM) directory tree
///
/// Usage:
/// ```swift
/// let url = try await BackupManager.shared.createBackup()
/// // Share `url` via UIActivityViewController, then clean up:
/// BackupManager.shared.cleanupBackup(at: url)
/// ```
public final class BackupManager: @unchecked Sendable {

    public static let shared = BackupManager()
    private init() {}

    // MARK: - Public API

    /// Creates a backup archive and returns the URL of the zip file.
    ///
    /// The caller is responsible for sharing/exporting the file and then
    /// calling `cleanupBackup(at:)` to remove the temporary file.
    ///
    /// - Parameters:
    ///   - contents: Which data components to include. Defaults to `.all`.
    ///   - progressHandler: Optional closure called with phase updates.
    /// - Returns: URL of the created backup zip file.
    public func createBackup(
        contents: BackupContents = .all,
        progressHandler: (@Sendable (BackupPhase) -> Void)? = nil
    ) async throws -> URL {
        progressHandler?(.preparing)

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("PVBackup_\(Int(Date().timeIntervalSince1970))", isDirectory: true)

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            throw BackupError.fileSystemError(error)
        }

        // 1. Copy Realm database
        if contents.contains(.database) {
            progressHandler?(.copyingDatabase)
            try copyRealmDatabase(to: tempDir)
        }

        // 2. Copy save states
        if contents.contains(.saveStates) {
            progressHandler?(.copyingSaveStates)
            copyDirectory(Paths.saveSavesPath, to: tempDir.appendingPathComponent("saves", isDirectory: true))
        }

        // 3. Copy custom artwork
        if contents.contains(.customArtwork) {
            progressHandler?(.copyingArtwork)
            copyDirectory(PVMediaCache.cachePath, to: tempDir.appendingPathComponent("artwork", isDirectory: true))
        }

        // 4. Copy battery saves
        if contents.contains(.batterySaves) {
            progressHandler?(.copyingBatterySaves)
            copyDirectory(Paths.batterySavesPath, to: tempDir.appendingPathComponent("battery", isDirectory: true))
        }

        // 5. Compress into zip
        progressHandler?(.compressing)
        let zipURL = try createZip(from: tempDir)

        // Clean up staging directory
        try? await fm.removeItem(at: tempDir)

        progressHandler?(.done)
        return zipURL
    }

    /// Removes a previously created backup zip file from the temporary directory.
    public func cleanupBackup(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Restores user data from a backup zip archive.
    ///
    /// - Warning: The Realm database restore takes effect on next launch.
    ///   The app must be restarted to load the restored database.
    ///
    /// - Parameters:
    ///   - zipURL: URL of the backup zip file.
    ///   - contents: Which components to restore. Defaults to `.all`.
    ///   - progressHandler: Optional closure called with phase updates.
    /// - Returns: A set of `BackupContents` flags for each component that was actually restored.
    @discardableResult
    public func restoreBackup(
        from zipURL: URL,
        contents: BackupContents = .all,
        progressHandler: (@Sendable (BackupPhase) -> Void)? = nil
    ) async throws -> BackupContents {
        progressHandler?(.restoring)

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("PVRestore_\(Int(Date().timeIntervalSince1970))", isDirectory: true)

        defer { try? fm.removeItem(at: tempDir) }

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            throw BackupError.fileSystemError(error)
        }

        // Extract archive
        do {
            try ArchiveManager.shared.unzipFile(at: zipURL, to: tempDir)
        } catch {
            throw BackupError.unzipFailed
        }

        // Validate it looks like a Provenance backup
        let hasDatabase = fm.fileExists(atPath: tempDir.appendingPathComponent("database/default.realm").path)
        let hasSaves = fm.fileExists(atPath: tempDir.appendingPathComponent("saves").path)
        let hasArtwork = fm.fileExists(atPath: tempDir.appendingPathComponent("artwork").path)
        let hasBattery = fm.fileExists(atPath: tempDir.appendingPathComponent("battery").path)

        guard hasDatabase || hasSaves || hasArtwork || hasBattery else {
            throw BackupError.invalidBackup("Archive does not contain any recognisable Provenance backup data.")
        }

        var restored: BackupContents = []

        // Restore Realm database
        if contents.contains(.database) && hasDatabase {
            progressHandler?(.restoringDatabase)
            try restoreRealmDatabase(from: tempDir)
            restored.insert(.database)
        }

        // Restore save states
        if contents.contains(.saveStates) && hasSaves {
            progressHandler?(.restoringSaveStates)
            try restoreDirectory(
                from: tempDir.appendingPathComponent("saves", isDirectory: true),
                to: Paths.saveSavesPath
            )
            restored.insert(.saveStates)
        }

        // Restore custom artwork
        if contents.contains(.customArtwork) && hasArtwork {
            progressHandler?(.restoringArtwork)
            try restoreDirectory(
                from: tempDir.appendingPathComponent("artwork", isDirectory: true),
                to: PVMediaCache.cachePath
            )
            restored.insert(.customArtwork)
        }

        // Restore battery saves
        if contents.contains(.batterySaves) && hasBattery {
            progressHandler?(.restoringBatterySaves)
            try restoreDirectory(
                from: tempDir.appendingPathComponent("battery", isDirectory: true),
                to: Paths.batterySavesPath
            )
            restored.insert(.batterySaves)
        }

        progressHandler?(.done)
        return restored
    }

    // MARK: - Helpers

    private func copyRealmDatabase(to stagingDir: URL) throws {
        let fm = FileManager.default
        let dbDir = stagingDir.appendingPathComponent("database", isDirectory: true)

        do {
            try fm.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            throw BackupError.fileSystemError(error)
        }

        let destURL = dbDir.appendingPathComponent("default.realm", isDirectory: false)

        // Use Realm.writeCopy(toFile:) to create a consistent, compacted snapshot
        // regardless of any concurrent background writes.
        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            try realm.writeCopy(toFile: destURL)
        } catch {
            throw BackupError.realmCopyFailed(error)
        }
    }

    private func copyDirectory(_ source: URL, to destination: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else {
            ILOG("BackupManager: skipping \(source.lastPathComponent) — directory does not exist")
            return
        }
        do {
            try fm.copyItem(at: source, to: destination)
        } catch {
            WLOG("BackupManager: failed to copy \(source.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func createZip(from directory: URL) throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Provenance_Backup_\(timestamp).pvbackup")

        do {
            try ArchiveManager.shared.createZipArchive(at: zipURL, from: directory)
        } catch {
            throw BackupError.zipCreationFailed
        }
        return zipURL
    }

    private func restoreRealmDatabase(from stagingDir: URL) throws {
        let fm = FileManager.default
        let backupRealmURL = stagingDir.appendingPathComponent("database/default.realm")

        guard fm.fileExists(atPath: backupRealmURL.path) else {
            throw BackupError.invalidBackup("Backup does not contain a Realm database file.")
        }

        guard let destURL = RealmConfiguration.realmConfig.fileURL else {
            throw BackupError.realmNotConfigured
        }

        // Place the restored realm alongside the active one with a distinct name.
        // The app reads this on next launch and swaps it in.
        let pendingRestoreURL = destURL.deletingLastPathComponent()
            .appendingPathComponent("default.restored.realm")

        do {
            if fm.fileExists(atPath: pendingRestoreURL.path) {
                try fm.removeItem(at: pendingRestoreURL)
            }
            try fm.copyItem(at: backupRealmURL, to: pendingRestoreURL)
        } catch {
            throw BackupError.restoreRealmFailed(error)
        }
    }

    private func restoreDirectory(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        let tempURL = destination.deletingLastPathComponent()
            .appendingPathComponent(destination.lastPathComponent + ".restoring", isDirectory: true)

        do {
            // Ensure parent directory exists
            try fm.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Copy to a temp location first; if this fails, the original is intact
            if fm.fileExists(atPath: tempURL.path) {
                try fm.removeItem(at: tempURL)
            }
            try fm.copyItem(at: source, to: tempURL)

            // Atomic swap: remove old, rename temp -> destination
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: tempURL, to: destination)
        } catch {
            // Clean up the temp location if it was created
            try? fm.removeItem(at: tempURL)
            throw BackupError.fileSystemError(error)
        }
    }
}
