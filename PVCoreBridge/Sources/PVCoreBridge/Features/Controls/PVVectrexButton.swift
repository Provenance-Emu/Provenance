//
//  PVVectrexButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Vectrex

@objc public enum PVVectrexButton: Int, EmulatorCoreButton {
    @objc(PVVectrexAnalogUp)
    case analogUp
    @objc(PVVectrexAnalogDown)
    case analogDown
    @objc(PVVectrexAnalogLeft)
    case analogLeft
    @objc(PVVectrexAnalogRight)
    case analogRight
    @objc(PVVectrexButton1)
    case button1
    @objc(PVVectrexButton2)
    case button2
    @objc(PVVectrexButton3)
    case button3
    @objc(PVVectrexButton4)
    case button4
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .analogUp
            case "down": self = .analogDown
            case "left": self = .analogLeft
            case "right": self = .analogRight
            case "button1", "1", "i": self = .button1
            case "button2", "2", "ii": self = .button2
            case "button3", "3", "iii": self = .button3
            case "button4", "4", "iv": self = .button4
            case "count": self = .count
            default: self = .analogUp
        }
    }

    public var stringValue: String {
        switch self {
            case .analogUp:
                return "up"
            case .analogDown:
                return "down"
            case .analogLeft:
                return "left"
            case .analogRight:
                return "right"
            case .button1:
                return "1"
            case .button2:
                return "2"
            case .button3:
                return "3"
            case .button4:
                return "4"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVVectrexSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didMoveVectrexJoystickDirection:withValue:forPlayer:)
    func didMoveJoystick(_ button: PVVectrexButton, withValue value: CGFloat, forPlayer player: Int)
    @objc(didPushVectrexButton:forPlayer:)
    func didPush(_ button: PVVectrexButton, forPlayer player: Int)
    @objc(didReleaseVectrexButton:forPlayer:)
    func didRelease(_ button: PVVectrexButton, forPlayer player: Int)
}
