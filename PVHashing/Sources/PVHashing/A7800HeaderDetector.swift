//
//  A7800HeaderDetector.swift
//  PVHashing
//
//  Detects and handles Atari 7800 headers for accurate MD5 hashing.
//

import Foundation
import PVLogging

/// Utility for detecting Atari 7800 headers and calculating appropriate MD5 offsets.
///
/// Atari 7800 ROMs may include a 128-byte header with a recognizable magic signature.
/// No-Intro/OpenVGDB stores hashes of the raw ROM data without this header.
///
/// Header format:
/// - Total header size: 128 bytes
/// - Magic signature: bytes at offset 1-9 (0-indexed) contain "ATARI7800" (ASCII)
///
/// Detection logic:
/// - If bytes[1..<10] == [0x41, 0x54, 0x41, 0x52, 0x49, 0x37, 0x38, 0x30, 0x30] → header present
/// - Otherwise → no header (hash from offset 0)
public enum A7800HeaderDetector {
    /// Size of the Atari 7800 header in bytes
    public static let headerSize: UInt = 128

    /// Magic bytes for the Atari 7800 header signature ("ATARI7800" starting at offset 1)
    public static let magicBytes: [UInt8] = [0x41, 0x54, 0x41, 0x52, 0x49, 0x37, 0x38, 0x30, 0x30]

    /// Detects if an Atari 7800 .a78 file has a 128-byte header.
    ///
    /// - Parameter fileURL: URL of the .a78 file
    /// - Returns: The number of bytes to skip (128 if header present, 0 if headerless),
    ///           or nil if the file cannot be accessed
    public static func detectOffset(for fileURL: URL) -> UInt? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path),
              let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            ELOG("Failed to open Atari 7800 file for header detection: \(fileURL.lastPathComponent)")
            return nil
        }
        defer { try? fileHandle.close() }

        guard let data = try? fileHandle.read(upToCount: Int(headerSize)),
              data.count >= Int(headerSize) else {
            WLOG("Atari 7800 file too small to contain header: \(fileURL.lastPathComponent)")
            return 0
        }

        return detectOffset(data: data)
    }

    /// Detects the MD5 offset based on the file data's magic bytes.
    ///
    /// - Parameter data: The file data (at least 128 bytes for header detection)
    /// - Returns: The number of bytes to skip (128 if header present, 0 if headerless)
    public static func detectOffset(data: Data) -> UInt {
        if hasA7800Header(data: data) {
            VLOG("Detected Atari 7800 header (128 bytes)")
            return headerSize
        } else {
            VLOG("No Atari 7800 header detected, treating as headerless")
            return 0
        }
    }

    /// Checks if the given data starts with the Atari 7800 header magic signature.
    ///
    /// The magic signature "ATARI7800" is located at bytes offset 1-9 (0-indexed)
    /// within the 128-byte header block.
    ///
    /// - Parameter data: The file data to inspect
    /// - Returns: true if the data contains the Atari 7800 header magic at the expected offset
    public static func hasA7800Header(data: Data) -> Bool {
        guard data.count >= 10 else { return false }
        let signatureRange = data[1..<10]
        return signatureRange.elementsEqual(magicBytes)
    }
}
