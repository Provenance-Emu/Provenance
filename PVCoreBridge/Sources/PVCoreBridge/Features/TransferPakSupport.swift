//
//  TransferPakSupport.swift
//  PVCoreBridge
//
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation

/// Identifies a GB/GBC ROM to mount in a Transfer Pak slot.
public struct TransferPakROM: Sendable {
    /// Absolute path to the .gb or .gbc ROM file.
    public let romPath: URL
    /// Optional absolute path to a .sav file.
    /// If `nil`, the core manages save data internally.
    public let savePath: URL?

    public init(romPath: URL, savePath: URL? = nil) {
        self.romPath = romPath
        self.savePath = savePath
    }
}

/// Adopted by N64 emulator cores that support the Transfer Pak accessory.
///
/// The Transfer Pak lets a GB/GBC cartridge be plugged into an N64 controller
/// port so that N64 games can read and write the GB game's save data and ROM.
/// Up to 4 simultaneous Transfer Pak slots are supported — one per controller port.
public protocol TransferPakSupport: AnyObject {
    /// Maximum number of simultaneous Transfer Pak slots (usually 4, one per controller port).
    var transferPakSlotCount: Int { get }

    /// Sets (or clears) the GB/GBC ROM mounted in the given controller port (0-based index).
    /// Pass `nil` to remove the cartridge from the slot.
    func setTransferPakROM(_ rom: TransferPakROM?, forPort port: Int)

    /// Returns the currently mounted ROM for the given port, or `nil` if the slot is empty.
    func transferPakROM(forPort port: Int) -> TransferPakROM?
}
