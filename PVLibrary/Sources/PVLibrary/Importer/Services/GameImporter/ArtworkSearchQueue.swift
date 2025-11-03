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

/// Feature flag to enable/disable enhanced artwork search
/// Set to false to disable this feature if bugs are found
#if DEBUG
public var ENABLE_ENHANCED_ARTWORK_SEARCH: Bool = true
#else
public var ENABLE_ENHANCED_ARTWORK_SEARCH: Bool = true
#endif

/// Manages a lower-priority queue for enhanced artwork searching
/// Uses PVLookup's multi-source search (TheGamesDB, LibretroDB) instead of just OpenVGDB
public actor ArtworkSearchQueue {
    public static let shared = ArtworkSearchQueue()

    private var pendingGames: [String] = [] // Game IDs that need artwork search
    private var isProcessing = false
    private let lookup: PVLookup

    private init() {
        self.lookup = PVLookup.shared
    }

    /// Queue a game for enhanced artwork search (lower priority)
    /// Only queues if the game doesn't already have artwork
    public func queueGameForArtworkSearch(_ gameID: String) async {
        guard ENABLE_ENHANCED_ARTWORK_SEARCH else { return }

        // Verify game doesn't have artwork before queuing
        // Use cache for quick check, will verify in Realm during processing
        if let cachedGame = RomDatabase.gamesCache.values.first(where: { $0.id == gameID }),
           cachedGame.originalArtworkFile == nil,
           cachedGame.originalArtworkURL.isEmpty {
            // Game needs artwork
            if !pendingGames.contains(gameID) {
                pendingGames.append(gameID)
                ILOG("ArtworkSearchQueue: Queued game \(cachedGame.title ?? gameID) for enhanced artwork search")
            }
        }
    }

    /// Process pending artwork searches (lower priority)
    /// Should be called after primary imports complete
    public func processPendingSearches() async {
        guard ENABLE_ENHANCED_ARTWORK_SEARCH else { return }
        guard !isProcessing, !pendingGames.isEmpty else { return }

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
    }

    /// Process a batch of games for artwork search
    private func processBatch(_ gameIDs: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for gameID in gameIDs {
                group.addTask {
                    await self.searchArtworkForGame(gameID)
                }
            }
        }
    }

    /// Search for artwork for a specific game using enhanced search
    private func searchArtworkForGame(_ gameID: String) async {
        // Get game from Realm on current thread
        let realm = RomDatabase.sharedInstance.realm

        guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: gameID) else {
            WLOG("ArtworkSearchQueue: Game \(gameID) not found in database")
            return
        }

        // Double-check game still needs artwork
        guard game.originalArtworkFile == nil,
              game.originalArtworkURL.isEmpty else {
            return
        }

        // Clean game title for search (same logic as ArtworkSearchView)
        let searchName = (game.title ?? "").cleanedForSearch()
        guard !searchName.isEmpty else {
            WLOG("ArtworkSearchQueue: Game \(gameID) has no searchable title")
            return
        }

        let systemID = SystemIdentifier(rawValue: game.systemIdentifier)
        let gameTitle = game.title ?? gameID

        do {
            // Progressive fallback search: try with systemID first, then without if no results
            // This matches the behavior of ArtworkSearchView and handles systems not in all databases
            var artworkResults: [ArtworkMetadata]? = nil

            // First attempt: search with systemID (more precise)
            if let systemID = systemID {
                artworkResults = try await lookup.searchArtwork(
                    byGameName: searchName,
                    systemID: systemID,
                    artworkTypes: .defaults
                )
                ILOG("ArtworkSearchQueue: First search attempt for \(gameTitle) with system \(systemID.rawValue): found \(artworkResults?.count ?? 0) results")
            }

            // Fallback: if no results with systemID, try without systemID (broader search)
            // This helps when the system isn't in certain databases (e.g., OpenVGDB)
            if artworkResults?.isEmpty ?? true {
                let fallbackResults = try await lookup.searchArtwork(
                    byGameName: searchName,
                    systemID: nil,
                    artworkTypes: .defaults
                )

                if let fallbackResults = fallbackResults, !fallbackResults.isEmpty {
                    ILOG("ArtworkSearchQueue: Fallback search (no system) for \(gameTitle): found \(fallbackResults.count) results")
                    artworkResults = fallbackResults
                } else {
                    VLOG("ArtworkSearchQueue: No artwork found for \(gameTitle) in any search attempt")
                }
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

                // Download the image
                if let response = try? await URLSession.shared.data(from: artworkURL),
                   (response.1 as? HTTPURLResponse)?.statusCode == 200 {
                    imageData = response.0
                }

                if let data = imageData {
                    #if os(macOS)
                    if let artwork = NSImage(data: data) {
                        do {
                            let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURL.absoluteString)
                            try realm.write {
                                let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                                game.originalArtworkFile = file
                                game.originalArtworkURL = artworkURL.absoluteString
                            }
                            ILOG("ArtworkSearchQueue: Downloaded and cached artwork for \(gameTitle)")
                        } catch {
                            WLOG("ArtworkSearchQueue: Failed to cache artwork for \(gameTitle): \(error.localizedDescription)")
                        }
                    }
                    #elseif !os(watchOS)
                    if let artwork = UIImage(data: data) {
                        do {
                            let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: artworkURL.absoluteString)
                            try realm.write {
                                let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                                game.originalArtworkFile = file
                                game.originalArtworkURL = artworkURL.absoluteString
                            }
                            ILOG("ArtworkSearchQueue: Downloaded and cached artwork for \(gameTitle)")
                        } catch {
                            WLOG("ArtworkSearchQueue: Failed to cache artwork for \(gameTitle): \(error.localizedDescription)")
                        }
                    }
                    #endif
                } else {
                    // If download failed, at least set the URL so it can be downloaded later
                    try realm.write {
                        game.originalArtworkURL = artworkURL.absoluteString
                    }
                    WLOG("ArtworkSearchQueue: Found artwork URL for \(gameTitle) but download failed, URL saved for later")
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
}

/// Extension to clean game titles for artwork search (same as ArtworkSearchView)
private extension String {
    func cleanedForSearch() -> String {
        var cleaned = self

        // Remove text in brackets: [], (), {}
        let bracketPatterns = [
            "\\[.*?\\]",  // Square brackets
            "\\(.*?\\)",  // Parentheses
            "\\{.*?\\}"   // Curly braces
        ]

        for pattern in bracketPatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        // Remove specific characters when surrounded by spaces
        let charsToRemove = ",:;!^%&*+/-"
        let spacePattern = "\\s[\(charsToRemove)]\\s"

        cleaned = cleaned.replacingOccurrences(
            of: spacePattern,
            with: " ",
            options: .regularExpression
        )

        // Trim whitespace and newlines
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
