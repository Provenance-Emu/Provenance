//
//  PViCadeInputAxis.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/29/18.
//  Copyright (c) 2018 Joseph Mattiello. All rights reserved.
//

public struct iCadeControllerState: OptionSet, Hashable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public var hashValue: Int {
        return rawValue
    }

    static let none = iCadeControllerState([])
    static let joystickUp = iCadeControllerState(rawValue: 1 << 0)
    static let joystickRight = iCadeControllerState(rawValue: 1 << 1)
    static let joystickDown = iCadeControllerState(rawValue: 1 << 2)
    static let joystickLeft = iCadeControllerState(rawValue: 1 << 3)
    static let joystickUpRight: iCadeControllerState = [.joystickUp, .joystickRight]
    static let joystickDownRight: iCadeControllerState = [.joystickDown, .joystickRight]
    static let joystickUpLeft: iCadeControllerState = [.joystickUp, .joystickLeft]
    static let joystickDownLeft: iCadeControllerState = [.joystickDown, .joystickLeft]

    static let buttonA = iCadeControllerState(rawValue: 1 << 4)
    static let buttonB = iCadeControllerState(rawValue: 1 << 5)
    static let buttonC = iCadeControllerState(rawValue: 1 << 6)
    static let buttonD = iCadeControllerState(rawValue: 1 << 7)
    static let buttonE = iCadeControllerState(rawValue: 1 << 8)
    static let buttonF = iCadeControllerState(rawValue: 1 << 9)
    static let buttonG = iCadeControllerState(rawValue: 1 << 10)
    static let buttonH = iCadeControllerState(rawValue: 1 << 11)
    static let buttonI = iCadeControllerState(rawValue: 1 << 13) // Mocute Left Trigger
    static let buttonJ = iCadeControllerState(rawValue: 1 << 13) // Mocute Right Trigger
    static let buttonK = iCadeControllerState(rawValue: 1 << 14)
    static let buttonL = iCadeControllerState(rawValue: 1 << 15)

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
        .buttonL
    ]

    public var description: String {
        var result = [String]()
        for key in iCadeControllerState.debugDescriptions.keys {
            guard contains(key),
                let description = iCadeControllerState.debugDescriptions[key]
            else { continue }
            result.append(description)
        }
        return "iCadeControllerState(rawValue: \(rawValue)) \(result)"
    }

    static var debugDescriptions: [iCadeControllerState: String] = {
        var descriptions = [iCadeControllerState: String]()

        descriptions[.joystickUp] = "JoyUp"
        descriptions[.joystickDown] = "JoyDown"
        descriptions[.joystickLeft] = "JoyLeft"
        descriptions[.joystickRight] = "JoyRight"

        descriptions[.buttonA] = "A"
        descriptions[.buttonB] = "B"
        descriptions[.buttonC] = "C"
        descriptions[.buttonD] = "D"
        descriptions[.buttonE] = "E"
        descriptions[.buttonF] = "F"
        descriptions[.buttonG] = "G"
        descriptions[.buttonH] = "H"
        descriptions[.buttonI] = "I"
        descriptions[.buttonJ] = "J"
        descriptions[.buttonK] = "K"
        descriptions[.buttonL] = "L"

        return descriptions
    }()
}

public protocol iCadeEventDelegate: AnyObject {
    func stateChanged(state: iCadeControllerState)
    func buttonDown(button: iCadeControllerState)
    func buttonUp(button: iCadeControllerState)
}
