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
open class PVGMECore: PVEmulatorCore {

    let _bridge: PVGMECoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVGMECore: PVNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVGMECore: PVDOSSystemResponderClient {
    public func mouseMoved(at point: CGPoint) {
        (_bridge as! PVDOSSystemResponderClient).mouseMoved(at: point)
    }
    public func leftMouseDown(at point: CGPoint) {
        (_bridge as! PVDOSSystemResponderClient).leftMouseDown(at: point)
    }
    public func leftMouseUp() {
        (_bridge as! PVDOSSystemResponderClient).leftMouseUp()
    }
    public var gameSupportsKeyboard: Bool {
        (_bridge as! PVDOSSystemResponderClient).gameSupportsKeyboard
    }
    public var requiresKeyboard: Bool {
        (_bridge as! PVDOSSystemResponderClient).requiresKeyboard
    }
    public func keyDown(_ key: GCKeyCode) {
        (_bridge as! PVDOSSystemResponderClient).keyDown(key)
    }
    public func keyUp(_ key: GCKeyCode) {
        (_bridge as! PVDOSSystemResponderClient).keyUp(key)
    }
    public var gameSupportsMouse: Bool {
        (_bridge as! PVDOSSystemResponderClient).gameSupportsMouse
    }
    public var requiresMouse: Bool {
        (_bridge as! PVDOSSystemResponderClient).requiresMouse
    }
    public func didScroll(_ cursor: GCDeviceCursor) {
        (_bridge as! PVDOSSystemResponderClient).didScroll(cursor)
    }
    public var mouseMovedHandler: GCMouseMoved? {
        (_bridge as! PVDOSSystemResponderClient).mouseMovedHandler
    }
    public func mouseMoved(atPoint point: CGPoint) {
        (_bridge as! PVDOSSystemResponderClient).mouseMoved(atPoint: point)
    }
    public func leftMouseDown(atPoint point: CGPoint) {
        (_bridge as! PVDOSSystemResponderClient).leftMouseDown(atPoint: point)
    }
    public func rightMouseDown(atPoint point: CGPoint) {
        (_bridge as! PVDOSSystemResponderClient).rightMouseDown(atPoint: point)
    }
    public func rightMouseUp() {
        (_bridge as! PVDOSSystemResponderClient).rightMouseUp()
    }
    public func didPush(_ button: PVCoreBridge.PVDOSButton, forPlayer player: Int) {
        (_bridge as! PVDOSSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVDOSButton, forPlayer player: Int) {
        (_bridge as! PVDOSSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
