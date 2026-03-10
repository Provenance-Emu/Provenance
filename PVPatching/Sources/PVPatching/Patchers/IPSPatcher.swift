//
//  IPSPatcher.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  IPS (International Patching System) format implementation.
//  Supports both classic IPS and IPS32 (large ROM extension).
//
//  Format spec: https://zerosoft.zophar.net/ips.php
//

import Foundation

/// Applies IPS and IPS32 patches to ROM data.
///
/// IPS format:
/// - Header: "PATCH" (5 bytes)
/// - Records: offset (3 bytes BE), length (2 bytes BE), data
///   - If length == 0: RLE record — repeat count (2 bytes BE), byte value (1 byte)
/// - EOF marker: "EOF" (3 bytes)
///
/// IPS32 format extends offsets to 4 bytes BE.
public struct IPSPatcher: Sendable {

    private static let header = Array("PATCH".utf8)
    private static let eof    = Array("EOF".utf8)
    private static let eof32  = Array("EEOF".utf8)

    public init() {}

    /// Determine if a patch file uses IPS32 format based on its file extension.
    ///
    /// IPS32 detection MUST be done by examining the file extension (`.ips32`), NOT by
    /// scanning the patch body for the "EEOF" byte sequence. Scanning the entire file for
    /// "EEOF" is unreliable because the bytes `0x45 0x45 0x4F 0x46` can legitimately appear
    /// inside a record's data payload in a standard IPS patch, causing false positives.
    ///
    /// - Parameter url: The patch file URL.
    /// - Returns: `true` if the extension is `ips32` (case-insensitive).
    public static func isIPS32Format(url: URL) -> Bool {
        url.pathExtension.lowercased() == "ips32"
    }

    /// Apply an IPS patch to source data and return the patched result.
    ///
    /// - Parameters:
    ///   - patch: The raw IPS patch file data.
    ///   - source: The source ROM data to patch.
    ///   - isIPS32: `true` for IPS32 (large ROM) patches that use 4-byte offsets.
    ///              **Must be determined from the file extension** (`.ips32`), never by
    ///              scanning the patch body for the "EEOF" byte sequence — see `isIPS32Format(url:)`.
    /// - Returns: The patched ROM data.
    /// - Throws: `PatchError` on format or integrity issues.
    public func apply(patch: Data, to source: Data, isIPS32: Bool = false) throws -> Data {
        var result = source

        var pos = 0

        // Validate header
        guard patch.count >= 5 else {
            throw PatchError.corruptPatchFile("File too small to contain IPS header")
        }
        let headerBytes = Array(patch[0..<5])
        guard headerBytes == Self.header else {
            throw PatchError.corruptPatchFile("Invalid IPS header")
        }
        pos = 5

        let offsetSize = isIPS32 ? 4 : 3
        let eofMarker = isIPS32 ? Self.eof32 : Self.eof

        while pos < patch.count {
            // Check for EOF marker
            let markerSize = eofMarker.count
            if pos + markerSize <= patch.count {
                let candidate = Array(patch[pos..<(pos + markerSize)])
                if candidate == eofMarker { break }
            }

            guard pos + offsetSize + 2 <= patch.count else {
                throw PatchError.corruptPatchFile("Unexpected end of patch data")
            }

            // Read offset
            let offset: Int
            if isIPS32 {
                offset = readBE32(patch, at: pos)
                pos += 4
            } else {
                offset = readBE24(patch, at: pos)
                pos += 3
            }

            // Read length
            let length = readBE16(patch, at: pos)
            pos += 2

            if length == 0 {
                // RLE record
                guard pos + 3 <= patch.count else {
                    throw PatchError.corruptPatchFile("Truncated RLE record")
                }
                let rleCount = readBE16(patch, at: pos)
                pos += 2
                let rleByte = patch[pos]
                pos += 1

                let needed = offset + rleCount
                if result.count < needed {
                    result.append(contentsOf: Data(repeating: 0, count: needed - result.count))
                }
                result.replaceSubrange(offset..<(offset + rleCount), with: Data(repeating: rleByte, count: rleCount))
            } else {
                // Standard record
                guard pos + length <= patch.count else {
                    throw PatchError.corruptPatchFile("Truncated patch data record")
                }
                let patchData = patch[pos..<(pos + length)]
                pos += length

                let needed = offset + length
                if result.count < needed {
                    result.append(contentsOf: Data(repeating: 0, count: needed - result.count))
                }
                result.replaceSubrange(offset..<(offset + length), with: patchData)
            }
        }

        // IPS patches may encode a truncation size after the EOF marker
        // (some tools write 3 bytes after "EOF" indicating target size)
        let eofEnd = pos + eofMarker.count
        if !isIPS32 && eofEnd + 3 <= patch.count {
            let truncSize = readBE24(patch, at: eofEnd)
            if truncSize > 0 && truncSize < result.count {
                result = result[0..<truncSize]
            }
        }

        return result
    }

    // MARK: - Private helpers

    private func readBE24(_ data: Data, at offset: Int) -> Int {
        Int(data[offset]) << 16 | Int(data[offset + 1]) << 8 | Int(data[offset + 2])
    }

    private func readBE32(_ data: Data, at offset: Int) -> Int {
        Int(data[offset]) << 24 | Int(data[offset + 1]) << 16 |
        Int(data[offset + 2]) << 8 | Int(data[offset + 3])
    }

    private func readBE16(_ data: Data, at offset: Int) -> Int {
        Int(data[offset]) << 8 | Int(data[offset + 1])
    }
}
