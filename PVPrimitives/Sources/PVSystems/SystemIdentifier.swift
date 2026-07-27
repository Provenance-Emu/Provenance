//
//  SystemIdentifier.swift
//
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation

public enum SystemIdentifier: String, CaseIterable, Codable, Sendable, Equatable, Hashable, Comparable {
    case _3DO = "com.provenance.3DO"
    case _3DS = "com.provenance.3ds"
    case AppleII = "com.provenance.appleII"
    case Atari2600 = "com.provenance.2600"
    case Atari5200 = "com.provenance.5200"
    case Atari7800 = "com.provenance.7800"
    case Atari8bit = "com.provenance.atari8bit"
    case AtariJaguar = "com.provenance.jaguar"
    case AtariJaguarCD = "com.provenance.jaguarcd"
    case AtariST = "com.provenance.atarist"
    // swiftlint:disable:next identifier_name
    case Atomiswave = "com.provenance.atomiswave"
    case C64 = "com.provenance.c64"
    case CDi = "com.provenance.cdi"
    case ColecoVision = "com.provenance.colecovision"
    case CPS1 = "com.provenance.cps1"
    case CPS2 = "com.provenance.cps2"
    case CPS3 = "com.provenance.cps3"
    case DOOM = "com.provenance.doom"
    case DOS = "com.provenance.dos"
    case Dreamcast = "com.provenance.dreamcast"
    case DS = "com.provenance.ds"
    case EP128 = "com.provenance.ep128"
    case FDS = "com.provenance.fds"
    case GameCube = "com.provenance.gamecube"
    case GameGear = "com.provenance.gamegear"
    case GB = "com.provenance.gb"
    case GBA = "com.provenance.gba"
    case GBC = "com.provenance.gbc"
    case Genesis = "com.provenance.genesis"
    case Intellivision = "com.provenance.intellivision"
    case Lynx = "com.provenance.lynx"
    case Macintosh = "com.provenance.macintosh"
    case MAME = "com.provenance.mame"
    case MasterSystem = "com.provenance.mastersystem"
    case MegaDuck = "com.provenance.megaduck"
    case MSX = "com.provenance.msx"
    case MSX2 = "com.provenance.msx2"
    case Music = "com.provenance.music"
    case N64 = "com.provenance.n64"
    case NAOMI = "com.provenance.naomi"
    case NAOMI2 = "com.provenance.naomi2"
    case NeoGeo = "com.provenance.neogeo"
    case NeoGeoCD = "com.provenance.neogeocd"
    case NES = "com.provenance.nes"
    case NGP = "com.provenance.ngp"
    case NGPC = "com.provenance.ngpc"
    case Odyssey2 = "com.provenance.odyssey2"
    case PalmOS = "com.provenance.palmos"
    case PC98 = "com.provenance.pc98"
    case PCE = "com.provenance.pce"
    case PCECD = "com.provenance.pcecd"
    case PCFX = "com.provenance.pcfx"
    case PokemonMini = "com.provenance.pokemonmini"
    case PS2 = "com.provenance.ps2"
    case PS3 = "com.provenance.ps3"
    case PSP = "com.provenance.psp"
    case PSX = "com.provenance.psx"
    case Quake = "com.provenance.quake"
    case Quake2 = "com.provenance.quake2"
    case RetroArch = "com.provenance.retroarch"
    case Saturn = "com.provenance.saturn"
    case Sega32X = "com.provenance.32X"
    case SegaCD = "com.provenance.segacd"
    case SG1000 = "com.provenance.sg1000"
    case SGFX = "com.provenance.sgfx"
    case SNES = "com.provenance.snes"
    case Supervision = "com.provenance.supervision"
    case TIC80 = "com.provenance.tic80"
    case Vectrex = "com.provenance.vectrex"
    case VirtualBoy = "com.provenance.vb"
    case Wii = "com.provenance.wii"
    case Wolf3D = "com.provenance.wolf3d"
    case WonderSwan = "com.provenance.ws"
    case WonderSwanColor = "com.provenance.wsc"
    case ZXSpectrum = "com.provenance.zxspectrum"

