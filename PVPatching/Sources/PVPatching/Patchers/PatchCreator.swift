//
//  PatchCreator.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-10.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// Creates BPS or IPS/IPS32 patches from an original + modified ROM pair.
///
/// Creation never modifies either input file. Round-trip verification is applied
/// by default so a bad encoder cannot silently produce an invalid patch.
public struct PatchCreator: Sendable {

    public enum CreationFormat: String, Sendable, CaseIterable, Identifiable {
        case bps
        case ips
        case ips32

        public var id: String { rawValue }

        public var patchFormat: PatchFormat {
            switch self {
            case .bps: return .bps
            case .ips: return .ips
            case .ips32: return .ips32
            }
        }

        public var fileExtension: String {
            switch self {
            case .bps: return "bps"
            case .ips: return "ips"
            case .ips32: return "ips32"
            }
        }

        public var displayName: String {
            patchFormat.displayName
        }
    }

    public init() {}

    /// Create a patch file from `originalURL` → `modifiedURL`.
    @discardableResult
    public func create(
        originalURL: URL,
        modifiedURL: URL,
        outputURL: URL,
        format: CreationFormat,
        metadata: PatchMetadata = PatchMetadata(),
        verifyRoundTrip: Bool = true,
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) throws -> URL {
        progress?(PatchProgress(fractionCompleted: 0.05, status: "Reading ROMs…"))
        let original = try Data(contentsOf: originalURL, options: .mappedIfSafe)
        let modified = try Data(contentsOf: modifiedURL, options: .mappedIfSafe)
        guard original != modified else {
            throw PatchError.patchApplicationFailed("Original and modified ROMs are identical")
        }

        progress?(PatchProgress(fractionCompleted: 0.35, status: "Encoding \(format.displayName)…"))
        let patchData: Data
        switch format {
        case .bps:
            patchData = try createBPS(original: original, modified: modified, metadata: metadata)
        case .ips:
            patchData = try createIPS(original: original, modified: modified, isIPS32: false)
        case .ips32:
            patchData = try createIPS(original: original, modified: modified, isIPS32: true)
        }

        if verifyRoundTrip {
            progress?(PatchProgress(fractionCompleted: 0.75, status: "Verifying round-trip…"))
            let applied: Data
            switch format {
            case .bps:
                applied = try BPSPatcher().apply(patch: patchData, to: original)
            case .ips:
                applied = try IPSPatcher().apply(patch: patchData, to: original, isIPS32: false)
            case .ips32:
                applied = try IPSPatcher().apply(patch: patchData, to: original, isIPS32: true)
            }
            guard applied == modified else {
                throw PatchError.patchedROMVerificationFailed
            }
        }

        progress?(PatchProgress(fractionCompleted: 0.95, status: "Writing patch…"))
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        try patchData.write(to: outputURL, options: .atomic)
        progress?(PatchProgress(fractionCompleted: 1.0, status: "Done"))
        ILOG("PatchCreator: wrote \(format.displayName) patch to \(outputURL.lastPathComponent)")
        return outputURL
    }

    // MARK: - BPS

    private func createBPS(original: Data, modified: Data, metadata: PatchMetadata) throws -> Data {
        var body = Data()
        body.append(contentsOf: Array("BPS1".utf8))
        body.append(contentsOf: encodeVLI(original.count))
        body.append(contentsOf: encodeVLI(modified.count))

        var metaObject: [String: String] = [:]
        if let title = metadata.title { metaObject["title"] = title }
        if let author = metadata.author { metaObject["author"] = author }
        if let version = metadata.version { metaObject["version"] = version }
        if let description = metadata.description { metaObject["description"] = description }
        let metaData = (try? JSONSerialization.data(withJSONObject: metaObject, options: [])) ?? Data()
        body.append(contentsOf: encodeVLI(metaData.count))
        body.append(metaData)

        // Encode only up to the modified (target) size. Extra source bytes when the
        // target is shorter are simply ignored — never emit zero-padding TargetReads
        // past `modified.count` or BPS apply will reject the patch as corrupt.
        var index = 0
        while index < modified.count {
            if index < original.count, original[index] == modified[index] {
                var length = 0
                while index + length < original.count,
                      index + length < modified.count,
                      original[index + length] == modified[index + length] {
                    length += 1
                }
                body.append(contentsOf: encodeVLI(((length - 1) << 2) | 0)) // SourceRead
                index += length
            } else {
                var bytes = [UInt8]()
                while index + bytes.count < modified.count {
                    let i = index + bytes.count
                    let same = i < original.count && original[i] == modified[i]
                    if same { break }
                    bytes.append(modified[i])
                    // Cap TargetRead chunks to keep VLI encoding simple / bounded.
                    if bytes.count >= 1024 { break }
                }
                guard !bytes.isEmpty else { break }
                body.append(contentsOf: encodeVLI(((bytes.count - 1) << 2) | 1)) // TargetRead
                body.append(contentsOf: bytes)
                index += bytes.count
            }
        }

        var patch = body
        patch.append(contentsOf: encodeLE32(patchCRC32(original)))
        patch.append(contentsOf: encodeLE32(patchCRC32(modified)))
        patch.append(contentsOf: encodeLE32(patchCRC32(patch)))
        return patch
    }

