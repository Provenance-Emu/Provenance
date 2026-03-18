//
//  MupenGameCore+Rumble.swift
//  PVMupenGameCore
//
//  Created by Joseph Mattiello on 8/18/24.
//
//  Part of #3130 — Timing-based haptic patterns + per-system profiles
//  Applies N64 haptic profile on session start/stop so the shared
//  GCControllerHapticsManager routes rumble with correct N64 characteristics.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
#if canImport(GameController) && canImport(CoreHaptics)
import GameController
import CoreHaptics
#endif

@objc extension MupenGameCore { // : EmulatorCoreRumbleDataSource { // (Rumble)

    @objc public override var supportsRumble: Bool { true }

    /// Set the N64 haptic profile on emulation start so controller motors are tuned
    /// to approximate the original RumblePak characteristics.
    /// `startEmulation()` is @MainActor — call GCControllerHapticsManager directly.
    public override func startEmulation() {
#if canImport(GameController) && canImport(CoreHaptics)
        if #available(iOS 14.0, tvOS 14.0, *) {
            GCControllerHapticsManager.shared.setSystemProfile(
                forSystemIdentifier: systemIdentifier ?? "com.provenance.n64"
            )
        }
#endif
        super.startEmulation()
    }

    /// Reset the haptic profile so the next core starts with neutral tuning.
    /// `stopEmulation()` is @MainActor — call GCControllerHapticsManager directly.
    public override func stopEmulation() {
#if canImport(GameController) && canImport(CoreHaptics)
        if #available(iOS 14.0, tvOS 14.0, *) {
            GCControllerHapticsManager.shared.resetSystemProfile()
        }
#endif
        super.stopEmulation()
    }
}
