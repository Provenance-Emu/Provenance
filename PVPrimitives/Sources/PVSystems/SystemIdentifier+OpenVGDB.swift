import Foundation

public extension SystemIdentifier {
    /// The corresponding system ID in the OpenVGDB database
    var openVGDBID: Int {
        switch self {
        case ._3DO: return 1
        case .CPS1: return 2
        case .CPS2: return 2
        case .CPS3: return 2
        case .MAME: return 2
        case .Atari2600: return 3
        case .Atari5200: return 4
        case .Atari7800: return 5
        case .Lynx: return 6
        case .AtariJaguar: return 7
        case .AtariJaguarCD: return 8
        case .WonderSwan: return 9
        case .WonderSwanColor: return 10
        case .ColecoVision: return 11
        case .Vectrex: return 12
        case .Intellivision: return 13
        case .PCE: return 14
        case .PCECD: return 15
        case .PCFX: return 16
        case .SGFX: return 17
        case .FDS: return 18
        case .GB: return 19
        case .GBA: return 20
        case .GBC: return 21
        case .GameCube: return 22
        case .N64: return 23
        case .DS: return 24
        case .NES: return 25
        case .SNES: return 26
        case .VirtualBoy: return 27
        case .Wii: return 28
        case .Sega32X: return 29
        case .GameGear: return 30
        case .MasterSystem: return 31
        case .SegaCD: return 32
        case .Genesis: return 33
        case .Saturn: return 34
        case .SG1000: return 35
        case .NGP: return 36
        case .NGPC: return 37
        case .PSX: return 38
        case .PSP: return 39
        case .Odyssey2: return 40
        case .C64: return 41
        case .MSX: return 42
        case .MSX2: return 43
        case .RetroArch: return 45
        case ._3DS: return 46
        case .AppleII: return 47
        default: return -1
        }
    }

    /// OpenEmu system identifier string
    var openEmuIdentifier: String {
        switch self {
        case ._3DO: return "openemu.system.3do"
        case .MAME: return "openemu.system.arcade"
        case .Atari2600: return "openemu.system.2600"
        case .Atari5200: return "openemu.system.5200"
        case .Atari7800: return "openemu.system.7800"
        case .Lynx: return "openemu.system.lynx"
        case .AtariJaguar: return "openemu.system.jaguar"
        case .AtariJaguarCD: return "openemu.system.jaguarcd"
        case .WonderSwan, .WonderSwanColor: return "openemu.system.ws"
        case .ColecoVision: return "openemu.system.colecovision"
        case .Vectrex: return "openemu.system.vectrex"
        case .Intellivision: return "openemu.system.intellivision"
        case .PCE, .SGFX: return "openemu.system.pce"
        case .PCECD: return "openemu.system.pcecd"
        case .PCFX: return "openemu.system.pcfx"
        case .FDS: return "openemu.system.fds"
        case .GB, .GBC: return "openemu.system.gb"
        case .GBA: return "openemu.system.gba"
        case .GameCube: return "openemu.system.gc"
        case .N64: return "openemu.system.n64"
        case .DS: return "openemu.system.nds"
        case .NES: return "openemu.system.nes"
        case .SNES: return "openemu.system.snes"
        case .VirtualBoy: return "openemu.system.vb"
        case .Wii: return "openemu.system.wii"
        case .Sega32X: return "openemu.system.32x"
        case .GameGear: return "openemu.system.gg"
        case .MasterSystem: return "openemu.system.sms"
        case .SegaCD: return "openemu.system.scd"
        case .Genesis: return "openemu.system.sg"
        case .Saturn: return "openemu.system.saturn"
        case .SG1000: return "openemu.system.sg1000"
        case .NGP, .NGPC: return "openemu.system.ngp"
        case .PSX: return "openemu.system.psx"
        case .PSP: return "openemu.system.psp"
        case .Odyssey2: return "openemu.system.odyssey2"
        case .C64: return "openemu.system.c64"
        case .MSX, .MSX2: return "openemu.system.msx"
        case .RetroArch: return "openemu.system.retroarch"
        case ._3DS: return "openemu.system.3ds"
        case .AppleII: return "openemu.system.appleii"
        case .CDi: return "openemu.system.cdi"
        default: return "unknown"
        }
    }

