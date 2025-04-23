import Foundation
import PVPrimitives
import Combine
import SwiftUI

/// Orientation for skin selection
public enum SkinOrientation: String, Codable, CaseIterable, Equatable, Hashable, Identifiable {
    case portrait
    case landscape
    
    public var id: String {
        rawValue
    }
    
    public static var allCases: [SkinOrientation] {
        [.portrait, .landscape]
    }
    
    public var displayName: String {
        switch self {
        case .portrait: return "Portrait"
        case .landscape: return "Landscape"
        }
    }
    
    public var icon: String {
        switch self {
        case .portrait: return "iphone"
        case .landscape: return "iphone.landscape"
        }
    }
    
    public var deltaSkinOrientation: DeltaSkinOrientation {
        switch self {
        case .portrait: return .portrait
        case .landscape: return .landscape
        }
    }
}

/// Manages user preferences for Delta skins
public final class DeltaSkinPreferences: ObservableObject {
    /// Shared instance
    public static let shared = DeltaSkinPreferences()
    
    /// Currently selected skin identifier for each system and orientation
    @Published public private(set) var selectedSkins: [SystemIdentifier: [SkinOrientation: String]] = [:]
    
    /// Currently selected skin identifier for specific games
    @Published public private(set) var gameSpecificSkins: [String: [SkinOrientation: String]] = [:]
    
    /// UserDefaults key for storing skin preferences
    private let preferencesKey = "com.provenance.deltaskin.preferences.v2"
    
    /// UserDefaults key for storing game-specific skin preferences
    private let gamePreferencesKey = "com.provenance.deltaskin.game.preferences.v1"

    private init() {
        loadPreferences()
    }

    /// Get the selected skin identifier for a system and orientation
    /// - Parameters:
    ///   - system: The system identifier
    ///   - orientation: The orientation (portrait or landscape)
    /// - Returns: The selected skin identifier, or nil if none selected
    public func selectedSkinIdentifier(for system: SystemIdentifier, orientation: SkinOrientation = .portrait) -> String? {
        return selectedSkins[system]?[orientation]
    }
    
    /// Get the selected skin identifier for a specific game
    /// - Parameters:
    ///   - gameId: The game's unique identifier
    ///   - orientation: The orientation (portrait or landscape)
    /// - Returns: The selected skin identifier, or nil if none selected
    public func selectedSkinIdentifier(for gameId: String, orientation: SkinOrientation = .portrait) -> String? {
        return gameSpecificSkins[gameId]?[orientation]
    }
    
    /// Get the selected skin identifier for a game, falling back to system if not set
    /// - Parameters:
    ///   - gameId: The game's unique identifier
    ///   - system: The system identifier (fallback)
    ///   - orientation: The orientation (portrait or landscape)
    /// - Returns: The selected skin identifier, or nil if none selected
    public func effectiveSkinIdentifier(for gameId: String, system: SystemIdentifier, orientation: SkinOrientation = .portrait) -> String? {
        // First check for game-specific preference
        if let gameSkin = selectedSkinIdentifier(for: gameId, orientation: orientation) {
            return gameSkin
        }
        
        // Fall back to system preference
        return selectedSkinIdentifier(for: system, orientation: orientation)
    }
    
    /// Get the selected skin identifier for a system (legacy method)
    /// - Parameter system: The system identifier
    /// - Returns: The selected skin identifier for portrait orientation, or nil if none selected
    public func selectedSkinIdentifier(for system: SystemIdentifier) -> String? {
        return selectedSkinIdentifier(for: system, orientation: .portrait)
    }

    /// Set the selected skin for a system and orientation
    /// - Parameters:
    ///   - skinIdentifier: The skin identifier to select
    ///   - system: The system identifier
    ///   - orientation: The orientation (portrait or landscape)
    @MainActor
    public func setSelectedSkin(_ skinIdentifier: String?, for system: SystemIdentifier, orientation: SkinOrientation = .portrait) {
        if let skinIdentifier = skinIdentifier {
            if selectedSkins[system] == nil {
                selectedSkins[system] = [:]
            }
            selectedSkins[system]?[orientation] = skinIdentifier
        } else {
            selectedSkins[system]?[orientation] = nil
            
            // If both orientations are nil, remove the system entry entirely
            if selectedSkins[system]?.isEmpty ?? true {
                selectedSkins.removeValue(forKey: system)
            }
        }
        savePreferences()
    }
    
