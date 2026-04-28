//
//  PVPokeMiniEmulatorCore+RetroAchievements.swift
//  PVPokeMini
//
//  Conformance of PVPokeMiniEmulatorCore (Pokemon Mini) to
//  CoreRetroAchievements via the shared PVRcheevosBridge default impl.
//
//  Memory map:
//    The Pokemon Mini RAM block (`PM_RAM`, 8 KiB — 4 KiB RAM + 4 KiB I/O,
//    covering CPU addresses $001000–$002FFF) is exposed at rcheevos
//    address 0x0000. This matches what the libretro core publishes via
//    RETRO_MEMORY_SYSTEM_RAM.
//

import Foundation
import PVCoreBridge
import PVPokeMiniBridge
import PVRcheevos
import PVRcheevosBridge

extension PVPokeMiniEmulatorCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        guard let ptr = _bridge.systemRAMPtr else { return [] }
        let byteCount = UInt32(_bridge.systemRAMSize)
        guard byteCount > 0 else { return [] }
        return [
            RcheevosRegion(
                rcAddress: 0x0000,
                base: ptr,
                size: byteCount)
        ]
    }
}
