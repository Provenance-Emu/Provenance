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
import PVRcheevos
import PVRcheevosBridge
import PVStellaBridge

extension PVStellaGameCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        guard let ptr = _bridge.stellaSystemRAMPtr else { return [] }
        let byteCount = UInt32(_bridge.stellaSystemRAMSize)
        guard byteCount > 0 else { return [] }
        return [
            RcheevosRegion(
                rcAddress: 0x0000,
                base: ptr,
                size: byteCount)
        ]
    }
}
