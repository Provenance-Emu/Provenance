//
//  ArtworkLoader.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVRealm
import PVMediaCache
import RealmSwift
import PVLogging
import Combine

/// A simple loader for game artwork that prioritizes visible items
/// This class uses PVMediaCache directly without additional caching layers
@MainActor
class ArtworkLoader: ObservableObject {
    /// Shared instance for the application
    static let shared = ArtworkLoader()

    /// Active loading tasks by game ID to prevent duplicate loads
    private var loadingTasks: [String: Task<UIImage?, Error>] = [:]

    /// Initialize the loader with default settings
    init() {}

    /// Load artwork for a game with priority based on visibility
    /// - Parameters:
    ///   - game: The game to load artwork for
    ///   - priority: The priority of the loading operation
    ///   - isVisible: Whether the game item is currently visible
    /// - Returns: The loaded artwork image, if available
    func loadArtwork(for game: PVGame, priority: TaskPriority = .medium, isVisible: Bool = true) async -> UIImage? {
        guard !game.isInvalidated else { return nil }

        // If game has no artwork URL, return nil early
        let artworkURL = game.trueArtworkURL
        guard !artworkURL.isEmpty else {
            return nil
        }

        // If there's already a task loading this artwork, join it
        if let existingTask = loadingTasks[game.id] {
            do {
                return try await existingTask.value
            } catch {
                DLOG("Error loading artwork for \(game.title): \(error.localizedDescription)")
                return nil
            }
        }

        // Create a new loading task with the specified priority
        let loadingTask = Task(priority: priority) {
            // Yield to allow UI updates if we're loading many items
            if !isVisible {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay for non-visible items
            }

            // Fetch the artwork directly from PVMediaCache
            return await game.fetchArtworkFromCache()
        }

        // Store the task
        loadingTasks[game.id] = loadingTask

        do {
            // Wait for the task to complete
            let result = try await loadingTask.value

            // Remove the task from the dictionary
            loadingTasks[game.id] = nil

            return result
        } catch {
            // Remove the task from the dictionary on error
            loadingTasks[game.id] = nil
            DLOG("Error loading artwork for \(game.title): \(error.localizedDescription)")
            return nil
        }
    }

    /// Cancel loading for a specific game
    func cancelLoading(for gameId: String) {
        loadingTasks[gameId]?.cancel()
        loadingTasks[gameId] = nil
    }

    /// Preload artwork for a collection of games
    /// - Parameter games: The games to preload artwork for
    /// - Parameter priority: The priority to use for preloading
    func preloadArtwork(for games: [PVGame], priority: TaskPriority = .low) {
        Task(priority: priority) {
            // Extract valid artwork URLs
            let artworkURLs = games.compactMap { game -> String? in
                let url = game.trueArtworkURL
                return url.isEmpty ? nil : url
            }

            // Use PVMediaCache's preload method directly
            if !artworkURLs.isEmpty {
                await PVMediaCache.shareInstance().preloadImages(forKeys: artworkURLs)
            }
        }
    }
}
