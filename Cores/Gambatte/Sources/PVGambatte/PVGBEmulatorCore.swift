//
//  PVGBEmulatorCore.swift
//  PVGB
//
//  Created by Joseph Mattiello on 6/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import PVGambatteBridge
import PVGambatteOptions
import PVLogging

@objc
@objcMembers
public class PVGBEmulatorCore: PVEmulatorCore {

    public var displayMode: GBPalette = .default {
        didSet {
            _bridge.changeDisplayMode(displayMode.rawValue)
        }
    }
    public var isGameboyColor: Bool = false

    var _bridge: PVGBEmulatorCoreBridge = .init()

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }

    // MARK: - RetroAchievements backing storage

    /// Weak reference to the OSD delegate.
    weak var _achievementsDelegate: (any RetroAchievementsOSDDelegate)?

    /// Hardcore mode flag.
    var _hardcoreMode: Bool = false
}

extension PVGBEmulatorCore: PVGBSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVGBEmulatorCore: GameWithCheat {
    public var supportsCheatCode: Bool { true }

    public var cheatCodeTypes: [String] {
        return CheatCodeTypesMakeStringArray([.gameGenie, .gameShark])
    }

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        return _bridge.setCheat(code, setType: type, setEnabled: enabled)
    }

    public func resetCheatCodes() {
        _bridge.resetCheatCodes()
    }
}

extension PVGBEmulatorCore: CoreActions {
    public var coreActions: [CoreAction]? {
        // Provide "Change Palette" for the classic RetroMenuView (cycling).
        // The tile-based PauseTileMenuView uses PaletteProviding instead and
        // filters out this action when the picker tile is shown.
        guard !isGameboyColor else { return nil }
        return [CoreAction(title: changePaletteLegacyActionTitle, options: nil)]
    }

    public func selected(action: CoreAction) {
        switch action.title {
        case changePaletteLegacyActionTitle:
            cycleToNextPalette()
        default:
            WLOG("Unknown action: \(action.title)")
        }
    }
}

// MARK: - PaletteProviding

extension PVGBEmulatorCore: PaletteProviding {
    public var availablePalettes: [CorePalette] {
        // GBC games don't use the DMG palette system.
        guard !isGameboyColor else { return [] }
        return GBPalette.allCases.map(\.asCorePalette)
    }

    public var currentPaletteID: String {
        displayMode.paletteID
    }

    public func selectPalette(id: String) {
        guard let rawValue = Int(id),
              let palette = GBPalette(rawValue: rawValue) else { return }
        displayMode = palette
    }
}
