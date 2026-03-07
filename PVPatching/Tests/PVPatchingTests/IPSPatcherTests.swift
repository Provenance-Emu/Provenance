//
//  IPSPatcherTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

final class IPSPatcherTests: XCTestCase {

    private let patcher = IPSPatcher()

    // MARK: - Helper to build IPS patches

    /// Build a minimal IPS patch that replaces bytes at a given offset.
    private func makeIPSPatch(records: [(offset: Int, data: [UInt8])], truncateTo: Int? = nil) -> Data {
        var patch = Data("PATCH".utf8)
        for record in records {
            // 3-byte BE offset
            patch.append(UInt8((record.offset >> 16) & 0xFF))
            patch.append(UInt8((record.offset >> 8) & 0xFF))
            patch.append(UInt8(record.offset & 0xFF))
            // 2-byte BE length
            patch.append(UInt8((record.data.count >> 8) & 0xFF))
            patch.append(UInt8(record.data.count & 0xFF))
            // data
            patch.append(contentsOf: record.data)
        }
        if let size = truncateTo {
            patch.append(contentsOf: Data("EOF".utf8))
            patch.append(UInt8((size >> 16) & 0xFF))
            patch.append(UInt8((size >> 8) & 0xFF))
            patch.append(UInt8(size & 0xFF))
        } else {
            patch.append(contentsOf: Data("EOF".utf8))
        }
        return patch
    }

    /// Build an IPS RLE record.
    private func makeIPSRLEPatch(offset: Int, count: Int, byte: UInt8) -> Data {
        var patch = Data("PATCH".utf8)
        patch.append(UInt8((offset >> 16) & 0xFF))
        patch.append(UInt8((offset >> 8) & 0xFF))
        patch.append(UInt8(offset & 0xFF))
        // length == 0 signals RLE
        patch.append(0x00)
        patch.append(0x00)
        // RLE count (2 bytes BE)
        patch.append(UInt8((count >> 8) & 0xFF))
        patch.append(UInt8(count & 0xFF))
        // byte value
        patch.append(byte)
        patch.append(contentsOf: Data("EOF".utf8))
        return patch
    }

    // MARK: - Tests

    func testApplySimplePatch() throws {
        let source = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        let patch = makeIPSPatch(records: [(offset: 1, data: [0xAA, 0xBB])])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), [0x00, 0xAA, 0xBB, 0x03, 0x04])
    }

    func testApplyRLERecord() throws {
        let source = Data(repeating: 0x00, count: 10)
        let patch = makeIPSRLEPatch(offset: 2, count: 4, byte: 0xFF)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), [0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00])
    }

    func testPatchExtendsROMIfNeeded() throws {
        let source = Data([0x01, 0x02])
        let patch = makeIPSPatch(records: [(offset: 4, data: [0xCC])])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[4], 0xCC)
    }

    func testApplyMultipleRecords() throws {
        let source = Data(repeating: 0x00, count: 10)
        let patch = makeIPSPatch(records: [
            (offset: 0, data: [0xAA]),
            (offset: 5, data: [0xBB, 0xCC])
        ])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[0], 0xAA)
        XCTAssertEqual(result[5], 0xBB)
        XCTAssertEqual(result[6], 0xCC)
    }

    func testInvalidHeaderThrows() {
        let badPatch = Data("BADPATCH".utf8)
        XCTAssertThrowsError(try patcher.apply(patch: badPatch, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testEmptyPatchThrows() {
        XCTAssertThrowsError(try patcher.apply(patch: Data(), to: Data()))
    }
}
