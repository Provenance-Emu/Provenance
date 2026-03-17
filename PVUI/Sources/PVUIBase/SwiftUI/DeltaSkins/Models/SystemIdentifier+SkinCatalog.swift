//
//  SystemIdentifier+SkinCatalog.swift
//  PVUIBase
//
//  Created for Provenance (GitHub issue #2514)
//

import Foundation
import PVPrimitives
import PVSystems

// MARK: - SystemIdentifier Skin Catalog Mapping

extension SystemIdentifier {
    /// The short code used in the remote skin catalog JSON.
    ///
    /// These codes correspond to the `systems` array in each `SkinCatalogEntry`.
    /// Returns `nil` for systems that do not yet have skin catalog support.
    ///
    /// All codes are lowercase so comparisons against catalog data can be made
    /// with a simple `==` after both sides are lowercased (or directly when
    /// using `SystemIdentifier.displayName(forCatalogCode:)`).
    public var skinCatalogSystemCode: String? {
        switch self {
        // Nintendo handhelds
        case .GB:            return "gbc"
        case .GBC:           return "gbc"
        case .GBA:           return "gba"
        case .VirtualBoy:    return "virtualboy"
        case .PokemonMini:   return "pm"
        case .DS:            return "nds"
        case ._3DS:          return "3ds"

        // Nintendo consoles
        case .NES, .FDS:     return "nes"
        case .SNES:          return "snes"
        case .N64:           return "n64"
        case .GameCube:      return "gamecube"
        case .Wii:           return "wii"

        // Sega
        case .Genesis:       return "genesis"
        case .SegaCD:        return "segacd"
        case .Sega32X:       return "32x"
        case .MasterSystem:  return "mastersystem"
        case .GameGear:      return "gamegear"
        case .SG1000:        return "sg1000"
        case .Saturn:        return "saturn"
        case .Dreamcast:     return "dreamcast"

        // Sony
        case .PSX:           return "psx"
        case .PS2:           return "ps2"
        case .PS3:           return "ps3"
        case .PSP:           return "psp"

        // NEC
        case .PCE:           return "pce"
        case .PCECD:         return "pcecd"
        case .PCFX:          return "pcfx"
        case .SGFX:          return "sgfx"

        // Atari
        case .Atari2600:     return "atari2600"
        case .Atari5200:     return "atari5200"
        case .Atari7800:     return "atari7800"
        case .AtariJaguar:   return "jaguar"
        case .AtariJaguarCD: return "jaguarcd"
        case .Lynx:          return "lynx"
        case .Atari8bit:     return "atari8bit"
        case .AtariST:       return "atarist"

        // SNK
        case .NeoGeo:        return "neogeo"
        case .NeoGeoCD:      return "neogeocd"
        case .NGP:           return "ngp"
        case .NGPC:          return "ngpc"

        // Bandai
        case .WonderSwan:      return "ws"
        case .WonderSwanColor: return "wsc"

        // Other
        case ._3DO:          return "3do"
        case .ColecoVision:  return "colecovision"
        case .Intellivision: return "intellivision"
        case .Odyssey2:      return "odyssey2"
        case .Vectrex:       return "vectrex"
        case .C64:           return "c64"
        case .MAME:          return "mame"
        case .DOS:           return "dos"
        case .MSX:           return "msx"
        case .MSX2:          return "msx2"

        // Unsupported / no catalog code
        case .AppleII, .CDi, .CPS1, .CPS2, .CPS3, .DOOM, .EP128,
             .Macintosh, .MegaDuck, .Music, .PalmOS, .Quake, .Quake2,
             .RetroArch, .Supervision, .TIC80, .Wolf3D, .ZXSpectrum,
             .Unknown:
            return nil
        }
    }

