//
//  PVTGBDualCore+RetroAchievements.swift
//  PVTGBDual
//
//  Conformance of PVTGBDualCore (Game Boy / Game Boy Color) to
//  CoreRetroAchievements via the shared PVRcheevosBridge default impl.
//
//  Memory map:
//    Work RAM (libretro RETRO_MEMORY_SYSTEM_RAM) is exposed at rcheevos
//    address 0xC000 (DMG: 8 KiB; GBC: 32 KiB across the swappable banks).
//    Video RAM (libretro RETRO_MEMORY_VIDEO_RAM) is exposed at 0x8000
//    (DMG: 8 KiB; GBC: 16 KiB across both VRAM banks).
//

import Foundation
import PVCoreBridge
import PVRcheevos
import PVRcheevosBridge
import PVTGBDualBridge

extension PVTGBDualCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        var regions: [RcheevosRegion] = []
        if let wramPtr = _bridge.wramBasePtr {
            let wramSize = UInt32(_bridge.wramSize)
            if wramSize > 0 {
                regions.append(RcheevosRegion(
                    rcAddress: 0xC000,
                    base: wramPtr,
                    size: wramSize))
            }
        }
        if let vramPtr = _bridge.vramBasePtr {
            let vramSize = UInt32(_bridge.vramSize)
            if vramSize > 0 {
                regions.append(RcheevosRegion(
                    rcAddress: 0x8000,
                    base: vramPtr,
                    size: vramSize))
            }
        }
        return regions
    }
}
