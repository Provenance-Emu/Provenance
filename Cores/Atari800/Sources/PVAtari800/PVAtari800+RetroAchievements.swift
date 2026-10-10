//
//  PVAtari800+RetroAchievements.swift
//  PVAtari800
//
//  Conformance of PVAtari800 (Atari 800 / 5200) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map:
//    The 6502 64 KiB address space (`MEMORY_mem`) is exposed at rcheevos
//    address 0x0000. Atari 5200 achievements use addresses inside the first
//    16 KiB (RAM at $0000–$3FFF); Atari 800 achievements span the full bus.
//

import Foundation
import PVCoreBridge
import PVAtari800Bridge
import PVRcheevos
import PVRcheevosBridge

extension PVAtari800: CoreRetroAchievements, RcheevosRegionProviding {

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
