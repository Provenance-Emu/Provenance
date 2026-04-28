//
//  PVSNES9xEmulatorCore+RetroAchievements.swift
//  PVSNES
//
//  Conformance of PVSNES9xEmulatorCore (snes9x) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map:
//    snes9x exposes 128 KiB of WRAM via `Memory.RAM`. We expose it at
//    rcheevos address 0x7E0000 to match the SNES Bus-A WRAM bank
//    convention used by the rcheevos memory map for the SNES system.
//

import Foundation
import PVCoreBridge
import PVRcheevos
import PVRcheevosBridge

extension PVSNES9xEmulatorCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        let snesBridge = bridge as? PVSNESEmulatorCoreBridge
        guard let ptr = snesBridge?.systemRAMPtr else { return [] }
        let byteCount = UInt32(snesBridge?.systemRAMSize ?? 0)
        guard byteCount > 0 else { return [] }
        return [
            RcheevosRegion(
                rcAddress: 0x7E0000,
                base: ptr,
                size: byteCount)
        ]
    }
}
