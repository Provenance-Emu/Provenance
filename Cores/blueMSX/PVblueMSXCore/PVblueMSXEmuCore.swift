//
//  PVblueMSXEmuCore.swift
//  PVblueMSXCore
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
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
open class PVblueMSXEmuCore: PVEmulatorCore {

    let _bridge: PVblueMSXCore = .init()

    public required init() {
        super.init()
        guard let bridgedCore = _bridge as? any ObjCBridgedCoreBridge else {
            preconditionFailure("PVblueMSXCore must conform to ObjCBridgedCoreBridge")
        }
        self.bridge = bridgedCore
    }
}

extension PVblueMSXEmuCore: PVMSXSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVMSXButton, forPlayer player: Int) {
        (_bridge as? PVMSXSystemResponderClient)?.didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVMSXButton, forPlayer player: Int) {
        (_bridge as? PVMSXSystemResponderClient)?.didRelease(button, forPlayer: player)
    }

    public var gameSupportsKeyboard: Bool { (_bridge as? PVMSXSystemResponderClient)?.gameSupportsKeyboard ?? false }
    public var requiresKeyboard: Bool { (_bridge as? PVMSXSystemResponderClient)?.requiresKeyboard ?? false }
#if canImport(GameController)
    public func keyDown(_ key: GCKeyCode) {
        (_bridge as? PVMSXSystemResponderClient)?.keyDown(key)
    }
    public func keyUp(_ key: GCKeyCode) {
        (_bridge as? PVMSXSystemResponderClient)?.keyUp(key)
    }
#endif

    public var gameSupportsMouse: Bool { (_bridge as? PVMSXSystemResponderClient)?.gameSupportsMouse ?? false }
    public var requiresMouse: Bool { (_bridge as? PVMSXSystemResponderClient)?.requiresMouse ?? false }

#if canImport(GameController)
    public func didScroll(_ cursor: GCDeviceCursor) {
        (_bridge as? PVMSXSystemResponderClient)?.didScroll(cursor)
    }
    public var mouseMovedHandler: GCMouseMoved? { (_bridge as? PVMSXSystemResponderClient)?.mouseMovedHandler }
#endif

    public func mouseMoved(atPoint point: CGPoint) {
        (_bridge as? PVMSXSystemResponderClient)?.mouseMoved(at: point)
    }
    public func mouseMoved(at point: CGPoint) {
        (_bridge as? PVMSXSystemResponderClient)?.mouseMoved(at: point)
    }
    public func leftMouseDown(at point: CGPoint) {
        (_bridge as? PVMSXSystemResponderClient)?.leftMouseDown(at: point)
    }
    public func leftMouseDown(atPoint point: CGPoint) {
        (_bridge as? PVMSXSystemResponderClient)?.leftMouseDown(atPoint: point)
    }
    public func leftMouseUp() {
        (_bridge as? PVMSXSystemResponderClient)?.leftMouseUp()
    }
    public func rightMouseDown(atPoint point: CGPoint) {
        (_bridge as? PVMSXSystemResponderClient)?.rightMouseDown(atPoint: point)
    }
    public func rightMouseUp() {
        (_bridge as? PVMSXSystemResponderClient)?.rightMouseUp()
    }
}
