//
//  TestPatchEncoding.swift
//  PVPatchingTests
//
//  Shared test-only helpers for encoding BPS/UPS patch binary fields.
//  Extracted to avoid duplication between BPSPatcherTests and UPSPatcherTests.
//

import Foundation

// MARK: - VLI / CRC helpers

// `encodeVLI` lives in PVPatching (PatcherUtilities) and is available via `@testable import`.

/// Write a UInt32 as 4 bytes little-endian.
func le32(_ value: UInt32) -> [UInt8] {
    [UInt8(value & 0xFF),
     UInt8((value >> 8) & 0xFF),
     UInt8((value >> 16) & 0xFF),
     UInt8((value >> 24) & 0xFF)]
}

/// CRC32 — identical to the `patchCRC32` implementation in PatcherUtilities.swift.
func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = (crc >> 1) ^ (0xEDB8_8320 * (crc & 1))
        }
    }
    return ~crc
}
