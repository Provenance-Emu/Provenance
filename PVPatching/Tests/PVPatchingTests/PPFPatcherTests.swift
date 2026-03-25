//
//  PPFPatcherTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

final class PPFPatcherTests: XCTestCase {

    private let patcher = PPFPatcher()

    // MARK: - Helpers

    /// Build a PPF 1.0 patch with the given records.
    /// Layout: magic(5) + description(50) + fileSize(4) + records
    private func makePPFv1Patch(
        records: [(offset: Int, data: [UInt8])],
        fileSize: UInt32 = 0
    ) -> Data {
        var patch = Data("PPF10".utf8)
        // 50-byte description (zero-padded)
        patch.append(contentsOf: [UInt8](repeating: 0, count: 50))
        // 4-byte LE file size check
        patch.append(UInt8(fileSize & 0xFF))
        patch.append(UInt8((fileSize >> 8) & 0xFF))
        patch.append(UInt8((fileSize >> 16) & 0xFF))
        patch.append(UInt8((fileSize >> 24) & 0xFF))
        // Records
        for record in records {
            appendLE32(&patch, value: UInt32(record.offset))
            patch.append(UInt8(record.data.count))
            patch.append(contentsOf: record.data)
        }
        return patch
    }

    /// Build a PPF 2.0 patch with the given records.
    /// Layout: magic(5) + encoding(1) + description(50) + imageType(4) +
    ///         blockCheck(1) + undoData(1) + dummy(1) + records
    private func makePPFv2Patch(records: [(offset: Int, data: [UInt8])]) -> Data {
        var patch = Data("PPF20".utf8)
        patch.append(0x00)  // encoding: sequential
        patch.append(contentsOf: [UInt8](repeating: 0, count: 50))  // description
        appendLE32(&patch, value: 0)  // image type: BIN
        patch.append(0x00)  // block check flag
        patch.append(0x00)  // undo data flag
        patch.append(0x00)  // dummy
        for record in records {
            appendLE32(&patch, value: UInt32(record.offset))
            patch.append(UInt8(record.data.count))
            patch.append(contentsOf: record.data)
        }
        return patch
    }

    /// Build a PPF 3.0 patch with the given records (8-byte offsets).
    /// Layout: magic(5) + encoding(1) + description(50) + imageType(1) +
    ///         blockCheck(1) + undoData(1) + dummy(1) + records
    private func makePPFv3Patch(records: [(offset: Int, data: [UInt8])]) -> Data {
        var patch = Data("PPF30".utf8)
        patch.append(0x00)  // encoding
        patch.append(contentsOf: [UInt8](repeating: 0, count: 50))  // description
        patch.append(0x00)  // image type
        patch.append(0x00)  // block check flag
        patch.append(0x00)  // undo data flag
        patch.append(0x00)  // dummy
        for record in records {
            appendLE64(&patch, value: UInt64(record.offset))
            patch.append(UInt8(record.data.count))
            patch.append(contentsOf: record.data)
        }
        return patch
    }

