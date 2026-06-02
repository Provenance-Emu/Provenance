//
//  Controls+SystemResponderClient.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

import PVPrimitives
import PVSystems

/// ## Keyboard & Mouse capability discovery chain
///
/// Whether a running core supports (or requires) a virtual keyboard / mouse is
/// determined by walking the following chain:
///
/// 1. **`KeyboardResponder` / `MouseResponder` protocols** (`Controls.swift`)
///    Adopted by Obj-C bridge classes.  The bridge sets `gameSupportsKeyboard`,
///    `requiresKeyboard`, `gameSupportsMouse`, and `requiresMouse` based on the
///    currently loaded system/core.
///
/// 2. **`PVEmulatorCore` computed properties** (`PVEmulatorCore.swift`)
///    `supportsVirtualKeyboard`, `requiresVirtualKeyboard`,
///    `supportsVirtualMouse`, and `requiresVirtualMouse` forward to the bridge's
///    protocol conformance (if any), returning `false` as a safe default.
///
/// 3. **PVUI / emulator view controller**
///    Reads the `PVEmulatorCore` properties above and decides whether to show the
///    virtual-keyboard or virtual-mouse overlay button.
///
/// Systems that route through `PVRetroArchCoreResponderClient` (e.g. DOS,
/// AppleII, C64) automatically inherit keyboard support because
/// `PVRetroArchCoreResponderClient` requires conformance to `KeyboardResponder`.
public extension SystemIdentifier {
    public var responderClientType: any ResponderClient.Type {
        switch self {
        case .VirtualBoy:
            return PVVirtualBoySystemResponderClient.self
        case .GB, .GBC:
            return PVGBSystemResponderClient.self
        case .GBA:
            return PVGBASystemResponderClient.self
        case .Sega32X:
            return PVSega32XSystemResponderClient.self
        case .Genesis, .SegaCD:
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
        case .NeoGeo, .NeoGeoCD:
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
        case .Dreamcast, .NAOMI, .NAOMI2, .Atomiswave:
            return PVDreamcastSystemResponderClient.self
        case .Wii:
            return PVWiiSystemResponderClient.self
        case .PS2, .PS3:
            return PVPS2SystemResponderClient.self
        case .GameCube:
            return PVGameCubeSystemResponderClient.self
        case ._3DO:
            return PV3DOSystemResponderClient.self
        case ._3DS:
            return PV3DSSystemResponderClient.self
        case .AppleII:
            return PVRetroArchCoreResponderClient.self
        case .AtariST:
            return PVDOSSystemResponderClient.self
        case .C64:
            return PVRetroArchCoreResponderClient.self
        case .CDi:
            return PVCDiSystemResponderClient.self
        case .CPS1:
            return PVMAMESystemResponderClient.self
        case .CPS2:
            return PVMAMESystemResponderClient.self
        case .CPS3:
            return PVMAMESystemResponderClient.self
        case .DOOM:
            return PVDoomSystemResponderClient.self
        case .DOS:
            return PVDOSSystemResponderClient.self
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
        case .PC98:
            return PVRetroArchCoreResponderClient.self
        case .PalmOS:
            return PVRetroArchCoreResponderClient.self
        case .Quake:
            return PVDOSSystemResponderClient.self
        case .Quake2:
            return PVDOSSystemResponderClient.self
        case .RetroArch:
            return PVRetroArchCoreResponderClient.self
        case .TIC80:
            return PVTIC80SystemResponderClient.self
        case .Wolf3D:
            return PVWolf3DSystemResponderClient.self
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
