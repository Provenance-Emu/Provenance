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

// MARK: - PVA8SystemResponderClient
//
// The underlying ObjC `PVAtari800Bridge` already implements every requirement of
// `PVA8SystemResponderClient` (button + keyboard + mouse). The Swift wrapper needs to
// explicitly declare conformance and forward each method to the bridge so that
// `PVCoreFactory.controllerViewController(forSystem:)` (case `.Atari8bit`) succeeds
// instead of hitting `fatalError("Core doesn't implement PVA8SystemResponderClient")`.
// Follows the same pattern as `PVDosBoxCore` / `PVSNES9xEmulatorCore`.
extension PVAtari800: PVA8SystemResponderClient {

    // MARK: Button input
    public func didPush(_ button: PVCoreBridge.PVA8Button, forPlayer player: Int) {
        (bridge as! PVA8SystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVA8Button, forPlayer player: Int) {
        (bridge as! PVA8SystemResponderClient).didRelease(button, forPlayer: player)
    }

    // MARK: KeyboardResponder
    public var gameSupportsKeyboard: Bool {
        (bridge as! PVA8SystemResponderClient).gameSupportsKeyboard
    }

    public var requiresKeyboard: Bool {
        (bridge as! PVA8SystemResponderClient).requiresKeyboard
    }

    public func keyDown(_ key: GCKeyCode) {
        (bridge as! PVA8SystemResponderClient).keyDown(key)
    }

    public func keyUp(_ key: GCKeyCode) {
        (bridge as! PVA8SystemResponderClient).keyUp(key)
    }

    // MARK: MouseResponder
    public var gameSupportsMouse: Bool {
        (bridge as! PVA8SystemResponderClient).gameSupportsMouse
    }

    public var requiresMouse: Bool {
        (bridge as! PVA8SystemResponderClient).requiresMouse
    }

    public func didScroll(_ cursor: GCDeviceCursor) {
        (bridge as! PVA8SystemResponderClient).didScroll(cursor)
    }

    public var mouseMovedHandler: GCMouseMoved? {
        (bridge as! PVA8SystemResponderClient).mouseMovedHandler
    }

    public func mouseMoved(at point: CGPoint) {
        (bridge as! PVA8SystemResponderClient).mouseMoved(at: point)
    }

    public func leftMouseDown(at point: CGPoint) {
        (bridge as! PVA8SystemResponderClient).leftMouseDown(at: point)
    }

    public func leftMouseUp() {
        (bridge as! PVA8SystemResponderClient).leftMouseUp()
    }

    public func rightMouseDown(at point: CGPoint) {
        (bridge as! PVA8SystemResponderClient).rightMouseDown(at: point)
    }

    public func rightMouseUp() {
        (bridge as! PVA8SystemResponderClient).rightMouseUp()
    }

    // MARK: MouseResponder (legacy `atPoint:` selectors)
    public func mouseMoved(atPoint point: CGPoint) {
        (bridge as! PVA8SystemResponderClient).mouseMoved(atPoint: point)
    }

    public func leftMouseDown(atPoint point: CGPoint) {
        (bridge as! PVA8SystemResponderClient).leftMouseDown(atPoint: point)
    }

    public func rightMouseDown(atPoint point: CGPoint) {
        (bridge as! PVA8SystemResponderClient).rightMouseDown(atPoint: point)
    }
}
