//
//  PVSG1000Button.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - SG1000

@objc public enum PVSG1000Button: Int, EmulatorCoreButton {
    case b = 0
    case c
    case start
    case up
    case down
    case left
    case right
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "b": self = .b
            case "c": self = .c
            case "start": self = .start
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "count": self = .count
            default: self = .b
        }
    }

    public var stringValue: String {
        switch self {
            case .b:
                return "b"
            case .c:
                return "c"
            case .start:
                return "start"
            case .up:
                return "up"
            case .down:
                return "down"
            case .left:
                return "left"
            case .right:
                return "right"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVSG1000SystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushSG1000Button:forPlayer:)
    func didPush(_ button: PVSG1000Button, forPlayer player: Int)
    @objc(didReleaseSG1000Button:forPlayer:)
    func didRelease(_ button: PVSG1000Button, forPlayer player: Int)
}
