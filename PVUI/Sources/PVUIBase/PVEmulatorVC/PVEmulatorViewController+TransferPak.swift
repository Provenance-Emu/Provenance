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
import PVFeatureFlags
import PVLogging

extension PVEmulatorViewController {
    /// Reads `TransferPakStore` for the current game and applies any persisted
    /// slot selections to the core if it conforms to `TransferPakSupport`.
    ///
    /// Call this immediately before `core.startEmulation()` using `await`.
    /// No-ops when the `mupenTransferPak` feature flag is disabled so that
    /// disabling the flag suppresses both the UI and the behavior.
    /// Realm resolution runs on a background thread to avoid blocking the main run loop.
    func applyPersistedTransferPakIfNeeded() async {
        guard PVFeatureFlagsManager.shared.mupenTransferPak else { return }
        guard let transferCore = core as? TransferPakSupport else { return }
        guard let md5 = game?.md5Hash, !md5.isEmpty else { return }

        let slotCount = transferCore.transferPakSlotCount
        // Resolve Realm + filesystem on a background thread so we don't block the main run loop.
        let roms = await Task.detached(priority: .userInitiated) {
            TransferPakStore.allROMs(forGameMD5: md5, slotCount: slotCount)
        }.value
        guard !roms.isEmpty else { return }

        for (port, rom) in roms {
            transferCore.setTransferPakROM(rom, forPort: port)
            DLOG("TransferPak: applied persisted slot \(port) → \(rom.romPath.lastPathComponent)")
        }
    }
}
