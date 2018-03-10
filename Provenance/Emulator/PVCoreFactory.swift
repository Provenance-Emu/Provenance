//  PVCoreFactory.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

import PVSupport
import PVGB
import PVGBA
import PVNES
import PVSNES
import PVStella
import PVGenesis
import ProSystem
import PicoDrive
import PVAtari800
import PVPokeMini
import PVMednafen
import PVAtari800
import PVMupen64Plus

public final class PVCoreFactory : NSObject {
    
    @objc
    class func emulatorCore(forGame game: PVGame) -> PVEmulatorCore? {
        return emulatorCore(forSystemIdentifier:game.systemIdentifier)
    }
    
    @objc
    class func emulatorCore(forSystemIdentifier systemID: String) -> PVEmulatorCore? {
        guard let systemID = SystemIdentifier(rawValue: systemID) else {
            ELOG("Fail")
            return nil
        }
        return emulatorCore(forSystemIdentifier:systemID)
    }
    
    class func emulatorCore(forSystemIdentifier systemID: SystemIdentifier) ->  PVEmulatorCore {
        
        let core : PVEmulatorCore

        switch systemID {
        case .Genesis, .GameGear, .MasterSystem, .SegaCD, .SG1000:
            core = PVGenesisEmulatorCore()
        case .SNES:
            core = PVSNESEmulatorCore()
        case .GBA:
            core = PVGBAEmulatorCore()
        case .GB, .GBC:
            core = PVGBEmulatorCore()
        case .NES, .FDS:
            core = PVNESEmulatorCore()
        case .Atari2600:
            core = PVStellaGameCore()
        case .Atari5200:
            core = ATR800GameCore()
        case .Atari7800:
            core = PVProSystemGameCore()
        case .Sega32X:
            core = PicodriveGameCore()
        case .PokemonMini:
            core = PVPokeMiniEmulatorCore()
        case .PSX, .Lynx, .PCE, .PCECD, .NGP, .NGPC, .PCFX, .SGFX, .VirtualBoy, .WonderSwan, .WonderSwanColor:
            core = MednafenGameCore()
        case .N64:
            core = MupenGameCore()
        }

        core.systemIdentifier = systemID.rawValue
        return core
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
