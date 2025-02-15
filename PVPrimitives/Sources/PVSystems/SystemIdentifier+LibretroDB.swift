import Foundation

public extension SystemIdentifier {
    /// LibretroDB platform ID for this system
    var libretroDatabaseID: Int {
        switch self {
        case .Atari2600: return 38  // 2600
        case .Atari5200: return 77  // 5200
        case .Atari7800: return 34  // 7800
        case .AtariJaguar: return 29  // Jaguar
        case .AtariJaguarCD: return 29  // Using same as Jaguar since no CD-specific ID
        case .AtariST: return 55  // ST
        case .C64: return 100  // Commodore 64
        case .ColecoVision: return 114
        case .DOS: return 10
        case .DS: return 90    // Nintendo DS
        case .Dreamcast: return 99
        case .FDS: return 40   // Family Computer Disk System
        case .GB: return 75    // Game Boy
        case .GBA: return 115  // Game Boy Advance
        case .GBC: return 86   // Game Boy Color
        case .GameCube: return 51
        case .GameGear: return 78
        case .Genesis: return 15  // Mega Drive - Genesis
        case .Intellivision: return 92
        case .Lynx: return 79
        case .MAME: return 41  // Arcade Games
        case .MSX2: return 63
        case .MSX: return 36
        case .MasterSystem: return 83  // Master System - Mark III
        case .N64: return 22   // Nintendo 64
        case .NES: return 28   // Nintendo Entertainment System
        case .NGP: return 9    // Neo Geo Pocket
        case .NGPC: return 71  // Neo Geo Pocket Color
        case .Odyssey2: return 35
        case .PCE: return 108  // PC Engine - TurboGrafx 16
        case .PCECD: return 12  // PC Engine CD - TurboGrafx-CD
        case .PCFX: return 20
        case .PS2: return 56   // PlayStation 2
        case .PS3: return 48   // PlayStation 3
        case .PSP: return 61   // PlayStation Portable
        case .PSX: return 6    // PlayStation
        case .PokemonMini: return 30
        case .SG1000: return 76
        case .SGFX: return 3   // PC Engine SuperGrafx
        case .SNES: return 37  // Super Nintendo Entertainment System
        case .Saturn: return 47
        case .Sega32X: return 14  // 32X
        case .SegaCD: return 2   // Mega-CD - Sega CD
        case .Supervision: return 82
        case .Vectrex: return 69
        case .VirtualBoy: return 113
        case .Wii: return 101
        case .WonderSwan: return 33
        case .WonderSwanColor: return 109
        case .ZXSpectrum: return 64
        case ._3DO: return 73
        case ._3DS: return 21  // Nintendo 3DS
        case .TIC80: return 26
        case .NeoGeo: return 1
//      case .Amiga: return 89
        case .Quake: return 23
        case .Quake2: return 4
        case .Wolf3D: return 59
        case .DOOM: return 53
        case .CPS1: return 41 // Arcade
        case .CPS2: return 41 // Arcade
        case .CPS3: return 41 // Arcade

        // Systems we don't map (yet)
        case
                .AppleII,
                .Atari8bit,
                .CDi,
                .EP128,
                .Macintosh,
                .MegaDuck,
                .Music,
                .PalmOS,
                .RetroArch,
                .Unknown:
            return 0
        }
    }

