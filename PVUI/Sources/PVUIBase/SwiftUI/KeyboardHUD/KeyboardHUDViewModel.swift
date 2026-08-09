// KeyboardHUDViewModel.swift
// PVUI
//
// Observable state for the in-game input legend (Phase B of the macOS desktop
// input design — see
// docs/superpowers/specs/2026-08-09-macos-desktop-input-design.md).
//
// The legend is READ-ONLY. It exists to answer "what does what" for the system
// being played, and it deliberately owns no interactive affordance: rebinding
// lives in Settings › Controller › Keyboard Mapping (`KeyboardMappingView`),
// which is the complete implementation of that feature. An earlier revision
// duplicated rebinding here as tappable chips floating over the running game;
// that made an informational overlay look and behave like a control panel, and
// it dragged the `GCKeyboardInput.keyChangedHandler` hijack — the single most
// dangerous manoeuvre in the input stack — into the emulator view controller's
// lifetime. Both are gone.
//
// What remains is passive: which `KeyboardControllerAction`s are currently held
// is discovered by SAMPLING raw `GCKeyboardInput` button state on a
// low-frequency timer, never by installing a handler.
// `GCKeyboardInput.keyChangedHandler` is owned end-to-end by
// `PVControllerManager` (see `GCKeyboard.createController()`) — it is how every
// keypress becomes gameplay input. A second consumer assigning that slot would
// either silently replace the gameplay handler (input dies) or, if "restored"
// later from a stale reference, revive a closure bound to a virtual controller
// PVControllerManager no longer tracks (see the extensive warning on
// `KeyboardMappingView.abortCaptureForHardwareChange`). Polling
// `GCKeyboardInput.button(forKeyCode:)?.isPressed` sidesteps that hazard
// entirely: it reads hardware state without touching any shared handler slot,
// so there is nothing to hijack and nothing to restore.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import Foundation
import Combine
import Defaults
import GameController
import PVCoreBridge
import PVPlists
import PVLogging
import PVSettings

