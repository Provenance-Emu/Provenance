//
//  PVOdyssey2Button.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Magnavox Odyssey2/Videopac+

@objc public enum PVOdyssey2Button: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case action
    case count
    case key0
    case key1
    case key2
    case key3
    case key4
    case key5
    case key6
    case key7
    case key8
    case key9

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "action", "a", "i", "b", "x", "y": self = .action
            case "count": self = .count
            case "0", "key0": self = .key0
            case "1", "key1": self = .key1
            case "2", "key2": self = .key2
            case "3", "key3": self = .key3
            case "4", "key4": self = .key4
            case "5", "key5": self = .key5
            case "6", "key6": self = .key6
            case "7", "key7": self = .key7
            case "8", "key8": self = .key8
            case "9", "key9": self = .key9
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
            case .action:
                return "action"
            case .count:
                return "count"
            case .key0:
                return "0"
            case .key1:
                return "1"
            case .key2:
                return "2"
            case .key3:
                return "3"
            case .key4:
                return "4"
            case .key5:
                return "5"
            case .key6:
                return "6"
            case .key7:
                return "7"
            case .key8:
                return "8"
            case .key9:
                return "9"
        }
    }
}

@objc public protocol PVOdyssey2SystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushOdyssey2Button:forPlayer:)
    func didPush(_ button: PVOdyssey2Button, forPlayer player: Int)
    @objc(didReleaseOdyssey2Button:forPlayer:)
    func didRelease(_ button: PVOdyssey2Button, forPlayer player: Int)
}
