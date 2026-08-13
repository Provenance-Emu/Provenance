//
//  SwiftImage.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes
import PVSettings
import PVMediaCache
import Defaults
import Foundation

#if os(macOS)
public typealias SwiftImage = NSImage
#else
public typealias SwiftImage = UIImage
#endif

/// Manages both memory and disk caching for missing artwork images
public class MissingArtworkCacheManager {
    /// Shared instance for the cache manager
    public static let shared = MissingArtworkCacheManager()

    /// In-memory cache for quick access.
    ///
    /// Previously a bare `NSCache` with `countLimit = 200` and **no**
    /// `totalCostLimit`, whose `setObject` calls supplied no cost — so no byte
    /// budget was ever applied. Each entry is a full placeholder bitmap
    /// (several MB), keyed per game title, giving a ceiling well over a
    /// gigabyte. `ImageMemoryCache` costs entries by decoded byte size and
    /// purges on memory warnings.
    private let memoryCache = ImageMemoryCache(
        name: "MissingArtworkCache",
        totalCostLimit: ImageCacheBudget.missingArtwork,
        countLimit: MissingArtworkCacheManager.maxMemoryCachedImages
    )

    /// Entry-count guard. `totalCostLimit` is the real bound.
    private static let maxMemoryCachedImages = 200

    /// URL for the disk cache directory
    private let diskCacheURL: URL

    /// Maximum number of disk-cached images to keep - increased for better hit rates
    private let maxDiskCachedImages = 500

