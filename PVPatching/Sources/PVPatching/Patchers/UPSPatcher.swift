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
        // Minimum valid UPS: header(4) + 2×VLI-min(2) + 3×CRC32(12) = 18 bytes.
        // A file with 4..17 bytes can pass the header check but crash on
        // readLE32(patch, at: patch.count - 12) / patch.count - 8 / patch.count - 4.
        guard patch.count >= 18 else {
            throw PatchError.corruptPatchFile("UPS file too small (minimum 18 bytes)")
        }
        guard patch[0..<4].elementsEqual("UPS1".utf8) else {
            throw PatchError.corruptPatchFile("Invalid UPS header — expected 'UPS1'")
        }

        // Verify patch CRC32
        let patchCRC = patch.readLE32(at: patch.count - 4)
        let computedPatchCRC = patchCRC32(patch[0..<(patch.count - 4)])
        guard patchCRC == computedPatchCRC else {
            throw PatchError.crcMismatch(expected: patchCRC, actual: computedPatchCRC)
        }

        var pos = 4
        let inputSize  = readVLI(patch, pos: &pos)
        let outputSize = readVLI(patch, pos: &pos)

        // Verify source CRC32
        let inputCRC  = patch.readLE32(at: patch.count - 12)
        let outputCRC = patch.readLE32(at: patch.count - 8)
        let computedSourceCRC = patchCRC32(source[0..<min(inputSize, source.count)])
        guard inputCRC == computedSourceCRC else {
            // Try reverse direction (output → input patching), as UPS is bidirectional.
            // In reverse, the caller's "source" is the output ROM; we produce the input ROM.
            let computedOutputCRC = patchCRC32(source[0..<min(outputSize, source.count)])
            guard outputCRC == computedOutputCRC else {
                throw PatchError.sourceROMMismatch
            }
            // Reverse patching: swap input/output sizes.
            // The expected CRC for the produced result is the original input CRC.
            return try applyPatching(patch: patch, source: source,
                                     inputSize: outputSize, outputSize: inputSize,
                                     startPos: pos, expectedOutputCRC: inputCRC)
        }

        return try applyPatching(patch: patch, source: source,
                                 inputSize: inputSize, outputSize: outputSize,
                                 startPos: pos, expectedOutputCRC: outputCRC)
    }

    // MARK: - Private helpers

    private func applyPatching(patch: Data, source: Data,
                               inputSize: Int, outputSize: Int,
                               startPos: Int, expectedOutputCRC: UInt32) throws -> Data {
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

        // Verify output CRC32 — ensures the patched ROM matches the expected result.
        let computedOutputCRC = patchCRC32(result)
        guard expectedOutputCRC == computedOutputCRC else {
            throw PatchError.patchedROMVerificationFailed
        }

        return result
    }

}
