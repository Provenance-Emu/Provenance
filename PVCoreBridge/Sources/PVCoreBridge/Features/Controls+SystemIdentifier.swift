//
//  Controls+SystemIdentifier.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

import PVSystems

public extension SystemIdentifier {
    var controllerType: any EmulatorCoreButton.Type {
        switch self {
        case ._3DO: return PV3DOButton.self
        case ._3DS: return PV3DSButton.self
        case .AppleII: return PVDOSButton.self  // TODO: Add me
        case .Atari2600: return PV2600Button.self
        case .Atari5200: return PV5200Button.self
        case .Atari7800: return PV7800Button.self
        case .Atari8bit: return PVA8Button.self
        case .AtariJaguar: return PVJaguarButton.self
        case .AtariJaguarCD: return PVJaguarButton.self
        case .AtariST: return PVA8Button.self   // TODO: Add me
        case .C64: return PVDOSButton.self   // TODO: Add me
        case .CDi: return PVDOSButton.self                          // TODO: Add me
        case .CPS1, .CPS2, .CPS3: return PVMAMEButton.self   // TODO: Add me
        case .ColecoVision: return PVColecoVisionButton.self
        case .DOS: return PVDOSButton.self
        case .DOOM: return PVDOSButton.self
        case .Dreamcast: return PVDreamcastButton.self
        case .DS: return PVDSButton.self
        case .EP128: return PVEP128Button.self
        case .FDS: return PVNESButton.self
        case .GameCube: return PVGCButton.self
        case .GameGear: return PVGenesisButton.self // TODO: Add me
        case .GB: return PVGBButton.self
        case .GBA: return PVGBAButton.self
        case .GBC: return PVGBButton.self
        case .Genesis: return PVGenesisButton.self
        case .Intellivision: return PVIntellivisionButton.self
        case .Lynx: return PVLynxButton.self
        case .Macintosh: return PVDOSButton.self    // TODO: Add me
        case .MAME: return PVMAMEButton.self
        case .MasterSystem: return PVMasterSystemButton.self
        case .MegaDuck: return PVGBButton.self  // TODO: Add me
        case .MSX: return PVMSXButton.self
        case .MSX2: return PVMSXButton.self
        case .Music: return PVNESButton.self
        case .N64: return PVN64Button.self
        case .NeoGeo: return PVNeoGeoButton.self
        case .NES: return PVNESButton.self
        case .NGP: return PVNGPButton.self
        case .NGPC: return PVNGPButton.self
        case .Odyssey2: return PVOdyssey2Button.self
        case .PalmOS: return PVDOSButton.self
        case .PCE: return PVPCEButton.self
        case .PCECD: return PVPCECDButton.self
        case .PCFX: return PVPCFXButton.self
        case .PokemonMini: return PVPMButton.self
        case .PS2: return PVPS2Button.self
        case .PS3: return PVPS2Button.self
        case .PSP: return PVPSPButton.self
        case .PSX: return PVPSXButton.self
        case .Quake: return PVDOSButton.self  // TODO: Add me
        case .Quake2: return PVDOSButton.self // TODO: Add me
        case .Saturn: return PVSaturnButton.self
        case .Sega32X: return PVSega32XButton.self
        case .SegaCD: return PVGenesisButton.self
        case .SG1000: return PVSG1000Button.self
        case .SGFX: return PVPCFXButton.self    // TODO: Add me
        case .SNES: return PVSNESButton.self
        case .Supervision: return PVSupervisionButton.self
        case .TIC80: return PVDOSButton.self // TODO: Add me
        case .Vectrex: return PVVectrexButton.self
        case .VirtualBoy: return PVVBButton.self
        case .Wii: return PVWiiMoteButton.self
        case .WonderSwan: return PVWSButton.self
        case .WonderSwanColor: return PVWSButton.self
        case .ZXSpectrum: return PVDOSButton.self // TODO: Add me
        case .Unknown: return PVPSXButton.self  // TODO: Add me
        case .Wolf3D: return PVDSButton.self    // TODO: Add me
        case .RetroArch: return PVPSXButton.self // TODO: Add me
//        default: return PVRetroArchButton.self
        }

    }
}
