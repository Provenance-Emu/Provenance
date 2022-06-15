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

        switch system.enumValue {
        case .Genesis, .GameGear, .SegaCD, .MasterSystem, .SG1000:
            if let core = core as? PVGenesisSystemResponderClient {
                return PVGenesisControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVGenesisSystemResponderClient")
            }
        case .Dreamcast:
            if let core = core as? PVDreamcastSystemResponderClient {
                return PVDreamcastControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
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
        case .SNES:
            if let core = core as? PVSNESSystemResponderClient {
                return PVSNESControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVSNESSystemResponderClient")
            }
        case .GBA:
            if let core = core as? PVGBASystemResponderClient {
                return PVGBAControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVGBASystemResponderClient")
            }
        case .GB, .GBC:
            if let core = core as? PVGBSystemResponderClient {
                return PVGBControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVGBSystemResponderClient")
            }
        case .NES, .FDS:
            if let core = core as? PVNESSystemResponderClient {
                return PVNESControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVNESSystemResponderClient")
            }
        case .Atari2600:
            if let core = core as? PV2600SystemResponderClient {
                return PVAtari2600ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PV2600SystemResponderClient")
            }
        case .Atari5200:
            if let core = core as? PV5200SystemResponderClient {
                return PVAtari5200ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PV5200SystemResponderClient")
            }
        case .Atari8bit:
            if let core = core as? PV5200SystemResponderClient {
                return PVAtari5200ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PV5200SystemResponderClient")
            }
        case .Atari7800:
            if let core = core as? PV7800SystemResponderClient {
                return PVAtari7800ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PV7800SystemResponderClient")
            }
        case .AtariJaguar:
            if let core = core as? PVJaguarSystemResponderClient {
                return PVAtariJaguarControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVJaguarSystemResponderClient")
            }
        case .Odyssey2:
            if let core = core as? PVOdyssey2SystemResponderClient {
                return PVOdyssey2ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVOdyssey2SystemResponderClient")
            }
        case .Sega32X:
            if let core = core as? PVSega32XSystemResponderClient {
                return PVSega32XControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVSega32XSystemResponderClient")
            }
        case .PokemonMini:
            if let core = core as? PVPokeMiniSystemResponderClient {
                return PVPokeMiniControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVPokeMiniSystemResponderClient")
            }
        case .PSX:
            if let core = core as? PVPSXSystemResponderClient {
                return PVPSXControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVPSXSystemResponderClient")
            }
        case .PS2, .PS3:
            if let core = core as? PVPS2SystemResponderClient {
                return PVPS2ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVPS2SystemResponderClient")
            }
        case .PSP:
            if let core = core as? PVPSPSystemResponderClient {
                return PVPSPControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVPSPSystemResponderClient")
            }
        case .Lynx:
            if let core = core as? PVLynxSystemResponderClient {
                return PVLynxControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVLynxSystemResponderClient")
            }
        case .PCE, .PCECD, .SGFX:
            if let core = core as? PVPCESystemResponderClient {
                return PVPCEControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVPCESystemResponderClient")
            }
        case .PCFX:
            if let core = core as? PVPCFXSystemResponderClient {
                return PVPCFXControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVPCFXSystemResponderClient")
            }
        case .NeoGeo, .NGP, .NGPC:
            if let core = core as? PVNeoGeoPocketSystemResponderClient {
                return PVNeoGeoPocketControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVNeoGeoPocketSystemResponderClient")
            }
        case .Saturn:
            if let core = core as? PVSaturnSystemResponderClient {
                return PVSaturnControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVSaturnSystemResponderClient")
            }
        case .VirtualBoy:
            if let core = core as? PVVirtualBoySystemResponderClient {
                return PVVBControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVVirtualBoySystemResponderClient")
            }
        case .WonderSwan, .WonderSwanColor:
            if let core = core as? PVWonderSwanSystemResponderClient {
                return PVWonderSwanControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVWonderSwanSystemResponderClient")
            }
        case .N64:
            if let core = core as? PVN64SystemResponderClient {
				return PVN64ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVN64SystemResponderClient")
            }
		case .GameCube:
			if let core = core as? PVGameCubeSystemResponderClient {
				return PVGameCubeControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
			} else {
				fatalError("Core doesn't implement PVN64SystemResponderClient")
			}
        case ._3DO:
            if let core = core as? PV3DOSystemResponderClient {
                return PV3DOControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PV3DOSystemResponderClient")
            }
        case .ColecoVision:
            if let core = core as? PVColecoVisionSystemResponderClient {
                return PVColecoVisionControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVColecoVisionSystemResponderClient")
            }
        case .Intellivision:
            if let core = core as? PVIntellivisionSystemResponderClient {
                return PVIntellivisionControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVIntellivisionSystemResponderClient")
            }
        case .Vectrex:
            if let core = core as? PVVectrexSystemResponderClient {
                return PVVectrexControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVVectrexSystemResponderClient")
            }
        case .DS:
            if let core = core as? PVDSSystemResponderClient {
                return PVDSControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVDSSystemResponderClient")
            }
        case .DOS:
            if let core = core as? PVDOSSystemResponderClient {
                return PVDOSControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't implement PVDOSSystemResponderClient")
            }
        case .Unknown:
            ELOG("No known system named: \(system.name) id: \(system.identifier)")
            return nil
        @unknown default:
            ELOG("No known system named: \(system.name) id: \(system.identifier)")
            return nil
        }
    }
}
