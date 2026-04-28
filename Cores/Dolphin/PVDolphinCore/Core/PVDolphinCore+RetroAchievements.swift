//
//  PVDolphinCore+RetroAchievements.swift
//  PVDolphin
//
//  Conformance of PVDolphinCore (GameCube/Wii) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map:
//    GameCube — MEM1 (24 MiB) at GC bus address 0x80000000.
//    Wii — adds MEM2 (64 MiB) at Wii bus address 0x90000000.
//
//  rcheevos's GC/Wii memory map mirrors the bus addresses, so we expose
//  the regions at the same rcheevos addresses.
//

import Foundation
import PVCoreBridge
import PVRcheevos
import PVRcheevosBridge

extension PVDolphinCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        var regions: [RcheevosRegion] = []

        if let mem1 = _bridge.systemRAMPtr, _bridge.systemRAMSize > 0 {
            regions.append(
                RcheevosRegion(
                    rcAddress: 0x80000000,
                    base: mem1,
                    size: UInt32(_bridge.systemRAMSize))
            )
        }

        if let mem2 = _bridge.systemEXRAMPtr, _bridge.systemEXRAMSize > 0 {
            regions.append(
                RcheevosRegion(
                    rcAddress: 0x90000000,
                    base: mem2,
                    size: UInt32(_bridge.systemEXRAMSize))
            )
        }

        return regions
    }
}
