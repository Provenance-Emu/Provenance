// KeyboardHUDViewModel.swift
// PVUI
//
// Observable state for the desktop-input keyboard HUD (Phase B of the macOS
// desktop input design — see
// docs/superpowers/specs/2026-08-09-macos-desktop-input-design.md).
//
// Displays which `KeyboardControllerAction`s are currently held by SAMPLING
// raw `GCKeyboardInput` button state on a low-frequency timer, rather than by
// installing a handler on `GCKeyboardInput.keyChangedHandler`. That handler
// slot is already owned end-to-end by `PVControllerManager` (see
// `GCKeyboard.createController()` in PVControllerManager.swift) — it is how
// every keypress becomes gameplay input. A second consumer assigning the same
// slot would either silently replace the gameplay handler (input dies) or,
// if "restored" later from a stale reference, revive a closure bound to a
// virtual controller PVControllerManager no longer tracks (see the extensive
// warning on `KeyboardMappingView.abortCaptureForHardwareChange`). Polling
// `GCKeyboardInput.button(forKeyCode:)?.isPressed` sidesteps that hazard
// entirely for passive display: it reads hardware state without touching any
// shared handler slot, so there is nothing to hijack and nothing to restore.
//
// Rebinding (pinned mode only) is the one place this file DOES take over
// `keyChangedHandler`, because capturing "the next key pressed" requires it.
// That path mirrors `KeyboardMappingView.beginCapture`/`endCapture`/
// `abortCaptureForHardwareChange` exactly, including the ordering that makes
// it safe: `endCapture()` unconditionally before starting a new capture or
// rebuilding, and hardware-change notifications abort WITHOUT writing back
// the saved handler.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import Foundation
import Combine
import GameController
import PVLogging

