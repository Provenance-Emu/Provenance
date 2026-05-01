//
//  iCloudDriveRomsSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVPrimitives
import PVFileSystem
import PVRealm
import RealmSwift
import CloudKit

// MARK: - iOS/macOS Implementation

#if !os(tvOS)
/// ROM syncer for iOS/macOS using iCloud Documents
public class iCloudDriveRomsSyncer: iCloudContainerSyncer, RomsSyncing {
    /// Initialize a new ROM syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(directories: ["ROMs"], notificationCenter: notificationCenter, errorHandler: errorHandler)
    }

    /// Get the local URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The local URL for the ROM file
    public func localURL(for game: PVGame) -> URL? {
        guard let file = game.file else {
            return nil
        }

        return file.url
    }

    /// Get the cloud URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The cloud URL for the ROM file
    public func cloudURL(for game: PVGame) -> URL? {
        guard let file = game.file,
              let url = file.url,
              let containerURL = documentsURL else {
            return nil
        }

        let systemPath = (game.systemIdentifier as NSString)
        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
        return containerURL.appendingPathComponent("ROMs").appendingPathComponent(systemDir).appendingPathComponent(url.lastPathComponent)
    }

    /// Upload a ROM file to the cloud (Async Version)
    /// - Parameter game: The game to upload
    /// - Throws: CloudSyncError on failure
    public func uploadGame(_ md5: String) async throws {
        try await RealmProvider.ensureInitialized()
        let realm = try await Realm()
        guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
            throw CloudSyncError.invalidData
        }

        guard let localURL = self.localURL(for: game),
              let cloudURL = self.cloudURL(for: game) else {
            CloudSyncManager.syncLog.event(.upload, item: "roms/\(game.title)", status: .failed, detail: "Invalid ROM file or URLs for game: \(game.title)")
            throw CloudSyncError.invalidData
        }

        // Create directory if needed
        let cloudDir = cloudURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: cloudDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            CloudSyncManager.syncLog.event(.upload, item: "roms/directory", status: .failed, detail: "Failed to create iCloud directory \(cloudDir.path): \(error.localizedDescription)")
            throw CloudSyncError.fileSystemError(error)
        }

        // Copy file
        do {
            // Remove existing item at cloudURL if it exists before copying
            if FileManager.default.fileExists(atPath: cloudURL.path) {
                VLOG("Removing existing file at cloud destination: \(cloudURL.path)")
                try await FileManager.default.removeItem(at: cloudURL)
            }
            VLOG("Copying ROM from \(localURL.path) to \(cloudURL.path)")
            try FileManager.default.copyItem(at: localURL, to: cloudURL)
            CloudSyncManager.syncLog.event(.upload, item: "roms/\(localURL.lastPathComponent)", status: .ok, detail: "Successfully uploaded ROM \(localURL.lastPathComponent) to iCloud Drive.")
            // Update local game sync status? (Maybe CloudSyncManager responsibility?)
            // await RomDatabase.shared.updateGame(md5: game.md5Hash ?? "") { $0?.cloudStatus = .synced } // Example
        } catch {
            CloudSyncManager.syncLog.event(.upload, item: "roms/\(cloudURL.lastPathComponent)", status: .failed, detail: "Failed to copy ROM to iCloud Drive at \(cloudURL.path): \(error.localizedDescription)")
            throw CloudSyncError.fileSystemError(error)
        }
    }

    /// Download a ROM file from the cloud (Async Version)
    /// - Parameter md5: MD5 hash of the game to download
    /// - Throws: CloudSyncError on failure
    public func downloadGame(md5: String) async throws {
        // 1. Get the PVGame object from the datastore
        guard let game = RomDatabase.sharedInstance.object(ofType: PVGame.self, wherePrimaryKeyEquals: md5) else {
            CloudSyncManager.syncLog.event(.download, item: "roms/\(md5)", status: .failed, detail: "Cannot download game: PVGame with MD5 \(md5) not found in local database.")
            // Use .invalidData as the game mapping failed
            throw CloudSyncError.invalidData
        }

        guard let cloudURL = self.cloudURL(for: game),
              let localURL = self.localURL(for: game) else {
             CloudSyncManager.syncLog.event(.download, item: "roms/\(md5)", status: .failed, detail: "Could not determine cloud or local URL for game MD5: \(md5)")
             throw CloudSyncError.invalidData
        }

        // 2. Check if file exists in the cloud
        guard FileManager.default.fileExists(atPath: cloudURL.path) else {
            CloudSyncManager.syncLog.event(.download, item: "roms/\(md5)", status: .failed, detail: "ROM file not found in iCloud Drive at \(cloudURL.path) for MD5: \(md5)")
            // Use .invalidData as the expected cloud file is missing
            throw CloudSyncError.invalidData
        }

        // 3. Create local directory if needed
        let localDir = localURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            CloudSyncManager.syncLog.event(.download, item: "roms/directory", status: .failed, detail: "Failed to create local directory \(localDir.path): \(error.localizedDescription)")
            throw CloudSyncError.fileSystemError(error)
        }

        // 4. Copy file from cloud to local
        do {
            // Remove existing local file first to ensure clean copy
            if FileManager.default.fileExists(atPath: localURL.path) {
                VLOG("Removing existing local file before download: \(localURL.path)")
                try await FileManager.default.removeItem(at: localURL)
            }
            VLOG("Downloading ROM from \(cloudURL.path) to \(localURL.path)")
            try FileManager.default.copyItem(at: cloudURL, to: localURL)
            CloudSyncManager.syncLog.event(.download, item: "roms/\(localURL.lastPathComponent)", status: .ok, detail: "Successfully downloaded ROM \(localURL.lastPathComponent) from iCloud Drive.")

            // Use a Realm write transaction to update the game properties.
            // Inline realm.write here (instead of going through writeTransaction)
            // so the fetch and mutation both happen on the same Realm instance
            // that owns the active write transaction.
            do {
                let realm = Thread.isMainThread ? RomDatabase.sharedInstance.realm : try Realm(configuration: RealmConfiguration.realmConfig)
                try realm.write {
                    if let gameToUpdate = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) {
                        gameToUpdate.isDownloaded = true
                        gameToUpdate.lastCloudSyncDate = Date()
                    } else {
                        CloudSyncManager.syncLog.event(.download, item: "roms/\(md5)", status: .skipped, detail: "Game with MD5 \(md5) not found during sync status update (success).")
                    }
                }
            } catch {
                WLOG("Failed to update game sync status (success path) for \(md5): \(error.localizedDescription)")
            }
            NotificationCenter.default.post(name: .romDownloadCompleted, object: game)
        } catch {
            CloudSyncManager.syncLog.event(.download, item: "roms/\(cloudURL.lastPathComponent)", status: .failed, detail: "Failed to copy ROM from iCloud Drive at \(cloudURL.path): \(error.localizedDescription)")
            // If download failed, ensure local file doesn't exist in partial state
            if FileManager.default.fileExists(atPath: localURL.path) {
                try? await FileManager.default.removeItem(at: localURL)
            }
            // Use a Realm write transaction to update the game properties.
            // Inline realm.write here (instead of going through writeTransaction)
            // so the fetch and mutation both happen on the same Realm instance
            // that owns the active write transaction.
            do {
                let realm = Thread.isMainThread ? RomDatabase.sharedInstance.realm : try Realm(configuration: RealmConfiguration.realmConfig)
                try realm.write {
                    if let gameToUpdate = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) {
                        gameToUpdate.isDownloaded = false
                        // We don't have an error state, just mark as not downloaded
                    } else {
                        CloudSyncManager.syncLog.event(.download, item: "roms/\(md5)", status: .skipped, detail: "Game with MD5 \(md5) not found during sync status update (error).")
                    }
                }
            } catch {
                WLOG("Failed to update game sync status (error path) for \(md5): \(error.localizedDescription)")
            }
            throw CloudSyncError.fileSystemError(error)
        }
    }

    /// Marks a game as deleted by removing its file from iCloud Drive.
    /// - Parameter md5: The MD5 hash of the game to delete.
    /// - Throws: CloudSyncError if the game or file cannot be found or deletion fails.
    public func markGameAsDeleted(md5: String) async throws {
        VLOG("Attempting to mark game as deleted (delete file) in iCloud Drive for MD5: \(md5)")

        // 1. Get the PVGame object from the datastore
        guard let game = RomDatabase.sharedInstance.object(ofType: PVGame.self, wherePrimaryKeyEquals: md5) else {
            // If the game isn't local, we can't determine the cloud path to delete.
            // We could potentially query CloudKit metadata if it existed, but for iCloud Drive, we rely on the local entry.
            CloudSyncManager.syncLog.event(.delete, item: "roms/\(md5)", status: .skipped, detail: "Cannot mark game as deleted: PVGame with MD5 \(md5) not found locally.")
            // Consider if this should be an error or just a warning.
            // If called during a sync reconcile, maybe it's okay if local is gone?
            // For now, let's treat not finding the local game as ignorable.
            return
        }

        // 2. Determine the Cloud URL
        guard let cloudURL = self.cloudURL(for: game) else {
             CloudSyncManager.syncLog.event(.delete, item: "roms/\(md5)", status: .failed, detail: "Could not determine cloud URL for game MD5: \(md5). Cannot delete.")
             throw CloudSyncError.invalidData
        }

        // 3. Check if the file exists in iCloud Drive
        guard FileManager.default.fileExists(atPath: cloudURL.path) else {
            CloudSyncManager.syncLog.event(.delete, item: "roms/\(md5)", status: .skipped, detail: "Cloud file for game MD5 \(md5) at \(cloudURL.path) does not exist. Assuming already deleted.")
            // File is already gone, so consider the deletion successful/unnecessary.
            return
        }

        // 4. Attempt to delete the file
        do {
            VLOG("Deleting ROM file from iCloud Drive: \(cloudURL.path)")
            try await FileManager.default.removeItem(at: cloudURL)
            CloudSyncManager.syncLog.event(.delete, item: "roms/\(cloudURL.lastPathComponent)", status: .ok, detail: "Successfully deleted ROM file \(cloudURL.lastPathComponent) from iCloud Drive for MD5: \(md5).")

            // TODO: Update local game sync status if necessary?
            // Perhaps set cloudStatus = .deleted ? Needs a new status.
            // Or maybe CloudSyncManager handles local deletion after this completes.

        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            // If we checked existence and it's gone now, treat as success (race condition?)
            CloudSyncManager.syncLog.event(.delete, item: "roms/\(cloudURL.lastPathComponent)", status: .skipped, detail: "File \(cloudURL.path) was not found during deletion attempt (maybe already deleted): \(error.localizedDescription)")
            // Consider this case as successfully deleted.
        } catch {
            CloudSyncManager.syncLog.event(.delete, item: "roms/\(cloudURL.lastPathComponent)", status: .failed, detail: "Failed to delete ROM file from iCloud Drive at \(cloudURL.path): \(error.localizedDescription)")
            throw CloudSyncError.fileSystemError(error)
        }
    }
}
#endif
