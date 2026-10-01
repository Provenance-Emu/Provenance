//
//  ArtworkSearchQueue+Retry.swift
//  PVLibrary
//
//  Deferred artwork URL→file retries with write budgeting (PROVENANCE-1AW).
//

import Foundation
import PVLogging
import PVLookup
import PVMediaCache
import PVRealm
import RealmSwift
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

extension ArtworkSearchQueue {

    /// Schedules artwork URL→file retries after the primary pass, deferring full-library work during large backfills.
    func scheduleRetryAfterPrimaryPass(primaryBatchCount: Int) {
        guard !isPaused else { return }

        if primaryBatchCount <= ArtworkRetryLimits.deferRetryPrimaryBatchThreshold {
            Task { await retryFailedArtworkDownloads() }
            return
        }

        ILOG("ArtworkSearchQueue: Deferring full-library artwork retry (\(primaryBatchCount) games queued)")
        deferredRetryTask?.cancel()
        deferredRetryTask = Task.detached(priority: .utility) { [self] in
            do {
                try await Task.sleep(for: .seconds(ArtworkRetryLimits.deferredRetryDelaySeconds))
            } catch {
                return
            }
            await self.retryFailedArtworkDownloads()
        }
    }

    /// Once per launch, shortly after startup: drop cached "artwork" files that are not images
    /// (an error page cached by an older build), then retry artwork for every game that has a
    /// URL but no usable file, replacing dead URLs. Bounded and low priority; a later launch
    /// retries whatever is still failing.
    public func scheduleLaunchArtworkRepair() {
        guard !didScheduleLaunchRepair else { return }
        didScheduleLaunchRepair = true
        Task.detached(priority: .utility) { [self] in
            do {
                try await Task.sleep(for: .seconds(ArtworkRetryLimits.launchRepairDelaySeconds))
            } catch {
                return
            }
            await self.discardUndecodableArtworkFiles()
            for pass in 1...ArtworkRetryLimits.launchRepairMaxPasses {
                guard await !self.isPausedForWork else { return }
                let handled = await self.retryFailedArtworkDownloads()
                VLOG("ArtworkSearchQueue: launch artwork repair pass \(pass) handled \(handled) game(s)")
                if handled == 0 { break }
            }
        }
    }

    /// Clear `originalArtworkFile` (and delete the cached file) for games whose cached artwork is
    /// not a decodable image, so `retryFailedArtworkDownloads` downloads it again.
    func discardUndecodableArtworkFiles() async {
        let discarded = await Task.detached(priority: .utility) { () -> [String] in
            guard let realm = try? Realm() else { return [] }
            var suspects: [(md5: String, path: String)] = []
            let candidates = realm.objects(PVGame.self)
                .filter("originalArtworkFile != nil AND originalArtworkURL != '' AND customArtworkURL == ''")
                .prefix(ArtworkRetryLimits.launchRepairMaxFileChecks)
            for game in candidates {
                guard let path = game.originalArtworkFile?.url?.path,
                      FileManager.default.fileExists(atPath: path),
                      !ArtworkDownsampler.isDecodableImage(atPath: path) else { continue }
                suspects.append((game.md5Hash, path))
            }
            guard !suspects.isEmpty else { return [] }
            var cleared: [String] = []
            for suspect in suspects {
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: suspect.md5) else { continue }
                try? FileManager.default.removeItem(atPath: suspect.path)
                if (try? realm.write({ game.originalArtworkFile = nil })) != nil {
                    cleared.append(suspect.md5)
                }
            }
            return cleared
        }.value

