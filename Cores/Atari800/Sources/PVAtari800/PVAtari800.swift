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

    let _bridge: PVAtari800Bridge = .init()

    public required init() {
        super.init()
        bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }

    public override func executeFrame() {
        super.executeFrame()
        if achievementsActive {
            tickAchievements()
        }
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

// TODO(tvos-tester-18may): The underlying `PVAtari800Bridge` ObjC class implements both
// PVA8SystemResponderClient and PV5200SystemResponderClient (see PVAtari800Bridge.h),
// but the Swift `PVAtari800` wrapper only declares PV5200SystemResponderClient conformance.
// As a result, when an Atari 8-bit ROM is launched with the native Atari800 core,
// `PVCoreFactory.controllerViewController(forSystem:)` hits the `fatalError("Core doesn't
// implement PVA8SystemResponderClient")` branch (PVCoreFactory.swift:184). The matching
// Core.plist mismatch (`com.provenance.8bit` vs the canonical `com.provenance.atari8bit`)
// has been fixed in this commit so that the core is correctly associated with the system.
// Adding `PVA8SystemResponderClient` conformance here requires also satisfying its
// KeyboardResponder + MouseResponder requirements — too broad a change to land surgically
// without a runtime smoke test on a real Atari 8-bit ROM.
