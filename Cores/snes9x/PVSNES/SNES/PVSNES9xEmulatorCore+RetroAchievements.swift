//
//  PVSNES9xEmulatorCore+RetroAchievements.swift
//  PVSNES
//
//  Conformance of PVSNES9xEmulatorCore (snes9x) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map:
//    snes9x exposes 128 KiB of WRAM via `Memory.RAM`. rcheevos addresses the
//    SNES System RAM at FLAT address 0x000000 (consoleinfo.c column 1). The
//    0x7E0000 SNES Bus-A WRAM bank is the *real* address (column 3), which
//    rc_client does NOT use — RcheevosRegion.rcAddress must be the flat value.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVRcheevos
import PVRcheevosBridge

extension PVSNES9xEmulatorCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        let snesBridge = bridge as? PVSNESEmulatorCoreBridge
        guard let ptr = snesBridge?.systemRAMPtr else {
            // [CHEEVOS-DIAG] systemRAMPtr was nil — bridge not ready or core didn't expose RAM.
            ILOG("[CHEEVOS-DIAG] SNES9x rcheevosRegions: systemRAMPtr=nil bridge=\(snesBridge.map { String(describing: type(of: $0)) } ?? "nil")")
            return []
        }
        let byteCount = UInt32(snesBridge?.systemRAMSize ?? 0)
        guard byteCount > 0 else {
            // [CHEEVOS-DIAG] systemRAMSize was 0 — likely race with core init.
            ILOG("[CHEEVOS-DIAG] SNES9x rcheevosRegions: byteCount=0 (systemRAMSize=\(snesBridge?.systemRAMSize ?? 0))")
            return []
        }
        // [CHEEVOS-DIAG] First-call dump of region details (log every call — cheap and bounded).
        ILOG("[CHEEVOS-DIAG] SNES9x rcheevosRegions rcAddress=0x000000 base=\(String(format: "%p", Int(bitPattern: ptr))) size=\(byteCount)")
        return [
            RcheevosRegion(
                rcAddress: 0x000000,
                base: ptr,
                size: byteCount)
        ]
    }
}