    /// Create a SystemIdentifier from a LibretroDB platform ID
    /// - Parameter libretroDatabaseID: The LibretroDB platform ID
    /// - Returns: The corresponding SystemIdentifier, if one exists
    static func fromLibretroDatabaseID(_ libretroDatabaseID: Int) -> SystemIdentifier? {
        switch libretroDatabaseID {
        case 100: return .C64          // Commodore 64
        case 101: return .Wii           // Wii
        case 108: return .PCE          // PC Engine - TurboGrafx 16
        case 109: return .WonderSwanColor
        case 10: return .DOS
        case 113: return .VirtualBoy    // VirtualBoy
        case 114: return .ColecoVision
        case 115: return .GBA          // Game Boy Advance
        case 12: return .PCECD         // PC Engine CD
        case 14: return .Sega32X       // 32X
        case 15: return .Genesis       // Mega Drive
        case 20: return .PCFX
        case 21: return ._3DS          // Nintendo 3DS
        case 22: return .N64           // Nintendo 64
        case 28: return .NES           // Nintendo Entertainment System
        case 29: return .AtariJaguar   // Jaguar
        case 2: return .SegaCD         // Mega-CD
        case 30: return .PokemonMini   // Nintendo PokeMini
        case 33: return .WonderSwan
        case 34: return .Atari7800     // 7800
        case 35: return .Odyssey2
        case 36: return .MSX
        case 37: return .SNES          // Super Nintendo Entertainment System
        case 38: return .Atari2600     // 2600
        case 3: return .SGFX           // PC Engine SuperGrafx
        case 40: return .FDS           // Family Computer Disk System
        case 41: return .MAME          // Arcade Games
        case 47: return .Saturn
        case 48: return .PS3           // PlayStation 3
        case 49: return .Wii            // Wii (Digital)
        case 51: return .GameCube
        case 55: return .AtariST       // ST
        case 56: return .PS2           // PlayStation 2
        case 61: return .PSP           // PlayStation Portable
        case 63: return .MSX2
        case 64: return .ZXSpectrum
        case 69: return .Vectrex
        case 6: return .PSX            // PlayStation
        case 71: return .NGPC          // Neo Geo Pocket Color
        case 73: return ._3DO
        case 75: return .GB            // Game Boy
        case 76: return .SG1000
        case 77: return .Atari5200     // 5200
        case 78: return .GameGear
        case 79: return .Lynx
        case 82: return .Supervision   // Watara Supervision
        case 83: return .MasterSystem  // Master System - Mark III
        case 86: return .GBC           // Game Boy Color
        case 90: return .DS            // Nintendo DS
        case 92: return .Intellivision
        case 99: return .Dreamcast
        case 9: return .NGP            // Neo Geo Pocket
        // case 89: return .Amiga
        // Unsupported systems:
        case 4:  return .Quake2
        // case 5: Game.com
        // case 7: Game Master
        // case 8: Adventure Vision
        // case 11: Jump 'n Bump
        // case 13: PlayStation Vita
        // case 16: Tomb Raider
        // case 17: RPG Maker
        // case 18: Lutro
        // case 19: Cannonball
        case 23: return .Quake
        // case 24: Satellaview
        // case 25: Atomiswave
        // case 26: TIC-80
        case 26: return .TIC80
        // case 27: Handheld Electronic Game
        // case 30: Pokemon Mini
        // case 31: Quake III
        // case 32: Sufami Turbo
        // case 42: e-Reader
        // case 43: Arcadia 2001
        case 44: return .MAME
        // case 45: ZX Spectrum +3
        case 45: return .ZXSpectrum
        // case 46: PV-1000
        // case 50: ZX 81
        // case 52: VIC-20
        case 53: return .DOOM
        // case 54: Channel F
        // case 57: Loopy
        // case 58: MAME 2003
        case 58: return .MAME
        case 59: return .Wolf3D
        // case 60: Dinothawr
        // case 62: MAME 2016
        case 62: return .MAME
        // case 65: MrBoom
        // case 66: MAME 2000
        case 66: return .MAME
        // case 67: MOTO
        // case 68: Super Cassette Vision
        // case 70: Rick Dangerous
        // case 72: Uzebox
        // case 74: MAME 2015
        case 74: return .MAME
        // case 80: CPC
        // case 81: MAME 2010
        case 81: return .MAME
        // case 84: X68000
        // case 85: PC-98
        // case 87: GX4000
        // case 88: Cave Story
        // case 91: PICO
        // case 93: PlayStation Portable (PSN)
        case 93: return .PSP
        // case 94: Leapster Learning Game System
        // case 95: Nintendo 64DD
        case 95: return .N64
        // case 96: WASM-4
        // case 97: CreatiVision
        // case 98: Super Acan
        // case 102: Videopac+
        // case 103: Nintendo DSi
        case 103: return .DS
        // case 104: V.Smile
        // case 105: Xbox
        // case 106: PlayStation 3 (PSN)
        case 106: return .PS3
        // case 107: GP32
        // case 110: ChaiLove
        // case 111: LowRes NX
        // case 112: Studio II
        // case 116: HBMAME
        // case 117: Flashback
        // case 118: ScummVM
        // case 119: Plus-4

        default: return nil
        }
    }
}

import Foundation

