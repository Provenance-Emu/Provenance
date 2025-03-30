import Foundation
import PVPrimitives
import Combine
import PVLogging

/// Structure to hold skin selection for different orientations
public struct OrientationSkinSelection: Codable {
    var portrait: String?
    var landscape: String?
    
    init(portrait: String? = nil, landscape: String? = nil) {
        self.portrait = portrait
        self.landscape = landscape
    }
}

/// Manages user preferences for Delta skins
public final class DeltaSkinPreferences: ObservableObject {
    /// Shared instance
    public static let shared = DeltaSkinPreferences()

    /// Currently selected skin identifier for each system and orientation
    @Published public private(set) var selectedSkins: [SystemIdentifier: OrientationSkinSelection] = [:]

    /// UserDefaults key for storing skin preferences
    private let preferencesKey = "com.provenance.deltaskin.preferences"

    private init() {
        loadPreferences()
    }

    /// Get the selected skin identifier for a system and orientation
    /// - Parameters:
    ///   - system: The system identifier
    ///   - orientation: The orientation (portrait or landscape)
    /// - Returns: The selected skin identifier, or nil if none selected
    public func selectedSkinIdentifier(for system: SystemIdentifier, orientation: DeltaSkinOrientation = .portrait) -> String? {
        guard let selection = selectedSkins[system] else {
            return nil
        }
        
        switch orientation {
        case .portrait:
            return selection.portrait
        case .landscape:
            // Fall back to portrait selection if no landscape-specific selection exists
            return selection.landscape ?? selection.portrait
        }
    }

    /// Set the selected skin for a system and orientation
    /// - Parameters:
    ///   - skinIdentifier: The skin identifier to select
    ///   - system: The system identifier
    ///   - orientation: The orientation (portrait or landscape)
    @MainActor
    public func setSelectedSkin(_ skinIdentifier: String?, for system: SystemIdentifier, orientation: DeltaSkinOrientation = .portrait) {
        // Get current selection or create a new one
        var selection = selectedSkins[system] ?? OrientationSkinSelection()
        
        // Update the appropriate orientation
        switch orientation {
        case .portrait:
            selection.portrait = skinIdentifier
        case .landscape:
            selection.landscape = skinIdentifier
        }
        
        // If both orientations are nil, remove the entry entirely
        if selection.portrait == nil && selection.landscape == nil {
            selectedSkins.removeValue(forKey: system)
        } else {
            selectedSkins[system] = selection
        }
        
        DLOG("Set skin for \(system.systemName) in \(orientation) mode to: \(skinIdentifier ?? "default")")
        savePreferences()
    }

    /// Load preferences from UserDefaults
    private func loadPreferences() {
        // Try to load new format first (with orientation support)
        if let data = UserDefaults.standard.data(forKey: preferencesKey + ".v2") {
            do {
                let preferences = try JSONDecoder().decode([String: OrientationSkinSelection].self, from: data)
                
                // Convert string keys to SystemIdentifier
                selectedSkins = preferences.compactMapKeys { key in
                    SystemIdentifier(rawValue: key)
                }
                return
            } catch {
                ELOG("Error loading skin preferences: \(error)")
            }
        }
        
        // Fall back to old format for backward compatibility
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let preferences = try? JSONDecoder().decode([String: String].self, from: data) {
            
            // Convert old format to new format (all selections are considered portrait)
            var newPreferences: [SystemIdentifier: OrientationSkinSelection] = [:]
            
            for (key, value) in preferences {
                if let system = SystemIdentifier(rawValue: key) {
                    newPreferences[system] = OrientationSkinSelection(portrait: value)
                }
            }
            
            selectedSkins = newPreferences
            
            // Save in new format for future use
            savePreferences()
        }
    }

    /// Save preferences to UserDefaults
    private func savePreferences() {
        // Convert SystemIdentifier keys to strings
        let stringDict = selectedSkins.compactMapKeys { $0.rawValue }

        if let data = try? JSONEncoder().encode(stringDict) {
            UserDefaults.standard.set(data, forKey: preferencesKey)
        }
    }
}

// Helper extension for dictionary transformations
extension Dictionary {
    func compactMapKeys<T>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let transformedKey = transform(key) {
                result[transformedKey] = value
            }
        }
        return result
    }
}
