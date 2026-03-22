// PVStellaGameCore+CompanionController.swift
// PVStella
//
// Wires the Companion Controller's trackball axis events into the Stella core.
//
// The Companion Controller (TrackballLayout) sends relative X/Y deltas and
// button events via CompanionInputRouter.  PVEmulatorViewController detects
// that this core adopts CompanionControllerCapable and forwards those events
// here each main-run-loop pass.
//
// Input mapping:
//   .axisChanged(.leftX, v)  → trackball horizontal delta (RETRO_DEVICE_MOUSE X)
//   .axisChanged(.leftY, v)  → trackball vertical delta   (RETRO_DEVICE_MOUSE Y)
//   .buttonDown(.south)      → fire button down            (RETRO_DEVICE_MOUSE_LEFT)
//   .buttonUp(.south)        → fire button up
//
// Controller-type detection:
//   The trackball companion layout is only offered when the loaded ROM is known
//   to use a trackball peripheral.  Detection is done by TrackballGameRegistry
//   using the ROM's MD5 hash and/or title string.  The preferredCompanionLayoutID
//   property communicates this to PVEmulatorViewController so the factory can
//   vend a TrackballLayout instead of the generic Atari 2600 layout.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation
import PVCoreBridge
import PVSystems
import PVStellaBridge

// MARK: - Layout ID constant

/// Companion layout identifier used for Atari 2600 trackball games.
/// `CompanionLayoutFactory` maps this string to `TrackballLayout`.
public let kAtari2600TrackballLayoutID = "com.provenance.atari2600.trackball"

// MARK: - CompanionControllerCapable

extension PVStellaGameCore: CompanionControllerCapable {

    // MARK: - Layout selection

    /// Returns the trackball layout ID when the loaded ROM uses a trackball
    /// controller, or `nil` to fall back to the generic Atari 2600 layout.
    ///
    /// Detection uses `TrackballGameRegistry` (MD5 first, then title keywords).
    public var preferredCompanionLayoutID: String? {
        guard isTrackballGame else { return nil }
        return kAtari2600TrackballLayoutID
    }

    /// `true` when the currently loaded ROM is a known trackball title.
    ///
    /// Reads from `TrackballGameRegistry` using the ROM's MD5 hash and title.
    /// Falls back to `false` for unrecognised ROMs so the generic layout is
    /// shown rather than a trackball overlay that won't work.
    var isTrackballGame: Bool {
        TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: romMD5,
            title: romName
        )
    }

    // MARK: - Trackball movement

    /// Route a relative trackball delta from the Companion Controller to Stella.
    ///
    /// The Stella libretro core reads the pending deltas in `input_state_callback`
    /// on the next frame as `RETRO_DEVICE_MOUSE` X/Y values.  Deltas accumulate
    /// between frames and are zeroed after consumption.
    ///
    /// - Parameters:
    ///   - deltaX: Normalised horizontal delta (-1.0…1.0 per gesture update).
    ///   - deltaY: Normalised vertical delta.
    public func companionTrackballMoved(deltaX: Float, deltaY: Float) {
        _bridge.setTrackballDeltaX(deltaX, deltaY: deltaY)
    }

    // MARK: - Buttons

    /// Route a Companion Controller button press to Stella.
    ///
    /// `.south` (the large red FIRE button on TrackballLayout) maps to the
    /// trackball's fire button (`RETRO_DEVICE_MOUSE_LEFT`).
    public func companionButtonDown(_ button: CompanionCoreButton) {
        switch button {
        case .south:
            _bridge.setMouseButtonLeft(true)
        default:
            break
        }
    }

    /// Route a Companion Controller button release to Stella.
    public func companionButtonUp(_ button: CompanionCoreButton) {
        switch button {
        case .south:
            _bridge.setMouseButtonLeft(false)
        default:
            break
        }
    }
}
