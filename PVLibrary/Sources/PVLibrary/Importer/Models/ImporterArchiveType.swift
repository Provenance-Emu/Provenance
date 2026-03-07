//
//  ImporterArchiveType.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

public enum ImporterArchiveType: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case zip
    case gzip
    case sevenZip
    case rar
    case tar
    case bzip2
    case lzh
    case xz
    case zstd

    /// Whether this archive format stores a CRC index that can be read without full decompression.
    /// Used for fast ROM identification without needing to decompress and hash the full file.
    var supportsCRCIndex: Bool {
        switch self {
        case .zip, .sevenZip, .rar, .lzh: return true
        case .gzip, .tar, .bzip2, .xz, .zstd: return false
        }
    }

    var fileExtensions: [String] {
        switch self {
        case .zip: return ["zip"]
        case .gzip: return ["gz", "gzip"]
        case .sevenZip: return ["7z"]
        case .rar: return ["rar"]
        case .tar: return ["tar"]
        case .bzip2: return ["bz2", "bzip2"]
        case .lzh: return ["lzh", "lha"]
        case .xz: return ["xz"]
        case .zstd: return ["zst", "zstd"]
        }
    }

    static func from(fileExtension ext: String) -> ImporterArchiveType? {
        let lower = ext.lowercased()
        return ImporterArchiveType.allCases.first { $0.fileExtensions.contains(lower) }
    }
}
