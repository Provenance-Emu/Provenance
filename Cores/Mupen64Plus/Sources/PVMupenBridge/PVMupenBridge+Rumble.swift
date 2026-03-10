//
//  PVMupenBridge+Rumble.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 3/10/26.
//

import Foundation
import PVCoreBridge

@objc extension PVMupenBridge {
    /// Trigger a player-specific N64 RumblePak haptic pulse.
    /// Called from `MupenControllerCommand` when a rumble write is detected.
    @objc func rumbleForPlayer(_ player: Int) {
        guard supportsRumble else { return }
        if #available(iOS 14.0, tvOS 14.0, *) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rumble(lowFrequency: 1.0, highFrequency: 0.3, duration: 0.5, player: player)
            }
        }
    }

    /// Stop rumble for the given player index.
    /// Called from `MupenControllerCommand` when the rumble write is cleared.
    @objc func stopRumbleForPlayer(_ player: Int) {
        if #available(iOS 14.0, tvOS 14.0, *) {
            Task { @MainActor [weak self] in
                self?.stopRumble(player: player)
            }
        }
    }
}
