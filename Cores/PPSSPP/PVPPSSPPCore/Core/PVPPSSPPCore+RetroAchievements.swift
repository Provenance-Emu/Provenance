//
//  PVPPSSPPCore+RetroAchievements.swift
//  PVPPSSPP
//
//  Conformance of PVPPSSPPCore (PSP) to CoreRetroAchievements via the shared
//  PVRcheevosBridge default impl.
//
//  Memory map:
//    PSP main RAM lives at PSP virtual address 0x08000000, but rcheevos
//    addresses the PSP RAM at FLAT address 0x00000000 (consoleinfo.c column 1:
//    Kernel RAM 0x0 / System RAM 0x800000; 0x08000000 is the *real* bus address
//    in column 3, which rc_client does NOT use). systemRAMPtr already points at
//    the base of PSP RAM, so flat offset indexes directly into it.
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
                rcAddress: 0x00000000,
                base: ptr,
                size: byteCount)
        ]
    }
}
