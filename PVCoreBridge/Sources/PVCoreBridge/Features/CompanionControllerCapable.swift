// CompanionControllerCapable.swift
// PVCoreBridge
//
// Input event types and protocol for emulator cores that support companion
// controller input (a second iOS device acting as a physical controller).
//
// These types live in PVCoreBridge so that both core bridges (Tier 4) and
// the UI layer (PVUI, Tier 6) can reference them without a circular dependency.
//
// The PVUI layer owns `CompanionInputRouter`, `CompanionInputState`, and
// `CompanionSlotDelegate` (DSU transport concerns). The core-facing types —
// button/axis identifiers and the capability protocol — live here.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation

// MARK: - CompanionButton

/// Logical button identifiers shared across all companion layouts.
/// Maps onto the DSU button bitmask defined in the DSU protocol.
public enum CompanionButton: UInt32, CaseIterable, Sendable {
    // Face buttons
    case south      = 0x0001   // Cross / A / Vectrex 1
    case east       = 0x0002   // Circle / B / Vectrex 2
    case west       = 0x0004   // Square / X / Vectrex 3
    case north      = 0x0008   // Triangle / Y / Vectrex 4

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
public enum CompanionInputEvent: Equatable, Sendable {
    case buttonDown(CompanionButton)
    case buttonUp(CompanionButton)
    case axisChanged(CompanionAxisID, Float)   // value: -1.0 … 1.0
}

// MARK: - CompanionLayoutID

/// Well-known companion controller layout identifiers shared between core and UI modules.
///
/// Define layout IDs here (PVCoreBridge) so both emulator cores and PVUI can reference
/// the same string without duplicating the literal or creating a cross-module dependency.
public enum CompanionLayoutID {
    /// Companion layout identifier for Atari 2600 trackball games (Centipede, Missile Command…).
    /// `CompanionLayoutFactory` maps this to `TrackballLayout`.
    public static let atari2600Trackball = "com.provenance.atari2600.trackball"
}

// MARK: - CompanionControllerCapable

/// Adopted by emulator cores that support companion controller input.
///
/// The wiring is:
/// 1. A `CompanionControllerSession` contains a `CompanionInputRouter`.
/// 2. Layout components call `router.send(_:)` on each touch event.
/// 3. `CompanionInputRouter` notifies its `slotDelegate` (a `CoreCompanionBridge`)
///    with an updated `CompanionInputState` snapshot.
/// 4. `CoreCompanionBridge` diffs the snapshot and calls `handleCompanionInput(_:forPlayer:)`
///    for each changed button or axis.
///
/// Cores that do not conform are silently skipped when the session is wired.
///
/// ## Layout selection
///
/// Override `preferredCompanionLayoutID` to return a non-nil string when the loaded
/// game requires a specific companion layout (e.g. trackball titles on Atari 2600).
/// The default implementation returns `nil`, which causes the factory to choose the
/// system default layout.
///
/// Example (in a core bridge):
/// ```swift
/// extension MyCoreBridge: CompanionControllerCapable {
///     public var preferredCompanionLayoutID: String? { nil }
///
///     // Note: always called on the main thread by the emulator view controller.
///     public func handleCompanionInput(_ event: CompanionInputEvent, forPlayer player: Int) {
///         switch event {
///         case .buttonDown(let btn):          setButton(btn, pressed: true,  player: player)
///         case .buttonUp(let btn):            setButton(btn, pressed: false, player: player)
///         case .axisChanged(let axis, let v): setAxis(axis, value: v,        player: player)
///         }
///     }
/// }
/// ```
public protocol CompanionControllerCapable: AnyObject {

    // MARK: - Layout

    /// The companion layout identifier for the currently loaded game, or `nil`
    /// to use the system-default layout.
    ///
    /// Return a layout-specific override string (e.g.
    /// `CompanionLayoutID.atari2600Trackball`) when the game needs a
    /// non-standard input overlay.  The `CompanionLayoutFactory` maps this
    /// string to the corresponding `CompanionLayout` implementation.
    var preferredCompanionLayoutID: String? { get }

    // MARK: - Input

    /// Called on every companion input event (button down/up, axis change).
    ///
    /// This method is always called on the **main thread** by the emulator view
    /// controller. Conforming implementations must not dispatch to a background
    /// queue without explicit synchronization.
    ///
    /// - Parameters:
    ///   - event: The input event generated by the companion layout.
    ///   - player: Zero-based player index (0 = player 1).
    func handleCompanionInput(_ event: CompanionInputEvent, forPlayer player: Int)
}

// MARK: - Default implementations

public extension CompanionControllerCapable {
    /// Default: return `nil` so the system-default layout is used.
    var preferredCompanionLayoutID: String? { nil }
}
