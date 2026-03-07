//
//  ArchiveFormats.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

enum ArchiveFormats: String, CaseIterable, Sendable {
    case zip
    case sevenZip = "7z"
    case rar
    case tar
    case gzip = "gz"
    case bzip2 = "bz2"
    case xz
    case zstd = "zst"
    case lzh
    case lha

    var fileExtensions: [String] {
        switch self {
        case .zip: return ["zip"]
        case .sevenZip: return ["7z"]
        case .rar: return ["rar"]
        case .tar: return ["tar"]
        case .gzip: return ["gz", "gzip"]
        case .bzip2: return ["bz2", "bzip2"]
        case .xz: return ["xz"]
        case .zstd: return ["zst", "zstd"]
        case .lzh: return ["lzh"]
        case .lha: return ["lha"]
        }
    }

    var mimeType: String {
        switch self {
        case .zip: return "application/zip"
        case .sevenZip: return "application/x-7z-compressed"
        case .rar: return "application/x-rar-compressed"
        case .tar: return "application/x-tar"
        case .gzip: return "application/gzip"
        case .bzip2: return "application/x-bzip2"
        case .xz: return "application/x-xz"
        case .zstd: return "application/zstd"
        case .lzh: return "application/x-lzh-compressed"
        case .lha: return "application/x-lzh-compressed"
        }
    }

    /// Whether this archive format stores a CRC index readable without decompressing
    var supportsCRCIndex: Bool {
        switch self {
        case .zip, .sevenZip, .rar, .lzh, .lha: return true
        case .tar, .gzip, .bzip2, .xz, .zstd: return false
        }
    }

    static func from(fileExtension ext: String) -> ArchiveFormats? {
        let lower = ext.lowercased()
        return ArchiveFormats.allCases.first { $0.fileExtensions.contains(lower) }
    }
}
