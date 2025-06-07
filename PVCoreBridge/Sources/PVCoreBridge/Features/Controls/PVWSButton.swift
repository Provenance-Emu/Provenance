//
//  PVWSButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - WonderSwan

@objc public enum PVWSButton: Int, EmulatorCoreButton {
    case x1
    // Up
    case x3
    // Down
    case x4
    // Left
    case x2
    // Right
    case y1
    case y3
    case y4
    case y2
    case a
    case b
    case start
    case sound
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "x1": self = .x1
            case "x3": self = .x3
            case "x4": self = .x4
            case "x2": self = .x2
            case "y1": self = .y1
            case "y3": self = .y3
            case "y4": self = .y4
            case "y2": self = .y2
            case "a": self = .a
            case "b": self = .b
            case "start": self = .start
            case "sound": self = .sound
            case "count": self = .count
            default: self = .x1
        }
    }

    public var stringValue: String {
        switch self {
            case .x1:
                return "x1"
            case .x3:
                return "x3"
            case .x4:
                return "x4"
            case .x2:
                return "x2"
            case .y1:
                return "y1"
            case .y3:
                return "y3"
            case .y4:
                return "y4"
            case .y2:
                return "y2"
            case .a:
                return "a"
            case .b:
                return "b"
            case .start:
                return "start"
            case .sound:
                return "sound"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVWonderSwanSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushWSButton:forPlayer:)
    func didPush(_ button: PVWSButton, forPlayer player: Int)
    @objc(didReleaseWSButton:forPlayer:)
    func didRelease(_ button: PVWSButton, forPlayer player: Int)
}
