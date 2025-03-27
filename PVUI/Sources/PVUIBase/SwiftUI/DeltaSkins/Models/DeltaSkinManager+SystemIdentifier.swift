import Foundation
import PVPrimitives

public extension DeltaSkinManager {
    /// Get all skins for a specific system identifier
    /// - Parameter system: The system identifier
    /// - Returns: Array of skins compatible with the system
    func skins(for system: SystemIdentifier) async throws -> [DeltaSkinProtocol] {
        // Convert SystemIdentifier to DeltaSkinGameType
        guard let gameType = DeltaSkinGameType(systemIdentifier: system) else {
            return []
        }

        // Get all skins and filter by game type
        let allSkins = try await availableSkins()
        return allSkins.filter { $0.gameType == gameType }
    }

    /// Get the currently selected skin for a system
    /// - Parameter system: The system identifier
    /// - Returns: The selected skin, or nil if none selected
    func selectedSkin(for system: SystemIdentifier) async throws -> DeltaSkinProtocol? {
        // Get the selected skin identifier from preferences
        guard let selectedIdentifier = DeltaSkinPreferences.shared.selectedSkinIdentifier(for: system) else {
            return nil
        }

        // Find the skin with this identifier
        let systemSkins = try await skins(for: system)
        return systemSkins.first { $0.identifier == selectedIdentifier }
    }

    /// Get the default skin for a system (first available)
    /// - Parameter system: The system identifier
    /// - Returns: The default skin, or nil if none available
    func defaultSkin(for system: SystemIdentifier) async throws -> DeltaSkinProtocol? {
        let systemSkins = try await skins(for: system)
        return systemSkins.first
    }

    /// Get the skin to use for a system (selected or default)
    /// - Parameter system: The system identifier
    /// - Returns: The skin to use, or nil if none available
    func skinToUse(for system: SystemIdentifier) async throws -> DeltaSkinProtocol? {
        // Try to get selected skin first
        if let selected = try await selectedSkin(for: system) {
            return selected
        }

        // Fall back to default skin
        return try await defaultSkin(for: system)
    }
}
