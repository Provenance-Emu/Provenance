/// DSU protocol CRC32 utilities using the CRC-32/ISO-HDLC (zlib) algorithm.
///
/// The DSU/CemuHook protocol stores a CRC32 checksum at bytes 8-11 of every
/// packet header. The checksum is computed over the entire buffer with those
/// four bytes set to zero.
///
/// The CRC-32 table is computed at module-init time using the standard
/// 0xEDB88320 reflected polynomial — identical to zlib's `crc32()`.

import Foundation

// MARK: - CRC-32 table (reflected polynomial 0xEDB88320, same as zlib)

private let crc32Table: [UInt32] = {
    (0..<256).map { i -> UInt32 in
        var crc = UInt32(i)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xEDB88320
            } else {
                crc >>= 1
            }
        }
        return crc
    }
}()

public enum DSUCRC32: Sendable {

    // MARK: - Public API

    /// Compute CRC32 over arbitrary data using the zlib (CRC-32/ISO-HDLC) algorithm.
    ///
    /// - Parameter data: The bytes to checksum.
    /// - Returns: A 32-bit CRC value.
    public static func compute(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crc32Table[index]
        }
        return crc ^ 0xFFFFFFFF
    }

    /// Stamp a CRC32 into a packet buffer in-place.
    ///
    /// The function:
    /// 1. Zeros bytes 8-11 (the CRC field in the DSU header).
    /// 2. Computes the CRC32 over the whole buffer.
    /// 3. Writes the result back as a little-endian UInt32 at bytes 8-11.
    ///
    /// - Parameter buffer: The packet buffer to stamp. Must be at least 12 bytes.
    public static func stamp(into buffer: inout Data) {
        guard buffer.count >= 12 else { return }

        // Zero the CRC field
        buffer[8] = 0
        buffer[9] = 0
        buffer[10] = 0
        buffer[11] = 0

        let crc = compute(buffer)

        // Write as little-endian
        buffer[8]  = UInt8(crc & 0xFF)
        buffer[9]  = UInt8((crc >> 8)  & 0xFF)
        buffer[10] = UInt8((crc >> 16) & 0xFF)
        buffer[11] = UInt8((crc >> 24) & 0xFF)
    }

    /// Verify the CRC32 of a received packet.
    ///
    /// Extracts the stored CRC from bytes 8-11, zeros those bytes, recomputes,
    /// and returns `true` if the values match.
    ///
    /// - Parameter data: The raw packet bytes. Must be at least 12 bytes.
    /// - Returns: `true` if CRC is valid.
    public static func verify(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }

        // Read stored CRC (little-endian)
        let stored = UInt32(data[8])
            | (UInt32(data[9])  << 8)
            | (UInt32(data[10]) << 16)
            | (UInt32(data[11]) << 24)

        // Build a copy with CRC field zeroed
        var copy = data
        copy[8]  = 0
        copy[9]  = 0
        copy[10] = 0
        copy[11] = 0

        let computed = compute(copy)
        return computed == stored
    }
}
