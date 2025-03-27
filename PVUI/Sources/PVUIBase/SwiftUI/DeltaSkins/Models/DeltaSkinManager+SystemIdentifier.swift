import Foundation
import PVPrimitives
import PVSystems

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

    /// Get a skin for a specific system identifier (synchronous version)
    func skin(for systemIdentifier: SystemIdentifier) async -> DeltaSkin? {
        // Convert SystemIdentifier to a string identifier that DeltaSkinManager understands
        let skinIdentifier = skinIdentifier(for: systemIdentifier)

        print("Looking for skin with identifier: \(skinIdentifier) for system: \(systemIdentifier)")

        // Get all available skins synchronously
        let allSkins = try! await availableSkins()

        // Find a skin that matches the identifier
        let matchingSkin = allSkins.first { skin in
            return skin.identifier.contains(skinIdentifier) ||
            (skin.gameType.rawValue.lowercased() == skinIdentifier)
        }

        if let skin = matchingSkin {
            print("Found skin: \(skin.name) for \(skinIdentifier)")
            // Make sure it's a DeltaSkin
            if let deltaSkin = skin as? DeltaSkin {
                return deltaSkin
            } else {
                print("Found skin is not a DeltaSkin: \(skin.identifier)")
                return nil
            }
        } else {
            print("No skin found for \(skinIdentifier)")
            return nil
        }
    }

    /// Get available skins for a specific system identifier
    func availableSkins(for systemIdentifier: SystemIdentifier) async throws -> [DeltaSkin] {
        // Convert SystemIdentifier to a string identifier that DeltaSkinManager understands
        let skinIdentifier = skinIdentifier(for: systemIdentifier)

        // Get all available skins
        let allSkins = try await availableSkins()

        // Filter skins for this system and convert to [DeltaSkin]
        let filteredSkins = allSkins.filter { skin in
            // Check if the skin is for this system
            return skin.gameType.rawValue.lowercased() == skinIdentifier ||
                   skin.identifier.contains(skinIdentifier)
        }

        // Convert to [DeltaSkin] - this might need adjustment based on your actual types
        return filteredSkins.compactMap { $0 as? DeltaSkin }
    }

    /// Get available skins for a specific system identifier (synchronous version)
    func availableSkinsSync(for systemIdentifier: SystemIdentifier) async -> [DeltaSkin] {
        // Convert SystemIdentifier to a string identifier that DeltaSkinManager understands
        let skinIdentifier = skinIdentifier(for: systemIdentifier)

        // Get all available skins synchronously
        let allSkins = try! await availableSkins()

        // Filter skins for this system and convert to [DeltaSkin]
        let filteredSkins = allSkins.filter { skin in
            // Check if the skin is for this system
            return (skin.gameType.rawValue.lowercased() == skinIdentifier) ||
                   skin.identifier.contains(skinIdentifier)
        }

        // Convert to [DeltaSkin]
        return filteredSkins.compactMap { $0 as? DeltaSkin }
    }

    /// Convert a SystemIdentifier to a string identifier for DeltaSkinManager
    private func skinIdentifier(for systemIdentifier: SystemIdentifier) -> String {
        switch systemIdentifier {
        case .NES:
            return "nes"
        case .SNES:
            return "snes"
        case .N64:
            return "n64"
        case .GB:
            return "gb"
        case .GBC:
            return "gbc"
        case .GBA:
            return "gba"
        case .Genesis:
            return "genesis"
        case .SegaCD:
            return "segacd"
        case .Sega32X:
            return "32x"
        case .MasterSystem:
            return "mastersystem"
        case .PSX:
            return "psx"
        case .PSP:
            return "psp"
        case .DS:
            return "nds"
        case .Atari2600:
            return "atari2600"
        case .Atari5200:
            return "atari5200"
        case .Atari7800:
            return "atari7800"
        case .AtariJaguar, .AtariJaguarCD:
            return "jaguar"
        case .Lynx:
            return "lynx"
        case .PCE, .PCECD:
            return "pcengine"
        case .SGFX:
            return "sgfx"
        case .WonderSwan, .WonderSwanColor:
            return "wonderswan"
        case .NGP, .NGPC:
            return "neogeopocket"
        case .PokemonMini:
            return "pokemonmini"
        case .VirtualBoy:
            return "virtualboy"
        case .Dreamcast:
            return "dreamcast"
        default:
            // For any other system, return a default identifier
            return systemIdentifier.rawValue.lowercased()
        }
    }
}
