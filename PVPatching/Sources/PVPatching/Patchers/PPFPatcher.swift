//
//  PPFPatcher.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-24.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  PPF (PlayStation Patch Format) implementation for versions 1, 2, and 3.
//
//  Layouts follow the PPF3.0 specification by Icarus/Paradox (also the reference
//  for how ppf-o-matic / applyppf / DuckStation / RetroArch read v1 and v2):
//
//  Common header (all versions):
//    0x00  5   magic "PPF10" / "PPF20" / "PPF30"
//    0x05  1   version index: 0x00 = 1.0, 0x01 = 2.0, 0x02 = 3.0
//    0x06  50  description (space padded)
//
//  PPF 1.0:
//    0x38  …   records: offset (4 LE), length (1), data
//
//  PPF 2.0:
//    0x38  4   size of the original image (LE)
//    0x3C  1024 block check: bytes 0x9320…0x971F of the original image
//    0x43C …   records: offset (4 LE), length (1), data
//
//  PPF 3.0:
//    0x38  1   image type: 0x00 = BIN (block check from 0x9320), 0x01 = GI (from 0x80A0)
//    0x39  1   block check present (0/1)
//    0x3A  1   undo data present (0/1)
//    0x3B  1   dummy
//    0x3C  1024 block check (only when flagged)
//    …     …   records: offset (8 LE), length (1), data, [undo data: length bytes]
//
//  v2 and v3 may be followed by "@BEGIN_FILE_ID.DIZ" … "@END_FILE_ID.DIZ" plus a
//  length word. Parsing stops at that marker.
//

import Foundation

/// Applies PPF (PlayStation Patch Format) patches to disc image data.
public struct PPFPatcher: Sendable {

    private static let magicV1 = Array("PPF10".utf8)
    private static let magicV2 = Array("PPF20".utf8)
    private static let magicV3 = Array("PPF30".utf8)

    /// Optional trailer that follows the records in v2/v3 files.
    private static let beginFileMarker = Array("@BEGIN_FILE_ID.DIZ".utf8)

    /// Offsets in the header shared by every version.
    static let versionByteOffset = 5
    static let descriptionOffset = 6
    static let descriptionLength = 50
    /// First byte after the common header (0x38).
    static let commonHeaderLength = 56
    static let blockCheckLength = 1024

    /// Where the 1024-byte block check is sampled from in the original image.
    static let binBlockCheckOffset = 0x9320
    static let giBlockCheckOffset = 0x80A0

    public init() {}

    /// Apply a PPF patch to source data and return the patched result.
    ///
    /// - Parameters:
    ///   - patch: The raw PPF patch file data.
    ///   - source: The source disc image data to patch.
    /// - Returns: The patched data.
    /// - Throws: `PatchError` on format or integrity issues.
    public func apply(patch: Data, to source: Data) throws -> Data {
        guard patch.count >= 5 else {
            throw PatchError.corruptPatchFile("PPF file too small to contain header")
        }

        let magic = Array(patch[0..<5])

        if magic == Self.magicV1 {
            return try applyV1(patch: patch, to: source)
        } else if magic == Self.magicV2 {
            return try applyV2(patch: patch, to: source)
        } else if magic == Self.magicV3 {
            return try applyV3(patch: patch, to: source)
        } else {
            // Check if it looks like a future PPF version we can't handle
            if magic[0] == UInt8(ascii: "P"),
               magic[1] == UInt8(ascii: "P"),
               magic[2] == UInt8(ascii: "F") {
                let versionString = String(decoding: [magic[3], magic[4]], as: UTF8.self)
                throw PatchError.unsupportedFormat("PPF version \(versionString) is not supported (only 10, 20, 30)")
            }
            throw PatchError.corruptPatchFile("Invalid PPF magic bytes — not a PPF file")
        }
    }

    // MARK: - Version-specific parsers

    private func applyV1(patch: Data, to source: Data) throws -> Data {
        let headerSize = Self.commonHeaderLength
        guard patch.count >= headerSize else {
            throw PatchError.corruptPatchFile("PPF 1.0 header truncated (need \(headerSize) bytes, got \(patch.count))")
        }

        var result = source
        var pos = headerSize
        try applyRecords(
            patch: patch, pos: &pos, result: &result,
            offsetWidth: 4, hasUndoData: false
        )
        return result
    }

