//
//  PV2600Button.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Atari 2600

@objc public enum PV2600Button: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case fire1
    case leftDiffA
    case leftDiffB
    case rightDiffA
    case rightDiffB
    case reset
    case select
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "fire1": self = .fire1
            case "leftdiffa": self = .leftDiffA
            case "leftdiffb": self = .leftDiffB
            case "rightdiffa": self = .rightDiffA
            case "rightdiffb": self = .rightDiffB
            case "reset": self = .reset
            case "select": self = .select
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
            case .fire1:
                return "fire1"
            case .leftDiffA:
                return "leftdiffa"
            case .leftDiffB:
                return "leftdiffb"
            case .rightDiffA:
                return "rightdiffa"
            case .rightDiffB:
                return "rightdiffb"
            case .reset:
                return "reset"
            case .select:
                return "select"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PV2600SystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPV2600Button:forPlayer:)
    func didPush(_ button: PV2600Button, forPlayer player: Int)
    @objc(didReleasePV2600Button:forPlayer:)
    func didRelease(_ button: PV2600Button, forPlayer player: Int)
}
