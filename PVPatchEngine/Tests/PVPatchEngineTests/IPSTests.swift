//
//  IPSTests.swift
//  PVPatchEngineTests
//

import XCTest
@testable import PVPatchEngine

final class IPSTests: PatchTestCase {
    func testAppliesRecordsAndRuns() async throws {
        let source = [UInt8](0..<10)
        let patch = IPSBuilder.patch(records: [(1, [0xAA, 0xBB])], runs: [(5, 3, 0xFF)])
        let (result, output) = try await apply(patch, ext: "ips", to: source)
        XCTAssertEqual(output, [0, 0xAA, 0xBB, 3, 4, 0xFF, 0xFF, 0xFF, 8, 9])
        XCTAssertEqual(result.bytesWritten, 10)
        XCTAssertEqual(result.verifiedChecksums, [])
        XCTAssertNil(result.ignoredTargetMismatch)
    }

    func testRecordsCanExtendTheImage() async throws {
        let patch = IPSBuilder.patch(records: [(4, [0xCC])])
        let (result, output) = try await apply(patch, ext: "ips", to: [1, 2])
        XCTAssertEqual(output, [1, 2, 0, 0, 0xCC])
        XCTAssertEqual(result.bytesWritten, 5)
    }

    func testRecordAtTheEOFOffsetIsNotTheTerminator() async throws {
        let patch = IPSBuilder.patch(records: [(0x454F46, [0x11, 0x22])])
        let (_, output) = try await apply(patch, ext: "ips", to: [UInt8](repeating: 7, count: 4))
        XCTAssertEqual(output.count, 0x454F46 + 2)
        XCTAssertEqual(Array(output[0..<4]), [7, 7, 7, 7])
        XCTAssertEqual(Array(output[0x454F46...]), [0x11, 0x22])
    }

    func testTruncationTrailerShrinksTheImage() async throws {
        let patch = IPSBuilder.patch(records: [(0, [9])], truncateTo: 4)
        let (result, output) = try await apply(patch, ext: "ips", to: [UInt8](repeating: 1, count: 10))
        XCTAssertEqual(output, [9, 1, 1, 1])
        XCTAssertEqual(result.bytesWritten, 4)
    }

    func testTruncationLargerThanTheImageIsIgnored() async throws {
        let patch = IPSBuilder.patch(records: [(0, [9])], truncateTo: 100)
        let (_, output) = try await apply(patch, ext: "ips", to: [1, 1, 1])
        XCTAssertEqual(output, [9, 1, 1])
    }

    func testIPS32UsesFourByteOffsets() async throws {
        let patch = IPSBuilder.patch(records: [(0x0100_0000, [1, 2, 3])], ips32: true)
        let (result, output) = try await apply(patch, ext: "ips32", to: [5])
        XCTAssertEqual(output.count, 0x0100_0003)
        XCTAssertEqual(Array(output[0x0100_0000...]), [1, 2, 3])
        XCTAssertEqual(output[0], 5)
        XCTAssertEqual(result.bytesWritten, 0x0100_0003)
    }

    func testIPS32AcceptsPatchMagicWithTheIPS32Extension() async throws {
        var patch = IPSBuilder.patch(records: [(2, [0xAB])], ips32: true)
        patch.replaceSubrange(0..<5, with: Array("PATCH".utf8))
        let (_, output) = try await apply(patch, ext: "ips32", to: [0, 0, 0])
        XCTAssertEqual(output, [0, 0, 0xAB])
    }

    func testPatchWithoutTerminatorIsTruncated() async throws {
        var patch = IPSBuilder.patch(records: [(0, [1, 2])])
        patch.removeLast(3)
        let error = await expectPatchError { _ = try await apply(patch, ext: "ips", to: [0, 0, 0]) }
        guard case .truncatedPatch? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertTrue(partialFiles.isEmpty)
    }

    func testRecordCutShortIsTruncated() async throws {
        var patch = IPSBuilder.patch(records: [(0, [1, 2, 3, 4])])
        patch.removeLast(6)
        let error = await expectPatchError { _ = try await apply(patch, ext: "ips", to: [0, 0, 0]) }
        guard case .truncatedPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testOutputBeyondTheLimitIsRefused() async throws {
        let patch = IPSBuilder.patch(records: [(0x100_0000, [1])], ips32: true)
        let error = await expectPatchError {
            _ = try await apply(patch, ext: "ips32", to: [0], options: PatchOptions(maxOutputSize: 1024))
        }
        guard case .outputTooLarge? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("output.bin").path))
    }

    func testNotAPatchIsUnsupported() async throws {
        let error = await expectPatchError { _ = try await apply([1, 2, 3, 4, 5, 6], ext: "ips", to: [0]) }
        guard case .unsupportedFormat? = error else { return XCTFail("got \(String(describing: error))") }
    }
}
