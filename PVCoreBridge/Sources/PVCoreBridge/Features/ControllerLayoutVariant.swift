// MARK: - Controller Layout Variant Models

import Foundation
import PVPrimitives
import PVSystems

/// A named layout variant for a specific console's controller configuration.
///
/// Examples:
/// - Genesis: "3-Button Pad" vs "6-Button Pad"
/// - Wii: "Wiimote", "Wiimote + Nunchuck", "Classic Controller", "Classic Controller Pro"
/// - Atari 5200: "Joystick + Keypad" vs "Joystick Only"
/// - NES: "Standard" vs "Zapper"
public struct ControllerLayoutVariant: Identifiable, Sendable, Equatable, Hashable {
    /// Stable identifier used as storage key (e.g. "genesis-3btn", "wii-classic").
    public let id: String
    /// Human-readable name shown in Settings (e.g. "6-Button Pad").
    public let displayName: String
    /// Optional short description shown below the picker row.
    public let description: String?
    /// SF Symbol name that represents this layout in the UI.
    public let sfSymbol: String

    public init(id: String, displayName: String, description: String? = nil, sfSymbol: String = "gamecontroller") {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.sfSymbol = sfSymbol
    }

    // Identity is determined solely by `id`; display-name / symbol changes don't
    // create a new logical variant.
    public static func == (lhs: ControllerLayoutVariant, rhs: ControllerLayoutVariant) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Built-in Variants

public extension ControllerLayoutVariant {

    // MARK: Genesis
    static let genesis3Button = ControllerLayoutVariant(
        id: "genesis-3btn",
        displayName: "3-Button Pad",
        description: "Standard 3-button Mega Drive / Genesis controller (A, B, C).",
        sfSymbol: "gamecontroller"
    )
    static let genesis6Button = ControllerLayoutVariant(
        id: "genesis-6btn",
        displayName: "6-Button Pad",
        description: "6-button controller with extra X, Y, Z buttons for fighting games.",
        sfSymbol: "gamecontroller.fill"
    )

    // MARK: Wii
    static let wiiWiimote = ControllerLayoutVariant(
        id: "wii-wiimote",
        displayName: "Wiimote",
        description: "Horizontal Wiimote-only layout (D-pad + 1/2 buttons).",
        sfSymbol: "tv.remote"
    )
    static let wiiWiimoteNunchuck = ControllerLayoutVariant(
        id: "wii-wiimote-nunchuck",
        displayName: "Wiimote + Nunchuck",
        description: "Wiimote with Nunchuck attachment (analog stick + C/Z buttons).",
        sfSymbol: "tv.remote.fill"
    )
    static let wiiClassicController = ControllerLayoutVariant(
        id: "wii-classic",
        displayName: "Classic Controller",
        description: "Classic Controller with dual analog sticks and full button set.",
        sfSymbol: "gamecontroller"
    )
    static let wiiClassicControllerPro = ControllerLayoutVariant(
        id: "wii-classic-pro",
        displayName: "Classic Controller Pro",
        description: "Classic Controller Pro with grips and improved shoulder buttons.",
        sfSymbol: "gamecontroller.fill"
    )

    // MARK: Atari 5200
    static let atari5200Joystick = ControllerLayoutVariant(
        id: "5200-joystick",
        displayName: "Joystick + Keypad",
        description: "Full 5200 controller with analog joystick, numeric keypad, and side buttons.",
        sfSymbol: "gamecontroller"
    )
    static let atari5200JoystickOnly = ControllerLayoutVariant(
        id: "5200-joystick-only",
        displayName: "Joystick Only",
        description: "Simplified layout using only the joystick and fire buttons.",
        sfSymbol: "dpad"
    )

    // MARK: NES
    static let nesStandard = ControllerLayoutVariant(
        id: "nes-standard",
        displayName: "Standard",
        description: "Standard NES controller with D-pad, A/B, Start/Select.",
        sfSymbol: "gamecontroller"
    )
    static let nesZapper = ControllerLayoutVariant(
        id: "nes-zapper",
        displayName: "Zapper",
        description: "NES Zapper light gun for Duck Hunt and other compatible games.",
        sfSymbol: "scope"
    )
}

// MARK: - System Variant Map

public extension SystemIdentifier {

    /// Returns the available controller layout variants for this system,
    /// or `nil` if the system has only one fixed layout.
    var availableControllerLayoutVariants: [ControllerLayoutVariant]? {
        switch self {
        case .Genesis:
            return [.genesis3Button, .genesis6Button]
        case .Wii:
            return [.wiiWiimote, .wiiWiimoteNunchuck, .wiiClassicController, .wiiClassicControllerPro]
        case .Atari5200:
            return [.atari5200Joystick, .atari5200JoystickOnly]
        case .NES:
            return [.nesStandard, .nesZapper]
        default:
            return nil
        }
    }

    /// Default (first) variant for this system.
    var defaultControllerLayoutVariant: ControllerLayoutVariant? {
        availableControllerLayoutVariants?.first
    }
}

// MARK: - ConsoleVariantConfigurable Protocol

/// Implement this protocol in an emulator core to receive layout-variant change
/// notifications when the user switches the per-system controller layout in Settings.
///
/// The variant `id` corresponds to one of the `ControllerLayoutVariant` constants
/// (e.g. `"genesis-6btn"`, `"wii-classic"`). Cores should map those IDs to their
/// own device-type or core-option values.
///
/// - Note: This PR introduces the model, persistence layer, and Settings UI picker.
///   The emulator VC / core-bridge call-site that invokes `applyControllerLayoutVariant(_:)`
///   at launch and on variant change will be wired in a follow-up PR.
public protocol ConsoleVariantConfigurable: AnyObject {
    /// Apply the selected controller layout variant.
    /// - Parameter variantID: The `ControllerLayoutVariant.id` string chosen by the user.
    func applyControllerLayoutVariant(_ variantID: String)
}
