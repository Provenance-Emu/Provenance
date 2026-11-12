//
//  PauseMenuTrigger.swift
//  PVUI
//
//  Which controller input opens the pause menu, and when it fires.
//

import Foundation
import PVSystems
import PVTouchOverlay

/// A controller input that opens (and closes) the pause menu.
public enum PauseMenuTrigger: String, Equatable, Sendable, CaseIterable {
    /// The touchpad click of a PlayStation pad, while the touchpad is not the game's pointer.
    case touchpadButton
    /// The extra capture button that no emulated system uses: Xbox Share, Switch Pro Capture.
    case shareButton
    /// `buttonOptions`: PlayStation Create/Share, Xbox View, Switch "−".
    case options
    /// Both thumbsticks clicked together (L3 + R3).
    case thumbstickChord
    /// `buttonOptions` and `buttonMenu` together (Select + Start).
    case startSelectChord
    /// `buttonHome`, for pads that have no Options button.
    case home
    /// The single Menu button of a pad with nothing else (Siri Remote, first-generation MFi),
    /// delivered through `controllerPausedHandler`.
    case legacyPause
    /// A Switch Online pad's own trigger (Home, or Select + Start), fired by `PVPhysicalProfileController`.
    case profileTrigger
}

/// What a pad exposes, reduced to what the pause binding depends on.
public struct PauseMenuPadCapabilities: Equatable, Sendable {
    public var hasExtendedProfile: Bool
    /// `buttonOptions` exists.
    public var hasOptions: Bool
    /// A capture button separate from `buttonOptions` exists.
    public var hasShareButton: Bool
    public var hasHome: Bool
    /// Both L3 and R3 exist.
    public var hasThumbstickButtons: Bool
    /// The pad is a synthesized Switch Online profile that pauses from its own trigger.
    public var hasProfileTrigger: Bool
    /// The pad has a touchpad that clicks (DualSense, DualShock 4).
    public var hasTouchpadButton: Bool

    public init(hasExtendedProfile: Bool, hasOptions: Bool = false, hasShareButton: Bool = false,
                hasHome: Bool = false, hasThumbstickButtons: Bool = false, hasProfileTrigger: Bool = false,
                hasTouchpadButton: Bool = false) {
        self.hasExtendedProfile = hasExtendedProfile
        self.hasOptions = hasOptions
        self.hasShareButton = hasShareButton
        self.hasHome = hasHome
        self.hasThumbstickButtons = hasThumbstickButtons
        self.hasProfileTrigger = hasProfileTrigger
        self.hasTouchpadButton = hasTouchpadButton
    }
}

/// The inputs that open the pause menu on one pad, most convenient first.
public struct PauseMenuBindingPlan: Equatable, Sendable {
    public let triggers: [PauseMenuTrigger]

    public var primary: PauseMenuTrigger? { triggers.first }
    public var backups: [PauseMenuTrigger] { Array(triggers.dropFirst()) }

    /// Triggers read by sampling the pad's buttons, as opposed to a handler the pad calls.
    public var polledTriggers: [PauseMenuTrigger] {
        triggers.filter { $0 != .legacyPause && $0 != .profileTrigger }
    }
}

/// Chooses the pause-menu inputs for a pad.
///
/// The rule is that a button the running game uses never opens the menu on its own.
/// `buttonMenu` (PlayStation Options, Xbox Menu, Switch "+") is the emulated Start on
/// every system, so it only counts as half of the Select + Start chord. `buttonOptions`
/// opens the menu with a single press only where the system has no Select button.
/// `buttonHome` belongs to the system (Game Center, app switching) and is used only by
/// pads with no Options button.
///
/// A PlayStation pad's touchpad click is the one button no emulated system has, so it
/// opens the menu on every system. It stops doing so while the touchpad is the game's
/// pointer (a mouse, a light gun, the Wii pointer), where the click belongs to the game,
/// and when the player has remapped it.
public enum PauseMenuBindingPolicy {

    public static func plan(for pad: PauseMenuPadCapabilities, systemUsesSelect: Bool,
                            touchpadIsFree: Bool = false) -> PauseMenuBindingPlan {
        if pad.hasProfileTrigger {
            return PauseMenuBindingPlan(triggers: [.profileTrigger])
        }
        guard pad.hasExtendedProfile else {
            return PauseMenuBindingPlan(triggers: [.legacyPause])
        }
        var triggers: [PauseMenuTrigger] = []
        if pad.hasTouchpadButton, touchpadIsFree { triggers.append(.touchpadButton) }
        if pad.hasShareButton { triggers.append(.shareButton) }
        if pad.hasOptions, !systemUsesSelect { triggers.append(.options) }
        if pad.hasThumbstickButtons { triggers.append(.thumbstickChord) }
        if pad.hasOptions {
            triggers.append(.startSelectChord)
        } else {
            /// No Options button: an older MFi pad. Its Home button if it has one,
            /// otherwise its one Menu button, which is all it has.
            triggers.append(pad.hasHome ? .home : .legacyPause)
        }
        return PauseMenuBindingPlan(triggers: triggers)
    }

