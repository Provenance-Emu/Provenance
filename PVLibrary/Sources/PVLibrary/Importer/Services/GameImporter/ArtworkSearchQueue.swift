//
//  ArtworkSearchQueue.swift
//  PVLibrary
//
//  Created on 12/14/24.
//

import Foundation
import PVLogging
import PVLookup
import PVLookupTypes
import PVRealm
import RealmSwift
import PVSystems

/// Feature flag to enable/disable enhanced artwork search.
/// Set to `false` to disable this feature if bugs are found.
public var ENABLE_ENHANCED_ARTWORK_SEARCH: Bool = true

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
    private let lookup: PVLookup

    /// Custom URLSession for artwork downloads with longer timeouts
    private let artworkURLSession: URLSession

    private init() {
        self.lookup = PVLookup.shared

        // Configure URLSession for artwork downloads with longer timeouts
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0 // 30 second timeout
        configuration.timeoutIntervalForResource = 60.0 // 60 second total timeout
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
        guard ENABLE_ENHANCED_ARTWORK_SEARCH else { return }

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
            processingTask = Task.detached(priority: .utility) {
                // Wait for more games to be queued (debounce)
                try? await Task.sleep(for: .seconds(3))
                // Check if we still have games to process
                await ArtworkSearchQueue.shared.processPendingSearches()
            }
        }
    }

    /// Process pending artwork searches (lower priority)
    /// Should be called after primary imports complete
    public func processPendingSearches() async {
        ILOG("ArtworkSearchQueue: processPendingSearches called (ENABLE_ENHANCED_ARTWORK_SEARCH=\(ENABLE_ENHANCED_ARTWORK_SEARCH), isProcessing=\(isProcessing), pendingGames.count=\(pendingGames.count))")

        guard ENABLE_ENHANCED_ARTWORK_SEARCH else {
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

    /// Search for artwork for a specific game using enhanced search
    /// Uses metadata directly - no Realm lookup required
    private func searchArtworkForGame(_ metadata: ArtworkSearchMetadata) async {
        // Check if game still needs artwork (quick Realm check only when saving)
        // We'll verify this when we actually save the artwork

        let md5Hash = metadata.md5Hash.uppercased()
        let gameTitle = metadata.title.isEmpty ? metadata.gameID : metadata.title

        // Need at least one meaningful searchable term (after bracket/noise stripping)
        guard !metadata.title.cleanedForArtworkSearch().isEmpty || !metadata.filename.cleanedForArtworkSearch().isEmpty else {
            WLOG("ArtworkSearchQueue: Game \(metadata.gameID) has no searchable title or filename")
            return
        }

        do {
            // Delegate progressive fallback search to ArtworkMatchingService
            let artworkResults = try await ArtworkMatchingService.shared.searchWithFallback(
                title: metadata.title,
                filename: metadata.filename,
                systemID: metadata.systemID,
                md5Hash: metadata.md5Hash
            )

            if artworkResults?.isEmpty ?? true {
                VLOG("ArtworkSearchQueue: No artwork found for \(gameTitle) after trying title, filename, and MD5 lookup")
            }

            // Process results if found
            if let artworkResults = artworkResults, !artworkResults.isEmpty {
                // Prioritize box front artwork if available, otherwise use first result
                let selectedArtwork = artworkResults.first { $0.type == .boxFront } ?? artworkResults.first!

                // Found artwork! Download and set it
                ILOG("ArtworkSearchQueue: Found artwork for \(gameTitle) from \(selectedArtwork.source) (type: \(selectedArtwork.type.displayName))")

                // Download and cache the artwork image
                let artworkURL = selectedArtwork.url
                var imageData: Data?
                var downloadError: Error?

                // Download the image using custom URLSession with longer timeouts
                // Use Task.detached to prevent cancellation from parent task group
                ILOG("ArtworkSearchQueue: Downloading artwork from \(artworkURL.absoluteString)")

                // Capture URLSession before detached task (actor isolation)
                let session = artworkURLSession

                // Perform download in detached task to avoid cancellation from task group
                // Don't check cancellation - let the download attempt proceed
                let downloadResult = await Task.detached(priority: .utility) { () -> (Data?, Error?) in
                    do {
                        let response = try await session.data(from: artworkURL)
                        if let httpResponse = response.1 as? HTTPURLResponse {
                            if httpResponse.statusCode == 200 {
                                return (response.0, nil)
                            } else {
                                let error = NSError(domain: "ArtworkSearchQueue", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                                return (nil, error)
                            }
                        } else {
                            // No HTTP response (shouldn't happen but handle it)
                            return (response.0, nil)
                        }
                    } catch {
                        return (nil, error)
                    }
                }.value

                imageData = downloadResult.0
                downloadError = downloadResult.1

                if let data = imageData {
                    ILOG("ArtworkSearchQueue: Successfully downloaded \(data.count) bytes from \(artworkURL.absoluteString)")
                } else if let error = downloadError {
                    // Log error details
                    if let urlError = error as? URLError {
                        if urlError.code == .cancelled {
                            WLOG("ArtworkSearchQueue: Download was cancelled for \(artworkURL.absoluteString) - this may indicate a timeout or task cancellation")
                        } else {
                            WLOG("ArtworkSearchQueue: URL error \(urlError.code.rawValue) (\(urlError.localizedDescription)) downloading from \(artworkURL.absoluteString)")
                        }
                    } else if error is CancellationError {
                        WLOG("ArtworkSearchQueue: Download was cancelled (CancellationError) for \(artworkURL.absoluteString)")
                    } else {
                        WLOG("ArtworkSearchQueue: Download error (\(error.localizedDescription)) for \(artworkURL.absoluteString)")
                    }
                }

                // Save artwork to database using md5Hash (primary key)
                // Add retry mechanism in case game hasn't been committed yet
                // Create Realm in detached task to avoid actor isolation issues
                let maxRetries = 3
                var retryCount = 0
                var gameFound = false
                var shouldSave = false
                var hasOriginalArtworkFile = false
                var hasCustomArtworkURL = false
                var currentOriginalArtworkURL = ""

                // Try to find the game with retries (game might not be committed yet)
                while !gameFound && retryCount < maxRetries {
                    let lookupResult = await Task.detached(priority: .utility) { () -> (found: Bool, hasOriginalFile: Bool, hasCustomURL: Bool, originalURL: String) in
                        guard let realm = try? Realm() else {
                            return (false, false, false, "")
                        }

                        // Try lookup by MD5 hash (primary key)
                        if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) {
                            return (true, game.originalArtworkFile != nil, !game.customArtworkURL.isEmpty, game.originalArtworkURL)
                        }

                        // If not found by MD5, try lookup by id as fallback
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
                        shouldSave = !hasOriginalArtworkFile && !hasCustomArtworkURL
                        break
                    }

                    // If still not found and we have retries left, wait a bit and try again
                    if retryCount < maxRetries - 1 {
                        retryCount += 1
                        ILOG("ArtworkSearchQueue: Game \(gameTitle) (MD5: \(md5Hash), ID: \(metadata.gameID)) not found in database, retrying (\(retryCount)/\(maxRetries))...")
                        try? await Task.sleep(for: .milliseconds(500))
                    } else {
                        break
                    }
                }

                let finalRetryCount = retryCount

                // Quick check if game exists and still needs artwork
                // Save if: no artwork file exists AND no custom artwork
                if gameFound && shouldSave {
                    if let data = imageData {
                        #if os(macOS)
                        if let artwork = NSImage(data: data) {
                            do {
                                let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURL.absoluteString)
                                try await Task.detached(priority: .utility) {
                                    guard let realm = try? Realm() else { return }
                                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                                      (!metadata.gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", metadata.gameID).first : nil) else { return }
                                    try realm.write {
                                        let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                                        game.originalArtworkFile = file
                                        game.originalArtworkURL = artworkURL.absoluteString
                                    }
                                }.value
                                ILOG("ArtworkSearchQueue: Downloaded and cached artwork for \(gameTitle)")
                            } catch {
                                WLOG("ArtworkSearchQueue: Failed to cache artwork for \(gameTitle): \(error.localizedDescription)")
                            }
                        }
                        #elseif !os(watchOS)
                        if let artwork = UIImage(data: data) {
                            do {
                                let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURL.absoluteString)
                                try await Task.detached(priority: .utility) {
                                    guard let realm = try? Realm() else { return }
                                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                                      (!metadata.gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", metadata.gameID).first : nil) else { return }
                                    try realm.write {
                                        let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                                        game.originalArtworkFile = file
                                        game.originalArtworkURL = artworkURL.absoluteString
                                    }
                                }.value
                                ILOG("ArtworkSearchQueue: Downloaded and cached artwork for \(gameTitle)")
                            } catch {
                                WLOG("ArtworkSearchQueue: Failed to cache artwork for \(gameTitle): \(error.localizedDescription)")
                            }
                        }
                        #endif
                    } else {
                        // If download failed, at least set the URL so it can be downloaded later
                        // Only set URL if it's not already set (avoid overwriting with same failed URL)
                        let errorDescription = downloadError?.localizedDescription ?? "Unknown error"
                        if currentOriginalArtworkURL != artworkURL.absoluteString {
                            try? await Task.detached(priority: .utility) {
                                guard let realm = try? Realm() else { return }
                                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash) ??
                                                  (!metadata.gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", metadata.gameID).first : nil) else { return }
                                try? realm.write {
                                    game.originalArtworkURL = artworkURL.absoluteString
                                }
                            }.value
                            WLOG("ArtworkSearchQueue: Found artwork URL for \(gameTitle) but download failed (\(errorDescription)), URL saved for later: \(artworkURL.absoluteString)")
                        } else {
                            WLOG("ArtworkSearchQueue: Artwork URL already set for \(gameTitle), skipping duplicate URL: \(artworkURL.absoluteString)")
                        }
                    }
                } else {
                    if gameFound {
                        if hasOriginalArtworkFile {
                            VLOG("ArtworkSearchQueue: Game \(metadata.title) (MD5: \(md5Hash), ID: \(metadata.gameID)) already has original artwork file, skipping save")
                        } else if hasCustomArtworkURL {
                            VLOG("ArtworkSearchQueue: Game \(metadata.title) (MD5: \(md5Hash), ID: \(metadata.gameID)) already has custom artwork, skipping save")
                        }
                    } else {
                        WLOG("ArtworkSearchQueue: Game \(metadata.title) (MD5: \(md5Hash), ID: \(metadata.gameID)) not found in database after \(finalRetryCount + 1) attempts, skipping save. Game may not be committed yet or MD5 mismatch.")
                    }
                }
            }
        } catch {
            WLOG("ArtworkSearchQueue: Error searching artwork for \(gameTitle): \(error.localizedDescription)")
        }
    }

    /// Clear the queue (useful for testing or reset)
    public func clearQueue() {
        pendingGames.removeAll()
        isProcessing = false
    }

    /// Retry downloading artwork for games that have URLs but no files
    /// This should be called periodically or when games are accessed
    public func retryFailedArtworkDownloads() async {
        guard ENABLE_ENHANCED_ARTWORK_SEARCH else { return }

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

