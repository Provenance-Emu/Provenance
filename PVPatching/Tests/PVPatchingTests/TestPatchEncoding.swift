//
//  TestPatchEncoding.swift
//  PVPatchingTests
//
//  Shared test-only helpers for encoding BPS/UPS patch binary fields.
//  Extracted to avoid duplication between BPSPatcherTests and UPSPatcherTests.
//

import Foundation

// MARK: - VLI / CRC helpers

/// Encode an integer as a BPS/UPS variable-length integer.
///
/// Encoding mirrors the `readVLI` decode algorithm used by the patchers.
/// Single-byte form: `0x80 | value` for value ∈ 0…127.
/// Multi-byte form:  emit `value & 0x7F`, subtract 128, shift right 7, repeat.
func encodeVLI(_ n: Int) -> [UInt8] {
    var bytes: [UInt8] = []
    var value = n
    while true {
        if value <= 127 {
            bytes.append(UInt8(0x80 | value))
            break
        } else {
            bytes.append(UInt8(value & 0x7F))
            value = (value - 128) >> 7
        }
    }
    return bytes
}

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
