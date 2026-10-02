//
//  PVFCEUEmulatorCore+RetroAchievements.swift
//  PVFCEU
//
//  Conformance of PVFCEUEmulatorCore (NES/Famicom/FDS) to CoreRetroAchievements
//  via the shared PVRcheevosBridge default impl.
//
//  Memory map — rcAddress is the FLAT consoleinfo.c column-1 address
//  (`_rc_memory_regions_nes` / `_rc_memory_regions_famicom_disk_system`):
//    0x0000-0x07FF  System RAM            -> FCEUX `RAM[0x800]`
//    0x0800-0x1FFF  Mirror RAM (3x 2 KiB) -> the same `RAM` block
//    0x2000-0x2003  PPU registers         -> FCEUX `PPU[4]` (fceumm exposes the same 4 bytes)
//    0x6000-0x7FFF  Cartridge RAM (NES)   -> PRG-RAM mapped at $6000 (board WRAM)
//    0x6000-0xDFFF  FDS RAM (FDS)         -> FDSRAM mapped at $6000
//  Every region matters: at load rc_client probes each referenced address
//  with a 1-byte read and permanently disables achievements whose reads come
//  back short, so an unmapped mirror / $6000 address kills that achievement.
//  NES RAM is byte-addressed host memory — no byte swapping.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVRcheevos
import PVRcheevosBridge

extension PVFCEUEmulatorCore: CoreRetroAchievements, RcheevosRegionProviding {

    /// Flat rcheevos addresses from consoleinfo.c.
    private enum RcAddress {
        static let systemRAM: UInt32 = 0x0000
        static let systemRAMMirrors: [UInt32] = [0x0800, 0x1000, 0x1800]
        static let ppuRegisters: UInt32 = 0x2000
        static let cartridgeRAM: UInt32 = 0x6000
    }

    public func rcheevosRegions() -> [RcheevosRegion] {
        guard let ram = _bridge.systemRAMPtr, _bridge.systemRAMSize > 0 else {
            ILOG("[CHEEVOS-DIAG] FCEU rcheevosRegions: systemRAMPtr unavailable")
            return []
        }
        let ramSize = UInt32(_bridge.systemRAMSize)
        var regions = ([RcAddress.systemRAM] + RcAddress.systemRAMMirrors).map {
            RcheevosRegion(rcAddress: $0, base: ram, size: ramSize)
        }
        if let ppu = _bridge.ppuRegistersPtr, _bridge.ppuRegistersSize > 0 {
            regions.append(RcheevosRegion(rcAddress: RcAddress.ppuRegisters,
                                          base: ppu,
                                          size: UInt32(_bridge.ppuRegistersSize)))
        }
        let cartRAMSize = _bridge.cartridgeRAMSize
        if cartRAMSize > 0, let cartRAM = _bridge.cartridgeRAMPtr {
            regions.append(RcheevosRegion(rcAddress: RcAddress.cartridgeRAM,
                                          base: cartRAM,
                                          size: UInt32(cartRAMSize)))
        }
        let summary = regions
            .map { String(format: "0x%04X+0x%X", $0.rcAddress, $0.size) }
            .joined(separator: ", ")
        ILOG("[CHEEVOS-DIAG] FCEU rcheevosRegions [\(summary)]")
        return regions
    }

    /// Drives the per-frame rcheevos tick from the ObjC bridge's frame hook.
    ///
    /// The emulation loop in `PVCoreObjCBridge` calls the bridge's
    /// `executeFrame` directly, so a Swift `executeFrame()` override on this
    /// class never runs. Upcasting to the existential dispatches through the
    /// conformance witness declared here (the PVRcheevosBridge implementation),
    /// not PVCoreBridge's no-op default.
    func installAchievementsFrameTick() {
        _bridge.frameCompletedHandler = { [weak self] in
            guard let self else { return }
            // Not gated on achievementsActive: tickAchievements() also drives the
            // lazy region retry, which runs while no session is loaded yet.
            let achievements: any CoreRetroAchievements = self
            achievements.tickAchievements()
        }
    }
}
