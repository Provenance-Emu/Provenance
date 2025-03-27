import Foundation
import PVPrimitives
import Combine

/// Manages user preferences for Delta skins
public final class DeltaSkinPreferences: ObservableObject {
    /// Shared instance
    public static let shared = DeltaSkinPreferences()

    /// Currently selected skin identifier for each system
    @Published public private(set) var selectedSkins: [SystemIdentifier: String] = [:]

    /// UserDefaults key for storing skin preferences
    private let preferencesKey = "com.provenance.deltaskin.preferences"

    private init() {
        loadPreferences()
    }

    /// Get the selected skin identifier for a system
    /// - Parameter system: The system identifier
    /// - Returns: The selected skin identifier, or nil if none selected
    public func selectedSkinIdentifier(for system: SystemIdentifier) -> String? {
        return selectedSkins[system]
    }

    /// Set the selected skin for a system
    /// - Parameters:
    ///   - skinIdentifier: The skin identifier to select
    ///   - system: The system identifier
    @MainActor
    public func setSelectedSkin(_ skinIdentifier: String?, for system: SystemIdentifier) {
        if let skinIdentifier = skinIdentifier {
            selectedSkins[system] = skinIdentifier
        } else {
            selectedSkins.removeValue(forKey: system)
        }
        savePreferences()
    }

    /// Load preferences from UserDefaults
    private func loadPreferences() {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey),
              let preferences = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        // Convert string keys to SystemIdentifier
        selectedSkins = preferences.compactMapKeys { key in
            SystemIdentifier(rawValue: key)
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
