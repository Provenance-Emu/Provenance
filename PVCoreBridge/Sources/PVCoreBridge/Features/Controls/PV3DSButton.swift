//
//  PV3DSButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Nintendo 3DS

@objc public enum PV3DSButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case a
    case b
    case x
    case y
    case l
    case r
    case zl
    case zr
    case start
    case select
    case rightAnalogUp
    case rightAnalogDown
    case rightAnalogLeft
    case rightAnalogRight
    case rightAnalog
    case leftAnalogUp
    case leftAnalogDown
    case leftAnalogLeft
    case leftAnalogRight
    case leftAnalog
    case swap
    case rotate
    case analogMode
    case home
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "a": self = .a
            case "b": self = .b
            case "x": self = .x
            case "y": self = .y
            case "l": self = .l
            case "r": self = .r
            case "zl": self = .zl
            case "zr": self = .zr
            case "start": self = .start
            case "select": self = .select
            case "rightanalogup": self = .rightAnalogUp
            case "rightanalogdown": self = .rightAnalogDown
            case "rightanalogleft": self = .rightAnalogLeft
            case "rightanalogright": self = .rightAnalogRight
            case "rightanalog": self = .rightAnalog
            case "leftanalogup": self = .leftAnalogUp
            case "leftanalogdown": self = .leftAnalogDown
            case "leftanalogleft": self = .leftAnalogLeft
            case "leftanalogright": self = .leftAnalogRight
            case "leftanalog": self = .leftAnalog
            case "swap": self = .swap
            case "rotate": self = .rotate
            case "analogMode": self = .analogMode
            case "home": self = .home
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
            case .a:
                return "a"
            case .b:
                return "b"
            case .x:
                return "x"
            case .y:
                return "y"
            case .l:
                return "l"
            case .r:
                return "r"
            case .zl:
                return "zl"
            case .zr:
                return "zr"
            case .start:
                return "start"
            case .select:
                return "select"
            case .rightanalogup:
                return "rightanalogup"
            case .rightanalogdown:
                return "rightanalogdown"
            case .rightanalogleft:
                return "rightanalogleft"
            case .rightanalogright:
                return "rightanalogright"
            case .rightanalog:
                return "rightanalog"
            case .leftanalogup:
                return "leftanalogup"
            case .leftanalogdown:
                return "leftanalogdown"
            case .leftanalogleft:
                return "leftanalogleft"
            case .leftanalogright:
                return "leftanalogright"
            case .leftAnalog:
                return "leftAnalog"
            case .swap:
                return "swap"
            case .rotate:
                return "rotate"
            case .analogMode:
                return "analogMode"
            case .home:
                return "home"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PV3DSSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPush3DSButton:forPlayer:)
    func didPush(_ button: PV3DSButton, forPlayer player: Int)
    @objc(didRelease3DSButton:forPlayer:)
    func didRelease(_ button: PV3DSButton, forPlayer player: Int)
    @objc(didMove3DSJoystickDirection:withXValue:withYValue:forPlayer:)
    func didMoveJoystick(_ button: PV3DSButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int)
}
