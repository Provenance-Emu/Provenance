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
//  VRAM is NOT part of the rcheevos GBA map, so it is intentionally not exposed.
//  TODO(device): add GamePak Save RAM at flat 0x048000 (needs a bridge sram accessor).
//

import Foundation
import PVCoreBridge
import PVVisualBoyAdvanceBridge
import PVRcheevos
import PVRcheevosBridge

extension PVVisualBoyAdvanceCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        var regions: [RcheevosRegion] = []
        regions.reserveCapacity(2)

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
        return regions
    }
}