    /// Set the selected skin for a system (legacy method)
    /// - Parameters:
    ///   - skinIdentifier: The skin identifier to select
    ///   - system: The system identifier
    @MainActor
    public func setSelectedSkin(_ skinIdentifier: String?, for system: SystemIdentifier) {
        setSelectedSkin(skinIdentifier, for: system, orientation: .portrait)
    }
    
    /// Set the selected skin for a specific game
    /// - Parameters:
    ///   - skinIdentifier: The skin identifier to select
    ///   - gameId: The game's unique identifier
    ///   - orientation: The orientation (portrait or landscape)
    @MainActor
    public func setSelectedSkin(_ skinIdentifier: String?, for gameId: String, orientation: SkinOrientation = .portrait) {
        if let skinIdentifier = skinIdentifier {
            if gameSpecificSkins[gameId] == nil {
                gameSpecificSkins[gameId] = [:]
            }
            gameSpecificSkins[gameId]?[orientation] = skinIdentifier
        } else {
            gameSpecificSkins[gameId]?[orientation] = nil
            
            // If both orientations are nil, remove the game entry entirely
            if gameSpecificSkins[gameId]?.isEmpty ?? true {
                gameSpecificSkins.removeValue(forKey: gameId)
            }
        }
        saveGamePreferences()
    }

    /// Load preferences from UserDefaults
    private func loadPreferences() {
        loadSystemPreferences()
        loadGamePreferences()
    }
    
    /// Load system-specific preferences
    private func loadSystemPreferences() {
        // Try to load new format first
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let preferences = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            
            // Convert string keys to SystemIdentifier and SkinOrientation
            selectedSkins = preferences.compactMapKeys { key in
                SystemIdentifier(rawValue: key)
            }.mapValues { orientationDict in
                orientationDict.compactMapKeys { key in
                    SkinOrientation(rawValue: key)
                }
            }
            return
        }
        
        // Try to load legacy format and migrate
        let legacyKey = "com.provenance.deltaskin.preferences"
        if let data = UserDefaults.standard.data(forKey: legacyKey),
           let preferences = try? JSONDecoder().decode([String: String].self, from: data) {
            
            // Convert legacy format to new format (all portrait)
            var newPreferences: [SystemIdentifier: [SkinOrientation: String]] = [:]
            
            for (systemStr, skinId) in preferences {
                if let system = SystemIdentifier(rawValue: systemStr) {
                    newPreferences[system] = [.portrait: skinId]
                }
            }
            
            selectedSkins = newPreferences
            savePreferences()
            
            // Clear legacy preferences
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }

    /// Save preferences to UserDefaults
    private func savePreferences() {
        // Convert SystemIdentifier and SkinOrientation keys to strings
        let stringDict = selectedSkins.compactMapKeys { $0.rawValue }
            .mapValues { orientationDict in
                orientationDict.compactMapKeys { $0.rawValue }
            }

        if let data = try? JSONEncoder().encode(stringDict) {
            UserDefaults.standard.set(data, forKey: preferencesKey)
        }
    }
    
    /// Load game-specific preferences
    private func loadGamePreferences() {
        if let data = UserDefaults.standard.data(forKey: gamePreferencesKey),
           let preferences = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            
            // Convert string keys to SkinOrientation
            gameSpecificSkins = preferences.mapValues { orientationDict in
                orientationDict.compactMapKeys { key in
                    SkinOrientation(rawValue: key)
                }
            }
        }
    }
    
    /// Save game-specific preferences to UserDefaults
    private func saveGamePreferences() {
        // Convert SkinOrientation keys to strings
        let stringDict = gameSpecificSkins.mapValues { orientationDict in
            orientationDict.compactMapKeys { $0.rawValue }
        }

        if let data = try? JSONEncoder().encode(stringDict) {
            UserDefaults.standard.set(data, forKey: gamePreferencesKey)
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
