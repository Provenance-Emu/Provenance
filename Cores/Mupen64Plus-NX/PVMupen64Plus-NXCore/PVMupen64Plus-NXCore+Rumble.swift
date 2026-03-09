//
//  PVMupen64Plus-NXCore+Rumble.swift
//  PVMupen64Plus-NX
//
//  Part of #2743 — Tier 2 haptics: wire N64 RumblePak to PVCoreBridge HapticsManager
//

import Foundation
import PVCoreBridge
import PVLogging

public extension PVMupen64PlusNXCore {
    /// Trigger a player-specific N64 RumblePak haptic pulse.
    /// Called from MupenControllerCommand (emulation thread) when PAK_IO_RUMBLE write is detected.
    @objc func rumbleForPlayer(_ player: Int) {
        guard supportsRumble else { return }
        if #available(iOS 14.0, tvOS 14.0, *) {
            // N64 RumblePak = strong low-frequency thump, brief high-frequency component.
            // Dispatch to MainActor since HapticsManager is @MainActor.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rumble(lowFrequency: 1.0, highFrequency: 0.3, duration: 0.5, player: player)
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
