//
//  MednafenGameCore+RetroAchievements.swift
//  PVMednafen
//
//  Conformance of MednafenGameCore to CoreRetroAchievements.
//
//  ## Integration status
//
//  Phase 1 (this file) — memory region wiring:
//  - achievementMemoryRegions() returns correct RAM pointers for each system
//    via the `mdfn_*_ptr()` / `mdfn_*_size()` C accessors defined at the end
//    of each system's .cpp file.
//  - achievementsActive returns true for supported systems while running.
//  - executeFrame is overridden to call tickAchievements() after each frame.
//
//  Phase 2 (future PR) — rcheevos runtime:
//  - Link PVRcheevos (shared SPM target wrapping rcheevos C library).
//  - prepareAchievements: call rc_client_load_game() with the MD5 hash.
//  - tickAchievements: call rc_client_do_frame().
//  - stopAchievements: call rc_client_unload_game().
//  - Register rc_client callbacks and forward events to achievementsDelegate.
//
//  ## System memory maps (rcheevos address space)
//
//  | System  | Region           | rcheevos addr | Size   |
//  |---------|------------------|---------------|--------|
//  | PSX     | Main RAM         | 0x00000000    | 2 MB   |
//  | NES     | CPU RAM          | 0x0000        | 2 KB   |
//  | Saturn  | Work RAM Low     | 0x00200000    | 1 MB   |
//  | Saturn  | Work RAM High    | 0x06000000    | 1 MB   |
//  | PCE     | Base RAM         | 0x1F0000      | 8 KB   |
//  | SNES    | Work RAM         | 0x7E0000      | 128 KB |
//

import Foundation
import PVCoreBridge
import PVPrimitives
import MednafenGameCoreC
import MednafenGameCoreOptions

extension MednafenGameCore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    public func prepareAchievements(gameHash: String) async {
        // Phase 2: call rc_client_load_game(client, gameHash) once PVRcheevos is linked.
        // The game hash is the MD5 of the ROM/disc image (supplied by PVHashing).
    }

    public func stopAchievements() {
        // Phase 2: call rc_client_unload_game(client) once PVRcheevos is linked.
    }

    // MARK: - Per-frame tick

    /// Advance the achievement runtime by one emulated frame.
    ///
    /// Called from `executeFrame` (in MednafenGameCore.swift) after the Mednafen
    /// core has updated all memory.  Phase 2 will call `rc_client_do_frame()` here.
    public func tickAchievements() {
        // Phase 2: call rc_client_do_frame(client) once PVRcheevos is linked.
        // Memory regions returned by achievementMemoryRegions() will be read here.
    }

    // MARK: - Memory regions

    /// Return the RAM regions rcheevos should read for the currently loaded system.
    ///
    /// Pointers come from the `mdfn_*_ptr()` C accessors appended to each system's
    /// mednafen .cpp file.  They are valid for the lifetime of the loaded game.
    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        guard let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") else { return [] }
        switch sysID {

        case .PSX:
            // 2 MB main RAM (0x00000000–0x001FFFFF in rcheevos address space)
            guard let ptr = mdfn_psx_mainram_ptr() else { return [] }
            return [AchievementMemoryRegion(base: UnsafeMutableRawPointer(ptr),
                                            size: mdfn_psx_mainram_size(),
                                            kind: .systemRAM)]

        case .NES, .FDS:
            // 2 KB CPU RAM (0x0000–0x07FF, mirrored to 0x1FFF)
            guard let ptr = mdfn_nes_ram_ptr() else { return [] }
            return [AchievementMemoryRegion(base: UnsafeMutableRawPointer(ptr),
                                            size: mdfn_nes_ram_size(),
                                            kind: .systemRAM)]

        case .SNES:
            // 128 KB Work RAM (0x7E0000–0x7FFFFF)
            // Only snes_faust exposes a direct pointer; legacy snes core is unsupported.
            guard MednafenGameCoreOptions.mednafen_snesFast else { return [] }
            guard let ptr = mdfn_snes_faust_wram_ptr() else { return [] }
            return [AchievementMemoryRegion(base: UnsafeMutableRawPointer(ptr),
                                            size: mdfn_snes_faust_wram_size(),
                                            kind: .systemRAM)]

        case .Saturn:
            // 1 MB Work RAM Low  (0x00200000–0x002FFFFF)
            // 1 MB Work RAM High (0x06000000–0x060FFFFF)
            guard let ptrL = mdfn_ss_workraml_ptr(),
                  let ptrH = mdfn_ss_workramh_ptr() else { return [] }
            return [
                AchievementMemoryRegion(base: UnsafeMutableRawPointer(ptrL),
                                        size: mdfn_ss_workraml_size(),
                                        kind: .systemRAM),
                AchievementMemoryRegion(base: UnsafeMutableRawPointer(ptrH),
                                        size: mdfn_ss_workramh_size(),
                                        kind: .systemRAM),
            ]

        case .PCE, .PCECD, .SGFX:
            // 8 KB base RAM for PCE/PCECD, 32 KB for SuperGrafx (0x1F0000–0x1F1FFF / 0x1F7FFF)
            if MednafenGameCoreOptions.mednafen_pceFast {
                guard let ptr = mdfn_pce_fast_baseram_ptr() else { return [] }
                return [AchievementMemoryRegion(base: UnsafeMutableRawPointer(ptr),
                                                size: mdfn_pce_fast_baseram_size(),
                                                kind: .systemRAM)]
            } else {
                guard let ptr = mdfn_pce_baseram_ptr() else { return [] }
                return [AchievementMemoryRegion(base: UnsafeMutableRawPointer(ptr),
                                                size: mdfn_pce_baseram_size(),
                                                kind: .systemRAM)]
            }

        default:
            return []
        }
    }

    // MARK: - State

    /// True when the current system has RetroAchievements support in Mednafen
    /// and the emulation is running.
    ///
    /// Phase 2 will also require a valid rc_client session before returning true.
    public var achievementsActive: Bool {
        guard isRunning else { return false }
        guard let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") else { return false }
        switch sysID {
        case .PSX, .NES, .FDS, .Saturn, .PCE, .PCECD, .SGFX:
            return true
        case .SNES:
            // Only snes_faust exposes a RAM pointer; legacy snes core is unsupported.
            return MednafenGameCoreOptions.mednafen_snesFast
        default:
            return false
        }
    }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }
}