    private init() {
        // Create disk cache directory in the caches folder
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cachesDirectory.appendingPathComponent("MissingArtworkCache", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: diskCacheURL.path) {
            try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }

    /// Generate a cache key for missing artwork images
    private func cacheKey(gameTitle: String, ratio: CGFloat, pattern: RetroTestPattern, minFontSize: CGFloat, isDarkTheme: Bool) -> String {
        let themeSuffix = isDarkTheme ? "dark" : "light"
        return "\(gameTitle)_\(ratio)_\(pattern.rawValue)_\(minFontSize)_\(themeSuffix)"
    }

    /// Get the disk URL for a cache key
    private func diskURL(for key: String) -> URL {
        // Create a safe filename from the key
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
                         .replacingOccurrences(of: ":", with: "_")
                         .replacingOccurrences(of: " ", with: "_")
        return diskCacheURL.appendingPathComponent("\(safeKey).png")
    }

    /// Get an image from cache (memory or disk)
    public func getImage(gameTitle: String, ratio: CGFloat, pattern: RetroTestPattern, minFontSize: CGFloat, isDarkTheme: Bool) -> SwiftImage? {
        let key = cacheKey(gameTitle: gameTitle, ratio: ratio, pattern: pattern, minFontSize: minFontSize, isDarkTheme: isDarkTheme)

        // Check memory cache first
        if let cachedImage = memoryCache.image(forKey: key) {
            return cachedImage
        }

        // If not in memory, check disk cache.
        // Decode through `ArtworkDownsampler` rather than `SwiftImage(data:)`:
        // the on-disk PNG is a full placeholder bitmap, and reloading it at
        // source resolution is the path that lands in "Image IO" memory.
        let fileURL = diskURL(for: key)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let image = autoreleasepool(invoking: {
            ArtworkDownsampler.image(atPath: fileURL.path, target: .thumbnail)
        }) else { return nil }

        // Store in memory cache for faster access next time
        memoryCache.setImage(image, forKey: key)
        return image
    }

    /// Store an image in both memory and disk cache
    public func storeImage(_ image: SwiftImage, gameTitle: String, ratio: CGFloat, pattern: RetroTestPattern, minFontSize: CGFloat, isDarkTheme: Bool) {
        let key = cacheKey(gameTitle: gameTitle, ratio: ratio, pattern: pattern, minFontSize: minFontSize, isDarkTheme: isDarkTheme)

        // Store in memory cache
        memoryCache.setImage(image, forKey: key)

        // Store in disk cache — capture image strongly so it survives until write completes
        let fileURL = diskURL(for: key)
        Task.detached {
            /// `pngData()` on a multi-megapixel bitmap allocates a second copy;
            /// bound it so the encode buffer is released immediately.
            let data = autoreleasepool { image.pngData() }
            if let data {
                try? data.write(to: fileURL)
            }
        }

        // Clean up disk cache if needed (debounced, off main thread)
        scheduleDiskCacheCleanup()
    }

    /// Pending cleanup work item — coalesces rapid storeImage calls.
    private static var cleanupWorkItem: DispatchWorkItem?
    /// Protects `cleanupWorkItem` from concurrent access across threads.
    private static let cleanupLock = NSLock()

    /// Schedules a debounced disk cache cleanup on a background queue.
    /// Multiple storeImage calls within 2 seconds share one cleanup pass.
    private func scheduleDiskCacheCleanup() {
        let cacheURL = diskCacheURL
        let limit = maxDiskCachedImages
        Self.cleanupLock.lock()
        Self.cleanupWorkItem?.cancel()
        let work = DispatchWorkItem {
            Self.performDiskCacheCleanup(cacheURL: cacheURL, limit: limit)
        }
        Self.cleanupWorkItem = work
        Self.cleanupLock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    /// Performs the actual disk cache cleanup. Runs on a background queue.
    private static func performDiskCacheCleanup(cacheURL: URL, limit: Int) {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        guard fileURLs.count > limit else { return }

        let sortedURLs = (try? fileURLs.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return date1 < date2
        }) ?? []

        let filesToRemove = sortedURLs.prefix(fileURLs.count - limit)
        for fileURL in filesToRemove {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Clear all caches (memory and disk)
    public func clearAllCaches() {
        // Clear memory cache
        memoryCache.removeAll()

        // Clear disk cache
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: diskCacheURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Error clearing disk cache: \(error)")
        }
    }

    /// Preload images for multiple games in background
    public func preloadImages(
        games: [(title: String, ratio: CGFloat)],
        pattern: RetroTestPattern,
        minFontSize: CGFloat = 12.0,
        isDarkTheme: Bool
    ) {
        Task.detached(priority: .utility) {
            for game in games {
                /// One pool per iteration — generating a placeholder allocates a
                /// multi-megapixel bitmap plus its PNG encode buffer, and without
                /// a pool the whole batch accumulates before the loop exits.
                autoreleasepool {
                    /// Check if already cached
                    if self.getImage(
                        gameTitle: game.title,
                        ratio: game.ratio,
                        pattern: pattern,
                        minFontSize: minFontSize,
                        isDarkTheme: isDarkTheme
                    ) != nil {
                        return
                    }

                    /// Generate and cache
                    let image = SwiftImage.missingArtworkImage(
                        gameTitle: game.title,
                        ratio: game.ratio,
                        pattern: pattern,
                        minFontSize: minFontSize
                    )

                    self.storeImage(
                        image,
                        gameTitle: game.title,
                        ratio: game.ratio,
                        pattern: pattern,
                        minFontSize: minFontSize,
                        isDarkTheme: isDarkTheme
                    )
                }
            }
        }
    }
}

public extension Defaults.Keys {
    // Missing artwork style setting
    static let missingArtworkStyle = Key<RetroTestPattern>("missingArtworkStyle", default: .rainbowNoise)
}

/// `RetroTestPattern` is defined in `PVMediaCache` so it can be shared with app
/// extensions. PVUIBase adds the `UserDefaultsRepresentable` + `Defaults.Serializable`
/// conformances needed for the in-app preference.
extension RetroTestPattern: UserDefaultsRepresentable, Defaults.Serializable {}

extension SwiftImage {
    /// Synchronous generator. Looks up the in-memory + on-disk
    /// `MissingArtworkCacheManager` cache before delegating to the shared
    /// `MissingArtworkGenerator` so the same artwork is returned across the app.
    public static func missingArtworkImage(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern = Defaults[.missingArtworkStyle],
        minFontSize: CGFloat = RetroStyle.defaultMinFontSize
    ) -> SwiftImage {
        let isDarkTheme = ThemeManager.shared.currentPalette.dark

        if let cached = MissingArtworkCacheManager.shared.getImage(
            gameTitle: gameTitle,
            ratio: ratio,
            pattern: pattern,
            minFontSize: minFontSize,
            isDarkTheme: isDarkTheme
        ) {
            return cached
        }

        let image = MissingArtworkGenerator.generate(
            gameTitle: gameTitle,
            ratio: ratio,
            pattern: pattern,
            isDarkTheme: isDarkTheme,
            minFontSize: minFontSize
        )

        MissingArtworkCacheManager.shared.storeImage(
            image,
            gameTitle: gameTitle,
            ratio: ratio,
            pattern: pattern,
            minFontSize: minFontSize,
            isDarkTheme: isDarkTheme
        )
        return image
    }

    /// Async, worker-thread generator with caching. Callers should check the
    /// cache synchronously first for instant display.
    public static func missingArtworkImageAsync(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern = Defaults[.missingArtworkStyle],
        minFontSize: CGFloat = RetroStyle.defaultMinFontSize
    ) async -> SwiftImage {
        let isDarkTheme = ThemeManager.shared.currentPalette.dark

        if let cached = MissingArtworkCacheManager.shared.getImage(
            gameTitle: gameTitle,
            ratio: ratio,
            pattern: pattern,
            minFontSize: minFontSize,
            isDarkTheme: isDarkTheme
        ) {
            return cached
        }

        return await Task.detached(priority: .utility) {
            let image = MissingArtworkGenerator.generate(
                gameTitle: gameTitle,
                ratio: ratio,
                pattern: pattern,
                isDarkTheme: isDarkTheme,
                minFontSize: minFontSize
            )

            MissingArtworkCacheManager.shared.storeImage(
                image,
                gameTitle: gameTitle,
                ratio: ratio,
                pattern: pattern,
                minFontSize: minFontSize,
                isDarkTheme: isDarkTheme
            )
            return image
        }.value
    }
}

// Add a new SwiftUI View for missing artwork with pattern selection
public struct MissingArtworkView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let gameTitle: String
    let ratio: CGFloat
    let pattern: RetroTestPattern

    public init(gameTitle: String, ratio: CGFloat, pattern: RetroTestPattern = .smpteColorBars) {
        self.gameTitle = gameTitle
        self.ratio = ratio
        self.pattern = pattern
    }

    public var body: some View {
        Image(uiImage: SwiftImage.missingArtworkImage(
            gameTitle: gameTitle,
            ratio: ratio,
            pattern: pattern
        ))
        .resizable()
        .aspectRatio(ratio, contentMode: .fit)
        .frame(height: CGFloat(PVThumbnailMaxResolution))
    }
}

// Extension to SwiftUI Image to create a missing artwork image
public extension Image {
    @ViewBuilder
    static func missingArtwork(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern = .smpteColorBars
    ) -> some View {
        MissingArtworkView(gameTitle: gameTitle, ratio: ratio, pattern: pattern)
    }
}
