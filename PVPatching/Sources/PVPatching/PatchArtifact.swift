//
//  PatchArtifact.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-10.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Result of applying a patch to a ROM.
///
/// The artifact URL is a unique, human-readable cache file so each patch
/// variant gets its own battery-save / save-state directory name.
public struct PatchArtifact: Sendable, Equatable, Codable {
    /// Location of the patched ROM on disk.
    public var url: URL
    /// Display stem used for the output file (without extension).
    public var outputStem: String
    /// MD5 of the patched ROM bytes (uppercase hex, no spaces).
    public var patchedMD5: String
    /// SHA-256 of the patched ROM bytes (lowercase hex).
    public var patchedSHA256: String
    /// SHA-256 of the source ROM used for the cache key.
    public var sourceSHA256: String
    /// SHA-256 of the patch file used for the cache key.
    public var patchSHA256: String
    /// Detected patch format that produced this artifact.
    public var format: PatchFormat
    /// Whether the result came from an existing cache entry.
    public var wasCached: Bool
    /// CRC32 of the patched ROM bytes. nil in artifacts recorded before streaming patching.
    public var patchedCRC32: UInt32?
    /// Whether applying checked the source or the result against the patch and it matched
    /// (a BPS/UPS CRC32, a PPF block check, xdelta3 window checksums). False for IPS, and for a
    /// patch applied with the source check ignored. nil when unknown (older records).
    public var checkedAgainstSource: Bool?

    public init(
        url: URL,
        outputStem: String,
        patchedMD5: String,
        patchedSHA256: String,
        sourceSHA256: String,
        patchSHA256: String,
        format: PatchFormat,
        wasCached: Bool,
        patchedCRC32: UInt32? = nil,
        checkedAgainstSource: Bool? = nil
    ) {
        self.url = url
        self.outputStem = outputStem
        self.patchedMD5 = patchedMD5
        self.patchedSHA256 = patchedSHA256
        self.sourceSHA256 = sourceSHA256
        self.patchSHA256 = patchSHA256
        self.format = format
        self.wasCached = wasCached
        self.patchedCRC32 = patchedCRC32
        self.checkedAgainstSource = checkedAgainstSource
    }
}

/// Progress reported while applying or creating patches.
public struct PatchProgress: Sendable, Equatable {
    public var fractionCompleted: Double
    public var status: String

    public init(fractionCompleted: Double, status: String) {
        self.fractionCompleted = min(max(fractionCompleted, 0), 1)
        self.status = status
    }
}
