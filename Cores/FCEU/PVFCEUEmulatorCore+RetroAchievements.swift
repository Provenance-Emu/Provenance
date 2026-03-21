//
//  PVFCEUEmulatorCore+RetroAchievements.swift
//  PVFCEU
//
//  Conformance of PVFCEUEmulatorCore (NES/Famicom) to CoreRetroAchievements.
//
//  ## Current status: protocol conformance stub
//
//  FCEUX does not include rcheevos.  Full integration requires:
//  1. Add a shared PVRcheevos SPM target (wrapping rcheevos C library) as a
//     dependency in Package.swift.
//  2. After `loadFileAtPath:`, hash the ROM and call rc_client_load_game().
//  3. At end of each frame, call rc_client_do_frame() — hook into
//     PVFCEUEmulatorCoreBridge's executeFrame path.
//  4. Expose NES System RAM (0x0000–0x07FF, 2 KiB mirror x4) and cartridge
//     SRAM (0x6000–0x7FFF, 8 KiB) in achievementMemoryRegions().
//  5. Register rc_client_achievement_triggered_callback and forward events
//     to achievementsDelegate.
//

import Foundation
import PVCoreBridge

extension PVFCEUEmulatorCore: CoreRetroAchievements {

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
        // TODO: expose NES System RAM (2 KiB) and cartridge SRAM (8 KiB) once wired.
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
