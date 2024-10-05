//
//  ATR800GameCore.swift
//  PVAtari800
//
//  Created by Joseph Mattiello on 5/23/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVSupport
import PVAtari800Bridge
#if canImport(GameController)
import GameController
#endif

@objc
@objcMembers
public final class PVAtari800: PVEmulatorCore, @unchecked Sendable {
    
    public required init() {
        super.init()
        bridge = (PVAtari800Bridge() as! any ObjCBridgedCoreBridge)
    }

#if canImport(GameController)
    @MainActor
    public var mouseMovedHandler: GCExtendedGamepadValueChangedHandler? = nil
    @MainActor
    public var keyChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
#endif
}

extension PVAtari800: PV5200SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PV5200Button, forPlayer player: Int) {
        (bridge as! PV5200SystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PV5200Button, forPlayer player: Int) {
        (bridge as! PV5200SystemResponderClient).didRelease(button, forPlayer: player)
    }
    
    public func didMoveJoystick(_ button: PVCoreBridge.PV5200Button, withValue value: CGFloat, forPlayer player: Int) {
        (bridge as! PV5200SystemResponderClient).didMoveJoystick(button, withValue: value, forPlayer: player)
    }
    
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (bridge as! PV5200SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
}
