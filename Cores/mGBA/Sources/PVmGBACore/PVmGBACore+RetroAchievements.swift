//
//  PVmGBACore+RetroAchievements.swift
//  PVmGBACore
//
//  Conformance of PVmGBACore to CoreRetroAchievements.
//
//  ## Current status: protocol conformance stub
//
//  mGBA has built-in rcheevos support (src/core/achievements.c in upstream),
//  but this Provenance build does not yet compile that source nor link the
//  full rcheevos library.  This file declares conformance so that:
//    - The type system enforces the interface contract now, and
//    - The next developer knows exactly where to hook in the real callbacks.
//
//  ## Full integration plan
//  1. Enable `src/core/achievements.c` (and deps) in libmGBA target in
//     Package.swift — add `HAVE_CHEATS` / `HAVE_ACHIEVEMENTS` defines.
//  2. In `-initialize`, call `mCoreCallbacksInit(&callbacks)` and set
//     `callbacks.achievementUnlocked` / `callbacks.achievementProgress`.
//  3. Call `tickAchievements()` (which calls `mCoreTick()`) after
//     `core->runFrame()` in `executeFrame`.
//  4. Populate `achievementMemoryRegions()` by querying
//     `core->getMemoryBlock(REGION_WORKING_RAM, &size)` etc.
//

import Foundation
import PVCoreBridge
import PVmGBABridge

extension PVmGBACore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    public func prepareAchievements(gameHash: String) async {
        // TODO: call mCoreAchievementsLoadGame(core, gameHash) once
        // the achievements source files are compiled into libmGBA.
    }

    public func stopAchievements() {
        // TODO: call mCoreAchievementsUnloadGame(core) once wired up.
    }

    // MARK: - Per-frame tick

    public func tickAchievements() {
        // TODO: call mCoreAchievementsTick(core) once wired up.
    }

    // MARK: - Memory regions

    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        // TODO: expose GBA IWRAM (0x03000000, 32 KiB) and EWRAM (0x02000000, 256 KiB).
        // Return empty until fully wired.
        return []
    }

    // MARK: - State

    public var achievementsActive: Bool {
        return false // TODO: reflect actual runtime state
    }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }
}
