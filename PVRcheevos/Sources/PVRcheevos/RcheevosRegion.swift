//
//  RcheevosRegion.swift
//  PVRcheevos
//
//  Memory region descriptor handed to `RcheevosSession`.
//
//  Each region maps a contiguous block of emulator RAM into the rcheevos
//  flat 32-bit address space. The base address (`rcAddress`) is system-
//  specific and must match what the RA database expects for that console
//  — see `RcheevosAddressSpace` in PVRcheevosCore for the canonical
//  per-system constants.
//

import Foundation
import PVRcheevosCore

/// Maps a range of rcheevos address space onto a pointer into emulator RAM.
///
/// The pointer must remain valid for the lifetime of the `RcheevosSession`
/// that consumes it (typically the entire emulation session). Cores that
/// allocate or relocate RAM mid-session must rebuild the session.
public struct RcheevosRegion: @unchecked Sendable {
    /// Base address in the rcheevos flat address space for this system
    /// (e.g. `0x7E0000` for SNES WRAM, `0x00000000` for PSX Main RAM).
    public let rcAddress: UInt32

    /// Direct pointer into emulator RAM. Read-only from rcheevos's perspective.
    public let base: UnsafeMutableRawPointer

    /// Size of this region in bytes.
    public let size: UInt32

    /// Byte-swap mode applied when reading from this region. Use `.off`
    /// for all systems except Saturn (which needs `.word16` for Mednafen's
    /// big-endian-stored Work RAM).
    public let byteSwapMode: RcheevosByteSwapMode

    public init(
        rcAddress: UInt32,
        base: UnsafeMutableRawPointer,
        size: UInt32,
        byteSwapMode: RcheevosByteSwapMode = .off
    ) {
        self.rcAddress = rcAddress
        self.base = base
        self.size = size
        self.byteSwapMode = byteSwapMode
    }
}

extension RcheevosRegion {
    /// Returns `true` if `address` falls within this region.
    @inlinable
    public func contains(address: UInt32) -> Bool {
        address >= rcAddress && address < rcAddress &+ size
    }
}
