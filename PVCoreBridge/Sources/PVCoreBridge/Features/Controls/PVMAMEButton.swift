//
//  PVMAMEButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


@objc public enum PVMAMEButton: Int, EmulatorCoreButton {
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
            case "l1", "l": self = .l1
            case "l2", "lt": self = .l2
            case "l3": self = .l3
            case "r1", "r": self = .r1
            case "r2", "rt": self = .r2
            case "r3": self = .r3
            case "start", "mode": self = .start
            case "select", "back", "cbdc": self = .select
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
                return "cbdc"
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

@objc public protocol PVMAMESystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPushMAMEButton:forPlayer:)
    func didPush(_ button: PVMAMEButton, forPlayer player: Int)

    @objc(didReleaseMAMEButton:forPlayer:)
    func didRelease(_ button: PVMAMEButton, forPlayer player: Int)

    @objc(didMoveMAMEJoystickDirection:withXValue:withYValue:forPlayer:)
    func didMoveJoystick(_ button: PVMAMEButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int)
}
