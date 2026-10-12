//
//  PPFPatcherTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

/// Fixtures follow the published PPF layouts (see PPFPatcher.swift header):
/// records at 0x38 for v1, at 0x43C for v2 (size + 1024-byte block check),
/// and after the 60-byte header (+1024 when block-checked) for v3.
final class PPFPatcherTests: XCTestCase {

    private let patcher = PPFPatcher()

    // MARK: - Helpers

    private func commonHeader(magic: String, version: UInt8) -> Data {
        var patch = Data(magic.utf8)
        patch.append(version)
        patch.append(contentsOf: [UInt8](repeating: 0x20, count: 50))
        return patch
    }

    private func makePPFv1Patch(records: [(offset: Int, data: [UInt8])]) -> Data {
        var patch = commonHeader(magic: "PPF10", version: 0x00)
        for record in records {
            appendLE32(&patch, value: UInt32(record.offset))
            patch.append(UInt8(record.data.count))
            patch.append(contentsOf: record.data)
        }
        return patch
    }

    private func makePPFv2Patch(
        records: [(offset: Int, data: [UInt8])],
        originalSize: UInt32 = 0,
        blockCheck: [UInt8] = [UInt8](repeating: 0, count: 1024)
    ) -> Data {
        var patch = commonHeader(magic: "PPF20", version: 0x01)
        appendLE32(&patch, value: originalSize)
        patch.append(contentsOf: blockCheck)
        for record in records {
            appendLE32(&patch, value: UInt32(record.offset))
            patch.append(UInt8(record.data.count))
            patch.append(contentsOf: record.data)
        }
        return patch
    }

    private func makePPFv3Patch(
        records: [(offset: Int, data: [UInt8], undo: [UInt8]?)],
        imageType: UInt8 = 0,
        blockCheck: [UInt8]? = nil,
        undoData: Bool = false
    ) -> Data {
        var patch = commonHeader(magic: "PPF30", version: 0x02)
        patch.append(imageType)
        patch.append(blockCheck == nil ? 0 : 1)
        patch.append(undoData ? 1 : 0)
        patch.append(0x00)
        if let blockCheck {
            patch.append(contentsOf: blockCheck)
        }
        for record in records {
            appendLE64(&patch, value: UInt64(record.offset))
            patch.append(UInt8(record.data.count))
            patch.append(contentsOf: record.data)
            if undoData {
                patch.append(contentsOf: record.undo ?? [UInt8](repeating: 0, count: record.data.count))
            }
        }
        return patch
    }