/// Tracks which keyboard-controller actions are currently held, drives the
/// HUD's show/auto-fade/pin lifecycle, and (pinned mode only) owns the
/// rebind-capture handshake.
@MainActor
public final class KeyboardHUDViewModel: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var isPinned: Bool = false
    /// Live hardware state, sampled every poll — used by the pinned expanded
    /// grid, which is always on screen and should reflect "right now".
    @Published public private(set) var pressedActions: Set<KeyboardControllerAction> = []
    /// What the transient compact strip renders: set to `pressedActions`
    /// whenever that's non-empty, but — unlike `pressedActions` — NOT cleared
    /// the instant keys release. It only clears when `isVisible` goes false,
    /// so the strip still shows what was just pressed for the whole ~2s
    /// auto-fade window instead of going blank the moment fingers lift.
    @Published public private(set) var displayActions: Set<KeyboardControllerAction> = []
    @Published public private(set) var capturingAction: KeyboardControllerAction?

    // MARK: - Tuning constants

    /// How often raw keyboard hardware state is sampled. Deliberately coarse —
    /// this drives cosmetic HUD display only, not gameplay input latency.
    private static let pollInterval: TimeInterval = 0.1
    /// How long the HUD stays visible after the last detected keypress before
    /// auto-fading, when not pinned. Per design: "~2s after the last input".
    private static let autoFadeDelay: TimeInterval = 2.0
    /// Fade in/out animation duration, matching the virtual keyboard overlay's
    /// own show/hide animation (`PVEmulatorViewController+VirtualKeyboard.swift`).
    public static let fadeAnimationDuration: TimeInterval = 0.25

    // MARK: - Private state

    private var pollTimer: Timer?
    private var fadeOutWorkItem: DispatchWorkItem?
    private var savedKeyHandler: GCKeyboardValueChangedHandler?
    /// The keyboard `savedKeyHandler` was captured from. Weak: if the hardware
    /// goes away this naturally becomes nil, which already fails the identity
    /// check in `endCapture()`. Used to detect "the keyboard changed under us"
    /// even in the race window before `abortCaptureForHardwareChange` runs —
    /// see `endCapture()`.
    private weak var capturedKeyboardInput: GCKeyboardInput?
    private var hardwareObservers: Set<AnyCancellable> = []

    public init() {
        observeHardwareKeyboardChanges()
    }

    deinit {
        // `deinit` on a `@MainActor` class is itself nonisolated and cannot
        // call actor-isolated methods like `stopObserving()`/`endCapture()`
        // (confirmed: the compiler rejects it), so cleanup here is limited to
        // plain Foundation APIs that aren't actor-isolated. This only guards
        // the path where the owning view controller is torn down WITHOUT
        // calling `stopObserving()` — otherwise the repeating poll timer
        // would keep firing forever (its closure captures `self` weakly, so
        // it doesn't even keep this object alive, just wastes cycles).
        // An in-progress rebind capture doesn't need attention here: the
        // `keyChangedHandler` closure installed in `beginCapture` captures
        // `self` weakly too and already self-heals on the next keypress via
        // `PVControllerManager.shared.rebuildKeyboardController()` when
        // `self` is gone.
        pollTimer?.invalidate()
        fadeOutWorkItem?.cancel()
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

    /// Stop sampling, cancel any pending fade, and release an in-progress
    /// capture. Call when the HUD's owning view controller is going away.
    public func stopObserving() {
        pollTimer?.invalidate()
        pollTimer = nil
        fadeOutWorkItem?.cancel()
        fadeOutWorkItem = nil
        endCapture()
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
        reveal()
    }

    // MARK: - Visibility

    private func reveal() {
        isVisible = true
        scheduleAutoFade()
    }

    private func scheduleAutoFade() {
        fadeOutWorkItem?.cancel()
        guard !isPinned else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.fadeOutIfUnpinned()
        }
        fadeOutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoFadeDelay, execute: workItem)
    }

    private func fadeOutIfUnpinned() {
        guard !isPinned else { return }
        isVisible = false
        displayActions = []
    }

    // MARK: - Pinning

    /// Toggles pinned mode (driven by the Game menu item). Pinning keeps the
    /// HUD open and exposes the rebind affordance; unpinning drops any
    /// in-progress capture and re-arms the auto-fade timer.
    public func togglePinned() {
        isPinned.toggle()
        if isPinned {
            isVisible = true
            fadeOutWorkItem?.cancel()
            fadeOutWorkItem = nil
        } else {
            endCapture()
            scheduleAutoFade()
        }
    }

    // MARK: - Rebinding (pinned mode only)

    /// Human-readable label for the first key bound to `action`, matching
    /// `KeyboardMappingView.keyName`.
    public func keyName(for action: KeyboardControllerAction) -> String {
        guard let code = KeyboardControllerMap.current.keys(for: action).first else { return "—" }
        if let button = GCKeyboard.coalesced?.keyboardInput?.button(forKeyCode: code),
           let name = button.aliases.first ?? button.localizedName {
            return name
        }
        return "Key \(code.rawValue)"
    }

    /// Begins capturing the next keypress for `action`, rebinding it in
    /// `KeyboardControllerMap`. Only meaningful while pinned — the view only
    /// offers this affordance in pinned mode.
    public func beginCapture(for action: KeyboardControllerAction) {
        guard isPinned else { return }
        // Unconditionally end any prior capture first, exactly like
        // `KeyboardMappingView.beginCapture`, so a stale capture never
        // survives past the point a new one starts.
        endCapture()
        guard let keyboardInput = GCKeyboard.coalesced?.keyboardInput else { return }
        capturingAction = action
        capturedKeyboardInput = keyboardInput
        savedKeyHandler = keyboardInput.keyChangedHandler
        keyboardInput.keyChangedHandler = { [weak self] _, _, keyCode, pressed in
            guard pressed else { return }
            DispatchQueue.main.async {
                guard let self else {
                    // The view model that owns this capture is gone — e.g. the
                    // hosting view controller was torn down through some path
                    // other than `teardownKeyboardHUD()`/`stopObserving()`.
                    // We're still squatting on the OS `keyChangedHandler` slot
                    // with a now-dead closure that swallows every keypress
                    // without forwarding it. Left alone that's a silent,
                    // app-wide keyboard-input death (the exact hazard this
                    // whole capture path exists to avoid) — self-heal by
                    // reinstalling PVControllerManager's real handler.
                    PVControllerManager.shared.rebuildKeyboardController()
                    return
                }
                var map = KeyboardControllerMap.current
                if keyCode == .deleteOrBackspace {
                    map.set(keys: KeyboardControllerMap.standard.keys(for: action), for: action)
                } else {
                    map.set(keys: [keyCode], for: action)
                }
                map.save()
                self.endCapture()
                PVControllerManager.shared.rebuildKeyboardController()
            }
        }
    }

    /// Ends capture (normal completion, a new capture starting, or an owning
    /// view controller tearing down via `stopObserving()`). Restores the
    /// handler saved in `beginCapture` — but ONLY if the keyboard we captured
    /// from ("same keyboard" = pointer identity via `===` on the
    /// `GCKeyboardInput` instance, tracked in `capturedKeyboardInput`) is
    /// still what `GCKeyboard.coalesced?.keyboardInput` currently resolves
    /// to.
    ///
    /// Hardware changes are normally already caught by
    /// `abortCaptureForHardwareChange`, which clears `savedKeyHandler`
    /// without restoring it. But that runs off a Combine pipeline with
    /// `.receive(on: DispatchQueue.main)`, which dispatches asynchronously
    /// even when already on the main queue/thread — so there is a window
    /// where the hardware has changed (disconnect, or a second keyboard
    /// connecting without an intervening disconnect) but the abort hasn't
    /// been processed yet. If some other MainActor call — most notably
    /// `stopObserving()` tearing down the owning view controller — reaches
    /// `endCapture()` inside that window, restoring the saved handler would
    /// write a closure belonging to a dead/superseded keyboard onto whatever
    /// keyboard is current now: the exact class of bug that previously
    /// killed keyboard input app-wide. The identity check below closes that
    /// window regardless of ordering.
    public func endCapture() {
        defer {
            savedKeyHandler = nil
            capturingAction = nil
            capturedKeyboardInput = nil
        }
        guard let saved = savedKeyHandler else { return }
        guard let current = GCKeyboard.coalesced?.keyboardInput,
              current === capturedKeyboardInput else {
            // Declining to restore is the safe default (see doc above) — but our
            // OWN capture closure (installed in `beginCapture`) may still be sitting
            // in `keyChangedHandler` on whatever keyboard is current now, e.g. if
            // this identity check false-negatives because `GCKeyboard.coalesced`
            // doesn't guarantee returning the same `GCKeyboardInput` instance across
            // calls even when the underlying hardware hasn't changed. Left alone,
            // that capture closure would swallow (and rebind on) the next keypress
            // instead of forwarding it as gameplay input. Reinstalling
            // PVControllerManager's real handler is idempotent — a no-op if a fresh
            // handler is already there (e.g. the genuine-hardware-change case, where
            // `abortCaptureForHardwareChange`'s own notification handler already did
            // this) — so it's safe to call unconditionally whenever a keyboard is
            // still present.
            if GCKeyboard.coalesced?.keyboardInput != nil {
                PVControllerManager.shared.rebuildKeyboardController()
            }
            return
        }
        current.keyChangedHandler = saved
    }

    /// Aborts an in-progress capture because the keyboard hardware changed
    /// underneath us (disconnect, or a second keyboard connecting without an
    /// intervening disconnect). Mirrors
    /// `KeyboardMappingView.abortCaptureForHardwareChange` exactly:
    /// `PVControllerManager` has already installed a fresh handler on the
    /// new/surviving keyboard in response to the same notification, so
    /// `savedKeyHandler` — bound to a controller PVControllerManager may no
    /// longer track — must be discarded, never written back. Writing it back
    /// would silently kill keyboard input app-wide.
    private func abortCaptureForHardwareChange() {
        guard capturingAction != nil else { return }
        savedKeyHandler = nil
        capturingAction = nil
        capturedKeyboardInput = nil
    }

    private func observeHardwareKeyboardChanges() {
        NotificationCenter.default.publisher(for: .GCKeyboardDidDisconnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.abortCaptureForHardwareChange() }
            .store(in: &hardwareObservers)
        NotificationCenter.default.publisher(for: .GCKeyboardDidConnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.abortCaptureForHardwareChange() }
            .store(in: &hardwareObservers)
    }
}
#endif // !os(tvOS)
