//
//  PVLynxButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

// MARK: - Atari Lynx

@objc public enum PVLynxButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case a
    case b
    case option1
    case option2
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "a": self = .a
            case "b": self = .b
            case "option1", "o1": self = .option1
            case "option2", "o2": self = .option2
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
            case .option1:
                return "o1"
            case .option2:
                return "o2"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVLynxSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushLynxButton:forPlayer:)
    func didPush(LynxButton: PVLynxButton, forPlayer player: Int)
    @objc(didReleaseLynxButton:forPlayer:)
    func didRelease(LynxButton: PVLynxButton, forPlayer player: Int)
}
