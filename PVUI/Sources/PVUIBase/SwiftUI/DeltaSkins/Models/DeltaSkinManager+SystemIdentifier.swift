import Foundation
import PVPrimitives
import PVSystems
import SkinKitCore
import SkinKitManager

extension SystemIdentifier {
    /// The id SkinKit stores per-system skin picks under (the raw value, as before).
    public var skinSystemID: SkinSystemID { SkinSystemID(rawValue) }
}

/// `SystemIdentifier` overloads of SkinKitManager's game-type queries. SkinKit takes the game type
/// and catalog codes; these compute them from the system, as Provenance's queries did.
public extension DeltaSkinManager {
    /// Get all skins for a specific system identifier
    /// - Parameter system: The system identifier
    /// - Returns: Array of skins compatible with the system
    func skins(for system: SystemIdentifier) async throws -> [any DeltaSkinProtocol] {
        guard let gameType = DeltaSkinGameType(systemIdentifier: system) else {
            WLOG("skins: No game type found for system \(system.rawValue)")
            return []
        }
        return try await skins(for: gameType, catalogSystemCodes: Set(system.relatedSkinCatalogSystemCodes))
    }

    /// Get the currently selected skin for a system
    /// - Parameter system: The system identifier
    /// - Returns: The selected skin, or nil if none selected (also returns nil when the
    ///   selected skin is a case-companion skin that shouldn't be auto-loaded right now)
    func selectedSkin(for system: SystemIdentifier) async throws -> (any DeltaSkinProtocol)? {
        guard let gameType = DeltaSkinGameType(systemIdentifier: system) else {
            WLOG("skins: No game type found for system \(system.rawValue)")
            return nil
        }
        return try await selectedSkin(for: system.skinSystemID, gameType: gameType,
                                      catalogSystemCodes: Set(system.relatedSkinCatalogSystemCodes))
    }

    /// Get the default skin for a system (first available, sorted deterministically).
    func defaultSkin(for system: SystemIdentifier) async throws -> (any DeltaSkinProtocol)? {
        guard let gameType = DeltaSkinGameType(systemIdentifier: system) else {
            WLOG("skins: No game type found for system \(system.rawValue)")
            return nil
        }
        return try await defaultSkin(for: gameType, catalogSystemCodes: Set(system.relatedSkinCatalogSystemCodes))
    }

    /// Get the skin to use for a system (selected or default)
    func skinToUse(for system: SystemIdentifier) async throws -> (any DeltaSkinProtocol)? {
        guard let gameType = DeltaSkinGameType(systemIdentifier: system) else {
            WLOG("skins: No game type found for system \(system.rawValue)")
            return nil
        }
        return try await skinToUse(for: system.skinSystemID, gameType: gameType,
                                   catalogSystemCodes: Set(system.relatedSkinCatalogSystemCodes))
    }

    /// Get a skin for a specific system identifier (synchronous version)
    func skin(for systemIdentifier: SystemIdentifier) async -> DeltaSkin? {
        // Convert SystemIdentifier to a string identifier that DeltaSkinManager understands
        let skinIdentifier = skinIdentifier(for: systemIdentifier)

        print("Looking for skin with identifier: \(skinIdentifier) for system: \(systemIdentifier)")

        // Get all available skins synchronously
        guard let allSkins = try? await availableSkins() else { return nil }

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
        let requestedCodes = Set(systemIdentifier.relatedSkinCatalogSystemCodes)

        // Get all available skins
        let allSkins = try await availableSkins()
        let overrideCodes = await SkinSystemOverrideRegistry.shared.overrideCodesByIdentifier(for: allSkins)

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

            /// Authoritative override path (see `skins(for:)`).
            if let codes = overrideCodes[skin.identifier], !codes.isDisjoint(with: requestedCodes) {
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
        let requestedCodes = Set(systemIdentifier.relatedSkinCatalogSystemCodes)

        // Get all available skins synchronously
        let allSkins: [any DeltaSkinProtocol]
        do {
            allSkins = try await availableSkins()
        } catch {
            ELOG("availableSkinsSync: Failed to load skins for system \(systemIdentifier.rawValue): \(error)")
            return []
        }

        let overrideCodes = await SkinSystemOverrideRegistry.shared.overrideCodesByIdentifier(for: allSkins)

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

            /// Authoritative override path (see `skins(for:)`).
            if let codes = overrideCodes[skin.identifier], !codes.isDisjoint(with: requestedCodes) {
                return true
            }

            return false
        }

        // Convert to [DeltaSkin]
        return filteredSkins.compactMap { $0 as? DeltaSkin }
    }

    /// Get the default skin for a system
    func defaultSkin(for systemIdentifier: SystemIdentifier) -> (any DeltaSkinProtocol)? {
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
        case .Dreamcast, .NAOMI, .Atomiswave, .NAOMI2:
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
