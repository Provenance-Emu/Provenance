//
//  ArtworkSearchQueue+Retry.swift
//  PVLibrary
//
//  Deferred artwork URL→file retries with write budgeting (PROVENANCE-1AW).
//

import Foundation
import PVLogging
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

    /// Retry downloading artwork for games that have URLs but no files.
    public func retryFailedArtworkDownloads() async {
        guard !isPaused else {
            VLOG("ArtworkSearchQueue: Paused — skipping retryFailedArtworkDownloads")
            return
        }

        let gamesNeedingDownload = await Task.detached(priority: .utility) { () -> [ArtworkRetryMetadata] in
            guard let realm = try? Realm() else {
                return []
            }
            return realm.objects(PVGame.self)
                .filter("originalArtworkURL != '' AND originalArtworkFile == nil AND customArtworkURL == ''")
                .map { game in
                    ArtworkRetryMetadata(
                        md5Hash: game.md5Hash.uppercased(),
                        artworkURL: game.originalArtworkURL,
                        title: game.title
                    )
                }
        }.value

        guard !gamesNeedingDownload.isEmpty else {
            VLOG("ArtworkSearchQueue: No games need artwork download retry")
            return
        }

        ILOG("ArtworkSearchQueue: Found \(gamesNeedingDownload.count) games with artwork URLs but no files, retrying downloads")

        var processed = 0

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

            let session = artworkURLSession
            let downloadResult = await Task.detached(priority: .utility) { () -> (Data?, Error?) in
                do {
                    let response = try await session.data(from: artworkURL)
                    if let httpResponse = response.1 as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            return (response.0, nil)
                        } else {
                            let error = NSError(domain: "ArtworkSearchQueue",
                                                code: httpResponse.statusCode,
                                                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                            return (nil, error)
                        }
                    } else {
                        return (response.0, nil)
                    }
                } catch {
                    return (nil, error)
                }
            }.value

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
    }

    /// Returns `true` for HTTP 5xx responses that should backoff rather than storm retries.
    func isTransientHTTPError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == "ArtworkSearchQueue" else { return false }
        return nsError.code >= 500 && nsError.code < 600
    }
}
