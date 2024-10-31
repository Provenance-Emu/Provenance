//
//  PVPokeMiniEmulatorCore.swift
//  PVPokeMini
//
//  Created by Joseph Mattiello on 5/25/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation

@_exported import PVEmulatorCore
@_exported import PVCoreBridge
import PVLogging
@preconcurrency import libpokemini
import PokeMiniC
import PVPokeMiniBridge
import PVPokeMiniOptions

@objc
@objcMembers
public final class PVPokeMiniEmulatorCore: PVEmulatorCore, @unchecked Sendable {

    let _bridge: PVPokeMiniBridge = .init()
    required public init() {
        super.init()
        self.bridge =  (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVPokeMiniEmulatorCore: PVPokeMiniSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPMButton, forPlayer player: Int) {
        (_bridge as! PVPokeMiniSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPMButton, forPlayer player: Int) {
        (_bridge as! PVPokeMiniSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVPokeMiniEmulatorCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVPokeMiniOptions.options
    }
}

extension PVPokeMiniEmulatorCore: CoreActions {
    
    enum Actions {
        static var changePalette: CoreAction { CoreAction(title: "Change Palette", options: nil) }
        static var changeLCDFilter: CoreAction { CoreAction(title: "Change LCD Filter", options: nil) }
        static var changeLCDMode: CoreAction { CoreAction(title: "Change LCD Mode", options: nil) }
    }
    
    public var coreActions: [CoreAction]? { [Actions.changePalette] }

    public func selected(action: CoreAction) {
        switch action {
        case Actions.changePalette:
            nextPalette()
        default:
            WLOG("Unknown action: " + action.title)
        }
    }
    func nextLCDFilter() {
        var lcdFilter = CommandLine.lcdfilter + 1
        if lcdFilter >= PVPokeMiniOptions.Options.Video.lcdFilterValues.count { lcdFilter = 0 }
        _bridge.setVideoSpec()
    }
    func nextLCDMode() {
        var lcdMode = CommandLine.lcdmode + 1
        if lcdMode >= PVPokeMiniOptions.Options.Video.lcdModeValues.count { lcdMode = 0 }
        _bridge.setVideoSpec()
    }
    func nextPalette() {
        var palette = CommandLine.palette + 1
        if palette >= PVPokeMiniOptions.Options.Video.paletteValues.count { palette = 0 }
        PokeMini_VideoPalette_Index(CommandLine.palette, nil, CommandLine.lcdcontrast, CommandLine.lcdbright);
        applyChanges()
    }
    func applyChanges() {
        PokeMini_ApplyChanges();
    }
}

