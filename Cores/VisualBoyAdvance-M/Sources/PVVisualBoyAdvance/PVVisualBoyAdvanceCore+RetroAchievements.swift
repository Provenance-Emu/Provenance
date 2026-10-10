//
//  PVVisualBoyAdvanceCore+RetroAchievements.swift
//  PVVisualBoyAdvance
//
//  Conformance of PVVisualBoyAdvanceCore (GBA) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map (GBA, FLAT rcheevos addresses from consoleinfo.c column 1 — NOT
//  the GBA bus addresses in column 3, which rc_client does not use):
//    IWRAM —  32 KiB at flat 0x000000  (bus 0x03000000)
//    EWRAM — 256 KiB at flat 0x008000  (bus 0x02000000)
//    Save RAM — 64 KiB at flat 0x048000 (bus 0x0E000000), a per-frame mirror of
//    libretro's RETRO_MEMORY_SAVE_RAM view (EEPROM: eepromData; SRAM/flash:
//    flashSaveMemory), omitted when the cart has no save storage.
//  VRAM is NOT part of the rcheevos GBA map, so it is intentionally not exposed.
//

import Foundation
import PVCoreBridge
import PVVisualBoyAdvanceBridge
import PVRcheevos
import PVRcheevosBridge

extension PVVisualBoyAdvanceCore: CoreRetroAchievements, RcheevosRegionProviding {

    public func rcheevosRegions() -> [RcheevosRegion] {
        var regions: [RcheevosRegion] = []
        regions.reserveCapacity(3)

        // IWRAM first — flat rcheevos address 0x000000 (consoleinfo.c GBA col 1)
        if let iwram = _bridge.iwramBasePtr {
            regions.append(
                RcheevosRegion(
                    rcAddress: 0x000000,
                    base: iwram,
                    size: UInt32(32 * 1024))
            )
        }
        // EWRAM — flat rcheevos address 0x008000
        if let ewram = _bridge.ewramBasePtr {
            regions.append(
                RcheevosRegion(
                    rcAddress: 0x008000,
                    base: ewram,
                    size: UInt32(256 * 1024))
            )
        }
        // Save RAM — flat rcheevos address 0x048000, clamped to the 64 KiB rcheevos maps.
        var saveSize: UInt = 0
        if let save = _bridge.saveRAMMirrorPointer(&saveSize), saveSize > 0 {
            regions.append(
                RcheevosRegion(
                    rcAddress: 0x048000,
                    base: save,
                    size: UInt32(min(Int(saveSize), 64 * 1024)))
            )
        }
        return regions
    }

    /// Ticks the shared session after every emulated frame. The emulation loop
    /// runs in the bridge, which never calls this core's `executeFrame()`.
    func installAchievementHooks() {
        // Not gated on `achievementsActive`: the shared lazy region retry in
        // `tickAchievements()` must run while no session exists yet. Called
        // through the existential so the PVRcheevosBridge default is used, not
        // PVCoreBridge's no-op.
        _bridge.frameCompletedHandler = { [weak self] in
            guard let core: any CoreRetroAchievements = self else { return }
            core.tickAchievements()
        }
    }
}
