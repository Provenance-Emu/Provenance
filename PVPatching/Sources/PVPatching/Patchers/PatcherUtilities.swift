//
//  PatcherUtilities.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-10.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Internal utilities shared by BPS/UPS/IPS patchers.
//

import Foundation

extension Data {
    /// Read a 4-byte little-endian UInt32 at the given byte offset.
    func readLE32(at offset: Int) -> UInt32 {
        UInt32(self[offset]) |
        UInt32(self[offset + 1]) << 8 |
        UInt32(self[offset + 2]) << 16 |
        UInt32(self[offset + 3]) << 24
    }

    /// Read an 8-byte little-endian UInt64 at the given byte offset.
    func readLE64(at offset: Int) -> UInt64 {
        UInt64(self[offset]) |
        UInt64(self[offset + 1]) << 8 |
        UInt64(self[offset + 2]) << 16 |
        UInt64(self[offset + 3]) << 24 |
        UInt64(self[offset + 4]) << 32 |
        UInt64(self[offset + 5]) << 40 |
        UInt64(self[offset + 6]) << 48 |
        UInt64(self[offset + 7]) << 56
    }
}

/// Read a BPS/UPS variable-length integer from `data` starting at `pos`, advancing `pos`.
///
/// Reference decoder (beat): `data += (x & 0x7f) * shift; if (x & 0x80) break; shift <<= 7; data += shift`.
/// The accumulation must be an addition, not an OR: the implicit `+ shift` carry can
/// set the same bit the next group contributes (e.g. `[0x00, 0x81]` is 256, not 128).
/// Unterminated or absurdly long encodings return `Int.max` so size checks fail loudly
/// instead of trapping on shift overflow.
func readVLI(_ data: Data, pos: inout Int) -> Int {
    var result: UInt64 = 0
    var shift: UInt64 = 0
    while pos < data.count {
        let byte = UInt64(data[pos])
        pos += 1
        guard shift <= 56 else { return Int.max }
        let (added, overflow) = result.addingReportingOverflow((byte & 0x7F) << shift)
        guard !overflow else { return Int.max }
        result = added
        if byte & 0x80 != 0 {
            return result > UInt64(Int.max) ? Int.max : Int(result)
        }
        shift += 7
        let (carried, carryOverflow) = result.addingReportingOverflow(1 << shift)
        guard !carryOverflow else { return Int.max }
        result = carried
    }
    // Ran off the end without a terminator byte.
    return Int.max
}

/// CRC-32/ISO-HDLC lookup table (reflected polynomial 0xEDB88320).
private let crc32Table: [UInt32] = (0..<256).map { index -> UInt32 in
    var crc = UInt32(index)
    for _ in 0..<8 {
        crc = (crc >> 1) ^ (0xEDB8_8320 * (crc & 1))
    }
    return crc
}

/// Compute CRC32 over arbitrary data (table-driven; whole ROMs go through here).
func patchCRC32(_ data: some DataProtocol) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc = crc32Table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
    }
    return ~crc
}

/// Encode an integer as a BPS/UPS variable-length integer.
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
func encodeLE32(_ value: UInt32) -> [UInt8] {
    [
        UInt8(value & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 24) & 0xFF)
    ]
}
