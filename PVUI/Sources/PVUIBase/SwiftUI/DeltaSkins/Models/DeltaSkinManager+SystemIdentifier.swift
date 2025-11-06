import Foundation
import PVPrimitives
import PVSystems

public extension DeltaSkinManager {
    /// Get all skins for a specific system identifier
    /// - Parameter system: The system identifier
    /// - Returns: Array of skins compatible with the system
    func skins(for system: SystemIdentifier) async throws -> [any DeltaSkinProtocol] {
        ILOG("skins: skins(for: \(system.rawValue)) called")
        // Convert SystemIdentifier to DeltaSkinGameType
        guard let gameType = DeltaSkinGameType(systemIdentifier: system) else {
            WLOG("skins: No game type found for system \(system.rawValue)")
            return []
        }

        // Get all skins and filter by game type
        let allSkins = try await availableSkins()
        ILOG("skins: Filtering \(allSkins.count) total skins for system \(system.rawValue)")

        // Filter by game type, including compatible types
        let filtered = allSkins.filter { skin in
            // Exact match
            if skin.gameType == gameType {
                return true
            }

            // Special case: GB systems can use GBC skins
            if system == .GB && skin.gameType == .gbc {
                return true
            }

            return false
        }
        ILOG("skins: Found \(filtered.count) skins for system \(system.rawValue)")
        return filtered
    }

    /// Get the currently selected skin for a system
    /// - Parameter system: The system identifier
    /// - Returns: The selected skin, or nil if none selected
    func selectedSkin(for system: SystemIdentifier) async throws -> (any DeltaSkinProtocol)? {
        ILOG("skins: selectedSkin(for: \(system.rawValue)) called")
        // Get the selected skin identifier from centralized manager (includes session overrides)
        let orientation: SkinOrientation = .portrait // Default to portrait, could be made dynamic
        guard let selectedIdentifier = DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
            for: system,
            gameId: nil,
            orientation: orientation
        ) else {
            ILOG("skins: No selected skin identifier found for system \(system.rawValue)")
            return nil
        }
        ILOG("skins: Selected skin identifier for \(system.rawValue): \(selectedIdentifier)")

        // Find the skin with this identifier
        let systemSkins = try await skins(for: system)
        if let skin = systemSkins.first(where: { $0.identifier == selectedIdentifier }) {
            ILOG("skins: Found selected skin '\(skin.name)' for system \(system.rawValue)")
            return skin
        } else {
            WLOG("skins: Selected skin identifier '\(selectedIdentifier)' not found in available skins for system \(system.rawValue)")
            return nil
        }
    }

    /// Get the default skin for a system (first available)
    /// - Parameter system: The system identifier
    /// - Returns: The default skin, or nil if none available
    func defaultSkin(for system: SystemIdentifier) async throws -> (any DeltaSkinProtocol)? {
        ILOG("skins: defaultSkin(for: \(system.rawValue)) called")
        let systemSkins = try await skins(for: system)
        if let skin = systemSkins.first {
            ILOG("skins: Found default skin '\(skin.name)' for system \(system.rawValue)")
            return skin
        } else {
            WLOG("skins: No default skin available for system \(system.rawValue)")
            return nil
        }
    }

    /// Get the skin to use for a system (selected or default)
    /// - Parameter system: The system identifier
    /// - Returns: The skin to use, or nil if none available
    func skinToUse(for system: SystemIdentifier) async throws -> (any DeltaSkinProtocol)? {
        ILOG("skins: skinToUse(for: \(system.rawValue)) called")
        // Try to get selected skin first
        if let selected = try await selectedSkin(for: system) {
            ILOG("skins: Using selected skin '\(selected.name)' for system \(system.rawValue)")
            return selected
        }

        // Fall back to default skin
        if let defaultSkin = try await defaultSkin(for: system) {
            ILOG("skins: Using default skin '\(defaultSkin.name)' for system \(system.rawValue)")
            return defaultSkin
        }

        WLOG("skins: No skin available for system \(system.rawValue)")
        return nil
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
            if skin.identifier.contains(skinIdentifier) ||
               skin.gameType.matchesIdentifier(skinIdentifier) {
                return true
            }

            // Special case: GB systems can use GBC skins
            if systemIdentifier == .GB && skin.gameType == .gbc {
                return true
            }

            return false
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
            if skin.gameType.matchesIdentifier(skinIdentifier) ||
               skin.identifier.contains(skinIdentifier) {
                return true
            }

            // Special case: GB systems can use GBC skins
            if systemIdentifier == .GB && skin.gameType == .gbc {
                return true
            }

            return false
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
            if skin.gameType.matchesIdentifier(skinIdentifier) ||
               skin.identifier.contains(skinIdentifier) {
                return true
            }

            // Special case: GB systems can use GBC skins
            if systemIdentifier == .GB && skin.gameType == .gbc {
                return true
            }

            return false
        }

        // Convert to [DeltaSkin]
        return filteredSkins.compactMap { $0 as? DeltaSkin }
    }


    /// Get the default skin for a system
    public func defaultSkin(for systemIdentifier: String) -> (any DeltaSkinProtocol)? {
        return loadedSkins.first { skin in
            let candidates = [skin.gameType.deltaIdentifierString, skin.gameType.manicIdentifierString].compactMap { $0?.lowercased() }
            return candidates.contains(systemIdentifier.lowercased())
        }
    }

    /// Get the default skin for a system
    public func defaultSkin(for systemIdentifier: SystemIdentifier) -> (any DeltaSkinProtocol)? {
        // First try exact match
        if let exactMatch = loadedSkins.first(where: { $0.gameType.systemIdentifier == systemIdentifier }) {
            return exactMatch
        }

        // Special case: GB systems can use GBC skins
        if systemIdentifier == .GB {
            return loadedSkins.first { $0.gameType == .gbc }
        }

        return nil
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
        case .GBC, .GB:
            return "gbc"
        case .GBA:
            return "gba"
        case .Genesis:
            return "md"
        case .SegaCD:
            return "mcd"
        case .Sega32X:
            return "32x"
        case .MasterSystem:
            return "ms"
        case .GameGear:
            return "gg"
        case .Saturn:
            return "ss"
        case .SG1000:
            return "sg1000"
        case .PSX, .PS2, .PS3:
            return "ps1"
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
            return "pce"
        case .SGFX:
            return "sgfx"
        case .WonderSwan, .WonderSwanColor:
            return "ws"
        case .NGP, .NGPC:
            return "ngp"
        case .PokemonMini:
            return "pm"
        case .VirtualBoy:
            return "vb"
        case .Dreamcast:
            return "dc"
        default:
            // For any other system, return a default identifier
            return systemIdentifier.rawValue.lowercased()
        }
    }
}
