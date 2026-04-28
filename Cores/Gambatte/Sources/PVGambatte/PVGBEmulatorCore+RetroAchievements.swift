//
//  PVGBEmulatorCore+RetroAchievements.swift
//  PVGambatte
//
//  Conformance of PVGBEmulatorCore (Gambatte GB/GBC) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map (rcheevos addresses match GB CPU bus addresses):
//    WRAM — 8 KiB (DMG) / 32 KiB (GBC) at 0xC000
//    VRAM — 8 KiB (DMG) / 16 KiB (GBC) at 0x8000
//

import Foundation
import PVCoreBridge
import PVGambatteBridge
import PVRcheevos
import PVRcheevosBridge

extension PVGBEmulatorCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        var regions: [RcheevosRegion] = []

        if let wramPtr = _bridge.wramBasePtr {
            let wramSize = UInt32(_bridge.wramSize)
            if wramSize > 0 {
                regions.append(
                    RcheevosRegion(
                        rcAddress: 0xC000,
                        base: wramPtr,
                        size: wramSize)
                )
            }
        }

        if let vramPtr = _bridge.vramBasePtr {
            let vramSize: UInt32 = _bridge.isGameboyColor ? 0x4000 : 0x2000
            regions.append(
                RcheevosRegion(
                    rcAddress: 0x8000,
                    base: vramPtr,
                    size: vramSize)
            )
        }

        return regions
    }
}
