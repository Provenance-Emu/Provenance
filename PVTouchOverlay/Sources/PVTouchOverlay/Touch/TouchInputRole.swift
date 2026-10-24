import Foundation
import SkinKitUI

// `TouchInputRole` (gameplay vs frontend / console-system control) lives in SkinKitUI, which the
// skin view shares; the token classifier and the overlay-control roles stay here.

/// Classifies skin / overlay input tokens.
///
/// This is a block list, unlike iFly's allow list: Provenance has no single table of the tokens each of
/// its systems reaches, and a token `DeltaSkinInputHandler` does not intercept goes to the core, so an
/// unknown token is a console input. The list covers:
/// - every token `DeltaSkinInputHandler.buttonPressed` intercepts as a frontend command (pause menu, quick
///   save / load, fast-forward, slow motion, screenshot and the extended function buttons), with the same
///   substring / exact-match rules it uses;
/// - latching console switches (2600 difficulty and TV type, PC Engine turbo switches);
/// - console-system and operator inputs (home, service, test).
///
/// `pause` is deliberately gameplay: it is the Start button of the Jaguar, 7800, MSX, PC-98, EP128 and the
/// DOS-style pads, and Start is a gameplay button (as in iFly).
public enum TouchInputClassifier {
    /// Extended function buttons `DeltaSkinInputHandler` handles itself on press and never forwards.
    /// The handler reads this set, so the two cannot drift apart.
    public static let frontendFunctionTokens: Set<String> = [
        "screenshot", "restart", "reset", "reboot", "quit", "exit",
        "savestates", "save_states", "saves",
        "cheats", "cheatcodes", "cheat_codes",
        "skins", "skin", "controllerskins",
        "filters", "filter", "videofilters",
        "speedmenu", "speed_menu", "gamespeed",
        "toggleanalog", "toggle_analog", "analogmode",
        "swapdiscs", "swap_discs", "swapdisc", "changedisc",
        "coreoptions", "core_options", "coresettings",
        "moreinfo", "more_info", "gameinfo", "info",
        "reversescreens", "reverse_screens", "swapscreens", "swap_screens",
        "haptics", "togglehaptics", "toggle_haptics",
        "controllers", "controllersettings", "controller_settings",
        "orientation", "orientationlock", "orientation_lock", "toggleorientation",
        "resolution", "cycleresolution", "cycle_resolution"
    ]

    /// Substrings `DeltaSkinInputHandler.buttonPressed` matches with `contains` (menu, quick save / load,
    /// both fast-forward styles, both slow-motion styles, screenshot).
    public static let frontendCommandSubstrings: [String] = [
        "menu", "quicksave", "quickload", "fastforward", "slowmotion", "screenshot"
    ]

    /// Two-position console switches: the position-less tokens, the position ids cores declare and the
    /// TV-type spellings `HardwareSwitchTokens` accepts. Each press flips a switch, so a slide must not.
    public static let consoleSwitchTokens: Set<String> = [
        "leftdifficulty", "leftdiff", "rightdifficulty", "rightdiff", "tvtype",
        "color", "clr", "colour", "colorbw", "bw", "blackwhite", "b&w",
        "turboi", "turboii"
    ]

    /// Prefixes of switch position ids (`leftdiffa`, `leftdiff_b`, `colorbw_color`...).
    public static let consoleSwitchPrefixes: [String] = ["leftdiff", "rightdiff", "colorbw"]

    /// Console-system and arcade operator inputs: they open a system menu or enter a service mode.
    public static let consoleSystemTokens: Set<String> = ["home", "service", "test"]

    public static func role(forToken token: String) -> TouchInputRole {
        let key = token.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if frontendCommandSubstrings.contains(where: key.contains) { return .system }
        if frontendFunctionTokens.contains(key) { return .system }
        if consoleSwitchTokens.contains(key) { return .system }
        if consoleSwitchPrefixes.contains(where: key.hasPrefix) { return .system }
        if consoleSystemTokens.contains(key) { return .system }
        return .gameplay
    }
}

public extension OverlayControlKind {
    /// Role of a programmatic overlay control. Actions and hardware switches are always system controls;
    /// buttons and triggers go by their token, since console switch pills and the keypad Reset are buttons.
    var touchRole: TouchInputRole {
        switch self {
        case .action, .hardwareSwitch:
            return .system
        case .button(let input), .analogTrigger(let input):
            return TouchInputClassifier.role(forToken: input.token)
        case .dpad, .stick, .touchSurface:
            return .gameplay
        }
    }

    /// A plain press-and-release gameplay control: the only kind that joins a multi-button press.
    var isMultiPressEligible: Bool {
        switch self {
        case .button, .analogTrigger: return touchRole == .gameplay
        default: return false
        }
    }
}

public extension OverlayControl {
    /// Role of this control for touch. The console Reset pill (the `reset` slot) is a system control
    /// whatever token a binding gives it (`r` on the 7800 and 5200).
    var touchRole: TouchInputRole {
        id == OverlayFamilySlot.reset.rawValue ? .system : kind.touchRole
    }

    /// A plain press-and-release gameplay control: the only kind that joins a multi-button press.
    var isMultiPressEligible: Bool { touchRole == .gameplay && kind.isMultiPressEligible }
}
