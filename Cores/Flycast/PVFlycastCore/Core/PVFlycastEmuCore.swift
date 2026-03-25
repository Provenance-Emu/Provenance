//
//  PVFlycastEmuCore.swift
//  PVFlycastEmuCore
//
//  Created by Joseph Mattiello on 10/06/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVCoreBridgeRetro
import PVSystems

@objc
@objcMembers
open class PVFlycastEmuCore: PVEmulatorCore {

    let _bridge: PVFlycastCoreBridge = .init()

    /// On iOS the Flycast libretro bridge checks RETRO_ENVIRONMENT_GET_JIT_CAPABLE
    /// and refuses to load a game if JIT is unavailable, logging
    /// "Cannot run without JIT" and returning false from retro_load_game.
    /// JIT is therefore required on iOS — running without it is not possible.
    open override var jitRequirement: PVJITRequirement { .requiredOrCrash }

    /// Tracks whether the Dreamcast mouse port has been configured this session.
    /// Ensures the retro_set_controller_port_device call is issued only once.
    var _didConfigureMousePort: Bool = false

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVFlycastEmuCore: PVDreamcastSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVDreamcastButton, forPlayer player: Int) {
        (_bridge as! PVDreamcastSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVDreamcastButton, forPlayer player: Int) {
        (_bridge as! PVDreamcastSystemResponderClient).didRelease(button, forPlayer: player)
    }
    
    public var gameSupportsKeyboard: Bool { true }
    public var requiresKeyboard: Bool { false }
#if canImport(GameController)
//    @objc optional var keyChangedHandler: GCKeyboardValueChangedHandler? { _bridge.keyChangedHandler }
    public func keyDown(_ key: GCKeyCode) {
        (_bridge as! PVDreamcastSystemResponderClient).keyDown(key)
    }
    public func keyUp(_ key: GCKeyCode) {
        (_bridge as! PVDreamcastSystemResponderClient).keyUp(key)
    }
#endif
}

extension PVFlycastEmuCore: MouseResponder {
    /// Returns true only for known Dreamcast mouse games, checked via MouseGameRegistry.
    /// Non-mouse games will use the standard controller without a mouse overlay.
    public var gameSupportsMouse: Bool {
        MouseGameRegistry.shared.gameSupportsMouse(
            systemIdentifier: .Dreamcast,
            md5: romMD5,
            title: romName
        )
    }

    public var requiresMouse: Bool { false }

    /// Lazily configures the Dreamcast mouse port once per game session.
    /// Caches the result so the device-type switch is issued exactly once,
    /// not on every input event (mouseMoved, leftMouseDown, etc.).
    /// The flag is set only when configuration succeeds — if the core is not
    /// yet initialised the call returns false and we retry on the next event.
    private func ensureMousePortConfigured() {
        guard !_didConfigureMousePort else { return }
        _didConfigureMousePort = _bridge.configureDreamcastMousePort()
    }

#if canImport(GameController)
    public func didScroll(_ cursor: GCDeviceCursor) {
        ensureMousePortConfigured()
        (_bridge as! MouseResponder).didScroll(cursor)
    }
    public var mouseMovedHandler: GCMouseMoved? { nil }
#endif
    public func mouseMoved(atPoint point: CGPoint) {
        ensureMousePortConfigured()
        (_bridge as! MouseResponder).mouseMoved(atPoint: point)
    }
    public func mouseMoved(at point: CGPoint) {
        ensureMousePortConfigured()
        (_bridge as! MouseResponder).mouseMoved(atPoint: point)
    }
    public func leftMouseDown(at point: CGPoint) {
        ensureMousePortConfigured()
        (_bridge as! MouseResponder).leftMouseDown(atPoint: point)
    }
    public func leftMouseDown(atPoint point: CGPoint) {
        ensureMousePortConfigured()
        (_bridge as! MouseResponder).leftMouseDown(atPoint: point)
    }
    public func leftMouseUp() {
        ensureMousePortConfigured()
        (_bridge as! MouseResponder).leftMouseUp()
    }
    public func rightMouseDown(atPoint point: CGPoint) {
        ensureMousePortConfigured()
        (_bridge as! MouseResponder).rightMouseDown(atPoint: point)
    }
    public func rightMouseUp() {
        ensureMousePortConfigured()
        (_bridge as! MouseResponder).rightMouseUp()
    }
}
