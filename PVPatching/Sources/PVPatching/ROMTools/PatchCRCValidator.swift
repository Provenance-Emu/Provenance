//
//  PatchCRCValidator.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Result of comparing a ROM against a patch’s embedded source CRC.
public enum PatchCRCValidation: Sendable, Equatable {
    case matched(expected: UInt32, actual: UInt32)
    case mismatched(expected: UInt32, actual: UInt32)
    /// Patch format does not embed a source CRC (e.g. classic IPS).
    case unavailable

    public var isMismatch: Bool {
        if case .mismatched = self { return true }
        return false
    }

    public var userMessage: String {
        switch self {
        case .matched(let expected, _):
            return String(format: "ROM CRC matches patch target (0x%08X).", expected)
        case .mismatched(let expected, let actual):
            return String(
                format: "Warning: ROM CRC 0x%08X does not match patch target 0x%08X.",
                actual,
                expected
            )
        case .unavailable:
            return "Patch does not embed a source CRC — cannot verify ROM match."
        }
    }
}

/// CRC helpers for the Patch Applier UI and batch matcher.
public enum PatchCRCValidator: Sendable {

    public static func crc32(of data: Data) -> UInt32 {
        patchCRC32(data)
    }

    /// CRC32 of a file, read in chunks (disc images are never loaded whole).
    public static func crc32(ofFileAt url: URL) throws -> UInt32 {
        try FileDigest.compute(url, kinds: .crc32).crc32 ?? 0
    }

    public static func validate(romURL: URL, inspection: PatchInspection) throws -> PatchCRCValidation {
        guard let expected = inspection.sourceCRC32 else {
            return .unavailable
        }
        let actual = try crc32(ofFileAt: romURL)
        return actual == expected
            ? .matched(expected: expected, actual: actual)
            : .mismatched(expected: expected, actual: actual)
    }

    public static func validate(romCRC: UInt32?, inspection: PatchInspection) -> PatchCRCValidation {
        guard let expected = inspection.sourceCRC32 else {
            return .unavailable
        }
        guard let actual = romCRC else {
            return .unavailable
        }
        return actual == expected
            ? .matched(expected: expected, actual: actual)
            : .mismatched(expected: expected, actual: actual)
    }
}