extension SystemIdentifier {
    /// Get the libretro system name used in thumbnail URLs
    public var libretroDatabaseName: String {
        switch self {
        // Atari Systems
        case .Atari8bit:     return "Atari - 8-bit"
        case .AtariJaguarCD: return "Atari - Atari Jaguar" // Does not exist
        case .Atari2600:     return "Atari - 2600"
        case .Atari5200:     return "Atari - 5200"
        case .Atari7800:     return "Atari - 7800"
        case .AtariJaguar:   return "Atari - Jaguar"
        case .Lynx:          return "Atari - Lynx"
        case .AtariST:       return "Atari - ST"

        // Nintendo Systems
        case .NES:           return "Nintendo - Nintendo Entertainment System"
        case .SNES:          return "Nintendo - Super Nintendo Entertainment System"
        case .N64:           return "Nintendo - Nintendo 64"
        case .GameCube:      return "Nintendo - GameCube"
        case .GB:            return "Nintendo - Game Boy"
        case .GBC:           return "Nintendo - Game Boy Color"
        case .GBA:           return "Nintendo - Game Boy Advance"
        case .VirtualBoy:    return "Nintendo - Virtual Boy"
        case .PokemonMini:   return "Nintendo - Pokemon Mini"
        case .FDS:           return "Nintendo - Family Computer Disk System"

        // Sega Systems
        //case .PICO:          return "Sega - PICO"
        case .Dreamcast:     return "Sega - Dreamcast"
        case .GameGear:      return "Sega - Game Gear"
        case .Genesis:       return "Sega - Mega Drive - Genesis"
        case .MasterSystem:  return "Sega - Master System - Mark III"
        case .SG1000:        return "Sega - SG-1000"
        case .Saturn:        return "Sega - Saturn"
        case .Sega32X:       return "Sega - 32X"
        case .SegaCD:        return "Sega - Mega-CD - Sega CD"

        // Sony Systems
        case .PSX:           return "Sony - PlayStation"
        case .PSP:           return "Sony - PlayStation Portable"
        case .PS2:           return "Sony - PlayStation 2"
        case .PS3:           return "Sony - PlayStation 3"
        //case .PS4:           return "Sony - PlayStation 4"

        // NEC Systems
        case .PCE:          return "NEC - PC Engine - TurboGrafx 16"
        case .PCFX:         return "NEC - PC-FX"
        case .PCECD:        return "NEC - PC Engine CD - TurboGrafx-CD"
        case .SGFX:         return "NEC - PC Engine SuperGrafx"

        // SNK Systems
        case .NeoGeo:       return "SNK - Neo Geo"
        case .NGP:          return "SNK - Neo Geo Pocket"
        case .NGPC:         return "SNK - Neo Geo Pocket Color"

        // Other Systems
        case .WonderSwan:       return "Bandai - WonderSwan"
        case .WonderSwanColor:  return "Bandai - WonderSwan Color"
        case .Vectrex:          return "GCE - Vectrex"
        case .ColecoVision:     return "Coleco - ColecoVision"
        case .Intellivision:    return "Mattel - Intellivision"
        case .Odyssey2:         return "Magnavox - Odyssey2"
        case ._3DO:             return "The 3DO Company - 3DO"
        case .CDi:              return "Philips - CD-i"
            
        // Capcom
        case .CPS1:         return "MAME"
        case .CPS2:         return "MAME"
        case .CPS3:         return "MAME"

        // Id Softare
        case .DOOM:         return "DOOM"
        case .Quake:        return "Quake"
        case .Quake2:       return "Quake II"
       //case .Quake3:        return "Quake III"
        case .Wolf3D:       return "Wolfenstein 3D"
            
        // Microsoft
        case .MSX:          return "Microsoft - MSX"
        case .MSX2:         return "Microsoft - MSX2"

        // Apple
        case .AppleII:      return "Apple - Apple II" // Does not exist
        case .Macintosh:    return "Apple - Macintosh"

        // Unknown/Default
        case .C64:          return "Commodore - C64"
        case .DOS:          return "DOS"
        case .DS:           return "Nintendo - Nintendo DS"
        case .EP128:        return "Enterpise-128"
        case .MAME:         return "MAME"
        case .MegaDuck:     return "Welback Holdings - Mega Duck"
        case .Music:        return "Music"
        case .PalmOS:       return "Palm - PalmOS"
        case .RetroArch:    return "Retroarch"
        case .Supervision:  return "Watara - Supervision"
        case .TIC80:        return "TIC-80"
        case .Unknown:      return "Unknown"
        case .Wii:          return "Nintendo - Wii"
        case .ZXSpectrum:   return "Sinclair - ZX Spectrum"
        case ._3DS:         return "Nintendo - Nintendo 3DS"
        }
    }
}