    private func appendLE32(_ data: inout Data, value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) {
            data.append(UInt8((value >> UInt32(shift)) & 0xFF))
        }
    }

    private func appendLE64(_ data: inout Data, value: UInt64) {
        for shift in stride(from: 0, to: 64, by: 8) {
            data.append(UInt8((value >> UInt64(shift)) & 0xFF))
        }
    }

    private func sampleSource(count: Int = 64) -> Data {
        Data((0..<count).map { UInt8($0 & 0xFF) })
    }

    // MARK: - PPF 1.0

    func testV1ApplySingleRecord() throws {
        let source = sampleSource()
        let patch = makePPFv1Patch(records: [(offset: 4, data: [0xAA, 0xBB])])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[4], 0xAA)
        XCTAssertEqual(result[5], 0xBB)
        XCTAssertEqual(result[3], source[3])
        XCTAssertEqual(result.count, source.count)
    }

    func testV1ApplyMultipleRecords() throws {
        let source = sampleSource()
        let patch = makePPFv1Patch(records: [
            (offset: 0, data: [0x11]),
            (offset: 10, data: [0x22, 0x33, 0x44]),
            (offset: 63, data: [0x55])
        ])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[0], 0x11)
        XCTAssertEqual(Array(result[10..<13]), [0x22, 0x33, 0x44])
        XCTAssertEqual(result[63], 0x55)
    }

    func testV1RecordBeyondSourceSizeThrows() {
        let source = sampleSource(count: 16)
        let patch = makePPFv1Patch(records: [(offset: 15, data: [0x01, 0x02])])
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: source)) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testV1TruncatedHeaderThrows() {
        let patch = Data("PPF10".utf8) + Data(repeating: 0, count: 10)
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: sampleSource())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testV1NoRecordsProducesUnmodifiedSource() throws {
        let source = sampleSource()
        XCTAssertEqual(try patcher.apply(patch: makePPFv1Patch(records: []), to: source), source)
    }

    func testV1MaxLengthRecord() throws {
        let source = Data(repeating: 0, count: 300)
        let payload = [UInt8](repeating: 0x7E, count: 255)
        let patch = makePPFv1Patch(records: [(offset: 10, data: payload)])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result[10..<265]), payload)
        XCTAssertEqual(result[265], 0)
    }

    // MARK: - PPF 2.0

    func testV2ApplyRecordsAfterBlockCheck() throws {
        let source = sampleSource()
        let patch = makePPFv2Patch(records: [
            (offset: 2, data: [0xDE, 0xAD]),
            (offset: 60, data: [0xBE, 0xEF])
        ], originalSize: UInt32(source.count))
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result[2..<4]), [0xDE, 0xAD])
        XCTAssertEqual(Array(result[60..<62]), [0xBE, 0xEF])
    }

    func testV2WrongOriginalSizeThrowsSourceMismatch() {
        let patch = makePPFv2Patch(records: [], originalSize: 999)
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: sampleSource())) { error in
            guard case PatchError.sourceROMMismatch = error else {
                return XCTFail("Expected sourceROMMismatch, got \(error)")
            }
        }
    }

    func testV2BlockCheckIsVerifiedAgainst0x9320() throws {
        // Large enough image to contain the 0x9320…0x971F window.
        var source = Data(repeating: 0x00, count: 0x9320 + 1024 + 16)
        for i in 0..<1024 { source[0x9320 + i] = UInt8(i & 0xFF) }
        let block = (0..<1024).map { UInt8($0 & 0xFF) }

        let good = makePPFv2Patch(records: [(offset: 1, data: [0x42])], blockCheck: block)
        XCTAssertEqual(try patcher.apply(patch: good, to: source)[1], 0x42)

        var wrongBlock = block
        wrongBlock[0] ^= 0xFF
        let bad = makePPFv2Patch(records: [(offset: 1, data: [0x42])], blockCheck: wrongBlock)
        XCTAssertThrowsError(try patcher.apply(patch: bad, to: source)) { error in
            guard case PatchError.sourceROMMismatch = error else {
                return XCTFail("Expected sourceROMMismatch, got \(error)")
            }
        }
    }

    func testV2TruncatedHeaderThrows() {
        let patch = Data("PPF20".utf8) + Data(repeating: 0, count: 100)
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: sampleSource())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testV2NoRecordsProducesUnmodifiedSource() throws {
        let source = sampleSource()
        XCTAssertEqual(try patcher.apply(patch: makePPFv2Patch(records: []), to: source), source)
    }

    // MARK: - PPF 3.0

    func testV3ApplySingleRecordWithoutBlockCheck() throws {
        let source = sampleSource()
        let patch = makePPFv3Patch(records: [(offset: 8, data: [0x99], undo: nil)])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[8], 0x99)
        XCTAssertEqual(result[7], source[7])
    }

    func testV3RecordsStartAfterBlockCheckWhenFlagged() throws {
        let source = sampleSource()
        let patch = makePPFv3Patch(
            records: [(offset: 3, data: [0x77, 0x66], undo: nil)],
            blockCheck: [UInt8](repeating: 0, count: 1024)
        )
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result[3..<5]), [0x77, 0x66])
    }

    func testV3UndoDataIsSkipped() throws {
        let source = sampleSource()
        let patch = makePPFv3Patch(
            records: [
                (offset: 1, data: [0xA1, 0xA2], undo: [source[1], source[2]]),
                (offset: 20, data: [0xB1], undo: [source[20]])
            ],
            undoData: true
        )
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result[1..<3]), [0xA1, 0xA2])
        XCTAssertEqual(result[20], 0xB1)
        // Undo bytes must not have been applied as a second record.
        XCTAssertEqual(result[3], source[3])
    }

    func testV3GIImageTypeUsesAlternateBlockCheckWindow() throws {
        var source = Data(repeating: 0x00, count: 0x9320 + 1024 + 16)
        for i in 0..<1024 { source[0x80A0 + i] = UInt8((i * 3) & 0xFF) }
        let block = (0..<1024).map { UInt8(($0 * 3) & 0xFF) }
        let patch = makePPFv3Patch(records: [(offset: 0, data: [0x01], undo: nil)], imageType: 1, blockCheck: block)
        XCTAssertEqual(try patcher.apply(patch: patch, to: source)[0], 0x01)
    }

    func testV3StopsAtFileIDTrailer() throws {
        let source = sampleSource()
        var patch = makePPFv3Patch(records: [(offset: 5, data: [0x5A], undo: nil)])
        patch.append(contentsOf: Array("@BEGIN_FILE_ID.DIZ".utf8))
        patch.append(contentsOf: Array("Made with ppf-o-matic".utf8))
        patch.append(contentsOf: Array("@END_FILE_ID.DIZ".utf8))
        patch.append(contentsOf: [0x15, 0x00])
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result[5], 0x5A)
        XCTAssertEqual(result.count, source.count)
    }

    func testV3TruncatedHeaderThrows() {
        let patch = Data("PPF30".utf8) + Data(repeating: 0, count: 20)
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: sampleSource())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testV3NoRecordsProducesUnmodifiedSource() throws {
        let source = sampleSource()
        XCTAssertEqual(try patcher.apply(patch: makePPFv3Patch(records: []), to: source), source)
    }

    // MARK: - Common

    func testInvalidMagicThrowsCorrupt() {
        let badPatch = Data("NOTPPF".utf8) + Data(repeating: 0, count: 100)
        XCTAssertThrowsError(try patcher.apply(patch: badPatch, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testEmptyPatchThrows() {
        XCTAssertThrowsError(try patcher.apply(patch: Data(), to: Data()))
    }

    func testUnknownPPFVersionThrowsUnsupported() {
        let patch = Data("PPF40".utf8) + Data(repeating: 0, count: 100)
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.unsupportedFormat = error else {
                return XCTFail("Expected unsupportedFormat, got \(error)")
            }
        }
    }

    func testIPSMagicIsRejectedAsCorrupt() {
        let patch = Data("PATCH".utf8) + Data(repeating: 0, count: 100)
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }
}
