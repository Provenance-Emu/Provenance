//
//  Data+DiscSerial.swift
//  PVHashing
//
//  Internal Data helpers shared by disc-serial plugins.
//

import Foundation

// MARK: - Little-endian integer reads

extension Data {
    /// Reads a 4-byte little-endian `UInt32` from `offset`.
    /// Returns `0` if there are not enough bytes.
    func loadLE32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return self[offset..<(offset + 4)].withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self).littleEndian
        }
    }

    /// Reads a 2-byte little-endian `UInt16` from `offset`.
    func loadLE16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return self[offset..<(offset + 2)].withUnsafeBytes {
            $0.loadUnaligned(as: UInt16.self).littleEndian
        }
    }

    /// Returns an ASCII string trimmed of whitespace from `offset` with `length`.
    /// Returns `nil` if the bytes are not valid ASCII or fall outside `count`.
    func asciiString(at offset: Int, length: Int) -> String? {
        guard offset + length <= count, length > 0 else { return nil }
        let slice = self[offset..<(offset + length)]
        return String(bytes: slice, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces)
    }
}
