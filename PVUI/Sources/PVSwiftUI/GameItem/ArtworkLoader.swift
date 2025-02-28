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

/// A shared loader for game artwork that prioritizes visible items and caches results
@MainActor
class ArtworkLoader: ObservableObject {
    /// Shared instance for the application
    static let shared = ArtworkLoader()

    /// In-memory cache for quick access to recently used images
    private let imageCache = NSCache<NSString, UIImage>()

    /// Queue for loading operations with controlled concurrency
    private let loadingQueue: OperationQueue

    /// Active loading tasks by game ID
    private var loadingTasks: [String: Task<UIImage?, Error>] = [:]

    /// Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Initialize the loader with default settings
    init() {
        self.loadingQueue = OperationQueue()
        self.loadingQueue.name = "com.provenance.artworkLoader"
        self.loadingQueue.maxConcurrentOperationCount = 3
        self.loadingQueue.qualityOfService = .userInitiated

        // Configure cache
        imageCache.name = "com.provenance.artworkCache"
        imageCache.countLimit = 100

        // Set up memory warning handler
        #if !os(tvOS)
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
        #endif
    }

    /// Load artwork for a game with priority based on visibility
    /// - Parameters:
    ///   - game: The game to load artwork for
    ///   - priority: The priority of the loading operation
    ///   - isVisible: Whether the game item is currently visible
    /// - Returns: The loaded artwork image, if available
    func loadArtwork(for game: PVGame, priority: TaskPriority = .medium, isVisible: Bool = true) async -> UIImage? {
        guard !game.isInvalidated else { return nil }

        // Use game ID as cache key
        let cacheKey = game.id as NSString

        // Check in-memory cache first
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

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

            do {
                // Fetch the artwork using the existing method
                let image = await game.fetchArtworkFromCache()

                // Cache the result if successful
                if let image = image {
                    self.imageCache.setObject(image, forKey: cacheKey)
                }

                return image
            } catch {
                DLOG("Failed to load artwork for \(game.title): \(error.localizedDescription)")
                throw error
            }
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

    /// Handle memory warning by clearing the cache
    private func handleMemoryWarning() {
        DLOG("Memory warning received, clearing artwork cache")
        imageCache.removeAllObjects()
    }

    /// Preload artwork for a collection of games
    /// - Parameter games: The games to preload artwork for
    /// - Parameter priority: The priority to use for preloading
    func preloadArtwork(for games: [PVGame], priority: TaskPriority = .low) {
        Task(priority: priority) {
            for game in games {
                guard !Task.isCancelled else { break }

                // Skip if already cached
                let cacheKey = game.id as NSString
                if imageCache.object(forKey: cacheKey) != nil {
                    continue
                }

                // Load with low priority and mark as not visible
                _ = await loadArtwork(for: game, priority: priority, isVisible: false)

                // Small delay between loads to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
            }
        }
    }
}
