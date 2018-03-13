//  PVCoreFactory.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

import PVSupport

public final class PVCoreFactory : NSObject {
    @objc
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
    @objc
    class func controllerViewController(forSystemIdentifier systemID : String) -> PVControllerViewController? {
        guard let systemID = SystemIdentifier(rawValue: systemID) else {
            return nil
        }
        return controllerViewController(forSystemIdentifier : systemID)
    }

    class func controllerViewController(forSystemIdentifier systemID: SystemIdentifier) -> PVControllerViewController? {
        guard let controllerLayoutStruct = PVEmulatorConfiguration.controllerLayout(forSystemIdentifier: systemID) else {
            ELOG("No controller layout config defined for system \(systemID)")
            return nil
        }
        
        let controllerLayout = controllerLayoutStruct.reduce([[String:Any]]()) { (result, layoutEntry) -> [[String:Any]] in
            var result = result
            result.append(layoutEntry.dictionaryValue)
            return result
        }
        
        switch systemID {
        case .Genesis, .GameGear, .MasterSystem, .SegaCD, .SG1000:
            return PVGenesisControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .SNES:
            return PVSNESControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .GBA:
            return PVGBAControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .GB, .GBC:
            return PVGBControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .NES, .FDS:
            return PVNESControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .Atari2600:
            return PVStellaControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .Atari5200:
            return PVAtari5200ControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .Atari7800:
            return PVAtari7800ControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .Sega32X:
            return PV32XControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .PokemonMini:
            return PVPokeMiniControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .PSX:
            return PVPSXControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .Lynx:
            return PVLynxControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .PCE, .PCECD, .PCFX, .SGFX:
            return PVPCEControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .NGP, .NGPC:
            return PVNeoGeoPocketControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .VirtualBoy:
            return PVVBControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .WonderSwan, .WonderSwanColor:
            return PVWonderSwanControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        case .N64:
            return PVN64ControllerViewController(controlLayout: controllerLayout , systemIdentifier: systemID.rawValue)
        }
    }
    #endif
}