    case Unknown

    public
    var isBeta: Bool {
        switch self {
            
        case ._3DO: false
        case ._3DS: false
        case .AppleII: true
        case .Atari2600: false
        case .Atari5200: false
        case .Atari7800: false
        case .Atari8bit: true
        case .AtariJaguar: false
        case .AtariJaguarCD: true
        case .AtariST: true
        case .Atomiswave: true
        case .C64: true
        case .CDi: true
        case .CPS1, .CPS2, .CPS3: true
        case .ColecoVision: false
        case .DOS: false
        case .DOOM: false
        case .Dreamcast: true
        case .DS: false
        case .EP128: true
        case .FDS: false
        case .GameCube: true
        case .GameGear: false
        case .GB: false
        case .GBA: false
        case .GBC: false
        case .Genesis: false
        case .Intellivision: false
        case .Lynx: false
        case .Macintosh: true
        case .MAME: false
        case .MasterSystem: false
        case .MegaDuck: true
        case .MSX: true
        case .MSX2: true
        case .Music: true
        case .N64: false
        case .NAOMI: true
        case .NAOMI2: true
        case .NeoGeo: false
        case .NeoGeoCD: false
        case .NES: false
        case .NGP: false
        case .NGPC: false
        case .Odyssey2: false
        case .PalmOS: true
        case .PC98: true
        case .PCE: false
        case .PCECD: false
        case .PCFX: false
        case .PokemonMini: false
        case .PS2: true
        case .PS3: true
        case .PSP: false
        case .PSX: false
        case .Quake: true
        case .Quake2: true
        case .Saturn: false
        case .Sega32X: false
        case .SegaCD: false
        case .SG1000: false
        case .SGFX: false
        case .SNES: false
        case .Supervision: false
        case .TIC80: true
        case .Vectrex: true
        case .VirtualBoy: false
        case .Wii: true
        case .WonderSwan: false
        case .WonderSwanColor: false
        case .ZXSpectrum: true
        case .Unknown: true
        case .Wolf3D: false
        case .RetroArch: false
        }
    }

    /// Offset for ROM header skipping during MD5 calculation.
    /// - Note: SNES uses dynamic detection in GameImporterDatabaseService (512-byte copier header)
    public
    var offset: UInt {
        switch self {
        case .NES: return 16  // iNES header
//        case .Atari7800: return 128
//        case .Lynx: return 64
        default: return 0
        }
    }

    static public var betas: [SystemIdentifier] { allCases.filter(\.isBeta) }

    static public var unsupported: [SystemIdentifier] {[]}
    // MARK: Assistance accessors for properties

    //    var name : String {
    //        return PVEmulatorConfiguration.name(forSystemIdentifier: self)!
    //    }
    //
    //    var shortName : String {
    //        return PVEmulatorConfiguration.shortName(forSystemIdentifier: self)!
    //    }
    //
    //    var controllerLayout : [ControlLayoutEntry] {
    //        return PVEmulatorConfiguration.controllerLayout(forSystemIdentifier: self)!
    //    }
    //
    //    var biosPath : URL {
    //        return PVEmulatorConfiguration.biosPath(forSystemIdentifier: self)
    //    }
    //
    //    var requiresBIOS : Bool {
    //        return PVEmulatorConfiguration.requiresBIOS(forSystemIdentifier: self)
    //    }
    //
    //    var biosEntries : [PVBIOS]? {
    //        return PVEmulatorConfiguration.biosEntries(forSystemIdentifier: self)
    //    }
    //
    //    var fileExtensions : [String] {
    //        return PVEmulatorConfiguration.fileExtensions(forSystemIdentifier: self)!
    //    }

    // TODO: Eventaully wouldl make sense to add batterySavesPath, savesStatePath that
    // are a sub-directory of the current paths. Right now those are just a folder
    // for all games by the game filename - extensions. Even then would be better
    // to use the ROM md5 not the name, since names might have collisions - jm

