//
//  SNESHeaderDetector.swift
//  PVHashing
//
//  Detects and handles SNES copier headers for accurate MD5 hashing.
//

import Foundation
import PVLogging

/// Utility for detecting SNES copier headers and calculating appropriate MD5 offsets.
public enum SNESHeaderDetector {
    /// Size of the SNES copier header (512 bytes)
    public static let copierHeaderSize: UInt64 = 512

    /// Size of SNES ROM banks (1024 bytes)
    public static let bankSize: UInt64 = 1024

    /// Detects if a SNES .smc file has a 512-byte copier header.
    ///
    /// SNES ROMs are composed of banks that are multiples of 1024 bytes.
    /// A 512-byte copier header (from old SNES copier hardware like Super Magicom)
    /// causes the total file size to be 512 bytes more than a multiple of 1024.
    ///
    /// Detection logic:
    /// - If (file_size - 512) % 1024 == 0 → header present (512-byte copier header)
    /// - If file_size % 1024 == 0 → no header (clean ROM)
    ///
    /// - Parameter fileURL: URL of the .smc file
    /// - Returns: The number of bytes to skip (512 if header present, 0 if clean),
    ///           or nil if the file cannot be accessed
    public static func detectOffset(for fileURL: URL) -> UInt? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0

            return detectOffset(fileSize: fileSize)
        } catch {
            ELOG("Failed to detect SNES header for \(fileURL.lastPathComponent): \(error)")
            return nil
        }
    }

    /// Detects the MD5 offset based on file size.
    ///
    /// - Parameter fileSize: Size of the SNES ROM file in bytes
    /// - Returns: The number of bytes to skip (512 if header present, 0 if clean)
    public static func detectOffset(fileSize: UInt64) -> UInt {
        /// A file with only 512 bytes is header-only and should not be treated as a valid headered ROM.
        let hasHeader = (fileSize > copierHeaderSize) &&
                        ((fileSize - copierHeaderSize) % bankSize == 0)
        let isClean = (fileSize % bankSize == 0)

        if hasHeader {
            VLOG("Detected SNES copier header (512 bytes), fileSize: \(fileSize)")
            return UInt(copierHeaderSize)
        } else if isClean {
            VLOG("SNES ROM is headerless (No-Intro), fileSize: \(fileSize)")
            return 0
        } else {
            // Ambiguous case - file size doesn't match expected patterns
            // Default to 0 (no offset) as a safe fallback
            WLOG("SNES ROM has unexpected size \(fileSize), treating as headerless")
            return 0
        }
    }

    /// Checks if a file size indicates a headered SNES ROM.
    ///
    /// - Parameter fileSize: Size of the SNES ROM file in bytes
    /// - Returns: true if the file appears to have a 512-byte copier header
    public static func hasCopierHeader(fileSize: UInt64) -> Bool {
        (fileSize > copierHeaderSize) && ((fileSize - copierHeaderSize) % bankSize == 0)
    }

    /// Checks if a file size indicates a headerless SNES ROM.
    ///
    /// - Parameter fileSize: Size of the SNES ROM file in bytes
    /// - Returns: true if the file appears to be a clean headerless ROM
    public static func isHeaderless(fileSize: UInt64) -> Bool {
        (fileSize % bankSize == 0)
    }
}
