//
//  PVGBEmulatorCore+RetroAchievements.swift
//  PVGambatte
//
//  Conformance of PVGBEmulatorCore (Gambatte GB/GBC core) to CoreRetroAchievements.
//
//  ## Current status: protocol conformance stub
//
//  Gambatte does not include rcheevos.  Full integration requires:
//  1. Add rcheevos source (or link the PVCheevos rcheevos target) to the
//     Gambatte SPM target in Package.swift.
//  2. After `loadFileAtPath:`, hash the ROM and call rc_client_load_game().
//  3. At end of each frame, call rc_client_do_frame() — hook into
//     PVGambatteBridge's executeFrame path.
//  4. Expose GB WRAM (0xC000–0xDFFF, 8 KiB) and VRAM (0x8000–0x9FFF, 8 KiB)
//     in achievementMemoryRegions().
//  5. Register rc_client_achievement_triggered_callback and forward events
//     to achievementsDelegate.
//

import Foundation
import PVCoreBridge

extension PVGBEmulatorCore: CoreRetroAchievements {

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
        // TODO: expose GB WRAM (8 KiB) and VRAM (8 KiB) once wired.
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
