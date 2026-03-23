// PVEmulatorViewController+CompanionController.swift
// PVUI
//
// Wires the CompanionControllerCapable and CompanionKeyboardMouseCapable protocols
// into PVEmulatorViewController:
//  • "Use as Companion Controller" entry in the pause menu
//  • Session lifecycle: present, wire delegate, tear down on dismiss
//  • System ID propagation to CompanionControllerSession
//  • Per-game layout override via preferredCompanionLayoutID
//  • Keyboard and mouse event subscription for cores that support them
//
// iOS/macCatalyst only — no companion overlay is shown on tvOS or visionOS.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import Combine
import SwiftUI
import PVCoreBridge
import PVLogging
import UIKit

// MARK: - Stored-property shim (associated object)

private enum CompanionAssociatedKeys {
    static var sessionKey:   UInt8 = 0
    static var bridgeKey:    UInt8 = 0
    static var kmCancelKey:  UInt8 = 0   // keyboard/mouse Combine subscription
}

@MainActor
extension PVEmulatorViewController {

    /// The active companion controller session, if any.
    ///
    /// Set when the user opens the companion overlay from the pause menu,
    /// cleared when they dismiss it or the emulator tears down.
    var companionSession: CompanionControllerSession? {
        get {
            objc_getAssociatedObject(self, &CompanionAssociatedKeys.sessionKey)
                as? CompanionControllerSession
        }
        set {
            objc_setAssociatedObject(
                self,
                &CompanionAssociatedKeys.sessionKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Private bridge between the session's input router and the emulator core (button/axis).
    private var _coreInputBridge: CoreCompanionBridge? {
        get {
            objc_getAssociatedObject(self, &CompanionAssociatedKeys.bridgeKey)
                as? CoreCompanionBridge
        }
        set {
            objc_setAssociatedObject(
                self,
                &CompanionAssociatedKeys.bridgeKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Combine subscription for the keyboard/mouse event stream.
    private var _keyboardMouseCancellable: AnyCancellable? {
        get {
            objc_getAssociatedObject(self, &CompanionAssociatedKeys.kmCancelKey)
                as? AnyCancellable
        }
        set {
            objc_setAssociatedObject(
                self,
                &CompanionAssociatedKeys.kmCancelKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Present companion overlay

    /// Present the companion controller host view and wire the session to the core.
    ///
    /// Called from the pause menu when the user taps "Companion Controller".
    /// If the core does not conform to `CompanionControllerCapable`, the overlay is still
    /// presented but button/axis events will not be forwarded to the core.
    /// If the core also conforms to `CompanionKeyboardMouseCapable`, keyboard and mouse
    /// events from the companion layout are forwarded directly.
    func presentCompanionController() {
        // Tear down any existing session before creating a new one.
        tearDownCompanionSession()

        let session = CompanionControllerSession()

        // Propagate the current system ID so CompanionLayoutFactory selects the right layout.
        // Prefer game.systemIdentifier (always populated after ROM load) over the core property.
        session.activeSystemID = game?.systemIdentifier ?? core.systemIdentifier ?? ""

        // Wire the core bridge if the core supports companion button/axis input.
        if let capable = core as? CompanionControllerCapable {
            // Allow the core to override the layout for per-game peripherals
            // (e.g. trackball titles on Atari 2600 return CompanionLayoutID.atari2600Trackball).
            if let preferredID = capable.preferredCompanionLayoutID {
                session.activeSystemID = preferredID
            }

            let bridge = CoreCompanionBridge(capable: capable, playerIndex: 0)
            session.inputRouter.slotDelegate = bridge
            _coreInputBridge = bridge
        } else {
            DLOG("[CompanionController] Core \(type(of: core)) does not conform to CompanionControllerCapable — button/axis events will not be forwarded")
        }

        // Subscribe to keyboard/mouse events if the core supports them.
        if let kmCapable = core as? CompanionKeyboardMouseCapable {
            _keyboardMouseCancellable = session.inputRouter.keyboardMouseEvents
                .receive(on: DispatchQueue.main)
                .sink { event in
                    switch event {
                    case .keyDown(let key):
                        if #available(iOS 14.0, tvOS 14.0, macOS 11.0, *) {
                            kmCapable.companionKeyDown(key)
                        }
                    case .keyUp(let key):
                        if #available(iOS 14.0, tvOS 14.0, macOS 11.0, *) {
                            kmCapable.companionKeyUp(key)
                        }
                    case .mouseMove(let delta):
                        kmCapable.companionMouseMoved(delta: delta)
                    case .mouseButton(let index, let isDown):
                        kmCapable.companionMouseButton(index, isDown: isDown)
                    }
                }
            ILOG("[CompanionController] Subscribed keyboard/mouse events for core \(type(of: core))")
        }

        companionSession = session

        let hostView = CompanionControllerHostView(session: session)
        let hostVC = CompanionHostingController(rootView: hostView)
        hostVC.modalPresentationStyle = .fullScreen

        // Pause emulation while the companion overlay is shown.
        core.setPauseEmulation(true)

        // Resume emulation and tear down the session when the overlay is dismissed.
        hostVC.onDismiss = { [weak self] in
            guard let self else { return }
            self.tearDownCompanionSession()
            self.core.setPauseEmulation(false)
            ILOG("[CompanionController] Companion overlay dismissed — emulation resumed")
        }

        present(hostVC, animated: true)
        ILOG("[CompanionController] Presented companion overlay for system: \(session.activeSystemID)")
    }

    // MARK: - Tear down

    /// Disconnect the session and release all resources.
    ///
    /// Called automatically when the companion overlay is dismissed.
    /// Also safe to call when the emulator itself is dismissed.
    func tearDownCompanionSession() {
        guard let session = companionSession else { return }
        session.disconnect()
        companionSession = nil
        _coreInputBridge = nil
        _keyboardMouseCancellable = nil
        DLOG("[CompanionController] Session torn down")
    }
}

// MARK: - CompanionHostingController

/// UIHostingController subclass that fires `onDismiss` when the view disappears
/// due to being dismissed, enabling the presenter to run cleanup logic.
private final class CompanionHostingController<Content: View>: UIHostingController<Content> {
    var onDismiss: (() -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            onDismiss?()
        }
    }
}

// MARK: - CoreCompanionBridge

/// Private `CompanionSlotDelegate` that diffs input state snapshots and
/// forwards individual `CompanionInputEvent`s to a `CompanionControllerCapable` core.
///
/// This lives in PVUI because `CompanionSlotDelegate` and `CompanionInputState` are
/// PVUI types; `CompanionControllerCapable` and `CompanionInputEvent` are PVCoreBridge types.
///
/// Thread safety: confined to `@MainActor` — all `CompanionSlotDelegate` callbacks
/// are dispatched on the main actor, so no shared mutable state crosses thread boundaries.
@MainActor
private final class CoreCompanionBridge: CompanionSlotDelegate {

    private weak var capable: (any CompanionControllerCapable)?
    private let playerIndex: Int

    // State diff accumulators
    private var lastButtons: UInt32 = 0
    private var lastLeftX:   Float  = 0
    private var lastLeftY:   Float  = 0
    private var lastRightX:  Float  = 0
    private var lastRightY:  Float  = 0
    private var lastL2:      Float  = 0
    private var lastR2:      Float  = 0

    init(capable: any CompanionControllerCapable, playerIndex: Int = 0) {
        self.capable     = capable
        self.playerIndex = playerIndex
    }

    // MARK: CompanionSlotDelegate

    func companionInputRouter(
        _ router: CompanionInputRouter,
        didUpdateState state: CompanionInputState
    ) {
        guard let capable else { return }

        // ── Button diffs ────────────────────────────────────────────────
        let changedButtons = state.buttons ^ lastButtons
        if changedButtons != 0 {
            for button in CompanionButton.allCases {
                guard changedButtons & button.rawValue != 0 else { continue }
                if state.buttons & button.rawValue != 0 {
                    capable.handleCompanionInput(.buttonDown(button), forPlayer: playerIndex)
                } else {
                    capable.handleCompanionInput(.buttonUp(button), forPlayer: playerIndex)
                }
            }
            lastButtons = state.buttons
        }

        // ── Axis diffs ──────────────────────────────────────────────────
        if state.leftX != lastLeftX {
            capable.handleCompanionInput(.axisChanged(.leftX, state.leftX), forPlayer: playerIndex)
            lastLeftX = state.leftX
        }
        if state.leftY != lastLeftY {
            capable.handleCompanionInput(.axisChanged(.leftY, state.leftY), forPlayer: playerIndex)
            lastLeftY = state.leftY
        }
        if state.rightX != lastRightX {
            capable.handleCompanionInput(.axisChanged(.rightX, state.rightX), forPlayer: playerIndex)
            lastRightX = state.rightX
        }
        if state.rightY != lastRightY {
            capable.handleCompanionInput(.axisChanged(.rightY, state.rightY), forPlayer: playerIndex)
            lastRightY = state.rightY
        }
        if state.l2 != lastL2 {
            capable.handleCompanionInput(.axisChanged(.l2Analog, state.l2), forPlayer: playerIndex)
            lastL2 = state.l2
        }
        if state.r2 != lastR2 {
            capable.handleCompanionInput(.axisChanged(.r2Analog, state.r2), forPlayer: playerIndex)
            lastR2 = state.r2
        }
    }
}

#endif // canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
