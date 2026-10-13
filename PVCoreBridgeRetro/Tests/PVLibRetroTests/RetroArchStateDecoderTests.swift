//
//  RetroArchStateDecoderTests.swift
//  PVLibRetroTests
//
//  Covers PVRetroArchStateDecoder: unwrapping save states written by the full
//  RetroArch runtime (Provenance 3.3.x) into the core bytes the thin wrapper
//  passes to retro_unserialize. Fixtures are built here byte by byte, following
//  rzip_stream.c and task_save.c at the RetroArch commit 3.3.1 pinned.
//

import Foundation
import Testing
import zlib
@testable import PVCoreBridgeRetro

// MARK: - Fixture builders

private enum StateFixture {
    static let rzipVersion: UInt8 = 1
    static let rastateVersion: UInt8 = 1
    static let rzipDefaultChunkSize = 131_072
    static let zlibLevel: Int32 = 6
    static let blockAlignment = 8

    static func le32(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
    }

    static func le64(_ value: UInt64) -> [UInt8] {
        (0..<8).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
    }

    /// Deterministic, mildly compressible "core data".
    static func coreBytes(_ count: Int, seed: UInt8 = 0x5A) -> [UInt8] {
        (0..<count).map { UInt8(truncatingIfNeeded: ($0 * 31) ^ Int(seed) ^ ($0 >> 7)) }
    }

    /// One RASTATE block: 4-char ID, LE32 unaligned size, payload padded to 8.
    static func block(_ id: String, _ payload: [UInt8]) -> [UInt8] {
        let idBytes = Array(id.utf8)
        precondition(idBytes.count == 4)
        let padding = (blockAlignment - payload.count % blockAlignment) % blockAlignment
        return idBytes + le32(UInt32(payload.count)) + payload + [UInt8](repeating: 0, count: padding)
    }

    static func rastate(_ blocks: [[UInt8]], version: UInt8 = rastateVersion, end: Bool = true) -> [UInt8] {
        var bytes = Array("RASTATE".utf8) + [version]
        for block in blocks { bytes += block }
        if end { bytes += block("END ", []) }
        return bytes
    }

    /// One complete zlib stream (window bits 15), as RetroArch's deflate backend writes per chunk.
    static func zlibStream(_ input: ArraySlice<UInt8>) -> [UInt8] {
        let source = Array(input)
        var destinationLength = compressBound(uLong(source.count))
        var destination = [UInt8](repeating: 0, count: Int(destinationLength))
        let status = source.withUnsafeBufferPointer { src in
            destination.withUnsafeMutableBufferPointer { dst in
                compress2(dst.baseAddress, &destinationLength, src.baseAddress, uLong(src.count), zlibLevel)
            }
        }
        precondition(status == Z_OK)
        return Array(destination.prefix(Int(destinationLength)))
    }

    static func rzipHeader(chunkSize: UInt32, totalSize: UInt64, version: UInt8 = rzipVersion) -> [UInt8] {
        Array("#RZIPv".utf8) + [version] + Array("#".utf8) + le32(chunkSize) + le64(totalSize)
    }

    static func rzip(_ payload: [UInt8], chunkSize: Int = rzipDefaultChunkSize) -> [UInt8] {
        var bytes = rzipHeader(chunkSize: UInt32(chunkSize), totalSize: UInt64(payload.count))
        var start = 0
        while start < payload.count {
            let end = min(start + chunkSize, payload.count)
            let chunk = zlibStream(payload[start..<end])
            bytes += le32(UInt32(chunk.count)) + chunk
            start = end
        }
        return bytes
    }
}

private func decode(_ bytes: [UInt8]) throws -> (Data, PVRetroArchStateFormat) {
    var format = PVRetroArchStateFormat.raw
    let data = try PVRetroArchStateDecoder.coreData(from: Data(bytes), format: &format)
    return (data, format)
}

/// Asserts that decoding fails with `code` and reports `expectedFormat`.
private func expectFailure(_ bytes: [UInt8],
                           _ code: PVRetroArchStateDecoderError.Code,
                           format expectedFormat: PVRetroArchStateFormat,
                           sourceLocation: SourceLocation = #_sourceLocation) {
    var format = PVRetroArchStateFormat.raw
    do {
        let data = try PVRetroArchStateDecoder.coreData(from: Data(bytes), format: &format)
        Issue.record("expected \(code), decoded \(data.count) bytes", sourceLocation: sourceLocation)
    } catch let error as PVRetroArchStateDecoderError {
        #expect(error.code == code, sourceLocation: sourceLocation)
    } catch {
        Issue.record("unexpected error \(error)", sourceLocation: sourceLocation)
    }
    #expect(format == expectedFormat, sourceLocation: sourceLocation)
}

