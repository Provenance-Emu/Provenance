//
//  PVGenesisEmulatorCore+RetroAchievements.swift
//  PVCoreGenesisPlus
//
//  Conformance of PVCoreGenesisPlus (Genesis-Plus-GX: Genesis/Mega Drive,
//  Master System, Game Gear, SG-1000) to CoreRetroAchievements via the shared
//  PVRcheevosBridge default impl.
//
//  Memory map:
//    libretro RETRO_MEMORY_SYSTEM_RAM is exposed at rcheevos address 0x000000.
//    Genesis-Plus-GX returns 64 KiB for Mega Drive / 32X bus M68K work RAM,
//    8 KiB for Master System / Game Gear, 1 KiB for SG-1000.
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

extension PVCoreGenesisPlus: CoreRetroAchievements {

    public func rcheevosRegions() -> [RcheevosRegion] {
        guard let ptr = _bridge.systemRAMPtr else { return [] }
        let byteCount = UInt32(_bridge.systemRAMSize)
        guard byteCount > 0 else { return [] }
        return [
            RcheevosRegion(
                rcAddress: 0x000000,
                base: ptr,
                size: byteCount)
        ]
    }
}
