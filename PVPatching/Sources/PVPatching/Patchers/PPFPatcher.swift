//
//  PPFPatcher.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-24.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  PPF (PlayStation Patch Format) implementation for versions 1, 2, and 3.
//
//  Format references:
//  - PPF 1.0: header "PPF10", 50-byte description, 4-byte file size, then patch records
//  - PPF 2.0: header "PPF20", encoding byte, 50-byte description, image type, flags, then records
//  - PPF 3.0: header "PPF30", like 2.0 but with 8-byte offsets (supports larger images)
//
//  Patch record format:
//  - PPF 1/2: offset (4 bytes LE), length (1 byte), data (length bytes)
//  - PPF 3:   offset (8 bytes LE), length (1 byte), data (length bytes)
//

import Foundation

/// Applies PPF (PlayStation Patch Format) patches to ROM/disc image data.
///
/// Supports PPF versions 1.0, 2.0, and 3.0.
///
/// PPF 1.0 format:
/// - Magic: "PPF10" (5 bytes)
/// - Description: 50 bytes
/// - File size check: 4 bytes LE
/// - Records: (offset: 4 bytes LE, length: 1 byte, data: N bytes)
///
/// PPF 2.0 format:
/// - Magic: "PPF20" (5 bytes)
/// - Encoding method: 1 byte
/// - Description: 50 bytes
/// - Image type: 4 bytes
/// - Block check flag: 1 byte
/// - Undo data flag: 1 byte
/// - Dummy: 1 byte
/// - Records: (offset: 4 bytes LE, length: 1 byte, data: N bytes)
/// - Optional "@BEGIN_FILE" / "@END_FILE" block data suffix
///
/// PPF 3.0 format:
/// - Magic: "PPF30" (5 bytes)
/// - Encoding method: 1 byte
/// - Description: 50 bytes
/// - Image type: 1 byte
/// - Block check flag: 1 byte
/// - Undo data flag: 1 byte
/// - Dummy: 1 byte
/// - Records: (offset: 8 bytes LE, length: 1 byte, data: N bytes)
public struct PPFPatcher: Sendable {

    private static let magicV1 = Array("PPF10".utf8)
    private static let magicV2 = Array("PPF20".utf8)
    private static let magicV3 = Array("PPF30".utf8)

    /// Marker appended after patch records in some PPF 2/3 files indicating
    /// additional block-check data follows — we stop parsing at this point.
    private static let beginFileMarker = Array("@BEGIN_FILE".utf8)

    public init() {}

    /// Apply a PPF patch to source data and return the patched result.
    ///
    /// - Parameters:
    ///   - patch: The raw PPF patch file data.
    ///   - source: The source disc image or ROM data to patch.
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
        // Layout: magic(5) + description(50) + fileSize(4) = 59 bytes minimum header
        let headerSize = 59
        guard patch.count >= headerSize else {
            throw PatchError.corruptPatchFile("PPF 1.0 header truncated (need \(headerSize) bytes, got \(patch.count))")
        }

        // Read the 4-byte expected file size (at offset 55, after magic+description).
        // If non-zero, validate it against the source size to catch wrong-file mistakes.
        let expectedSize = Int(patch.readLE32(at: 55))
        if expectedSize != 0 && expectedSize != source.count {
            throw PatchError.sourceROMMismatch
        }

        var result = source
        var pos = headerSize  // skip magic + description + 4-byte file size

