//
//  PVMasterSystemButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Master System

@objc public enum PVMasterSystemButton: Int, EmulatorCoreButton {
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

@objc public protocol PVMasterSystemSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushMasterSystemButton:forPlayer:)
    func didPush(_ button: PVMasterSystemButton, forPlayer player: Int)
    @objc(didReleaseMasterSystemButton:forPlayer:)
    func didRelease(_ button: PVMasterSystemButton, forPlayer player: Int)
}
