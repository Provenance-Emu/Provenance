//
//  PVMupen64Plus-NXCore+Rumble.swift
//  PVMupen64Plus-NX
//
//  Part of #2743 — Tier 2 haptics: wire N64 RumblePak to PVCoreBridge HapticsManager
//  Part of #3130 — Timing-based haptic patterns + per-system profiles
//

import Foundation
import PVCoreBridge
import PVLogging
#if canImport(GameController) && canImport(CoreHaptics)
import GameController
import CoreHaptics
#endif

public extension PVMupen64PlusNXCore {

    /// Register the N64 haptic profile on the shared HapticsManager.
    /// Call this once when emulation starts to ensure N64-specific tuning is active.
    @objc func setupRumbleProfile() {
        if #available(iOS 14.0, tvOS 14.0, *) {
            Task { @MainActor in
#if canImport(GameController) && canImport(CoreHaptics)
                GCControllerHapticsManager.shared.setSystemProfile(forSystemIdentifier: "com.provenance.n64")
#endif
            }
        }
    }

    /// Trigger a player-specific N64 RumblePak haptic pulse.
    /// Called from MupenControllerCommand (emulation thread) when PAK_IO_RUMBLE write is detected.
    @objc func rumbleForPlayer(_ player: Int) {
        guard supportsRumble else { return }
        if #available(iOS 14.0, tvOS 14.0, *) {
            // N64 RumblePak: heavy low-frequency thump, minimal high-frequency component.
            // Use a long duration (10s) so the haptic plays continuously until stopRumbleForPlayer
            // is called — the manager will classify the burst on stop.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rumble(lowFrequency: 1.0, highFrequency: 0.2, duration: 10.0, player: player)
            }
        }
    }

    /// Stop rumble for the given player index.
    /// Called from MupenControllerCommand when PAK_IO_RUMBLE is cleared (zero write).
    @objc func stopRumbleForPlayer(_ player: Int) {
        if #available(iOS 14.0, tvOS 14.0, *) {
            Task { @MainActor [weak self] in
                self?.stopRumble(player: player)
            }
        }
    }
}
