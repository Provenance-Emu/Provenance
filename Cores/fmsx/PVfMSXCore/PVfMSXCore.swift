//
//  PVfMSXCore.swift
//  PVfMSXCore
//
//  Created by Joseph Mattiello on 12/31/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVCoreBridgeRetro

#if canImport(GameController)
import GameController
#endif
@objc
@objcMembers
open class PVfMSXEmuCore: PVEmulatorCore {

    let _bridge: PVfMSXCoreBridge = .init()

    public required init() {
        super.init()
        guard let bridgedCore = _bridge as? any ObjCBridgedCoreBridge else {
            preconditionFailure("PVfMSXCoreBridge must conform to ObjCBridgedCoreBridge")
        }
        self.bridge = bridgedCore
    }
}

extension PVfMSXEmuCore: PVMSXSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVMSXButton, forPlayer player: Int) {
        _bridge.didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVMSXButton, forPlayer player: Int) {
        _bridge.didRelease(button, forPlayer: player)
    }

    public var gameSupportsKeyboard: Bool { _bridge.gameSupportsKeyboard }
    public var requiresKeyboard: Bool { _bridge.requiresKeyboard }
#if canImport(GameController)
    public func keyDown(_ key: GCKeyCode) {
        _bridge.keyDown(key)
    }
    public func keyUp(_ key: GCKeyCode) {
        _bridge.keyUp(key)
    }
#endif

    public var gameSupportsMouse: Bool { _bridge.gameSupportsMouse }
    public var requiresMouse: Bool { _bridge.requiresMouse }

#if canImport(GameController)
    public func didScroll(_ cursor: GCDeviceCursor) {
        _bridge.didScroll(cursor)
    }
    public var mouseMovedHandler: GCMouseMoved? { _bridge.mouseMovedHandler }
#endif

    public func mouseMoved(atPoint point: CGPoint) {
        _bridge.mouseMovedAtPoint(point)
    }
    public func mouseMoved(at point: CGPoint) {
        _bridge.mouseMovedAt(point)
    }
    public func leftMouseDown(at point: CGPoint) {
        _bridge.leftMouseDown(at: point)
    }
    public func leftMouseDown(atPoint point: CGPoint) {
        _bridge.leftMouseDown(atPoint: point)
    }
    public func leftMouseUp() {
        _bridge.leftMouseUp()
    }
    public func rightMouseDown(atPoint point: CGPoint) {
        _bridge.rightMouseDown(atPoint: point)
    }
    public func rightMouseUp() {
        _bridge.rightMouseUp()
    }
}
