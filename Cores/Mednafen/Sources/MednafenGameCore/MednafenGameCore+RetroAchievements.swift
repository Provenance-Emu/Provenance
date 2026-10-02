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
//  Every `rcAddress` is the FLAT address from column 1 of rcheevos's
//  `consoleinfo.c`, never the real bus address (column 3).
//
//  | System  | Region             | rcheevos addr | Size           | Swap   |
//  |---------|--------------------|---------------|----------------|--------|
//  | PSX     | Main RAM           | 0x000000      | 2 MB           | none   |
//  | NES     | CPU RAM            | 0x0000        | 2 KB           | none   |
//  | FDS     | FDS RAM            | 0x6000        | 32 KB          | none   |
//  | SNES    | Work RAM           | 0x000000      | 128 KB         | none   |
//  | PCE     | Base RAM           | 0x000000      | 8 KB / 32 KB   | none   |
//  | Saturn  | Low Work RAM       | 0x000000      | 1 MB           | word16 |
//  | Saturn  | High Work RAM      | 0x100000      | 1 MB           | word16 |
//  | Lynx    | RAM                | 0x0000        | 64 KB          | none   |
//  | NGP/C   | Work RAM           | 0x0000        | 16 KB          | none   |
//  | PC-FX   | RAM                | 0x000000      | 2 MB           | none   |
//  | PC-FX   | Internal backup    | 0x200000      | 32 KB          | none   |
//  | PC-FX   | External backup    | 0x208000      | 32 KB          | none   |
//  | VB      | Work RAM           | 0x000000      | 64 KB          | none   |
//  | VB      | Cartridge RAM      | 0x010000      | 64 KB          | none   |
//  | WS/WSC  | RAM                | 0x000000      | 64 KB          | none   |
//  | WS/WSC  | Cartridge SRAM     | 0x010000      | up to 512 KB   | none   |
//  | GB/GBC  | VRAM (bank 0)      | 0x8000        | 8 KB           | none   |
//  | GB/GBC  | Cart RAM (bank 0)  | 0xA000        | up to 8 KB     | none   |
//  | GB/GBC  | WRAM (banks 0-1)   | 0xC000        | 8 KB           | none   |
//  | GB/GBC  | HRAM               | 0xFF80        | 127 B          | none   |
//  | GBC     | WRAM (banks 2-7)   | 0x10000       | 24 KB          | none   |
//  | GB/GBC  | Cart RAM (1-15)    | 0x16000       | up to 120 KB   | none   |
//  | GBA     | IWRAM              | 0x000000      | 32 KB          | none   |
//  | GBA     | EWRAM              | 0x008000      | 256 KB         | none   |
//  | GBA     | Save RAM           | 0x048000      | 64 KB          | none   |
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

/// Size of one Game Boy WRAM / cartridge-RAM / VRAM bank window.
private let gbBankSize = 0x2000

extension MednafenGameCore: CoreRetroAchievements, RcheevosRegionProviding {

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
            var regions = [RcheevosRegion(rcAddress: 0x0000,
                                          base: UnsafeMutableRawPointer(ptr),
                                          size: UInt32(mdfn_nes_ram_size()))]
            // FDS RAM, $6000-$DFFF (consoleinfo.c famicom_disk_system). The
            // pointer is NULL for cartridge games, so this only adds for FDS.
            regions.appendRegion(rcAddress: 0x6000, mdfn_nes_fdsram_ptr(),
                                 size: mdfn_nes_fdsram_size(), window: 0x8000)
            return regions

