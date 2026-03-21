//
//  PVDuckStationCore+RetroAchievements.swift
//  PVDuckStation
//
//  Conformance of PVDuckStationCore (PSX) to CoreRetroAchievements.
//
//  ## Current status: protocol conformance stub
//
//  DuckStation has its own built-in RetroAchievements implementation in
//  its upstream source (Achievements namespace, powered by rcheevos).
//  The Provenance build does not yet activate that path.  Full integration
//  requires one of two approaches:
//
//  ### Option A — Enable DuckStation's native rcheevos (preferred)
//  1. Set `WITH_ACHIEVEMENTS=ON` / `ENABLE_CHEEVOS=1` in cmake/Package.swift
//     to compile DuckStation's own achievements.cpp and the bundled rcheevos.
//  2. After loading a disc, DuckStation internally calls the RA login flow.
//     Pass the stored credentials from PVCheevos.RetroCredentialsManager.
//  3. Bridge DuckStation's achievement-triggered callback to achievementsDelegate
//     (add a C++ → ObjC++ shim in PVDuckStationCoreBridge.mm).
//  4. Bypass PVCheevos.AchievementSessionManager for DuckStation — it manages
//     its own session.  Set achievementsActive = true once DuckStation confirms
//     the game is loaded and credentials are valid.
//
//  ### Option B — Shared PVRcheevos SPM target
//  If Option A is too invasive, link the shared PVRcheevos target and drive
//  rcheevos externally, exposing PSX RAM via achievementMemoryRegions().
//  PSX main RAM is 2 MiB (0x80000000–0x801FFFFF).
//

import Foundation
import PVCoreBridge

extension PVDuckStationCore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    public func prepareAchievements(gameHash: String) async {
        // TODO (Option A): pass credentials to DuckStation's internal achievement
        //   loader — Achievements::Initialize(username, token).
        // TODO (Option B): call rc_client_load_game once PVRcheevos is linked.
    }

    public func stopAchievements() {
        // TODO (Option A): call Achievements::Shutdown() via bridge.
        // TODO (Option B): call rc_client_unload_game once PVRcheevos is linked.
    }

    // MARK: - Per-frame tick

    public func tickAchievements() {
        // TODO (Option A): DuckStation ticks rcheevos internally — no-op here.
        // TODO (Option B): call rc_client_do_frame once PVRcheevos is linked.
    }

    // MARK: - Memory regions

    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        // TODO (Option B): expose PSX main RAM (2 MiB) once PVRcheevos is linked.
        // Option A manages memory internally — return empty.
        return []
    }

    // MARK: - State

    public var achievementsActive: Bool {
        return false // TODO: reflect DuckStation or rc_client runtime state
    }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }
}