/// Drives the in-game input legend: builds its rows from the real mapping data,
/// tracks which actions are currently held, and owns the show / auto-fade /
/// pin lifecycle.
@MainActor
public final class KeyboardHUDViewModel: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var isVisible: Bool = false
    /// Pinned means "stay up until told otherwise" — the Game menu's HUD item
    /// toggles it, which is also how the launch legend is re-shown after it
    /// fades.
    @Published public private(set) var isPinned: Bool = false
    /// Live hardware state, sampled every poll. Used to highlight rows so the
    /// legend doubles as a "did that key register?" check.
    @Published public private(set) var pressedActions: Set<KeyboardControllerAction> = []
    /// What the transient compact strip renders: set to `pressedActions`
    /// whenever that's non-empty, but — unlike `pressedActions` — NOT cleared
    /// the instant keys release. It only clears when `isVisible` goes false,
    /// so the strip still shows what was just pressed for the whole auto-fade
    /// window instead of going blank the moment fingers lift.
    @Published public private(set) var displayActions: Set<KeyboardControllerAction> = []
    /// The full legend. Recomputed on `configure(...)` and whenever bindings
    /// change underneath us, so a remap in Settings is reflected on return.
    @Published public private(set) var legend: InputLegend = .empty
    /// Short name of the system being played ("SNES", "PlayStation"), for the
    /// legend header. `nil` renders a generic header.
    @Published public private(set) var systemName: String?
    /// True while the at-launch legend is showing, as opposed to the transient
    /// pressed-keys strip. Drives which presentation the view picks.
    @Published public private(set) var isShowingFullLegend: Bool = false

    // MARK: - Tuning constants

    /// How often raw keyboard hardware state is sampled. Deliberately coarse —
    /// this drives cosmetic display only, not gameplay input latency.
    private static let pollInterval: TimeInterval = 0.1
    /// How long the transient strip stays visible after the last detected
    /// keypress before auto-fading. Per design: "~2s after the last input".
    private static let autoFadeDelay: TimeInterval = 2.0
    /// How long the at-launch "what does what" legend stays up before fading.
    /// Long enough to read a dozen rows, short enough not to intrude on the
    /// first moments of play.
    private static let launchLegendDuration: TimeInterval = 5.0
    /// Fade in/out animation duration, matching the virtual keyboard overlay's
    /// own show/hide animation (`PVEmulatorViewController+VirtualKeyboard.swift`).
    public static let fadeAnimationDuration: TimeInterval = 0.3

    // MARK: - Private state

    private var pollTimer: Timer?
    private var fadeOutWorkItem: DispatchWorkItem?
    private var observers: Set<AnyCancellable> = []
    /// Retained so the legend can be rebuilt when the bindings or the attached
    /// hardware change without the caller having to re-`configure`.
    private var layout: [ControlLayoutEntry]?
    private var faceNamesAreTrustworthy: Bool = false

    public init() {
        observeBindingChanges()
    }

    deinit {
        // `deinit` on a `@MainActor` class is itself nonisolated and cannot
        // call actor-isolated methods like `stopObserving()` (confirmed: the
        // compiler rejects it), so cleanup here is limited to plain Foundation
        // APIs that aren't actor-isolated. This only guards the path where the
        // owning view controller is torn down WITHOUT calling
        // `stopObserving()` — otherwise the repeating poll timer would keep
        // firing forever (its closure captures `self` weakly, so it doesn't
        // even keep this object alive, just wastes cycles).
        pollTimer?.invalidate()
        fadeOutWorkItem?.cancel()
    }

    // MARK: - Configuration

    /// Point the legend at the game that's starting.
    ///
    /// - Parameters:
    ///   - layout: the system's shipped control layout, i.e.
    ///     `PVEmulatorConfiguration.controllerLayout(forSystemIdentifier:)`.
    ///   - systemName: short display name for the header.
    ///   - faceNamesAreTrustworthy: whether the running core is known to
    ///     follow the positional MFi↔console face-button convention. See
    ///     `InputLegend.swift` — passing `true` when the core doesn't would put
    ///     wrong labels on A/B/X/Y, so the caller must have evidence.
    public func configure(layout: [ControlLayoutEntry]?, systemName: String?, faceNamesAreTrustworthy: Bool) {
        self.layout = layout
        self.systemName = systemName
        self.faceNamesAreTrustworthy = faceNamesAreTrustworthy
        rebuildLegend()
    }

    // MARK: - Lifecycle

    /// Begin sampling keyboard state. Idempotent.
    public func startObserving() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    /// Stop sampling and cancel any pending fade. Call when the legend's
    /// owning view controller is going away.
    public func stopObserving() {
        pollTimer?.invalidate()
        pollTimer = nil
        fadeOutWorkItem?.cancel()
        fadeOutWorkItem = nil
    }

    // MARK: - Legend

    private func rebuildLegend() {
        var inputLabels: [KeyboardControllerAction: String] = [:]
        for action in KeyboardControllerAction.allCases {
            inputLabels[action] = Self.inputLabel(for: action)
        }
        legend = InputLegendBuilder.legend(
            layout: layout,
            faceNamesAreTrustworthy: faceNamesAreTrustworthy,
            inputLabels: inputLabels
        )
    }

    /// Physical-input label for an action, or `nil` when nothing is bound on
    /// the currently attached hardware (the row is then dropped rather than
    /// shown with a placeholder).
    ///
    /// Keyboard wins when one is attached, because on a keyboard-and-gamepad
    /// desk the keyboard is the surface the user is least sure about.
    /// Gamepad labels come from `ControllerMappingStore`, so a user who
    /// swapped A/B in Settings sees the button they actually have to press.
    private static func inputLabel(for action: KeyboardControllerAction) -> String? {
        if GCKeyboard.coalesced?.keyboardInput != nil {
            let names = KeyboardControllerMap.current.keys(for: action).compactMap { keyName(for: $0) }
            return names.isEmpty ? nil : names.joined(separator: " / ")
        }
        // Directional actions are deliberately unlabelled for gamepad users:
        // "D-Pad Up → D-Pad" tells nobody anything, and the builder drops any
        // row whose inputs all come back nil.
        guard !action.isDirectional,
              let controller = GCController.current ?? GCController.controllers().first,
              controller.extendedGamepad != nil,
              let source = action.buttonIdentifier else { return nil }
        return ControllerMappingStore.shared
            .destination(forSource: source, vendor: controller.vendorName ?? "unknown")
            .displayName
    }

    /// Human-readable label for a key code, matching `KeyboardMappingView.keyName`.
    private static func keyName(for code: GCKeyCode) -> String? {
        if let button = GCKeyboard.coalesced?.keyboardInput?.button(forKeyCode: code),
           let name = button.aliases.first ?? button.localizedName {
            return name
        }
        return "Key \(code.rawValue)"
    }

    /// Rebuild when the stored bindings change (a remap in Settings) or when
    /// the attached hardware changes (keyboard in/out swaps the whole legend
    /// between key names and gamepad button names).
    private func observeBindingChanges() {
        Defaults.publisher(.keyboardControllerBindings)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildLegend() }
            .store(in: &observers)

        let hardwareChanges: [Notification.Name] = [
            .GCKeyboardDidConnect,
            .GCKeyboardDidDisconnect,
            .GCControllerDidConnect,
            .GCControllerDidDisconnect
        ]
        for name in hardwareChanges {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.rebuildLegend() }
                .store(in: &observers)
        }
    }

    // MARK: - Polling (passive — reads raw GCKeyboard button state only)

    private func poll() {
        guard let keyboardInput = GCKeyboard.coalesced?.keyboardInput else {
            if !pressedActions.isEmpty { pressedActions = [] }
            return
        }

        let map = KeyboardControllerMap.current
        var newlyPressed: Set<KeyboardControllerAction> = []
        for action in KeyboardControllerAction.allCases {
            let isDown = map.keys(for: action).contains {
                keyboardInput.button(forKeyCode: $0)?.isPressed == true
            }
            if isDown { newlyPressed.insert(action) }
        }

        if newlyPressed != pressedActions {
            pressedActions = newlyPressed
        }

        guard !newlyPressed.isEmpty else { return }
        // Live-update the display snapshot while keys are actually held —
        // only skipped once everything releases, so the compact strip keeps
        // showing the last thing that was pressed through the fade window.
        displayActions = newlyPressed
        // A keypress during the launch legend means the player is already
        // playing; get out of the way and let the transient strip take over.
        revealTransientStrip()
    }

    // MARK: - Visibility

    /// Show the full "what does what" legend and fade it after
    /// `launchLegendDuration`. Called once when the game starts.
    public func showLaunchLegend() {
        guard !legend.rows.isEmpty else {
            ILOG("[InputLegend] No rows derived — skipping launch legend")
            return
        }
        isShowingFullLegend = true
        isVisible = true
        scheduleFadeOut(after: Self.launchLegendDuration)
    }

    private func revealTransientStrip() {
        isShowingFullLegend = false
        isVisible = true
        scheduleFadeOut(after: Self.autoFadeDelay)
    }

    private func scheduleFadeOut(after delay: TimeInterval) {
        fadeOutWorkItem?.cancel()
        guard !isPinned else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.fadeOutIfUnpinned()
        }
        fadeOutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func fadeOutIfUnpinned() {
        guard !isPinned else { return }
        isVisible = false
        isShowingFullLegend = false
        displayActions = []
    }

    // MARK: - Show / hide

    /// Show / hide the persistent legend. Wired to the Game menu's HUD item,
    /// which is deliberately the *only* control: it dismisses the launch
    /// legend early when it's still up, and brings the legend back once it has
    /// faded. Keeping both behaviours on one item is what lets the overlay stay
    /// entirely non-interactive — see `KeyboardHUDView`.
    public func togglePinned() {
        fadeOutWorkItem?.cancel()
        fadeOutWorkItem = nil
        if isVisible {
            isPinned = false
            isVisible = false
            isShowingFullLegend = false
            displayActions = []
        } else {
            isPinned = true
            isVisible = true
            isShowingFullLegend = true
        }
    }
}