        case .SNES:
            // Flat rcheevos SNES System RAM is 0x000000 (consoleinfo.c col 1);
            // 0x7E0000 is the real Bus-A bank (col 3) rc_client does not use.
            if MednafenGameCoreOptions.mednafen_snesFast {
                guard let ptr = mdfn_snes_faust_wram_ptr() else { return [] }
                return [RcheevosRegion(rcAddress: 0x000000,
                                       base: UnsafeMutableRawPointer(ptr),
                                       size: UInt32(mdfn_snes_faust_wram_size()))]
            } else {
                guard let ptr = mdfn_snes_wram_ptr() else { return [] }
                return [RcheevosRegion(rcAddress: 0x000000,
                                       base: UnsafeMutableRawPointer(ptr),
                                       size: UInt32(mdfn_snes_wram_size()))]
            }

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
                               byteSwapMode: .word16)
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

        case .Lynx:
            // consoleinfo.c atari_lynx: flat == bus for $0000-$FFFF.
            var regions: [RcheevosRegion] = []
            regions.appendRegion(rcAddress: 0x0000, mdfn_lynx_ram_ptr(),
                                 size: mdfn_lynx_ram_size(), window: 0x10000)
            return regions

        case .NGP, .NGPC:
            // consoleinfo.c neo_geo_pocket: flat 0x0000-0x3FFF = bus $4000-$7FFF.
            var regions: [RcheevosRegion] = []
            regions.appendRegion(rcAddress: 0x0000, mdfn_ngp_ram_ptr(),
                                 size: mdfn_ngp_ram_size(), window: 0x4000)
            return regions

        case .PCFX:
            return pcfxRegions()

        case .VirtualBoy:
            // consoleinfo.c virtualboy: System RAM 0x000000 (bus 0x05000000),
            // Cartridge RAM 0x010000 (bus 0x06000000).
            guard mdfn_vb_wram_ptr() != nil else { return [] }
            var regions: [RcheevosRegion] = []
            regions.appendRegion(rcAddress: 0x000000, mdfn_vb_wram_ptr(),
                                 size: mdfn_vb_wram_size(), window: 0x10000)
            regions.appendRegion(rcAddress: 0x010000, mdfn_vb_gpram_ptr(),
                                 size: mdfn_vb_gpram_size(), window: 0x10000)
            return regions

        case .WonderSwan, .WonderSwanColor:
            // consoleinfo.c wonderswan: System RAM 0x000000-0x00FFFF,
            // Cartridge RAM 0x010000-0x08FFFF (contiguous, like beetle_wswan).
            var regions: [RcheevosRegion] = []
            regions.appendRegion(rcAddress: 0x000000, mdfn_wswan_ram_ptr(),
                                 size: mdfn_wswan_ram_size(), window: 0x10000)
            regions.appendRegion(rcAddress: 0x010000, mdfn_wswan_sram_ptr(),
                                 size: mdfn_wswan_sram_size(), window: 0x80000)
            return regions

        case .GB, .GBC:
            return gameBoyRegions()

        case .GBA:
            // consoleinfo.c gameboy_advance: IWRAM 0x000000 (bus 0x03000000),
            // EWRAM 0x008000 (bus 0x02000000), Save RAM 0x048000 (bus 0x0E000000).
            guard mdfn_gba_iwram_ptr() != nil, mdfn_gba_ewram_ptr() != nil else { return [] }
            var regions: [RcheevosRegion] = []
            regions.appendRegion(rcAddress: 0x000000, mdfn_gba_iwram_ptr(),
                                 size: mdfn_gba_iwram_size(), window: 0x8000)
            regions.appendRegion(rcAddress: 0x008000, mdfn_gba_ewram_ptr(),
                                 size: mdfn_gba_ewram_size(), window: 0x40000)
            regions.appendRegion(rcAddress: 0x048000, mdfn_gba_saveram_ptr(),
                                 size: mdfn_gba_saveram_size(), window: 0x10000)
            return regions

        default:
            return []
        }
    }

    /// consoleinfo.c pcfx: System RAM 0x000000 (bus 0x00000000), Internal
    /// Backup Memory 0x200000 (bus 0xE0000000), External Backup Memory
    /// 0x208000 (bus 0xE8000000). Mednafen's external backup array is 128 KB;
    /// rcheevos only maps its first 32 KB.
    private func pcfxRegions() -> [RcheevosRegion] {
        guard mdfn_pcfx_ram_ptr() != nil else { return [] }
        var regions: [RcheevosRegion] = []
        regions.appendRegion(rcAddress: 0x000000, mdfn_pcfx_ram_ptr(),
                             size: mdfn_pcfx_ram_size(), window: 0x200000)
        regions.appendRegion(rcAddress: 0x200000, mdfn_pcfx_backupram_ptr(),
                             size: mdfn_pcfx_backupram_size(), window: 0x8000)
        regions.appendRegion(rcAddress: 0x208000, mdfn_pcfx_exbackupram_ptr(),
                             size: mdfn_pcfx_exbackupram_size(), window: 0x8000)
        return regions
    }

    /// consoleinfo.c gameboy / gameboy_color. $0000-$FFFF is flat == bus; the
    /// extra banks live past $FFFF: GBC WRAM banks 2-7 at 0x10000-0x15FFF and
    /// cartridge RAM banks 1-15 at 0x16000-0x33FFF. Mednafen keeps WRAM and
    /// cartridge RAM as contiguous arrays (bank N at N * 0x2000 / N * 0x1000),
    /// so fixed slices of them line up with those flat windows.
    private func gameBoyRegions() -> [RcheevosRegion] {
        guard let wram = mdfn_gb_wram_ptr() else { return [] }
        let wramSize = mdfn_gb_wram_size()
        let cartRAM = mdfn_gb_cartram_ptr()
        let cartRAMSize = mdfn_gb_cartram_size()

        var regions: [RcheevosRegion] = []
        regions.appendRegion(rcAddress: 0x8000, mdfn_gb_vram_ptr(),
                             size: mdfn_gb_vram_size(), window: gbBankSize)
        regions.appendRegion(rcAddress: 0xA000, cartRAM,
                             size: cartRAMSize, window: gbBankSize)
        regions.appendRegion(rcAddress: 0xC000, wram,
                             size: wramSize, window: gbBankSize)
        // HRAM $FF80-$FFFE; $FFFF is the interrupt-enable register.
        regions.appendRegion(rcAddress: 0xFF80, mdfn_gb_hram_ptr(),
                             size: mdfn_gb_hram_size(), window: 0x7F)
        if wramSize > gbBankSize {
            regions.appendRegion(rcAddress: 0x10000, wram + gbBankSize,
                                 size: wramSize - gbBankSize, window: 0x6000)
        }
        if let cartRAM, cartRAMSize > gbBankSize {
            regions.appendRegion(rcAddress: 0x16000, cartRAM + gbBankSize,
                                 size: cartRAMSize - gbBankSize, window: 0x1E000)
        }
        return regions
    }
}

private extension Array where Element == RcheevosRegion {
    /// Appends a region when the accessor returned memory, clamping its size
    /// to the rcheevos window so it never overlaps the next flat region.
    mutating func appendRegion(rcAddress: UInt32,
                               _ ptr: UnsafeMutablePointer<UInt8>?,
                               size: Int,
                               window: Int) {
        guard let ptr, size > 0 else { return }
        append(RcheevosRegion(rcAddress: rcAddress,
                              base: UnsafeMutableRawPointer(ptr),
                              size: UInt32(Swift.min(size, window))))
    }
}
