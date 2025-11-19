//
//  PVPCEButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - PCE

@objc public enum PVPCEButton: Int, EmulatorCoreButton {
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
        /// Normalize Unicode Roman numerals to ASCII equivalents
        let normalized = value
            .replacingOccurrences(of: "ⅰ", with: "i")
            .replacingOccurrences(of: "ⅱ", with: "ii")
            .replacingOccurrences(of: "ⅲ", with: "iii")
            .replacingOccurrences(of: "ⅳ", with: "iv")
            .replacingOccurrences(of: "ⅴ", with: "v")
            .replacingOccurrences(of: "ⅵ", with: "vi")
            .replacingOccurrences(of: "Ⅰ", with: "i")
            .replacingOccurrences(of: "Ⅱ", with: "ii")
            .replacingOccurrences(of: "Ⅲ", with: "iii")
            .replacingOccurrences(of: "Ⅳ", with: "iv")
            .replacingOccurrences(of: "Ⅴ", with: "v")
            .replacingOccurrences(of: "Ⅵ", with: "vi")

        switch normalized.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "button1", "1", "i", "a": self = .button1
            case "button2", "2", "ii", "b": self = .button2
            case "button3", "3", "iii", "x": self = .button3
            case "button4", "4", "iv", "y": self = .button4
            case "button5", "5", "v": self = .button5
            case "button6", "6", "vi": self = .button6
            case "run", "start": self = .run
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

@objc public protocol PVPCESystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPCEButton:forPlayer:)
    func didPush(_ button: PVPCEButton, forPlayer player: Int)
    @objc(didReleasePCEButton:forPlayer:)
    func didRelease(_ button: PVPCEButton, forPlayer player: Int)
}
