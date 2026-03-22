// CompanionInputRouter.swift
// PVUI
//
// Translates button/axis events from a CompanionLayout into DSU slot state updates.
// Acts as the bridge between the SwiftUI overlay and the DSU transport layer.
//
// CompanionButton, CompanionAxisID, and CompanionInputEvent are defined in
// PVCoreBridge so that emulator core bridges (Tier 4) can adopt
// CompanionControllerCapable without depending on PVUI.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation
import Combine
import PVCoreBridge

// CompanionButton, CompanionAxisID, CompanionInputEvent — re-exported from PVCoreBridge.

// MARK: - CompanionInputRouter

/// Collects input events from layout components and forwards them to the
/// active DSU session slot.
///
/// Layout components call `send(_:)` on this object whenever a touch begins
/// or ends. The router maintains the current bitmask / axis state and pushes
/// updates to DSU via the `DSUSlotDelegate` protocol.
public final class CompanionInputRouter: ObservableObject {

    // MARK: - Published state (for debug overlays)

    /// Bitmask of currently held buttons.
    @Published public private(set) var heldButtons: UInt32 = 0

    /// Current axis values keyed by axis ID.
    @Published public private(set) var axisValues: [CompanionAxisID: Float] = [:]

    // MARK: - DSU delegation

    /// The object that forwards state updates to the DSU transport.
    /// Nil until a DSU session is connected.
    public weak var slotDelegate: (any CompanionSlotDelegate)?

    // MARK: - Init

    public init(slotDelegate: (any CompanionSlotDelegate)? = nil) {
        self.slotDelegate = slotDelegate
    }

    // MARK: - Event ingestion

    /// Send an input event from a layout component.
    @MainActor public func send(_ event: CompanionInputEvent) {
        switch event {
        case .buttonDown(let btn):
            heldButtons |= btn.rawValue
        case .buttonUp(let btn):
            heldButtons &= ~btn.rawValue
        case .axisChanged(let axis, let value):
            axisValues[axis] = value
        }
        slotDelegate?.companionInputRouter(self, didUpdateState: currentState)
    }

    // MARK: - State snapshot

    /// Current snapshot of all inputs, ready to be serialised into a DSU packet.
    public var currentState: CompanionInputState {
        CompanionInputState(
            buttons: heldButtons,
            leftX:   axisValues[.leftX]    ?? 0,
            leftY:   axisValues[.leftY]    ?? 0,
            rightX:  axisValues[.rightX]   ?? 0,
            rightY:  axisValues[.rightY]   ?? 0,
            l2:      axisValues[.l2Analog] ?? 0,
            r2:      axisValues[.r2Analog] ?? 0
        )
    }
}

// MARK: - CompanionInputState

/// Serialisable snapshot of all companion controller inputs.
public struct CompanionInputState: Sendable {
    public var buttons: UInt32
    public var leftX:  Float
    public var leftY:  Float
    public var rightX: Float
    public var rightY: Float
    public var l2:     Float
    public var r2:     Float

    public init(
        buttons: UInt32 = 0,
        leftX: Float = 0, leftY: Float = 0,
        rightX: Float = 0, rightY: Float = 0,
        l2: Float = 0, r2: Float = 0
    ) {
        self.buttons = buttons
        self.leftX   = leftX
        self.leftY   = leftY
        self.rightX  = rightX
        self.rightY  = rightY
        self.l2      = l2
        self.r2      = r2
    }
}

// MARK: - CompanionSlotDelegate

/// Implemented by the DSU transport layer to receive state updates.
/// When `PVControllerDSU` lands, this will be implemented by `DSUServerSlot`.
public protocol CompanionSlotDelegate: AnyObject, Sendable {
    /// Called every time the companion router has a new input snapshot ready.
    @MainActor
    func companionInputRouter(
        _ router: CompanionInputRouter,
        didUpdateState state: CompanionInputState
    )
}
