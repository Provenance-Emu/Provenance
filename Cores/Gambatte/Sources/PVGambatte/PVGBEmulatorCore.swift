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
}

extension PVGBEmulatorCore: PVGBSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVGBEmulatorCore: CoreActions {
    public var coreActions: [CoreAction]? {
        if !isGameboyColor {
            return [CoreAction(title: "Change Palette", options: nil)]
        } else {
            return nil
        }
    }

    public func selected(action: CoreAction) {
        switch action.title {
        case "Change Palette":
            let nextI = displayMode.rawValue + 1
            let next = GBPalette(rawValue: nextI) ?? .default
            displayMode = next
        default:
            print("Unknown action: " + action.title)
        }
    }
}
