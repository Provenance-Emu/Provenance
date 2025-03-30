import Foundation
import ZIPFoundation
import PVLogging

/// Manages loading and caching of DeltaSkins
public final class DeltaSkinManager: ObservableObject, DeltaSkinManagerProtocol {
    /// Singleton instance
    public static let shared = DeltaSkinManager()

    /// Currently loaded skins
    @Published public private(set) var loadedSkins: [DeltaSkinProtocol] = []

    /// Queue for synchronizing skin operations
    private let queue = DispatchQueue(label: "com.provenance.deltaskin-manager")

    public init() {
        print("Initializing DeltaSkinManager")
        Task.detached { [weak self] in
            try? self?.scanForSkins()
        }
    }

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
    
    /// Get skins for a specific game type, filtered by device and orientation
    /// - Parameters:
    ///   - gameType: The game type to filter by
    ///   - device: The device to filter by (iPhone or iPad)
    ///   - orientation: The orientation to filter by (portrait or landscape)
    /// - Returns: Array of skins that match the criteria
    public func skins(for system: SystemIdentifier, device: DeltaSkinDevice, orientation: DeltaSkinOrientation? = nil) async throws -> [DeltaSkinProtocol] {
        try await queue.asyncResult {
            try self.scanForSkins()
            
            // First get all skins for this game type (using case-insensitive matching)
            let gameSkins = self.loadedSkins.filter { 
                $0.gameType.systemIdentifier == system
            }
            DLOG("Found \(gameSkins.count) total skins for \(system.rawValue) (case-insensitive matching)")
            
            // Log the first few skins' details to help diagnose issues
            for (index, skin) in gameSkins.prefix(3).enumerated() {
                DLOG("Skin \(index+1): \(skin.name), ID: \(skin.identifier), Game Type: \(skin.gameType.rawValue)")
                if let jsonRep = skin.jsonRepresentation["representations"] as? [String: Any] {
                    DLOG("  Available representations for \(skin.name):")
                    for (deviceKey, deviceValue) in jsonRep {
                        DLOG("  - Device: \(deviceKey)")
                        if let deviceRep = deviceValue as? [String: Any] {
                            for (displayKey, displayValue) in deviceRep {
                                DLOG("    - Display: \(displayKey)")
                                if let displayRep = displayValue as? [String: Any] {
                                    DLOG("      - Orientations: \(displayRep.keys.joined(separator: ", "))")
                                }
                            }
                        }
                    }
                }
            }
            
            // Filter skins based on device and optional orientation
            let deviceSkins = gameSkins.filter { skin in
                // Use the protocol extension method that handles all the matching logic
                let supported = skin.supports(device, orientation: orientation)
                
                if supported {
                    if let orientation = orientation {
                        DLOG("✅ Skin '\(skin.name)' supports \(device) in \(orientation) mode")
                    } else {
                        DLOG("✅ Skin '\(skin.name)' supports \(device)")
                    }
                } else {
                    if let orientation = orientation {
                        DLOG("❌ Skin '\(skin.name)' does not support \(device) in \(orientation) mode")
                    } else {
                        DLOG("❌ Skin '\(skin.name)' does not support \(device)")
                    }
                }
                
                return supported
            }
            DLOG("Found \(deviceSkins.count) skins for \(device) (any orientation)")
            return deviceSkins

        }
    }
    
    /// Get the appropriate skin to use for a system based on current device and orientation
    /// - Parameters:
    ///   - system: The system identifier
    ///   - device: The device type (defaults to current device)
    ///   - orientation: The orientation (defaults to current orientation)
    /// - Returns: The skin to use, or nil if none is available
    public func skinToUse(for system: SystemIdentifier, 
                          device: DeltaSkinDevice? = nil,
                          orientation: DeltaSkinOrientation? = nil) async throws -> DeltaSkinProtocol? {
        // Determine current device and orientation if not specified
        let currentDevice = device ?? (UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone)
        let currentOrientation = orientation ?? (UIDevice.current.orientation.isLandscape ? .landscape : .portrait)
        
        // Get the selected skin identifier for the current orientation
        let selectedSkinId = DeltaSkinPreferences.shared.selectedSkinIdentifier(for: system, orientation: currentOrientation)
        
        // If a skin is selected, try to find it
        if let selectedSkinId = selectedSkinId {
            DLOG("Looking for selected skin \(selectedSkinId) for \(system.systemName) in \(currentOrientation) mode")
            
            // Get all skins for this system
            let allSkins = try await skins(for: system)
            
            // Find the selected skin
            if let selectedSkin = allSkins.first(where: { $0.identifier == selectedSkinId }) {
                // Check if the skin supports the current device and orientation
                let traits = DeltaSkinTraits(
                    device: currentDevice,
                    displayType: .standard,
                    orientation: currentOrientation
                )
                
                if selectedSkin.supports(traits) {
                    DLOG("Using selected skin: \(selectedSkin.name)")
                    return selectedSkin
                } else {
                    WLOG("Selected skin \(selectedSkin.name) doesn't support \(currentDevice) in \(currentOrientation) mode")
                }
            } else {
                WLOG("Selected skin with ID \(selectedSkinId) not found")
            }
        }
        
        // If no skin is selected or the selected skin doesn't support the current device/orientation,
        // find a compatible skin
        DLOG("Finding compatible skin for \(system.systemName) on \(currentDevice) in \(currentOrientation) mode")
        
        // First try to get skins specifically for this orientation
        let compatibleSkins = try await skins(for: system, device: currentDevice, orientation: currentOrientation)
        
        if let firstCompatibleSkin = compatibleSkins.first {
            DLOG("Using compatible skin: \(firstCompatibleSkin.name)")
            return firstCompatibleSkin
        }
        
        // If no compatible skin is found for the current orientation, try any skin for this device
        WLOG("No skin found for \(currentOrientation) mode, trying any skin for \(currentDevice)")
        let deviceSkins = try await skins(for: system, device: currentDevice)
        
        if let firstDeviceSkin = deviceSkins.first {
            DLOG("Using device skin: \(firstDeviceSkin.name)")
            return firstDeviceSkin
        }
        
        // If still no skin is found, try the opposite orientation
        let oppositeOrientation: DeltaSkinOrientation = currentOrientation == .portrait ? .landscape : .portrait
        let oppositeOrientationSkins = try await skins(for: system, device: currentDevice, orientation: oppositeOrientation)
        
        if let firstOppositeOrientationSkin = oppositeOrientationSkins.first {
            WLOG("No skin found for \(currentDevice), using \(oppositeOrientation) skin: \(firstOppositeOrientationSkin.name)")
            return firstOppositeOrientationSkin
        }
        
        // If still no skin is found, return nil
        WLOG("No compatible skin found for \(system.systemName) on \(currentDevice)")
        return nil
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
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
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
