//  PVCoreFactory.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

import PVSupport

//extension PVSystem {
//    var responderClassType : AnyClass {
//        guard let responderClassHandle = NSClassFromString(self.responderClass) else {
//            fatalError("Couldn't get class for <\(self.responderClass)>")
//        }
//
//        return responderClassHandle
//    }
//}

extension PVCore {
    func createInstance(forSystem system: PVSystem) -> PVEmulatorCore? {
        guard let coreClass = NSClassFromString(self.principleClass) as? PVEmulatorCore.Type else {
            ELOG("Couldn't get class for <\(self.principleClass)>")
            return nil
        }

        let emuCore = coreClass.init()

        DLOG("Created core : <\(emuCore.debugDescription)>")

        emuCore.systemIdentifier = system.identifier
        return emuCore
    }
}

public final class PVCoreFactory: NSObject {
    class func controllerViewController(forSystem system: PVSystem, core: ResponderClient) -> (UIViewController & StartSelectDelegate)? {
        guard let controllerLayout = system.controllerLayout else {
            fatalError("No controller layout config defined for system \(system.name)")
        }

        switch system.enumValue {
        case .Genesis, .GameGear, .MasterSystem, .SegaCD, .SG1000:
            if let core = core as? PVGenesisSystemResponderClient {
                return PVGenesisControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVGenesisSystemResponderClient")
            }
        case .SNES:
            if let core = core as? PVSNESSystemResponderClient {
                return PVSNESControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVSNESSystemResponderClient")
            }
        case .GBA:
            if let core = core as? PVGBASystemResponderClient {
                return PVGBAControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVGBASystemResponderClient")
            }
        case .GB, .GBC:
            if let core = core as? PVGBSystemResponderClient {
                return PVGBControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVGBSystemResponderClient")
            }
        case .NES, .FDS:
            if let core = core as? PVNESSystemResponderClient {
                return PVNESControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVNESSystemResponderClient")
            }
        case .Atari2600:
            if let core = core as? PV2600SystemResponderClient {
                return PVAtari2600ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PV2600SystemResponderClient")
            }
        case .Atari5200:
            if let core = core as? PV5200SystemResponderClient {
                return PVAtari5200ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PV5200SystemResponderClient")
            }
        case .Atari7800:
            if let core = core as? PV7800SystemResponderClient {
                return PVAtari7800ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PV7800SystemResponderClient")
            }
        case .Sega32X:
            if let core = core as? PVSega32XSystemResponderClient {
                return PVSega32XControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVSega32XSystemResponderClient")
            }
        case .PokemonMini:
            if let core = core as? PVPokeMiniSystemResponderClient {
                return PVPokeMiniControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVPokeMiniSystemResponderClient")
            }
        case .PSX:
            if let core = core as? PVPSXSystemResponderClient {
                return PVPSXControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVPSXSystemResponderClient")
            }
        case .Lynx:
            if let core = core as? PVLynxSystemResponderClient {
                return PVLynxControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVLynxSystemResponderClient")
            }
        case .PCE, .PCECD, .PCFX, .SGFX:
            if let core = core as? PVPCESystemResponderClient {
                return PVPCEControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVPCESystemResponderClient")
            }
        case .NGP, .NGPC:
            if let core = core as? PVNeoGeoPocketSystemResponderClient {
                return PVNeoGeoPocketControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVNeoGeoPocketSystemResponderClient")
            }
        case .VirtualBoy:
            if let core = core as? PVVirtualBoySystemResponderClient {
                return PVVBControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVVirtualBoySystemResponderClient")
            }
        case .WonderSwan, .WonderSwanColor:
            if let core = core as? PVWonderSwanSystemResponderClient {
                return PVWonderSwanControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVWonderSwanSystemResponderClient")
            }
        case .N64:
            if let core = core as? PVN64SystemResponderClient {
                return PVN64ControllerViewController(controlLayout: controllerLayout, system: system, responder: core)
            } else {
                fatalError("Core doesn't impliment PVN64SystemResponderClient")
            }
        }
    }
}
