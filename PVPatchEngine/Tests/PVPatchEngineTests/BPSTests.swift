//
//  BPSTests.swift
//  PVPatchEngineTests
//

import XCTest
@testable import PVPatchEngine

final class BPSTests: PatchTestCase {
    private let source = FixtureData.bytes(seed: 11, count: 50_000)

    private func mixedBuilder() -> BPSBuilder {
        var builder = BPSBuilder(source: source)
        builder.sourceRead(1_000)
        builder.targetRead(Array("patched!".utf8))
        builder.sourceCopy(offset: 30_000, length: 2_000)
        builder.targetCopy(offset: 500, length: 700)
        builder.sourceCopy(offset: 100, length: 50)
        builder.targetRead([1, 2, 3])
        builder.metadata = Array("{\"title\":\"test\"}".utf8)
        return builder
    }

    func testAppliesEveryActionAndVerifiesEveryChecksum() async throws {
        let builder = mixedBuilder()
        let patch = builder.patch()
        let (result, output) = try await apply(patch, ext: "bps", to: source)
        XCTAssertEqual(output, builder.target)
        XCTAssertEqual(result.bytesWritten, UInt64(builder.target.count))
        XCTAssertEqual(
            result.verifiedChecksums,
            [.patchCRC32(trailingCRC(patch)), .sourceCRC32(crc32(source)), .targetCRC32(crc32(builder.target))]
        )
        XCTAssertNil(result.ignoredTargetMismatch)
        XCTAssertTrue(partialFiles.isEmpty)
    }

    func testTargetCopyRepeatsOverlappingBytes() async throws {
        var builder = BPSBuilder(source: [])
        builder.targetRead([0xAA])
        builder.targetCopy(offset: 0, length: 2_100_000)
        builder.targetRead([0x01, 0x02, 0x03])
        builder.targetCopy(offset: 2_100_001, length: 2_200_000)
        builder.targetRead(Array("abcdefg".utf8))
        builder.targetCopy(offset: builder.target.count - 7, length: 40)
        builder.targetCopy(offset: 10, length: 300_000)
        builder.targetCopy(offset: builder.target.count - 2_100_000, length: 2_200_000)
        let (_, output) = try await apply(builder.patch(), ext: "bps", to: [])
        XCTAssertEqual(output.count, builder.target.count)
        XCTAssertTrue(output == builder.target, "overlapping TargetCopy output differs from byte-wise semantics")
    }

    func testSourceReadPastTheSourceReadsZeros() async throws {
        var builder = BPSBuilder(source: [1, 2, 3])
        builder.sourceRead(6)
        let (_, output) = try await apply(builder.patch(), ext: "bps", to: [1, 2, 3])
        XCTAssertEqual(output, [1, 2, 3, 0, 0, 0])
    }

