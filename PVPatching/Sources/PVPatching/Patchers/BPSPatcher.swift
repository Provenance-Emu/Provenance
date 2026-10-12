//
//  BPSPatcher.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  BPS (Beat Patch System) format implementation.
//  Includes CRC32 verification for source, target, and patch.
//
//  Format spec: https://www.romhacking.net/documents/746/
//

import Foundation

/// Applies BPS patches to ROM data with full CRC32 verification.
///
/// BPS format:
/// - Header: "BPS1" (4 bytes)
/// - Source size (VLI)
/// - Target size (VLI)
/// - Metadata length (VLI) + metadata (JSON string)
/// - Actions (variable):
///   - SourceRead, TargetRead, SourceCopy, TargetCopy — each VLI-encoded
/// - Source CRC32 (4 bytes LE)
/// - Target CRC32 (4 bytes LE)
/// - Patch CRC32 (4 bytes LE) — checksum of entire patch file excluding last 4 bytes
public struct BPSPatcher: Sendable {

    /// Upper bound on a target image. Keeps a corrupt or hostile size field from
    /// allocating terabytes; real BPS targets are well under this.
    static let maxTargetSize = 4 * 1024 * 1024 * 1024

    public init() {}

    /// Apply a BPS patch to source data and return the patched result.
    ///
    /// - Parameters:
    ///   - patch: The raw BPS patch file data.
    ///   - source: The source ROM data to patch.
    /// - Returns: The patched ROM data.
    /// - Throws: `PatchError` on format or integrity issues.
    public func apply(patch: Data, to source: Data) throws -> Data {
        // Minimum valid BPS: header(4) + 3×VLI-min(3) + 3×CRC32(12) = 19 bytes.
        // A file with 4..18 bytes can pass the header check but crash on
        // readLE32(patch, at: patch.count - 12) / patch.count - 8 / patch.count - 4.
        guard patch.count >= 19 else {
            throw PatchError.corruptPatchFile("BPS file too small (minimum 19 bytes)")
        }
        guard patch[0..<4].elementsEqual("BPS1".utf8) else {
            throw PatchError.corruptPatchFile("Invalid BPS header — expected 'BPS1'")
        }

        // Verify patch CRC32
        let patchCRC = patch.readLE32(at: patch.count - 4)
        let computedPatchCRC = patchCRC32(patch[0..<(patch.count - 4)])
        guard patchCRC == computedPatchCRC else {
            throw PatchError.crcMismatch(expected: patchCRC, actual: computedPatchCRC)
        }

        var pos = 4

        let sourceSize = readVLI(patch, pos: &pos)
        let targetSize = readVLI(patch, pos: &pos)
        let metadataLength = readVLI(patch, pos: &pos)
        let actionsEnd = patch.count - 12  // before the 3 CRC32 fields
        guard sourceSize <= source.count else {
            // The patch expects a larger base image than it was given.
            throw PatchError.sourceROMMismatch
        }
        guard targetSize <= Self.maxTargetSize else {
            throw PatchError.corruptPatchFile("BPS target size \(targetSize) is implausibly large")
        }
        guard metadataLength <= actionsEnd - pos else {
            throw PatchError.corruptPatchFile("BPS metadata length overruns the patch")
        }
        pos += metadataLength  // skip metadata (BML/JSON string)

        // Verify source CRC32
        let sourceCRC = patch.readLE32(at: patch.count - 12)
        let computedSourceCRC = patchCRC32(source[0..<min(sourceSize, source.count)])
        guard sourceCRC == computedSourceCRC else {
            throw PatchError.sourceROMMismatch
        }

        var target = Data(count: targetSize)
        var sourceRelOffset = 0
        var targetRelOffset = 0
        var outputOffset = 0

        while pos < actionsEnd {
            let data = readVLI(patch, pos: &pos)
            let command = data & 3
            let length = (data >> 2) + 1
            guard length <= targetSize - outputOffset else {
                throw PatchError.corruptPatchFile("BPS action at output offset \(outputOffset) overflows the target")
            }

            switch command {
            case 0:  // SourceRead
                guard outputOffset + length <= targetSize else {
                    throw PatchError.corruptPatchFile("SourceRead overflows target buffer at offset \(outputOffset)")
                }
                for i in 0..<length {
                    let srcIdx = outputOffset + i
                    target[outputOffset + i] = srcIdx < source.count ? source[srcIdx] : 0
                }
                outputOffset += length

            case 1:  // TargetRead
                guard pos + length <= actionsEnd else {
                    throw PatchError.corruptPatchFile("Truncated TargetRead data")
                }
                guard outputOffset + length <= targetSize else {
                    throw PatchError.corruptPatchFile("TargetRead overflows target buffer at offset \(outputOffset)")
                }
                target.replaceSubrange(outputOffset..<(outputOffset + length), with: patch[pos..<(pos + length)])
                pos += length
                outputOffset += length

            case 2:  // SourceCopy
                let rawOffset = readVLI(patch, pos: &pos)
                let negative = (rawOffset & 1) != 0
                let delta = rawOffset >> 1
                sourceRelOffset = negative ? sourceRelOffset - delta : sourceRelOffset + delta
                guard outputOffset + length <= targetSize else {
                    throw PatchError.corruptPatchFile("SourceCopy overflows target buffer at offset \(outputOffset)")
                }
                guard sourceRelOffset >= 0 else {
                    throw PatchError.corruptPatchFile("SourceCopy has negative source offset")
                }
                for _ in 0..<length {
                    target[outputOffset] = sourceRelOffset < source.count ? source[sourceRelOffset] : 0
                    outputOffset += 1
                    sourceRelOffset += 1
                }

            case 3:  // TargetCopy
                let rawOffset = readVLI(patch, pos: &pos)
                let negative = (rawOffset & 1) != 0
                let delta = rawOffset >> 1
                targetRelOffset = negative ? targetRelOffset - delta : targetRelOffset + delta
                guard outputOffset + length <= targetSize else {
                    throw PatchError.corruptPatchFile("TargetCopy overflows target buffer at offset \(outputOffset)")
                }
                guard targetRelOffset >= 0 else {
                    throw PatchError.corruptPatchFile("TargetCopy has negative source offset")
                }
                for _ in 0..<length {
                    guard targetRelOffset < outputOffset else {
                        throw PatchError.corruptPatchFile("TargetCopy source position \(targetRelOffset) references unwritten data")
                    }
                    target[outputOffset] = target[targetRelOffset]
                    outputOffset += 1
                    targetRelOffset += 1
                }

            default:
                throw PatchError.corruptPatchFile("Unknown BPS action: \(command)")
            }
        }

        // Verify target CRC32
        let targetCRC = patch.readLE32(at: patch.count - 8)
        let computedTargetCRC = patchCRC32(target)
        guard targetCRC == computedTargetCRC else {
            throw PatchError.patchedROMVerificationFailed
        }

        return target
    }
}
