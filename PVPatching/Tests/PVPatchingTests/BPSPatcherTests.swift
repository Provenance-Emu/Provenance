//
//  BPSPatcherTests.swift
//  PVPatchingTests
//

import XCTest
@testable import PVPatching

final class BPSPatcherTests: XCTestCase {

    private let patcher = BPSPatcher()

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

    // MARK: - Patch builders

    /// Build a valid BPS patch that writes `target` using a single **TargetRead** action.
    ///
    /// TargetRead embeds the target bytes verbatim in the patch file, making it trivial
    /// to produce a known output without needing SourceCopy/TargetCopy offsets.
    private func makeBPSPatchTargetRead(source: Data, target: Data) -> Data {
        var body = Data("BPS1".utf8)
        body.append(contentsOf: encodeVLI(source.count))  // source size
        body.append(contentsOf: encodeVLI(target.count))  // target size
        body.append(contentsOf: encodeVLI(0))             // metadata length = 0

        if !target.isEmpty {
            // TargetRead action: command = 1, length = target.count
            // action VLI = ((length - 1) << 2) | command
            let actionValue = ((target.count - 1) << 2) | 1
            body.append(contentsOf: encodeVLI(actionValue))
            body.append(contentsOf: target)
        }

        // Footer: sourceCRC (count-12), targetCRC (count-8), patchCRC (count-4)
        body.append(contentsOf: le32(crc32(source)))
        body.append(contentsOf: le32(crc32(target)))
        let patchCRC = crc32(body)
        body.append(contentsOf: le32(patchCRC))
        return body
    }

    /// Build a valid BPS patch with caller-supplied action bytes.
    ///
    /// The three CRC32 footer fields are computed automatically.
    /// Pass `invalidatePatchCRC: true` to corrupt the trailing CRC field.
    private func buildBPSPatch(
        source: Data,
        target: Data,
        actionBytes: [UInt8],
        overrideTargetCRC: UInt32? = nil,
        invalidatePatchCRC: Bool = false
    ) -> Data {
        var body = Data("BPS1".utf8)
        body.append(contentsOf: encodeVLI(source.count))
        body.append(contentsOf: encodeVLI(target.count))
        body.append(contentsOf: encodeVLI(0))  // no metadata
        body.append(contentsOf: actionBytes)
        body.append(contentsOf: le32(crc32(source)))
        body.append(contentsOf: le32(overrideTargetCRC ?? crc32(target)))
        if invalidatePatchCRC {
            body.append(contentsOf: le32(0xFFFF_FFFF))
        } else {
            body.append(contentsOf: le32(crc32(body)))
        }
        return body
    }

    /// Build a valid BPS identity patch using a single **SourceRead** action.
    ///
    /// SourceRead copies bytes from the source into the target at the same offset,
    /// producing an unchanged output (target == source).
    private func makeBPSPatchSourceRead(source: Data) -> Data {
        var body = Data("BPS1".utf8)
        body.append(contentsOf: encodeVLI(source.count))
        body.append(contentsOf: encodeVLI(source.count))  // target same size as source
        body.append(contentsOf: encodeVLI(0))

        if !source.isEmpty {
            // SourceRead action: command = 0, length = source.count
            let actionValue = ((source.count - 1) << 2) | 0
            body.append(contentsOf: encodeVLI(actionValue))
        }

        let sourceCRC = crc32(source)
        body.append(contentsOf: le32(sourceCRC))
        body.append(contentsOf: le32(sourceCRC))  // target CRC == source CRC (identity)
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
        // 18 bytes: valid header + 14 trailing bytes — below the 19-byte minimum.
        var data = Data("BPS1".utf8)
        data.append(contentsOf: [UInt8](repeating: 0x00, count: 14))
        XCTAssertEqual(data.count, 18)
        XCTAssertThrowsError(try patcher.apply(patch: data, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    func testBadHeaderThrows() {
        var data = Data("XBPS".utf8)
        data.append(contentsOf: [UInt8](repeating: 0x00, count: 20))
        XCTAssertThrowsError(try patcher.apply(patch: data, to: Data())) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile, got \(error)")
            }
        }
    }

    // MARK: - Valid patch application

    func testApplyTargetReadPatch() throws {
        let source = Data([0x00, 0x01, 0x02])
        let target = Data([0xDE, 0xAD, 0xBE])
        let patch = makeBPSPatchTargetRead(source: source, target: target)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result, target)
    }

