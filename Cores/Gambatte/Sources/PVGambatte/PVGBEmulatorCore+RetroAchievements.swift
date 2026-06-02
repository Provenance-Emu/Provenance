//
//  PVGBEmulatorCore+RetroAchievements.swift
//  PVGambatte
//
//  Conformance of PVGBEmulatorCore (Gambatte GB/GBC) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map (flat rcheevos GB/GBC addresses — consoleinfo.c):
//    WRAM — base window 0xC000-0xDFFF (8 KiB). On GBC the buffer is 32 KiB, but
//           the flat window at 0xC000 is only 8 KiB (bank 0 + the active bank);
//           GBC banks 2-7 live at flat 0x10000-0x15FFF. We clamp to 0x2000 so the
//           region does NOT overrun into Echo/IO/HRAM (0xE000+) — that overrun
//           produced false reads. TODO(device): expose banks 2-7 at flat 0x10000.
//    VRAM — 0x8000-0x9FFF (8 KiB). The rcheevos GB/GBC map has no second VRAM
//           bank, so we clamp to 0x2000; a 0x4000 region overruns into SAVE_RAM
//           (0xA000-0xBFFF) and corrupts cartridge-RAM achievement reads.
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
            // Clamp to the 0xC000-0xDFFF flat window (8 KiB) so GBC's 32 KiB buffer
            // does not overrun into Echo/IO/HRAM and produce false reads.
            let wramSize = min(UInt32(_bridge.wramSize), 0x2000)
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
            // rcheevos GB/GBC map exposes a single 8 KiB VRAM window at 0x8000;
            // a 0x4000 GBC size overruns into SAVE_RAM (0xA000), so clamp to 0x2000.
            let vramSize: UInt32 = 0x2000
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
