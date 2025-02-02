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
        let locations = skinLocations()
        DLOG("Total locations to scan: \(locations.count)")

        // Create a new array to hold all skins
        var scannedSkins: [DeltaSkinProtocol] = []

        // Keep track of existing skin identifiers
        let existingIdentifiers = Set(loadedSkins.map { $0.identifier })

        for location in locations {
            DLOG("Examining location: \(location.path)")
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: location.path, isDirectory: &isDirectory) else { continue }
            DLOG("Is directory: \(isDirectory.boolValue)")

            if isDirectory.boolValue {
                // Scan directory for .deltaskin files
                if let contents = try? FileManager.default.contentsOfDirectory(
                    at: location,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ).filter({ $0.pathExtension == "deltaskin" }) {
                    for url in contents {
                        if let skin = try? loadSkinFromURL(url) {
                            // Only add if not already in scannedSkins
                            if !scannedSkins.contains(where: { $0.identifier == skin.identifier }) {
                                scannedSkins.append(skin)
                            }
                        }
                    }
                }
            } else if location.pathExtension == "deltaskin" {
                if let skin = try? loadSkinFromURL(location) {
                    // Only add if not already in scannedSkins
                    if !scannedSkins.contains(where: { $0.identifier == skin.identifier }) {
                        scannedSkins.append(skin)
                    }
                }
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

        // Update loadedSkins, preserving existing skins
        loadedSkins = scannedSkins
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

    /// Import a skin from a URL, handling spaces in paths
    public func importSkin(from url: URL) async throws -> DeltaSkinProtocol {
        DLOG("Starting skin import from: \(url.path)")

        return try await queue.asyncResult { [self] in
            // Get destination in Documents directory
            let skinsDir = try self.skinsDirectory
            let destinationURL = skinsDir.appendingPathComponent(url.lastPathComponent)

            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                DLOG("Removing existing skin at: \(destinationURL.path)")
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Copy to skins directory
            DLOG("Copying skin to: \(destinationURL.path)")
            try FileManager.default.copyItem(at: url, to: destinationURL)

            // Scan to reload all skins
            try self.scanForSkins()

            // Return the imported skin
            guard let skin = self.loadedSkins.first(where: { $0.fileURL == destinationURL }) else {
                throw DeltaSkinError.invalidArchive
            }

            return skin
        }
    }

    /// Check if a skin can be deleted (i.e., it's in the skins directory and not bundled)
    public func isDeletable(_ skin: DeltaSkinProtocol) -> Bool {
        guard let skinsDir = try? skinsDirectory else { return false }
        return skin.fileURL.path.starts(with: skinsDir.path)
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

            // Rescan skins
            try self.scanForSkins()
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