    // MARK: - IPS

    private func createIPS(original: Data, modified: Data, isIPS32: Bool) throws -> Data {
        var patch = Data(Array("PATCH".utf8))
        let maxOffset = isIPS32 ? 0xFFFF_FFFF : 0xFF_FFFF
        // Only encode bytes that exist in the modified ROM. Shrinks are represented
        // by the optional truncation trailer after EOF (classic IPS) rather than
        // writing zero-padding records past the new end.
        var index = 0

        while index < modified.count {
            // Skip matching bytes
            while index < modified.count {
                let same = index < original.count && original[index] == modified[index]
                if !same { break }
                index += 1
            }
            guard index < modified.count else { break }
            guard index <= maxOffset else {
                throw PatchError.patchApplicationFailed("ROM too large for \(isIPS32 ? "IPS32" : "IPS") offsets")
            }

            let recordStart = index
            var bytes = [UInt8]()
            while index < modified.count {
                let same = index < original.count && original[index] == modified[index]
                if same { break }
                bytes.append(modified[index])
                index += 1
                if bytes.count >= 0xFFFF { break }
            }

            // Prefer RLE when a single byte repeats.
            if bytes.count >= 3, Set(bytes).count == 1 {
                appendIPSOffset(&patch, offset: recordStart, isIPS32: isIPS32)
                patch.append(contentsOf: [0x00, 0x00]) // length 0 => RLE
                patch.append(contentsOf: [
                    UInt8((bytes.count >> 8) & 0xFF),
                    UInt8(bytes.count & 0xFF),
                    bytes[0]
                ])
            } else {
                // Avoid writing a record whose 3-byte offset looks like "EOF".
                if !isIPS32 && recordStart == 0x454F46 {
                    throw PatchError.patchApplicationFailed("IPS cannot encode a record at offset 0x454F46 (EOF)")
                }
                appendIPSOffset(&patch, offset: recordStart, isIPS32: isIPS32)
                patch.append(contentsOf: [
                    UInt8((bytes.count >> 8) & 0xFF),
                    UInt8(bytes.count & 0xFF)
                ])
                patch.append(contentsOf: bytes)
            }
        }

        patch.append(contentsOf: Array((isIPS32 ? "EEOF" : "EOF").utf8))
        if !isIPS32, modified.count < original.count {
            // Optional truncation size after EOF.
            let size = modified.count
            patch.append(contentsOf: [
                UInt8((size >> 16) & 0xFF),
                UInt8((size >> 8) & 0xFF),
                UInt8(size & 0xFF)
            ])
        }
        return patch
    }

    private func appendIPSOffset(_ patch: inout Data, offset: Int, isIPS32: Bool) {
        if isIPS32 {
            patch.append(contentsOf: [
                UInt8((offset >> 24) & 0xFF),
                UInt8((offset >> 16) & 0xFF),
                UInt8((offset >> 8) & 0xFF),
                UInt8(offset & 0xFF)
            ])
        } else {
            patch.append(contentsOf: [
                UInt8((offset >> 16) & 0xFF),
                UInt8((offset >> 8) & 0xFF),
                UInt8(offset & 0xFF)
            ])
        }
    }
}
