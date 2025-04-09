//
//  PVPS2Button.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - PS2

@objc public enum PVPS2Button: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case triangle
    case circle
    case cross
    case square
    case l1
    case l2
    case l3
    case r1
    case r2
    case r3
    case start
    case select
    case analogMode
    case leftAnalogUp
    case leftAnalogDown
    case leftAnalogLeft
    case leftAnalogRight
    case rightAnalogUp
    case rightAnalogDown
    case rightAnalogLeft
    case rightAnalogRight
    case leftAnalog
    case rightAnalog
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "triangle", "a", "▵": self = .triangle
            case "circle", "b", "○": self = .circle
            case "cross", "x", "✕": self = .cross
            case "square", "y", "□": self = .square
            case "l1", "l", "lb": self = .l1
            case "l2", "l2", "lb": self = .l2
            case "l3", "l3", "lb": self = .l3
            case "r1", "r", "rb": self = .r1
            case "r2", "r2", "rb": self = .r2
            case "r3", "r3", "rb": self = .r3
            case "start": self = .start
            case "select": self = .select
            case "analogMode": self = .analogMode
            case "leftAnalogUp": self = .leftAnalogUp
            case "leftAnalogDown": self = .leftAnalogDown
            case "leftAnalogLeft": self = .leftAnalogLeft
            case "leftAnalogRight": self = .leftAnalogRight
            case "rightAnalogUp": self = .rightAnalogUp
            case "rightAnalogDown": self = .rightAnalogDown
            case "rightAnalogLeft": self = .rightAnalogLeft
            case "rightAnalogRight": self = .rightAnalogRight
            case "leftAnalog": self = .leftAnalog
            case "rightAnalog": self = .rightAnalog
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
            case .triangle:
                return "▵"
            case .circle:
                return "○"
            case .cross:
                return "✕"
            case .square:
                return "□"
            case .l1:
                return "l1"
            case .l2:
                return "l2"
            case .l3:
                return "l3"
            case .r1:
                return "r1"
            case .r2:
                return "r2"
            case .r3:
                return "r3"
            case .start:
                return "start"
            case .select:
                return "select"
            case .analogMode:
                return "analogMode"
            case .leftAnalogUp:
                return "leftAnalogUp"
            case .leftAnalogDown:
                return "leftAnalogDown"
            case .leftAnalogLeft:
                return "leftAnalogLeft"
            case .leftAnalogRight:
                return "leftAnalogRight"
            case .rightAnalogUp:
                return "rightAnalogUp"
            case .rightAnalogDown:
                return "rightAnalogDown"
            case .rightAnalogLeft:
                return "rightAnalogLeft"
            case .rightAnalogRight:
                return "rightAnalogRight"
            case .leftAnalog:
                return "leftAnalog"
            case .rightAnalog:
                return "rightAnalog"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVPS2SystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPushPS2Button:forPlayer:)
    func didPush(_ button: PVPS2Button, forPlayer player: Int)

    @objc(didReleasePS2Button:forPlayer:)
    func didRelease(_ button: PVPS2Button, forPlayer player: Int)

    @objc(didMovePS2JoystickDirection:withXValue:withYValue:forPlayer:)
    func didMoveJoystick(_ button: PVPS2Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int)
}
