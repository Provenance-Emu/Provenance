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
}

@objc public enum Touchpad: Int {
	case primary
	case secondary
}

@objc public protocol TouchPadResponder {
#if canImport(GameController)
	var touchedChangedHandler: GCControllerButtonTouchedChangedHandler? { get }
	var pressedChangedHandler: GCControllerButtonValueChangedHandler? { get }
	var valueChangedHandler: GCControllerButtonValueChangedHandler? { get }
#endif

	var gameSupportsTouchpad: Bool { get }
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