    /// Initialize from OpenEmu system identifier
    init?(openEmuIdentifier: String) {
        switch openEmuIdentifier {
        case "openemu.system.3do": self = ._3DO
        case "openemu.system.arcade": self = .MAME
        case "openemu.system.2600": self = .Atari2600
        case "openemu.system.5200": self = .Atari5200
        case "openemu.system.7800": self = .Atari7800
        case "openemu.system.lynx": self = .Lynx
        case "openemu.system.jaguar": self = .AtariJaguar
        case "openemu.system.jaguarcd": self = .AtariJaguarCD
        case "openemu.system.ws": self = .WonderSwan // Note: Both WS and WSC use this
        case "openemu.system.colecovision": self = .ColecoVision
        case "openemu.system.vectrex": self = .Vectrex
        case "openemu.system.intellivision": self = .Intellivision
        case "openemu.system.pce": self = .PCE // Note: Also used for SuperGrafx
        case "openemu.system.pcecd": self = .PCECD
        case "openemu.system.pcfx": self = .PCFX
        case "openemu.system.fds": self = .FDS
        case "openemu.system.gb": self = .GB // Note: Also used for GBC
        case "openemu.system.gba": self = .GBA
        case "openemu.system.gc": self = .GameCube
        case "openemu.system.n64": self = .N64
        case "openemu.system.n64dd": self = .N64
        case "openemu.system.nds": self = .DS
        case "openemu.system.nes": self = .NES
        case "openemu.system.snes": self = .SNES
        case "openemu.system.vb": self = .VirtualBoy
        case "openemu.system.wii": self = .Wii
        case "openemu.system.32x": self = .Sega32X
        case "openemu.system.gg": self = .GameGear
        case "openemu.system.sms": self = .MasterSystem
        case "openemu.system.scd": self = .SegaCD
        case "openemu.system.sg": self = .Genesis
        case "openemu.system.saturn": self = .Saturn
        case "openemu.system.sg1000": self = .SG1000
        case "openemu.system.ngp": self = .NGP // Note: Also used for NGPC
        case "openemu.system.psx": self = .PSX
        case "openemu.system.psp": self = .PSP
        case "openemu.system.odyssey2": self = .Odyssey2
        case "openemu.system.c64": self = .C64
        case "openemu.system.msx": self = .MSX // Note: Also used for MSX2
        case "openemu.system.retroarch": self = .RetroArch
        case "openemu.system.3ds": self = ._3DS
        case "openemu.system.appleii": self = .AppleII
        case "openemu.system.cdi": self = .CDi
        default: return nil
        }
    }

    static func fromOpenVGDBID(_ openVGDBID: Int) -> SystemIdentifier? {
        switch openVGDBID {
        case 1: return ._3DO
        case 2: return .MAME
        case 3: return .Atari2600
        case 4: return .Atari5200
        case 5: return .Atari7800
        case 6: return .Lynx
        case 7: return .AtariJaguar
        case 8: return .AtariJaguarCD
        case 9: return .WonderSwan
        case 10: return .WonderSwanColor
        case 11: return .ColecoVision
        case 12: return .Vectrex
        case 13: return .Intellivision
        case 14: return .PCE
        case 15: return .PCECD
        case 16: return .PCFX
        case 17: return .SGFX
        case 18: return .FDS
        case 19: return .GB
        case 20: return .GBA
        case 21: return .GBC
        case 22: return .GameCube
        case 23: return .N64
        case 24: return .DS
        case 25: return .NES
        case 26: return .SNES
        case 27: return .VirtualBoy
        case 28: return .Wii
        case 29: return .Sega32X
        case 30: return .GameGear
        case 31: return .MasterSystem
        case 32: return .SegaCD
        case 33: return .Genesis
        case 34: return .Saturn
        case 35: return .SG1000
        case 36: return .NGP
        case 37: return .NGPC
        case 38: return .PSX
        case 39: return .PSP
        case 40: return .Odyssey2
        case 41: return .C64
        case 42: return .MSX
        case 43: return .MSX2
//        case 44: return .pc98
        case 45: return .RetroArch
        case 46: return ._3DS
        case 47: return .AppleII
        default: return nil
        }
    }
}
