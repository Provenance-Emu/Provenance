//
//  PVPicoDrive+RetroAchievements.swift
//  PVPicoDrive
//
//  Conformance of PVPicoDrive (Genesis / Mega Drive / 32X / Sega CD) to
//  CoreRetroAchievements via the shared PVRcheevosBridge default impl.
//
//  Memory map:
//    libretro RETRO_MEMORY_SYSTEM_RAM is exposed at rcheevos address 0x000000.
//    PicoDrive returns 64 KiB Genesis 68K work RAM by default. Sega CD and 32X
//    expose additional regions via libretro RETRO_MEMORY_VIDEO_RAM /
//    RETRO_MEMORY_RTC slots, but rcheevos at present only consumes SYSTEM_RAM
//    on these platforms.
//

import Foundation
import PVCoreBridge
import PVPicoDriveBridge
import PVRcheevos
import PVRcheevosBridge

extension PVPicoDrive: CoreRetroAchievements {

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
