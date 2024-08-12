//
//  JSButtonDisplayer.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

#if canImport(UIKit)
import UIKit
public typealias ButtonGroupView = UIView
#elseif canImport(AppKit)
import AppKit
public typealias ButtonGroupView = NSView
#endif
protocol JSButtonDisplayer {
	var dPad: JSDPad? { get set }
	var dPad2: JSDPad? { get set }
    var joyPad: JSDPad? { get set }
    var joyPad2: JSDPad? { get set }
	var buttonGroup: ButtonGroupView? { get set }
	var leftShoulderButton: JSButton? { get set }
	var rightShoulderButton: JSButton? { get set }
	var leftShoulderButton2: JSButton? { get set }
	var rightShoulderButton2: JSButton? { get set }
	var leftAnalogButton: JSButton? { get set }
	var rightAnalogButton: JSButton? { get set }
	var zTriggerButton: JSButton? { get set }
	var startButton: JSButton? { get set }
	var selectButton: JSButton? { get set }
}