    /// The manufacturer/company that made the system
    public var manufacturer: String {
        switch self {
        case .Atari2600, .Atari5200, .Atari7800, .AtariJaguar, .AtariJaguarCD, .AtariST, .Atari8bit, .Lynx:
            return "Atari"
        case .NES, .SNES, .N64, .GameCube, .GB, .GBC, .GBA, .VirtualBoy, .PokemonMini, .FDS, .DS, ._3DS, .Wii:
            return "Nintendo"
        case .Genesis, .SegaCD, .MasterSystem, .GameGear, .Saturn, .Dreamcast, .SG1000, .Sega32X, .NAOMI, .NAOMI2:
            return "Sega"
        case .Atomiswave:
            return "Sammy"
        case .PSX, .PSP, .PS2, .PS3:
            return "Sony"
        case .PC98, .PCE, .PCFX, .PCECD, .SGFX:
            return "NEC"
        case .NeoGeo, .NeoGeoCD, .NGP, .NGPC:
            return "SNK"
        case .WonderSwan, .WonderSwanColor:
            return "Bandai"
        case .Vectrex:
            return "GCE"
        case .ColecoVision:
            return "Coleco"
        case .Intellivision:
            return "Mattel"
        case .Odyssey2:
            return "Magnavox"
        case ._3DO:
            return "The 3DO Company"
        case .C64:
            return "Commodore"
        case .AppleII, .Macintosh:
            return "Apple"
        case .MegaDuck:
            return "Welback Holdings"
        case .MSX, .MSX2:
            return "Microsoft"
        case .Supervision:
            return "Watara"
        case .ZXSpectrum:
            return "Sinclair"
        case .DOS:
            return "IBM"
        case .EP128:
            return "Enterprise Systems"
        case .PalmOS:
            return "Palm"
        case .CDi:
            return "Philips"
        case .MAME, .Music, .RetroArch, .TIC80:
            return "Various"
        case .CPS1, .CPS2, .CPS3:
            return "Capcom"
        case .DOOM, .Wolf3D, .Quake, .Quake2:
            return "Id Software"
        case .Unknown:
            return "Unknown"
        }
    }

    /// The name of the system without manufacturer
    public var systemName: String {
        switch self {
        case .Atari2600:     return "2600"
        case .Atari5200:     return "5200"
        case .Atari7800:     return "7800"
        case .AtariJaguar:   return "Jaguar"
        case .AtariJaguarCD: return "Jaguar CD"
        case .AtariST:       return "ST"
        case .Atomiswave:    return "Atomiswave"
        case .Atari8bit:     return "8-bit"
        case .Lynx:          return "Lynx"
        case .CDi:           return "CD-i"
        case .NES:           return "Nintendo Entertainment System"
        case .SNES:          return "Super Nintendo Entertainment System"
        case .N64:           return "Nintendo 64"
        case .NAOMI:         return "NAOMI"
        case .NAOMI2:        return "NAOMI 2"
        case .GameCube:      return "GameCube"
        case .GB:            return "Game Boy"
        case .GBC:           return "Game Boy Color"
        case .GBA:           return "Game Boy Advance"
        case .VirtualBoy:    return "Virtual Boy"
        case .PokemonMini:   return "Pokemon Mini"
        case .FDS:           return "Family Computer Disk System"
        case .Genesis:       return "Mega Drive - Genesis"
        case .SegaCD:        return "Mega-CD - Sega CD"
        case .MasterSystem:  return "Master System - Mark III"
        case .GameGear:      return "Game Gear"
        case .Saturn:        return "Saturn"
        case .Dreamcast:     return "Dreamcast"
        case .SG1000:        return "SG-1000"
        case .PSX:           return "PlayStation"
        case .PSP:           return "PlayStation Portable"
        case .PS2:           return "PlayStation 2"
        case .PS3:           return "PlayStation 3"
        case .PC98:          return "PC-98"
        case .PCE:           return "PC Engine - TurboGrafx 16"
        case .PCFX:          return "PC-FX"
        case .PCECD:         return "PC Engine CD - TurboGrafx-CD"
        case .SGFX:          return "PC Engine SuperGrafx"
        case .NeoGeo:        return "Neo Geo"
        case .NeoGeoCD:      return "Neo Geo CD"
        case .NGP:           return "Neo Geo Pocket"
        case .NGPC:          return "Neo Geo Pocket Color"
        case .WonderSwan:    return "WonderSwan"
        case .WonderSwanColor: return "WonderSwan Color"
        case .Vectrex:       return "Vectrex"
        case .ColecoVision:  return "ColecoVision"
        case .Intellivision: return "Intellivision"
        case .Odyssey2:      return "Odyssey2"
        case ._3DO:          return "3DO"
        case ._3DS:          return "Nintendo 3DS"
        case .AppleII:       return "Apple II"
        case .C64:           return "C64"
        case .DOS:           return "DOS"
        case .DS:            return "Nintendo DS"
        case .EP128:         return "Enterpise-128"
        case .Macintosh:     return "Macintosh"
        case .MAME:          return "MAME"
        case .MegaDuck:      return "Mega Duck"
        case .MSX:           return "MSX"
        case .MSX2:          return "MSX2"
        case .Music:         return "Music"
        case .PalmOS:        return "PalmOS"
        case .RetroArch:     return "Retroarch"
        case .Sega32X:       return "32X"
        case .Supervision:   return "Supervision"
        case .TIC80:         return "TIC-80"
        case .Wii:           return "Wii"
        case .ZXSpectrum:    return "ZX Spectrum"
        case .CPS1:           return "CPS/1"
        case .CPS2:           return "CPS/2"
        case .CPS3:           return "CPS/3"
        case .Quake:         return "Quake 1"
        case .Quake2:        return "Quake 2"
        case .DOOM:           return "Doom"
        case .Wolf3D:         return "Wolfenstein 3D"
        case .Unknown:       return "Unknown"
        }
    }