    /// Systems whose Select slot is not a button a game needs during play, so the pad's
    /// Options button is free to open the menu: arcade boards (the thin wrapper keeps the
    /// hardware button away from Insert Coin) and the Mega Drive family (Mode only matters at boot).
    static let systemsWithSpareSelect: Set<SystemIdentifier> = [
        .MAME, .CPS1, .CPS2, .CPS3, .NeoGeo, .NeoGeoCD, .Genesis, .Sega32X, .SegaCD
    ]

    /// Whether games on `system` use the pad's Select button.
    ///
    /// Read from the touch overlay's binding table, which lists every emulated button a
    /// system has. A system without a binding is treated as using it, so its Select
    /// keeps working and the menu opens from the other inputs.
    public static func systemUsesSelect(_ system: SystemIdentifier?) -> Bool {
        guard let system, let binding = SystemOverlayBindings.binding(for: system) else { return true }
        guard !systemsWithSpareSelect.contains(system) else { return false }
        return binding.tokens[.select] != nil
    }
}

/// One sample of the buttons the pause triggers read.
public struct PauseMenuButtonSample: Equatable, Sendable {
    public var options = false
    public var menu = false
    public var share = false
    public var home = false
    public var leftThumbstickButton = false
    public var rightThumbstickButton = false
    public var touchpadButton = false

    public init(options: Bool = false, menu: Bool = false, share: Bool = false, home: Bool = false,
                leftThumbstickButton: Bool = false, rightThumbstickButton: Bool = false,
                touchpadButton: Bool = false) {
        self.options = options
        self.menu = menu
        self.share = share
        self.home = home
        self.leftThumbstickButton = leftThumbstickButton
        self.rightThumbstickButton = rightThumbstickButton
        self.touchpadButton = touchpadButton
    }

    func isActive(_ trigger: PauseMenuTrigger) -> Bool {
        switch trigger {
        case .touchpadButton: return touchpadButton
        case .shareButton: return share
        case .options: return options
        case .thumbstickChord: return leftThumbstickButton && rightThumbstickButton
        case .startSelectChord: return options && menu
        case .home: return home
        case .legacyPause, .profileTrigger: return false
        }
    }
}

/// Turns successive button samples into pause requests.
///
/// The pad is sampled rather than given `pressedChangedHandler`s because several cores
/// (PPSSPP, Dolphin, emuThree) install their own handlers on these same buttons, and
/// whoever wrote last silently took the button from the other.
public struct PauseMenuTriggerDetector: Sendable {
    public let plan: PauseMenuBindingPlan
    private var active: Set<PauseMenuTrigger>?

    public init(plan: PauseMenuBindingPlan) {
        self.plan = plan
    }

    /// Returns the trigger that started on this sample, if any.
    ///
    /// The first sample only records what is held, so a button already down when
    /// sampling starts (the PS button held to pair the pad) fires nothing.
    public mutating func update(with sample: PauseMenuButtonSample) -> PauseMenuTrigger? {
        let nowActive = Set(plan.polledTriggers.filter { sample.isActive($0) })
        defer { active = nowActive }
        guard let active else { return nil }
        return plan.polledTriggers.first { nowActive.contains($0) && !active.contains($0) }
    }
}

// MARK: - Pause request notification

public extension Notification.Name {
    /// Asks the running emulator to toggle its pause menu. `userInfo` carries the
    /// trigger under ``PauseMenuTrigger/userInfoKey`` when a controller sent it.
    static let pvPauseGame = Notification.Name("PauseGame")
}

public extension PauseMenuTrigger {
    static let userInfoKey = "PauseMenuTrigger"

    /// Posts the pause request for this trigger.
    func postPauseRequest() {
        NotificationCenter.default.post(name: .pvPauseGame, object: nil, userInfo: [Self.userInfoKey: rawValue])
    }

    /// The trigger a pause request came from, when a controller sent it.
    init?(pauseRequest note: Notification?) {
        guard let raw = note?.userInfo?[Self.userInfoKey] as? String else { return nil }
        self.init(rawValue: raw)
    }

    /// Whether this trigger opens the menu no matter what "Pause/Menu button opens pause
    /// menu" says. Only a pad's single Menu button answers to that setting on iOS: it is
    /// also the nearest thing that pad has to Start, and the screen has a menu button.
    var alwaysOpensMenu: Bool { self != .legacyPause }

    /// How to open the pause menu with this trigger, for the on-screen hint.
    var hint: String {
        switch self {
        case .touchpadButton: return String(localized: "Press the touchpad to open the pause menu")
        case .shareButton: return String(localized: "Press Share / Capture to open the pause menu")
        case .options: return String(localized: "Press Share / Create / View to open the pause menu")
        case .thumbstickChord: return String(localized: "Click both thumbsticks (L3 + R3) to open the pause menu")
        case .startSelectChord: return String(localized: "Press Select + Start together to open the pause menu")
        case .home: return String(localized: "Press Home on your controller to open the pause menu")
        case .legacyPause: return String(localized: "Press Menu on your controller to open the pause menu")
        case .profileTrigger: return String(localized: "Press Home, or Select + Start, to open the pause menu")
        }
    }

    var hintSymbol: String {
        switch self {
        case .touchpadButton: return "hand.tap.fill"
        case .shareButton, .options: return "square.and.arrow.up"
        case .thumbstickChord: return "l.joystick.fill"
        case .startSelectChord, .home, .legacyPause, .profileTrigger: return "gamecontroller.fill"
        }
    }
}
