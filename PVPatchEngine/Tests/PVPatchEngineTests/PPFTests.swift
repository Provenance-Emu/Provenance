//
//  PPFTests.swift
//  PVPatchEngineTests
//

import XCTest
@testable import PVPatchEngine

final class PPFTests: PatchTestCase {
    /// Large enough to hold the 1 KiB block-check window at 0x9320.
    private let source = FixtureData.bytes(seed: 31, count: 0x9320 + 4_096)
    private var block: [UInt8] { Array(source[0x9320..<(0x9320 + 1024)]) }

    func testVersion1() async throws {
        let patch = PPFBuilder.v1(records: [(10, [1, 2, 3]), (100, [9])])
        let (result, output) = try await apply(patch, ext: "ppf", to: source)
        var expected = source
        expected.replaceSubrange(10..<13, with: [1, 2, 3])
        expected[100] = 9
        XCTAssertEqual(output, expected)
        XCTAssertEqual(result.bytesWritten, UInt64(source.count))
    }

    func testVersion2ChecksSizeAndBlock() async throws {
        let patch = PPFBuilder.v2(sourceSize: UInt32(source.count), block: block, records: [(0x9320 + 2000, [7, 7])])
        let (result, output) = try await apply(patch, ext: "ppf", to: source)
        XCTAssertEqual(Array(output[(0x9320 + 2000)..<(0x9320 + 2002)]), [7, 7])
        XCTAssertEqual(result.verifiedChecksums, [.sourceBlockCheck])
    }

    func testVersion2WrongSizeIsASizeMismatch() async throws {
        let patch = PPFBuilder.v2(sourceSize: UInt32(source.count + 1), block: block, records: [(0, [1])])
        let error = await expectPatchError { _ = try await apply(patch, ext: "ppf", to: source) }
        guard case let .sourceSizeMismatch(expected, actual)? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertEqual(expected, UInt64(source.count + 1))
        XCTAssertEqual(actual, UInt64(source.count))
    }

    func testBlockMismatchIsASourceMismatchAndCanBeIgnored() async throws {
        var wrong = source
        wrong[0x9320 + 500] ^= 0xFF
        let patch = PPFBuilder.v3(block: block, records: [(20, [5])])
        let error = await expectPatchError { _ = try await apply(patch, ext: "ppf", to: wrong) }
        guard case let .sourceMismatch(expected, actual)? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertEqual(expected, crc32(block))
        XCTAssertEqual(actual, crc32(Array(wrong[0x9320..<(0x9320 + 1024)])))
        XCTAssertTrue(partialFiles.isEmpty)

        let (result, output) = try await apply(patch, ext: "ppf", to: wrong, options: PatchOptions(ignoreSourceChecksum: true))
        XCTAssertEqual(output[20], 5)
        XCTAssertEqual(result.verifiedChecksums, [])
    }

    func testVersion3WithUndoDataAndTrailer() async throws {
        let trailer = Array("@BEGIN_FILE_ID.DIZ".utf8) + [UInt8](repeating: 0x41, count: 40) + Array("@END_FILE_ID.DIZ".utf8) + [0, 0]
        let patch = PPFBuilder.v3(block: block, undo: true, records: [(30, [1, 2]), (60, [3])], trailer: trailer)
        let (result, output) = try await apply(patch, ext: "ppf", to: source)
        XCTAssertEqual(Array(output[30..<32]), [1, 2])
        XCTAssertEqual(output[60], 3)
        XCTAssertEqual(result.verifiedChecksums, [.sourceBlockCheck])
    }

    func testVersion3EightByteOffsetsBeyondTheImageAreRejected() async throws {
        let patch = PPFBuilder.v3(block: nil, records: [(0x1_0000_0000, [1])])
        let error = await expectPatchError { _ = try await apply(patch, ext: "ppf", to: source) }
        guard case .corruptPatch? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertTrue(partialFiles.isEmpty)
    }

    func testRecordRunningPastTheEndIsRejected() async throws {
        let patch = PPFBuilder.v1(records: [(UInt64(source.count - 1), [1, 2])])
        let error = await expectPatchError { _ = try await apply(patch, ext: "ppf", to: source) }
        guard case .corruptPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testTruncatedRecordIsReported() async throws {
        var patch = PPFBuilder.v1(records: [(10, [1, 2, 3, 4])])
        patch.removeLast(2)
        let error = await expectPatchError { _ = try await apply(patch, ext: "ppf", to: source) }
        guard case .truncatedPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testUnknownVersionIsUnsupported() async throws {
        var patch = PPFBuilder.v1(records: [(0, [1])])
        patch[3] = UInt8(ascii: "4")
        let error = await expectPatchError { _ = try await apply(patch, ext: "ppf", to: source) }
        guard case .unsupportedFormat? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testInspectReadsDescriptionAndDeclaredSize() throws {
        let url = try write(PPFBuilder.v2(sourceSize: UInt32(source.count), block: block, records: [(0, [1])]), named: "inspect.ppf")
        let info = try PatchEngine.inspect(patch: url)
        XCTAssertEqual(info.format, .ppf)
        XCTAssertEqual(info.sourceSize, UInt64(source.count))
        XCTAssertEqual(info.description, "test patch")
    }
}
