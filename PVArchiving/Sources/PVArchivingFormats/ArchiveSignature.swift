//
//  ArchiveSignature.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation

/// Detects archive format by reading magic bytes from the file header.
public struct ArchiveSignatureDetector {

    /// Detect the archive format of a file by inspecting its magic bytes.
    /// Returns `nil` if the format is unrecognized.
    public static func detect(at url: URL) -> ArchiveFormat? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let header = handle.readData(ofLength: 16)
        guard header.count >= 4 else { return nil }

        let bytes = [UInt8](header)

        // ZIP: PK\x03\x04
        if bytes[0] == 0x50, bytes[1] == 0x4B, bytes[2] == 0x03, bytes[3] == 0x04 {
            return .zip
        }
        // 7z: 7z\xBC\xAF\x27\x1C
        if header.count >= 6,
           bytes[0] == 0x37, bytes[1] == 0x7A, bytes[2] == 0xBC, bytes[3] == 0xAF,
           bytes[4] == 0x27, bytes[5] == 0x1C {
            return .sevenZip
        }
        // RAR: Rar!\x1A\x07
        if header.count >= 6,
           bytes[0] == 0x52, bytes[1] == 0x61, bytes[2] == 0x72, bytes[3] == 0x21,
           bytes[4] == 0x1A, bytes[5] == 0x07 {
            return .rar
        }
        // GZIP: \x1F\x8B
        if bytes[0] == 0x1F, bytes[1] == 0x8B {
            return .gzip
        }
        // BZip2: BZ
        if bytes[0] == 0x42, bytes[1] == 0x5A {
            return .bzip2
        }
        // XZ: \xFD7zXZ\x00
        if header.count >= 6,
           bytes[0] == 0xFD, bytes[1] == 0x37, bytes[2] == 0x7A, bytes[3] == 0x58,
           bytes[4] == 0x5A, bytes[5] == 0x00 {
            return .xz
        }
        // Zstd: \x28\xB5\x2F\xFD
        if bytes[0] == 0x28, bytes[1] == 0xB5, bytes[2] == 0x2F, bytes[3] == 0xFD {
            return .zstd
        }
        // LZH: -lh (at offset 2)
        if header.count >= 5, bytes[2] == 0x2D, bytes[3] == 0x6C, bytes[4] == 0x68 {
            return .lzh
        }
        // TAR: ustar at offset 257 — need more data
        if let tarHandle = try? FileHandle(forReadingFrom: url) {
            defer { try? tarHandle.close() }
            tarHandle.seek(toFileOffset: 257)
            let tarMagic = tarHandle.readData(ofLength: 5)
            if tarMagic == Data("ustar".utf8) {
                return .tar
            }
        }
        // XIP: xar! header
        if bytes[0] == 0x78, bytes[1] == 0x61, bytes[2] == 0x72, bytes[3] == 0x21 {
            return .xip
        }
        // LZMA: \x5D\x00\x00
        if bytes[0] == 0x5D, bytes[1] == 0x00, bytes[2] == 0x00 {
            return .lzma
        }

        return nil
    }
}
