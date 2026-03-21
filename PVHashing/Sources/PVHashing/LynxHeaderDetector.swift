//
//  LynxHeaderDetector.swift
//  PVHashing
//
//  Detects and handles Atari Lynx headers for accurate MD5 hashing.
//

import Foundation
import PVLogging

/// Utility for detecting Atari Lynx headers and calculating appropriate MD5 offsets.
///
/// Atari Lynx ROMs may include a 64-byte header with a recognizable magic signature.
/// No-Intro/OpenVGDB stores hashes of the raw ROM data without this header.
///
/// Header format:
/// - Total header size: 64 bytes
/// - Magic signature: first 4 bytes are "LYNX" (ASCII: 0x4C 0x59 0x4E 0x58)
///
/// Detection logic:
/// - If bytes[0..<4] == [0x4C, 0x59, 0x4E, 0x58] → header present
/// - Otherwise → no header (hash from offset 0)
public enum LynxHeaderDetector {
    /// Size of the Atari Lynx header in bytes
    public static let headerSize: UInt = 64

    /// Magic bytes for the Lynx header signature ("LYNX" at offset 0)
    public static let magicBytes: [UInt8] = [0x4C, 0x59, 0x4E, 0x58]

    /// Detects if an Atari Lynx .lnx file has a 64-byte header.
    ///
    /// - Parameter fileURL: URL of the .lnx file
    /// - Returns: The number of bytes to skip (64 if header present, 0 if headerless),
    ///           or nil if the file cannot be accessed
    public static func detectOffset(for fileURL: URL) -> UInt? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path),
              let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            ELOG("Failed to open Lynx file for header detection: \(fileURL.lastPathComponent)")
            return nil
        }
        defer { try? fileHandle.close() }

        let minimumBytes = magicBytes.count
        guard let data = try? fileHandle.read(upToCount: minimumBytes) else {
            ELOG("Failed to read Lynx file for header detection: \(fileURL.lastPathComponent)")
            return nil
        }
        guard data.count >= minimumBytes else {
            WLOG("Lynx file too small to contain header: \(fileURL.lastPathComponent)")
            return 0
        }

        let detectedOffset = detectOffset(data: data)
        if detectedOffset > 0 {
            // Verify the file is large enough to contain the full header
            let fileSize = (try? fileHandle.seekToEndOfFile()) ?? 0
            guard fileSize >= UInt64(detectedOffset) else {
                WLOG("Lynx file too small for detected header (\(fileSize) bytes < \(detectedOffset)): \(fileURL.lastPathComponent)")
                return 0
            }
        }
        return detectedOffset
    }

    /// Detects the MD5 offset based on the file data's magic bytes.
    ///
    /// - Parameter data: The file data (at least 4 bytes for magic detection)
    /// - Returns: The number of bytes to skip (64 if header present, 0 if headerless)
    public static func detectOffset(data: Data) -> UInt {
        if hasLynxHeader(data: data) {
            VLOG("Detected Lynx header (64 bytes)")
            return headerSize
        } else {
            VLOG("No Lynx header detected, treating as headerless")
            return 0
        }
    }

    /// Checks if the given data starts with the Atari Lynx header magic signature.
    ///
    /// The magic signature "LYNX" is located at the very start of the file (bytes 0-3).
    ///
    /// - Parameter data: The file data to inspect
    /// - Returns: true if the data begins with the Lynx header magic bytes
    public static func hasLynxHeader(data: Data) -> Bool {
        guard data.count >= magicBytes.count else { return false }
        let signatureRange = data[0..<magicBytes.count]
        return signatureRange.elementsEqual(magicBytes)
    }
}