// MARK: - Action → gamepad element

private extension KeyboardControllerAction {
    /// D-Pad and thumbstick directions, which the legend renders as one
    /// combined row rather than four.
    var isDirectional: Bool {
        switch self {
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
             .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight,
             .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight:
            return true
        default:
            return false
        }
    }

    /// The `ButtonIdentifier` this action drives on the virtual gamepad, for
    /// resolving physical gamepad labels through `ControllerMappingStore`.
    ///
    /// Mirrors `GCKeyboard.createController()` in PVControllerManager.swift
    /// exactly. `nil` for the directional actions (they drive axes, not
    /// buttons) and for `.start`/`.select`, which bypass the gamepad entirely
    /// and call `pressStart`/`pressSelect` on the controller view controller —
    /// there is no gamepad element to name.
    var buttonIdentifier: ButtonIdentifier? {
        switch self {
        case .buttonA: return .buttonA
        case .buttonB: return .buttonB
        case .buttonX: return .buttonX
        case .buttonY: return .buttonY
        case .l1: return .leftShoulder
        case .l2: return .leftTrigger
        case .r1: return .rightShoulder
        case .r2: return .rightTrigger
        case .l3: return .leftThumbstickButton
        case .r3: return .rightThumbstickButton
        case .menu: return .menu
        case .options: return .options
        case .dpadUp: return .dpadUp
        case .dpadDown: return .dpadDown
        case .dpadLeft: return .dpadLeft
        case .dpadRight: return .dpadRight
        case .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight,
             .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight,
             .start, .select:
            return nil
        }
    }
}
#endif // !os(tvOS)
