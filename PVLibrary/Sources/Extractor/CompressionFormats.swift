//
//  CompressionFormats.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

enum CompressionFormats: String, Codable, Sendable, Equatable, Hashable {
    case lzma
    case lzma2
    case zlib
    case defalate
    case bzip
    case bzip2
}
