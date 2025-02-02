import Foundation
import ZIPFoundation
import PVLogging

/// Manages loading and caching of DeltaSkins
public final class DeltaSkinManager: ObservableObject, DeltaSkinManagerProtocol {
    /// Singleton instance
    public static let shared = DeltaSkinManager()

    /// Currently loaded skins
    private var loadedSkins: [DeltaSkinProtocol] = []

    /// Queue for synchronizing skin operations
    private let queue = DispatchQueue(label: "com.provenance.deltaskin-manager")

    private init() {}

    /// Get all available skins
    public func availableSkins() async throws -> [DeltaSkinProtocol] {
        try await queue.asyncResult {
            try self.scanForSkins()
            return self.loadedSkins
        }
    }

    /// Load a skin from a file URL
    public func loadSkin(from url: URL) async throws -> DeltaSkinProtocol {
        try await queue.asyncResult {
            try self.loadSkinFromURL(url)
        }
    }

    /// Get skins for a specific game type
    public func skins(for gameType: String) async throws -> [DeltaSkinProtocol] {
        try await queue.asyncResult {
            try self.scanForSkins()
            return self.loadedSkins.filter { $0.gameType.rawValue == gameType }
        }
    }

    /// Scan for available skins
    private func scanForSkins() throws {
        DLOG("Starting skin scan...")

        // Clear existing skins
        loadedSkins.removeAll()

        // Get skin locations
        let locations = skinLocations()
        DLOG("Total locations to scan: \(locations.count)")

        // Scan each location
        for location in locations {
            DLOG("Examining location: \(location.path)")

            do {
                let isDirectory = (try? location.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                DLOG("Is directory: \(isDirectory)")

                // Handle both directory and archive formats
                if location.pathExtension == "deltaskin" || (isDirectory && location.lastPathComponent.hasSuffix(".deltaskin")) {
                    try loadSkinFromURL(location)
                }
            } catch {
                ELOG("Error loading skin at \(location.path): \(error)")
                // Continue loading other skins even if one fails
                continue
            }
        }

        // Log results
        DLOG("Scan complete. Available skins by type:")
        let skinsByType = Dictionary(grouping: loadedSkins) { $0.gameType }
        for (type, skins) in skinsByType {
            DLOG("- \(type.rawValue): \(skins.count) skins")
            for skin in skins {
                DLOG("  • \(skin.fileURL.lastPathComponent)")
            }
        }
    }

    /// Load a skin from URL and add to loadedSkins
    private func loadSkinFromURL(_ url: URL) throws -> DeltaSkinProtocol {
        DLOG("Loading skin from: \(url.lastPathComponent)")

        do {
            let skin = try DeltaSkin(fileURL: url)
            ILOG("Successfully loaded skin: \(skin.name) (type: \(skin.gameType.rawValue))")

            DLOG("Current loaded skins count: \(loadedSkins.count)")
            loadedSkins.append(skin)
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

        // Add bundle skins
        if let bundleSkins = Bundle.main.urls(forResourcesWithExtension: "deltaskin", subdirectory: nil) {
            DLOG("Found bundle skins: \(bundleSkins.map { $0.lastPathComponent })")
            locations.append(contentsOf: bundleSkins)
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

    /// Import a skin file into the app's storage
    public func importSkin(from sourceURL: URL) async throws {
        ILOG("Importing skin from: \(sourceURL.lastPathComponent)")
        try await queue.asyncResult {
            let skinsDir = try self.skinsDirectory
            let destinationURL = skinsDir.appendingPathComponent(sourceURL.lastPathComponent)

            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                ILOG("Removing existing file at: \(destinationURL.path)")
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Copy the file
            ILOG("Copying file from: \(sourceURL.path) to: \(destinationURL.path)")
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            ILOG("File copied successfully")

            // Load the skin to verify it
            ILOG("Loading skin from: \(destinationURL.path)")
            _ = try self.loadSkinFromURL(destinationURL)
            ILOG("Skin loaded successfully")
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
extension UTType {
    static var deltaSkin: UTType {
        UTType(exportedAs: "com.rileytestut.delta.skin")  // Delta's official UTType
    }
}
