//
//  PVRcheevosTests.swift
//  PVRcheevosCore
//
//  Unit tests for the PVRcheevosCore utilities.
//  No dependency on the rcheevos C library — runs on macOS, iOS, tvOS, and Linux.
//
import Testing
@testable import PVRcheevosCore

// MARK: - Byte-swap mode tests

@Suite("RcheevosByteSwapMode")
struct ByteSwapModeTests {

    // MARK: .off mode — identity transformation

    @Test("off mode: offset 0 is unchanged")
    func offMode_offset0() {
        #expect(RcheevosByteSwapMode.off.physicalOffset(for: 0) == 0)
    }

    @Test("off mode: arbitrary offsets are unchanged")
    func offMode_arbitrary() {
        for offset: UInt32 in [1, 2, 7, 100, 0xFFFF] {
            #expect(RcheevosByteSwapMode.off.physicalOffset(for: offset) == offset)
        }
    }

    // MARK: .word16 mode — XOR-by-1 swap

    @Test("word16 mode: byte 0 maps to byte 1")
    func word16Mode_byte0() {
        #expect(RcheevosByteSwapMode.word16.physicalOffset(for: 0) == 1)
    }

    @Test("word16 mode: byte 1 maps to byte 0")
    func word16Mode_byte1() {
        #expect(RcheevosByteSwapMode.word16.physicalOffset(for: 1) == 0)
    }

    @Test("word16 mode: byte 2 maps to byte 3")
    func word16Mode_byte2() {
        #expect(RcheevosByteSwapMode.word16.physicalOffset(for: 2) == 3)
    }

    @Test("word16 mode: byte 3 maps to byte 2")
    func word16Mode_byte3() {
        #expect(RcheevosByteSwapMode.word16.physicalOffset(for: 3) == 2)
    }

    @Test("word16 mode: applying twice yields identity")
    func word16Mode_idempotent() {
        for offset: UInt32 in [0, 1, 2, 3, 100, 0xFFFE, 0xFFFF] {
            let swapped = RcheevosByteSwapMode.word16.physicalOffset(for: offset)
            let restored = RcheevosByteSwapMode.word16.physicalOffset(for: swapped)
            #expect(restored == offset, "Double-swap of \(offset) should restore original")
        }
    }

    @Test("word16 mode: adjacent byte pairs always swap")
    func word16Mode_adjacentPairs() {
        for n: UInt32 in stride(from: 0, to: 20, by: 2) {
            #expect(RcheevosByteSwapMode.word16.physicalOffset(for: n)     == n + 1)
            #expect(RcheevosByteSwapMode.word16.physicalOffset(for: n + 1) == n)
        }
    }

    @Test("word16 raw value matches ObjC MednafenRcheevosByteSwapModeWord16 (1)")
    func word16Mode_rawValue() {
        #expect(RcheevosByteSwapMode.word16.rawValue == 1)
    }

    @Test("off raw value matches ObjC MednafenRcheevosByteSwapModeOff (0)")
    func offMode_rawValue() {
        #expect(RcheevosByteSwapMode.off.rawValue == 0)
    }

    @Test("RcheevosByteSwapMode can be initialised from UInt8 raw value")
    func initFromRawValue() {
        #expect(RcheevosByteSwapMode(rawValue: 0) == .off)
        #expect(RcheevosByteSwapMode(rawValue: 1) == .word16)
        #expect(RcheevosByteSwapMode(rawValue: 99) == nil)
    }
}

// MARK: - Address space constant tests

@Suite("RcheevosAddressSpace")
struct AddressSpaceTests {

    @Test("PSX Main RAM base is 0x00000000")
    func psxMainRAMBase() {
        #expect(RcheevosAddressSpace.psxMainRAMBase == 0x00000000)
    }

    @Test("PSX Main RAM size is 2 MB")
    func psxMainRAMSize() {
        #expect(RcheevosAddressSpace.psxMainRAMSize == 2 * 1024 * 1024)
    }

    @Test("NES CPU RAM base is 0x0000")
    func nesRAMBase() {
        #expect(RcheevosAddressSpace.nesRAMBase == 0x0000)
    }

    @Test("NES CPU RAM size is 2 KB")
    func nesRAMSize() {
        #expect(RcheevosAddressSpace.nesRAMSize == 0x800)
    }

    @Test("SNES WRAM base is 0x7E0000")
    func snesWRAMBase() {
        #expect(RcheevosAddressSpace.snesWRAMBase == 0x7E0000)
    }

    @Test("PCE base RAM base is 0x1F0000")
    func pceBaseRAMBase() {
        #expect(RcheevosAddressSpace.pceBaseRAMBase == 0x1F0000)
    }

    @Test("PCE base RAM size is 8 KB")
    func pceBaseRAMSize() {
        #expect(RcheevosAddressSpace.pceBaseRAMSize == 8 * 1024)
    }

    @Test("SuperGrafx extended RAM size is 32 KB")
    func sgfxBaseRAMSize() {
        #expect(RcheevosAddressSpace.sgfxBaseRAMSize == 32 * 1024)
    }

