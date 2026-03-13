//
//  UPSPatcherTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

final class UPSPatcherTests: XCTestCase {

    private let patcher = UPSPatcher()

    // MARK: - VLI / CRC helpers (self-contained, no @testable dependency)

    /// Encode an integer as a BPS/UPS variable-length integer.
    ///
    /// Encoding mirrors the `readVLI` decode algorithm used by the patchers.
    /// Single-byte form: `0x80 | value` for value ∈ 0…127.
    /// Multi-byte form:  emit `value & 0x7F`, subtract 128, shift right 7, repeat.
    private func encodeVLI(_ n: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        var value = n
        while true {
            if value <= 127 {
                bytes.append(UInt8(0x80 | value))
                break
            } else {
                bytes.append(UInt8(value & 0x7F))
                value = (value - 128) >> 7
            }
        }
        return bytes
    }

    /// Write a UInt32 as 4 bytes little-endian.
    private func le32(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF),
         UInt8((value >> 8) & 0xFF),
         UInt8((value >> 16) & 0xFF),
         UInt8((value >> 24) & 0xFF)]
    }

    /// CRC32 — identical to the `patchCRC32` implementation in PatcherUtilities.swift.
    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (0xEDB8_8320 * (crc & 1))
            }
        }
        return ~crc
    }

    // MARK: - Patch builder

    /// Build a minimal valid UPS patch that transforms `source` into `target`.
    ///
    /// The patch encodes contiguous runs of differing bytes as XOR records with
    /// relative-offset VLIs, matching the UPS specification exactly.
    private func makeUPSPatch(source: Data, target: Data) -> Data {
        let maxLen = max(source.count, target.count)

        // Collect runs of positions where source and target differ.
        struct Run { var startOffset: Int; var xorBytes: [UInt8] }
        var runs: [Run] = []
        var i = 0
        while i < maxLen {
            let s: UInt8 = i < source.count ? source[i] : 0
            let t: UInt8 = i < target.count ? target[i] : 0
            if s == t { i += 1; continue }
            // Collect consecutive differing bytes
            var xorBytes: [UInt8] = []
            while i < maxLen {
                let sb: UInt8 = i < source.count ? source[i] : 0
                let tb: UInt8 = i < target.count ? target[i] : 0
                if sb == tb { break }
                xorBytes.append(sb ^ tb)
                i += 1
            }
            runs.append(Run(startOffset: i - xorBytes.count, xorBytes: xorBytes))
        }

        // Build the patch body: header + VLI sizes + XOR records
        var body = Data("UPS1".utf8)
        body.append(contentsOf: encodeVLI(source.count))
        body.append(contentsOf: encodeVLI(target.count))

        // Encode XOR records.
        // `currentOffset` tracks the patcher's internal `offset` value after the previous record.
        // Each record adds a relative VLI to advance to the run's start, then XOR bytes + 0x00.
        var currentOffset = 0
        for run in runs {
            let relOffset = run.startOffset - currentOffset
            body.append(contentsOf: encodeVLI(relOffset))
            body.append(contentsOf: run.xorBytes)
            body.append(0x00)  // null terminator
            // After the null terminator the patcher advances offset by 1
            currentOffset = run.startOffset + run.xorBytes.count + 1
        }

        // Footer: inputCRC (count-12), outputCRC (count-8), patchCRC (count-4)
        body.append(contentsOf: le32(crc32(source)))
        body.append(contentsOf: le32(crc32(target)))
        let patchCRC = crc32(body)
        body.append(contentsOf: le32(patchCRC))
        return body
    }

    // MARK: - Minimum-size guard (pre-existing)

    func testEmptyPatchThrows() {
        XCTAssertThrowsError(try patcher.apply(patch: Data(), to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testTooSmallPatchThrows() {
        // 17 bytes: valid header + 13 trailing bytes — below the 18-byte minimum.
        var data = Data("UPS1".utf8)
        data.append(contentsOf: [UInt8](repeating: 0x00, count: 13))
        XCTAssertEqual(data.count, 17)
        XCTAssertThrowsError(try patcher.apply(patch: data, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testBadHeaderThrows() {
        var data = Data("XUPS".utf8)
        data.append(contentsOf: [UInt8](repeating: 0x00, count: 20))
        XCTAssertThrowsError(try patcher.apply(patch: data, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    // MARK: - Valid patch application

    func testApplySimplePatch() throws {
        // Change a single byte
        let source = Data([0x00, 0x01, 0x02])
        let target = Data([0x00, 0xFF, 0x02])
        let patch = makeUPSPatch(source: source, target: target)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result, target)
    }

    func testApplyIdentityPatch() throws {
        // No differing bytes → patch contains no XOR records; result equals source
        let source = Data([0x10, 0x20, 0x30, 0x40])
        let patch = makeUPSPatch(source: source, target: source)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result, source)
    }

    func testApplyAllBytesChanged() throws {
        // Every byte in the target differs from the source
        let source = Data([0x01, 0x02, 0x03])
        let target = Data([0xFE, 0xFD, 0xFC])
        let patch = makeUPSPatch(source: source, target: target)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result, target)
    }

    func testApplyMultipleDisjointRuns() throws {
        // Two separate runs of differing bytes with unchanged bytes in between
        let source = Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
        let target = Data([0xAA, 0x22, 0x33, 0x44, 0xBB, 0x66])
        let patch = makeUPSPatch(source: source, target: target)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result, target)
    }

    func testApplyPatchProducesLargerTarget() throws {
        // Output size > input size; extra bytes are initialised to 0 then XOR-patched
        let source = Data([0x01, 0x02])
        let target = Data([0x01, 0x02, 0x03, 0x04])
        let patch = makeUPSPatch(source: source, target: target)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result, target)
    }

    func testApplyPatchProducesSmallerTarget() throws {
        // Output size < input size; truncated portion is simply omitted
        let source = Data([0xAA, 0xBB, 0xCC, 0xDD])
        let target = Data([0x11, 0x22])
        let patch = makeUPSPatch(source: source, target: target)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result, target)
    }

    // MARK: - Bidirectional (reverse) patching

    func testBidirectionalReverseApply() throws {
        // UPS is bidirectional: applying a patch to the *output* ROM produces the *input* ROM.
        let input  = Data([0xAA, 0xBB, 0xCC])
        let output = Data([0x11, 0x22, 0x33])
        let patch = makeUPSPatch(source: input, target: output)

        // Forward: input → output
        let forwardResult = try patcher.apply(patch: patch, to: input)
        XCTAssertEqual(forwardResult, output, "Forward patching should produce the target")

        // Reverse: output → input
        let reverseResult = try patcher.apply(patch: patch, to: output)
        XCTAssertEqual(reverseResult, input, "Reverse patching should reproduce the source")
    }

    // MARK: - CRC mismatch errors

    func testPatchCRCMismatchThrows() {
        let source = Data([0x01, 0x02, 0x03])
        var patch = makeUPSPatch(source: source, target: Data([0xAA, 0xBB, 0xCC]))
        // Corrupt a byte in the patch body (before the CRC footer)
        patch[5] ^= 0xFF
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: source)) { error in
            guard case PatchError.crcMismatch = error else {
                return XCTFail("Expected crcMismatch, got \(error)")
            }
        }
    }

    func testSourceCRCMismatchThrows() {
        // Build valid patch for correctSource, then pass wrongSource
        let correctSource = Data([0x01, 0x02, 0x03])
        let wrongSource   = Data([0xFF, 0xFE, 0xFD])
        let patch = makeUPSPatch(source: correctSource, target: Data([0xAA, 0xBB, 0xCC]))
        // wrongSource matches neither inputCRC nor outputCRC → sourceROMMismatch
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: wrongSource)) { error in
            guard case PatchError.sourceROMMismatch = error else {
                return XCTFail("Expected sourceROMMismatch, got \(error)")
            }
        }
    }

    func testOutputCRCMismatchThrows() {
        // Corrupt the output CRC in the patch footer, then recompute patch CRC so
        // the patch-integrity check still passes — isolating the output verification failure.
        let source = Data([0x01, 0x02, 0x03])
        var patch = makeUPSPatch(source: source, target: Data([0xDE, 0xAD, 0xBE]))

        // Output CRC is at patch.count - 8 (4 bytes LE)
        let outputCRCOffset = patch.count - 8
        patch[outputCRCOffset] ^= 0xFF
        // Recompute patch CRC to cover the corrupted footer
        let newPatchCRC = crc32(patch[0..<(patch.count - 4)])
        let newBytes = le32(newPatchCRC)
        for i in 0..<4 { patch[patch.count - 4 + i] = newBytes[i] }

        XCTAssertThrowsError(try patcher.apply(patch: patch, to: source)) { error in
            guard case PatchError.patchedROMVerificationFailed = error else {
                return XCTFail("Expected patchedROMVerificationFailed, got \(error)")
            }
        }
    }

    // MARK: - Truncated patch

    /// A patch file with bytes stripped from its end is rejected.
    ///
    /// The truncated file is still ≥ 18 bytes (so the size guard passes) but its
    /// patch CRC field is now corrupt because the file content changed.
    func testTruncatedPatch() {
        let source = Data([0x00, 0x00, 0x00])
        var valid = makeUPSPatch(source: source, target: Data([0xFF, 0x00, 0x00]))
        XCTAssertGreaterThanOrEqual(valid.count, 20,
            "Precondition: the valid patch must be long enough to truncate meaningfully")
        // Drop 2 bytes — the patch CRC field is now corrupt.
        valid = valid.dropLast(2)

        XCTAssertThrowsError(try patcher.apply(patch: valid, to: source))
    }

    // MARK: - Source size mismatch

    /// A source ROM that is shorter than the patch's declared `inputSize` fails the
    /// CRC check, because the CRC is computed over `min(inputSize, source.count)` bytes
    /// and therefore differs from the stored value (computed over the full `inputSize`).
    func testSourceSizeMismatch() {
        let fullSource  = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let shortSource = Data([0x01, 0x02, 0x03])  // missing last 2 bytes

        // Build the patch against fullSource; its inputCRC covers all 5 bytes.
        let patch = makeUPSPatch(source: fullSource, target: Data([0xFE, 0xFD, 0xFC, 0xFB, 0xFA]))

        XCTAssertThrowsError(try patcher.apply(patch: patch, to: shortSource)) { error in
            guard case PatchError.sourceROMMismatch = error else {
                return XCTFail("Expected sourceROMMismatch for short source, got \(error)")
            }
        }
    }
}
