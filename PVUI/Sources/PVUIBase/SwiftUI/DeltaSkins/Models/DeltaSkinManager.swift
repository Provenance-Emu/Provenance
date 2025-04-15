import Foundation
import ZIPFoundation
import PVLogging
import PVLibrary
import UIKit

/// Manages loading and caching of DeltaSkins
public final class DeltaSkinManager: ObservableObject, DeltaSkinManagerProtocol {
    /// Cache key prefix for skin preview images
    private static let skinPreviewCacheKeyPrefix = "deltaskin_preview_"
    /// Singleton instance
    public static let shared = DeltaSkinManager()

    /// Currently loaded skins
    @Published public private(set) var loadedSkins: [DeltaSkinProtocol] = []

    /// Session-specific skin selections that persist only for the current session
    /// Maps [SystemIdentifier.rawValue: [SkinOrientation.rawValue: skinIdentifier]]
    private var sessionSkins: [String: [String: String]] = [:]

    /// Queue for synchronizing skin operations
    private let queue = DispatchQueue(label: "com.provenance.deltaskin-manager")

    /// Default traits for preview images
    private let defaultPreviewTraits = DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .portrait)

    /// Alternative traits to try if default traits aren't supported
    private let alternativeTraits: [DeltaSkinTraits] = [
        DeltaSkinTraits(device: .iphone, displayType: .edgeToEdge, orientation: .portrait),
        DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .landscape),
        DeltaSkinTraits(device: .ipad, displayType: .standard, orientation: .portrait),
        DeltaSkinTraits(device: .ipad, displayType: .standard, orientation: .landscape)
    ]

    public init() {
        print("Initializing DeltaSkinManager")
        Task.detached { [weak self] in
            try? self?.scanForSkins()
        }

        // Register for session skin notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionSkinRegistration(_:)),
            name: NSNotification.Name("RegisterSessionSkin"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Get all available skins
    public func availableSkins() async throws -> [DeltaSkinProtocol] {
        try await queue.asyncResult {
            try self.scanForSkins()
            return self.loadedSkins
        }
    }

    /// Get a skin by its identifier
    /// - Parameter identifier: The unique identifier of the skin
    /// - Returns: The skin if found, or nil if not found
    public func skin(withIdentifier identifier: String) async throws -> DeltaSkinProtocol? {
        try await queue.asyncResult {
            // Find the skin with the matching identifier
            if let skin = self.loadedSkins.first { $0.identifier == identifier } {
                return skin
            } else {
                // Ensure skins are loaded
                try self.scanForSkins()
                return self.loadedSkins.first { $0.identifier == identifier }
            }
        }
    }

    /// Get the currently selected skin for a system in the current session
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - orientation: The current orientation
    /// - Returns: The session skin identifier if set, otherwise nil
    public func sessionSkinIdentifier(for systemId: SystemIdentifier, orientation: SkinOrientation) -> String? {
        return sessionSkins[systemId.rawValue]?[orientation.rawValue]
    }

    /// Set the session skin for a system
    /// - Parameters:
    ///   - skinIdentifier: The skin identifier to use for the session, or nil to clear
    ///   - systemId: The system identifier
    ///   - orientation: The current orientation
    public func setSessionSkin(_ skinIdentifier: String?, for systemId: SystemIdentifier, orientation: SkinOrientation) {
        queue.sync {
            if let skinIdentifier = skinIdentifier {
                // Initialize the dictionary for this system if needed
                if sessionSkins[systemId.rawValue] == nil {
                    sessionSkins[systemId.rawValue] = [:]
                }

                // Set the skin for this orientation
                sessionSkins[systemId.rawValue]?[orientation.rawValue] = skinIdentifier

                print("Set session skin \(skinIdentifier) for system \(systemId.rawValue) in \(orientation.rawValue) orientation")
            } else {
                // Clear the skin for this orientation
                sessionSkins[systemId.rawValue]?[orientation.rawValue] = nil

                // If both orientations are nil, remove the system entry
                if sessionSkins[systemId.rawValue]?.isEmpty ?? true {
                    sessionSkins.removeValue(forKey: systemId.rawValue)
                }

                print("Cleared session skin for system \(systemId.rawValue) in \(orientation.rawValue) orientation")
            }
        }
    }

    /// Get the selected skin for a system, checking session skins first, then preferences
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - gameId: The game identifier (optional)
    ///   - orientation: The current orientation
    /// - Returns: The effective skin identifier to use
    public func effectiveSkinIdentifier(for systemId: SystemIdentifier, gameId: String? = nil, orientation: SkinOrientation) -> String? {
        
        // Check for system session skin first
        if let sessionSkin = sessionSkinIdentifier(for: systemId, orientation: orientation) {
            return sessionSkin
        }
        
        // Then, ff we have a game ID, check game-specific session skin first
        if let gameId = gameId {
            // Use the composite key for game-specific session skins
            let compositeKey = "\(systemId.rawValue)_\(gameId)"
            if let gameSpecificSessionSkin = sessionSkins[compositeKey]?[orientation.rawValue] {
                return gameSpecificSessionSkin
            }
        }

        // Then check preferences (game-specific, then system)
        if let gameId = gameId {
            return DeltaSkinPreferences.shared.effectiveSkinIdentifier(for: gameId, system: systemId, orientation: orientation)
        } else {
            return DeltaSkinPreferences.shared.selectedSkinIdentifier(for: systemId, orientation: orientation)
        }
    }

    /// Handle session skin registration notifications
    @objc private func handleSessionSkinRegistration(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let systemIdString = userInfo["systemId"] as? String,
              let systemId = SystemIdentifier(rawValue: systemIdString) else {
            return
        }

        // Get the current orientation
        #if !os(tvOS)
        let orientation: SkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
        #else
        let orientation: SkinOrientation = .landscape
        #endif

        // Get the skin identifier (nil means clear)
        let skinIdentifier = userInfo["skinIdentifier"] as? String

        // Set the session skin
        setSessionSkin(skinIdentifier, for: systemId, orientation: orientation)
    }

    /// Load a skin from a file URL
    public func loadSkin(from url: URL) async throws -> DeltaSkinProtocol {
        try await queue.asyncResult {
            try self.loadSkinFromURL(url)
        }
    }

    /// Scan for available skins
    private func scanForSkins() throws {
        DLOG("Starting skin scan...")
        let locations = skinLocations()
        DLOG("Total locations to scan: \(locations.count)")

        // Create a new array to hold all skins
        var scannedSkins: [DeltaSkinProtocol] = []

        for location in locations {
            DLOG("Examining location: \(location.path)")

            do {
                let isDirectory = (try? location.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                DLOG("Is directory: \(isDirectory)")

                // Handle both directory formats:
                // 1. A .deltaskin directory
                // 2. A directory containing .deltaskin files/directories
                if isDirectory {
                    if location.lastPathComponent.hasSuffix(".deltaskin") {
                        // This is a .deltaskin directory, load it directly
                        if let skin = try? loadSkinFromURL(location) {
                            if !scannedSkins.contains(where: { $0.identifier == skin.identifier }) {
                                scannedSkins.append(skin)
                            }
                        }
                    } else {
                        // This is a directory that might contain skins, scan it
                        let contents = try FileManager.default.contentsOfDirectory(
                            at: location,
                            includingPropertiesForKeys: [.isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        )

                        for url in contents where url.lastPathComponent.hasSuffix(".deltaskin") {
                            if let skin = try? loadSkinFromURL(url) {
                                if !scannedSkins.contains(where: { $0.identifier == skin.identifier }) {
                                    scannedSkins.append(skin)
                                }
                            }
                        }
                    }
                } else if location.pathExtension == "deltaskin" {
                    // This is a .deltaskin file (archive)
                    if let skin = try? loadSkinFromURL(location) {
                        if !scannedSkins.contains(where: { $0.identifier == skin.identifier }) {
                            scannedSkins.append(skin)
                        }
                    }
                }
            } catch {
                ELOG("Error scanning location \(location.path): \(error)")
                // Continue scanning other locations
                continue
            }
        }

        // Log results
        DLOG("Scan complete. Available skins by type:")
        let groupedSkins = Dictionary(grouping: scannedSkins) { $0.gameType.rawValue }
        for (type, skins) in groupedSkins.sorted(by: { $0.key < $1.key }) {
            DLOG("- \(type): \(skins.count) skins")
            for skin in skins {
                DLOG("  • \(skin.name)")
            }
        }

        // Update loadedSkins
        Task { @MainActor in
            loadedSkins = scannedSkins
        }
    }

    /// Load a skin from URL and add to loadedSkins
    private func loadSkinFromURL(_ url: URL) throws -> DeltaSkinProtocol {
        DLOG("Loading skin from: \(url.lastPathComponent)")

        do {
            let skin = try DeltaSkin(fileURL: url)
            ILOG("Successfully loaded skin: \(skin.name) (type: \(skin.gameType.rawValue))")

            DLOG("Current loaded skins count: \(loadedSkins.count)")
            Task { @MainActor in
                loadedSkins.append(skin)
            }
            DLOG("New loaded skins count: \(loadedSkins.count)")

            return skin
        } catch {
            ELOG("Failed to load skin from \(url.lastPathComponent): \(error)")
            if let deltaSkinError = error as? DeltaSkinError {
                ELOG("DeltaSkin Error: \(deltaSkinError)")
            }
            throw error
        }
    }

    /// Get locations of skin files
    private func skinLocations() -> [URL] {
        var locations: [URL] = []

        // Add bundle skins from all bundles
        let bundleSkins = Bundle.main.urls(forResourcesWithExtension: "deltaskin", subdirectory: nil) ?? []
        locations.append(contentsOf: bundleSkins)

        if !bundleSkins.isEmpty {
            DLOG("Found bundle skins: \(bundleSkins.map { $0.lastPathComponent })")
            locations.append(contentsOf: bundleSkins)
        } else {
            WLOG("No skinds found in any bundles")
        }

        // Add framework bundle skins
        let frameworkSkins = Bundle.allFrameworks.flatMap { bundle in
            bundle.urls(forResourcesWithExtension: "deltaskin", subdirectory: nil) ?? []
        }
        if !frameworkSkins.isEmpty {
            DLOG("Found framework skins: \(frameworkSkins.map { $0.lastPathComponent })")
            locations.append(contentsOf: frameworkSkins)
        }

        // Add Documents directory skins
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let skinsURL = documentsURL.appendingPathComponent("DeltaSkins")
            DLOG("Found Documents directory: \(skinsURL.path)")
            locations.append(skinsURL)
        }

        DLOG("Total locations to scan: \(locations.count)")
        return locations
    }

    /// Directory for storing imported skins
    public var skinsDirectory: URL {
        get throws {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let skinsURL = documentsURL.appendingPathComponent("DeltaSkins")

            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: skinsURL.path) {
                try FileManager.default.createDirectory(at: skinsURL, withIntermediateDirectories: true)
            }

            return skinsURL
        }
    }

    /// Reload all skins from disk
    @MainActor
    public func reloadSkins() async {
        do {
            try await queue.asyncResult {
                try self.scanForSkins()
                self.objectWillChange.send()
            }
        } catch {
            ELOG("Failed to reload skins: \(error)")
        }
    }

    /// Import a skin from a URL, handling spaces in paths
    public func importSkin(from url: URL) async throws {
        DLOG("Starting skin import from: \(url.path)")

        return try await queue.asyncResult { [self] in
            // Get destination in Documents directory
            let skinsDir = try self.skinsDirectory
            let destinationURL = skinsDir.appendingPathComponent(url.lastPathComponent)

            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                ILOG("Removing existing skin at: \(destinationURL.path)")
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Copy to skins directory
            ILOG("Copying skin to: \(destinationURL.path)")
            try FileManager.default.copyItem(at: url, to: destinationURL)

            // Scan to reload all skins
            // try self.scanForSkins()
        }
    }

    /// Check if a skin can be deleted (i.e., it's in the skins directory and not bundled)
    public func isDeletable(_ skin: DeltaSkinProtocol) -> Bool {
        guard let skinsDir = try? skinsDirectory else { return false }
        return skin.fileURL.path.contains(skinsDir.path)
    }

    /// Delete a skin by its identifier
    public func deleteSkin(_ identifier: String) async throws {
        try await queue.asyncResult { [self] in
            // Find the skin
            guard let skin = self.loadedSkins.first(where: { $0.identifier == identifier }) else {
                throw DeltaSkinError.notFound
            }

            // Verify it's deletable
            guard self.isDeletable(skin) else {
                throw DeltaSkinError.deletionNotAllowed
            }

            // Delete the file
            DLOG("Deleting skin at: \(skin.fileURL.path)")
            try FileManager.default.removeItem(at: skin.fileURL)

            // Update loadedSkins immediately
            self.loadedSkins.removeAll { $0.identifier == identifier }

            // Then rescan on main thread
            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
    }
}

// MARK: - Skin Preview Image Caching
extension DeltaSkinManager {
    /// Generate a cache key for a skin preview image
    private func previewCacheKey(for skin: DeltaSkinProtocol) -> String {
        return DeltaSkinManager.skinPreviewCacheKeyPrefix + skin.identifier
    }

    /// Get a preview image for a skin, using cache if available
    /// - Parameter skin: The skin to get a preview for
    /// - Returns: A preview image if available, nil otherwise
    public func previewImage(for skin: DeltaSkinProtocol) async -> UIImage? {
        let cacheKey = previewCacheKey(for: skin)

        // Check if image is already cached
        if let cachedImage = await PVMediaCache.shareInstance().image(forKey: cacheKey) {
            DLOG("Using cached preview for skin: \(skin.name)")
            return cachedImage
        }

        // Generate a new preview image
        return await generateAndCachePreview(for: skin)
    }

    /// Generate and cache a preview image for a skin
    /// - Parameter skin: The skin to generate a preview for
    /// - Returns: The generated preview image, or nil if generation failed
    private func generateAndCachePreview(for skin: DeltaSkinProtocol) async -> UIImage? {
        DLOG("Generating preview for skin: \(skin.name)")

        // Try default traits first
        if skin.supports(defaultPreviewTraits) {
            return await generatePreview(for: skin, with: defaultPreviewTraits)
        }

        // Try alternative traits if default isn't supported
        for traits in alternativeTraits {
            if skin.supports(traits) {
                return await generatePreview(for: skin, with: traits)
            }
        }

        DLOG("No supported traits found for skin: \(skin.name)")
        return nil
    }

    /// Generate a preview image for a skin with specific traits and cache it
    /// - Parameters:
    ///   - skin: The skin to generate a preview for
    ///   - traits: The traits to use for the preview
    /// - Returns: The generated preview image, or nil if generation failed
    private func generatePreview(for skin: DeltaSkinProtocol, with traits: DeltaSkinTraits) async -> UIImage? {
        do {
            // Get the skin image for the specified traits
            let skinImage = try await skin.image(for: traits)

            // Create a smaller preview image for the cache
            let previewImage = skinImage.scaledImage(withMaxResolution: 300) ?? skinImage

            // Cache the preview image
            let cacheKey = previewCacheKey(for: skin)
            try PVMediaCache.writeImage(toDisk: previewImage, withKey: cacheKey)

            DLOG("Generated and cached preview for skin: \(skin.name)")
            return previewImage
        } catch {
            ELOG("Failed to generate preview for skin \(skin.name): \(error)")
            return nil
        }
    }

    /// Invalidate cached preview for a skin
    /// - Parameter skin: The skin to invalidate the preview for
    public func invalidatePreview(for skin: DeltaSkinProtocol) {
        let cacheKey = previewCacheKey(for: skin)
        Task {
            try? PVMediaCache.deleteImage(forKey: cacheKey)
            DLOG("Invalidated preview cache for skin: \(skin.name)")
        }
    }

    /// Preload preview images for multiple skins
    /// - Parameter skins: The skins to preload previews for
    public func preloadPreviews(for skins: [DeltaSkinProtocol]) async {
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

// MARK: - Helper Extensions
extension DispatchQueue {
    func asyncResult<T>(_ block: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.async {
                do {
                    let result = try block()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

import UniformTypeIdentifiers

// Add UTType for .deltaskin files
public extension UTType {
    static var deltaSkin: UTType {
        UTType(exportedAs: "com.rileytestut.delta.skin")  // Delta's official UTType
    }
}

// MARK: - Extra Methods for Session Skin Management

extension DeltaSkinManager {
    /// Set or clear the session skin for a specific game
    /// - Parameters:
    ///   - skinIdentifier: The skin identifier to use for the session, or nil to clear
    ///   - systemId: The system identifier
    ///   - gameId: The game identifier
    ///   - orientation: The current orientation
    public func setSessionSkin(_ skinIdentifier: String?, for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) {
        // Create a composite key combining system ID and game ID
        let compositeKey = "\(systemId.rawValue)_\(gameId)"

        queue.sync {
            if let skinIdentifier = skinIdentifier {
                // Initialize the dictionary for this composite key if needed
                if sessionSkins[compositeKey] == nil {
                    sessionSkins[compositeKey] = [:]
                }

                // Set the skin for this orientation
                sessionSkins[compositeKey]?[orientation.rawValue] = skinIdentifier

                print("Set session skin \(skinIdentifier) for game \(gameId) on system \(systemId.rawValue) in \(orientation.rawValue) orientation")
            } else {
                // Clear the skin for this orientation
                sessionSkins[compositeKey]?[orientation.rawValue] = nil

                // If both orientations are nil, remove the entry
                if sessionSkins[compositeKey]?.isEmpty ?? true {
                    sessionSkins.removeValue(forKey: compositeKey)
                }

                print("Cleared session skin for game \(gameId) on system \(systemId.rawValue) in \(orientation.rawValue) orientation")
            }
        }
    }

    /// Get the session skin identifier for a specific game
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - gameId: The game identifier
    ///   - orientation: The current orientation
    /// - Returns: The session skin identifier if set, otherwise nil
    public func sessionSkinIdentifier(for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) -> String? {
        // Create a composite key combining system ID and game ID
        let compositeKey = "\(systemId.rawValue)_\(gameId)"
        return sessionSkins[compositeKey]?[orientation.rawValue]
    }

    /// Get the effective skin identifier for a game, checking game-specific session skins first,
    /// then system session skins, then game preferences, and finally system preferences
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - gameId: The game identifier
    ///   - orientation: The current orientation
    /// - Returns: The effective skin identifier to use
    public func effectiveGameSkinIdentifier(for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) -> String? {
        // First check for game-specific session skin
        if let gameSessionSkin = sessionSkinIdentifier(for: systemId, gameId: gameId, orientation: orientation) {
            return gameSessionSkin
        }

        // Then check for system session skin
        if let systemSessionSkin = sessionSkinIdentifier(for: systemId, orientation: orientation) {
            return systemSessionSkin
        }

        // Then check game-specific preference
        return DeltaSkinPreferences.shared.effectiveSkinIdentifier(for: gameId, system: systemId, orientation: orientation)
    }
}
