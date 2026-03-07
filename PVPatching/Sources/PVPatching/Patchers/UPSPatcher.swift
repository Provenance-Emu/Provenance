//
//  UPSPatcher.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  UPS (Universal Patch System) format implementation.
//  Bidirectional patching with CRC32 verification.
//
//  Format spec: https://www.romhacking.net/documents/392/
//

import Foundation

/// Applies UPS patches to ROM data with CRC32 verification.
///
/// UPS format:
/// - Header: "UPS1" (4 bytes)
/// - Input size (VLI)
/// - Output size (VLI)
/// - Patch records: relative offset (VLI) + XOR data (terminated by 0x00)
/// - Input CRC32 (4 bytes LE)
/// - Output CRC32 (4 bytes LE)
/// - Patch CRC32 (4 bytes LE)
public struct UPSPatcher: Sendable {

    public init() {}

    /// Apply a UPS patch to source data and return the patched result.
    ///
    /// - Parameters:
    ///   - patch: The raw UPS patch file data.
    ///   - source: The source ROM data to patch.
    /// - Returns: The patched ROM data.
    /// - Throws: `PatchError` on format or integrity issues.
    public func apply(patch: Data, to source: Data) throws -> Data {
        guard patch.count >= 4 else {
            throw PatchError.corruptPatchFile("UPS file too small")
        }
        guard patch[0..<4].elementsEqual("UPS1".utf8) else {
            throw PatchError.corruptPatchFile("Invalid UPS header — expected 'UPS1'")
        }

        // Verify patch CRC32
        let patchCRC = readLE32(patch, at: patch.count - 4)
        let computedPatchCRC = crc32(patch[0..<(patch.count - 4)])
        guard patchCRC == computedPatchCRC else {
            throw PatchError.crcMismatch(expected: patchCRC, actual: computedPatchCRC)
        }

        var pos = 4
        let inputSize  = readVLI(patch, pos: &pos)
        let outputSize = readVLI(patch, pos: &pos)

        // Verify source CRC32
        let sourceCRC = readLE32(patch, at: patch.count - 12)
        let computedSourceCRC = crc32(source[0..<min(inputSize, source.count)])
        guard sourceCRC == computedSourceCRC else {
            // Try reverse direction (output → input patching), as UPS is bidirectional
            let outputCRC = readLE32(patch, at: patch.count - 8)
            let computedOutputCRC = crc32(source[0..<min(outputSize, source.count)])
            guard outputCRC == computedOutputCRC else {
                throw PatchError.sourceROMMismatch
            }
            // Reverse patching: swap input/output sizes
            return try applyPatching(patch: patch, source: source,
                                     inputSize: outputSize, outputSize: inputSize, startPos: pos)
        }

        return try applyPatching(patch: patch, source: source,
                                 inputSize: inputSize, outputSize: outputSize, startPos: pos)
    }

    // MARK: - Private helpers

    private func applyPatching(patch: Data, source: Data,
                               inputSize: Int, outputSize: Int, startPos: Int) throws -> Data {
        var result = Data(count: outputSize)

        // Copy source into result (truncating or padding as needed)
        let copyLen = min(inputSize, outputSize, source.count)
        result[0..<copyLen] = source[0..<copyLen]

        var pos = startPos
        var offset = 0
        let dataEnd = patch.count - 12  // before the 3 CRC32 fields

        while pos < dataEnd {
            offset += readVLI(patch, pos: &pos)

            // XOR bytes until null terminator
            while pos < dataEnd {
                let xorByte = patch[pos]
                pos += 1
                if xorByte == 0 {
                    offset += 1
                    break
                }
                if offset < result.count {
                    result[offset] ^= xorByte
                }
                offset += 1
            }
        }

        return result
    }

    private func readVLI(_ data: Data, pos: inout Int) -> Int {
        var result = 0
        var shift = 0
        while pos < data.count {
            let byte = Int(data[pos])
            pos += 1
            result += (byte & 0x7F) << shift
            if byte & 0x80 != 0 { break }
            shift += 7
            result += 1 << shift
        }
        return result
    }

    private func readLE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) |
        UInt32(data[offset + 1]) << 8 |
        UInt32(data[offset + 2]) << 16 |
        UInt32(data[offset + 3]) << 24
    }

    private func crc32(_ data: some DataProtocol) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (0xEDB8_8320 * (crc & 1))
            }
        }
        return ~crc
    }
}
