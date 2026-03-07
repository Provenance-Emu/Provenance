//
//  MednafenGameCore+RetroAchievements.swift
//  PVMednafen
//
//  Conformance of MednafenGameCore to CoreRetroAchievements.
//
//  ## Current status: protocol conformance stub
//
//  Mednafen is a multi-system emulator covering PSX, Saturn, PCE, VB, WS,
//  NES, SNES, GBA, GB, Lynx, and Neo Geo Pocket — all of which have
//  RetroAchievements support via the RA database.
//
//  Full integration requires:
//  1. Link rcheevos (available at Cores/DuckStation/cmake/dep/rcheevos or
//     via a shared PVRcheevos SPM target to be created).
//  2. After loadFileAtPath:, identify the system and hash the ROM with the
//     correct rcheevos hasher for that console.
//  3. Call rc_client_load_game() with the hash.
//  4. In executeFrame, call rc_client_do_frame() after the mednafen tick.
//  5. Expose the relevant system RAM regions in achievementMemoryRegions().
//  6. Forward rc_client callbacks to achievementsDelegate.
//

import Foundation
import PVCoreBridge

extension MednafenGameCore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    public func prepareAchievements(gameHash: String) async {
        // TODO: call rc_client_load_game once rcheevos is linked.
    }

    public func stopAchievements() {
        // TODO: call rc_client_unload_game once rcheevos is linked.
    }

    // MARK: - Per-frame tick

    public func tickAchievements() {
        // TODO: call rc_client_do_frame once rcheevos is linked.
    }

    // MARK: - Memory regions

    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        // TODO: expose system-specific memory maps once rcheevos is linked.
        // Each Mednafen system module exposes its RAM differently.
        return []
    }

    // MARK: - State

    public var achievementsActive: Bool {
        return false // TODO: reflect rc_client state
    }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }
}