// MARK: - Raw

struct RetroArchStateDecoderRawTests {

    @Test func rawCoreDataPassesThroughUnchanged() throws {
        let core = StateFixture.coreBytes(4096)
        let (data, format) = try decode(core)
        #expect(format == .raw)
        #expect(data == Data(core))
    }

    @Test func shortInputWithoutMagicIsRaw() throws {
        let (data, format) = try decode([0x01, 0x02, 0x03])
        #expect(format == .raw)
        #expect(data == Data([0x01, 0x02, 0x03]))
    }

    @Test func nearMissMagicIsRaw() throws {
        // "RASTATX" and "#RZIPv\u{1}X" are not containers.
        let notRastate = Array("RASTATX".utf8) + [1] + StateFixture.coreBytes(32)
        #expect(try decode(notRastate).1 == .raw)
        let notRzip = Array("#RZIPv".utf8) + [1] + Array("X".utf8) + StateFixture.coreBytes(32)
        #expect(try decode(notRzip).1 == .raw)
    }
}

// MARK: - RASTATE

struct RetroArchStateDecoderRASTATETests {

    @Test func memOnlyContainerYieldsUnalignedPayload() throws {
        let core = StateFixture.coreBytes(1001) // not a multiple of 8
        let (data, format) = try decode(StateFixture.rastate([StateFixture.block("MEM ", core)]))
        #expect(format == .rastate)
        #expect(data == Data(core))
    }

    @Test func replayBeforeAndCheevosAfterMEM() throws {
        // RetroArch 3.3.1 order: RPLY, MEM , ACHV, END .
        let core = StateFixture.coreBytes(777)
        let bytes = StateFixture.rastate([
            StateFixture.block("RPLY", StateFixture.coreBytes(13, seed: 1)),
            StateFixture.block("MEM ", core),
            StateFixture.block("ACHV", StateFixture.coreBytes(29, seed: 2))
        ])
        let (data, format) = try decode(bytes)
        #expect(format == .rastate)
        #expect(data == Data(core))
    }

    @Test func unknownBlocksBeforeMEMAreSkipped() throws {
        let core = StateFixture.coreBytes(64)
        let bytes = StateFixture.rastate([
            StateFixture.block("ZZZZ", StateFixture.coreBytes(5, seed: 3)),
            StateFixture.block("ACHV", StateFixture.coreBytes(16, seed: 4)),
            StateFixture.block("MEM ", core)
        ])
        #expect(try decode(bytes).0 == Data(core))
    }

    @Test func missingEndBlockIsAccepted() throws {
        let core = StateFixture.coreBytes(40)
        let bytes = StateFixture.rastate([StateFixture.block("MEM ", core)], end: false)
        #expect(try decode(bytes).0 == Data(core))
    }

    @Test func trailingZeroPaddingAfterEndIsIgnored() throws {
        let core = StateFixture.coreBytes(40)
        let bytes = StateFixture.rastate([StateFixture.block("MEM ", core)]) + [UInt8](repeating: 0, count: 24)
        #expect(try decode(bytes).0 == Data(core))
    }

    @Test func unsupportedVersionFails() {
        let bytes = StateFixture.rastate([StateFixture.block("MEM ", StateFixture.coreBytes(8))], version: 2)
        expectFailure(bytes, .unsupportedRASTATEVersion, format: .rastate)
    }

    @Test func asciiVersionOneIsNotVersionOne() {
        // The comment in task_save.c says "RASTATE1" but the byte is binary 1.
        let bytes = StateFixture.rastate([StateFixture.block("MEM ", StateFixture.coreBytes(8))], version: UInt8(ascii: "1"))
        expectFailure(bytes, .unsupportedRASTATEVersion, format: .rastate)
    }

    @Test func magicWithoutVersionByteFails() {
        expectFailure(Array("RASTATE".utf8), .truncatedRASTATEBlock, format: .rastate)
    }

    @Test func noMEMBlockFails() {
        let bytes = StateFixture.rastate([StateFixture.block("ACHV", StateFixture.coreBytes(16))])
        expectFailure(bytes, .missingMEMBlock, format: .rastate)
        expectFailure(StateFixture.rastate([]), .missingMEMBlock, format: .rastate)
    }

