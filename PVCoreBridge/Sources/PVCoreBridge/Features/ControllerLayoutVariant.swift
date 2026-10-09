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

    // MARK: GameCube
    static let gcStandard = ControllerLayoutVariant(
        id: "gc-standard",
        displayName: "Standard Controller",
        description: "Standard GameCube controller (also covers WaveBird).",
        sfSymbol: "gamecontroller"
    )
    static let gcBongos = ControllerLayoutVariant(
        id: "gc-bongos",
        displayName: "DK Bongos",
        description: "DK Bongos for Donkey Konga and Donkey Kong Jungle Beat.",
        sfSymbol: "circle.grid.2x1"
    )
    static let gcKeyboard = ControllerLayoutVariant(
        id: "gc-keyboard",
        displayName: "Keyboard",
        description: "GameCube keyboard controller for Phantasy Star Online.",
        sfSymbol: "keyboard"
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

    // MARK: PlayStation
    static let psxDualShock = ControllerLayoutVariant(
        id: "psx-dualshock",
        displayName: "DualShock",
        description: "Analog controller with two sticks, L3/R3 and analog mode.",
        sfSymbol: "gamecontroller.fill"
    )
    static let psxDigital = ControllerLayoutVariant(
        id: "psx-digital",
        displayName: "Digital Pad",
        description: "Original PlayStation controller without analog sticks.",
        sfSymbol: "gamecontroller"
    )

    // MARK: Dreamcast
    static let dreamcastStandard = ControllerLayoutVariant(
        id: "dreamcast-standard",
        displayName: "Standard Controller",
        description: "Dreamcast controller with analog stick, D-pad, A B X Y and analog triggers.",
        sfSymbol: "gamecontroller"
    )
    static let dreamcastArcade = ControllerLayoutVariant(
        id: "dreamcast-arcade",
        displayName: "Arcade Stick",
        description: "Joystick and four buttons, as on the Dreamcast arcade stick.",
        sfSymbol: "gamecontroller.fill"
    )

    // MARK: PC Engine
    static let pce2Button = ControllerLayoutVariant(
        id: "pce-2btn",
        displayName: "2-Button Pad",
        description: "Standard PC Engine / TurboGrafx-16 pad (I, II, Run, Select).",
        sfSymbol: "gamecontroller"
    )
    static let pce6Button = ControllerLayoutVariant(
        id: "pce-6btn",
        displayName: "6-Button Pad",
        description: "Avenue Pad 6 with the extra III to VI buttons for fighting games.",
        sfSymbol: "gamecontroller.fill"
    )

    // MARK: WonderSwan
    static let wonderSwanHorizontal = ControllerLayoutVariant(
        id: "ws-horizontal",
        displayName: "Horizontal",
        description: "Console held sideways, as for most games.",
        sfSymbol: "iphone.landscape"
    )
    static let wonderSwanVertical = ControllerLayoutVariant(
        id: "ws-vertical",
        displayName: "Vertical",
        description: "Console held upright, for games drawn in portrait.",
        sfSymbol: "iphone"
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
        case .Genesis, .Sega32X, .SegaCD:
            return [.genesis3Button, .genesis6Button]
        case .Wii:
            return [.wiiWiimote, .wiiWiimoteNunchuck, .wiiClassicController, .wiiClassicControllerPro]
        case .GameCube:
            return [.gcStandard, .gcBongos, .gcKeyboard]
        case .Atari5200:
            return [.atari5200Joystick, .atari5200JoystickOnly]
        case .NES:
            return [.nesStandard, .nesZapper]
        case .PSX:
            return [.psxDualShock, .psxDigital]
        case .Dreamcast:
            return [.dreamcastStandard, .dreamcastArcade]
        case .PCE, .SGFX, .PCECD:
            return [.pce2Button, .pce6Button]
        case .WonderSwan, .WonderSwanColor:
            return [.wonderSwanHorizontal, .wonderSwanVertical]
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

/// Implement this protocol in an emulator core to receive layout-variant changes
/// and to report the variant it is actually running.
///
/// The variant `id` corresponds to one of the `ControllerLayoutVariant` constants
/// (e.g. `"genesis-6btn"`, `"wii-classic"`). Cores should map those IDs to their
/// own device-type or core-option values.
///
/// Conformers post `.controllerLayoutVariantDidChange` after applying a variant so
/// views that draw the controller (the programmatic touch overlay) can follow it.
public protocol ConsoleVariantConfigurable: AnyObject {
    /// Apply the selected controller layout variant.
    /// - Parameter variantID: The `ControllerLayoutVariant.id` string chosen by the user.
    func applyControllerLayoutVariant(_ variantID: String)

    /// The variant the core is actually running, or `nil` when it cannot tell.
    var currentControllerLayoutVariantID: String? { get }
}

public extension ConsoleVariantConfigurable {
    /// Cores that cannot report their running variant leave resolution to the settings.
    var currentControllerLayoutVariantID: String? { nil }
}

public extension Notification.Name {
    /// A core applied (or restored) a controller layout variant. `object` is the core;
    /// `userInfo[ControllerLayoutVariantNotificationKey.variantID]` is the variant id `String`
    /// when the poster knows it — re-read `currentControllerLayoutVariantID` otherwise.
    static let controllerLayoutVariantDidChange = Notification.Name("PVControllerLayoutVariantDidChange")
}

/// `userInfo` keys of `.controllerLayoutVariantDidChange`.
public enum ControllerLayoutVariantNotificationKey {
    public static let variantID = "variantID"
}
