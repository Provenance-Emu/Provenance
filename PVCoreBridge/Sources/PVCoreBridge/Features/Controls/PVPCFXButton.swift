//
//  PVPCFXButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//



// MARK: - PCE FX

@objc public enum PVPCFXButton: Int, EmulatorCoreButton {
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
    case turboI
    case turboII
    case count

    public init(_ value: String) {
        switch value.lowercased() {
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
            case "run": self = .run
            case "select": self = .select
            case "mode": self = .mode
            case "turboi", "turbo1", "turbo_i": self = .turboI
            case "turboii", "turbo2", "turbo_ii": self = .turboII
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
            case .turboI:
                return "turboi"
            case .turboII:
                return "turboii"
            case .count:
                return "count"
        }
    }
}

// MARK: - Hardware switches

extension PVPCFXButton: HardwareSwitchProvider {
    public static var hardwareSwitches: [HardwareSwitchDescriptor]? {
        [
            HardwareSwitchDescriptor(
                id: "turbo_i",
                title: "TURBO I",
                offPosition: HardwareSwitchPosition(label: "OFF", buttonId: "turboi"),
                onPosition:  HardwareSwitchPosition(label: "ON", buttonId: "turboi"),
                defaultState: false
            ),
            HardwareSwitchDescriptor(
                id: "turbo_ii",
                title: "TURBO II",
                offPosition: HardwareSwitchPosition(label: "OFF", buttonId: "turboii"),
                onPosition:  HardwareSwitchPosition(label: "ON", buttonId: "turboii"),
                defaultState: false
            )
        ]
    }
}

@objc public protocol PVPCFXSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPCFXButton:forPlayer:)
    func didPush(_ button: PVPCFXButton, forPlayer player: Int)
    @objc(didReleasePCFXButton:forPlayer:)
    func didRelease(_ button: PVPCFXButton, forPlayer player: Int)
}
