// PVEmulatorViewController+CompanionController.swift
// PVUI
//
// Wires the CompanionControllerCapable protocol into PVEmulatorViewController:
//  • "Use as Companion Controller" entry in the pause menu
//  • Session lifecycle: present, wire delegate, tear down on dismiss
//  • System ID propagation to CompanionControllerSession
//
// iOS only — no companion overlay is shown on tvOS.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI
import PVCoreBridge
import PVLogging
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Stored-property shim (associated object)

private enum CompanionAssociatedKeys {
    static var sessionKey = "CompanionControllerSession"
    static var bridgeKey  = "CompanionCoreInputBridge"
}

@MainActor
extension PVEmulatorViewController {

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

    // MARK: - Present companion overlay

    /// Present the companion controller host view and wire the session to the core.
    ///
    /// Called from the pause menu when the user taps "Companion Controller".
    /// No-ops if the core does not conform to `CompanionControllerCapable`.
    public func presentCompanionController() {
        let session = CompanionControllerSession()

        // Propagate the current system ID so CompanionLayoutFactory selects the right layout.
        session.activeSystemID = core.systemIdentifier ?? ""

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
        let hostVC = UIHostingController(rootView: hostView)
        hostVC.modalPresentationStyle = .fullScreen
        hostVC.presentationController?.delegate = self as? UIAdaptivePresentationControllerDelegate

        // Pause emulation while the companion overlay is shown.
        core.setPauseEmulation(true)

        present(hostVC, animated: true)
        ILOG("[CompanionController] Presented companion overlay for system: \(session.activeSystemID)")
    }

    // MARK: - Tear down

    /// Disconnect the session and release all resources.
    ///
    /// Call this when the emulator is dismissed or when the user closes the
    /// companion overlay.
    public func tearDownCompanionSession() {
        guard let session = companionSession else { return }
        session.disconnect()
        companionSession = nil
        _coreInputBridge = nil
        DLOG("[CompanionController] Session torn down")
    }
}

// MARK: - CoreCompanionBridge

/// Private `CompanionSlotDelegate` that diffs input state snapshots and
/// forwards individual `CompanionInputEvent`s to a `CompanionControllerCapable` core.
///
/// This lives in PVUI because `CompanionSlotDelegate` and `CompanionInputState` are
/// PVUI types; `CompanionControllerCapable` and `CompanionInputEvent` are PVCoreBridge types.
@MainActor
private final class CoreCompanionBridge: CompanionSlotDelegate, @unchecked Sendable {

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

#endif // !os(tvOS)
