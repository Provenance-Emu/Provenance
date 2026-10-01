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

// `RcheevosRegionProviding` is required: `rcheevosRegions()` is not a requirement of
// `CoreRetroAchievements` (only a protocol-extension default), so without this
// conformance PVRcheevosBridge statically binds to the empty default and never sees
// the region below.
extension PVPPSSPPCore: CoreRetroAchievements, RcheevosRegionProviding {

    /// rcheevos PSP map spans flat 0x0...0x01FFFFFF (consoleinfo.c); PSP-2000 mode
    /// reports a 64 MiB `g_MemorySize`, but only this much is addressable by rcheevos.
    private static let rcheevosPSPRAMSize: UInt32 = 0x0200_0000

    func rcheevosRegions() -> [RcheevosRegion] {
        guard let ptr = _bridge.systemRAMPtr else { return [] }
        let byteCount = min(UInt32(truncatingIfNeeded: _bridge.systemRAMSize), Self.rcheevosPSPRAMSize)
        guard byteCount > 0 else { return [] }
        return [
            RcheevosRegion(
                rcAddress: 0x00000000,
                base: ptr,
                size: byteCount)
        ]
    }
}
