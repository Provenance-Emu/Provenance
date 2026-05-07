//
//  PVStellaGameCore+RetroAchievements.swift
//  PVStella
//
//  Conformance of PVStellaGameCore (Atari 2600) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map:
//    Atari 2600 6507 scratch RAM — 128 bytes at rcheevos address 0x0000.
//    Pointer comes from libretro RETRO_MEMORY_SYSTEM_RAM via the bridge.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVRcheevos
import PVRcheevosBridge
import PVStellaBridge

extension PVStellaGameCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        guard let ptr = _bridge.stellaSystemRAMPtr else {
            // [CHEEVOS-DIAG] stellaSystemRAMPtr was nil — bridge not ready.
            ILOG("[CHEEVOS-DIAG] Stella rcheevosRegions: stellaSystemRAMPtr=nil")
            return []
        }
        let byteCount = UInt32(_bridge.stellaSystemRAMSize)
        guard byteCount > 0 else {
            // [CHEEVOS-DIAG] stellaSystemRAMSize was 0 — bridge not ready.
            ILOG("[CHEEVOS-DIAG] Stella rcheevosRegions: byteCount=0 (stellaSystemRAMSize=\(_bridge.stellaSystemRAMSize))")
            return []
        }
        // [CHEEVOS-DIAG] Log region details — Atari 2600 expects 128B at 0x0000.
        ILOG("[CHEEVOS-DIAG] Stella rcheevosRegions rcAddress=0x0000 base=\(String(format: "%p", Int(bitPattern: ptr))) size=\(byteCount)")
        return [
            RcheevosRegion(
                rcAddress: 0x0000,
                base: ptr,
                size: byteCount)
        ]
    }
}
