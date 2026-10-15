//
//  UPSTests.swift
//  PVPatchEngineTests
//

import XCTest
@testable import PVPatchEngine

final class UPSTests: PatchTestCase {
    private let source = FixtureData.bytes(seed: 21, count: 20_000)

    private func changedTarget() -> [UInt8] {
        var target = source
        target[0] ^= 0x55
        target.replaceSubrange(5_000..<5_300, with: FixtureData.bytes(seed: 22, count: 300))
        target[19_999] ^= 0x0F
        return target
    }

    func testForwardPatchVerifiesEveryChecksum() async throws {
        let target = changedTarget()
        let patch = UPSBuilder.patch(source: source, target: target)
        let (result, output) = try await apply(patch, ext: "ups", to: source)
        XCTAssertEqual(output, target)
        XCTAssertEqual(result.verifiedChecksums, [.patchCRC32(trailingCRC(patch)), .sourceCRC32(crc32(source)), .targetCRC32(crc32(target))])
    }

    func testPatchAppliesInReverse() async throws {
        let target = changedTarget()
        let patch = UPSBuilder.patch(source: source, target: target)
        let (result, output) = try await apply(patch, ext: "ups", to: target)
        XCTAssertEqual(output, source)
        XCTAssertTrue(result.verifiedChecksums.contains(.targetCRC32(crc32(source))))
    }

    func testGrowingPatchForwardAndBack() async throws {
        let target = source + FixtureData.bytes(seed: 23, count: 777)
        let patch = UPSBuilder.patch(source: source, target: target)
        let forward = try await apply(patch, ext: "ups", to: source)
        XCTAssertEqual(forward.output, target)
        let back = try await apply(patch, ext: "ups", to: target)
        XCTAssertEqual(back.output, source)
    }

    func testShrinkingPatchForwardAndBack() async throws {
        let target = Array(source.prefix(15_000))
        let patch = UPSBuilder.patch(source: source, target: target)
        let forward = try await apply(patch, ext: "ups", to: source)
        XCTAssertEqual(forward.output, target)
        let back = try await apply(patch, ext: "ups", to: target)
        XCTAssertEqual(back.output, source)
    }

    func testIdenticalImagesNeedNoHunks() async throws {
        let patch = UPSBuilder.patch(source: source, target: source)
        let (_, output) = try await apply(patch, ext: "ups", to: source)
        XCTAssertEqual(output, source)
    }

    func testSourceMismatch() async throws {
        let target = changedTarget()
        var wrong = source
        wrong[100] ^= 1
        let patch = UPSBuilder.patch(source: source, target: target)
        let error = await expectPatchError { _ = try await apply(patch, ext: "ups", to: wrong) }
        guard case let .sourceMismatch(expected, actual)? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertEqual(expected, crc32(source))
        XCTAssertEqual(actual, crc32(wrong))
        XCTAssertTrue(partialFiles.isEmpty)
    }

    func testIgnoreSourceChecksumAppliesAnyway() async throws {
        let target = changedTarget()
        var wrong = source
        wrong[100] ^= 1
        let patch = UPSBuilder.patch(source: source, target: target)
        let (result, output) = try await apply(patch, ext: "ups", to: wrong, options: PatchOptions(ignoreSourceChecksum: true))
        var expected = target
        expected[100] ^= 1
        XCTAssertEqual(output, expected)
        XCTAssertEqual(result.ignoredTargetMismatch, ChecksumMismatch(expected: crc32(target), actual: crc32(expected)))
    }

    func testWrongTargetChecksum() async throws {
        let target = changedTarget()
        var patch = Array(UPSBuilder.patch(source: source, target: target).dropLast(4))
        patch.replaceSubrange((patch.count - 4)..<patch.count, with: littleEndian(0x1234_5678))
        let error = await expectPatchError { _ = try await apply(appendingPatchCRC(patch), ext: "ups", to: source) }
        guard case let .targetMismatch(expected, _)? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertEqual(expected, 0x1234_5678)
    }

    func testCorruptedPatchFailsItsOwnChecksum() async throws {
        var patch = UPSBuilder.patch(source: source, target: changedTarget())
        patch[10] ^= 0x40
        let error = await expectPatchError { _ = try await apply(patch, ext: "ups", to: source) }
        guard case .corruptPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testHunkWithoutTerminatorIsTruncated() async throws {
        var body = Array("UPS1".utf8) + variableLength(4) + variableLength(4) + variableLength(0) + [0x01, 0x02]
        body += littleEndian(crc32([1, 2, 3, 4])) + littleEndian(0)
        let error = await expectPatchError { _ = try await apply(appendingPatchCRC(body), ext: "ups", to: [1, 2, 3, 4]) }
        guard case .truncatedPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testPatchShorterThanTheMinimumIsTruncated() async throws {
        let error = await expectPatchError { _ = try await apply(Array("UPS1".utf8) + [0x80], ext: "ups", to: source) }
        guard case .truncatedPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testInspectReadsTheDeclaredValues() throws {
        let target = changedTarget()
        let url = try write(UPSBuilder.patch(source: source, target: target), named: "inspect.ups")
        let info = try PatchEngine.inspect(patch: url)
        XCTAssertEqual(info.format, .ups)
        XCTAssertEqual(info.sourceSize, UInt64(source.count))
        XCTAssertEqual(info.targetSize, UInt64(target.count))
        XCTAssertEqual(info.sourceCRC32, crc32(source))
        XCTAssertEqual(info.targetCRC32, crc32(target))
    }
}
