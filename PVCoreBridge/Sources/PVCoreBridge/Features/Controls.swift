//
//  Controls.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol ResponderClient: AnyObject {
    func sendEvent(_ event: UIEvent?)
}

#if canImport(GameController)
@_exported import GameController
#endif

@objc public protocol ButtonResponder {
#if canImport(GameController)
    @objc var valueChangedHandler: GCExtendedGamepadValueChangedHandler? { get }
#endif
//    func didPush(_ button: Int, forPlayer player: Int)
//    func didRelease(_ button: Int, forPlayer player: Int)
}

@objc public protocol JoystickResponder {
    @objc func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int)
}

@objc public protocol KeyboardResponder {
    @objc var gameSupportsKeyboard: Bool { get }
    @objc var requiresKeyboard: Bool { get }
#if canImport(GameController)
    @objc optional var keyChangedHandler: GCKeyboardValueChangedHandler? { get }
    @available(iOS 14.0, tvOS 14.0, *)
    @objc func keyDown(_ key: GCKeyCode)
    //	func keyDown(_ key: GCKeyCode, chararacters: String, charactersIgnoringModifiers: String)

    @available(iOS 14.0, tvOS 14.0, *)
    @objc func keyUp(_ key: GCKeyCode)
    //	func keyUp(_ key: GCKeyCode, chararacters: String, charactersIgnoringModifiers: String)
#endif
}

@objc public enum MouseButton: Int {
	case left
	case right
	case middle
	case auxiliary
}

@objc public protocol MouseResponder {
	var gameSupportsMouse: Bool { get }
	var requiresMouse: Bool { get }

#if canImport(GameController)
    @available(iOS 14.0, tvOS 14.0, *)
    func didScroll(_ cursor: GCDeviceCursor)

	var mouseMovedHandler: GCMouseMoved? { get }
#endif
	func mouseMoved(atPoint point: CGPoint)

	func leftMouseDown(atPoint point: CGPoint)
	func leftMouseUp()

	func rightMouseDown(atPoint point: CGPoint)
	func rightMouseUp()

	@objc optional func middleMouseDown(atPoint point: CGPoint)
	@objc optional func middleMouseUp(atPoint point: CGPoint)
}

/// Protocol for cores that support light gun peripherals (Zapper, Super Scope, Guncon, etc.).
/// All coordinates are normalized to the emulator screen space (0.0–1.0 in both axes),
/// where (0,0) is top-left and (1,1) is bottom-right.
/// The driver (GCMouse delta accumulation, UIPointerInteraction, or touch) calls these methods
/// when the user aims and fires.
@objc public protocol LightGunResponder: AnyObject {
    /// Whether this core/system supports a light gun device.
    var gameSupportsLightGun: Bool { get }
    /// Whether this core/system requires a light gun to be playable.
    var requiresLightGun: Bool { get }

    /// Update the current aim position in normalized screen coordinates (0.0–1.0).
    /// - Parameters:
    ///   - point: Normalized screen point. (0,0) = top-left, (1,1) = bottom-right.
    ///   - isOffscreen: `true` when the gun is pointed off-screen (reload gesture or cursor out of bounds).
    func lightGunMovedToPoint(_ point: CGPoint, isOffscreen: Bool)

    /// The primary trigger was pressed.
    func lightGunTriggerDown()
    /// The primary trigger was released.
    func lightGunTriggerUp()

    /// Auxiliary button A pressed (e.g. Super Scope pause, Guncon B).
    @objc optional func lightGunAuxADown()
    @objc optional func lightGunAuxAUp()
    /// Auxiliary button B pressed (e.g. Super Scope fire toggle, Guncon C).
    @objc optional func lightGunAuxBDown()
    @objc optional func lightGunAuxBUp()
    /// Start button (Guncon A / Super Scope start).
    @objc optional func lightGunStartDown()
    @objc optional func lightGunStartUp()
    /// Select / cursor button.
    @objc optional func lightGunSelectDown()
    @objc optional func lightGunSelectUp()
    /// Forced off-screen reload (right-click / long-press gesture).
    @objc optional func lightGunReloadDown()
    @objc optional func lightGunReloadUp()
}


//@objc extension PVEmulatorCore: ResponderClient {}

public protocol EmulatorCoreButton: JSButtonConvertible, CaseIterable, RawRepresentable where RawValue == Int {
}

public protocol JSButtonConvertible {
    init (_ value: String)
    var stringValue: String { get }
}

@objc public protocol PVRetroArchCoreResponderClient: ResponderClient, ButtonResponder, KeyboardResponder, MouseResponder, JoystickResponder {
}