    private func appendLE32(_ data: inout Data, value: UInt32) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }

    private func appendLE64(_ data: inout Data, value: UInt64) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 32) & 0xFF))
        data.append(UInt8((value >> 40) & 0xFF))
        data.append(UInt8((value >> 48) & 0xFF))
        data.append(UInt8((value >> 56) & 0xFF))
    }

    // MARK: - PPF 1.0 Tests

    func testV1ApplySingleRecord() throws {
        let source = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        let patch = makePPFv1Patch(records: [(offset: 1, data: [0xAA, 0xBB])])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), [0x00, 0xAA, 0xBB, 0x03, 0x04])
    }

    func testV1ApplyMultipleRecords() throws {
        let source = Data(repeating: 0x00, count: 10)
        let patch = makePPFv1Patch(records: [
            (offset: 0, data: [0xDE, 0xAD]),
            (offset: 7, data: [0xBE, 0xEF])
        ])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[0], 0xDE)
        XCTAssertEqual(result[1], 0xAD)
        XCTAssertEqual(result[7], 0xBE)
        XCTAssertEqual(result[8], 0xEF)
        // Unchanged bytes remain zero
        XCTAssertEqual(result[2], 0x00)
        XCTAssertEqual(result[6], 0x00)
    }

    func testV1RecordBeyondSourceSizeThrows() {
        // Writing beyond the original source boundary should be rejected to prevent
        // unbounded allocation from malicious/corrupt patches.
        let source = Data([0x01, 0x02])
        let patch = makePPFv1Patch(records: [(offset: 5, data: [0xFF])])
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: source)) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testV1AtOffset0() throws {
        let source = Data([0xAA, 0xBB, 0xCC])
        let patch = makePPFv1Patch(records: [(offset: 0, data: [0x11, 0x22])])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), [0x11, 0x22, 0xCC])
    }

    func testV1TruncatedHeaderThrows() {
        // Header needs 59 bytes; give only the 5-byte magic
        let patch = Data("PPF10".utf8)
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    // MARK: - PPF 2.0 Tests

    func testV2ApplySingleRecord() throws {
        let source = Data(repeating: 0x00, count: 20)
        let patch = makePPFv2Patch(records: [(offset: 10, data: [0x42, 0x43, 0x44])])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[10], 0x42)
        XCTAssertEqual(result[11], 0x43)
        XCTAssertEqual(result[12], 0x44)
        // Unchanged
        XCTAssertEqual(result[9], 0x00)
        XCTAssertEqual(result[13], 0x00)
    }

    func testV2ApplyMultipleRecords() throws {
        let source = Data(repeating: 0xFF, count: 16)
        let patch = makePPFv2Patch(records: [
            (offset: 0, data: [0x01]),
            (offset: 8, data: [0x02, 0x03])
        ])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[0], 0x01)
        XCTAssertEqual(result[8], 0x02)
        XCTAssertEqual(result[9], 0x03)
        XCTAssertEqual(result[1], 0xFF)
    }

    func testV2TruncatedHeaderThrows() {
        // Only 10 bytes — not enough for a 63-byte header
        var patch = Data("PPF20".utf8)
        patch.append(contentsOf: [UInt8](repeating: 0, count: 5))
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testV2NonZeroEncodingMethodThrows() {
        var patch = Data("PPF20".utf8)
        patch.append(0x01)  // encoding method = 1 (unsupported)
        patch.append(contentsOf: [UInt8](repeating: 0, count: 57))  // rest of header
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.unsupportedFormat = error else {
                return XCTFail("Expected unsupportedFormat, got \(error)")
            }
        }
    }

    func testV2NonZeroBlockCheckThrows() {
        var patch = Data("PPF20".utf8)
        patch.append(0x00)  // encoding = 0
        patch.append(contentsOf: [UInt8](repeating: 0, count: 54))  // description + imageType
        patch.append(0x01)  // blockCheck = 1 (unsupported)
        patch.append(contentsOf: [UInt8](repeating: 0, count: 2))
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.unsupportedFormat = error else {
                return XCTFail("Expected unsupportedFormat, got \(error)")
            }
        }
    }

    func testV3NonZeroEncodingMethodThrows() {
        var patch = Data("PPF30".utf8)
        patch.append(0x01)  // encoding method = 1 (unsupported)
        patch.append(contentsOf: [UInt8](repeating: 0, count: 54))  // rest of header
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.unsupportedFormat = error else {
                return XCTFail("Expected unsupportedFormat, got \(error)")
            }
        }
    }

    func testV3NonZeroBlockCheckThrows() {
        var patch = Data("PPF30".utf8)
        patch.append(0x00)  // encoding = 0
        patch.append(contentsOf: [UInt8](repeating: 0, count: 51))  // description + imageType
        patch.append(0x01)  // blockCheck = 1 (unsupported)
        patch.append(contentsOf: [UInt8](repeating: 0, count: 2))  // undoData + reserved
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.unsupportedFormat = error else {
                return XCTFail("Expected unsupportedFormat, got \(error)")
            }
        }
    }

    func testV3NonZeroUndoDataThrows() {
        var patch = Data("PPF30".utf8)
        patch.append(0x00)  // encoding = 0
        patch.append(contentsOf: [UInt8](repeating: 0, count: 52))  // description + imageType + blockCheck
        patch.append(0x01)  // undoData = 1 (unsupported)
        patch.append(contentsOf: [UInt8](repeating: 0, count: 1))  // reserved
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.unsupportedFormat = error else {
                return XCTFail("Expected unsupportedFormat, got \(error)")
            }
        }
    }

    // MARK: - PPF 3.0 Tests

    func testV3ApplySingleRecord() throws {
        let source = Data(repeating: 0x00, count: 16)
        let patch = makePPFv3Patch(records: [(offset: 4, data: [0xCA, 0xFE])])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[4], 0xCA)
        XCTAssertEqual(result[5], 0xFE)
        XCTAssertEqual(result[3], 0x00)
        XCTAssertEqual(result[6], 0x00)
    }

    func testV3ApplyMultipleRecords() throws {
        let source = Data(repeating: 0xAB, count: 20)
        let patch = makePPFv3Patch(records: [
            (offset: 0, data: [0x10, 0x20, 0x30]),
            (offset: 15, data: [0x99])
        ])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[0], 0x10)
        XCTAssertEqual(result[1], 0x20)
        XCTAssertEqual(result[2], 0x30)
        XCTAssertEqual(result[15], 0x99)
        // Unchanged
        XCTAssertEqual(result[3], 0xAB)
        XCTAssertEqual(result[14], 0xAB)
    }

    func testV3TruncatedHeaderThrows() {
        var patch = Data("PPF30".utf8)
        patch.append(contentsOf: [UInt8](repeating: 0, count: 3))
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    // MARK: - Invalid magic / version detection

    func testInvalidMagicThrowsCorrupt() {
        let badPatch = Data("GARBAGE_DATA".utf8)
        XCTAssertThrowsError(try patcher.apply(patch: badPatch, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testEmptyPatchThrows() {
        XCTAssertThrowsError(try patcher.apply(patch: Data(), to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testUnknownPPFVersionThrowsUnsupported() {
        // "PPF40" would be a future/unknown version
        let patch = Data("PPF40".utf8)
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.unsupportedFormat = error else {
                return XCTFail("Expected unsupportedFormat, got \(error)")
            }
        }
    }

    func testIPSMagicIsRejectedAsCorrupt() {
        // "PATCH" header — not a PPF file
        let patch = Data("PATCH".utf8)
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    // MARK: - Edge cases

    func testV1NoRecordsProducesUnmodifiedSource() throws {
        let source = Data([0x01, 0x02, 0x03])
        let patch = makePPFv1Patch(records: [])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), [0x01, 0x02, 0x03])
    }

    func testV2NoRecordsProducesUnmodifiedSource() throws {
        let source = Data([0xDE, 0xAD])
        let patch = makePPFv2Patch(records: [])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), [0xDE, 0xAD])
    }

    func testV3NoRecordsProducesUnmodifiedSource() throws {
        let source = Data([0x00, 0x11, 0x22])
        let patch = makePPFv3Patch(records: [])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), [0x00, 0x11, 0x22])
    }

    func testV1MaxLengthRecord() throws {
        // length byte = 255 (max value in one byte)
        let source = Data(repeating: 0x00, count: 256)
        let data = [UInt8](repeating: 0xAB, count: 255)
        let patch = makePPFv1Patch(records: [(offset: 0, data: data)])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[0], 0xAB)
        XCTAssertEqual(result[254], 0xAB)
        XCTAssertEqual(result[255], 0x00)  // untouched
    }
}
