//
//  PVPCECDButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - PCE CD

@objc public enum PVPCECDButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case button1
    case button2
    case button3
    case button4
    case button5
    case button6
    case run
    case select
    case mode
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "button1", "1", "i": self = .button1
            case "button2", "2", "ii": self = .button2
            case "button3", "3", "iii": self = .button3
            case "button4", "4", "iv": self = .button4
            case "button5", "5", "v": self = .button5
            case "button6", "6", "vi": self = .button6
            case "run": self = .run
            case "select": self = .select
            case "mode": self = .mode
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
            case .run:
                return "run"
            case .select:
                return "select"
            case .mode:
                return "mode"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVPCECDSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPCECDButton:forPlayer:)
    func didPush(_ button: PVPCECDButton, forPlayer player: Int)
    @objc(didReleasePCECDButton:forPlayer:)
    func didRelease(_ button: PVPCECDButton, forPlayer player: Int)
}