    /// Full name in the format "Manufacturer - System Name"
    public var fullName: String {
        let mfg = manufacturer
        return mfg.isEmpty ? systemName : "\(mfg) - \(systemName)"
    }

    /// The conventional subdirectory name under `Documents/System/` (or `Caches/System/` on tvOS)
    /// for this system's firmware, assets, and core data files.
    ///
    /// Returns `nil` for systems that need no dedicated system directory.
    ///
    /// ## Thin wrapper behaviour
    /// `PVThinLibretroFrontend._systemSpecificDirectory` returns `<docs>/System/<name>/` when this
    /// is non-nil, or falls back to `BIOSPath` when nil. Returning the wrong name (or nil) means
    /// the libretro core cannot find its system files via `RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY`.
    ///
    /// ## RetroArch conventions
    /// Names follow the wider emulation community convention where possible (e.g. "PSP", "DC", "N64").
    /// The RetroArch full-wrapper (`PVRetroArchCoreCore`) uses `<RetroArch>/system/<name>/` instead,
    /// so its system files live under a separate `RetroArch/` prefix and don't share this table.
    ///
    /// ## Validated thin wrapper support
    /// - **PSP**: `System/PSP/` — flash0/font seeded from bundle by `PVThinLibretroCore`
    /// - **N64**: `System/N64/` — mupen64plus-next RetroArch core; INI files from bundle
    /// - **Dreamcast**: `System/DC/` — Flycast jitless RetroArch; DC BIOS placed by user
    /// - **Atari ST**: `System/AtariST/` — TOS path patched into hatari.cfg at launch
    /// - **GameCube/Wii**: `System/GC/` + `System/Wii/` — Dolphin requires JIT (App Store restricted)
    /// - **PS2**: `System/PS2/` — Play! requires JIT (App Store restricted)
    ///
    /// Example paths: `Documents/System/PSP`, `Documents/System/NDS`, `Documents/System/3DS`
    ///
    /// - Note: Part of Epic #3577 — future UI will let users manage these directories.
    ///   ObjC callers should use `PVSystemDirectoryHelper.systemDirectoryName(forIdentifier:)`
    ///   in `PVCoreBridgeRetro` rather than duplicating this table.
    public var systemDirectoryName: String? {
        switch self {
        case .PSP:           return "PSP"
        case .DS:            return "NDS"
        case ._3DS:          return "3DS"
        case .PS2:           return "PS2"
        // Dreamcast + the Sega arcade boards all run on flycast, which has ONE
        // hardcoded BIOS convention (<system dir>/dc/), so they deliberately
        // share a single system directory. This also means naomi.zip is stored
        // once even though both NAOMI and NAOMI 2 need it.
        case .Dreamcast, .NAOMI, .NAOMI2, .Atomiswave: return "DC"
        case .Saturn:        return "Saturn"
        case .N64:           return "N64"
        case .GameCube:      return "GC"
        case .Wii:           return "Wii"
        case .AtariST:       return "AtariST"
        case .DOS:           return "DOS"
        case .MAME:          return "MAME"
        case .NeoGeo:        return "NeoGeo"
        case .NeoGeoCD:      return "NeoGeoCD"
        case .CDi:           return "CDi"
        case .Macintosh:     return "Mac"
        case .PC98:          return "PC98"
        case .MSX:           return "MSX"
        case .MSX2:          return "MSX"
        case .C64:           return "C64"
        case .EP128:         return "EP128"
        default:             return nil
        }
    }

