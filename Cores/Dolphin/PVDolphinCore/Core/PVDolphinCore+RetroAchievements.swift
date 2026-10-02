//
//  PVDolphinCore+RetroAchievements.swift
//  PVDolphin
//
//  Conformance of PVDolphinCore (GameCube/Wii) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map — rcheevos FLAT addresses (rcheevos/src/rcheevos/consoleinfo.c,
//  `_rc_memory_regions_gamecube` / `_rc_memory_regions_wii`), not CPU bus
//  addresses. They equal the PowerPC physical addresses, which is what
//  Dolphin's own AchievementManager::MemoryPeeker reads.
//    GameCube — MEM1 at 0x00000000–0x017FFFFF (bus 0x80000000).
//    Wii — MEM1 as above, plus MEM2 at 0x10000000–0x13FFFFFF (bus 0x90000000).
//  Bytes are served raw (big-endian guest order), so no byte swapping.
//

import Foundation
import PVCoreBridge
import PVRcheevos
import PVRcheevosBridge

/// rcheevos flat-address layout for GameCube/Wii (consoleinfo.c).
private enum DolphinRcheevosMemoryMap {
    static let mem1Address: UInt32 = 0x0000_0000
    static let mem1MaxSize: UInt = 0x0180_0000 // 24 MiB
    static let mem2Address: UInt32 = 0x1000_0000
    static let mem2MaxSize: UInt = 0x0400_0000 // 64 MiB
}

extension PVDolphinCore: CoreRetroAchievements, RcheevosRegionProviding {

    public func rcheevosRegions() -> [RcheevosRegion] {
        var regions: [RcheevosRegion] = []

        let mem1Size = min(_bridge.systemRAMSize, DolphinRcheevosMemoryMap.mem1MaxSize)
        if let mem1 = _bridge.systemRAMPtr, mem1Size > 0 {
            regions.append(
                RcheevosRegion(
                    rcAddress: DolphinRcheevosMemoryMap.mem1Address,
                    base: mem1,
                    size: UInt32(mem1Size))
            )
        }

        // Wii only — the bridge returns nil / 0 on GameCube titles.
        let mem2Size = min(_bridge.systemEXRAMSize, DolphinRcheevosMemoryMap.mem2MaxSize)
        if let mem2 = _bridge.systemEXRAMPtr, mem2Size > 0 {
            regions.append(
                RcheevosRegion(
                    rcAddress: DolphinRcheevosMemoryMap.mem2Address,
                    base: mem2,
                    size: UInt32(mem2Size))
            )
        }

        return regions
    }

    /// Ticks the shared session at the end of every emulated field. Dolphin runs
    /// its own loop, so this core's `executeFrame()` is never called.
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
