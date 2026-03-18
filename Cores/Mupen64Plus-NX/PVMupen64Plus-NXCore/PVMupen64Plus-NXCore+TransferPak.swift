//
//  PVMupen64Plus-NXCore+TransferPak.swift
//  PVMupen64Plus-NX
//
//  Part of #2741 — Transfer Pak support for the Mupen64Plus-NX core
//
//  Wires the `TransferPakSupport` protocol to the Mupen64Plus-NX bridge so
//  that the app's generic Transfer Pak UI and persistence layer can mount
//  GB/GBC cartridges into the N64 controller-port Transfer Pak slots.
//
//  ## How it works
//
//  1. `setTransferPakROM(_:forPort:)` stores the GB ROM path via
//     `setGBCartROMPath(_:savePath:forPort:)` (declared in Controls.h),
//     which keeps C-string copies that the registered `m64p_media_loader`
//     callbacks (`MupenNXGetGBCartROM` / `MupenNXGetGBCartRAM`) return to
//     the emulator core on demand.
//
//  2. The pak mode is set to `PLUGIN_TRANSFER_PAK` (4) so `MupenInitiateControllers`
//     reports the correct plugin type to the core's input system.
//
//  3. The media loader is registered once in `loadFileAtPath:` (PVMupen64Plus-NXCore.m),
//     so the core can request GB cart data before and during emulation.
//
//  ## Platform notes
//  This file is compiled for iOS, tvOS, macOS Catalyst, and visionOS.
//  No platform guards are needed here because all referenced APIs are
//  available on all Provenance targets.
//

import Foundation
import PVCoreBridge
import PVLogging

private let PLUGIN_TRANSFER_PAK: Int = 4   // from plugin.h
private let PLUGIN_MEMPAK: Int       = 2   // from plugin.h — fallback when slot cleared

extension PVMupen64PlusNXCore: TransferPakSupport {

    public var transferPakSlotCount: Int { 4 }

    /// Mounts (or unmounts) a GB/GBC cartridge in the given controller-port
    /// Transfer Pak slot, and switches the controller pak mode accordingly.
    ///
    /// Pass `nil` to clear the slot and revert to Memory Pak mode.
    public func setTransferPakROM(_ rom: TransferPakROM?, forPort port: Int) {
        guard port >= 0 && port < transferPakSlotCount else {
            ELOG("TransferPak-NX: invalid port \(port) — must be 0–3")
            return
        }

        // Store the GB cart paths so the m64p_media_loader callbacks can serve them.
        setGBCartROMPath(
            rom?.romPath.path,
            savePath: rom?.savePath?.path,
            forPort: port
        )

        // Switch the controller pak plugin mode:
        //   4 = PLUGIN_TRANSFER_PAK — tells MupenInitiateControllers to declare
        //       this port as a Transfer Pak, which the core checks on ROM load.
        //   2 = PLUGIN_MEMPAK       — safe fallback when no cart is assigned.
        let mode = rom != nil ? PLUGIN_TRANSFER_PAK : PLUGIN_MEMPAK
        setMode(mode, forController: port)

        if let rom {
            DLOG("TransferPak-NX: port \(port) → \(rom.romPath.lastPathComponent)")
        } else {
            DLOG("TransferPak-NX: port \(port) cleared (pak mode → Memory Pak)")
        }
    }

    /// Returns the currently mounted Transfer Pak ROM for the given port, or
    /// `nil` if the slot is empty.
    public func transferPakROM(forPort port: Int) -> TransferPakROM? {
        guard port >= 0 && port < transferPakSlotCount else { return nil }
        guard let romPathStr = gbCartROMPathForPort(port) else { return nil }
        let romURL  = URL(fileURLWithPath: romPathStr)
        let saveURL = gbCartSavePathForPort(port).map { URL(fileURLWithPath: $0) }
        return TransferPakROM(romPath: romURL, savePath: saveURL)
    }
}
