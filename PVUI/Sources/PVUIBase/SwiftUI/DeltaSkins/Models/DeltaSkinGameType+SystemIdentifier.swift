import PVPrimitives
import SkinKitCore

/// `SystemIdentifier` ↔ `DeltaSkinGameType`. The game type lives in SkinKitCore, which can't see
/// PVSystems, so the mapping stays in the app.
extension DeltaSkinGameType {
    // MARK: - SystemIdentifier Mapping

    public init?(systemIdentifier: SystemIdentifier) {
        switch systemIdentifier {
        case .GB: self = .gb
        case .GBC: self = .gbc
        case .GBA: self = .gba
        case .FDS, .NES: self = .nes
        case .SNES: self = .snes
        case .N64: self = .n64
        case .DS: self = .nds
        case .Genesis: self = .genesis
        case .GameGear: self = .gamegear
        case .MasterSystem: self = .masterSystem
        case .SG1000: self = .sg1000
        case .Sega32X: self = .sega32X
        case .SegaCD: self = .segaCD
        case .Saturn: self = .saturn
        case .VirtualBoy: self = .virtualBoy
        case .PSX, .PS2, .PS3: self = .psx
        case .PSP: self = .psp
        case ._3DS: self = .threeDS
        case .PokemonMini: self = .pokemonMini
        case .Dreamcast, .NAOMI, .Atomiswave, .NAOMI2: self = .dreamcast
        case .PCE: self = .pce
        case .PCECD: self = .pcecd
        case .PCFX: self = .pcfx
        case .SGFX: self = .sgfx
        case .Vectrex: self = .vectrex
        case .Atari2600: self = .atari2600
        case .Atari5200: self = .atari5200
        case .Atari7800: self = .atari7800
        // Jaguar CD is a peripheral on a Jaguar — identical controller (including
        // the numeric keypad), so it reuses Jaguar skins rather than requiring a
        // separate `jaguarcd` skin that essentially no author ships. Same reason
        // NeoGeo CD maps to `.neogeo` below. The `.jaguarcd` case still exists and
        // is reachable by explicit identifier for anyone who does author one.
        case .AtariJaguar, .AtariJaguarCD: self = .jaguar
        case .Lynx: self = .lynx
        case .Atari8bit: self = .atari8bit
        case .AtariST: self = .atarist
        case .NeoGeo, .NeoGeoCD: self = .neogeo
        case .NGP: self = .ngp
        case .NGPC: self = .ngpc
        case .WonderSwan: self = .wonderswan
        case .WonderSwanColor: self = .wonderswancolor
        case .GameCube: self = .gamecube
        case .Wii: self = .wii
        case ._3DO: self = ._3do
        case .AppleII: self = .appleII
        case .C64: self = .c64
        case .CDi: self = .cdi
        case .ColecoVision: self = .colecovision
        case .CPS1: self = .cps1
        case .CPS2: self = .cps2
        case .CPS3: self = .cps3
        case .DOOM: self = .doom
        case .DOS: self = .dos
        case .EP128: self = .ep128
        case .Intellivision: self = .intellivision
        case .Macintosh: self = .macintosh
        case .MAME: self = .mame
        case .MegaDuck: self = .megaduck
        case .MSX: self = .msx
        case .MSX2: self = .msx2
        case .Music: self = .music
        case .Odyssey2: self = .odyssey2
        case .PalmOS: self = .palmos
        case .PC98: self = .pc98
        case .Quake: self = .quake
        case .Quake2: self = .quake2
        case .RetroArch: self = .retroarch
        case .Supervision: self = .supervision
        case .TIC80: self = .tic80
        case .Wolf3D: self = .wolf3d
        case .ZXSpectrum: self = .zxspectrum
        default : return nil
        }
    }

    public var systemIdentifier: SystemIdentifier? {
        switch self {
        case .gb: return .GB
        case .gbc: return .GBC
        case .gba: return .GBA
        case .nes: return .NES
        case .snes: return .SNES
        case .n64: return .N64
        case .nds: return .DS
        case .genesis: return .Genesis
        case .gamegear: return .GameGear
        case .masterSystem: return .MasterSystem
        case .sg1000: return .SG1000
        case .sega32X: return .Sega32X
        case .segaCD: return .SegaCD
        case .saturn: return .Saturn
        case .virtualBoy: return .VirtualBoy
        case .psx: return .PSX
        case .psp: return .PSP
        case .threeDS: return ._3DS
        case .pokemonMini: return .PokemonMini
        case .dreamcast: return .Dreamcast
        case .pce: return .PCE
        case .pcecd: return .PCECD
        case .pcfx: return .PCFX
        case .sgfx: return .SGFX
        case .vectrex: return .Vectrex
        case .atari2600: return .Atari2600
        case .atari5200: return .Atari5200
        case .atari7800: return .Atari7800
        case .jaguar: return .AtariJaguar
        case .jaguarcd: return .AtariJaguarCD
        case .lynx: return .Lynx
        case .atari8bit: return .Atari8bit
        case .atarist: return .AtariST
        case .neogeo: return .NeoGeo
        case .ngp: return .NGP
        case .ngpc: return .NGPC
        case .wonderswan: return .WonderSwan
        case .wonderswancolor: return .WonderSwanColor
        case .gamecube: return .GameCube
        case .wii: return .Wii
        case ._3do: return ._3DO
        case .appleII: return .AppleII
        case .c64: return .C64
        case .cdi: return .CDi
        case .colecovision: return .ColecoVision
        case .cps1: return .CPS1
        case .cps2: return .CPS2
        case .cps3: return .CPS3
        case .doom: return .DOOM
        case .dos: return .DOS
        case .ep128: return .EP128
        case .intellivision: return .Intellivision
        case .macintosh: return .Macintosh
        case .mame: return .MAME
        case .megaduck: return .MegaDuck
        case .msx: return .MSX
        case .msx2: return .MSX2
        case .music: return .Music
        case .odyssey2: return .Odyssey2
        case .palmos: return .PalmOS
        case .pc98: return .PC98
        case .quake: return .Quake
        case .quake2: return .Quake2
        case .retroarch: return .RetroArch
        case .supervision: return .Supervision
        case .tic80: return .TIC80
        case .wolf3d: return .Wolf3D
        case .zxspectrum: return .ZXSpectrum
        }
    }
}

extension VirtualKeyboardVariant {
    /// Maps this skin-level variant identifier to the corresponding keyboard layout.
    public func toLayout() -> VirtualKeyboardLayout {
        if let layout = VirtualKeyboardLayout(rawValue: rawValue) {
            return layout
        }
        return .full
    }
}
