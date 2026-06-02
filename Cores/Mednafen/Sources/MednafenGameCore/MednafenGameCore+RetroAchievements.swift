//
//  MednafenGameCore+RetroAchievements.swift
//  PVMednafen
//
//  Conformance of MednafenGameCore to CoreRetroAchievements via the shared
//  PVRcheevosBridge default implementation. Cores only need to expose the
//  RAM regions they want rcheevos to read; lifecycle, per-frame tick, and
//  delegate plumbing are provided by the bridge.
//
//  ## System memory maps (rcheevos address space)
//
//  | System  | Region           | rcheevos addr | Size         | Swap        |
//  |---------|------------------|---------------|--------------|-------------|
//  | PSX     | Main RAM         | 0x00000000    | 2 MB         | none        |
//  | NES     | CPU RAM          | 0x0000        | 2 KB         | none        |
//  | SNES    | Work RAM         | 0x000000      | 128 KB       | none        |
//  | PCE     | Base RAM         | 0x1F0000      | 8 KB / 32 KB | none        |
//  | Saturn  | Low Work RAM     | 0x000000      | 1 MB         | word16      |
//  | Saturn  | High Work RAM    | 0x100000      | 1 MB         | word16      |
//

import Foundation
import PVCoreBridge
import PVPrimitives
import PVRcheevos
import PVRcheevosBridge
import PVSystems
import PVLogging
import MednafenGameCoreC
import MednafenGameCoreOptions

extension MednafenGameCore: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        guard let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") else { return [] }
        switch sysID {

        case .PSX:
            guard let ptr = mdfn_psx_mainram_ptr() else { return [] }
            return [RcheevosRegion(rcAddress: 0x00000000,
                                   base: UnsafeMutableRawPointer(ptr),
                                   size: UInt32(mdfn_psx_mainram_size()))]

        case .NES, .FDS:
            guard let ptr = mdfn_nes_ram_ptr() else { return [] }
            return [RcheevosRegion(rcAddress: 0x0000,
                                   base: UnsafeMutableRawPointer(ptr),
                                   size: UInt32(mdfn_nes_ram_size()))]

        case .SNES:
            guard MednafenGameCoreOptions.mednafen_snesFast else { return [] }
            guard let ptr = mdfn_snes_faust_wram_ptr() else { return [] }
            // Flat rcheevos SNES System RAM is 0x000000 (consoleinfo.c col 1);
            // 0x7E0000 is the real Bus-A bank (col 3) rc_client does not use.
            return [RcheevosRegion(rcAddress: 0x000000,
                                   base: UnsafeMutableRawPointer(ptr),
                                   size: UInt32(mdfn_snes_faust_wram_size()))]

        case .Saturn:
            guard let ptrL = mdfn_ss_workraml_ptr(),
                  let ptrH = mdfn_ss_workramh_ptr() else { return [] }
            return [
                RcheevosRegion(rcAddress: 0x000000,
                               base: UnsafeMutableRawPointer(ptrL),
                               size: UInt32(mdfn_ss_workraml_size()),
                               byteSwapMode: .word16),
                RcheevosRegion(rcAddress: 0x100000,
                               base: UnsafeMutableRawPointer(ptrH),
                               size: UInt32(mdfn_ss_workramh_size()),
                               byteSwapMode: .word16),
            ]

        case .PCE, .PCECD, .SGFX:
            // Flat rcheevos PCE System RAM is 0x000000 (consoleinfo.c:779/786);
            // 0x1F0000 is the real bus address (col 3) rc_client never queries,
            // so PCE cheevos were dead. (CD RAM / Super System Card / CD save RAM
            // regions are a separate device-validated follow-up.)
            if MednafenGameCoreOptions.mednafen_pceFast {
                guard let ptr = mdfn_pce_fast_baseram_ptr() else { return [] }
                return [RcheevosRegion(rcAddress: 0x000000,
                                       base: UnsafeMutableRawPointer(ptr),
                                       size: UInt32(mdfn_pce_fast_baseram_size()))]
            } else {
                guard let ptr = mdfn_pce_baseram_ptr() else { return [] }
                return [RcheevosRegion(rcAddress: 0x000000,
                                       base: UnsafeMutableRawPointer(ptr),
                                       size: UInt32(mdfn_pce_baseram_size()))]
            }

        default:
            return []
        }
    }
}
