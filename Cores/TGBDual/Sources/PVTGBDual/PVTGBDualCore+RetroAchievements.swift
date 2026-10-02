//
//  PVTGBDualCore+RetroAchievements.swift
//  PVTGBDual
//
//  Conformance of PVTGBDualCore (Game Boy / Game Boy Color) to
//  CoreRetroAchievements via the shared PVRcheevosBridge default impl.
//
//  Memory map — flat rcheevos addresses from rcheevos consoleinfo.c
//  (`_rc_memory_regions_gameboy` / `_rc_memory_regions_gameboy_color`):
//
//    0x0000-0x7FFF  ROM bank 0 + bank 1          (static storage, read-only)
//    0x8000-0x9FFF  VRAM bank 0                  (static, never follows VBK)
//    0xA000-0xBFFF  cart RAM bank 0              (static)
//    0xC000-0xDFFF  WRAM bank 0 + bank 1         (static, never follows SVBK)
//    0xE000-0xFDFF  echo of 0xC000-0xDDFF
//    0xFE00-0xFE9F  OAM
//    0xFF00-0xFF7F  I/O registers                (per-frame mirror, see bridge)
//    0xFF80-0xFFFE  HRAM
//    0xFFFF         IE
//    0x10000-0x15FFF WRAM banks 2-7              (GBC only)
//    0x16000-0x33FFF cart RAM banks 1-15         (when the cart has them)
//
//  Banked windows are STATIC to match RetroArch: gambatte-libretro (the core
//  RA sets are developed against) maps 0xD000 to WRAM bank 1 storage and
//  0x10000 to banks 2-7, with pointers captured once at load. tgbdual's
//  `cpu::ram` holds bank N at `ram + N * 0x1000` (SVBK writes set
//  `ram_bank = ram + 0x1000 * bank`), so the same static layout applies.
//  tgbdual-libretro publishes no memory map, which is why RetroArch cannot
//  serve most of these ranges for this core; the layout here follows
//  consoleinfo.c and the gambatte map instead.
//

import Foundation
import PVCoreBridge
import PVRcheevos
import PVRcheevosBridge
import PVTGBDualBridge

/// Flat rcheevos GB/GBC addresses and window sizes (consoleinfo.c).
private enum GBFlatMap {
    static let rom: UInt32 = 0x0000
    static let romWindowSize: UInt32 = 0x8000
    static let vram: UInt32 = 0x8000
    static let vramWindowSize: UInt32 = 0x2000
    static let cartRAM: UInt32 = 0xA000
    static let cartRAMBankSize: UInt32 = 0x2000
    static let wram: UInt32 = 0xC000
    static let wramWindowSize: UInt32 = 0x2000
    static let echo: UInt32 = 0xE000
    static let echoSize: UInt32 = 0x1E00
    static let oam: UInt32 = 0xFE00
    static let oamSize: UInt32 = 0xA0
    static let io: UInt32 = 0xFF00
    static let ioSize: UInt32 = 0x80
    static let hram: UInt32 = 0xFF80
    static let hramSize: UInt32 = 0x7F
    static let interruptEnable: UInt32 = 0xFFFF
    static let cgbWRAMBanks2to7: UInt32 = 0x10000
    static let cgbWRAMBanks2to7Size: UInt32 = 0x6000
    static let cartRAMBanks1to15: UInt32 = 0x16000
    static let cartRAMBanks1to15MaxSize: UInt32 = 0x1E000
}

extension PVTGBDualCore: CoreRetroAchievements, RcheevosRegionProviding {

    public func rcheevosRegions() -> [RcheevosRegion] {
        // Every accessor reports nil / 0 until a game is loaded.
        guard let wram = _bridge.wramBasePtr else { return [] }
        let wramSize = UInt32(_bridge.wramSize)
        guard wramSize >= GBFlatMap.wramWindowSize else { return [] }

        var regions: [RcheevosRegion] = []

        if let rom = _bridge.romBasePtr {
            let size = min(UInt32(_bridge.romSize), GBFlatMap.romWindowSize)
            if size > 0 {
                regions.append(RcheevosRegion(rcAddress: GBFlatMap.rom, base: rom, size: size))
            }
        }

        if let vram = _bridge.vramBasePtr, UInt32(_bridge.vramSize) >= GBFlatMap.vramWindowSize {
            regions.append(RcheevosRegion(rcAddress: GBFlatMap.vram, base: vram, size: GBFlatMap.vramWindowSize))
        }

        let cartRAMSize = UInt32(_bridge.cartRamSize)
        if let cartRAM = _bridge.cartRamBasePtr, cartRAMSize > 0 {
            regions.append(RcheevosRegion(
                rcAddress: GBFlatMap.cartRAM,
                base: cartRAM,
                size: min(cartRAMSize, GBFlatMap.cartRAMBankSize)))
            if cartRAMSize > GBFlatMap.cartRAMBankSize {
                regions.append(RcheevosRegion(
                    rcAddress: GBFlatMap.cartRAMBanks1to15,
                    base: cartRAM + Int(GBFlatMap.cartRAMBankSize),
                    size: min(cartRAMSize - GBFlatMap.cartRAMBankSize, GBFlatMap.cartRAMBanks1to15MaxSize)))
            }
        }

        regions.append(RcheevosRegion(rcAddress: GBFlatMap.wram, base: wram, size: GBFlatMap.wramWindowSize))
        regions.append(RcheevosRegion(rcAddress: GBFlatMap.echo, base: wram, size: GBFlatMap.echoSize))

        if let oam = _bridge.oamPtr {
            regions.append(RcheevosRegion(rcAddress: GBFlatMap.oam, base: oam, size: GBFlatMap.oamSize))
        }
        regions.append(RcheevosRegion(rcAddress: GBFlatMap.io, base: _bridge.ioMirrorPtr, size: GBFlatMap.ioSize))
        if let hram = _bridge.hramPtr {
            regions.append(RcheevosRegion(rcAddress: GBFlatMap.hram, base: hram, size: GBFlatMap.hramSize))
        }
        if let interruptEnable = _bridge.interruptEnablePtr {
            regions.append(RcheevosRegion(rcAddress: GBFlatMap.interruptEnable, base: interruptEnable, size: 1))
        }

        if _bridge.isGameBoyColorMode,
           wramSize >= GBFlatMap.wramWindowSize + GBFlatMap.cgbWRAMBanks2to7Size {
            regions.append(RcheevosRegion(
                rcAddress: GBFlatMap.cgbWRAMBanks2to7,
                base: wram + Int(GBFlatMap.wramWindowSize),
                size: GBFlatMap.cgbWRAMBanks2to7Size))
        }

        return regions
    }

    /// Ticks the shared session after every emulated frame. The emulation loop
    /// runs in the bridge, which never calls this core's `executeFrame()`.
    func installAchievementHooks() {
        // Not gated on `achievementsActive`: the shared lazy region retry in
        // `tickAchievements()` must run while no session exists yet. Called
        // through the existential so the PVRcheevosBridge default is used, not
        // PVCoreBridge's no-op.
        _bridge.frameCompletedHandler = { [weak self] in
            guard let core: any CoreRetroAchievements = self else { return }
            core.tickAchievements()
        }
    }
}
