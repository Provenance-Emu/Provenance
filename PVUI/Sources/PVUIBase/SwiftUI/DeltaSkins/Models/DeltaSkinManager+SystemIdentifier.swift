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

        // Filter by game type, including compatible types via skinLayoutGroup
        let requestedGroup = gameType.skinLayoutGroup
        let filtered = allSkins.filter { skin in
            // Exact match
            if skin.gameType == gameType {
                return true
            }

            // Group-based match: skins in the same layout group are compatible
            // (e.g. a Genesis skin works for Sega CD and 32X; a GBC skin works for GB)
            if skin.gameType.skinLayoutGroup == requestedGroup {
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
        if let skin = systemSkins.first(where: { CaseControllerDetector.isAllowedInAutomaticSkinSelection($0.identifier) }) {
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
            let typeMatches: Bool = {
                if skin.identifier.contains(skinIdentifier) || skin.gameType.matchesIdentifier(skinIdentifier) {
                    return true
                }
                if systemIdentifier == .GB && skin.gameType == .gbc {
                    return true
                }
                return false
            }()
            guard typeMatches else { return false }
            return CaseControllerDetector.isAllowedInAutomaticSkinSelection(skin.identifier)
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
        let requestedGroup = DeltaSkinGameType(systemIdentifier: systemIdentifier)?.skinLayoutGroup

        // Get all available skins
        let allSkins = try await availableSkins()

        // Filter skins for this system and convert to [DeltaSkin]
        let filteredSkins = allSkins.filter { skin in
            // Check if the skin is for this system (exact identifier or layout group match)
            if skin.gameType.matchesIdentifier(skinIdentifier) ||
               skin.identifier.contains(skinIdentifier) {
                return true
            }

            // Group-based match: skins in the same layout group are compatible
            if let group = requestedGroup, skin.gameType.skinLayoutGroup == group {
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
        let requestedGroup = DeltaSkinGameType(systemIdentifier: systemIdentifier)?.skinLayoutGroup

        // Get all available skins synchronously
        let allSkins: [any DeltaSkinProtocol]
        do {
            allSkins = try await availableSkins()
        } catch {
            ELOG("availableSkinsSync: Failed to load skins for system \(systemIdentifier.rawValue): \(error)")
            return []
        }

        // Filter skins for this system and convert to [DeltaSkin]
        let filteredSkins = allSkins.filter { skin in
            // Check if the skin is for this system (exact identifier or layout group match)
            if skin.gameType.matchesIdentifier(skinIdentifier) ||
               skin.identifier.contains(skinIdentifier) {
                return true
            }

            // Group-based match: skins in the same layout group are compatible
            if let group = requestedGroup, skin.gameType.skinLayoutGroup == group {
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
            guard candidates.contains(systemIdentifier.lowercased()) else { return false }
            return CaseControllerDetector.isAllowedInAutomaticSkinSelection(skin.identifier)
        }
    }

    /// Get the default skin for a system
    public func defaultSkin(for systemIdentifier: SystemIdentifier) -> (any DeltaSkinProtocol)? {
        if let exactMatch = loadedSkins.first(where: {
            $0.gameType.systemIdentifier == systemIdentifier && CaseControllerDetector.isAllowedInAutomaticSkinSelection($0.identifier)
        }) {
            return exactMatch
        }

        if systemIdentifier == .GB {
            return loadedSkins.first {
                $0.gameType == .gbc && CaseControllerDetector.isAllowedInAutomaticSkinSelection($0.identifier)
            }
        }

        return nil
    }

    /// Convert a SystemIdentifier to a string identifier for DeltaSkinManager
    private func skinIdentifier(for systemIdentifier: SystemIdentifier) -> String {
        switch systemIdentifier {
        // Nintendo
        case .NES, .FDS:
            return "nes"
        case .SNES:
            return "snes"
        case .N64:
            return "n64"
        case .GBC, .GB:
            return "gbc"
        case .GBA:
            return "gba"
        case .DS:
            return "nds"
        case ._3DS:
            return "3ds"
        case .VirtualBoy:
            return "vb"
        case .PokemonMini:
            return "pm"
        case .GameCube:
            return "gamecube"
        case .Wii:
            return "wii"

        // Sega
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
        case .Dreamcast:
            return "dc"

        // Sony
        case .PSX, .PS2, .PS3:
            return "ps1"
        case .PSP:
            return "psp"

        // NEC
        case .PCE, .PCECD:
            return "pce"
        case .PCFX:
            return "pcfx"
        case .SGFX:
            return "sgfx"

        // Atari
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
        case .Atari8bit:
            return "atari8bit"
        case .AtariST:
            return "atarist"

        // SNK
        case .NeoGeo, .NeoGeoCD:
            return "neogeo"
        case .NGP:
            return "ngp"
        case .NGPC:
            return "ngpc"

        // Bandai
        case .WonderSwan, .WonderSwanColor:
            return "ws"

        // Other
        case .Vectrex:
            return "vectrex"
        case ._3DO:
            return "3do"
        case .AppleII:
            return "appleii"
        case .C64:
            return "c64"
        case .CDi:
            return "cdi"
        case .ColecoVision:
            return "colecovision"
        case .CPS1:
            return "cps1"
        case .CPS2:
            return "cps2"
        case .CPS3:
            return "cps3"
        case .DOOM:
            return "doom"
        case .DOS:
            return "dos"
        case .EP128:
            return "ep128"
        case .Intellivision:
            return "intellivision"
        case .Macintosh:
            return "macintosh"
        case .MAME:
            return "mame"
        case .MegaDuck:
            return "megaduck"
        case .MSX:
            return "msx"
        case .MSX2:
            return "msx2"
        case .Music:
            return "music"
        case .Odyssey2:
            return "odyssey2"
        case .PalmOS:
            return "palmos"
        case .Quake:
            return "quake"
        case .Quake2:
            return "quake2"
        case .RetroArch:
            return "retroarch"
        case .Supervision:
            return "supervision"
        case .TIC80:
            return "tic80"
        case .Wolf3D:
            return "wolf3d"
        case .PC98:
            return "pc98"
        case .ZXSpectrum:
            return "zxspectrum"
        case .Unknown:
            return "unknown"
        }
    }
}
