//
//  PVmGBACore+RetroAchievements.swift
//  PVmGBACore
//
//  Conformance of PVmGBACore (GBA) to CoreRetroAchievements via the shared
//  PVRcheevosBridge default implementation, which drives login, game load,
//  the per-frame tick, and the hardcore flag.
//
//  Memory map (GBA, FLAT rcheevos addresses from consoleinfo.c column 1 — NOT
//  the GBA bus addresses in column 3, which rc_client does not use):
//    IWRAM    —  32 KiB at flat 0x000000  (bus 0x03000000)
//    EWRAM    — 256 KiB at flat 0x008000  (bus 0x02000000)
//    Save RAM —  64 KiB at flat 0x048000  (bus 0x0E000000)
//
//  The emulation loop runs inside the ObjC bridge, which never calls
//  `PVmGBACore.executeFrame()`, so the bridge reports each finished frame
//  through `frameCompletedHandler` instead.
//

import Foundation
import PVCoreBridge
import PVmGBABridge
import PVRcheevos
import PVRcheevosBridge

/// GBA regions from rcheevos `src/rcheevos/consoleinfo.c`
/// (`_rc_memory_regions_gameboy_advance`).
private enum GBARcheevosMap {
    static let iwramAddress: UInt32 = 0x000000
    static let iwramSize = 0x8000
    static let ewramAddress: UInt32 = 0x008000
    static let ewramSize = 0x40000
    static let saveRAMAddress: UInt32 = 0x048000
    static let saveRAMSize = 0x10000
}

extension PVmGBACore: CoreRetroAchievements, RcheevosRegionProviding {

    /// Regions are empty until the bridge has loaded a ROM; the shared session
    /// retries from `tickAchievements()` until they appear.
    public func rcheevosRegions() -> [RcheevosRegion] {
        var regions: [RcheevosRegion] = []
        regions.reserveCapacity(3)

        var iwramSize: UInt = 0
        if let iwram = _bridge.iwramPointer(&iwramSize) {
            regions.append(RcheevosRegion(
                rcAddress: GBARcheevosMap.iwramAddress,
                base: iwram,
                size: UInt32(min(Int(iwramSize), GBARcheevosMap.iwramSize))))
        }

        var ewramSize: UInt = 0
        if let ewram = _bridge.ewramPointer(&ewramSize) {
            regions.append(RcheevosRegion(
                rcAddress: GBARcheevosMap.ewramAddress,
                base: ewram,
                size: UInt32(min(Int(ewramSize), GBARcheevosMap.ewramSize))))
        }

        var saveSize: UInt = 0
        if let save = _bridge.saveRAMMirrorPointer(&saveSize) {
            regions.append(RcheevosRegion(
                rcAddress: GBARcheevosMap.saveRAMAddress,
                base: save,
                size: UInt32(min(Int(saveSize), GBARcheevosMap.saveRAMSize))))
        }

        return regions
    }

    /// Connects the bridge's per-frame and save-state hooks to the shared session.
    func installAchievementHooks() {
        // Not gated on `achievementsActive`: the shared lazy region retry in
        // `tickAchievements()` must run while no session exists yet. Called
        // through the existential so the PVRcheevosBridge default is used, not
        // PVCoreBridge's no-op (the same reason applies to the flags below).
        _bridge.frameCompletedHandler = { [weak self] in
            guard let core: any CoreRetroAchievements = self else { return }
            core.tickAchievements()
        }
        // Defence in depth: the app already refuses hardcore loads in the UI,
        // and this keeps the core refusing them too.
        _bridge.saveStateLoadBlockedHandler = { [weak self] in
            guard let core: any CoreRetroAchievements = self else { return false }
            return core.hardcoreMode && core.achievementsActive
        }
    }
}
