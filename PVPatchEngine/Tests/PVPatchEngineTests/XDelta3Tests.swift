//
//  XDelta3Tests.swift
//  PVPatchEngineTests
//

import XCTest
@testable import PVPatchEngine

final class XDelta3Tests: PatchTestCase {
    private let source = FixtureData.xdeltaSource()
    private let target = FixtureData.xdeltaTarget()

    private func fixture(_ name: String) throws -> [UInt8] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "xdelta", subdirectory: "Fixtures"))
        return try read(url)
    }

    func testEveryFixtureReproducesTheTarget() async throws {
        for name in ["basic", "djw", "fgk", "nochecksum", "multiwindow"] {
            let (result, output) = try await apply(try fixture(name), ext: "xdelta", to: source)
            XCTAssertTrue(output == target, "\(name).xdelta did not reproduce the target")
            XCTAssertEqual(result.bytesWritten, UInt64(target.count), name)
            XCTAssertTrue(partialFiles.isEmpty)
        }
    }

    func testWindowChecksumsAreReported() async throws {
        let (basic, _) = try await apply(try fixture("basic"), ext: "xdelta", to: source)
        XCTAssertEqual(basic.verifiedChecksums, [.targetWindowAdler32(windows: 1)])
        let (multi, _) = try await apply(try fixture("multiwindow"), ext: "xdelta", to: source)
        XCTAssertEqual(multi.verifiedChecksums, [.targetWindowAdler32(windows: 6)])
        let (none, _) = try await apply(try fixture("nochecksum"), ext: "xdelta", to: source)
        XCTAssertEqual(none.verifiedChecksums, [])
    }

    func testDetectedAsXDelta3() throws {
        let url = try write(try fixture("djw"), named: "djw.xdelta")
        XCTAssertEqual(PatchEngine.detectFormat(url), .xdelta3)
    }

    func testSourceMismatchIsCaughtByTheWindowChecksum() async throws {
        var wrong = source
        wrong[100_000] ^= 0xFF
        let patch = try fixture("basic")
        let error = await expectPatchError { _ = try await apply(patch, ext: "xdelta", to: wrong) }
        guard case let .sourceMismatch(expected, actual)? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertNotEqual(expected, actual)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("output.bin").path))
        XCTAssertTrue(partialFiles.isEmpty)
    }

    func testIgnoreSourceChecksumAppliesAnyway() async throws {
        var wrong = source
        wrong[100_000] ^= 0xFF
        let (result, output) = try await apply(try fixture("basic"), ext: "xdelta", to: wrong, options: PatchOptions(ignoreSourceChecksum: true))
        XCTAssertEqual(output.count, target.count)
        XCTAssertFalse(output == target)
        XCTAssertEqual(result.verifiedChecksums, [])
    }

    func testSourceShorterThanThePatchNeedsIsASizeMismatch() async throws {
        let patch = try fixture("basic")
        let error = await expectPatchError { _ = try await apply(patch, ext: "xdelta", to: Array(source.prefix(1_000))) }
        guard case let .sourceSizeMismatch(expected, actual)? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertEqual(expected, UInt64(source.count))
        XCTAssertEqual(actual, 1_000)
    }

    func testPatchCutMidWindowIsTruncated() async throws {
        for name in ["multiwindow", "djw"] {
            let patch = try fixture(name)
            let cut = Array(patch.prefix(patch.count * 6 / 10))
            let error = await expectPatchError { _ = try await apply(cut, ext: "xdelta", to: source) }
            guard case .truncatedPatch? = error else { return XCTFail("\(name): got \(String(describing: error))") }
            XCTAssertTrue(partialFiles.isEmpty)
        }
    }

    func testPatchCutInsideTheFileHeaderIsTruncated() async throws {
        let error = await expectPatchError { _ = try await apply([0xD6, 0xC3, 0xC4], ext: "xdelta", to: source) }
        guard case .truncatedPatch? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testCorruptedPatchIsRejected() async throws {
        var patch = try fixture("basic")
        patch[patch.count / 3] ^= 0x5A
        let error = await expectPatchError { _ = try await apply(patch, ext: "xdelta", to: source) }
        switch error {
        case .sourceMismatch?, .corruptPatch?: break
        default: XCTFail("got \(String(describing: error))")
        }
        XCTAssertTrue(partialFiles.isEmpty)
    }

    func testLZMASecondaryCompressionIsReportedUpFront() async throws {
        let header: [UInt8] = [0xD6, 0xC3, 0xC4, 0x00, 0x01, 0x02]
        let error = await expectPatchError { _ = try await apply(header, ext: "xdelta", to: source) }
        guard case .unsupportedSecondaryCompression? = error else { return XCTFail("got \(String(describing: error))") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("output.bin").path))
    }

    func testUnknownSecondaryCompressorIsUnsupported() async throws {
        let error = await expectPatchError { _ = try await apply([0xD6, 0xC3, 0xC4, 0x00, 0x01, 0x7F], ext: "xdelta", to: source) }
        guard case .unsupportedSecondaryCompression? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testCustomCodeTableIsUnsupported() async throws {
        let error = await expectPatchError { _ = try await apply([0xD6, 0xC3, 0xC4, 0x00, 0x02], ext: "xdelta", to: source) }
        guard case .unsupportedFormat? = error else { return XCTFail("got \(String(describing: error))") }
    }

    func testInspectReadsTheDeclaredSizes() throws {
        let url = try write(try fixture("multiwindow"), named: "inspect.xdelta")
        let info = try PatchEngine.inspect(patch: url)
        XCTAssertEqual(info.format, .xdelta3)
        XCTAssertEqual(info.targetSize, UInt64(target.count))
        XCTAssertNil(info.sourceSize)
        XCTAssertEqual(info.minimumSourceSize, UInt64(source.count))
        XCTAssertNil(info.sourceCRC32)
    }

    func testInspectReportsTheSecondaryCompressor() throws {
        XCTAssertNil(try PatchEngine.inspect(patch: write(try fixture("basic"), named: "plain.xdelta")).secondaryCompression)
        XCTAssertEqual(try PatchEngine.inspect(patch: write(try fixture("djw"), named: "djw.xdelta")).secondaryCompression, .djw)
        XCTAssertEqual(try PatchEngine.inspect(patch: write(try fixture("fgk"), named: "fgk.xdelta")).secondaryCompression, .fgk)
    }

    func testInspectFlagsLZMAAndUnknownCompressorsAsUnsupported() throws {
        let lzma = try PatchEngine.inspect(patch: write([0xD6, 0xC3, 0xC4, 0x00, 0x01, 0x02], named: "lzma.xdelta"))
        XCTAssertEqual(lzma.secondaryCompression, .lzma)
        XCTAssertEqual(lzma.secondaryCompression?.isSupported, false)
        let unknown = try PatchEngine.inspect(patch: write([0xD6, 0xC3, 0xC4, 0x00, 0x01, 0x7F], named: "unknown.xdelta"))
        XCTAssertEqual(unknown.secondaryCompression, .unknown(0x7F))
        XCTAssertEqual(unknown.secondaryCompression?.isSupported, false)
        XCTAssertEqual(SecondaryCompression.djw.isSupported, true)
        XCTAssertEqual(SecondaryCompression.fgk.isSupported, true)
    }
}
