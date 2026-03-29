//
//  ArchiveExtractorBackend.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation

/// Protocol that all format-specific extraction backends conform to.
public protocol ArchiveExtractorBackend: Sendable {
    /// The archive format this backend handles.
    static var format: ArchiveFormat { get }

    /// Extract an archive, yielding each extracted file URL as an async stream.
    func extract(
        at source: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) -> AsyncThrowingStream<URL, Error>
}

/// Protocol for backends that can list archive entries without extracting.
/// Used for CRC-based ROM identification and archive inspection.
public protocol ArchiveListingBackend: Sendable {
    /// List entries in an archive without extracting file data.
    func listEntries(at source: URL) throws -> [ArchiveEntryInfo]
}

/// Protocol for backends that support creating archives (compression).
public protocol ArchiveCreationBackend: Sendable {
    /// Create an archive from a directory.
    func createArchive(at destination: URL, from directory: URL) throws

    /// Create an archive from specific file paths.
    func createArchive(at destination: URL, withFiles paths: [String]) throws
}
