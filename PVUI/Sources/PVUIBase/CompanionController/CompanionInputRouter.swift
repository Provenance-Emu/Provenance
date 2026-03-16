// CompanionInputRouter.swift
// PVUI
//
// Translates button/axis events from a CompanionLayout into DSU slot state updates.
// Acts as the bridge between the SwiftUI overlay and the DSU transport layer.
//
// When the DSU module (PVControllerDSU) lands, replace the stub types below with
// real imports from that module.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation
import Combine

// MARK: - CompanionButton

/// Logical button identifiers shared across all companion layouts.
/// Maps onto the DSU button bitmask defined in the DSU protocol.
public enum CompanionButton: UInt32, CaseIterable, Sendable {
    // Face buttons
    case south      = 0x0001   // Cross / A
    case east       = 0x0002   // Circle / B
    case west       = 0x0004   // Square / X
    case north      = 0x0008   // Triangle / Y

    // Shoulder
    case l1         = 0x0010
    case r1         = 0x0020
    case l2         = 0x0040
    case r2         = 0x0080

    // Special
    case select     = 0x0100
    case start      = 0x0200
    case l3         = 0x0400
    case r3         = 0x0800

    // D-pad
    case dpadUp     = 0x1000
    case dpadDown   = 0x2000
    case dpadLeft   = 0x4000
    case dpadRight  = 0x8000

    // Numpad digits (extra buttons for systems with keypads)
    case num0       = 0x00010000
    case num1       = 0x00020000
    case num2       = 0x00040000
    case num3       = 0x00080000
    case num4       = 0x00100000
    case num5       = 0x00200000
    case num6       = 0x00400000
    case num7       = 0x00800000
    case num8       = 0x01000000
    case num9       = 0x02000000
    case numStar    = 0x04000000   // * (Atari/Coleco side button)
    case numHash    = 0x08000000   // # (Atari/Coleco side button)
}

// MARK: - CompanionAxisID

/// Named axes for joystick and trigger events.
public enum CompanionAxisID: Hashable, Sendable {
    case leftX, leftY
    case rightX, rightY
    case l2Analog, r2Analog
}

// MARK: - CompanionInputEvent

/// A discrete input event emitted by a companion layout component.
public enum CompanionInputEvent: Sendable {
    case buttonDown(CompanionButton)
    case buttonUp(CompanionButton)
    case axisChanged(CompanionAxisID, Float)   // value: -1.0 … 1.0
}

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
