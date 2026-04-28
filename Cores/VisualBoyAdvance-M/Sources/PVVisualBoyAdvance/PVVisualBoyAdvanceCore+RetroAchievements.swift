//
//  PVVisualBoyAdvanceCore+RetroAchievements.swift
//  PVVisualBoyAdvance
//
//  Conformance of PVVisualBoyAdvanceCore (GBA) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map (GBA, rcheevos addresses match GBA bus addresses):
//    EWRAM — 256 KiB at 0x02000000
//    IWRAM —  32 KiB at 0x03000000
//    VRAM  —  96 KiB at 0x06000000
//

import Foundation
import PVCoreBridge
import PVVisualBoyAdvanceBridge
import PVRcheevos
import PVRcheevosBridge

extension PVVisualBoyAdvanceCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        var regions: [RcheevosRegion] = []
        regions.reserveCapacity(3)

        if let ewram = _bridge.ewramBasePtr {
            regions.append(
                RcheevosRegion(
                    rcAddress: 0x02000000,
                    base: ewram,
                    size: UInt32(256 * 1024))
            )
        }
        if let iwram = _bridge.iwramBasePtr {
            regions.append(
                RcheevosRegion(
                    rcAddress: 0x03000000,
                    base: iwram,
                    size: UInt32(32 * 1024))
            )
        }
        if let vram = _bridge.vbaVramBasePtr {
            regions.append(
                RcheevosRegion(
                    rcAddress: 0x06000000,
                    base: vram,
                    size: UInt32(96 * 1024))
            )
        }
        return regions
    }
}
