//
//  PVSNES9xEmulatorCore+RetroAchievements.swift
//  PVSNES
//
//  Conformance of PVSNES9xEmulatorCore (snes9x) to CoreRetroAchievements via
//  the shared PVRcheevosBridge default impl.
//
//  Memory map — rcheevos consoleinfo.c, RC_CONSOLE_SUPER_NINTENDO. rcAddress is
//  the FLAT column-1 address; the real bus address (column 3) is NOT what
//  rc_client reads with:
//    0x000000-0x01FFFF  System RAM     ← Memory.RAM (128 KiB WRAM; bus 0x7E0000)
//    0x020000-0x09FFFF  Cartridge RAM  ← Memory.SRAM (battery SRAM, SA-1 BW-RAM,
//                                        SuperFX GSU RAM; sized from the header)
//    0x0A0000-0x0A07FF  I-RAM (SA-1)   ← Memory.FillRAM + 0x3000 (SA-1 carts only)
//  All three are plain byte arrays in SNES order, so no byte swapping.
//  The per-frame tick is driven by the bridge's `frameCompletedHandler`
//  (see PVSNESEmulatorCore.swift).
//

import Foundation
import PVCoreBridge
import PVLogging
import PVRcheevos
import PVRcheevosBridge

/// rcheevos flat addresses for the SNES regions (consoleinfo.c column 1).
private enum SNESRcheevosAddress {
    static let systemRAM: UInt32 = 0x000000
    static let cartridgeRAM: UInt32 = 0x020000
    static let sa1IRAM: UInt32 = 0x0A0000
}

extension PVSNES9xEmulatorCore: CoreRetroAchievements, RcheevosRegionProviding {

    public func rcheevosRegions() -> [RcheevosRegion] {
        guard let snesBridge = bridge as? PVSNESEmulatorCoreBridge else { return [] }
        // Snapshot each pointer/size pair once: the bridge clears them on stop.
        // Both are nil/0 until a ROM has loaded, which arms the lazy retry in
        // tickAchievements() instead of handing rcheevos a pre-load buffer.
        guard let ram = snesBridge.systemRAMPtr, snesBridge.systemRAMSize > 0 else {
            ILOG("[CHEEVOS-DIAG] SNES9x rcheevosRegions: no ROM loaded yet (systemRAMPtr nil)")
            return []
        }
        var regions = [
            RcheevosRegion(
                rcAddress: SNESRcheevosAddress.systemRAM,
                base: ram,
                size: UInt32(snesBridge.systemRAMSize))
        ]
        // Cartridge RAM — needed for save-/progress-based achievements, and for
        // SA-1/SuperFX games whose working state lives in BW-RAM / GSU RAM.
        let cartSize = snesBridge.cartridgeSRAMSize
        if let cart = snesBridge.cartridgeSRAMPtr, cartSize > 0 {
            regions.append(RcheevosRegion(
                rcAddress: SNESRcheevosAddress.cartridgeRAM,
                base: cart,
                size: UInt32(cartSize)))
        }
        let iramSize = snesBridge.sa1IRAMSize
        if let iram = snesBridge.sa1IRAMPtr, iramSize > 0 {
            regions.append(RcheevosRegion(
                rcAddress: SNESRcheevosAddress.sa1IRAM,
                base: iram,
                size: UInt32(iramSize)))
        }
        ILOG("[CHEEVOS-DIAG] SNES9x rcheevosRegions wram=\(snesBridge.systemRAMSize) cartRAM=\(cartSize) sa1IRAM=\(iramSize)")
        return regions
    }
}
