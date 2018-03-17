//  PVCoreFactory.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

import PVSupport

public final class PVCoreFactory : NSObject {
    class func emulatorCore(forGame game: PVGame) ->  PVEmulatorCore? {
        guard let system = game.system else {
            ELOG("No system for game \(game.title)")
            return nil
        }
        
        guard let core = system.cores.first else {
            ELOG("No core for system \(system.identifier)")
            return nil
        }
        
        guard let coreClass = NSClassFromString(core.principleClass) as? PVEmulatorCore.Type else {
            ELOG("Couldn't get class for <\(core.principleClass)>")
            return nil
        }
    
        let emuCore = coreClass.init()

        DLOG("Created core : <\(emuCore.debugDescription)>")
        
        emuCore.systemIdentifier = system.identifier
        return emuCore
    }
    
    #if os(iOS)
    class func controllerViewController<T:PVEmulatorCore>(forSystemIdentifier systemID : String) -> PVControllerViewController<T> {
        guard let system = RomDatabase.sharedInstance.object(ofType: PVSystem.self, wherePrimaryKeyEquals: systemID) else {
            fatalError("No system for id \(systemID)")
        }
        return controllerViewController(forSystem : system)
    }

    class func controllerViewController<T:PVEmulatorCore>(forSystem system: PVSystem) -> PVControllerViewController<T> {
        guard let controllerLayout = system.controllerLayout else {
            fatalError("No controller layout config defined for system \(system.name)")
        }
        
        switch system.enumValue {
        case .Genesis, .GameGear, .MasterSystem, .SegaCD, .SG1000:
            return PVGenesisControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .SNES:
            return PVSNESControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .GBA:
            return PVGBAControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .GB, .GBC:
            return PVGBControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .NES, .FDS:
            return PVNESControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .Atari2600:
            return PVStellaControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .Atari5200:
            return PVAtari5200ControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .Atari7800:
            return PVAtari7800ControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .Sega32X:
            return PV32XControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .PokemonMini:
            return PVPokeMiniControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .PSX:
            return PVPSXControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .Lynx:
            return PVLynxControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .PCE, .PCECD, .PCFX, .SGFX:
            return PVPCEControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .NGP, .NGPC:
            return PVNeoGeoPocketControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .VirtualBoy:
            return PVVBControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .WonderSwan, .WonderSwanColor:
            return PVWonderSwanControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        case .N64:
            return PVN64ControllerViewController(controlLayout: controllerLayout , system: system) as! PVControllerViewController<T>
        }
    }
    #endif
}
