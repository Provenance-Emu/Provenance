//
//  Controls+SystemResponderClient.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

import PVPrimitives
import PVSystems

public extension SystemIdentifier {
    public var responderClientType: any ResponderClient.Type {
        switch self {
        case .VirtualBoy:
            return PVVirtualBoySystemResponderClient.self
        case .GB, .GBC:
            return PVGBSystemResponderClient.self
        case .GBA:
            return PVGBASystemResponderClient.self
        case .Genesis, .SegaCD, .Sega32X:
            return PVGenesisSystemResponderClient.self
        case .MasterSystem, .GameGear:
            return PVMasterSystemSystemResponderClient.self
        case .NES:
            return PVNESSystemResponderClient.self
        case .SNES:
            return PVSNESSystemResponderClient.self
        case .N64:
            return PVN64SystemResponderClient.self
        case .PSX:
            return PVPSXSystemResponderClient.self
        case .Saturn:
            return PVSaturnSystemResponderClient.self
        case .PCE, .PCECD:
            return PVPCESystemResponderClient.self
        case .PCFX, .SGFX:
            return PVPCFXSystemResponderClient.self
        case .NGP, .NGPC:
            return PVNeoGeoPocketSystemResponderClient.self
        case .WonderSwan, .WonderSwanColor:
            return PVWonderSwanSystemResponderClient.self
        case .Lynx:
            return PVLynxSystemResponderClient.self
        case .Atari2600:
            return PV2600SystemResponderClient.self
        case .Atari5200:
            return PV5200SystemResponderClient.self
        case .Atari7800:
            return PV7800SystemResponderClient.self
        case .Atari8bit:
            return PVA8SystemResponderClient.self
        case .AtariJaguar, .AtariJaguarCD:
            return PVJaguarSystemResponderClient.self
        case .ColecoVision:
            return PVColecoVisionSystemResponderClient.self
        case .Intellivision:
            return PVIntellivisionSystemResponderClient.self
        case .NeoGeo:
            return PVNeoGeoSystemResponderClient.self
        case .Odyssey2:
            return PVOdyssey2SystemResponderClient.self
        case .PokemonMini:
            return PVPokeMiniSystemResponderClient.self
        case .SG1000:
            return PVSG1000SystemResponderClient.self
        case .Supervision:
            return PVSupervisionSystemResponderClient.self
        case .Vectrex:
            return PVVectrexSystemResponderClient.self
        case .DS:
            return PVDSSystemResponderClient.self
        case .PSP:
            return PVPSPSystemResponderClient.self
        case .Dreamcast:
            return PVDreamcastSystemResponderClient.self
        case .Wii:
            return PVWiiSystemResponderClient.self
        case .PS2, .PS3:
            return PVPS2SystemResponderClient.self
        case .GameCube:
            return PVGameCubeSystemResponderClient.self
        case ._3DO:
            return PVRetroArchCoreResponderClient.self
        case ._3DS:
            return PV3DSSystemResponderClient.self
        case .AppleII:
            return PVRetroArchCoreResponderClient.self
        case .AtariST:
            return PVRetroArchCoreResponderClient.self
        case .C64:
            return PVRetroArchCoreResponderClient.self
        case .CDi:
            return PVRetroArchCoreResponderClient.self
        case .CPS1:
            return PVRetroArchCoreResponderClient.self
        case .CPS2:
            return PVRetroArchCoreResponderClient.self
        case .CPS3:
            return PVRetroArchCoreResponderClient.self
        case .DOOM:
            return PVRetroArchCoreResponderClient.self
        case .DOS:
            return PVRetroArchCoreResponderClient.self
        case .EP128:
            return PVEP128SystemResponderClient.self
        case .FDS:
            return PVNESSystemResponderClient.self
        case .Macintosh:
            return PVRetroArchCoreResponderClient.self
        case .MAME:
            return PVMAMESystemResponderClient.self
        case .MegaDuck:
            return PVGBSystemResponderClient.self
        case .MSX:
            return PVMSXSystemResponderClient.self
        case .MSX2:
            return PVMSXSystemResponderClient.self
        case .Music:
            return PVNESSystemResponderClient.self
        case .PalmOS:
            return PVRetroArchCoreResponderClient.self
        case .Quake:
            return PVDOSSystemResponderClient.self
        case .Quake2:
            return PVDOSSystemResponderClient.self
        case .RetroArch:
            return PVRetroArchCoreResponderClient.self
        case .TIC80:
            return PVRetroArchCoreResponderClient.self
        case .Wolf3D:
            return PVDOSSystemResponderClient.self
        case .ZXSpectrum:
            return PVEP128SystemResponderClient.self
        case .Unknown:
            return PVRetroArchCoreResponderClient.self
            // Add fallbacks for systems that don't have specific responder clients
        @unknown default:
            return PVRetroArchCoreResponderClient.self // ResponderClient.self
        }
    }

    /// Helper method to check if a core conforms to the system's responder client type
    func conformsToResponderClient(_ core: Any) -> Bool {
        let mirror = Mirror(reflecting: core)
        let conformances = mirror.description

        // Get the name of the responder client type
        let responderName = String(describing: responderClientType)

        // Check if the core conforms to the responder client type
        return conformances.contains(responderName)
    }
}
