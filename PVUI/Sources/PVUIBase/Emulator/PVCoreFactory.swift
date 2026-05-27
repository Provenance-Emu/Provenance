//  PVCoreFactory.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVLibrary
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import PVRealm
import PVLogging
import PVSettings
import Defaults

// extension PVSystem {
//    var responderClassType : AnyClass {
//        guard let responderClassHandle = NSClassFromString(self.responderClass) else {
//            fatalError("Couldn't get class for <\(self.responderClass)>")
//        }
//
//        return responderClassHandle
//    }
// }

public extension PVCore {
    public func createInstance(forSystem system: PVSystem) -> PVEmulatorCore? {
        var className = self.principleClass

        // Thin libretro wrapper is the default on all platforms. The legacy
        // full-RetroArch in-process wrapper is available as an opt-in escape
        // hatch via Settings > Advanced > "Use Legacy RetroArch Wrapper".
        ILOG("createInstance: principleClass=\(className) for \(identifier)")
        if className.contains("RetroArch") || className.contains("LibRetro") || className == "PVRetroArchCoreBridge" {
            let pvRetroArchCoreExists = NSClassFromString(className) != nil
            let userWantsLegacy = Defaults[.useLegacyRetroArchWrapper]
            // PPSSPP hangs during retro_load_game in the thin wrapper (GL
            // context not current yet). Force legacy wrapper until fixed.
            let isPPSSPP = identifier.lowercased().contains("ppsspp")
            let useLegacy = (userWantsLegacy || isPPSSPP) && pvRetroArchCoreExists
            ILOG("ThinLibretro: userWantsLegacy=\(userWantsLegacy), legacyClassExists=\(pvRetroArchCoreExists), useLegacy=\(useLegacy) (probed=\(className))")
            if !useLegacy {
                Self.ensurePVCoreBridgeRetroLoaded()
                if NSClassFromString("PVThinLibretroCore") != nil {
                    ILOG("ThinLibretro: swapping \(className) → PVThinLibretroCore for \(identifier)")
                    className = "PVThinLibretroCore"
                } else {
                    WLOG("ThinLibretro: PVThinLibretroCore class not found even after loading framework — falling back to legacy")
                }
            }
        }

        guard let coreClass = NSClassFromString(className) as? PVEmulatorCore.Type else {
            ELOG("Couldn't get class for <\(className)> (original: \(principleClass))")
            return nil
        }

        let emuCore = coreClass.init()

        DLOG("Created core : <\(emuCore.debugDescription)>")

        emuCore.systemIdentifier = system.identifier
        emuCore.coreIdentifier = identifier
        return emuCore
    }

    /// Ensures PVCoreBridgeRetro.framework is loaded so its classes are registered
    /// with the ObjC runtime. Called once lazily before the thin wrapper swap.
    private static var _bridgeRetroLoaded = false
    private static func ensurePVCoreBridgeRetroLoaded() {
        guard !_bridgeRetroLoaded else { return }
        _bridgeRetroLoaded = true
        // Find and load PVCoreBridgeRetro.framework from the app's Frameworks dir
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            let bundleURL = frameworksURL.appendingPathComponent("PVCoreBridgeRetro.framework")
            if let bundle = Bundle(url: bundleURL), !bundle.isLoaded {
                ILOG("ThinLibretro: loading PVCoreBridgeRetro.framework from \(bundleURL.path)")
                bundle.load()
            }
        }
    }
}

