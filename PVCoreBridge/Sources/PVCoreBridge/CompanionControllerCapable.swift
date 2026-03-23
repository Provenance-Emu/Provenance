// CompanionControllerCapable.swift
// PVCoreBridge
//
// Protocol adopted by emulator cores that can receive input from a Companion
// Controller overlay (e.g. trackball, numpad, mouse) beyond the standard
// GCController button/axis events.
//
// The PVEmulatorViewController observes the active CompanionInputRouter (PVUI)
// and bridges relevant events to any core that adopts this protocol.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation

// MARK: - Companion layout ID constants

/// Well-known companion controller layout identifiers shared between core and UI modules.
///
/// Define layout IDs here (PVCoreBridge) so both emulator cores and PVUI can reference
/// the same string without duplicating the literal or creating a cross-module dependency.
public enum CompanionLayoutID {
    /// Companion layout identifier for Atari 2600 trackball games (Centipede, Missile Command…).
    /// `CompanionLayoutFactory` maps this to `TrackballLayout`.
    public static let atari2600Trackball = "com.provenance.atari2600.trackball"
}

// MARK: - Companion button bitmask constants

/// Well-known button IDs used by the Companion Controller system.
/// Mirrors `CompanionButton.rawValue` from PVUI without introducing a
/// cross-module import at the PVCoreBridge layer.
public enum CompanionCoreButton: UInt32 {
    case south  = 0x0001   // Cross/A — primary fire
    case east   = 0x0002   // Circle/B — secondary fire / action
    case west   = 0x0004   // Square/X
    case north  = 0x0008   // Triangle/Y
}

// MARK: - CompanionControllerCapable

/// Adopted by emulator cores that can receive input from a Companion Controller
/// overlay (touchscreen trackball, numpad, keyboard, mouse trackpad, etc.).
///
/// The emulator view controller (PVUI tier) is responsible for:
///   1. Detecting that the active core adopts this protocol.
///   2. Subscribing to `CompanionInputRouter`'s published state.
///   3. Forwarding trackball delta and button events to the core whenever the
///      published input state changes (e.g. on gesture updates and button
///      edge changes).
///
/// ## Layout selection
///
/// `preferredCompanionLayoutID` lets the core advertise which companion layout
/// should be shown for the currently loaded game.  Return `nil` to fall back to
/// the default layout for the system (as determined by `CompanionLayoutFactory`).
///
/// Typical usage in a core:
/// ```swift
/// extension PVStellaGameCore: CompanionControllerCapable {
///     public var preferredCompanionLayoutID: String? {
///         // Only show trackball layout for trackball-using titles.
///         guard isTrackballGame else { return nil }
///         return "com.provenance.atari2600.trackball"
///     }
///
///     public func companionTrackballMoved(deltaX: Float, deltaY: Float) {
///         _bridge.setTrackballDeltaX(deltaX, deltaY: deltaY)
///     }
///
///     public func companionButtonDown(_ button: CompanionCoreButton) {
///         if button == .south { _bridge.setMouseButtonLeft(true) }
///     }
///     public func companionButtonUp(_ button: CompanionCoreButton) {
///         if button == .south { _bridge.setMouseButtonLeft(false) }
///     }
/// }
/// ```
public protocol CompanionControllerCapable: AnyObject {

    // MARK: - Layout

    /// The companion layout identifier for the currently loaded game, or `nil`
    /// to use the system-default layout.
    ///
    /// Return a system-specific override string (e.g.
    /// `"com.provenance.atari2600.trackball"`) when the game needs a
    /// non-standard input overlay.  The `CompanionLayoutFactory` maps this
    /// string to the corresponding `CompanionLayout` implementation.
    var preferredCompanionLayoutID: String? { get }

    // MARK: - Trackball / Mouse delta

    /// Deliver a relative trackball/mouse movement delta to the core.
    ///
    /// - Parameters:
    ///   - deltaX: Horizontal movement, normalised to approximately -1.0…1.0
    ///             per gesture update (velocity-based; larger sweeps produce
    ///             larger deltas).
    ///   - deltaY: Vertical movement in the same scale.
    ///
    /// The core is responsible for converting these deltas into whatever
    /// internal representation the emulated peripheral uses (e.g. libretro
    /// `RETRO_DEVICE_MOUSE` X/Y state, paddle register writes, etc.).
    func companionTrackballMoved(deltaX: Float, deltaY: Float)

    // MARK: - Buttons

    /// A companion controller button was pressed.
    ///
    /// - Parameter button: The logical button identifier.
    func companionButtonDown(_ button: CompanionCoreButton)

    /// A companion controller button was released.
    ///
    /// - Parameter button: The logical button identifier.
    func companionButtonUp(_ button: CompanionCoreButton)
}