    @Test func emptyMEMBlockFails() {
        expectFailure(StateFixture.rastate([StateFixture.block("MEM ", [])]), .missingMEMBlock, format: .rastate)
    }

    @Test func memBlockSizePastEndFails() {
        var bytes = Array("RASTATE".utf8) + [StateFixture.rastateVersion]
        bytes += Array("MEM ".utf8) + StateFixture.le32(4096) + StateFixture.coreBytes(100)
        expectFailure(bytes, .truncatedRASTATEBlock, format: .rastate)
    }

    @Test func hugeBlockSizeBeforeMEMFails() {
        var bytes = Array("RASTATE".utf8) + [StateFixture.rastateVersion]
        bytes += Array("RPLY".utf8) + StateFixture.le32(UInt32.max) + StateFixture.coreBytes(16)
        bytes += StateFixture.block("MEM ", StateFixture.coreBytes(8))
        expectFailure(bytes, .truncatedRASTATEBlock, format: .rastate)
    }

    @Test func truncatedBlockHeaderFails() {
        // Version byte, then 5 stray bytes: no room for a block header, no MEM.
        let bytes = Array("RASTATE".utf8) + [StateFixture.rastateVersion] + Array("MEM ".utf8) + [0x10]
        expectFailure(bytes, .missingMEMBlock, format: .rastate)
    }

    @Test func everyTruncationOfAContainerFailsSafely() {
        let full = StateFixture.rastate([
            StateFixture.block("RPLY", StateFixture.coreBytes(9, seed: 7)),
            StateFixture.block("MEM ", StateFixture.coreBytes(50))
        ])
        // Cut anywhere before the MEM payload ends: must throw, never crash.
        let memPayloadEnd = 8 + 8 + 16 + 8 + 50
        for length in 7..<memPayloadEnd {
            #expect(throws: PVRetroArchStateDecoderError.self) {
                _ = try decode(Array(full.prefix(length)))
            }
        }
    }
}

// MARK: - rzip

struct RetroArchStateDecoderRZIPTests {

    @Test func rzipOfRawCoreData() throws {
        let core = StateFixture.coreBytes(10_000)
        let (data, format) = try decode(StateFixture.rzip(core))
        #expect(format == .rzipRaw)
        #expect(data == Data(core))
    }

    @Test func rzipOfRawSpanningManyChunks() throws {
        let core = StateFixture.coreBytes(10_000)
        let (data, format) = try decode(StateFixture.rzip(core, chunkSize: 1024))
        #expect(format == .rzipRaw)
        #expect(data == Data(core))
    }

    @Test func rzipOfDefaultChunkSizeMultipleChunks() throws {
        let core = StateFixture.coreBytes(StateFixture.rzipDefaultChunkSize * 2 + 123)
        #expect(try decode(StateFixture.rzip(core)).0 == Data(core))
    }

    @Test func rzipOfRASTATE() throws {
        let core = StateFixture.coreBytes(5000)
        let container = StateFixture.rastate([
            StateFixture.block("RPLY", StateFixture.coreBytes(11, seed: 5)),
            StateFixture.block("MEM ", core),
            StateFixture.block("ACHV", StateFixture.coreBytes(33, seed: 6))
        ])
        let (data, format) = try decode(StateFixture.rzip(container, chunkSize: 2048))
        #expect(format == .rzipRASTATE)
        #expect(data == Data(core))
    }

    @Test func rzipOfMalformedRASTATEFailsAsRASTATE() {
        let container = StateFixture.rastate([StateFixture.block("ACHV", StateFixture.coreBytes(16))])
        expectFailure(StateFixture.rzip(container), .missingMEMBlock, format: .rzipRASTATE)
    }

    @Test func headerShorterThanTwentyBytesFails() {
        let header = StateFixture.rzipHeader(chunkSize: 1024, totalSize: 100)
        expectFailure(Array(header.prefix(12)), .malformedRZIPHeader, format: .rzipRaw)
    }

    @Test func unsupportedVersionFails() {
        var bytes = StateFixture.rzip(StateFixture.coreBytes(100))
        bytes[6] = 2
        expectFailure(bytes, .unsupportedRZIPVersion, format: .rzipRaw)
    }

    @Test func zeroChunkSizeFails() {
        expectFailure(StateFixture.rzipHeader(chunkSize: 0, totalSize: 100), .malformedRZIPHeader, format: .rzipRaw)
    }