    /// A concise, human-readable display name for the system suitable for UI
    /// badges and filter chips in the skin catalog browser.
    ///
    /// This is intentionally shorter than `systemName` (e.g. "Master System"
    /// rather than "Master System - Mark III") because catalog badges have
    /// limited horizontal space.  Returns `nil` for systems with no catalog
    /// support (i.e. where `skinCatalogSystemCode` is also `nil`).
    public var skinCatalogDisplayName: String? {
        guard skinCatalogSystemCode != nil else { return nil }
        switch self {
        // Nintendo handhelds
        case .GB:            return "Game Boy"
        case .GBC:           return "Game Boy Color"
        case .GBA:           return "Game Boy Advance"
        case .VirtualBoy:    return "Virtual Boy"
        case .PokemonMini:   return "Pokémon Mini"
        case .DS:            return "Nintendo DS"
        case ._3DS:          return "Nintendo 3DS"

        // Nintendo consoles
        case .NES, .FDS:     return "NES"
        case .SNES:          return "SNES"
        case .N64:           return "N64"
        case .GameCube:      return "GameCube"
        case .Wii:           return "Wii"

        // Sega
        case .Genesis:       return "Genesis"
        case .SegaCD:        return "Sega CD"
        case .Sega32X:       return "32X"
        case .MasterSystem:  return "Master System"
        case .GameGear:      return "Game Gear"
        case .SG1000:        return "SG-1000"
        case .Saturn:        return "Saturn"
        case .Dreamcast:     return "Dreamcast"

        // Sony
        case .PSX:           return "PlayStation"
        case .PS2:           return "PlayStation 2"
        case .PS3:           return "PlayStation 3"
        case .PSP:           return "PSP"

        // NEC
        case .PCE:           return "PC Engine"
        case .PCECD:         return "PC Engine CD"
        case .PCFX:          return "PC-FX"
        case .SGFX:          return "SuperGrafx"

        // Atari
        case .Atari2600:     return "Atari 2600"
        case .Atari5200:     return "Atari 5200"
        case .Atari7800:     return "Atari 7800"
        case .AtariJaguar:   return "Jaguar"
        case .AtariJaguarCD: return "Jaguar CD"
        case .Lynx:          return "Lynx"
        case .Atari8bit:     return "Atari 8-bit"
        case .AtariST:       return "Atari ST"

        // SNK
        case .NeoGeo:        return "Neo Geo"
        case .NeoGeoCD:      return "Neo Geo CD"
        case .NGP:           return "NGP"
        case .NGPC:          return "NGP Color"

        // Bandai
        case .WonderSwan:      return "WonderSwan"
        case .WonderSwanColor: return "WonderSwan Color"

        // Other
        case ._3DO:          return "3DO"
        case .ColecoVision:  return "ColecoVision"
        case .Intellivision: return "Intellivision"
        case .Odyssey2:      return "Odyssey²"
        case .Vectrex:       return "Vectrex"
        case .C64:           return "C64"
        case .MAME:          return "MAME"
        case .DOS:           return "DOS"
        case .MSX:           return "MSX"
        case .MSX2:          return "MSX2"

        default:             return nil
        }
    }

    /// Returns a human-readable display name for the given skin catalog system
    /// code.
    ///
    /// Looks up the `SystemIdentifier` whose `skinCatalogSystemCode` matches
    /// `code` (case-insensitively) and returns its `skinCatalogDisplayName`.
    /// Falls back to an uppercased version of the code when no match is found.
    ///
    /// This is the canonical lookup used by catalog browser views so that all
    /// system-name rendering goes through a single, testable code path rather
    /// than scattered inline dictionaries.
    ///
    /// - Parameter code: A system code from the catalog JSON (e.g.
    ///   `"mastersystem"`, `"gba"`, `"virtualboy"`).
    /// - Returns: A short human-friendly label such as `"Master System"` or
    ///   `"Game Boy Advance"`.
    public static func displayName(forCatalogCode code: String) -> String {
        let normalized = code.lowercased()
        if let match = SystemIdentifier.allCases.first(where: {
            $0.skinCatalogSystemCode?.lowercased() == normalized
        }) {
            return match.skinCatalogDisplayName ?? match.systemName
        }
        // Unknown code — at least make it readable
        return code.uppercased()
    }
}
