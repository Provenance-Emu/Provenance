//
//  PVFCEUEmulatorCore+RetroAchievements.swift
//  PVFCEU
//
//  Conformance of PVFCEUEmulatorCore (NES/Famicom) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl. Mirror of the SNES9x pattern at
//  Cores/snes9x/PVSNES/SNES/PVSNES9xEmulatorCore+RetroAchievements.swift.
//
//  Memory map:
//    FCEUX exposes 2 KiB of internal NES RAM via the `RAM` global. The
//    rcheevos NES memory map expects this block at bus address 0x0000
//    (mirrored four times across 0x0000-0x1FFF). Cartridge SRAM at
//    0x6000-0x7FFF is per-cart and not exposed here yet — most NES
//    achievements operate on the internal RAM block alone.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVRcheevos
import PVRcheevosBridge

extension PVFCEUEmulatorCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        let fceuBridge = bridge as? PVFCEUEmulatorCoreBridge
        guard let ptr = fceuBridge?.systemRAMPtr else {
            ILOG("[CHEEVOS-DIAG] FCEU rcheevosRegions: systemRAMPtr=nil bridge=\(fceuBridge.map { String(describing: type(of: $0)) } ?? "nil")")
            return []
        }
        let byteCount = UInt32(fceuBridge?.systemRAMSize ?? 0)
        guard byteCount > 0 else {
            ILOG("[CHEEVOS-DIAG] FCEU rcheevosRegions: byteCount=0 (systemRAMSize=\(fceuBridge?.systemRAMSize ?? 0))")
            return []
        }
        ILOG("[CHEEVOS-DIAG] FCEU rcheevosRegions rcAddress=0x0000 base=\(String(format: "%p", Int(bitPattern: ptr))) size=\(byteCount)")
        return [
            RcheevosRegion(
                rcAddress: 0x0000,
                base: ptr,
                size: byteCount)
        ]
    }
}
