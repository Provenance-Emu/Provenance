//
//  ArtworkSearchQueue.swift
//  PVLibrary
//
//  Created on 12/14/24.
//

import Foundation
import PVFeatureFlags
import PVLogging
import PVLookup
import PVLookupTypes
import PVRealm
import RealmSwift
import PVSystems

/// Metadata needed for artwork search (no Realm objects required)
private struct ArtworkSearchMetadata: Sendable {
    let gameID: String
    let title: String
    let filename: String // Filename without extension
    let systemID: SystemIdentifier?
    let md5Hash: String
}

/// Metadata for retrying artwork downloads (no Realm objects required)
private struct ArtworkRetryMetadata: Sendable {
    let md5Hash: String
    let artworkURL: String
    let title: String?
}

/// Manages a lower-priority queue for enhanced artwork searching
/// Uses PVLookup's multi-source search (TheGamesDB, LibretroDB) instead of just OpenVGDB
public actor ArtworkSearchQueue {
    public static let shared = ArtworkSearchQueue()

    private var pendingGames: [ArtworkSearchMetadata] = [] // Game metadata for artwork search
    private var isProcessing = false
    private var processingTask: Task<Void, Never>? // Track processing task for cancellation
    /// Service that performs the multi-source artwork search with progressive fallback.
    private let matchingService: any ArtworkMatchingServiceProtocol

    /// Artwork types fetched in the primary (box art) pass.
    private static let primaryArtworkTypes: ArtworkType = [.boxFront, .boxBack]
    /// Artwork types deferred to background tasks after the primary pass.
    private static let backgroundArtworkTypes: ArtworkType = [.screenshot, .titleScreen]

    /// Custom URLSession for artwork downloads with longer timeouts
    private let artworkURLSession: URLSession

    private init() {
        self.matchingService = ArtworkMatchingService.shared

        // Configure URLSession for artwork downloads with longer timeouts
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0 // 30 second timeout
        configuration.timeoutIntervalForResource = 60.0 // 60 second total timeout
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        self.artworkURLSession = URLSession(configuration: configuration)
    }

    /// Initialiser for unit testing — injects a mock matching service.
    internal init(matchingService: any ArtworkMatchingServiceProtocol) {
        self.matchingService = matchingService

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        self.artworkURLSession = URLSession(configuration: configuration)
    }

    /// Queue a game for enhanced artwork search (lower priority)
    /// Accepts all required metadata directly - no Realm lookup needed
    public func queueGameForArtworkSearch(
        gameID: String,
        title: String,
        filename: String,
        systemID: SystemIdentifier?,
        md5Hash: String
    ) async {
        guard await PVFeatureFlags.shared.isEnabled(.enhancedArtworkSearch) else { return }

        // Check if already queued
        if !pendingGames.contains(where: { $0.gameID == gameID }) {
            let metadata = ArtworkSearchMetadata(
                gameID: gameID,
                title: title,
                filename: filename,
                systemID: systemID,
                md5Hash: md5Hash
            )
            pendingGames.append(metadata)
            ILOG("ArtworkSearchQueue: Queued game \(title) (ID: \(gameID)) for enhanced artwork search (queue size: \(pendingGames.count))")

            // Schedule processing with debounce - cancel previous task and start new one
            processingTask?.cancel()
            processingTask = Task.detached(priority: .utility) { [self] in
                // Wait for more games to be queued (debounce)
                try? await Task.sleep(for: .seconds(3))
                // Respect cancellation: if a newer task was queued during the sleep, bail out.
                guard !Task.isCancelled else { return }
                await self.processPendingSearches()
            }
        }
    }

    /// Process pending artwork searches (lower priority)
    /// Should be called after primary imports complete
    public func processPendingSearches() async {
        let featureEnabled = await PVFeatureFlags.shared.isEnabled(.enhancedArtworkSearch)
        ILOG("ArtworkSearchQueue: processPendingSearches called (enhancedArtworkSearch=\(featureEnabled), isProcessing=\(isProcessing), pendingGames.count=\(pendingGames.count))")

        guard featureEnabled else {
            ILOG("ArtworkSearchQueue: Enhanced artwork search is disabled")
            return
        }

        guard !isProcessing else {
            ILOG("ArtworkSearchQueue: Already processing, skipping")
            return
        }

        guard !pendingGames.isEmpty else {
            ILOG("ArtworkSearchQueue: No pending games to process")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        ILOG("ArtworkSearchQueue: Starting enhanced artwork search for \(pendingGames.count) games")

        // Process in batches to avoid overwhelming the system
        let batchSize = 5
        var processed = 0

        while !pendingGames.isEmpty {
            let batch = Array(pendingGames.prefix(batchSize))
            pendingGames.removeFirst(min(batchSize, pendingGames.count))

            await processBatch(batch)
            processed += batch.count

            // Small delay between batches to avoid rate limiting
            try? await Task.sleep(for: .milliseconds(500))
        }

        ILOG("ArtworkSearchQueue: Completed enhanced artwork search for \(processed) games")

        // After processing, retry any failed downloads
        await retryFailedArtworkDownloads()
    }

    /// Process a batch of games for artwork search
    private func processBatch(_ metadataList: [ArtworkSearchMetadata]) async {
        await withTaskGroup(of: Void.self) { group in
            for metadata in metadataList {
                group.addTask {
                    await self.searchArtworkForGame(metadata)
                }
            }
        }
    }

    /// Search for artwork for a specific game using enhanced search.
    /// Delegates lookup to `ArtworkMatchingService`, then persists each artwork type separately.
    private func searchArtworkForGame(_ metadata: ArtworkSearchMetadata) async {
        let md5Hash = metadata.md5Hash.uppercased()
        let gameTitle = metadata.title.isEmpty ? metadata.gameID : metadata.title

        guard !metadata.title.isEmpty || !metadata.filename.isEmpty else {
            WLOG("ArtworkSearchQueue: Game \(metadata.gameID) has no searchable title or filename")
            return
        }

        // Fetch box front + box back in one round-trip via ArtworkMatchingService.
        let artworkResults = await matchingService.findArtwork(
            title: metadata.title,
            filename: metadata.filename,
            md5: md5Hash,
            systemIdentifier: metadata.systemID,
            artworkTypes: Self.primaryArtworkTypes
        )

        if artworkResults.isEmpty {
            VLOG("ArtworkSearchQueue: No artwork found for \(gameTitle)")
        } else {
            ILOG("ArtworkSearchQueue: Found \(artworkResults.count) result(s) for \(gameTitle)")

            // --- Box front ---
            if let frontArtwork = artworkResults.first(where: { $0.type == .boxFront }) {
                await saveBoxFrontArtwork(frontArtwork, metadata: metadata, md5Hash: md5Hash, gameTitle: gameTitle)
            }

            // --- Box back ---
            if let backArtwork = artworkResults.first(where: { $0.type == .boxBack }) {
                await saveBoxBackArtwork(backArtwork, md5Hash: md5Hash, gameID: metadata.gameID, gameTitle: gameTitle)
            }

            // --- Screenshots / title screens (lower priority, non-blocking) ---
            // Only queue background artwork when box art was found to avoid excess API traffic.
            queueBackgroundArtworkSearch(metadata: metadata)
        }
    }

    /// Queue a background task to fetch screenshot / title-screen artwork after box art is done.
    /// Uses `.background` priority so it never contends with box-art downloads.
    private func queueBackgroundArtworkSearch(metadata: ArtworkSearchMetadata) {
        let md5Hash = metadata.md5Hash.uppercased()
        let gameTitle = metadata.title.isEmpty ? metadata.gameID : metadata.title

        Task.detached(priority: .background) { [weak self, matchingService] in
            let results = await matchingService.findArtwork(
                title: metadata.title,
                filename: metadata.filename,
                md5: md5Hash,
                systemIdentifier: metadata.systemID,
                artworkTypes: ArtworkSearchQueue.backgroundArtworkTypes
            )
            if results.isEmpty {
                VLOG("ArtworkSearchQueue: No screenshot/title-screen artwork for \(gameTitle)")
            } else {
                ILOG("ArtworkSearchQueue: Found \(results.count) screenshot/title-screen result(s) for \(gameTitle) — saving URLs")
                await self?.saveBackgroundArtwork(results, md5Hash: md5Hash, gameID: metadata.gameID)
            }
        }
    }

    // MARK: - Artwork persistence helpers

    /// Download box-front image and persist both file and URL to the game record.
    private func saveBoxFrontArtwork(
        _ artwork: ArtworkMetadata,
        metadata: ArtworkSearchMetadata,
        md5Hash: String,
        gameTitle: String
    ) async {
        let artworkURL = artwork.url

        // Check game state (retrying until it is committed to Realm)
        let maxRetries = 3
        var retryCount = 0
        var gameFound = false
        var shouldSave = false
        var hasOriginalArtworkFile = false
        var hasCustomArtworkURL = false
        var currentOriginalArtworkURL = ""

        while !gameFound && retryCount < maxRetries {
            let lookupResult = await Task.detached(priority: .utility) { () -> (found: Bool, hasOriginalFile: Bool, hasCustomURL: Bool, originalURL: String) in
                guard let realm = try? Realm() else { return (false, false, false, "") }
                if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) {
                    return (true, game.originalArtworkFile != nil, !game.customArtworkURL.isEmpty, game.originalArtworkURL)
                }
                if !metadata.gameID.isEmpty,
                   let game = realm.objects(PVGame.self).filter("id == %@", metadata.gameID).first {
                    return (true, game.originalArtworkFile != nil, !game.customArtworkURL.isEmpty, game.originalArtworkURL)
                }
                return (false, false, false, "")
            }.value

            gameFound = lookupResult.found
            if gameFound {
                hasOriginalArtworkFile = lookupResult.hasOriginalFile
                hasCustomArtworkURL = lookupResult.hasCustomURL
                currentOriginalArtworkURL = lookupResult.originalURL
                shouldSave = !hasOriginalArtworkFile && !hasCustomArtworkURL && currentOriginalArtworkURL.isEmpty
                break
            }
            if retryCount < maxRetries - 1 {
                retryCount += 1
                ILOG("ArtworkSearchQueue: Game \(gameTitle) not in DB yet, retrying (\(retryCount)/\(maxRetries))…")
                try? await Task.sleep(nanoseconds: 500_000_000)
            } else {
                break
            }
        }

        guard gameFound else {
            WLOG("ArtworkSearchQueue: Game \(gameTitle) (MD5: \(md5Hash)) not found after \(retryCount + 1) attempt(s)")
            return
        }

        guard shouldSave else {
            if hasOriginalArtworkFile {
                VLOG("ArtworkSearchQueue: \(gameTitle) already has box-front file, skipping")
            } else if hasCustomArtworkURL {
                VLOG("ArtworkSearchQueue: \(gameTitle) has custom artwork, skipping")
            } else if !currentOriginalArtworkURL.isEmpty {
                VLOG("ArtworkSearchQueue: \(gameTitle) already has originalArtworkURL, skipping")
            }
            return
        }

        let session = artworkURLSession
        let downloadResult = await Task.detached(priority: .utility) { () -> (Data?, Error?) in
            do {
                let (data, response) = try await session.data(from: artworkURL)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    return (nil, NSError(domain: "ArtworkSearchQueue", code: http.statusCode,
                                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]))
                }
                return (data, nil)
            } catch {
                return (nil, error)
            }
        }.value

        if let data = downloadResult.0 {
            ILOG("ArtworkSearchQueue: Downloaded \(data.count) bytes (box front) for \(gameTitle)")
            await persistBoxFrontImage(data: data, artworkURL: artworkURL, md5Hash: md5Hash, gameID: metadata.gameID, gameTitle: gameTitle)
        } else {
            let desc = downloadResult.1?.localizedDescription ?? "unknown"
            if currentOriginalArtworkURL != artworkURL.absoluteString {
                await Task.detached(priority: .utility) {
                    guard let realm = try? Realm(),
                          let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                     (!metadata.gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", metadata.gameID).first : nil)
                    else { return }
                    try? realm.write { game.originalArtworkURL = artworkURL.absoluteString }
                }.value
                WLOG("ArtworkSearchQueue: Box-front download failed (\(desc)), URL saved for later: \(artworkURL.absoluteString)")
            }
        }
    }

    /// Download a box-back image and store its URL in `game.boxBackArtworkURL`.
    /// Retries the Realm lookup (up to 3 attempts) in case the game record hasn't been
    /// committed yet at the time this method is called.
    private func saveBoxBackArtwork(
        _ artwork: ArtworkMetadata,
        md5Hash: String,
        gameID: String,
        gameTitle: String
    ) async {
        let artworkURL = artwork.url

        // Retry Realm lookup so we don't silently drop back art when the game
        // record is committed slightly after the box-front pass.
        let maxRetries = 3
        var retryCount = 0
        var gameFound = false
        var alreadySet = false

        while !gameFound && retryCount < maxRetries {
            let lookupResult = await Task.detached(priority: .utility) { () -> (found: Bool, alreadySet: Bool) in
                guard let realm = try? Realm() else { return (false, false) }
                if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) {
                    let set = game.boxBackArtworkURL != nil && !(game.boxBackArtworkURL?.isEmpty ?? true)
                    return (true, set)
                }
                if !gameID.isEmpty,
                   let game = realm.objects(PVGame.self).filter("id == %@", gameID).first {
                    let set = game.boxBackArtworkURL != nil && !(game.boxBackArtworkURL?.isEmpty ?? true)
                    return (true, set)
                }
                return (false, false)
            }.value

            gameFound = lookupResult.found
            alreadySet = lookupResult.alreadySet
            if gameFound { break }

            if retryCount < maxRetries - 1 {
                retryCount += 1
                ILOG("ArtworkSearchQueue: Game \(gameTitle) not in DB yet (back art), retrying (\(retryCount)/\(maxRetries))…")
                try? await Task.sleep(nanoseconds: 500_000_000)
            } else {
                break
            }
        }

        guard gameFound else {
            WLOG("ArtworkSearchQueue: Game \(gameTitle) (MD5: \(md5Hash)) not found for back art after \(retryCount + 1) attempt(s)")
            return
        }

        guard !alreadySet else {
            VLOG("ArtworkSearchQueue: \(gameTitle) already has boxBackArtworkURL, skipping")
            return
        }

        let session = artworkURLSession
        let downloadResult = await Task.detached(priority: .utility) { () -> (Data?, Error?) in
            do {
                let (data, response) = try await session.data(from: artworkURL)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    return (nil, NSError(domain: "ArtworkSearchQueue", code: http.statusCode,
                                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]))
                }
                return (data, nil)
            } catch {
                return (nil, error)
            }
        }.value

        if let data = downloadResult.0 {
            ILOG("ArtworkSearchQueue: Downloaded \(data.count) bytes (box back) for \(gameTitle)")
            await persistBoxBackImage(data: data, artworkURL: artworkURL, md5Hash: md5Hash, gameID: gameID, gameTitle: gameTitle)
        } else {
            // Save URL even if download failed so it can be retried later.
            let desc = downloadResult.1?.localizedDescription ?? "unknown"
            await Task.detached(priority: .utility) {
                guard let realm = try? Realm(),
                      let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                 (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
                else { return }
                try? realm.write { game.boxBackArtworkURL = artworkURL.absoluteString }
            }.value
            WLOG("ArtworkSearchQueue: Box-back download failed (\(desc)), URL saved for later: \(artworkURL.absoluteString)")
        }
    }

    /// Logs the first available screenshot / title-screen URL from `results`.
    /// Full persistence to `game.screenShots` is deferred until a `PVImageFile` download
    /// helper exists (see TODO comment inside).
    internal func saveBackgroundArtwork(_ results: [ArtworkMetadata], md5Hash: String, gameID: String) async {
        guard let first = results.first else { return }
        let urlString = first.url.absoluteString

        guard let realm = try? Realm(),
              let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                         (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
        else { return }
        ILOG("ArtworkSearchQueue: Background artwork URL available for \(game.title): \(urlString)")
        // TODO: Persist to game.screenShots once a PVImageFile download helper exists (#3470)
    }

    // MARK: - Image caching helpers

    private func persistBoxFrontImage(data: Data, artworkURL: URL, md5Hash: String, gameID: String, gameTitle: String) async {
        #if os(macOS)
        guard let artwork = NSImage(data: data) else {
            WLOG("ArtworkSearchQueue: Could not decode image data for \(gameTitle) — persisting URL for retry")
            await Task.detached(priority: .utility) {
                guard let realm = try? Realm(),
                      let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                 (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
                else { return }
                try? realm.write { game.originalArtworkURL = artworkURL.absoluteString }
            }.value
            return
        }
        do {
            let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURL.absoluteString)
            try await Task.detached(priority: .utility) {
                guard let realm = try? Realm(),
                      let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                 (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
                else { return }
                try realm.write {
                    game.originalArtworkFile = PVImageFile(withURL: localURL, relativeRoot: .documents)
                    game.originalArtworkURL = artworkURL.absoluteString
                }
            }.value
            ILOG("ArtworkSearchQueue: Cached box-front artwork for \(gameTitle)")
        } catch {
            WLOG("ArtworkSearchQueue: Failed to cache box-front for \(gameTitle): \(error.localizedDescription)")
        }
        #elseif !os(watchOS)
        guard let artwork = UIImage(data: data) else {
            WLOG("ArtworkSearchQueue: Could not decode image data for \(gameTitle) — persisting URL for retry")
            await Task.detached(priority: .utility) {
                guard let realm = try? Realm(),
                      let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                 (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
                else { return }
                try? realm.write { game.originalArtworkURL = artworkURL.absoluteString }
            }.value
            return
        }
        do {
            let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURL.absoluteString)
            try await Task.detached(priority: .utility) {
                guard let realm = try? Realm(),
                      let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                 (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
                else { return }
                try realm.write {
                    game.originalArtworkFile = PVImageFile(withURL: localURL, relativeRoot: .documents)
                    game.originalArtworkURL = artworkURL.absoluteString
                }
            }.value
            ILOG("ArtworkSearchQueue: Cached box-front artwork for \(gameTitle)")
        } catch {
            WLOG("ArtworkSearchQueue: Failed to cache box-front for \(gameTitle): \(error.localizedDescription)")
        }
        #endif
    }

    private func persistBoxBackImage(data: Data, artworkURL: URL, md5Hash: String, gameID: String, gameTitle: String) async {
        #if os(macOS)
        guard let artwork = NSImage(data: data) else {
            WLOG("ArtworkSearchQueue: Could not decode box-back image for \(gameTitle) — persisting URL for later")
            await Task.detached(priority: .utility) {
                guard let realm = try? Realm(),
                      let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                 (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
                else { return }
                try? realm.write { game.boxBackArtworkURL = artworkURL.absoluteString }
            }.value
            return
        }
        do {
            _ = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURL.absoluteString)
            try await Task.detached(priority: .utility) {
                guard let realm = try? Realm(),
                      let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                 (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
                else { return }
                try realm.write {
                    game.boxBackArtworkURL = artworkURL.absoluteString
                }
            }.value
            ILOG("ArtworkSearchQueue: Cached box-back artwork for \(gameTitle)")
        } catch {
            WLOG("ArtworkSearchQueue: Failed to cache box-back for \(gameTitle): \(error.localizedDescription)")
        }
        #elseif !os(watchOS)
        guard let artwork = UIImage(data: data) else {
            WLOG("ArtworkSearchQueue: Could not decode box-back image for \(gameTitle) — persisting URL for later")
            await Task.detached(priority: .utility) {
                guard let realm = try? Realm(),
                      let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                 (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
                else { return }
                try? realm.write { game.boxBackArtworkURL = artworkURL.absoluteString }
            }.value
            return
        }
        do {
            _ = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURL.absoluteString)
            try await Task.detached(priority: .utility) {
                guard let realm = try? Realm(),
                      let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                 (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
                else { return }
                try realm.write {
                    game.boxBackArtworkURL = artworkURL.absoluteString
                }
            }.value
            ILOG("ArtworkSearchQueue: Cached box-back artwork for \(gameTitle)")
        } catch {
            WLOG("ArtworkSearchQueue: Failed to cache box-back for \(gameTitle): \(error.localizedDescription)")
        }
        #endif
    }

    /// Clear the queue (useful for testing or reset)
    public func clearQueue() {
        pendingGames.removeAll()
        isProcessing = false
    }

    /// Retry downloading artwork for games that have URLs but no files
    /// This should be called periodically or when games are accessed
    public func retryFailedArtworkDownloads() async {
        guard await PVFeatureFlags.shared.isEnabled(.enhancedArtworkSearch) else { return }

        // Find games with artwork URLs but no artwork files
        // Extract values from Realm objects inside detached task to avoid cross-thread access
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

        // Process in small batches to avoid overwhelming the system
        let batchSize = 5
        var processed = 0

        for gameMetadata in gamesNeedingDownload {
            guard processed < 20 else { break } // Limit to 20 retries per call

            let md5Hash = gameMetadata.md5Hash
            let artworkURLString = gameMetadata.artworkURL
            guard let artworkURL = URL(string: artworkURLString) else {
                WLOG("ArtworkSearchQueue: Invalid artwork URL for game \(gameMetadata.title ?? "Unknown"): \(artworkURLString)")
                continue
            }

            // Download the artwork
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
                // Successfully downloaded - save it
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
            }

            // Small delay between downloads
            try? await Task.sleep(for: .milliseconds(200))
        }

        if processed > 0 {
            ILOG("ArtworkSearchQueue: Completed retry downloads for \(processed) games")
        }
    }
}

// Title-cleaning logic lives in String.artworkSearchCleaned() (defined in ArtworkMatchingService.swift).