    @Test func zeroTotalSizeFails() {
        // RetroArch writes the total last; 0 means the write never completed.
        expectFailure(StateFixture.rzipHeader(chunkSize: 1024, totalSize: 0), .malformedRZIPHeader, format: .rzipRaw)
    }

    @Test func absurdTotalSizeIsRejectedBeforeAllocating() {
        let tooBig = PVRetroArchStateDecoder.maximumDecodedSize + 1
        expectFailure(StateFixture.rzipHeader(chunkSize: 1024, totalSize: tooBig) + StateFixture.coreBytes(64),
                      .malformedRZIPHeader, format: .rzipRaw)
        expectFailure(StateFixture.rzipHeader(chunkSize: 1024, totalSize: UInt64.max),
                      .malformedRZIPHeader, format: .rzipRaw)
    }

    @Test func impossibleCompressionRatioIsRejected() {
        // 100 MiB claimed from a handful of bytes.
        let bytes = StateFixture.rzipHeader(chunkSize: 131_072, totalSize: 100 * 1024 * 1024) + StateFixture.le32(4) + [1, 2, 3, 4]
        expectFailure(bytes, .malformedRZIPHeader, format: .rzipRaw)
    }

    @Test func missingChunksFail() {
        let core = StateFixture.coreBytes(4000)
        let full = StateFixture.rzip(core, chunkSize: 1000)
        // Header only.
        expectFailure(Array(full.prefix(20)), .truncatedRZIPChunk, format: .rzipRaw)
        // Header plus a partial chunk-size field.
        expectFailure(Array(full.prefix(22)), .truncatedRZIPChunk, format: .rzipRaw)
    }

    @Test func chunkSizePastEndFails() {
        let bytes = StateFixture.rzipHeader(chunkSize: 1024, totalSize: 100) + StateFixture.le32(500) + StateFixture.coreBytes(10)
        expectFailure(bytes, .truncatedRZIPChunk, format: .rzipRaw)
    }

    @Test func zeroCompressedChunkSizeFails() {
        let bytes = StateFixture.rzipHeader(chunkSize: 1024, totalSize: 100) + StateFixture.le32(0) + StateFixture.coreBytes(10)
        expectFailure(bytes, .truncatedRZIPChunk, format: .rzipRaw)
    }

    @Test func garbageChunkFailsInflate() {
        let garbage: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x11, 0x22, 0x33]
        let bytes = StateFixture.rzipHeader(chunkSize: 1024, totalSize: 100) + StateFixture.le32(UInt32(garbage.count)) + garbage
        expectFailure(bytes, .rzipInflateFailed, format: .rzipRaw)
    }

    @Test func declaredSizeSmallerThanDataFails() {
        let core = StateFixture.coreBytes(1000)
        var bytes = StateFixture.rzip(core, chunkSize: 1024)
        bytes.replaceSubrange(12..<20, with: StateFixture.le64(500))
        expectFailure(bytes, .rzipInflateFailed, format: .rzipRaw)
    }

    @Test func declaredSizeLargerThanDataFails() {
        let core = StateFixture.coreBytes(1000)
        var bytes = StateFixture.rzip(core, chunkSize: 1024)
        bytes.replaceSubrange(12..<20, with: StateFixture.le64(1500))
        expectFailure(bytes, .truncatedRZIPChunk, format: .rzipRaw)
    }

    @Test func chunkLargerThanChunkSizeFails() {
        // RetroArch's reader holds at most chunk + chunk/4 bytes per chunk.
        let core = StateFixture.coreBytes(1000)
        var bytes = StateFixture.rzip(core, chunkSize: 1024)
        bytes.replaceSubrange(8..<12, with: StateFixture.le32(100))
        expectFailure(bytes, .rzipInflateFailed, format: .rzipRaw)
    }

    @Test func truncatedChunkPayloadFails() {
        let full = StateFixture.rzip(StateFixture.coreBytes(3000), chunkSize: 1024)
        for cut in [1, 2, 7, 40] {
            #expect(throws: PVRetroArchStateDecoderError.self) {
                _ = try decode(Array(full.dropLast(cut)))
            }
        }
    }

    @Test func trailingBytesAfterDeclaredSizeAreIgnored() throws {
        let core = StateFixture.coreBytes(500)
        let bytes = StateFixture.rzip(core) + [0xFF, 0xFF, 0xFF]
        #expect(try decode(bytes).0 == Data(core))
    }
}
