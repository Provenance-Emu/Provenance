//
//  PVEP128EmuCore.swift
//  PVEP128EmuCore
//
//  Created by Joseph Mattiello on 10/06/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVCoreBridgeRetro

@objc
@objcMembers
open class PVEP128EmuCore: PVEmulatorCore {

    let _bridge: PVEP128EmuCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVEP128EmuCore: PVEP128SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVEP128Button, forPlayer player: Int) {
        (_bridge as! PVEP128SystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVEP128Button, forPlayer player: Int) {
        (_bridge as! PVEP128SystemResponderClient).didRelease(button, forPlayer: player)
    }
    
    public var gameSupportsKeyboard: Bool { true }
    public var requiresKeyboard: Bool { false }
#if canImport(GameController)
//    @objc optional var keyChangedHandler: GCKeyboardValueChangedHandler? { _bridge.keyChangedHandler }
    public func keyDown(_ key: GCKeyCode) {
        (_bridge as! PVEP128SystemResponderClient).keyDown(key)
    }
    public func keyUp(_ key: GCKeyCode) {
        (_bridge as! PVEP128SystemResponderClient).keyUp(key)
    }
#endif
}

extension PVEP128EmuCore: MouseResponder {
    public var gameSupportsMouse: Bool { true }
    public var requiresMouse: Bool { false }

#if canImport(GameController)
    public func didScroll(_ cursor: GCDeviceCursor) {
        (_bridge as! MouseResponder).didScroll(cursor)
    }
    public var mouseMovedHandler: GCMouseMoved? { nil }
#endif
    public func mouseMoved(atPoint point: CGPoint) {
        (_bridge as! MouseResponder).mouseMoved(atPoint: point)
    }
    public func mouseMoved(at point: CGPoint) {
        (_bridge as! MouseResponder).mouseMoved(atPoint: point)
    }
    public func leftMouseDown(at point: CGPoint) {
        (_bridge as! MouseResponder).leftMouseDown(atPoint: point)
    }
    public func leftMouseDown(atPoint point: CGPoint) {
        (_bridge as! MouseResponder).leftMouseDown(atPoint: point)
    }
    public func leftMouseUp() {
        (_bridge as! MouseResponder).leftMouseUp()
    }
    public func rightMouseDown(atPoint point: CGPoint) {
        (_bridge as! MouseResponder).rightMouseDown(atPoint: point)
    }
    public func rightMouseUp() {
        (_bridge as! MouseResponder).rightMouseUp()
    }
}

extension PVEP128EmuCore: PVMSXSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVMSXButton, forPlayer player: Int) {
        (_bridge as! PVMSXSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVMSXButton, forPlayer player: Int) {
        (_bridge as! PVMSXSystemResponderClient).didRelease(button, forPlayer: player)
    }

}