    @Test("Saturn Low Work RAM starts at 0x000000")
    func saturnLowBase() {
        #expect(RcheevosAddressSpace.saturnLowWorkRAMBase == 0x000000)
    }

    @Test("Saturn High Work RAM starts at 0x100000")
    func saturnHighBase() {
        #expect(RcheevosAddressSpace.saturnHighWorkRAMBase == 0x100000)
    }

    @Test("Saturn High Work RAM base equals Low base plus one bank size")
    func saturnBanksAreContiguous() {
        #expect(RcheevosAddressSpace.saturnHighWorkRAMBase ==
                RcheevosAddressSpace.saturnLowWorkRAMBase + RcheevosAddressSpace.saturnWorkRAMBankSize)
    }

    @Test("Saturn Work RAM bank size is 1 MB")
    func saturnBankSize() {
        #expect(RcheevosAddressSpace.saturnWorkRAMBankSize == 1024 * 1024)
    }
}

// MARK: - Memory region descriptor tests

@Suite("RcheevosMemoryRegion")
struct MemoryRegionTests {

    // MARK: contains(address:)

    @Test("contains: address at region start is included")
    func containsStart() {
        let r = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x800)
        #expect(r.contains(address: 0x1000))
    }

    @Test("contains: last byte in region is included")
    func containsLastByte() {
        let r = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x800)
        #expect(r.contains(address: 0x17FF))
    }

    @Test("contains: past-the-end address is excluded")
    func containsEnd() {
        let r = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x800)
        #expect(!r.contains(address: 0x1800))
    }

    @Test("contains: address before region start is excluded")
    func containsBefore() {
        let r = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x800)
        #expect(!r.contains(address: 0x0FFF))
    }

    // MARK: physicalOffset(for:)

    @Test("physicalOffset: out-of-range address returns nil")
    func physicalOffsetOutOfRange() {
        let r = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x100)
        #expect(r.physicalOffset(for: 0x1100) == nil)
    }

    @Test("physicalOffset: .off mode returns logical offset from region base")
    func physicalOffsetOff() {
        let r = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x100, byteSwapMode: .off)
        #expect(r.physicalOffset(for: 0x1005) == 5)
    }

    @Test("physicalOffset: .word16 mode swaps adjacent bytes")
    func physicalOffsetWord16() {
        let r = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x100, byteSwapMode: .word16)
        #expect(r.physicalOffset(for: 0x1000) == 1)
        #expect(r.physicalOffset(for: 0x1001) == 0)
        #expect(r.physicalOffset(for: 0x1004) == 5)
    }

    // MARK: System-specific region coverage

    @Test("PSX Main RAM region covers 0x00000000–0x001FFFFF")
    func psxMainRAMRegion() {
        let r = RcheevosMemoryRegion(
            rcAddress: RcheevosAddressSpace.psxMainRAMBase,
            size: RcheevosAddressSpace.psxMainRAMSize)
        #expect(r.contains(address: 0x00000000))
        #expect(r.contains(address: 0x001FFFFF))
        #expect(!r.contains(address: 0x00200000))
    }

    @Test("NES RAM region covers 0x0000–0x07FF")
    func nesRAMRegion() {
        let r = RcheevosMemoryRegion(
            rcAddress: RcheevosAddressSpace.nesRAMBase,
            size: RcheevosAddressSpace.nesRAMSize)
        #expect(r.contains(address: 0x0000))
        #expect(r.contains(address: 0x07FF))
        #expect(!r.contains(address: 0x0800))
    }

    @Test("Saturn Low Work RAM uses word16 swap and covers 1 MB from 0x000000")
    func saturnLowWorkRAMRegion() {
        let r = RcheevosMemoryRegion(
            rcAddress: RcheevosAddressSpace.saturnLowWorkRAMBase,
            size: RcheevosAddressSpace.saturnWorkRAMBankSize,
            byteSwapMode: .word16)
        #expect(r.byteSwapMode == .word16)
        #expect(r.contains(address: 0x000000))
        #expect(r.contains(address: 0x0FFFFF))
        #expect(!r.contains(address: 0x100000))
    }

    @Test("Saturn High Work RAM uses word16 swap and covers 1 MB from 0x100000")
    func saturnHighWorkRAMRegion() {
        let r = RcheevosMemoryRegion(
            rcAddress: RcheevosAddressSpace.saturnHighWorkRAMBase,
            size: RcheevosAddressSpace.saturnWorkRAMBankSize,
            byteSwapMode: .word16)
        #expect(r.byteSwapMode == .word16)
        #expect(r.contains(address: 0x100000))
        #expect(r.contains(address: 0x1FFFFF))
        #expect(!r.contains(address: 0x200000))
    }

    // MARK: Equatable

    @Test("Two regions with identical fields are equal")
    func equatable() {
        let r1 = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x800, byteSwapMode: .off)
        let r2 = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x800, byteSwapMode: .off)
        #expect(r1 == r2)
    }

    @Test("Regions differing only in byteSwapMode are not equal")
    func notEquatableDifferentSwap() {
        let r1 = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x800, byteSwapMode: .off)
        let r2 = RcheevosMemoryRegion(rcAddress: 0x1000, size: 0x800, byteSwapMode: .word16)
        #expect(r1 != r2)
    }
}
