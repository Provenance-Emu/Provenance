//
//  PVRetroArchCoreCore+RetroAchievements.swift
//  PVRetroArchCore
//
//  Conformance of PVRetroArchCoreCore to CoreRetroAchievements.
//
//  ## Architecture note — GL-layer vs native OSD
//
//  RetroArch already ships cheevos.c which drives rcheevos internally.
//  When HAVE_CHEEVOS is defined (it is, in the existing build), RetroArch:
//    - Renders unlock/progress/challenge badges directly into its GL
//      frame buffer via its menu/notification subsystem.
//    - Manages the rcheevos client lifecycle internally (login, game
//      identification, session keep-alive via pings).
//    - Reads credentials from retroarch.cfg (RetroArchConfigManager
//      writes these after the user authenticates via PVCheevos).
//
//  This conformance therefore does NOT replicate the GL-OSD logic.
//  It wires the `achievementsDelegate` so the Swift/SwiftUI layer can:
//    - Play a native iOS haptic / sound on unlock.
//    - Update PVLibrary progress tracking (CloudKit).
//    - Show a native SwiftUI toast when the game runs in a mode where
//      RetroArch's GL overlay is unavailable (e.g. Metal renderer).
//
//  ## Full integration plan
//  1. In PVLibRetroCore.m, when HAVE_CHEEVOS is defined, intercept the
//     cheevos callback notifications (cheevos_set_rcheevos_callbacks)
//     and forward them to a Swift-side handler.
//  2. The Swift handler constructs the appropriate notification model
//     and calls `achievementsDelegate?.achievementUnlocked(...)` etc.
//  3. Hardcore mode should be read from / written to RetroArchConfigManager.
//

import Foundation
import PVCoreBridge

extension PVRetroArchCoreCore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    /// RetroArch manages its own session; this is a no-op.
    /// Credentials are pushed via RetroArchConfigManager before the core loads.
    public func prepareAchievements(gameHash: String) async {
        // RetroArch handles game identification and session setup internally
        // via cheevos.c / rcheevos client.
    }

    /// RetroArch manages its own teardown.
    public func stopAchievements() {}

    // MARK: - Per-frame tick

    /// RetroArch calls rcheevos per-frame internally — no external tick needed.
    public func tickAchievements() {}

    // MARK: - Memory regions

    /// RetroArch exposes memory to rcheevos via RETRO_ENVIRONMENT_GET_MEMORY_DATA;
    /// there is nothing to return here.
    public func achievementMemoryRegions() -> [AchievementMemoryRegion] { [] }

    // MARK: - State

    public var achievementsActive: Bool {
        // TODO: query cheevos_state() once the C-to-Swift bridge is wired.
        return false
    }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set {
            _hardcoreMode = newValue
            // TODO: update RetroArchConfigManager when implemented.
        }
    }
}
