//
//  PViCadeInputAxis.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/29/18.
//  Copyright (c) 2018 Joseph Mattiello. All rights reserved.
//


public struct iCadeControllerState: OptionSet {
	public let rawValue: Int

	public init(rawValue : Int) {
		self.rawValue = rawValue
	}
	
    static let joystickNone                  = iCadeControllerState(rawValue: 1 << 0)
    static let joystickUp                    = iCadeControllerState(rawValue: 1 << 1)
    static let joystickRight                 = iCadeControllerState(rawValue: 1 << 2)
    static let joystickDown                  = iCadeControllerState(rawValue: 1 << 3)
    static let joystickLeft                  = iCadeControllerState(rawValue: 1 << 4)
    static let joystickUpRight: iCadeControllerState   = [.joystickUp, .joystickRight]
    static let joystickDownRight: iCadeControllerState = [.joystickDown, .joystickRight]
    static let joystickUpLeft: iCadeControllerState    = [.joystickUp, .joystickLeft]
	static let joystickDownLeft: iCadeControllerState  = [.joystickDown, .joystickLeft]

	static let buttonA = iCadeControllerState(rawValue: 1 << 5)
	static let buttonB = iCadeControllerState(rawValue: 1 << 6)
	static let buttonC = iCadeControllerState(rawValue: 1 << 7)
	static let buttonD = iCadeControllerState(rawValue: 1 << 8)
	static let buttonE = iCadeControllerState(rawValue: 1 << 9)
	static let buttonF = iCadeControllerState(rawValue: 1 << 10)
	static let buttonG = iCadeControllerState(rawValue: 1 << 11)
	static let buttonH = iCadeControllerState(rawValue: 1 << 12)
	static let buttonI = iCadeControllerState(rawValue: 1 << 13) // Mocute Left Trigger
	static let buttonJ = iCadeControllerState(rawValue: 1 << 14) // Mocute Right Trigger
	static let buttonK = iCadeControllerState(rawValue: 1 << 15)
	static let buttonL = iCadeControllerState(rawValue: 1 << 16)

	static let joystickStates: iCadeControllerState = [.joystickUp, .joystickDown, .joystickLeft, .joystickRight]
	static let buttons: iCadeControllerState = [
		.buttonA,
		.buttonB,
		.buttonC,
		.buttonD,
		.buttonE,
		.buttonF,
		.buttonG,
		.buttonH,
		.buttonI,
		.buttonJ,
		.buttonK,
		.buttonL]
}

public protocol iCadeEventDelegate : class {
	func stateChanged(state : iCadeControllerState)
	func buttonDown(button : Int)
	func buttonUp(button : Int)
}
