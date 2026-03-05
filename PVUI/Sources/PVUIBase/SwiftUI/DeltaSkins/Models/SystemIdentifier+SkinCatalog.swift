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
    public var skinCatalogSystemCode: String? {
        switch self {
        // Nintendo handhelds
        case .GB:            return "gbc"
        case .GBC:           return "gbc"
        case .GBA:           return "gba"
        case .VirtualBoy:    return "vb"
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
        case .MasterSystem:  return "sms"
        case .GameGear:      return "gg"
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
}
