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
}

/// Read a variable-length integer (VLI) from `data` starting at `pos`, advancing `pos`.
func readVLI(_ data: Data, pos: inout Int) -> Int {
    var result = 0
    var shift = 0
    while pos < data.count {
        let byte = Int(data[pos])
        pos += 1
        result |= (byte & 0x7F) << shift
        if byte & 0x80 != 0 { break }
        shift += 7
        result += 1 << shift
    }
    return result
}

/// Compute CRC32 over arbitrary data.
func patchCRC32(_ data: some DataProtocol) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = (crc >> 1) ^ (0xEDB8_8320 * (crc & 1))
        }
    }
    return ~crc
}
