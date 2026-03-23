// PVEmulatorViewController+CompanionController.swift
// PVUI
//
// Wires the CompanionControllerCapable protocol into PVEmulatorViewController:
//  • "Use as Companion Controller" entry in the pause menu
//  • Session lifecycle: present, wire delegate, tear down on dismiss
//  • System ID propagation to CompanionControllerSession
//  • Combine-based input bridge (setupCompanionControllerBridgeIfNeeded)
//
// iOS/macCatalyst only — no companion overlay is shown on tvOS or visionOS.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if canImport(UIKit) && !os(tvOS)
import SwiftUI
import UIKit
import Combine
import PVCoreBridge
import PVLogging

// MARK: - Stored-property shim (associated object)

private enum CompanionAssociatedKeys {
    static var sessionKey:      UInt8 = 0
    static var bridgeKey:       UInt8 = 0
    static var cancellablesKey: UInt8 = 0
}

@MainActor
extension PVEmulatorViewController {

    // MARK: - Stored properties via associated objects

    /// The active companion controller session, if any.
    ///
    /// Set when the user opens the companion overlay from the pause menu,
    /// cleared when they dismiss it or the emulator tears down.
    public var companionSession: CompanionControllerSession? {
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

    /// Private bridge between the session's input router and the emulator core.
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

    private var companionCancellables: Set<AnyCancellable> {
        get {
            (objc_getAssociatedObject(self, &CompanionAssociatedKeys.cancellablesKey)
                as? CancellablesBox)?.cancellables ?? []
        }
        set {
            let box = CancellablesBox(newValue)
            objc_setAssociatedObject(
                self,
                &CompanionAssociatedKeys.cancellablesKey,
                box,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Capability

    /// Whether the currently active core can receive Companion Controller input.
    public var coreSupportsCompanionController: Bool {
        core is CompanionControllerCapable
    }

    // MARK: - Present companion overlay

    /// Present the companion controller host view and wire the session to the core.
    ///
    /// Called from the pause menu when the user taps "Companion Controller".
    /// If the core does not conform to `CompanionControllerCapable`, the overlay is still
    /// presented but input events will not be forwarded to the core.
    func presentCompanionController() {
        // Tear down any existing session before creating a new one.
        tearDownCompanionSession()

        let session = CompanionControllerSession()

        // Propagate the current system ID so CompanionLayoutFactory selects the right layout.
        // Prefer game.systemIdentifier (always populated after ROM load) over the core property.
        session.activeSystemID = game?.systemIdentifier ?? core.systemIdentifier ?? ""

        // Wire the core bridge if the core supports companion input.
        if let capable = core as? CompanionControllerCapable {
            let bridge = CoreCompanionBridge(capable: capable, playerIndex: 0)
            session.inputRouter.slotDelegate = bridge
            _coreInputBridge = bridge
        } else {
            DLOG("[CompanionController] Core \(type(of: core)) does not conform to CompanionControllerCapable — events will not be forwarded")
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

    // MARK: - Combine-based bridge setup

    /// Attach Companion Controller input forwarding when the core supports it.
    ///
    /// Call this after the core finishes loading a ROM so that `preferredCompanionLayoutID`
    /// (which may depend on the game's MD5 / title) is available.
    ///
    /// - Parameter session: The active companion controller session whose
    ///   `inputRouter` will be subscribed to.
    public func setupCompanionControllerBridgeIfNeeded(session: CompanionControllerSession) {
        guard let companionCore = core as? CompanionControllerCapable else { return }

        // Store the session so it can be referenced later (e.g. for teardown).
        companionSession = session

        // Update the session's active system ID so the correct layout is shown.
        if let preferredID = companionCore.preferredCompanionLayoutID {
            session.activeSystemID = preferredID
        }

        ILOG("[CompanionController] Core adopts CompanionControllerCapable — wiring input router (layoutID: \(session.activeSystemID))")

        var cancellables = Set<AnyCancellable>()

        // Track button mask locally within the sink to compute press/release edges.
        var previousButtonMask: UInt32 = 0

        // Subscribe to button state changes and forward edge events to the core.
        session.inputRouter.$heldButtons
            .removeDuplicates()
            .sink { [weak self] newMask in
                guard self != nil else { return }
                let pressed  = newMask & ~previousButtonMask   // bits newly set
                let released = previousButtonMask & ~newMask   // bits newly cleared
                previousButtonMask = newMask

                for button in [CompanionCoreButton.south, .east, .west, .north] {
                    if pressed  & button.rawValue != 0 { companionCore.companionButtonDown(button) }
                    if released & button.rawValue != 0 { companionCore.companionButtonUp(button) }
                }
            }
            .store(in: &cancellables)

        // Subscribe to axis changes (trackball deltas) and forward to the core.
        //
        // TrackballLayout sends .axisChanged(.leftX, …) and .axisChanged(.leftY, …) as two
        // separate calls, so $axisValues fires twice per gesture update.  Subscribing to
        // each axis independently (with removeDuplicates) ensures only the changed axis
        // triggers a core call, preventing dx from being double-applied.
        session.inputRouter.$axisValues
            .map { $0[.leftX] ?? 0 }
            .removeDuplicates()
            .sink { [weak self] dx in
                guard self != nil, dx != 0 else { return }
                companionCore.companionTrackballMoved(deltaX: dx, deltaY: 0)
            }
            .store(in: &cancellables)

        session.inputRouter.$axisValues
            .map { $0[.leftY] ?? 0 }
            .removeDuplicates()
            .sink { [weak self] dy in
                guard self != nil, dy != 0 else { return }
                companionCore.companionTrackballMoved(deltaX: 0, deltaY: dy)
            }
            .store(in: &cancellables)

        companionCancellables = cancellables
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
        companionCancellables = []
        DLOG("[CompanionController] Session torn down")
    }

    /// Stop forwarding Companion Controller input to the core (Combine bridge only).
    public func teardownCompanionControllerBridge() {
        companionCancellables = []
        companionSession = nil
        ILOG("[CompanionController] Companion input bridge torn down")
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

// MARK: - CancellablesBox

/// Reference-type wrapper so `Set<AnyCancellable>` can be stored via associated objects.
private final class CancellablesBox {
    var cancellables: Set<AnyCancellable>
    init(_ cancellables: Set<AnyCancellable>) {
        self.cancellables = cancellables
    }
}

#endif // canImport(UIKit) && !os(tvOS)
