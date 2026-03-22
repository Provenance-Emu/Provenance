// CompanionControllerCapable.swift
// PVCoreBridge
//
// Protocol and bitmask constants for routing Companion Controller input to
// emulator cores.  Lives in PVCoreBridge so that both the UI layer
// (PVEmulatorVC) and individual core modules can reference it without
// creating circular dependencies.
//
// Wiring:
//   CompanionInputRouter (PVUIBase)
//     → CompanionSlotDelegate (PVEmulatorVC)
//       → CompanionControllerCapable (this protocol, implemented by each core)
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation

// MARK: - CompanionButtonBits

/// Bitmask constants for companion controller buttons.
///
/// These values are identical to `CompanionButton.rawValue` in PVUIBase and
/// to the DSU button bitmask defined in the DSU protocol.  They are mirrored
/// here so that core modules (which cannot import PVUIBase) can decode the
/// bitmask delivered through ``CompanionControllerCapable``.
public enum CompanionButtonBits {
    // Face buttons
    public static let south:     UInt32 = 0x0001   // Cross / A  → left action
    public static let east:      UInt32 = 0x0002   // Circle / B → right action
    public static let west:      UInt32 = 0x0004   // Square / X
    public static let north:     UInt32 = 0x0008   // Triangle / Y

    // Shoulder
    public static let l1:        UInt32 = 0x0010
    public static let r1:        UInt32 = 0x0020
    public static let l2:        UInt32 = 0x0040
    public static let r2:        UInt32 = 0x0080

    // Special
    public static let select:    UInt32 = 0x0100
    public static let start:     UInt32 = 0x0200
    public static let l3:        UInt32 = 0x0400
    public static let r3:        UInt32 = 0x0800

    // D-pad
    public static let dpadUp:    UInt32 = 0x1000
    public static let dpadDown:  UInt32 = 0x2000
    public static let dpadLeft:  UInt32 = 0x4000
    public static let dpadRight: UInt32 = 0x8000

    // Numpad digits (for systems with keypads: ColecoVision, Atari 5200, etc.)
    public static let num0:      UInt32 = 0x0001_0000
    public static let num1:      UInt32 = 0x0002_0000
    public static let num2:      UInt32 = 0x0004_0000
    public static let num3:      UInt32 = 0x0008_0000
    public static let num4:      UInt32 = 0x0010_0000
    public static let num5:      UInt32 = 0x0020_0000
    public static let num6:      UInt32 = 0x0040_0000
    public static let num7:      UInt32 = 0x0080_0000
    public static let num8:      UInt32 = 0x0100_0000
    public static let num9:      UInt32 = 0x0200_0000
    public static let numStar:   UInt32 = 0x0400_0000   // * key
    public static let numHash:   UInt32 = 0x0800_0000   // # key
}

// MARK: - CompanionControllerCapable

/// Adopted by emulator cores that can accept input from the Companion
/// Controller overlay.
///
/// The UI layer (typically `PVEmulatorVC`) acts as a `CompanionSlotDelegate`,
/// receives `CompanionInputState` snapshots from the router, computes the
/// delta from the previous state, and then calls
/// ``companionButtonsChanged(held:pressed:released:forPlayer:)`` on any core
/// that conforms to this protocol.
///
/// ## Implementing a new core
///
/// 1. Create `PV<Core>Core+CompanionController.swift` alongside the core.
/// 2. Extend the core class with `CompanionControllerCapable`.
/// 3. In the method body, iterate over the relevant `CompanionButtonBits`
///    constants and forward presses/releases to the system-specific responder.
///
/// See `PVGearcolecoCore+CompanionController.swift` for a reference
/// implementation mapping the ColecoVision 12-key numpad.
public protocol CompanionControllerCapable: AnyObject {

    /// Called on the main thread each time the companion-controller button
    /// state changes.
    ///
    /// The UI layer tracks the previous state so that `pressed` and `released`
    /// are accurate deltas; the core does not need to debounce.
    ///
    /// - Parameters:
    ///   - held:     Bitmask of all buttons currently held down.
    ///               Bit positions match ``CompanionButtonBits``.
    ///   - pressed:  Bits that transitioned released → held in this update.
    ///   - released: Bits that transitioned held → released in this update.
    ///   - player:   Zero-based player index.
    func companionButtonsChanged(
        held: UInt32,
        pressed: UInt32,
        released: UInt32,
        forPlayer player: Int
    )
}
