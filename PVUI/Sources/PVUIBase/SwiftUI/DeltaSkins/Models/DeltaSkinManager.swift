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

    /// Flag to track if skins have been scanned at least once
    private var hasScanned: Bool = false

    /// Check if skins have been scanned and are available in memory
    public var skinsAreLoaded: Bool {
        hasScanned
    }

    /// The most recent scan results, accessible from the background queue
    /// without waiting for MainActor.  `loadedSkins` is @Published and can
    /// only be safely written on MainActor, but callers on the background
    /// queue need immediate access to the scan results.
    private var lastScannedSkins: [DeltaSkinProtocol] = []

    /// Flag to track if scan is currently in progress (prevents concurrent scans)
    private var isScanning: Bool = false

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
        // Scan is intentionally deferred — Bundle.allFrameworks enumeration and
        // .deltaskin discovery are I/O-heavy and compete with the core-plist scanner
        // during app boot.  availableSkins() triggers the scan lazily on first use.
        ILOG("skins: Initializing DeltaSkinManager (scan deferred to first use)")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Get all available skins (protocol conformance)
    public func availableSkins() async throws -> [any DeltaSkinProtocol] {
        ILOG("skins: availableSkins() called - fetching skins")
        let skins = try await availableSkins(forceRescan: false)
        ILOG("skins: availableSkins() returning \(skins.count) skins")
        return skins
    }

    /// Get all available skins
    /// - Parameter forceRescan: If true, forces a rescan even if skins are already loaded. Defaults to false.
    public func availableSkins(forceRescan: Bool = false) async throws -> [DeltaSkinProtocol] {
        ILOG("skins: availableSkins(forceRescan: \(forceRescan)) called - hasScanned: \(self.hasScanned)")
        let skins = try await queue.asyncResult {
            // Only scan if we haven't scanned yet, or if forceRescan is true
            if !self.hasScanned || forceRescan {
                ILOG("skins: Scanning for skins (hasScanned: \(self.hasScanned), forceRescan: \(forceRescan))")
                try self.scanForSkins()
            } else {
                ILOG("skins: Using cached skins, skipping scan")
            }
            // Return lastScannedSkins which is set synchronously on this queue,
            // rather than loadedSkins which is @Published and updated on MainActor
            // asynchronously (could still be empty when we read it here).
            ILOG("skins: Returning \(self.lastScannedSkins.count) scanned skins")
            return self.lastScannedSkins
        }
        ILOG("skins: availableSkins() completed with \(skins.count) skins")
        return skins
    }

    /// Get a skin by its identifier
    /// - Parameter identifier: The unique identifier of the skin
    /// - Returns: The skin if found, or nil if not found
    public func skin(withIdentifier identifier: String) async throws -> DeltaSkinProtocol? {
        ILOG("skins: skin(withIdentifier: \(identifier)) called")
        let result: DeltaSkinProtocol? = try await queue.asyncResult {
            // Find the skin with the matching identifier (use lastScannedSkins for
            // immediate access; loadedSkins is updated on MainActor asynchronously)
            if let skin = self.lastScannedSkins.first(where: { $0.identifier == identifier }) {
                ILOG("skins: Found skin '\(skin.name)' with identifier '\(identifier)' in cache")
                return skin as DeltaSkinProtocol?
            } else {
                ILOG("skins: Skin '\(identifier)' not found in cache, scanning for skins")
                // Ensure skins are loaded
                try self.scanForSkins()
                if let skin = self.lastScannedSkins.first(where: { $0.identifier == identifier }) {
                    ILOG("skins: Found skin '\(skin.name)' with identifier '\(identifier)' after scan")
                    return skin as DeltaSkinProtocol?
                } else {
                    WLOG("skins: Skin with identifier '\(identifier)' not found after scan")
                    return nil
                }
            }
        }
        if let skin = result {
            ILOG("skins: Returning skin '\(skin.name)' for identifier '\(identifier)'")
        } else {
            WLOG("skins: No skin found for identifier '\(identifier)'")
        }
        return result
    }

    /// Get the currently selected skin for a system in the current session
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - orientation: The current orientation
    /// - Returns: The session skin identifier if set, otherwise nil
    /// - Note: Delegates to centralized DeltaSkinSelectionManager
    public func sessionSkinIdentifier(for systemId: SystemIdentifier, orientation: SkinOrientation) -> String? {
        // Synchronous access to centralized manager (it uses internal queue for thread safety)
        return DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
            for: systemId,
            gameId: nil,
            orientation: orientation
        )
    }

    /// Set the session skin for a system
    /// - Parameters:
    ///   - skinIdentifier: The skin identifier to use for the session, or nil to clear
    ///   - systemId: The system identifier
    ///   - orientation: The current orientation
    /// - Note: Delegates to centralized DeltaSkinSelectionManager
    public func setSessionSkin(_ skinIdentifier: String?, for systemId: SystemIdentifier, orientation: SkinOrientation) {
        Task { @MainActor in
            DeltaSkinSelectionManager.shared.setSkin(
                skinIdentifier,
                for: systemId,
                gameId: nil,
                orientation: orientation,
                scope: .session
            )
        }
    }

    /// Get the selected skin for a system, checking session skins first, then preferences
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - gameId: The game identifier (optional)
    ///   - orientation: The current orientation
    /// - Returns: The effective skin identifier to use
    /// - Note: Delegates to centralized DeltaSkinSelectionManager
    public func effectiveSkinIdentifier(for systemId: SystemIdentifier, gameId: String? = nil, orientation: SkinOrientation) -> String? {
        return DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
            for: systemId,
            gameId: gameId,
            orientation: orientation
        )
    }


    /// Load a skin from a file URL
    public func loadSkin(from url: URL) async throws -> DeltaSkinProtocol {
        try await queue.asyncResult {
            try self.loadSkinFromURL(url)
        }
    }

    /// Scan for available skins
    private func scanForSkins() throws {
        // Prevent concurrent scans
        guard !isScanning else {
            WLOG("skins: Scan already in progress, skipping")
            return
        }

        isScanning = true
        defer { isScanning = false }

        ILOG("skins: Starting skin scan...")
        let locations = skinLocations()
        ILOG("skins: Found \(locations.count) locations to scan")

        // Use Set for O(1) lookup instead of O(n) contains check
        var scannedSkinIdentifiers = Set<String>()
        var scannedSkins: [DeltaSkinProtocol] = []

        for location in locations {
            ILOG("skins: Examining location: \(location.path)")

            do {
                let isDirectory = (try? location.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                ILOG("skins: Location '\(location.lastPathComponent)' is directory: \(isDirectory)")

                // Handle both directory formats:
                // 1. A .deltaskin directory
                // 2. A directory containing .deltaskin files/directories
                if isDirectory {
                    if location.lastPathComponent.hasSuffix(".deltaskin") || location.lastPathComponent.hasSuffix(".manicskin") {
                        // This is a .deltaskin directory, load it directly
                        ILOG("skins: Found skin directory: \(location.lastPathComponent)")
                        if let skin = try? loadSkinFromURLWithoutAdding(location) {
                            if !scannedSkinIdentifiers.contains(skin.identifier) {
                                scannedSkinIdentifiers.insert(skin.identifier)
                                scannedSkins.append(skin)
                                ILOG("skins: Loaded skin '\(skin.name)' (identifier: \(skin.identifier))")
                            } else {
                                ILOG("skins: Skipping duplicate skin '\(skin.name)' (identifier: \(skin.identifier))")
                            }
                        } else {
                            WLOG("skins: Failed to load skin from directory: \(location.lastPathComponent)")
                        }
                    } else {
                        // This is a directory that might contain skins, scan it
                        let contents = try FileManager.default.contentsOfDirectory(
                            at: location,
                            includingPropertiesForKeys: [.isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        )

                        for url in contents where (url.lastPathComponent.hasSuffix(".deltaskin") || url.lastPathComponent.hasSuffix(".manicskin")) {
                            ILOG("skins: Found skin file in directory: \(url.lastPathComponent)")
                            if let skin = try? loadSkinFromURLWithoutAdding(url) {
                                if !scannedSkinIdentifiers.contains(skin.identifier) {
                                    scannedSkinIdentifiers.insert(skin.identifier)
                                    scannedSkins.append(skin)
                                    ILOG("skins: Loaded skin '\(skin.name)' (identifier: \(skin.identifier))")
                                } else {
                                    ILOG("skins: Skipping duplicate skin '\(skin.name)' (identifier: \(skin.identifier))")
                                }
                            } else {
                                WLOG("skins: Failed to load skin from file: \(url.lastPathComponent)")
                            }
                        }
                    }
                } else if location.pathExtension == "deltaskin" || location.pathExtension == "manicskin" {
                    // This is a .deltaskin or .manicskin file (archive)
                    ILOG("skins: Found skin archive file: \(location.lastPathComponent)")
                    if let skin = try? loadSkinFromURLWithoutAdding(location) {
                        if !scannedSkinIdentifiers.contains(skin.identifier) {
                            scannedSkinIdentifiers.insert(skin.identifier)
                            scannedSkins.append(skin)
                            ILOG("skins: Loaded skin '\(skin.name)' from archive (identifier: \(skin.identifier))")
                        } else {
                            ILOG("skins: Skipping duplicate skin '\(skin.name)' from archive (identifier: \(skin.identifier))")
                        }
                    } else {
                        WLOG("skins: Failed to load skin from archive: \(location.lastPathComponent)")
                    }
                }
            } catch {
                ELOG("skins: Error scanning location \(location.path): \(error)")
                // Continue scanning other locations
                continue
            }
        }

        // Log results
        ILOG("skins: Scan complete. Found \(scannedSkins.count) total skins. Available skins by type:")
        let groupedSkins = Dictionary(grouping: scannedSkins) { skin in
            // Prefer Delta-style identifier for logging; fallback to Manic; else case name
            skin.gameType.deltaIdentifierString ?? skin.gameType.manicIdentifierString ?? String(describing: skin.gameType)
        }
        for (type, skins) in groupedSkins.sorted(by: { $0.key < $1.key }) {
            ILOG("skins: - \(type): \(skins.count) skins")
            for skin in skins {
                ILOG("skins:   • \(skin.name) (id: \(skin.identifier))")
            }
        }

        // Store scanned results so queue-based callers can read them
        // immediately via lastScannedSkins (loadedSkins is @Published and
        // must be set on MainActor for SwiftUI).
        lastScannedSkins = scannedSkins
        hasScanned = true
        ILOG("skins: Scan complete, hasScanned set to true")

        // Batch update the @Published loadedSkins on the main thread for SwiftUI
        Task { @MainActor in
            ILOG("skins: Updating loadedSkins with \(scannedSkins.count) skins on main thread")
            self.loadedSkins = scannedSkins
            ILOG("skins: loadedSkins updated on main thread")
        }
    }

    /// Load a skin from URL without adding to loadedSkins (for use during scan)
    private func loadSkinFromURLWithoutAdding(_ url: URL) throws -> DeltaSkinProtocol {
        ILOG("skins: Loading skin from: \(url.lastPathComponent)")

        do {
            let skin = try DeltaSkin(fileURL: url)
            let typeLabel = skin.gameType.deltaIdentifierString ?? skin.gameType.manicIdentifierString ?? String(describing: skin.gameType)
            ILOG("skins: Successfully loaded skin '\(skin.name)' (type: \(typeLabel), identifier: \(skin.identifier))")
            return skin
        } catch {
            ELOG("skins: Failed to load skin from \(url.lastPathComponent): \(error)")
            if let deltaSkinError = error as? DeltaSkinError {
                ELOG("skins: DeltaSkin Error: \(deltaSkinError)")
            }
            throw error
        }
    }

    /// Load a skin from URL and add to loadedSkins (for manual loading)
    private func loadSkinFromURL(_ url: URL) throws -> DeltaSkinProtocol {
        let skin = try loadSkinFromURLWithoutAdding(url)
        // Update lastScannedSkins synchronously so callers see it immediately
        if !lastScannedSkins.contains(where: { $0.identifier == skin.identifier }) {
            lastScannedSkins.append(skin)
        }
        // Update @Published loadedSkins on MainActor for SwiftUI
        Task { @MainActor in
            if !self.loadedSkins.contains(where: { $0.identifier == skin.identifier }) {
                self.loadedSkins.append(skin)
            }
        }
        return skin
    }

    /// Get locations of skin files
    private func skinLocations() -> [URL] {
        var locations: [URL] = []

        // Add bundle skins from all bundles
        let deltaSkins = Bundle.main.urls(forResourcesWithExtension: "deltaskin", subdirectory: nil) ?? []
        let manicSkins = Bundle.main.urls(forResourcesWithExtension: "manicskin", subdirectory: nil) ?? []
        let bundleSkins = deltaSkins + manicSkins

        if !bundleSkins.isEmpty {
            ILOG("skins: Found \(bundleSkins.count) bundle skins: \(bundleSkins.map { $0.lastPathComponent }.joined(separator: ", "))")
            locations.append(contentsOf: bundleSkins)
        } else {
            WLOG("skins: No skins found in any bundles")
        }

        // Add framework bundle skins
        let frameworkSkins = Bundle.allFrameworks.flatMap { bundle in
            let deltaSkins = bundle.urls(forResourcesWithExtension: "deltaskin", subdirectory: nil) ?? []
            let manicSkins = bundle.urls(forResourcesWithExtension: "manicskin", subdirectory: nil) ?? []
            return deltaSkins + manicSkins
        }
        if !frameworkSkins.isEmpty {
            ILOG("skins: Found \(frameworkSkins.count) framework skins: \(frameworkSkins.map { $0.lastPathComponent }.joined(separator: ", "))")
            locations.append(contentsOf: frameworkSkins)
        }

        // Add Documents directory skins (use URL.documentsPath for tvOS caches mapping)
        let documentsURL = URL.documentsPath
        let skinsURL = documentsURL.appendingPathComponent("DeltaSkins", isDirectory: true)
        ILOG("skins: Adding Documents directory for skins: \(skinsURL.path)")
        locations.append(skinsURL)

        ILOG("skins: Total locations to scan: \(locations.count)")
        return locations
    }

    /// Directory for storing imported skins
    public var skinsDirectory: URL {
        get throws {
            let documentsURL = URL.documentsPath
            let skinsURL = documentsURL.appendingPathComponent("DeltaSkins", isDirectory: true)

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
        ILOG("skins: reloadSkins() called")
        do {
            try await queue.asyncResult {
                // Force rescan
                ILOG("skins: Forcing rescan of skins")
                self.hasScanned = false
                try self.scanForSkins()
            }
            // Trigger objectWillChange after scan completes
            self.objectWillChange.send()
            ILOG("skins: reloadSkins() completed successfully")
        } catch {
            ELOG("skins: Failed to reload skins: \(error)")
        }
    }

    /// Import a skin from a URL, handling spaces in paths
    public func importSkin(from url: URL) async throws {
        ILOG("skins: Starting skin import from: \(url.path)")

        return try await queue.asyncResult { [self] in
            // Get destination in Documents directory
            let skinsDir = try self.skinsDirectory
            let destinationURL = skinsDir.appendingPathComponent(url.lastPathComponent)
            ILOG("skins: Import destination: \(destinationURL.path)")

            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                ILOG("skins: Removing existing skin at: \(destinationURL.path)")
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Copy to skins directory
            ILOG("skins: Copying skin to: \(destinationURL.path)")
            try FileManager.default.copyItem(at: url, to: destinationURL)
            ILOG("skins: Skin import completed successfully")

            // Scan to reload all skins
            try self.scanForSkins()
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
            // Find the skin (use lastScannedSkins for immediate access on this queue)
            guard let skin = self.lastScannedSkins.first(where: { $0.identifier == identifier }) else {
                throw DeltaSkinError.notFound
            }

            // Verify it's deletable
            guard self.isDeletable(skin) else {
                throw DeltaSkinError.deletionNotAllowed
            }

            // Delete the file
            DLOG("Deleting skin at: \(skin.fileURL.path)")
            try FileManager.default.removeItem(at: skin.fileURL)

            // Synchronously remove from lastScannedSkins on this queue so subsequent
            // availableSkins()/skin(withIdentifier:) calls see the deletion immediately,
            // before the full rescan below has completed.
            self.lastScannedSkins.removeAll { $0.identifier == identifier }

            // Rescan on this queue (not on MainActor) so all mutations to
            // lastScannedSkins/hasScanned remain queue-confined and race-free.
            // scanForSkins() dispatches the MainActor loadedSkins update internally.
            self.hasScanned = false
            try self.scanForSkins()
        }
    }
}

// MARK: - Skin Preview Image Caching
extension DeltaSkinManager {
    /// Generate a cache key for a skin preview image
    private func previewCacheKey(for skin: DeltaSkinProtocol, device: DeltaSkinDevice? = nil) -> String {
        var key = DeltaSkinManager.skinPreviewCacheKeyPrefix + skin.identifier
        if let device = device {
            key += "_\(device.rawValue)"
        }
        return key
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

    /// Get a preview image for a skin with specific device type, using cache if available
    /// - Parameters:
    ///   - skin: The skin to get a preview for
    ///   - device: The device type to render the preview for
    /// - Returns: A preview image if available, nil otherwise
    public func previewImage(for skin: DeltaSkinProtocol, device: DeltaSkinDevice) async -> UIImage? {
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

    /// Generate and cache a preview image for a skin with specific device type
    /// - Parameters:
    ///   - skin: The skin to generate a preview for
    ///   - device: The device type to render the preview for
    /// - Returns: The generated preview image, or nil if generation failed
    private func generateAndCachePreview(for skin: DeltaSkinProtocol, device: DeltaSkinDevice) async -> UIImage? {
        DLOG("Generating preview for skin: \(skin.name) on device: \(device.rawValue)")

        // Try device-specific traits first (portrait, then landscape)
        let deviceTraits: [DeltaSkinTraits] = [
            DeltaSkinTraits(device: device, displayType: .standard, orientation: .portrait),
            DeltaSkinTraits(device: device, displayType: .edgeToEdge, orientation: .portrait),
            DeltaSkinTraits(device: device, displayType: .standard, orientation: .landscape),
            DeltaSkinTraits(device: device, displayType: .edgeToEdge, orientation: .landscape)
        ]

        for traits in deviceTraits {
            if skin.supports(traits) {
                return await generatePreview(for: skin, with: traits, device: device)
            }
        }

        DLOG("No supported traits found for skin: \(skin.name) on device: \(device.rawValue)")
        return nil
    }

    /// Generate a preview image for a skin with specific traits and cache it
    /// - Parameters:
    ///   - skin: The skin to generate a preview for
    ///   - traits: The traits to use for the preview
    /// - Returns: The generated preview image, or nil if generation failed
    private func generatePreview(for skin: DeltaSkinProtocol, with traits: DeltaSkinTraits) async -> UIImage? {
        return await generatePreview(for: skin, with: traits, device: nil)
    }

    /// Generate a preview image for a skin with specific traits and cache it
    /// - Parameters:
    ///   - skin: The skin to generate a preview for
    ///   - traits: The traits to use for the preview
    ///   - device: Optional device type for cache key differentiation
    /// - Returns: The generated preview image, or nil if generation failed
    private func generatePreview(for skin: DeltaSkinProtocol, with traits: DeltaSkinTraits, device: DeltaSkinDevice?) async -> UIImage? {
        do {
            // Get the skin image for the specified traits
            let skinImage = try await skin.image(for: traits)

            // Create a smaller preview image for the cache
            let previewImage = skinImage.scaledImage(withMaxResolution: 300) ?? skinImage

            // Cache the preview image with device-specific key if provided
            let cacheKey = previewCacheKey(for: skin, device: device)
            try PVMediaCache.writeImage(toDisk: previewImage, withKey: cacheKey)

            DLOG("Generated and cached preview for skin: \(skin.name)\(device != nil ? " on device: \(device!.rawValue)" : "")")
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

    /// Invalidate cached preview for a skin with specific device type
    /// - Parameters:
    ///   - skin: The skin to invalidate the preview for
    ///   - device: The device type to invalidate the preview for
    public func invalidatePreview(for skin: DeltaSkinProtocol, device: DeltaSkinDevice) {
        let cacheKey = previewCacheKey(for: skin, device: device)
        Task {
            try? PVMediaCache.deleteImage(forKey: cacheKey)
            DLOG("Invalidated preview cache for skin: \(skin.name) on device: \(device.rawValue)")
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
    /// UTType for .deltaskin files. Prefers our exported `com.provenance.deltaskin` (which owns
    /// the .deltaskin extension) so that file pickers accept files the system resolves to our UTI.
    /// Falls back to the imported `com.rileytestut.delta.skin` for interop when Delta is installed.
    static var deltaSkin: UTType {
        UTType("com.provenance.deltaskin") ?? UTType(importedAs: "com.rileytestut.delta.skin")
    }

    /// UTType for the Delta app's native skin identifier, used when interop with Delta is needed.
    static var deltaAppSkin: UTType {
        UTType(importedAs: "com.rileytestut.delta.skin")
    }

    static var manicSkin: UTType {
        // Try to use the imported type from plist first, fallback to dynamic type
        if let importedType = UTType("com.provenance.manicskin") {
            return importedType
        }
        return UTType(filenameExtension: "manicskin", conformingTo: .archive)!
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
    /// - Note: Delegates to centralized DeltaSkinSelectionManager
    public func setSessionSkin(_ skinIdentifier: String?, for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) {
        Task { @MainActor in
            DeltaSkinSelectionManager.shared.setSkin(
                skinIdentifier,
                for: systemId,
                gameId: gameId,
                orientation: orientation,
                scope: .session
            )
        }
    }

    /// Get the session skin identifier for a specific game
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - gameId: The game identifier
    ///   - orientation: The current orientation
    /// - Returns: The session skin identifier if set, otherwise nil
    /// - Note: Delegates to centralized DeltaSkinSelectionManager
    public func sessionSkinIdentifier(for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) -> String? {
        return DeltaSkinSelectionManager.shared.effectiveGameSkinIdentifier(
            for: systemId,
            gameId: gameId,
            orientation: orientation
        )
    }

    /// Get the effective skin identifier for a game, checking game-specific session skins first,
    /// then system session skins, then game preferences, and finally system preferences
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - gameId: The game identifier
    ///   - orientation: The current orientation
    /// - Returns: The effective skin identifier to use
    /// - Note: Delegates to centralized DeltaSkinSelectionManager
    public func effectiveGameSkinIdentifier(for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) -> String? {
        return DeltaSkinSelectionManager.shared.effectiveGameSkinIdentifier(
            for: systemId,
            gameId: gameId,
            orientation: orientation
        )
    }
}
