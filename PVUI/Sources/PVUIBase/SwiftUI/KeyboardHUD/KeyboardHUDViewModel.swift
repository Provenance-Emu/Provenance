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
    private var hardwareObservers: Set<AnyCancellable> = []

    public init() {
        observeHardwareKeyboardChanges()
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

    /// Ends capture normally: the keyboard hardware hasn't changed since
    /// capture began, so the handler saved beforehand is still correct to
    /// restore.
    public func endCapture() {
        if let saved = savedKeyHandler {
            GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = saved
            savedKeyHandler = nil
        }
        capturingAction = nil
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
