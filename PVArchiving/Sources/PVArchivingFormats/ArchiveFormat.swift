//
//  ArchiveFormat.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation

/// Unified archive format enum consolidating all archive type definitions.
/// This is the single source of truth for archive format identification.
public enum ArchiveFormat: String, CaseIterable, Sendable, Codable, Equatable, Hashable {
    case zip
    case sevenZip = "7z"
    case rar
    case tar
    case gzip = "gz"
    case bzip2 = "bz2"
    case xz
    case zstd = "zst"
    case lzh
    case lzma
    case xip

    /// All file extensions recognized by this format (primary + alternates).
    public var fileExtensions: [String] {
        switch self {
        case .zip:     return ["zip"]
        case .sevenZip: return ["7z"]
        case .rar:     return ["rar"]
        case .tar:     return ["tar"]
        case .gzip:    return ["gz", "gzip"]
        case .bzip2:   return ["bz2", "bzip2"]
        case .xz:      return ["xz"]
        case .zstd:    return ["zst", "zstd"]
        case .lzh:     return ["lzh", "lha"]
        case .lzma:    return ["lzma"]
        case .xip:     return ["xip"]
        }
    }

    /// MIME type for this archive format.
    public var mimeType: String {
        switch self {
        case .zip:     return "application/zip"
        case .sevenZip: return "application/x-7z-compressed"
        case .rar:     return "application/x-rar-compressed"
        case .tar:     return "application/x-tar"
        case .gzip:    return "application/gzip"
        case .bzip2:   return "application/x-bzip2"
        case .xz:      return "application/x-xz"
        case .zstd:    return "application/zstd"
        case .lzh:     return "application/x-lzh-compressed"
        case .lzma:    return "application/x-lzma"
        case .xip:     return "application/x-xip"
        }
    }

    /// Whether this format stores a CRC index that can be read without
    /// full decompression. Used for fast ROM identification.
    public var supportsCRCIndex: Bool {
        switch self {
        case .zip, .sevenZip, .rar, .lzh: return true
        case .gzip, .tar, .bzip2, .xz, .zstd, .lzma, .xip: return false
        }
    }

    /// Set of all recognized archive file extensions across all formats.
    public static var allFileExtensions: Set<String> {
        Set(allCases.flatMap(\.fileExtensions))
    }

    /// Detect archive format from a file extension string.
    public static func from(fileExtension ext: String) -> ArchiveFormat? {
        let lower = ext.lowercased()
        return allCases.first { $0.fileExtensions.contains(lower) }
    }

    /// Detect archive format from a MIME type string.
    public static func from(mimeType mime: String) -> ArchiveFormat? {
        let lower = mime.lowercased()
        return allCases.first { $0.mimeType == lower }
    }

    /// Detect archive format from a file URL's path extension.
    public static func from(url: URL) -> ArchiveFormat? {
        from(fileExtension: url.pathExtension)
    }
}