    func testSourceMismatchReportsBothChecksums() async throws {
        let builder = mixedBuilder()
        var wrong = source
        wrong[40_000] ^= 0xFF
        let error = await expectPatchError { _ = try await apply(builder.patch(), ext: "bps", to: wrong) }
        guard case let .sourceMismatch(expected, actual)? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertEqual(expected, crc32(source))
        XCTAssertEqual(actual, crc32(wrong))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("output.bin").path))
        XCTAssertTrue(partialFiles.isEmpty)
    }

    func testIgnoreSourceChecksumAppliesAnyway() async throws {
        let builder = mixedBuilder()
        var wrong = source
        wrong[500] ^= 0xFF
        let options = PatchOptions(ignoreSourceChecksum: true)
        let (result, output) = try await apply(builder.patch(), ext: "bps", to: wrong, options: options)

        var expected = BPSBuilder(source: wrong)
        expected.sourceRead(1_000)
        expected.targetRead(Array("patched!".utf8))
        expected.sourceCopy(offset: 30_000, length: 2_000)
        expected.targetCopy(offset: 500, length: 700)
        expected.sourceCopy(offset: 100, length: 50)
        expected.targetRead([1, 2, 3])
        XCTAssertEqual(output, expected.target)
        XCTAssertEqual(result.ignoredTargetMismatch, ChecksumMismatch(expected: crc32(builder.target), actual: crc32(expected.target)))
        XCTAssertFalse(result.verifiedChecksums.contains(.sourceCRC32(crc32(wrong))))
    }

    func testIgnoreSourceChecksumWithAMatchingSourceStillVerifiesTheTarget() async throws {
        let builder = mixedBuilder()
        let (result, _) = try await apply(builder.patch(), ext: "bps", to: source, options: PatchOptions(ignoreSourceChecksum: true))
        XCTAssertTrue(result.verifiedChecksums.contains(.targetCRC32(crc32(builder.target))))
        XCTAssertNil(result.ignoredTargetMismatch)
    }

    func testSourceSmallerThanDeclaredIsASizeMismatch() async throws {
        let error = await expectPatchError { _ = try await apply(mixedBuilder().patch(), ext: "bps", to: Array(source.prefix(1_000))) }
        guard case let .sourceSizeMismatch(expected, actual)? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertEqual(expected, UInt64(source.count))
        XCTAssertEqual(actual, 1_000)
    }

    func testWrongTargetChecksumIsReported() async throws {
        let builder = mixedBuilder()
        let patch = builder.patch(targetCRC: 0xDEAD_BEEF)
        let error = await expectPatchError { _ = try await apply(patch, ext: "bps", to: source) }
        guard case let .targetMismatch(expected, actual)? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertEqual(expected, 0xDEAD_BEEF)
        XCTAssertEqual(actual, crc32(builder.target))
        XCTAssertTrue(partialFiles.isEmpty)
    }

    func testCorruptedPatchFailsItsOwnChecksum() async throws {
        var patch = mixedBuilder().patch()
        patch[patch.count / 2] ^= 0x01
        let error = await expectPatchError { _ = try await apply(patch, ext: "bps", to: source) }
        guard case .corruptPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testPatchShorterThanTheMinimumIsTruncated() async throws {
        let error = await expectPatchError { _ = try await apply(Array("BPS1".utf8) + [0x80, 0x80], ext: "bps", to: source) }
        guard case .truncatedPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testCutPatchIsRejected() async throws {
        let patch = mixedBuilder().patch()
        let error = await expectPatchError { _ = try await apply(Array(patch.prefix(patch.count - 20)), ext: "bps", to: source) }
        XCTAssertNotNil(error)
        XCTAssertTrue(partialFiles.isEmpty)
    }

    func testActionsThatDoNotFillTheTargetAreCorrupt() async throws {
        var builder = BPSBuilder(source: [1, 2, 3, 4])
        builder.sourceRead(4)
        var patch = Array("BPS1".utf8) + variableLength(4) + variableLength(10) + variableLength(0) + builder.actions
        patch += littleEndian(crc32([1, 2, 3, 4])) + littleEndian(0)
        patch = appendingPatchCRC(patch)
        let error = await expectPatchError { _ = try await apply(patch, ext: "bps", to: [1, 2, 3, 4]) }
        guard case .corruptPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testTargetCopyOfUnwrittenDataIsCorrupt() async throws {
        var builder = BPSBuilder(source: [])
        builder.targetRead([1, 2, 3, 4])
        var patch = Array("BPS1".utf8) + variableLength(0) + variableLength(8) + variableLength(0)
        patch += builder.actions + variableLength(UInt64(3) << 2 | 3) + variableLength(UInt64(10) << 1)
        patch += littleEndian(crc32([])) + littleEndian(0)
        let error = await expectPatchError { _ = try await apply(appendingPatchCRC(patch), ext: "bps", to: []) }
        guard case .corruptPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testVariableLengthNumbersCarry() throws {
        let file = try write([0x00, 0x81, 0xFF, 0x80], named: "vli")
        let reader = PatchStreamReader(file: try PosixFile(readingAt: file.path), end: 4)
        XCTAssertEqual(try reader.readVariableLength(), 256)
        XCTAssertEqual(try reader.readVariableLength(), 127)
        XCTAssertEqual(try reader.readVariableLength(), 0)
    }

    func testInspectReadsTheDeclaredValues() throws {
        let builder = mixedBuilder()
        let patch = builder.patch()
        let url = try write(patch, named: "inspect.bps")
        let info = try PatchEngine.inspect(patch: url)
        XCTAssertEqual(info.format, .bps)
        XCTAssertEqual(info.sourceSize, UInt64(source.count))
        XCTAssertEqual(info.targetSize, UInt64(builder.target.count))
        XCTAssertEqual(info.sourceCRC32, crc32(source))
        XCTAssertEqual(info.targetCRC32, crc32(builder.target))
        XCTAssertEqual(info.description, "{\"title\":\"test\"}")
        XCTAssertEqual(info.patchSize, UInt64(patch.count))
    }
}
