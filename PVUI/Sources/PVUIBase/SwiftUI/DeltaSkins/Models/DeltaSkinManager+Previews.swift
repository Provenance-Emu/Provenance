import Foundation
import PVLibrary
import PVLogging
import PVSystems
import SkinKitCore
import SkinKitManager
import SkinKitUI
import UIKit

// MARK: - Skin Preview Image Caching

/// Preview images in `PVMediaCache`. App code: SkinKit has no media cache.
extension DeltaSkinManager {
    private static let skinPreviewCacheKeyPrefix = "deltaskin_preview_"

    /// Default traits for preview images
    private static let defaultPreviewTraits = DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .portrait)

    /// Alternative traits to try if default traits aren't supported
    private static let alternativeTraits: [DeltaSkinTraits] = [
        DeltaSkinTraits(device: .iphone, displayType: .edgeToEdge, orientation: .portrait),
        DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .landscape),
        DeltaSkinTraits(device: .ipad, displayType: .standard, orientation: .portrait),
        DeltaSkinTraits(device: .ipad, displayType: .standard, orientation: .landscape)
    ]

    /// Generate a cache key for a skin preview image
    private func previewCacheKey(for skin: any DeltaSkinProtocol, device: DeltaSkinDevice? = nil) -> String {
        var key = DeltaSkinManager.skinPreviewCacheKeyPrefix + skin.identifier
        if let device = device {
            key += "_\(device.rawValue)"
        }
        return key
    }

    /// Get a preview image for a skin, using cache if available
    /// - Parameter skin: The skin to get a preview for
    /// - Returns: A preview image if available, nil otherwise
    public func previewImage(for skin: any DeltaSkinProtocol) async -> UIImage? {
        let cacheKey = previewCacheKey(for: skin)

        // Check if image is already cached
        if let cachedImage = await PVMediaCache.shareInstance().image(forKey: cacheKey) {
            DLOG("Using cached preview for skin: \(skin.name)")
            return cachedImage
        }

        // Generate a new preview image
        return await generateAndCachePreview(for: skin)
    }

    /// Get a preview image for a skin with specific device type, using cache if available
    /// - Parameters:
    ///   - skin: The skin to get a preview for
    ///   - device: The device type to render the preview for
    /// - Returns: A preview image if available, nil otherwise
    public func previewImage(for skin: any DeltaSkinProtocol, device: DeltaSkinDevice) async -> UIImage? {
        let cacheKey = previewCacheKey(for: skin, device: device)

        // Check if image is already cached
        if let cachedImage = await PVMediaCache.shareInstance().image(forKey: cacheKey) {
            DLOG("Using cached preview for skin: \(skin.name) on device: \(device.rawValue)")
            return cachedImage
        }

        // Generate a new preview image for the specified device
        return await generateAndCachePreview(for: skin, device: device)
    }

    /// Generate and cache a preview image for a skin
    /// - Parameter skin: The skin to generate a preview for
    /// - Returns: The generated preview image, or nil if generation failed
    private func generateAndCachePreview(for skin: any DeltaSkinProtocol) async -> UIImage? {
        DLOG("Generating preview for skin: \(skin.name)")

        // Try default traits first
        if skin.supports(Self.defaultPreviewTraits) {
            return await generatePreview(for: skin, with: Self.defaultPreviewTraits)
        }

        // Try alternative traits if default isn't supported
        for traits in Self.alternativeTraits where skin.supports(traits) {
            return await generatePreview(for: skin, with: traits)
        }

        DLOG("No supported traits found for skin: \(skin.name)")
        return nil
    }

    /// Generate and cache a preview image for a skin with specific device type
    /// - Parameters:
    ///   - skin: The skin to generate a preview for
    ///   - device: The device type to render the preview for
    /// - Returns: The generated preview image, or nil if generation failed
    private func generateAndCachePreview(for skin: any DeltaSkinProtocol, device: DeltaSkinDevice) async -> UIImage? {
        DLOG("Generating preview for skin: \(skin.name) on device: \(device.rawValue)")

        // Try device-specific traits first (portrait, then landscape)
        let deviceTraits: [DeltaSkinTraits] = [
            DeltaSkinTraits(device: device, displayType: .standard, orientation: .portrait),
            DeltaSkinTraits(device: device, displayType: .edgeToEdge, orientation: .portrait),
            DeltaSkinTraits(device: device, displayType: .standard, orientation: .landscape),
            DeltaSkinTraits(device: device, displayType: .edgeToEdge, orientation: .landscape)
        ]

        for traits in deviceTraits where skin.supports(traits) {
            return await generatePreview(for: skin, with: traits, device: device)
        }

        DLOG("No supported traits found for skin: \(skin.name) on device: \(device.rawValue)")
        return nil
    }

    /// Generate a preview image for a skin with specific traits and cache it
    /// - Parameters:
    ///   - skin: The skin to generate a preview for
    ///   - traits: The traits to use for the preview
    /// - Returns: The generated preview image, or nil if generation failed
    private func generatePreview(for skin: any DeltaSkinProtocol, with traits: DeltaSkinTraits) async -> UIImage? {
        return await generatePreview(for: skin, with: traits, device: nil)
    }

    /// Generate a preview image for a skin with specific traits and cache it
    /// - Parameters:
    ///   - skin: The skin to generate a preview for
    ///   - traits: The traits to use for the preview
    ///   - device: Optional device type for cache key differentiation
    /// - Returns: The generated preview image, or nil if generation failed
    private func generatePreview(for skin: any DeltaSkinProtocol, with traits: DeltaSkinTraits, device: DeltaSkinDevice?) async -> UIImage? {
        do {
            // Get the skin image for the specified traits
            guard let renderable = skin.renderable else { return nil }
            let skinImage = try await renderable.image(for: traits)

            // Create a smaller preview image for the cache
            let previewImage = skinImage.scaledImage(withMaxResolution: 300) ?? skinImage

            // Cache the preview image with device-specific key if provided
            let cacheKey = previewCacheKey(for: skin, device: device)
            try PVMediaCache.writeImage(toDisk: previewImage, withKey: cacheKey)

            DLOG("Generated and cached preview for skin: \(skin.name)\(device.map { " on device: \($0.rawValue)" } ?? "")")
            return previewImage
        } catch {
            ELOG("Failed to generate preview for skin \(skin.name): \(error)")
            return nil
        }
    }

    /// Invalidate cached preview for a skin
    /// - Parameter skin: The skin to invalidate the preview for
    public func invalidatePreview(for skin: any DeltaSkinProtocol) {
        let cacheKey = previewCacheKey(for: skin)
        Task {
            try? PVMediaCache.deleteImage(forKey: cacheKey)
            DLOG("Invalidated preview cache for skin: \(skin.name)")
        }
    }

    /// Invalidate cached preview for a skin with specific device type
    /// - Parameters:
    ///   - skin: The skin to invalidate the preview for
    ///   - device: The device type to invalidate the preview for
    public func invalidatePreview(for skin: any DeltaSkinProtocol, device: DeltaSkinDevice) {
        let cacheKey = previewCacheKey(for: skin, device: device)
        Task {
            try? PVMediaCache.deleteImage(forKey: cacheKey)
            DLOG("Invalidated preview cache for skin: \(skin.name) on device: \(device.rawValue)")
        }
    }

    /// Preload preview images for multiple skins
    /// - Parameter skins: The skins to preload previews for
    public func preloadPreviews(for skins: [any DeltaSkinProtocol]) async {
        DLOG("Preloading previews for \(skins.count) skins")

        // Create a task group for concurrent loading
        await withTaskGroup(of: Void.self) { group in
            for skin in skins {
                group.addTask {
                    _ = await self.previewImage(for: skin)
                }
            }
        }
    }
}

// MARK: - Session Skin Management

/// `SystemIdentifier` overloads of SkinKitManager's session-skin pass-throughs.
extension DeltaSkinManager {
    /// Set or clear the session skin for a system
    public func setSessionSkin(_ skinIdentifier: String?, for systemId: SystemIdentifier, orientation: SkinOrientation) {
        setSessionSkin(skinIdentifier, for: systemId.skinSystemID, orientation: orientation)
    }

    /// Set or clear the session skin for a specific game
    public func setSessionSkin(_ skinIdentifier: String?, for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) {
        setSessionSkin(skinIdentifier, for: systemId.skinSystemID, gameId: gameId, orientation: orientation)
    }

    /// Get the session skin identifier for a specific game
    public func sessionSkinIdentifier(for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) -> String? {
        sessionSkinIdentifier(for: systemId.skinSystemID, gameId: gameId, orientation: orientation)
    }

    /// Get the effective skin identifier for a game, checking game-specific session skins first,
    /// then system session skins, then game preferences, and finally system preferences
    public func effectiveGameSkinIdentifier(for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) -> String? {
        effectiveGameSkinIdentifier(for: systemId.skinSystemID, gameId: gameId, orientation: orientation)
    }
}
