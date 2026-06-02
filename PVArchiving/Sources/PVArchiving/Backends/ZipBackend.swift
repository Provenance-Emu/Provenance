//
//  ZipBackend.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation
import PVLogging
import SWCompression
#if canImport(ZipArchive)
import ZipArchive
#endif

public struct ZipBackend: ArchiveExtractorBackend, ArchiveListingBackend, ArchiveCreationBackend {
    public static let format = ArchiveFormat.zip

    public init() {}

    // MARK: - Extraction (SWCompression — no SSZipArchive dependency)

    public func extract(
        at source: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard FileManager.default.fileExists(atPath: source.path) else {
                        throw ArchiveError.extractionFailed("ZIP file does not exist: \(source.path)")
                    }
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: source.path),
                       let size = attrs[.size] as? Int64, size == 0 {
                        throw ArchiveError.extractionFailed("ZIP file is empty: \(source.lastPathComponent)")
                    }
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

                    try autoreleasepool {
                        let data = try Data(contentsOf: source)
                        let entries = try ZipContainer.open(container: data)
                        let fileEntries = entries.filter { $0.info.type != .directory }
                        let total = fileEntries.count

                        for (i, entry) in fileEntries.enumerated() {
                            try autoreleasepool {
                                // Sanitize the entry name to prevent zip-slip / path
                                // traversal: strip `..`/`.` components and reject any
                                // path that resolves outside the destination dir
                                // (mirrors RarBackend). A malicious archive could
                                // otherwise overwrite BIOS/save/config files.
                                let sanitized = entry.info.name
                                    .components(separatedBy: "/")
                                    .filter { !$0.isEmpty && $0 != ".." && $0 != "." }
                                    .joined(separator: "/")
                                guard !sanitized.isEmpty else { return }
                                let fullPath = destination.appendingPathComponent(sanitized)
                                guard fullPath.path.hasPrefix(destination.path) else { return }
                                try FileManager.default.createDirectory(
                                    at: fullPath.deletingLastPathComponent(),
                                    withIntermediateDirectories: true
                                )
                                if let entryData = entry.data {
                                    try entryData.write(to: fullPath, options: [.atomic, .noFileProtection])
                                }
                                continuation.yield(fullPath)
                            }
                            progress(Double(i + 1) / Double(max(total, 1)))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Listing (SWCompression — reads central directory only)

    public func listEntries(at source: URL) throws -> [ArchiveEntryInfo] {
        let data = try Data(contentsOf: source)
        let infos = try ZipContainer.info(container: data)
        return infos.map { info in
            ArchiveEntryInfo(
                name: info.name,
                size: info.size.map { Int64($0) },
                isDirectory: info.type == .directory,
                crc: info.crc
            )
        }
    }

    // MARK: - Zip Creation (requires ZipArchive/SSZipArchive)

    public func createArchive(at destination: URL, from directory: URL) throws {
        try Self.createArchive(at: destination, from: directory)
    }

    public func createArchive(at destination: URL, withFiles paths: [String]) throws {
        try Self.createArchive(at: destination, withFiles: paths)
    }

    /// Create a ZIP archive from a directory.
    public static func createArchive(at destination: URL, from directory: URL) throws {
        #if canImport(ZipArchive)
        let success = SSZipArchive.createZipFile(
            atPath: destination.path,
            withContentsOfDirectory: directory.path
        )
        guard success else {
            throw ArchiveError.compressionFailed("Failed to create ZIP at \(destination.path)")
        }
        #else
        throw ArchiveError.backendUnavailable("ZipArchive (needed for ZIP creation)")
        #endif
    }

    /// Create a ZIP archive from specific file paths.
    public static func createArchive(at destination: URL, withFiles paths: [String]) throws {
        #if canImport(ZipArchive)
        let success = SSZipArchive.createZipFile(
            atPath: destination.path,
            withFilesAtPaths: paths
        )
        guard success else {
            throw ArchiveError.compressionFailed("Failed to create ZIP at \(destination.path)")
        }
        #else
        throw ArchiveError.backendUnavailable("ZipArchive (needed for ZIP creation)")
        #endif
    }

    /// Simple synchronous unzip using SWCompression.
    public static func unzip(at source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        try autoreleasepool {
            let data = try Data(contentsOf: source)
            let entries = try ZipContainer.open(container: data)
            for entry in entries where entry.info.type != .directory {
                try autoreleasepool {
                    let fullPath = destination.appendingPathComponent(entry.info.name)
                    try fm.createDirectory(
                        at: fullPath.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    if let entryData = entry.data {
                        try entryData.write(to: fullPath, options: [.atomic, .noFileProtection])
                    }
                }
            }
        }
    }
}