public final class PVCoreFactory: NSObject {
    class func controllerViewController(forSystem system: PVSystem, core: ResponderClient) -> (any ControllerVC)? {
        guard let controllerLayout = system.controllerLayout else {
            fatalError("No controller layout config defined for system \(system.name)")
        }
        var skipError = false;
        if core is PVRetroArchCoreResponderClient {
            skipError = true;
        }
        // PVThinLibretroCore doesn't conform to system-specific responder protocols
        // (it delegates to PVThinLibretroFrontend). Skip fatalError for it too.
        if NSStringFromClass(type(of: core)).contains("ThinLibretro") {
            skipError = true;
        }
        switch system.enumValue {
        case .Genesis, .GameGear, .SegaCD, .MasterSystem:
            if let core = core as? PVGenesisSystemResponderClient {
                return PVGenesisControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVGenesisSystemResponderClient")
            }
            break;
        case .SG1000:
            if let core = core as? PVSG1000SystemResponderClient {
                return PVSG1000ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVSG1000SystemResponderClient")
            }
            break;
        case .Dreamcast:
            if let core = core as? PVDreamcastSystemResponderClient {
                return PVDreamcastControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVDreamcastSystemResponderClient")
            }
            //        TO DO: strip out MS and SG1000 from Genesis, etc…
            //        case .MasterSystem:
            //            if let core = core as? PVMasterSystemSystemResponderClient {
            //                return PVMasterSystemControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            //            } else {
            //                fatalError("Core doesn't implement PVMasterSystemSystemResponderClient")
            //            }
            //        case .SG1000:
            //            if let core = core as? PVSG1000SystemResponderClient {
            //                return PVSG1000ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            //            } else {
            //                fatalError("Core doesn't implement PVSG1000SystemSystemResponderClient")
            //            }
            break;
        case .SNES:
            if let core = core as? PVSNESSystemResponderClient {
                return PVSNESControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVSNESSystemResponderClient")
            }
            break;
        case .GBA:
            if let core = core as? PVGBASystemResponderClient {
                return PVGBAControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVGBASystemResponderClient")
            }
            break;
        case .GB, .GBC:
            if let core = core as? PVGBSystemResponderClient {
                return PVGBControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVGBSystemResponderClient")
            }
            break;
        case .NES, .FDS, .Music:
            if let core = core as? PVNESSystemResponderClient {
                return PVNESControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVNESSystemResponderClient")
            }
            break;
        case .Atari2600:
            if let core = core as? PV2600SystemResponderClient {
                return PVAtari2600ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PV2600SystemResponderClient")
            }
            break;
        case .Atari5200:
            if let core = core as? PV5200SystemResponderClient {
                return PVAtari5200ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PV5200SystemResponderClient")
            }
            break;
        case .Atari8bit:
            if let core = core as? PVA8SystemResponderClient {
                return PVAtari8BitControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVA8SystemResponderClient")
            }
            break;
        case .Atari7800:
            if let core = core as? PV7800SystemResponderClient {
                return PVAtari7800ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PV7800SystemResponderClient")
            }
            break;
        case .AtariST:
            // AtariST uses keyboard+mouse (PVDOSSystemResponderClient) via Hatari libretro core.
            // Routing through PV7800SystemResponderClient caused a force-unwrap crash in
            // PVAtari7800ControllerViewController when button tags from the AtariST skin did not
            // correspond to valid PV7800Button raw values.
            if let core = core as? PVDOSSystemResponderClient {
                return PVDOSControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVDOSSystemResponderClient")
            }
            break;
        case .AtariJaguar, .AtariJaguarCD:
            if let core = core as? PVJaguarSystemResponderClient {
                return PVAtariJaguarControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVJaguarSystemResponderClient")
            }
            break;
        case .Odyssey2:
            if let core = core as? PVOdyssey2SystemResponderClient {
                return PVOdyssey2ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVOdyssey2SystemResponderClient")
            }
            break;
        case .Sega32X:
            if let core = core as? PVSega32XSystemResponderClient {
                return PVSega32XControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVSega32XSystemResponderClient")
            }
            break;
        case .PokemonMini:
            if let core = core as? PVPokeMiniSystemResponderClient {
                return PVPokeMiniControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVPokeMiniSystemResponderClient")
            }
            break;
        case .PSX:
            if let core = core as? PVPSXSystemResponderClient {
                return PVPSXControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVPSXSystemResponderClient")
            }
            break;
        case .PS2, .PS3:
            if let core = core as? PVPS2SystemResponderClient {
                return PVPS2ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVPS2SystemResponderClient")
            }
            break;
        case .PSP:
            if let core = core as? PVPSPSystemResponderClient {
                return PVPSPControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVPSPSystemResponderClient")
            }
            break;
        case .Lynx:
            if let core = core as? PVLynxSystemResponderClient {
                return PVLynxControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVLynxSystemResponderClient")
            }
            break;
        case .PCE, .PCECD, .SGFX:
            if let core = core as? PVPCESystemResponderClient {
                return PVPCEControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVPCESystemResponderClient")
            }
            break;
        case .PCFX:
            if let core = core as? PVPCFXSystemResponderClient {
                return PVPCFXControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVPCFXSystemResponderClient")
            }
            break;
        case .NGP, .NGPC:
            if let core = core as? PVNeoGeoPocketSystemResponderClient {
                return PVNeoGeoPocketControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVNeoGeoPocketSystemResponderClient")
            }
            break;
        case .NeoGeo, .NeoGeoCD:
            if let core = core as? PVNeoGeoSystemResponderClient {
                return PVNeoGeoControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVNeoGeoSystemResponderClient")
            }
            break;
        case .MAME, .CPS1, .CPS2, .CPS3:
            if let core = core as? PVMAMESystemResponderClient {
                return PVMAMEControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVMAMESystemResponderClient")
            }
            break;
        case .Saturn:
            if let core = core as? PVSaturnSystemResponderClient {
                return PVSaturnControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVSaturnSystemResponderClient")
            }
            break;
        case .VirtualBoy:
            if let core = core as? PVVirtualBoySystemResponderClient {
                return PVVBControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVVirtualBoySystemResponderClient")
            }
            break;
        case .WonderSwan, .WonderSwanColor:
            if let core = core as? PVWonderSwanSystemResponderClient {
                return PVWonderSwanControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVWonderSwanSystemResponderClient")
            }
            break;
        case .N64:
            if let core = core as? PVN64SystemResponderClient {
                return PVN64ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVN64SystemResponderClient")
            }
            break;
        case .GameCube:
            if let core = core as? PVGameCubeSystemResponderClient {
                return PVGameCubeControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVN64SystemResponderClient")
            }
            break;
        case .Wii:
            if let core = core as? PVWiiSystemResponderClient {
                return PVWiiControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVWiiSystemResponderClient")
            }
            break;
        case ._3DO:
            if let core = core as? PV3DOSystemResponderClient {
                return PV3DOControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PV3DOSystemResponderClient")
            }
            break;
        case .ColecoVision:
            if let core = core as? PVColecoVisionSystemResponderClient {
                return PVColecoVisionControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVColecoVisionSystemResponderClient")
            }
            break;
        case .CDi:
            if let core = core as? PVCDiSystemResponderClient {
                return PVCDiControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVColecoVisionSystemResponderClient")
            }
            break;
        case .Intellivision:
            if let core = core as? PVIntellivisionSystemResponderClient {
                return PVIntellivisionControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVIntellivisionSystemResponderClient")
            }
            break;
        case .Supervision:
            if let core = core as? PVSupervisionSystemResponderClient {
                return PVSupervisionControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVSupervisionSystemResponderClient")
            }
            break;
        case .Vectrex:
            if let core = core as? PVVectrexSystemResponderClient {
                return PVVectrexControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVVectrexSystemResponderClient")
            }
            break;
        case .DS:
            if let core = core as? PVDSSystemResponderClient {
                return PVDSControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if skipError {
                // Thin libretro wrapper: the cross-module @objc conformance to
                // PVDSSystemResponderClient may not be visible to `as?` at this call site.
                // Verify via responds(to:) and force-cast if the methods are present.
                let anyCore = core as AnyObject
                if anyCore.responds(to: NSSelectorFromString("didPushDSButton:forPlayer:")) {
                    // swiftlint:disable:next force_cast
                    let dsCore = anyCore as! PVDSSystemResponderClient
                    return PVDSControllerViewController(controlLayout: controllerLayout, system: system, responder: dsCore)
                }
                WLOG("DS thin wrapper: PVDSSystemResponderClient methods not found — no controller overlay")
            } else {
                fatalError("Core doesn't implement PVDSSystemResponderClient")
            }
            break;
        case ._3DS:
            if let core = core as? PV3DSSystemResponderClient {
                return PV3DSControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PV3DSSystemResponderClient")
            }
            break;
        case .DOOM:
            if let core = core as? PVDoomSystemResponderClient {
                return PVDoomControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if let core = core as? PVDOSSystemResponderClient {
                // Fallback: cores that only implement PVDOSSystemResponderClient still get a working controller
                return PVDOSControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVDoomSystemResponderClient or PVDOSSystemResponderClient")
            }
            break;
        case .DOS, .Quake, .Quake2:
            if let core = core as? PVDOSSystemResponderClient {
                return PVDOSControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVDOSSystemResponderClient")
            }
            break;
        case .Wolf3D:
            if let core = core as? PVWolf3DSystemResponderClient {
                return PVWolf3DControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVWolf3DSystemResponderClient")
            }
            break;
        case .ZXSpectrum, .EP128:
            if let core = core as? PVEP128SystemResponderClient {
                return PVEP128ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVEP128SystemResponderClient")
            }
            break;
        case .MSX, .MSX2:
            if let core = core as? PVMSXSystemResponderClient {
                return PVMSXControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVMSXSystemResponderClient")
            }
            break;
        case .RetroArch:
            if let core = core as? PVRetroArchCoreResponderClient {
                return PVRetroArchControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVRetroArchSystemResponderClient")
            }
            break;
        case .Unknown:
            if (!skipError) {
                ELOG("No known system named: \(system.name) id: \(system.identifier)")
                assertionFailure("No known system named: \(system.name) id: \(system.identifier)")
            }
            break;
        case .C64, .Macintosh, .PC98:
            if let core = core as? PVRetroArchCoreResponderClient {
                return PVRetroArchControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVRetroArchSystemResponderClient")
            }
            break;
        @unknown default:
            if (!skipError) {
                ELOG("No known system named: \(system.name) id: \(system.identifier)")
                assertionFailure("No known system named: \(system.name) id: \(system.identifier)")
            }
            break;
        }
        if let core = core as? PVRetroArchCoreResponderClient {
            return PVRetroArchControllerViewController(controlLayout: [], system: system, responder: core)
        }
        return nil
    }
}
