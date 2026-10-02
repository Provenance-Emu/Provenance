// SystemIdentifier+RetroAchievements.swift
// PVSystems
//
// Maps a Provenance system to its RetroAchievements console ID — the same
// numbering rcheevos uses for `RC_CONSOLE_*` in `rc_consoles.h`. Passing the
// console explicitly to rcheevos' hasher applies that console's rules (SNES
// copier-header strip, iNES header strip, N64 byte-order normalisation, CD
// boot-file hashing) instead of guessing the console from the file extension.

import Foundation

public extension SystemIdentifier {

    /// `RC_CONSOLE_ARCADE`: RetroAchievements hashes arcade sets by file name.
    static let retroAchievementsArcadeConsoleID: UInt32 = 27

    /// `RC_CONSOLE_MS_DOS`: RetroAchievements hashes the `.zip` itself.
    static let retroAchievementsMSDOSConsoleID: UInt32 = 26

    /// RetroAchievements console ID (`RC_CONSOLE_*`), or `nil` when
    /// RetroAchievements has no console for this system.
    var retroAchievementsConsoleID: UInt32? {
        switch self {
        case .Genesis: return 1
        case .N64: return 2
        case .SNES: return 3
        case .GB: return 4
        case .GBA: return 5
        case .GBC: return 6
        case .NES: return 7
        // RetroAchievements files SuperGrafx titles under PC Engine.
        case .PCE, .SGFX: return 8
        case .SegaCD: return 9
        case .Sega32X: return 10
        case .MasterSystem: return 11
        case .PSX: return 12
        case .Lynx: return 13
        case .NGP, .NGPC: return 14
        case .GameGear: return 15
        case .GameCube: return 16
        case .AtariJaguar: return 17
        case .DS: return 18
        case .Wii: return 19
        case .PS2: return 21
        case .Odyssey2: return 23
        case .PokemonMini: return 24
        case .Atari2600: return 25
        case .DOS: return Self.retroAchievementsMSDOSConsoleID
        // Provenance's Neo Geo system is the MVS/AES arcade board (FBNeo romsets).
        case .MAME, .CPS1, .CPS2, .CPS3, .NeoGeo, .NAOMI, .NAOMI2, .Atomiswave:
            return Self.retroAchievementsArcadeConsoleID
        case .VirtualBoy: return 28
        case .MSX, .MSX2: return 29
        case .C64: return 30
        case .SG1000: return 33
        case .AtariST: return 36
        case .AppleII: return 38
        case .Saturn: return 39
        case .Dreamcast: return 40
        case .PSP: return 41
        case .CDi: return 42
        case ._3DO: return 43
        case .ColecoVision: return 44
        case .Intellivision: return 45
        case .Vectrex: return 46
        case .PC98: return 48
        case .PCFX: return 49
        case .Atari5200: return 50
        case .Atari7800: return 51
        case .WonderSwan, .WonderSwanColor: return 53
        case .NeoGeoCD: return 56
        case .ZXSpectrum: return 59
        case ._3DS: return 62
        case .Supervision: return 63
        case .TIC80: return 65
        case .MegaDuck: return 69
        case .PCECD: return 76
        case .AtariJaguarCD: return 77
        case .FDS: return 81
        case .Atari8bit, .DOOM, .EP128, .Macintosh, .Music, .PalmOS, .PS3,
             .Quake, .Quake2, .RetroArch, .Unknown, .Wolf3D:
            return nil
        }
    }

    /// `true` when RetroAchievements identifies this system's games from the
    /// archive file itself (arcade sets by name, MS-DOS by zip contents), so a
    /// `.zip` must be hashed as-is rather than the ROM extracted from it.
    var retroAchievementsHashesArchiveDirectly: Bool {
        switch retroAchievementsConsoleID {
        case Self.retroAchievementsArcadeConsoleID, Self.retroAchievementsMSDOSConsoleID:
            return true
        default:
            return false
        }
    }
}