        if !discarded.isEmpty {
            WLOG("ArtworkSearchQueue: Discarded \(discarded.count) cached artwork file(s) that are not images; they will be downloaded again")
            let ids = Set(discarded)
            await MainActor.run {
                NotificationCenter.default.post(name: .artworkDidCache, object: nil, userInfo: [SyncNotification.gameIDsKey: ids])
            }
        }
    }

    /// Retry downloading artwork for games that have URLs but no files.
    /// - Returns: How many games got artwork this pass (0 when nothing more can be done now).
    @discardableResult
    public func retryFailedArtworkDownloads() async -> Int {
        guard !isPaused else {
            VLOG("ArtworkSearchQueue: Paused — skipping retryFailedArtworkDownloads")
            return 0
        }

        let gamesNeedingDownload = await Task.detached(priority: .utility) { () -> [ArtworkRetryMetadata] in
            guard let realm = try? Realm() else {
                return []
            }
            return realm.objects(PVGame.self)
                .filter("originalArtworkURL != '' AND originalArtworkFile == nil AND customArtworkURL == ''")
                .map { game in
                    let healContext = ArtworkSelfHealing.context(for: game)
                    return ArtworkRetryMetadata(
                        md5Hash: game.md5Hash.uppercased(),
                        artworkURL: game.originalArtworkURL,
                        title: game.title,
                        gameID: healContext.gameID,
                        filename: healContext.romFileName,
                        systemID: healContext.systemID
                    )
                }
        }.value

        guard !gamesNeedingDownload.isEmpty else {
            VLOG("ArtworkSearchQueue: No games need artwork download retry")
            return 0
        }

        ILOG("ArtworkSearchQueue: Found \(gamesNeedingDownload.count) games with artwork URLs but no files, retrying downloads")

        var processed = 0
        var healAttempts = 0

        for gameMetadata in gamesNeedingDownload {
            guard processed < ArtworkRetryLimits.maxRetriesPerCall else { break }
            guard sessionWriteBudgetBytes > 0 else {
                WLOG("ArtworkSearchQueue: Session write budget exhausted — stopping artwork retries")
                break
            }

            let md5Hash = gameMetadata.md5Hash
            let artworkURLString = gameMetadata.artworkURL
            guard let artworkURL = URL(string: artworkURLString) else {
                WLOG("ArtworkSearchQueue: Invalid artwork URL for game \(gameMetadata.title ?? "Unknown"): \(artworkURLString)")
                continue
            }

            // Every source for this game already failed this launch: don't hit the servers again.
            if await ArtworkDeadURLCache.shared.isExhausted(gameKey: md5Hash) {
                VLOG("ArtworkSearchQueue: Skipping retry for \(gameMetadata.title ?? "Unknown") — no working source this launch")
                continue
            }

            var downloadResult: (Data?, Error?) = (nil, nil)
            switch await ArtworkSelfHealing.fetch(artworkURL, session: artworkURLSession) {
            case .image(let data):
                downloadResult = (data, nil)
            case .dead(let reason):
                // Dead stored URL: replace it from another source instead of retrying it forever.
                // Bounded per call; the rest are handled by the next retry pass.
                guard healAttempts < ArtworkRetryLimits.maxHealAttemptsPerCall else { continue }
                healAttempts += 1
                let context = ArtworkHealContext(
                    md5: md5Hash,
                    gameID: gameMetadata.gameID,
                    title: gameMetadata.title ?? "",
                    romFileName: gameMetadata.filename,
                    systemID: gameMetadata.systemID
                )
                if let bytes = await ArtworkSelfHealing.healAndPersist(context, deadURL: artworkURLString, reason: reason) {
                    sessionWriteBudgetBytes -= min(bytes, sessionWriteBudgetBytes)
                    processed += 1
                }
                try? await Task.sleep(for: .milliseconds(50))
                continue
            case .transient(let reason, let statusCode):
                downloadResult = (nil, NSError(domain: "ArtworkSearchQueue",
                                               code: statusCode ?? 0,
                                               userInfo: [NSLocalizedDescriptionKey: reason]))
            }

            if let data = downloadResult.0 {
                guard data.count <= sessionWriteBudgetBytes else {
                    WLOG("ArtworkSearchQueue: Skipping retry — \(data.count) bytes exceeds remaining write budget")
                    break
                }
                sessionWriteBudgetBytes -= data.count

                let gameTitle = gameMetadata.title
                #if os(macOS)
                if let artwork = NSImage(data: data) {
                    do {
                        let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURLString)
                        let saved = try await Task.detached(priority: .utility) { () -> Bool in
                            guard let realm = try? Realm() else { return false }
                            guard let gameToUpdate = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) else { return false }
                            try realm.write {
                                let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                                gameToUpdate.originalArtworkFile = file
                            }
                            return true
                        }.value
                        if saved {
                            ILOG("ArtworkSearchQueue: Successfully retried and downloaded artwork for \(gameTitle ?? "Unknown")")
                            notifyArtworkCached(gameId: md5Hash)
                            processed += 1
                        }
                    } catch {
                        WLOG("ArtworkSearchQueue: Failed to cache retried artwork for \(gameTitle ?? "Unknown"): \(error.localizedDescription)")
                    }
                }
                #elseif !os(watchOS)
                if let artwork = UIImage(data: data) {
                    do {
                        let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURLString)
                        let saved = try await Task.detached(priority: .utility) { () -> Bool in
                            guard let realm = try? Realm() else { return false }
                            guard let gameToUpdate = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) else { return false }
                            try realm.write {
                                let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                                gameToUpdate.originalArtworkFile = file
                            }
                            return true
                        }.value
                        if saved {
                            ILOG("ArtworkSearchQueue: Successfully retried and downloaded artwork for \(gameTitle ?? "Unknown")")
                            notifyArtworkCached(gameId: md5Hash)
                            processed += 1
                        }
                    } catch {
                        WLOG("ArtworkSearchQueue: Failed to cache retried artwork for \(gameTitle ?? "Unknown"): \(error.localizedDescription)")
                    }
                }
                #endif
            } else if let error = downloadResult.1 {
                let gameTitle = gameMetadata.title
                VLOG("ArtworkSearchQueue: Retry download failed for \(gameTitle ?? "Unknown"): \(error.localizedDescription)")
                if isTransientHTTPError(error) {
                    try? await Task.sleep(for: .seconds(ArtworkRetryLimits.transientHTTPBackoffSeconds))
                }
            }

            try? await Task.sleep(for: .milliseconds(50))
        }

        if processed > 0 {
            ILOG("ArtworkSearchQueue: Completed retry downloads for \(processed) games")
        }
        return processed
    }

    /// Returns `true` for HTTP 5xx responses that should backoff rather than storm retries.
    func isTransientHTTPError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == "ArtworkSearchQueue" else { return false }
        return nsError.code >= 500 && nsError.code < 600
    }
}