    private func applyV2(patch: Data, to source: Data) throws -> Data {
        // size(4) + block check(1024) always follow the common header in v2.
        let headerSize = Self.commonHeaderLength + 4 + Self.blockCheckLength
        guard patch.count >= headerSize else {
            throw PatchError.corruptPatchFile("PPF 2.0 header truncated (need \(headerSize) bytes, got \(patch.count))")
        }

        let expectedSize = Int(patch.readLE32(at: Self.commonHeaderLength))
        if expectedSize != 0 && expectedSize != source.count {
            throw PatchError.sourceROMMismatch
        }

        let blockStart = Self.commonHeaderLength + 4
        try verifyBlockCheck(
            patch: patch,
            at: blockStart,
            source: source,
            sourceOffset: Self.binBlockCheckOffset
        )

        var result = source
        var pos = headerSize
        try applyRecords(
            patch: patch, pos: &pos, result: &result,
            offsetWidth: 4, hasUndoData: false
        )
        return result
    }

    private func applyV3(patch: Data, to source: Data) throws -> Data {
        // imageType(1) + blockCheck(1) + undoData(1) + dummy(1) after the common header.
        let fixedHeader = Self.commonHeaderLength + 4
        guard patch.count >= fixedHeader else {
            throw PatchError.corruptPatchFile("PPF 3.0 header truncated (need \(fixedHeader) bytes, got \(patch.count))")
        }

        let imageType = patch[Self.commonHeaderLength]
        let hasBlockCheck = patch[Self.commonHeaderLength + 1] != 0
        let hasUndoData = patch[Self.commonHeaderLength + 2] != 0

        var pos = fixedHeader
        if hasBlockCheck {
            guard patch.count >= pos + Self.blockCheckLength else {
                throw PatchError.corruptPatchFile("PPF 3.0 block-check data truncated")
            }
            let sourceOffset = imageType == 1 ? Self.giBlockCheckOffset : Self.binBlockCheckOffset
            try verifyBlockCheck(patch: patch, at: pos, source: source, sourceOffset: sourceOffset)
            pos += Self.blockCheckLength
        }

        var result = source
        try applyRecords(
            patch: patch, pos: &pos, result: &result,
            offsetWidth: 8, hasUndoData: hasUndoData
        )
        return result
    }

    // MARK: - Record application

    /// Apply records starting at `pos` until the end of the patch or the FILE_ID.DIZ trailer.
    ///
    /// Records never grow the image: a write past `result.count` is rejected as corrupt,
    /// which also bounds allocation against malicious offsets.
    private func applyRecords(
        patch: Data,
        pos: inout Int,
        result: inout Data,
        offsetWidth: Int,
        hasUndoData: Bool
    ) throws {
        let maxOutputSize = result.count
        while pos < patch.count {
            if isBeginFileMarker(patch, at: pos) { break }

            guard pos + offsetWidth + 1 <= patch.count else {
                throw PatchError.corruptPatchFile("Truncated PPF record header at offset \(pos)")
            }

            let offset64: UInt64 = offsetWidth == 8
                ? patch.readLE64(at: pos)
                : UInt64(patch.readLE32(at: pos))
            pos += offsetWidth
            let length = Int(patch[pos])
            pos += 1

            guard length > 0 else {
                throw PatchError.corruptPatchFile("PPF record with zero-length data at file offset \(pos - 1)")
            }
            let payload = hasUndoData ? length * 2 : length
            guard pos + payload <= patch.count else {
                throw PatchError.corruptPatchFile("PPF record data truncated at file offset \(pos)")
            }
            guard offset64 <= UInt64(Int.max - length) else {
                throw PatchError.corruptPatchFile("PPF record offset \(offset64) is out of range")
            }
            let offset = Int(offset64)
            guard offset + length <= maxOutputSize else {
                throw PatchError.corruptPatchFile(
                    "PPF record writes beyond source image boundary (offset \(offset), length \(length), sourceSize \(maxOutputSize))"
                )
            }

            result.replaceSubrange(offset..<(offset + length), with: patch[pos..<(pos + length)])
            pos += payload // skip the undo bytes too when present
        }
    }

    // MARK: - Helpers

    /// Compare the patch's 1024-byte block check against the same window of the source.
    /// Images shorter than the window (unit tests, odd dumps) skip the check.
    private func verifyBlockCheck(patch: Data, at patchOffset: Int, source: Data, sourceOffset: Int) throws {
        let length = Self.blockCheckLength
        guard source.count >= sourceOffset + length else { return }
        let expected = patch[patchOffset..<(patchOffset + length)]
        // An all-zero block means the author skipped the check.
        guard expected.contains(where: { $0 != 0 }) else { return }
        let actual = source[sourceOffset..<(sourceOffset + length)]
        guard expected.elementsEqual(actual) else {
            throw PatchError.sourceROMMismatch
        }
    }

    /// Returns true if the `@BEGIN_FILE_ID.DIZ` marker appears at `pos`.
    private func isBeginFileMarker(_ data: Data, at pos: Int) -> Bool {
        let markerLen = Self.beginFileMarker.count
        guard pos + markerLen <= data.count else { return false }
        return data[pos..<(pos + markerLen)].elementsEqual(Self.beginFileMarker)
    }
}
