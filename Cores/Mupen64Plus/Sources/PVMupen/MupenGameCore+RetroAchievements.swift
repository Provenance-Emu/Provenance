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
//

import Foundation
import PVCoreBridge
import PVLogging
import PVMupen64PlusBridge
import PVRcheevos
import PVRcheevosBridge

extension MupenGameCore: CoreRetroAchievements {

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
