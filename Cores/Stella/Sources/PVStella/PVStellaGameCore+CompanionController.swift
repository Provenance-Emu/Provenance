// PVStellaGameCore+CompanionController.swift
// PVStella
//
// Wires the Companion Controller's trackball axis events into the Stella core.
//
// The Companion Controller (TrackballLayout) sends relative X/Y deltas and
// button events via CompanionInputRouter.  PVEmulatorViewController detects
// that this core adopts CompanionControllerCapable and forwards those events
// here via handleCompanionInput(_:forPlayer:).
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


// MARK: - CompanionControllerCapable

extension PVStellaGameCore: CompanionControllerCapable {

    // MARK: - Layout selection

    /// Returns the trackball layout ID when the loaded ROM uses a trackball
    /// controller, or `nil` to fall back to the generic Atari 2600 layout.
    ///
    /// Detection uses `TrackballGameRegistry` (MD5 first, then title keywords).
    public var preferredCompanionLayoutID: String? {
        guard isTrackballGame else { return nil }
        return CompanionLayoutID.atari2600Trackball
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

    // MARK: - Input handling

    /// Route a Companion Controller input event to Stella.
    ///
    /// - Axis events map to `RETRO_DEVICE_MOUSE` X/Y deltas consumed in
    ///   `input_state_callback` on the next emulation frame.
    /// - The `.south` button maps to the trackball fire button
    ///   (`RETRO_DEVICE_MOUSE_LEFT`).
    public func handleCompanionInput(_ event: CompanionInputEvent, forPlayer player: Int) {
        switch event {
        case .axisChanged(.leftX, let value):
            _bridge.setTrackballDeltaX(value, deltaY: 0)
        case .axisChanged(.leftY, let value):
            _bridge.setTrackballDeltaX(0, deltaY: value)
        case .buttonDown(.south):
            _bridge.setMouseButtonLeft(true)
        case .buttonUp(.south):
            _bridge.setMouseButtonLeft(false)
        default:
            break
        }
    }
}
