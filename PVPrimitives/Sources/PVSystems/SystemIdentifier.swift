//
//  SystemIdentifier.swift
//
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation

public enum SystemIdentifier: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
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
    case C64 = "com.provenance.c64"
    case ColecoVision = "com.provenance.colecovision"
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
    case NeoGeo = "com.provenance.neogeo"
    case NES = "com.provenance.nes"
    case NGP = "com.provenance.ngp"
    case NGPC = "com.provenance.ngpc"
    case Odyssey2 = "com.provenance.odyssey2"
    case PalmOS = "com.provenance.palmos"
    case PCE = "com.provenance.pce"
    case PCECD = "com.provenance.pcecd"
    case PCFX = "com.provenance.pcfx"
    case PokemonMini = "com.provenance.pokemonmini"
    case PS2 = "com.provenance.ps2"
    case PS3 = "com.provenance.ps3"
    case PSP = "com.provenance.psp"
    case PSX = "com.provenance.psx"
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
    case WonderSwan = "com.provenance.ws"
    case WonderSwanColor = "com.provenance.wsc"
    case ZXSpectrum = "com.provenance.zxspectrum"

    case Unknown

    public
    var isBeta: Bool {
        switch self {

        case ._3DO:
            true
        case ._3DS:
            true
        case .AppleII:
            true
        case .Atari2600:
            false
        case .Atari5200:
            false
        case .Atari7800:
            false
        case .Atari8bit:
            true
        case .AtariJaguar:
            false
        case .AtariJaguarCD:
            true
        case .AtariST:
            true
        case .C64:
            true
        case .ColecoVision:
            false
        case .DOS:
            true
        case .Dreamcast:
            true
        case .DS:
            true
        case .EP128:
            true
        case .FDS:
            false
        case .GameCube:
            true
        case .GameGear:
            false
        case .GB:
            false
        case .GBA:
            false
        case .GBC:
            false
        case .Genesis:
            false
        case .Intellivision:
            false
        case .Lynx:
            false
        case .Macintosh:
            true
        case .MAME:
            true
        case .MasterSystem:
            false
        case .MegaDuck:
            true
        case .MSX:
            true
        case .MSX2:
            true
        case .Music:
            true
        case .N64:
            false
        case .NeoGeo:
            false
        case .NES:
            false
        case .NGP:
            false
        case .NGPC:
            false
        case .Odyssey2:
            false
        case .PalmOS:
            true
        case .PCE:
            false
        case .PCECD:
            false
        case .PCFX:
            false
        case .PokemonMini:
            false
        case .PS2:
            true
        case .PS3:
            true
        case .PSP:
            false
        case .PSX:
            false
        case .Saturn:
            false
        case .Sega32X:
            false
        case .SegaCD:
            false
        case .SG1000:
            false
        case .SGFX:
            false
        case .SNES:
            false
        case .Supervision:
            false
        case .TIC80:
            true
        case .Vectrex:
            false
        case .VirtualBoy:
            false
        case .Wii:
            true
        case .WonderSwan:
            false
        case .WonderSwanColor:
            false
        case .ZXSpectrum:
            true
        case .Unknown:
            true
        case .RetroArch:
            false
        }
    }

    public
    var offset: UInt64 {
        switch self {
        case .SNES: return 16
        case .NES: return 16
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
}
