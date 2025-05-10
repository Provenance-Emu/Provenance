//
//  ControllerVC.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

#if canImport(UIKit)
import UIKit
import PVLibrary
import PVCoreBridge
import PVPlists
import PVRealm

/// Protocol for on-screen display controllers of type `UIViewController`
public protocol ControllerVC: StartSelectDelegate, JSButtonDelegate, JSDPadDelegate where Self: UIViewController {
	associatedtype ResponderType: ResponderClient
	var emulatorCore: ResponderType {get}
	var system: PVSystem {get set}
	var controlLayout: [ControlLayoutEntry] {get set}

	var dPad: JSDPad? {get}
	var dPad2: JSDPad? {get}
	var joyPad: JSDPad? { get }
    var joyPad2: JSDPad? { get }
	var buttonGroup: MovableButtonView? {get}
	var leftShoulderButton: JSButton? {get}
	var rightShoulderButton: JSButton? {get}
	var leftShoulderButton2: JSButton? {get}
	var rightShoulderButton2: JSButton? {get}
	var leftAnalogButton: JSButton? {get}
	var rightAnalogButton: JSButton? {get}
	var zTriggerButton: JSButton? { get set }
	var startButton: JSButton? {get}
	var selectButton: JSButton? {get}

	func layoutViews()
	func vibrate()
    
    func pressStart(forPlayer _: Int)
    func releaseStart(forPlayer _: Int)

    func pressSelect(forPlayer _: Int)

    func releaseSelect(forPlayer _: Int)

    func pressAnalogMode(forPlayer _: Int)

    func releaseAnalogMode(forPlayer _: Int)

    func pressL3(forPlayer _: Int)

    func releaseL3(forPlayer _: Int)

    func pressR3(forPlayer _: Int)

    func releaseR3(forPlayer _: Int)

    func buttonPressed(_: JSButton)
    func buttonReleased(_: JSButton)

    func dPad(_: JSDPad, didPress _: JSDPadDirection)

    func dPad(_: JSDPad, didRelease _: JSDPadDirection)
    func dPad(_: JSDPad, joystick _: JoystickValue)
    func dPad(_: JSDPad, joystick2 _: JoystickValue)

}
#endif
