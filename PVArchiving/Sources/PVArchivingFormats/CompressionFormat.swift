//
//  CompressionFormat.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation

/// Raw compression methods (as opposed to archive container formats).
public enum CompressionFormat: String, CaseIterable, Sendable, Codable, Equatable, Hashable {
    case lzma
    case lzma2
    case zlib
    case deflate
    case bzip
    case bzip2
    case zstd
}
