//
//  LocalGameSyncMonitor.swift
//  PVLibrary
//
//  Created by Cascade on 2025-04-29.
//

import Foundation
import RealmSwift
import PVLogging
import PVRealm // Assuming PVGame is here
// Assuming CloudKitRomsSyncer is accessible, potentially via PVLibrary module itself or another import

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

            gamesResults = realmInstance.objects(PVGame.self)

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
                    let md5 = modifiedGame.md5Hash
                    Task {
                         do {
                             VLOG("Realm modification detected for \(md5). Triggering CloudKit upload/update.")
                             try await self.romsSyncer.uploadGame(md5)
                             VLOG("CloudKit upload/update task completed for modified game \(md5).")
                         } catch {
                             ELOG("Error uploading/updating modified game \(md5) to CloudKit: \(error)")
                             // TODO: Implement retry logic or flag for later sync?
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
