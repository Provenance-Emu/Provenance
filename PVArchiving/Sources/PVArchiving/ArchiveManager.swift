//
//  ArchiveManager.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation
import PVLogging

/// Main public facade for archive operations.
/// Auto-detects format and delegates to the appropriate backend.
public final class ArchiveManager: Sendable {

    public static let shared = ArchiveManager()

    /// Registered backends keyed by format.
    private let backends: [ArchiveFormat: any ArchiveExtractorBackend]

    /// Backends that support listing entries without extraction.
    private let listingBackends: [ArchiveFormat: any ArchiveListingBackend]

    /// Backends that support archive creation.
    private let creationBackends: [ArchiveFormat: any ArchiveCreationBackend]

    public init() {
        let zip = ZipBackend()
        let sevenZip = SevenZipBackend()
        let rar = RarBackend()
        let tar = TarBackend()
        let gzip = GZipBackend()
        let bzip2 = BZip2Backend()
        let xz = XZBackend()
        let lzma = LZMABackend()
        let lzh = LzhBackend()
        let zstd = ZstdBackend()
        let xip = XIPBackend()

        self.backends = [
            .zip: zip,
            .sevenZip: sevenZip,
            .rar: rar,
            .tar: tar,
            .gzip: gzip,
            .bzip2: bzip2,
            .xz: xz,
            .lzma: lzma,
            .lzh: lzh,
            .zstd: zstd,
            .xip: xip,
        ]
        self.listingBackends = [
            .zip: zip,
            .sevenZip: sevenZip,
        ]
        self.creationBackends = [
            .zip: zip,
        ]
    }

    // MARK: - Format Detection

    /// Detect archive format using magic bytes first, then file extension.
    public func detectFormat(at url: URL) -> ArchiveFormat? {
        if let detected = ArchiveSignatureDetector.detect(at: url) {
            return detected
        }
        return ArchiveFormat.from(url: url)
    }

    /// Check whether a file is a supported archive.
    public func isArchive(at url: URL) -> Bool {
        detectFormat(at: url) != nil
    }

    /// Check whether a file extension corresponds to a supported archive format.
    public static func isArchiveExtension(_ ext: String) -> Bool {
        ArchiveFormat.from(fileExtension: ext) != nil
    }

    // MARK: - Extraction

    /// Extract an archive to the destination directory.
    /// Auto-detects the format. Yields each extracted file URL.
    public func extract(
        at source: URL,
        to destination: URL,
        format: ArchiveFormat? = nil,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) -> AsyncThrowingStream<URL, Error> {
        let resolved = format ?? detectFormat(at: source)
        guard let resolved else {
            return AsyncThrowingStream { $0.finish(throwing: ArchiveError.invalidArchive) }
        }
        guard let backend = backends[resolved] else {
            return AsyncThrowingStream { $0.finish(throwing: ArchiveError.formatNotSupported(resolved)) }
        }
        return backend.extract(at: source, to: destination, progress: progress)
    }

    /// Collect all extracted file URLs into an array.
    public func extractAll(
        at source: URL,
        to destination: URL,
        format: ArchiveFormat? = nil,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> [URL] {
        var files: [URL] = []
        for try await url in extract(at: source, to: destination, format: format, progress: progress) {
            files.append(url)
        }
        return files
    }

    // MARK: - Listing

    /// List entries in an archive without extracting file data.
    /// Returns entry metadata including names, sizes, and CRCs where available.
    public func listEntries(at source: URL, format: ArchiveFormat? = nil) throws -> [ArchiveEntryInfo] {
        let resolved = format ?? detectFormat(at: source)
        guard let resolved else {
            throw ArchiveError.invalidArchive
        }
        guard let backend = listingBackends[resolved] else {
            throw ArchiveError.formatNotSupported(resolved)
        }
        return try backend.listEntries(at: source)
    }

    /// Check if a format supports listing entries without full extraction.
    public func supportsListing(for format: ArchiveFormat) -> Bool {
        listingBackends[format] != nil
    }

    // MARK: - Zip Convenience

    /// Create a ZIP archive from a directory.
    public func createZipArchive(at destination: URL, from directory: URL) throws {
        try ZipBackend.createArchive(at: destination, from: directory)
    }

    /// Create a ZIP archive from specific file paths.
    public func createZipArchive(at destination: URL, withFiles paths: [String]) throws {
        try ZipBackend.createArchive(at: destination, withFiles: paths)
    }

    /// Simple synchronous unzip.
    public func unzipFile(at source: URL, to destination: URL) throws {
        try ZipBackend.unzip(at: source, to: destination)
    }

    // MARK: - Backend Access

    /// Get the extraction backend for a specific format, if registered.
    public func backend(for format: ArchiveFormat) -> (any ArchiveExtractorBackend)? {
        backends[format]
    }

    /// Get the listing backend for a specific format, if registered.
    public func listingBackend(for format: ArchiveFormat) -> (any ArchiveListingBackend)? {
        listingBackends[format]
    }

    /// Get the creation backend for a specific format, if registered.
    public func creationBackend(for format: ArchiveFormat) -> (any ArchiveCreationBackend)? {
        creationBackends[format]
    }
}
