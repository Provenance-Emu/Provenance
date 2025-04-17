//
//  PV5200Button.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Atari 5200

@objc public enum PV5200Button: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case fire1
    case fire2
    case start
    case pause
    case reset
    case number1
    case number2
    case number3
    case number4
    case number5
    case number6
    case number7
    case number8
    case number9
    case number0
    case asterisk
    case pound
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "fire1", "a": self = .fire1
            case "fire2", "b": self = .fire2
            case "start", "s": self = .start
            case "pause", "p": self = .pause
            case "reset", "r": self = .reset
            case "number1", "1": self = .number1
            case "number2", "2": self = .number2
            case "number3", "3": self = .number3
            case "number4", "4": self = .number4
            case "number5", "5": self = .number5
            case "number6", "6": self = .number6
            case "number7", "7": self = .number7
            case "number8", "8": self = .number8
            case "number9", "9": self = .number9
            case "number0", "0": self = .number0
            case "asterisk", "*": self = .asterisk
            case "pound", "#": self = .pound
            case "count": self = .count
            default: self = .up
        }
    }

    public var stringValue: String {
        switch self {
            case .up:
                return "up"
            case .down:
                return "down"
            case .left:
                return "left"
            case .right:
                return "right"
            case .fire1:
                return "fire1"
            case .fire2:
                return "fire2"
            case .start:
                return "start"
            case .pause:
                return "pause"
            case .reset:
                return "reset"
            case .number1:
                return "1"
            case .number2:
                return "2"
            case .number3:
                return "3"
            case .number4:
                return "4"
            case .number5:
                return "5"
            case .number6:
                return "6"
            case .number7:
                return "7"
            case .number8:
                return "8"
            case .number9:
                return "9"
            case .number0:
                return "0"
            case .asterisk:
                return "*"
            case .pound:
                return "#"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PV5200SystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPush5200Button:forPlayer:)
    func didPush(_ button: PV5200Button, forPlayer player: Int)
    @objc(didRelease5200Button:forPlayer:)
    func didRelease(_ button: PV5200Button, forPlayer player: Int)

    @objc(didMove5200JoystickDirection:withValue:forPlayer:)
    func didMoveJoystick(_ button: PV5200Button, withValue value: CGFloat, forPlayer player: Int)
}
