//
//  PVPicoDrive+RetroAchievements.swift
//  PVPicoDrive
//
//  Conformance of PVPicoDrive (Genesis / Mega Drive / 32X / Sega CD /
//  Master System / Game Gear) to CoreRetroAchievements via the shared
//  PVRcheevosBridge default impl.
//
//  Memory map:
//    `rcAddress` is the FLAT rcheevos address (column 1 of the region tables in
//    rcheevos `src/rcheevos/consoleinfo.c`), never the console bus address.
//    Host buffers are the ones upstream libretro/picodrive exposes to RetroArch
//    (set_memory_maps / retro_get_memory_data). PicoDrive stores 16-bit-bus RAM
//    as host-order words (MEM_BE2), RetroArch passes those buffers to rcheevos
//    unswapped, and RA sets are authored against that, so every region is `.off`.
//

import Foundation
import PVCoreBridge
import PVPicoDriveBridge
import PVRcheevos
import PVRcheevosBridge
import PVSystems

/// Flat rcheevos addresses and spans from consoleinfo.c.
private enum PicoDriveRcheevosMap {
    /// `_rc_memory_regions_megadrive` / `_megadrive_32x` / `_segacd`: 68K RAM at $000000-$00FFFF.
    static let main68KRAM: UInt32 = 0x000000
    static let main68KRAMSize: UInt32 = 0x10000

    /// `_rc_memory_regions_megadrive`: Cartridge RAM at $010000-$01FFFF.
    static let megaDriveCartRAM: UInt32 = 0x010000
    static let megaDriveCartRAMSize: UInt32 = 0x10000

    /// `_rc_memory_regions_megadrive_32x`: 32X RAM at $010000-$04FFFF (bus $06000000).
    static let sega32XSDRAM: UInt32 = 0x010000
    static let sega32XSDRAMSize: UInt32 = 0x40000
    /// `_rc_memory_regions_megadrive_32x`: Cartridge RAM at $050000-$05FFFF.
    static let sega32XCartRAM: UInt32 = 0x050000
    static let sega32XCartRAMSize: UInt32 = 0x10000

    /// `_rc_memory_regions_segacd`: CD PRG RAM at $010000-$08FFFF (virtual bus $80020000).
    static let segaCDProgramRAM: UInt32 = 0x010000
    static let segaCDProgramRAMSize: UInt32 = 0x80000
    /// `_rc_memory_regions_segacd`: CD WORD RAM at $090000-$0AFFFF (bus $200000).
    /// Only 128 KiB of the 256 KiB 2M buffer is mapped, as in RetroArch.
    static let segaCDWordRAM: UInt32 = 0x090000
    static let segaCDWordRAMSize: UInt32 = 0x20000

    /// `_rc_memory_regions_master_system` / `_game_gear`: System RAM at $0000-$1FFF.
    static let z80RAM: UInt32 = 0x000000
    static let z80RAMSize: UInt32 = 0x2000
    /// `_rc_memory_regions_master_system` / `_game_gear`: Cartridge RAM at $2000-$9FFF.
    static let eightBitCartRAM: UInt32 = 0x002000
    static let eightBitCartRAMSize: UInt32 = 0x8000
}

extension PVPicoDrive: CoreRetroAchievements, RcheevosRegionProviding {

    /// Ticks achievements after every frame the bridge's emulation loop runs
    /// (that loop never calls this class's `executeFrame()`). Not gated on
    /// `achievementsActive`: the shared lazy region retry in `tickAchievements()`
    /// must run while no session exists yet, e.g. a 32X game reports no regions
    /// until the 68K enables the adapter. Called through the existential so the
    /// PVRcheevosBridge implementation is used.
    func installAchievementHooks() {
        _bridge.frameCompletedHandler = { [weak self] in
            guard let core: any CoreRetroAchievements = self else { return }
            core.tickAchievements()
        }
    }

    public func rcheevosRegions() -> [RcheevosRegion] {
        typealias Map = PicoDriveRcheevosMap
        switch _bridge.activeHardware {
        case .megaDrive:
            // A 32X cart reports plain MD until the 68K enables the adapter, which
            // allocates SDRAM. Returning [] lets the bridge's per-frame retry build the
            // full 32X map instead of freezing a 68K-only one.
            if SystemIdentifier(rawValue: systemIdentifier ?? "") == .Sega32X { return [] }
            return regions([
                (.main68KRAM, Map.main68KRAM, Map.main68KRAMSize),
                (.cartridgeRAM, Map.megaDriveCartRAM, Map.megaDriveCartRAMSize)
            ])
        case .sega32X:
            return regions([
                (.main68KRAM, Map.main68KRAM, Map.main68KRAMSize),
                (.sega32XSDRAM, Map.sega32XSDRAM, Map.sega32XSDRAMSize),
                (.cartridgeRAM, Map.sega32XCartRAM, Map.sega32XCartRAMSize)
            ])
        case .segaCD:
            return regions([
                (.main68KRAM, Map.main68KRAM, Map.main68KRAMSize),
                (.segaCDProgramRAM, Map.segaCDProgramRAM, Map.segaCDProgramRAMSize),
                (.segaCDWordRAM, Map.segaCDWordRAM, Map.segaCDWordRAMSize)
            ])
        case .masterSystem, .gameGear:
            return regions([
                (.z80WorkRAM, Map.z80RAM, Map.z80RAMSize),
                (.cartridgeRAM, Map.eightBitCartRAM, Map.eightBitCartRAMSize)
            ])
        case .none, .other:
            return []
        @unknown default:
            return []
        }
    }

    /// Builds regions for the given (host buffer, flat address, max span) triples,
    /// clamping each to its consoleinfo.c span and skipping absent buffers.
    private func regions(
        _ specs: [(region: PVPicoDriveMemoryRegion, rcAddress: UInt32, maxSize: UInt32)]
    ) -> [RcheevosRegion] {
        specs.compactMap { spec in
            var hostSize: UInt = 0
            guard let base = _bridge.memoryPointer(for: spec.region, size: &hostSize), hostSize > 0 else {
                return nil
            }
            return RcheevosRegion(
                rcAddress: spec.rcAddress,
                base: base,
                size: min(UInt32(clamping: hostSize), spec.maxSize))
        }
    }
}
