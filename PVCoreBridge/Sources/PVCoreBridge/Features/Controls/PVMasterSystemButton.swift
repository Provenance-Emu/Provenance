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
            case "b", "a": self = .b
            case "c", "x", "y": self = .c
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

// MARK: - Hardware momentary buttons

/// The SMS Pause button is a physical button on the console (not the controller).
/// It generates an NMI (Non-Maskable Interrupt) — a momentary edge signal, not a
/// toggle. The `start` button ID is the standard mapping used by SMS emulator cores.
extension PVMasterSystemButton: HardwareSwitchProvider {
    public static var hardwareSwitches: [HardwareSwitchDescriptor]? { nil }

    public static var hardwareMomentaryButtons: [HardwareMomentaryDescriptor]? {
        [
            HardwareMomentaryDescriptor(
                id: "sms_pause",
                title: "PAUSE",
                label: "⏸",
                buttonId: "start"
            )
        ]
    }
}

@objc public protocol PVMasterSystemSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushMasterSystemButton:forPlayer:)
    func didPush(_ button: PVMasterSystemButton, forPlayer player: Int)
    @objc(didReleaseMasterSystemButton:forPlayer:)
    func didRelease(_ button: PVMasterSystemButton, forPlayer player: Int)
}
