//
//  MupenGameCore+RetroAchievements.swift
//  PVMupenGameCore
//
//  CoreRetroAchievements conformance for the native Mupen64Plus N64 core via
//  the shared PVRcheevosBridge default impl. Only the memory map needs to be
//  declared here — lifecycle, per-frame tick, hardcore flag, and delegate
//  plumbing come from the bridge.
//
//  Memory region:
//    N64 RDRAM — 8 MiB at rcheevos address 0x00000000.
//    Mupen64Plus always allocates 8 MiB; games that use only the base 4 MiB
//    leave the upper half zeroed. rcheevos is tolerant of this.
//    rcheevos consoleinfo.c splits N64 into three flat ranges (0x000000-0x1FFFFF,
//    0x200000-0x3FFFFF, 0x400000-0x7FFFFF expansion pak) that are contiguous, so
//    one 8 MiB region at flat 0 covers all of them.
//
//  Byte order: `.off` on purpose. Mupen stores RDRAM as host-endian 32-bit
//  words, so on little-endian hosts each word's bytes are reversed versus N64
//  bus order. RetroArch hands rcheevos exactly that raw view
//  (mupen64plus-next returns g_dev.rdram.dram for RETRO_MEMORY_SYSTEM_RAM, and
//  rc_libretro.c applies no swap), and RetroAchievements N64 sets are authored
//  against it. Swapping here would break every N64 set.
//
//  Per-frame tick: driven by `PVMupenBridge.frameCompletedHandler` (see
//  MupenGameCore.init), not `executeFrame()`.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVMupen64PlusBridge
import PVRcheevos
import PVRcheevosBridge

extension MupenGameCore: CoreRetroAchievements, RcheevosRegionProviding {

    public func rcheevosRegions() -> [RcheevosRegion] {
        var rdramSize: UInt = 0
        guard let ptr = _bridge.rdramPointer(&rdramSize), rdramSize > 0 else {
            WLOG("Mupen64Plus RDRAM not yet available — achievements memory region empty")
            return []
        }
        return [
            RcheevosRegion(
                rcAddress: 0x00000000,
                base: ptr,
                size: UInt32(rdramSize))
        ]
    }
}
