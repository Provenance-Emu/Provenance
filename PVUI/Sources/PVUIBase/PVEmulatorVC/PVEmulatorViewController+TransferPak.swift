//
//  PVEmulatorViewController+TransferPak.swift
//  PVUIBase
//
//  Applies persisted Transfer Pak slot configuration when an N64 game starts:
//
//    • applyPersistedTransferPakIfNeeded() — called before core.startEmulation()
//      Reads TransferPakStore for the current game and calls setTransferPakROM
//      on any core that conforms to TransferPakSupport.
//
//  This ensures the "context menu → configure → launch" flow actually mounts
//  the selected GB/GBC ROMs at startup, not just during the pause-menu session.
//

import PVCoreBridge
import PVLogging

extension PVEmulatorViewController {
    /// Reads `TransferPakStore` for the current game and applies any persisted
    /// slot selections to the core if it conforms to `TransferPakSupport`.
    ///
    /// Call this immediately before `core.startEmulation()`.
    func applyPersistedTransferPakIfNeeded() {
        guard let transferCore = core as? TransferPakSupport else { return }
        guard let md5 = game?.md5Hash, !md5.isEmpty else { return }

        let roms = TransferPakStore.allROMs(forGameMD5: md5, slotCount: transferCore.transferPakSlotCount)
        guard !roms.isEmpty else { return }

        for (port, rom) in roms {
            transferCore.setTransferPakROM(rom, forPort: port)
            DLOG("TransferPak: applied persisted slot \(port) → \(rom.romPath.lastPathComponent)")
        }
    }
}
