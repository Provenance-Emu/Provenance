//
//  LocalGameSyncMonitor.swift
//  PVLibrary
//
//  Created by Cascade on 2025-04-29.
//

import Foundation
import CloudKit
import RealmSwift
import PVLogging
import PVRealm
import PVSupport

/// Monitors local Realm database changes for PVGame objects and triggers
/// CloudKit uploads/updates accordingly.
public final class LocalGameSyncMonitor {

    // Realm instance used for observation. Created when monitoring starts.
    private var realm: Realm?
    private let romsSyncer: CloudKitRomsSyncer
    private var notificationToken: NotificationToken?
    private var gamesResults: Results<PVGame>?

    /// Initializes the monitor.
    /// - Parameters:
    ///   - romsSyncer: The `CloudKitRomsSyncer` instance used to perform CloudKit operations.
    public init(romsSyncer: CloudKitRomsSyncer) {
        self.romsSyncer = romsSyncer
        VLOG("LocalGameSyncMonitor initialized.")
    }

    deinit {
        stopMonitoring()
        VLOG("LocalGameSyncMonitor deinitialized.")
    }

    /// Starts observing Realm changes for PVGame objects.
    public func startMonitoring() {
        guard notificationToken == nil else {
            WLOG("Monitoring already started.")
            return
        }

        VLOG("Starting Realm observation for PVGame...")
        do {
            // Create a Realm instance specifically for this monitor's observation
            // Assumes default Realm configuration is appropriate.
            let realmInstance = try Realm()
            self.realm = realmInstance // Store the instance

            gamesResults = realmInstance.objects(PVGame.self).filter("contentless == false")

            notificationToken = gamesResults?.observe { [weak self] (changes: RealmCollectionChange) in
                guard let self = self else { return }
                self.handleRealmChanges(changes)
            }
            ILOG("Successfully started Realm observation for PVGame.")
        } catch {
            ELOG("Failed to start Realm observation: \(error)")
            // Handle error appropriately - perhaps retry?
            stopMonitoring() // Ensure partial setup is cleaned up
        }
    }

    /// Stops observing Realm changes.
    public func stopMonitoring() {
        VLOG("Stopping Realm observation for PVGame...")
        notificationToken?.invalidate()
        notificationToken = nil
        gamesResults = nil
        realm = nil // Release Realm instance when stopping
        ILOG("Stopped Realm observation for PVGame.")
    }

    /// Handles the changes received from the Realm notification block.
    private func handleRealmChanges(_ changes: RealmCollectionChange<Results<PVGame>>) {
        guard let currentResults = gamesResults else {
            ELOG("Received Realm changes but results object is nil. Stopping monitoring.")
            stopMonitoring()
            return
        }

        switch changes {
        case .initial:
            // Results are now populated and ready
            VLOG("Realm observation initial results received for PVGame (count: \(currentResults.count)).")
            // Potentially trigger an initial consistency check here if needed,
            // but CloudKitInitialSyncer likely handles the first full sync.
            break

        case .update(_, let deletions, let insertions, let modifications):
            // Handle Insertions
            if !insertions.isEmpty {
                VLOG("Processing \(insertions.count) PVGame insertions...")
                for index in insertions {
                    guard index < currentResults.count else {
                        WLOG("Insertion index \(index) out of bounds (count \(currentResults.count)). Skipping.")
                        continue
                    }
                    let insertedGame = currentResults[index]
                    if insertedGame.contentless {
                        VLOG("Skipping CloudKit upload for contentless placeholder game insert: \(insertedGame.title)")
                        continue
                    }
                    let md5 = insertedGame.md5Hash.uppercased()
                    Task {
                        do {
                            VLOG("Realm insertion detected for \(md5). Triggering CloudKit upload.")
                            try await self.romsSyncer.uploadGame(md5)
                            VLOG("CloudKit upload task completed for inserted game \(md5).")
                        } catch {
                            ELOG("Error uploading newly inserted game \(md5) to CloudKit: \(error)")
                            // TODO: Implement retry logic or flag for later sync?
                        }
                    }
                }
            }

            // Handle Modifications
            if !modifications.isEmpty {
                VLOG("Processing \(modifications.count) PVGame modifications...")
                for index in modifications {
                    guard index < currentResults.count else {
                        WLOG("Modification index \(index) out of bounds (count \(currentResults.count)). Skipping.")
                        continue
                    }
                    let modifiedGame = currentResults[index]
                    if modifiedGame.contentless {
                        VLOG("Skipping CloudKit upload for contentless placeholder game modification: \(modifiedGame.title)")
                        continue
                    }
                    let md5 = modifiedGame.md5Hash

                    // Skip if game is marked as not downloaded (likely downloading/syncing)
                    if !modifiedGame.isDownloaded {
                        VLOG("Skipping upload for \(md5): Game marked as not downloaded (likely syncing)")
                        continue
                    }

                    // Skip if file doesn't exist (can't upload what isn't there)
                    guard let fileURL = modifiedGame.file?.url,
                          FileManager.default.fileExists(atPath: fileURL.path) else {
                        WLOG("Skipping upload for \(md5): File not found at expected location")
                        continue
                    }

                    Task {
                        do {
                            VLOG("Realm modification detected for \(md5). Triggering CloudKit upload/update.")
                            try await self.romsSyncer.uploadGame(md5)
                            VLOG("CloudKit upload/update task completed for modified game \(md5).")
                        } catch let error as CloudSyncError {
                            // Log specific error types
                            switch error {
                            case .invalidData:
                                ELOG("Failed to upload \(md5): Invalid game data")
                            case .assetTooLarge(let size, let maxSize):
                                let sizeMB = Double(size) / (1024 * 1024)
                                let maxMB = Double(maxSize) / (1024 * 1024)
                                ELOG("Failed to upload \(md5): File too large (\(String(format: "%.1f", sizeMB))MB > \(String(format: "%.1f", maxMB))MB)")
                            case .fileSystemError(let underlyingError):
                                ELOG("Failed to upload \(md5): File system error - \(underlyingError.localizedDescription)")
                            case .cloudKitError(let ckError):
                                if let ckErr = ckError as? CKError {
                                    switch ckErr.code {
                                    case .networkUnavailable, .networkFailure:
                                        WLOG("Failed to upload \(md5): Network unavailable - will retry later")
                                    case .quotaExceeded:
                                        ELOG("Failed to upload \(md5): iCloud storage quota exceeded")
                                    default:
                                        ELOG("Failed to upload \(md5): CloudKit error - \(ckErr.localizedDescription)")
                                    }
                                } else {
                                    ELOG("Failed to upload \(md5): CloudKit error - \(ckError.localizedDescription)")
                                }
                            default:
                                ELOG("Failed to upload \(md5): \(error.localizedDescription)")
                            }
                        } catch {
                            ELOG("Error uploading/updating modified game \(md5) to CloudKit: \(error.localizedDescription)")
                        }
                    }
                }
            }

            // Handle Deletions (Explicitly, not here)
            if !deletions.isEmpty {
                VLOG("Detected \(deletions.count) PVGame deletions in Realm notification. These should be handled explicitly by the code performing the deletion.")
                // No action needed here as the trigger should be coupled with the delete operation itself.
            }

        case .error(let error):
            // An error occurred while observing the Realm collection
            ELOG("Realm notification error for PVGame: \(error). Stopping monitoring.")
            stopMonitoring()
            // Consider notifying the user or attempting to restart monitoring?
        }
    }
}
