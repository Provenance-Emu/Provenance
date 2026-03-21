//
//  PVVisualBoyAdvanceCore+RetroAchievements.swift
//  PVVisualBoyAdvance
//
//  Conformance of PVVisualBoyAdvanceCore to CoreRetroAchievements.
//
//  ## Current status: protocol conformance stub
//
//  VisualBoyAdvance-M does not include rcheevos.  Full integration requires:
//  1. Add a shared PVRcheevos SPM target (wrapping rcheevos C library) as a
//     dependency in Package.swift.
//  2. After `loadFileAtPath:`, hash the ROM and call rc_client_load_game().
//  3. At end of each frame, call rc_client_do_frame() — hook into
//     PVVisualBoyAdvanceBridge's executeFrame path.
//  4. Expose GBA IWRAM (0x03000000, 32 KiB), EWRAM (0x02000000, 256 KiB),
//     and VRAM (0x06000000, 96 KiB) in achievementMemoryRegions().
//  5. Register rc_client_achievement_triggered_callback and forward events
//     to achievementsDelegate.
//
//  Note: mGBA (PVmGBACore) is preferred for GBA achievements due to superior
//  accuracy and upstream rcheevos support.  This stub enables VBA-M as a
//  fallback path.
//

import Foundation
import PVCoreBridge

extension PVVisualBoyAdvanceCore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    public func prepareAchievements(gameHash: String) async {
        // TODO: call rc_client_load_game once PVRcheevos is linked.
    }

    public func stopAchievements() {
        // TODO: call rc_client_unload_game once PVRcheevos is linked.
    }

    // MARK: - Per-frame tick

    public func tickAchievements() {
        // TODO: call rc_client_do_frame once PVRcheevos is linked.
    }

    // MARK: - Memory regions

    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        // TODO: expose GBA IWRAM (32 KiB), EWRAM (256 KiB), VRAM (96 KiB).
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