    /// The subdirectory name a libretro core looks for under the system dir
    /// (`RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY` consumers). This deliberately
    /// differs from ``systemDirectoryName`` for several systems because the
    /// upstream libretro cores hard-code a specific lowercase / branded name.
    ///
    /// Examples: PPSSPP looks in `PPSSPP/`, flycast in `dc/`, dolphin in
    /// `dolphin-emu/`, melonDS in `melonds/`, mupen64plus-next in
    /// `Mupen64Plus-Next/`, FBNeo in `fbneo/`, MAME in `mame*`, hatari in
    /// `hatari/`, VICE in `vice/`.
    ///
    /// Callers that resolve a system dir for a libretro core (thin-wrapper +
    /// full RA wrapper) should prefer this property; user-facing display still
    /// uses ``systemDirectoryName``. Falls back to `nil` for systems with no
    /// libretro core or where the upstream looks in the BIOS root.
    ///
    /// - Note: Part of issue #3576 — paired with the legacy → RA-aligned
    ///   migration utility.
    public var retroArchSystemDirectoryName: String? {
        switch self {
        case .PSP:           return "PPSSPP"            // PPSSPP libretro
        // flycast: Dreamcast boot ROM and the arcade BIOS zips (naomi.zip /
        // awbios.zip) are all read from the core's "dc" subdirectory.
        case .Dreamcast, .NAOMI, .NAOMI2, .Atomiswave: return "dc"
        case .GameCube:      return "dolphin-emu"       // dolphin
        case .Wii:           return "dolphin-emu"       // dolphin
        case .DS:            return "melonds"           // melonDS
        case .N64:           return "Mupen64Plus-Next"  // mupen64plus-next
        case .AtariST:       return "hatari"            // hatari
        case .C64:           return "vice"              // vice_x64sc / vice_x64
        case .MAME:          return "mame"              // MAME (Current)
        case .CPS1:          return "fbneo"             // FinalBurnNeo
        case .CPS2:          return "fbneo"
        case .CPS3:          return "fbneo"
        case .NeoGeo:        return "fbneo"
        case .NeoGeoCD:      return "fbneo"
        case .CDi:           return "same_cdi"          // same_cdi uses bios/ inside
        case ._3DS:          return "citra"             // azahar / citra family
        case .Saturn:        return "Saturn"            // mednafen_saturn / yabasanshiro use same name
        case .PS2:           return "play"              // Play! (when run via libretro)
        // Systems that don't currently have a libretro fork in our matrix or
        // where the core reads from the BIOS dir directly (no subdir).
        default:             return nil
        }
    }

    // Add Comparable implementation
    public static func < (lhs: SystemIdentifier, rhs: SystemIdentifier) -> Bool {
        lhs.fullName < rhs.fullName
    }
}
