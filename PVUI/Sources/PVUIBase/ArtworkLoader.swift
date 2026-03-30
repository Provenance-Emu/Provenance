//
//  ArtworkLoader.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVLibrary
import PVRealm
import PVMediaCache
import RealmSwift
import PVLogging
import Combine

/// A simple loader for game artwork that prioritizes visible items
/// This class uses PVMediaCache directly without additional caching layers
@MainActor
public class ArtworkLoader: ObservableObject {
    /// Shared instance for the application
    public static let shared = ArtworkLoader()

    /// Active loading tasks by game ID to prevent duplicate loads
    private var loadingTasks: [String: Task<UIImage?, Error>] = [:]

    /// Recently accessed game IDs to prioritize caching
    private var recentlyAccessedIds = Set<String>()

    /// Maximum number of recent IDs to track
    private let maxRecentIds = 50

    /// Queue for managing background preloading tasks
    private let preloadQueue = DispatchQueue(label: "com.provenance.artworkPreloader", qos: .utility, attributes: .concurrent)

    /// Semaphore to limit concurrent preloading operations
    private let preloadSemaphore = DispatchSemaphore(value: 4)

    // MARK: - Local file URL memo cache (for resolveLocalArtworkFileURL)

    /// Game IDs for which a local file URL lookup has already been performed (hits AND misses).
    /// A game ID in this set means the lookup is complete; check `localURLCache` to see whether
    /// a file URL was found. Misses are tracked here rather than as nil entries in the dictionary
    /// because Swift dictionaries cannot distinguish "key absent" from "key present with nil value"
    /// when the value type is non-optional.
    private var localURLResolvedIds: Set<String> = []
    /// Resolved local filesystem URLs, keyed by game ID. Only hit entries are stored here.
    /// To test for a miss, check `localURLResolvedIds.contains(gameId)` first.
    private var localURLCache: [String: URL] = [:]

    /// Initialize the loader with default settings
    init() {}

    /// Load artwork for a game with priority based on visibility
    /// Uses thread-safe parameters instead of Realm objects to avoid thread crashes
    /// - Parameters:
    ///   - gameId: The game's unique identifier
    ///   - artworkURL: The artwork URL (pre-extracted from game.trueArtworkURL)
    ///   - gameTitle: The game title for logging
    ///   - priority: The priority of the loading operation
    ///   - isVisible: Whether the game item is currently visible
    /// - Returns: The loaded artwork image, if available
    public func loadArtwork(
        gameId: String,
        artworkURL: String,
        gameTitle: String,
        priority: TaskPriority = .medium,
        isVisible: Bool = true
    ) async -> UIImage? {
        // If game has no artwork URL, return nil early
        guard !artworkURL.isEmpty else {
            return nil
        }

        // Track this game ID as recently accessed
        updateRecentlyAccessed(gameId: gameId)

        // If there's already a task loading this artwork, join it
        if let existingTask = loadingTasks[gameId] {
            do {
                return try await existingTask.value
            } catch {
                DLOG("Error loading artwork for \(gameTitle): \(error.localizedDescription)")
                return nil
            }
        }

        // Create a new loading task with the specified priority
        let loadingTask = Task(priority: priority) {
            // Check cancellation before starting work
            try Task.checkCancellation()

            // Yield to allow UI updates if we're loading many items
            if !isVisible {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay for non-visible items
            }

            try Task.checkCancellation()

            // Fetch the artwork directly from PVMediaCache using the pre-extracted URL
            return await PVMediaCache.shareInstance().image(forKey: artworkURL)
        }

        // Store the task
        loadingTasks[gameId] = loadingTask

        do {
            // Wait for the task to complete
            let result = try await loadingTask.value

            // Remove the task from the dictionary
            loadingTasks[gameId] = nil

            return result
        } catch {
            // Remove the task from the dictionary on error
            loadingTasks[gameId] = nil
            DLOG("Error loading artwork for \(gameTitle): \(error.localizedDescription)")
            return nil
        }
    }

    /// Legacy method for backward compatibility - extracts values on main thread
    /// - Parameters:
    ///   - game: The game to load artwork for (must be called from main thread)
    ///   - priority: The priority of the loading operation
    ///   - isVisible: Whether the game item is currently visible
    /// - Returns: The loaded artwork image, if available
    @MainActor
    public func loadArtwork(for game: PVGame, priority: TaskPriority = .medium, isVisible: Bool = true) async -> UIImage? {
        guard !game.isInvalidated else { return nil }

        // Extract thread-safe values on main thread
        let gameId = game.id
        let artworkURL = game.trueArtworkURL
        let gameTitle = game.title

        return await loadArtwork(
            gameId: gameId,
            artworkURL: artworkURL,
            gameTitle: gameTitle,
            priority: priority,
            isVisible: isVisible
        )
    }

