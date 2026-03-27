//
//  RcheevosUtilities.swift
//  PVRcheevosCore
//
//  Pure-Swift utilities for the rcheevos integration layer.
//  No dependency on the CRcheevos C library — safe to import on all platforms
//  including Linux without the rcheevos git submodule.
//

// MARK: - Byte-swap mode

/// Controls per-byte reordering applied inside the read-memory callback before
/// bytes are handed to rcheevos.
///
/// Most systems store RAM as plain bytes and need no swapping.  Saturn is an
/// exception: Mednafen represents Saturn Work RAM as `uint16_t` arrays written/read
/// through `ne16_rbo_be` helpers which swap adjacent bytes on little-endian hosts.
/// Exposing the raw `uint8_t*` to rcheevos without correction yields scrambled bytes.
///
/// - SeeAlso: `MednafenRcheevosByteSwapMode` (ObjC equivalent in MednafenRcheevosObjC.h)
public enum RcheevosByteSwapMode: UInt8, Sendable {
    /// No byte swapping — bytes are served as-is (default for most systems).
    case off    = 0
    /// Swap bytes within each 16-bit word before serving to rcheevos.
    /// Physical byte at logical offset `k` is read from physical offset `k ^ 1`.
    /// Required for Saturn Work RAM on little-endian hosts (iOS/tvOS/macOS).
    case word16 = 1

    /// Apply the byte-swap transformation to a logical byte offset, returning
    /// the physical byte offset to read from the raw memory buffer.
    ///
    /// - Parameter offset: Logical byte offset within a memory region (0-based).
    /// - Returns: Physical byte offset after applying the swap, or `offset` unchanged
    ///   for `.off` mode.
    public func physicalOffset(for offset: UInt32) -> UInt32 {
        switch self {
        case .off:    return offset
        case .word16: return offset ^ 1
        }
    }
}

// MARK: - rcheevos address space constants

/// Base addresses and sizes in the rcheevos flat address space for each Mednafen
/// system.  These match the libretro/rcheevos memory-map specifications and must
/// be kept in sync with `MednafenGameCore+RetroAchievements.swift`.
public enum RcheevosAddressSpace {

    // MARK: PSX
    /// PSX Main RAM base address in rcheevos address space.
    public static let psxMainRAMBase: UInt32 = 0x00000000
    /// PSX Main RAM size (2 MB).
    public static let psxMainRAMSize: UInt32 = 2 * 1024 * 1024

    // MARK: NES
    /// NES CPU RAM base address in rcheevos address space.
    public static let nesRAMBase: UInt32 = 0x0000
    /// NES CPU RAM size (2 KB).
    public static let nesRAMSize: UInt32 = 0x800

    // MARK: SNES
    /// SNES Work RAM base address in rcheevos address space (snes_faust).
    public static let snesWRAMBase: UInt32 = 0x7E0000

    // MARK: PCE / SuperGrafx
    /// PCE / SuperGrafx base RAM start address in rcheevos address space.
    public static let pceBaseRAMBase: UInt32 = 0x1F0000
    /// Standard PCE base RAM size (8 KB).
    public static let pceBaseRAMSize: UInt32 = 8 * 1024
    /// SuperGrafx extended base RAM size (32 KB).
    public static let sgfxBaseRAMSize: UInt32 = 32 * 1024

    // MARK: Saturn
    /// Saturn Low Work RAM base address in rcheevos address space (1 MB).
    public static let saturnLowWorkRAMBase: UInt32 = 0x000000
    /// Saturn High Work RAM base address in rcheevos address space (1 MB).
    public static let saturnHighWorkRAMBase: UInt32 = 0x100000
    /// Size of each Saturn Work RAM bank (1 MB).
    public static let saturnWorkRAMBankSize: UInt32 = 1024 * 1024
}

// MARK: - Memory region descriptor (pure-Swift equivalent)

/// A pure-Swift description of a single rcheevos memory region.
///
/// Mirrors `MednafenRcheevosRegion` (the ObjC struct in MednafenRcheevosObjC.h)
/// for use in tests and logging without requiring the CRcheevos C library.
public struct RcheevosMemoryRegion: Equatable, Sendable {
    /// Base address of this region in the rcheevos flat address space.
    public let rcAddress: UInt32
    /// Size of this region in bytes.
    public let size: UInt32
    /// Byte-swap mode applied when reading from this region.
    public let byteSwapMode: RcheevosByteSwapMode

    public init(rcAddress: UInt32, size: UInt32, byteSwapMode: RcheevosByteSwapMode = .off) {
        self.rcAddress = rcAddress
        self.size = size
        self.byteSwapMode = byteSwapMode
    }

    /// Returns `true` if `address` falls within this region's rcheevos address space.
    public func contains(address: UInt32) -> Bool {
        address >= rcAddress && address < rcAddress &+ size
    }

    /// Translate a flat rcheevos address to a physical byte offset within this region.
    ///
    /// - Parameter address: A flat rcheevos address that `contains(address:)` returns `true` for.
    /// - Returns: The physical byte offset after applying `byteSwapMode`, or `nil` if the
    ///   address is out of range.
    public func physicalOffset(for address: UInt32) -> UInt32? {
        guard contains(address: address) else { return nil }
        let logicalOffset = address - rcAddress
        return byteSwapMode.physicalOffset(for: logicalOffset)
    }
}
