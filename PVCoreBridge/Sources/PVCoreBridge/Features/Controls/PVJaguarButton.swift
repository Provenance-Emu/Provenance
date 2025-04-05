//
//  PVJaguarButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

// MARK: - Atari Jaguar

@objc public enum PVJaguarButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case a
    case b
    case c
    case pause
    case option
    @objc(PVJaguarButton1)
    case button1
    @objc(PVJaguarButton2)
    case button2
    @objc(PVJaguarButton3)
    case button3
    @objc(PVJaguarButton4)
    case button4
    @objc(PVJaguarButton5)
    case button5
    @objc(PVJaguarButton6)
    case button6
    @objc(PVJaguarButton7)
    case button7
    @objc(PVJaguarButton8)
    case button8
    @objc(PVJaguarButton9)
    case button9
    @objc(PVJaguarButton0)
    case button0
    case asterisk
    case pound
    case count

    public init(_ value: String) {
        switch value.lowercased() {
        case "up"     : self = .up
        case "down"   : self = .down
        case "left"   : self = .left
        case "right"  : self = .right
        case "1"      : self = .button1
        case "2"      : self = .button2
        case "3"      : self = .button3
        case "4"      : self = .button4
        case "5"      : self = .button5
        case "6"      : self = .button6
        case "7"      : self = .button7
        case "8"      : self = .button8
        case "9"      : self = .button9
        case "0"      : self = .button0
        case "*"      : self = .asterisk
        case "#"      : self = .pound
        case "pause"  : self = .pause
        case "option" : self = .option
        case "a"      : self = .a
        case "b"      : self = .b
        case "c"      : self = .c
        default       : self = .count
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
            case .c:
                return "c"
            case .pause:
                return "pause"
            case .option:
                return "option"
            case .button1:
                return "1"
            case .button2:
                return "2"
            case .button3:
                return "3"
            case .button4:
                return "4"
            case .button5:
                return "5"
            case .button6:
                return "6"
            case .button7:
                return "7"
            case .button8:
                return "8"
            case .button9:
                return "9"
            case .button0:
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

@objc public protocol PVJaguarSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushJaguarButton:forPlayer:) func didPush(jaguarButton button: PVJaguarButton, forPlayer player: Int)
    @objc(didReleaseJaguarButton:forPlayer:) func didRelease(jaguarButton button: PVJaguarButton, forPlayer player: Int)
}
