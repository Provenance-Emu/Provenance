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
protocol ControllerVC: StartSelectDelegate, JSButtonDelegate, JSDPadDelegate where Self: UIViewController {
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
}
#endif