    func testApplySourceReadIdentityPatch() throws {
        // SourceRead: output should be identical to input
        let source = Data([0x01, 0x02, 0x03, 0x04])
        let patch = makeBPSPatchSourceRead(source: source)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result, source)
    }

    func testApplyPatchProducesLargerTarget() throws {
        // TargetRead can write a target that is larger than the source
        let source = Data([0x01, 0x02])
        let target = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let patch = makeBPSPatchTargetRead(source: source, target: target)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(result, target)
    }

    func testApplyEmptyTargetPatch() throws {
        // Degenerate patch: target size is 0, no actions needed
        let source = Data([0x01, 0x02])
        var body = Data("BPS1".utf8)
        body.append(contentsOf: encodeVLI(source.count))  // source size = 2
        body.append(contentsOf: encodeVLI(0))             // target size = 0
        body.append(contentsOf: encodeVLI(0))             // metadata length = 0
        // No actions
        body.append(contentsOf: le32(crc32(source)))
        body.append(contentsOf: le32(crc32(Data())))      // CRC of empty target = 0x00000000
        let patchCRC = crc32(body)
        body.append(contentsOf: le32(patchCRC))

        let result = try patcher.apply(patch: body, to: source)
        XCTAssertEqual(result, Data())
    }

    func testApplyPatchWithSingleByteTarget() throws {
        let source = Data([0xFF])
        let target = Data([0x42])
        let patch = makeBPSPatchTargetRead(source: source, target: target)
        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), [0x42])
    }

    // MARK: - CRC mismatch errors

    func testPatchCRCMismatchThrows() {
        let source = Data([0x01, 0x02, 0x03])
        var patch = makeBPSPatchTargetRead(source: source, target: Data([0xAA, 0xBB, 0xCC]))
        // Corrupt a byte in the patch body (before the CRC fields) to invalidate patch CRC
        patch[5] ^= 0xFF
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: source)) { error in
            guard case PatchError.crcMismatch = error else {
                return XCTFail("Expected crcMismatch, got \(error)")
            }
        }
    }

    func testSourceCRCMismatchThrows() {
        // Build a valid patch for correctSource, then apply it with wrongSource
        let correctSource = Data([0x01, 0x02, 0x03])
        let wrongSource   = Data([0xFF, 0xFE, 0xFD])
        let patch = makeBPSPatchTargetRead(source: correctSource, target: Data([0xAA, 0xBB, 0xCC]))
        XCTAssertThrowsError(try patcher.apply(patch: patch, to: wrongSource)) { error in
            guard case PatchError.sourceROMMismatch = error else {
                return XCTFail("Expected sourceROMMismatch, got \(error)")
            }
        }
    }

    func testTargetCRCMismatchThrows() {
        let source = Data([0x01, 0x02, 0x03])
        var patch = makeBPSPatchTargetRead(source: source, target: Data([0xDE, 0xAD, 0xBE]))

        // Corrupt the target CRC (at patch.count - 8) and recompute the patch CRC
        // so that the patch-integrity check still passes — isolating the target CRC failure.
        let targetCRCOffset = patch.count - 8
        patch[targetCRCOffset] ^= 0xFF
        let newPatchCRC = crc32(patch[0..<(patch.count - 4)])
        let newCRCBytes = le32(newPatchCRC)
        for i in 0..<4 { patch[patch.count - 4 + i] = newCRCBytes[i] }

        XCTAssertThrowsError(try patcher.apply(patch: patch, to: source)) { error in
            guard case PatchError.patchedROMVerificationFailed = error else {
                return XCTFail("Expected patchedROMVerificationFailed, got \(error)")
            }
        }
    }

    // MARK: - SourceCopy

    /// SourceCopy copies non-contiguous bytes from the source using a relative signed offset.
    ///
    /// This test uses two SourceCopy actions to rearrange source bytes:
    ///   source[2..4] → target[0..2], source[0..1] → target[3..4]
    func testSourceCopy() throws {
        let source = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        let target = Data([0x02, 0x03, 0x04, 0x00, 0x01])

        // Action 1 — SourceCopy 3 bytes, advance sourceRelOffset from 0 to +2:
        //   action VLI = (3-1)<<2|2 = 10 → encodeVLI(10) = [0x8A]
        //   rawOffset = 2*2 = 4 (positive delta 2, even) → [0x84]
        //   After: sourceRelOffset=2, outputOffset=3
        //
        // Action 2 — SourceCopy 2 bytes, move sourceRelOffset from 5 back to 0 (delta -5):
        //   action VLI = (2-1)<<2|2 = 6 → [0x86]
        //   rawOffset = 2*5+1 = 11 (negative delta 5, odd) → [0x8B]
        let actionBytes: [UInt8] = [0x8A, 0x84, 0x86, 0x8B]
        let patch = buildBPSPatch(source: source, target: target, actionBytes: actionBytes)

        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), Array(target))
    }

    // MARK: - TargetCopy

    /// TargetCopy replicates already-written target bytes within the output buffer.
    ///
    /// Strategy: write the first byte via TargetRead, then TargetCopy the remainder.
    func testTargetCopy() throws {
        let source = Data(repeating: 0x00, count: 8)
        let target = Data(repeating: 0xAA, count: 8)

        // TargetRead 1 byte [0xAA]:
        //   action VLI = (1-1)<<2|1 = 1 → [0x81]
        // TargetCopy 7 bytes, targetRelOffset from 0 + delta 0 = 0:
        //   action VLI = (7-1)<<2|3 = 27 → [0x9B]
        //   rawOffset = 0 (delta 0, positive) → [0x80]
        let actionBytes: [UInt8] = [0x81, 0xAA, 0x9B, 0x80]
        let patch = buildBPSPatch(source: source, target: target, actionBytes: actionBytes)

        let result = try patcher.apply(patch: patch, to: source)
        XCTAssertEqual(Array(result), Array(target))
    }

    // MARK: - TargetCopy forward-reference guard

    /// TargetCopy must not reference a target position that has not yet been written.
    ///
    /// Attempting TargetCopy at outputOffset=0 (nothing written yet) must throw
    /// `corruptPatchFile` before any output is produced.
    func testTargetCopyForwardReferenceGuard() {
        let source = Data([0xAA])
        let target = Data([0xAA])

        // TargetCopy 1 byte, targetRelOffset stays at 0 while outputOffset == 0:
        //   action VLI = (1-1)<<2|3 = 3 → [0x83]
        //   rawOffset = 0 → [0x80]
        // The guard `targetRelOffset < outputOffset` (0 < 0 == false) must fire.
        let actionBytes: [UInt8] = [0x83, 0x80]
        let patch = buildBPSPatch(source: source, target: target, actionBytes: actionBytes)

        XCTAssertThrowsError(try patcher.apply(patch: patch, to: source)) { error in
            guard case PatchError.corruptPatchFile = error else {
                return XCTFail("Expected corruptPatchFile for forward reference, got \(error)")
            }
        }
    }
}
