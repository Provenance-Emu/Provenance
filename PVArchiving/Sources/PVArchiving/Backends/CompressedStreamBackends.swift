//
//  CompressedStreamBackends.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//
//  Backends for single-stream compressed formats: gzip, bzip2, xz, lzma.
//  These decompress to a single blob which may itself be a tar archive.

import Foundation
import PVLogging
import SWCompression

// MARK: - Shared helper

/// Decompress a single-stream format. If the result is a tar, extract its entries.
/// Otherwise write the decompressed data as a single file (stripping the compression extension).
func extractCompressedStream(
    _ data: Data,
    originalURL: URL,
    to destination: URL,
    yield: (URL) -> Void,
    progress: (Double) -> Void
) throws {
    if let entries = try? TarContainer.open(container: data) {
        for (i, item) in entries.enumerated() where item.info.type != .directory {
            try autoreleasepool {
                let fullPath = destination.appendingPathComponent(item.info.name)
                try FileManager.default.createDirectory(at: fullPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                if let itemData = item.data {
                    try itemData.write(to: fullPath, options: [.atomic, .noFileProtection])
                }
                yield(fullPath)
            }
            progress(Double(i + 1) / Double(entries.count))
        }
    } else {
        let name = originalURL.deletingPathExtension().lastPathComponent
        let fullPath = destination.appendingPathComponent(name)
        try data.write(to: fullPath, options: [.atomic, .noFileProtection])
        yield(fullPath)
        progress(1.0)
    }
}

// MARK: - GZip

public struct GZipBackend: ArchiveExtractorBackend {
    public static let format = ArchiveFormat.gzip
    public init() {}

    public func extract(at source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    try autoreleasepool {
                        let compressed = try Data(contentsOf: source)
                        let decompressed = try GzipArchive.unarchive(archive: compressed)
                        try extractCompressedStream(decompressed, originalURL: source, to: destination, yield: { continuation.yield($0) }, progress: progress)
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}

// MARK: - BZip2

public struct BZip2Backend: ArchiveExtractorBackend {
    public static let format = ArchiveFormat.bzip2
    public init() {}

    public func extract(at source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    try autoreleasepool {
                        let compressed = try Data(contentsOf: source)
                        let decompressed = try BZip2.decompress(data: compressed)
                        try extractCompressedStream(decompressed, originalURL: source, to: destination, yield: { continuation.yield($0) }, progress: progress)
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}

// MARK: - XZ

public struct XZBackend: ArchiveExtractorBackend {
    public static let format = ArchiveFormat.xz
    public init() {}

    public func extract(at source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    try autoreleasepool {
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: source.path),
                           let size = attrs[.size] as? Int64, size > 200_000_000 {
                            WLOG("XZ: loading \(size / 1_000_000) MB file into memory")
                        }
                        let compressed = try Data(contentsOf: source)
                        let decompressed = try XZArchive.unarchive(archive: compressed)
                        try extractCompressedStream(decompressed, originalURL: source, to: destination, yield: { continuation.yield($0) }, progress: progress)
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}

// MARK: - LZMA (standalone, not inside 7z container)

public struct LZMABackend: ArchiveExtractorBackend {
    public static let format = ArchiveFormat.lzma
    public init() {}

    public func extract(at source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    try autoreleasepool {
                        let compressed = try Data(contentsOf: source)
                        let decompressed = try LZMA.decompress(data: compressed)
                        try extractCompressedStream(decompressed, originalURL: source, to: destination, yield: { continuation.yield($0) }, progress: progress)
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}

// MARK: - Zstd (stub)

public struct ZstdBackend: ArchiveExtractorBackend {
    public static let format = ArchiveFormat.zstd
    public init() {}

    public func extract(at source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ArchiveError.formatNotSupported(.zstd))
        }
    }
}

// MARK: - XIP (stub)

public struct XIPBackend: ArchiveExtractorBackend {
    public static let format = ArchiveFormat.xip
    public init() {}

    public func extract(at source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ArchiveError.formatNotSupported(.xip))
        }
    }
}
