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
        case .NGP, .NGPC:
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
        case .Unknown:
            ELOG("No known system named: \(system.name) id: \(system.identifier)")
            return nil
        }
    }
}
