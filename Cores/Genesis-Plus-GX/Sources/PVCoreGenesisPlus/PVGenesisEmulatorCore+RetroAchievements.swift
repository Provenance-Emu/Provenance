//
//  PVGenesisEmulatorCore+RetroAchievements.swift
//  PVCoreGenesisPlus
//
//  Conformance of PVCoreGenesisPlus (Genesis-Plus-GX: Genesis/Mega Drive,
//  Sega CD, Master System, Game Gear, SG-1000) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map: every `rcAddress` below is the FLAT rcheevos address from
//  column 1 of rcheevos src/rcheevos/consoleinfo.c, never the real bus address
//  in column 3. The buffers are the ones upstream GPGX's libretro port gives
//  RetroArch, read without byte swapping: 68K memory keeps GPGX's
//  host-swapped 16-bit words, which is the layout RA sets are written against.
//
//  The layout is picked from the game's system, not from the emulated
//  hardware: a Mega Drive cartridge booted with Sega CD hardware attached
//  still uses the Mega Drive map.
//

import Foundation
import PVCoreBridge
// PVCoreGenesisPlusBridge is a separate Swift target in Package.swift but is
// part of the same framework target in PVGenesis.xcodeproj — the workspace
// build path. Importing only when canImport satisfies both build paths.
#if canImport(PVCoreGenesisPlusBridge)
import PVCoreGenesisPlusBridge
#endif
import PVRcheevos
import PVRcheevosBridge
import PVSystems

/// Flat rcheevos regions (consoleinfo.c column 1) for the systems GPGX runs.
enum GenesisRcheevosMemoryMap {
    /// consoleinfo.c:618-619 — MegaDrive System RAM and Cartridge RAM.
    enum MegaDrive {
        static let systemRAM: (address: UInt32, size: UInt32) = (0x000000, 0x10000)
        static let cartridgeRAM: (address: UInt32, size: UInt32) = (0x010000, 0x10000)
    }

    /// consoleinfo.c:839-841 — Sega CD 68000 RAM, CD PRG RAM, CD WORD RAM.
    enum SegaCD {
        static let systemRAM: (address: UInt32, size: UInt32) = (0x000000, 0x10000)
        static let prgRAM: (address: UInt32, size: UInt32) = (0x010000, 0x80000)
        static let wordRAM: (address: UInt32, size: UInt32) = (0x090000, 0x20000)
    }

    /// consoleinfo.c:604/611 (Master System) and 528/535 (Game Gear) — identical maps.
    enum SMSAndGameGear {
        static let systemRAM: (address: UInt32, size: UInt32) = (0x000000, 0x2000)
        static let cartridgeRAM: (address: UInt32, size: UInt32) = (0x002000, 0x8000)
    }

    /// consoleinfo.c:856-864 — SG-1000 System RAM plus the expansion RAM windows.
    enum SG1000 {
        /// $0000-$3FFF: internal RAM, then the expansion RAM at $2000.
        static let systemRAM: (address: UInt32, size: UInt32) = (0x000000, 0x4000)
        /// $4000-$5FFF: on-board RAM a cartridge maps at $8000 (The Castle, Othello).
        static let cartridgeRAMAt8000: (address: UInt32, size: UInt32) = (0x004000, 0x2000)
        /// Offset of on-board cartridge RAM inside GPGX's Z80 work RAM.
        static let onboardRAMOffset = 0x2000
    }
}

extension PVCoreGenesisPlus: CoreRetroAchievements, RcheevosRegionProviding {

    /// The emulation loop runs inside the ObjC bridge and never calls this
    /// class's `executeFrame()`, so achievements tick from the bridge's
    /// per-frame callback. It is not gated on `achievementsActive`: the shared
    /// session's lazy region retry needs ticks before a session exists.
    func installAchievementHooks() {
        // Called through the existential so the PVRcheevosBridge default is
        // used, not PVCoreBridge's no-op.
        _bridge.frameCompletedHandler = { [weak self] in
            guard let core: any CoreRetroAchievements = self else { return }
            core.tickAchievements()
        }
    }

    public func rcheevosRegions() -> [RcheevosRegion] {
        guard let systemRAM = _bridge.systemRAMPtr else { return [] }
        let systemRAMSize = UInt32(_bridge.systemRAMSize)
        guard systemRAMSize > 0 else { return [] }

        switch SystemIdentifier(rawValue: systemIdentifier ?? "") {
        case .SegaCD:
            typealias Map = GenesisRcheevosMemoryMap.SegaCD
            // All three or nothing: an empty list re-arms the session's lazy retry,
            // a partial one would lose PRG/Word RAM for the whole session.
            guard let prgRAM = _bridge.segaCDPrgRAMPtr,
                  let wordRAM = _bridge.segaCDWordRAMPtr else { return [] }
            return [
                region(Map.systemRAM, base: systemRAM, available: systemRAMSize),
                region(Map.prgRAM, base: prgRAM, available: UInt32(_bridge.segaCDPrgRAMSize)),
                // Word RAM in 2M mode; in 1M mode this holds the last 2M contents.
                region(Map.wordRAM, base: wordRAM, available: UInt32(_bridge.segaCDWordRAMSize))
            ].compactMap { $0 }

        case .MasterSystem, .GameGear:
            typealias Map = GenesisRcheevosMemoryMap.SMSAndGameGear
            return [
                region(Map.systemRAM, base: systemRAM, available: systemRAMSize),
                cartridgeRAMRegion(Map.cartridgeRAM)
            ].compactMap { $0 }

        case .SG1000:
            typealias Map = GenesisRcheevosMemoryMap.SG1000
            var regions = [region(Map.systemRAM, base: systemRAM, available: systemRAMSize)]
            // Upstream GPGX exposes on-board RAM at flat $2000 (inside system RAM);
            // consoleinfo puts RAM mapped at $8000 at flat $4000, so mirror it there too.
            let onboardRAMSize = Int(systemRAMSize) - Map.onboardRAMOffset
            if onboardRAMSize > 0 {
                regions.append(region(Map.cartridgeRAMAt8000,
                                      base: systemRAM.advanced(by: Map.onboardRAMOffset),
                                      available: UInt32(onboardRAMSize)))
            }
            return regions.compactMap { $0 }

        case .Genesis:
            typealias Map = GenesisRcheevosMemoryMap.MegaDrive
            return [
                region(Map.systemRAM, base: systemRAM, available: systemRAMSize),
                cartridgeRAMRegion(Map.cartridgeRAM)
            ].compactMap { $0 }

        default:
            return [RcheevosRegion(rcAddress: 0x000000, base: systemRAM, size: systemRAMSize)]
        }
    }

    /// A region clamped to both its consoleinfo size and what the core exposes.
    private func region(_ map: (address: UInt32, size: UInt32),
                        base: UnsafeMutableRawPointer,
                        available: UInt32) -> RcheevosRegion? {
        let size = min(map.size, available)
        guard size > 0 else { return nil }
        return RcheevosRegion(rcAddress: map.address, base: base, size: size)
    }

    private func cartridgeRAMRegion(_ map: (address: UInt32, size: UInt32)) -> RcheevosRegion? {
        guard let cartridgeRAM = _bridge.cartridgeRAMPtr else { return nil }
        return region(map, base: cartridgeRAM, available: UInt32(_bridge.cartridgeRAMSize))
    }
}
