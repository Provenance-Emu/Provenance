//
//  PVTGBDualCore+RetroAchievements.swift
//  PVTGBDual
//
//  Conformance of PVTGBDualCore (Game Boy / Game Boy Color) to
//  CoreRetroAchievements via the shared PVRcheevosBridge default impl.
//
//  Memory map (flat rcheevos GB/GBC addresses — consoleinfo.c):
//    Work RAM at 0xC000, clamped to the 8 KiB flat window (0xC000-0xDFFF). GBC's
//      32 KiB buffer must NOT be exposed as one block here or it overruns into
//      Echo/IO/HRAM (false reads); banks 2-7 belong at flat 0x10000 (TODO device).
//    Video RAM at 0x8000, clamped to 8 KiB — the rcheevos GB/GBC map has no second
//      VRAM bank, and 0x4000 overruns into SAVE_RAM (0xA000) corrupting reads.
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
            // Clamp to the 8 KiB flat window (0xC000-0xDFFF) so GBC's 32 KiB buffer
            // does not overrun into Echo/IO/HRAM and produce false reads.
            let wramSize = min(UInt32(_bridge.wramSize), 0x2000)
            if wramSize > 0 {
                regions.append(RcheevosRegion(
                    rcAddress: 0xC000,
                    base: wramPtr,
                    size: wramSize))
            }
        }
        if let vramPtr = _bridge.vramBasePtr {
            // Single 8 KiB VRAM window at 0x8000; clamp so a GBC 0x4000 size does
            // not overrun into SAVE_RAM (0xA000-0xBFFF).
            let vramSize = min(UInt32(_bridge.vramSize), 0x2000)
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