    /// Update the recently accessed game IDs set
    private func updateRecentlyAccessed(gameId: String) {
        recentlyAccessedIds.insert(gameId)

        // Trim if we exceed the maximum size
        if recentlyAccessedIds.count > maxRecentIds {
            // Remove oldest entries (approximation by removing random elements)
            while recentlyAccessedIds.count > maxRecentIds {
                if let first = recentlyAccessedIds.first {
                    recentlyAccessedIds.remove(first)
                }
            }
        }
    }

    /// Cancel loading for a specific game
    public func cancelLoading(for gameId: String) {
        loadingTasks[gameId]?.cancel()
        loadingTasks[gameId] = nil
    }

    // MARK: - Local Artwork File URL Resolution

    /// Returns the local filesystem URL for a game's artwork file, or `nil` if none is cached on disk.
    ///
    /// Both resolution paths verify that the file exists on disk before returning a URL.
    ///
    /// Resolution order:
    /// 1. `originalArtworkFile.pathOfCachedImage` — the direct-path local copy stored as a
    ///    `PVImageFile`; returns `nil` if the file has been deleted.
    /// 2. `PVMediaCache.filePath(forKey:)` via `game.trueArtworkURL` — for legacy games that
    ///    have only a remote URL string and no `PVImageFile` entry.
    ///
    /// Results are memoized so repeated calls (e.g. during list filtering while the user types)
    /// do not re-hit the Realm database or filesystem on every pass.
    /// Call `clearLocalURLCache()` after artwork is re-downloaded or updated.
    ///
    /// This method works with the Realm-backed `RomDatabase`. When SwiftData support is added,
    /// replace or augment `_resolveLocalURLFromDatabase(gameId:)` without changing call sites.
    @MainActor
    public func resolveLocalArtworkFileURL(forGameId gameId: String) -> URL? {
        if localURLResolvedIds.contains(gameId) {
            return localURLCache[gameId]
        }
        let url = _resolveLocalURLFromDatabase(gameId: gameId)
        localURLResolvedIds.insert(gameId)
        if let url {
            localURLCache[gameId] = url
        }
        return url
    }

    /// Clears the local URL memo cache.
    /// Call this after artwork is updated or re-imported so subsequent
    /// calls to `resolveLocalArtworkFileURL(forGameId:)` re-read from disk.
    @MainActor
    public func clearLocalURLCache() {
        localURLResolvedIds.removeAll()
        localURLCache.removeAll()
    }

    /// Clears the local URL memo cache for a single game.
    /// Useful when only one game's artwork has changed.
    @MainActor
    public func clearLocalURLCache(forGameId gameId: String) {
        localURLResolvedIds.remove(gameId)
        localURLCache[gameId] = nil
    }

    @MainActor
    private func _resolveLocalURLFromDatabase(gameId: String) -> URL? {
        guard let game = RomDatabase.sharedInstance
            .object(ofType: PVGame.self, wherePrimaryKeyEquals: gameId)
        else { return nil }
        // Prefer the direct-path PVImageFile entry (avoids a second hash lookup).
        // Use pathOfCachedImage rather than .url so we only return URLs for files
        // that actually exist on disk (guards against stale/deleted artwork).
        if let fileURL = game.originalArtworkFile?.pathOfCachedImage {
            return fileURL
        }
        // Fall back to PVMediaCache keyed by the artwork URL string (legacy path).
        let key = game.trueArtworkURL
        guard !key.isEmpty,
              PVMediaCache.fileExists(forKey: key),
              let localURL = PVMediaCache.filePath(forKey: key)
        else { return nil }
        return localURL
    }

    /// Preload artwork for a collection of games
    /// - Parameter games: The games to preload artwork for
    /// - Parameter priority: The priority to use for preloading
    @MainActor
    public func preloadArtwork(for games: [PVGame], priority: TaskPriority = .low) {
        /// Extract artwork URLs on main thread to avoid Realm thread issues
        /// Sort by recently accessed first, then by title
        let artworkURLs: [String] = games
            .filter { !$0.isInvalidated }
            .sorted { game1, game2 in
                let isRecent1 = recentlyAccessedIds.contains(game1.id)
                let isRecent2 = recentlyAccessedIds.contains(game2.id)

                if isRecent1 && !isRecent2 {
                    return true
                } else if !isRecent1 && isRecent2 {
                    return false
                } else {
                    return game1.title < game2.title
                }
            }
            .compactMap { game -> String? in
                let url = game.trueArtworkURL
                return url.isEmpty ? nil : url
            }

        /// Now preload with thread-safe URLs
        guard !artworkURLs.isEmpty else { return }

        Task(priority: priority) {
            await PVMediaCache.shareInstance().preloadImages(forKeys: artworkURLs)
        }
    }
}
