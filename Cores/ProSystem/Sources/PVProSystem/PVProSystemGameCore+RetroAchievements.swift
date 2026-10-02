//
//  PVProSystemGameCore+RetroAchievements.swift
//  PVProSystem
//
//  Conformance of PVProSystemCore (Atari 7800) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map:
//    The Atari 7800 6502 64 KiB address space (`memory_ram`) is exposed at
//    rcheevos address 0x0000. Achievements use addresses inside RAM regions
//    of this map per RetroAchievements' Atari 7800 spec.
//

import Foundation
import PVCoreBridge
import PVProSystemBridge
import PVRcheevos
import PVRcheevosBridge

extension PVProSystemCore: CoreRetroAchievements, RcheevosRegionProviding {

    public func rcheevosRegions() -> [RcheevosRegion] {
        guard let ptr = _bridge.systemRAMPtr else { return [] }
        let byteCount = UInt32(_bridge.systemRAMSize)
        guard byteCount > 0 else { return [] }
        return [
            RcheevosRegion(
                rcAddress: 0x0000,
                base: ptr,
                size: byteCount)
        ]
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
