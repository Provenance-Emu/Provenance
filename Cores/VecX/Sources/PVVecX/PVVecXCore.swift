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
open class PVVecXCore: PVEmulatorCore {

    let _bridge: PVVecXCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVVecXCore: PVVectrexSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVVectrexButton, withValue value: CGFloat, forPlayer player: Int) {
        (_bridge as! PVVectrexSystemResponderClient).didMoveJoystick(button, withValue: value, forPlayer: player    )
    }
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVVectrexSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVVectrexButton, forPlayer player: Int) {
        (_bridge as! PVVectrexSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVVectrexButton, forPlayer player: Int) {
        (_bridge as! PVVectrexSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVVecXCore: MouseResponder {
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
