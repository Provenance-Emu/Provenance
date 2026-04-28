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

    public override func executeFrame() {
        super.executeFrame()
        if achievementsActive {
            tickAchievements()
        }
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
        static var changePalette: CoreAction { CoreAction(title: changePaletteLegacyActionTitle, options: nil) }
    }

    /// Expose the legacy cycling action only for the classic `RetroMenuView`.
    /// `PauseTileMenuView` uses `PaletteProviding` and suppresses this action automatically.
    public var coreActions: [CoreAction]? { [Actions.changePalette] }

    public func selected(action: CoreAction) {
        switch action.title {
        case changePaletteLegacyActionTitle:
            cycleToNextPalette()
        default:
            WLOG("Unknown action: " + action.title)
        }
    }
}

