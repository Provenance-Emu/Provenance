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

    private struct MetadataSnapshot: Equatable, Sendable {
        let title: String
        let isFavorite: Bool
        let rating: Int
        let originalArtworkURL: String
        let customArtworkURL: String
        let boxBackArtworkURL: String?
        let gameDescription: String?
        let developer: String?
        let publisher: String?
        let publishDate: String?
        let genres: String?
        let referenceURL: String?
        let releaseID: String?
        let regionName: String?
        let regionID: Int?
        let systemShortName: String?
        let language: String?
    }

    private struct StatsSnapshot: Equatable, Sendable {
        let playCount: Int
        let timeSpentInGame: Int
        let lastPlayed: Date?
    }

    // Realm instance used for observation. Created when monitoring starts.
    private var realm: Realm?
    private let romsSyncer: CloudKitRomsSyncer
    private var notificationToken: NotificationToken?
    private var metadataCache: [String: MetadataSnapshot] = [:]
    private var statsCache: [String: StatsSnapshot] = [:]
    private let monitorQueue = DispatchQueue(label: "org.provenance.cloudsync.localgames.monitor", qos: .utility)

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
        monitorQueue.async { [weak self] in
            guard let self else { return }
            guard self.notificationToken == nil else {
                WLOG("Monitoring already started.")
                return
            }
            VLOG("Starting Realm observation for PVGame...")
            do {
                let realmInstance = try Realm()
                self.realm = realmInstance
                let results = realmInstance.objects(PVGame.self).filter("contentless == false")
                self.notificationToken = results.observe(on: self.monitorQueue) { [weak self] (changes: RealmCollectionChange) in
                    guard let self else { return }
                    self.handleRealmChanges(changes)
                }
                ILOG("Successfully started Realm observation for PVGame.")
            } catch {
                ELOG("Failed to initialize Realm for LocalGameSyncMonitor: \(error.localizedDescription)")
            }
        }
    }

    /// Stops observing Realm changes.
    public func stopMonitoring() {
        monitorQueue.async { [weak self] in
            guard let self else { return }
            VLOG("Stopping Realm observation for PVGame...")
            self.notificationToken?.invalidate()
            self.notificationToken = nil
            self.realm = nil
            self.metadataCache.removeAll()
            self.statsCache.removeAll()
            ILOG("Stopped Realm observation for PVGame.")
        }
    }

    /// Handles the changes received from the Realm notification block.
    private func handleRealmChanges(_ changes: RealmCollectionChange<Results<PVGame>>) {
        if CloudKitRemoteApplyGuard.isApplyingRemoteChanges {
            switch changes {
            case .initial(let collection):
                rebuildCaches(from: collection)
            case .update(let collection, _, _, _):
                rebuildCaches(from: collection)
            case .error:
                break
            }
            return
        }

        switch changes {
        case .initial(let currentResults):
            // Results are now populated and ready
            VLOG("Realm observation initial results received for PVGame (count: \(currentResults.count)).")
            rebuildCaches(from: currentResults)
            // Potentially trigger an initial consistency check here if needed,
            // but CloudKitInitialSyncer likely handles the first full sync.
            break

        case .update(let currentResults, let deletions, let insertions, let modifications):
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
                    metadataCache[md5] = snapshot(for: insertedGame)
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

                    let normalizedMD5 = md5.uppercased()
                    let newMetadata = metadataSnapshot(for: modifiedGame)
                    let oldMetadata = metadataCache[normalizedMD5]
                    let metadataChanged = oldMetadata.map { $0 != newMetadata } ?? true
                    metadataCache[normalizedMD5] = newMetadata

                    let newStats = statsSnapshot(for: modifiedGame)
                    let oldStats = statsCache[normalizedMD5]
                    statsCache[normalizedMD5] = newStats

                    if let oldStats {
                        let playDelta = max(0, newStats.playCount - oldStats.playCount)
                        let timeDelta = max(0, newStats.timeSpentInGame - oldStats.timeSpentInGame)
                        let endedAt = newStats.lastPlayed ?? Date()

                        if playDelta > 0 || timeDelta > 0 {
                            Task {
                                do {
                                    try await self.romsSyncer.incrementPlayStats(
                                        md5: normalizedMD5,
                                        playCountDelta: playDelta,
                                        timeSpentDelta: timeDelta,
                                        lastPlayed: endedAt
                                    )
                                } catch {
                                    WLOG("[SYNC] Failed to increment play stats for \(normalizedMD5): \(error.localizedDescription)")
                                }
                            }
                        }
                    }

                    if metadataChanged {
                        Task { [weak self] in
                            guard let self else { return }
                            await CloudKitGameMetadataUpdateQueue.shared.enqueue(md5: normalizedMD5)
                            await CloudKitGameMetadataUpdateQueue.shared.drain(using: self.romsSyncer)
                        }
                        VLOG("Detected user-metadata change for \(normalizedMD5). Queued CloudKit metadata-only update.")
                        continue
                    }

                    // Skip if only sync-metadata fields changed (cloudRecordID,
                    // lastCloudSyncDate, hasCloudAssets). These are written by
                    // updateLocalGamePostUpload after an upload completes. Without
                    // this guard, the Realm notification fires after the
                    // CloudKitRemoteApplyGuard scope exits, causing an infinite
                    // re-upload loop.
                    if let existingCloudID = modifiedGame.cloudRecordID,
                       !existingCloudID.isEmpty {
                        VLOG("Skipping upload for \(md5): no user-metadata change and cloudRecordID already set")
                        continue
                    }

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
                // Keep cache consistent with current results
                rebuildCaches(from: currentResults)
                // No action needed here as the trigger should be coupled with the delete operation itself.
            }

        case .error(let error):
            // An error occurred while observing the Realm collection
            ELOG("Realm notification error for PVGame: \(error). Stopping monitoring.")
            stopMonitoring()
            // Consider notifying the user or attempting to restart monitoring?
        }
    }

    private func snapshot(for game: PVGame) -> MetadataSnapshot {
        MetadataSnapshot(
            title: game.title,
            isFavorite: game.isFavorite,
            rating: game.rating,
            originalArtworkURL: game.originalArtworkURL,
            customArtworkURL: game.customArtworkURL,
            boxBackArtworkURL: game.boxBackArtworkURL,
            gameDescription: game.gameDescription,
            developer: game.developer,
            publisher: game.publisher,
            publishDate: game.publishDate,
            genres: game.genres,
            referenceURL: game.referenceURL,
            releaseID: game.releaseID,
            regionName: game.regionName,
            regionID: game.regionID,
            systemShortName: game.systemShortName,
            language: game.language
        )
    }

    private func metadataSnapshot(for game: PVGame) -> MetadataSnapshot { snapshot(for: game) }

    private func statsSnapshot(for game: PVGame) -> StatsSnapshot {
        StatsSnapshot(playCount: game.playCount, timeSpentInGame: game.timeSpentInGame, lastPlayed: game.lastPlayed)
    }

    private func rebuildCaches(from results: Results<PVGame>) {
        var newMetadata: [String: MetadataSnapshot] = [:]
        var newStats: [String: StatsSnapshot] = [:]
        for game in results {
            let md5 = game.md5Hash.uppercased()
            guard !md5.isEmpty else { continue }
            newMetadata[md5] = metadataSnapshot(for: game)
            newStats[md5] = statsSnapshot(for: game)
        }
        metadataCache = newMetadata
        statsCache = newStats
    }
}
