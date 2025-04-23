//
//  PV3DOButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - 3DO

@objc public enum PV3DOButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case a
    case b
    case c
    case L
    case R
    case P
    case X
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "a": self = .a
            case "b": self = .b
            case "c": self = .c
            case "l": self = .L
            case "r": self = .R
            case "p": self = .P
            case "x": self = .X
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
            case .c:
                return "c"
            case .L:
                return "l"
            case .R:
                return "r"
            case .P:
                return "p"
            case .X:
                return "x"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PV3DOSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPush3DOButton:forPlayer:)
    func didPush(_ button: PV3DOButton, forPlayer player: Int)
    @objc(didRelease3DOButton:forPlayer:)
    func didRelease(_ button: PV3DOButton, forPlayer player: Int)
}
