//  PVCoreFactory.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVLibrary
import PVSupport

// extension PVSystem {
//    var responderClassType : AnyClass {
//        guard let responderClassHandle = NSClassFromString(self.responderClass) else {
//            fatalError("Couldn't get class for <\(self.responderClass)>")
//        }
//
//        return responderClassHandle
//    }
// }

extension PVCore {
    func createInstance(forSystem system: PVSystem) -> PVEmulatorCore? {
        guard let coreClass = NSClassFromString(self.principleClass) as? PVEmulatorCore.Type else {
            ELOG("Couldn't get class for <\(principleClass)>")
            return nil
        }

        let emuCore = coreClass.init()

        DLOG("Created core : <\(emuCore.debugDescription)>")

        emuCore.systemIdentifier = system.identifier
        emuCore.coreIdentifier = identifier
        return emuCore
    }
}

public final class PVCoreFactory: NSObject {
    class func controllerViewController(forSystem system: PVSystem, core: ResponderClient) -> (UIViewController & StartSelectDelegate)? {
        guard let controllerLayout = system.controllerLayout else {
            fatalError("No controller layout config defined for system \(system.name)")
        }
        var skipError = false;
        if let core = core as? PVRetroArchCoreResponderClient {
            skipError = true;
        }
        switch system.enumValue {
        case .Genesis, .GameGear, .SegaCD, .MasterSystem, .SG1000:
            if let core = core as? PVGenesisSystemResponderClient {
                return PVGenesisControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVGenesisSystemResponderClient")
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
            if let core = core as? PV5200SystemResponderClient {
                return PVAtari5200ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PV5200SystemResponderClient")
            }
            break;
        case .Atari7800:
            if let core = core as? PV7800SystemResponderClient {
                return PVAtari7800ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PV7800SystemResponderClient")
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
        case .NeoGeo:
            if let core = core as? PVNeoGeoSystemResponderClient {
                return PVNeoGeoControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVNeoGeoSystemResponderClient")
            }
            break;
        case .MAME:
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
            } else if (!skipError) {
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
        case .DOS:
            if let core = core as? PVDOSSystemResponderClient {
                return PVDOSControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else if (!skipError) {
                fatalError("Core doesn't implement PVDOSSystemResponderClient")
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
        case .Unknown:
            if (!skipError) {
                ELOG("No known system named: \(system.name) id: \(system.identifier)")
                assertionFailure("No known system named: \(system.name) id: \(system.identifier)")
            }
            break;
        case .AtariST, .C64, .Macintosh:
            if (!skipError) {
                ELOG("No known system named: \(system.name) id: \(system.identifier)")
                assertionFailure("No known system named: \(system.name) id: \(system.identifier)")
            }
            break;
        @unknown default:
            if (!skipError) {
                ELOG("No known system named: \(system.name) id: \(system.identifier)")
                assertionFailure("No known system named: \(system.name) id: \(system.identifier)")
            }
            break;
        }
        #if !APP_STORE
        if let core = core as? PVRetroArchCoreResponderClient {
            return PVRetroArchControllerViewController(controlLayout: [], system: system, responder: core)
        }
        #endif
        return nil
    }
}
