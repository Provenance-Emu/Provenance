//
//  PVPPSSPPCore+RetroAchievements.swift
//  PVPPSSPP
//
//  Conformance of PVPPSSPPCore (PSP) to CoreRetroAchievements via the shared
//  PVRcheevosBridge default impl.
//
//  Memory map:
//    PSP main RAM lives at PSP virtual address 0x08000000 (32 MiB on retail
//    PSP, 64 MiB on PSP-2000). rcheevos's PSP memory map mirrors this — the
//    region is exposed at rcheevos address 0x08000000.
//

import Foundation
import PVCoreBridge
import PVRcheevos
import PVRcheevosBridge

extension PVPPSSPPCore: CoreRetroAchievements {

    func rcheevosRegions() -> [RcheevosRegion] {
        guard let ptr = _bridge.systemRAMPtr else { return [] }
        let byteCount = UInt32(_bridge.systemRAMSize)
        guard byteCount > 0 else { return [] }
        return [
            RcheevosRegion(
                rcAddress: 0x08000000,
                base: ptr,
                size: byteCount)
        ]
    }
}