        try applyRecords4ByteOffset(patch: patch, pos: &pos, result: &result)
        return result
    }

    private func applyV2(patch: Data, to source: Data) throws -> Data {
        // Layout: magic(5) + encoding(1) + description(50) + imageType(4) +
        //         blockCheck(1) + undoData(1) + dummy(1) = 63 bytes minimum header
        let headerSize = 63
        guard patch.count >= headerSize else {
            throw PatchError.corruptPatchFile("PPF 2.0 header truncated (need \(headerSize) bytes, got \(patch.count))")
        }

        var result = source
        var pos = headerSize  // skip header fields

        try applyRecords4ByteOffset(patch: patch, pos: &pos, result: &result)
        return result
    }

    private func applyV3(patch: Data, to source: Data) throws -> Data {
        // Layout: magic(5) + encoding(1) + description(50) + imageType(1) +
        //         blockCheck(1) + undoData(1) + dummy(1) = 60 bytes minimum header
        let headerSize = 60
        guard patch.count >= headerSize else {
            throw PatchError.corruptPatchFile("PPF 3.0 header truncated (need \(headerSize) bytes, got \(patch.count))")
        }

        var result = source
        var pos = headerSize  // skip header fields

        try applyRecords8ByteOffset(patch: patch, pos: &pos, result: &result)
        return result
    }

    // MARK: - Record application

    /// Apply patch records using 4-byte (32-bit) offsets (PPF 1.0 and 2.0).
    private func applyRecords4ByteOffset(patch: Data, pos: inout Int, result: inout Data) throws {
        while pos < patch.count {
            // Check for @BEGIN_FILE marker (optional suffix block in some PPF 2 files)
            if isBeginFileMarker(patch, at: pos) { break }

            // Each record: 4-byte LE offset + 1-byte length + N bytes of data
            guard pos + 5 <= patch.count else {
                throw PatchError.corruptPatchFile("Truncated PPF record header at offset \(pos)")
            }

            let offset = Int(patch.readLE32(at: pos))
            pos += 4
            let length = Int(patch[pos])
            pos += 1

            guard length > 0 else {
                throw PatchError.corruptPatchFile("PPF record with zero-length data at file offset \(pos - 1)")
            }
            guard pos + length <= patch.count else {
                throw PatchError.corruptPatchFile("PPF record data truncated at file offset \(pos)")
            }

            let patchBytes = patch[pos..<(pos + length)]
            pos += length

            applyBytes(patchBytes, at: offset, into: &result)
        }
    }

    /// Apply patch records using 8-byte (64-bit) offsets (PPF 3.0).
    private func applyRecords8ByteOffset(patch: Data, pos: inout Int, result: inout Data) throws {
        while pos < patch.count {
            // Check for @BEGIN_FILE marker
            if isBeginFileMarker(patch, at: pos) { break }

            // Each record: 8-byte LE offset + 1-byte length + N bytes of data
            guard pos + 9 <= patch.count else {
                throw PatchError.corruptPatchFile("Truncated PPF record header at offset \(pos)")
            }

            let offset64 = patch.readLE64(at: pos)
            pos += 8
            let length = Int(patch[pos])
            pos += 1

            guard length > 0 else {
                throw PatchError.corruptPatchFile("PPF record with zero-length data at file offset \(pos - 1)")
            }
            guard pos + length <= patch.count else {
                throw PatchError.corruptPatchFile("PPF record data truncated at file offset \(pos)")
            }

            // Validate that the 64-bit offset fits in Int on this platform.
            guard offset64 <= UInt64(Int.max) else {
                throw PatchError.corruptPatchFile("PPF record offset \(offset64) is out of range for this platform")
            }

            let offset = Int(offset64)
            let patchBytes = patch[pos..<(pos + length)]
            pos += length

            // Ensure offset + patchBytes.count does not overflow Int before applying.
            let byteCount = patchBytes.count
            guard offset <= Int.max - byteCount else {
                throw PatchError.corruptPatchFile("PPF record offset + length overflows addressable range")
            }

            applyBytes(patchBytes, at: offset, into: &result)
        }
    }

    // MARK: - Helpers

    /// Write `bytes` starting at `offset` into `result`, extending if needed.
    private func applyBytes(_ bytes: Data.SubSequence, at offset: Int, into result: inout Data) {
        let end = offset + bytes.count
        if result.count < end {
            result.append(contentsOf: Data(repeating: 0, count: end - result.count))
        }
        result.replaceSubrange(offset..<end, with: bytes)
    }

    /// Returns true if the `@BEGIN_FILE` marker appears at `pos`.
    private func isBeginFileMarker(_ data: Data, at pos: Int) -> Bool {
        let markerLen = Self.beginFileMarker.count
        guard pos + markerLen <= data.count else { return false }
        return data[pos..<(pos + markerLen)].elementsEqual(Self.beginFileMarker)
    }
}
