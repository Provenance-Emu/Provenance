//
//  PVFreeIntVCore.swift
//  PVFreeIntVCore
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
open class PVFreeIntvCore: PVEmulatorCore {

    let _bridge: PVFreeIntvCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVFreeIntvCore: PVIntellivisionSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVIntellivisionButton, forPlayer player: Int) {
        (_bridge as! PVIntellivisionSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVIntellivisionButton, forPlayer player: Int) {
        (_bridge as! PVIntellivisionSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVFreeIntvCore: MouseResponder {
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
