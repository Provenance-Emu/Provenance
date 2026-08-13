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

    // MARK: - Extraction

    /// Extract a ZIP archive, yielding each written file as it lands on disk.
    ///
    /// Backed by SSZipArchive/minizip, which inflates each entry through a small
    /// fixed buffer straight to a `FILE *`. The previous SWCompression path called
    /// `ZipContainer.open`, which is *not* lazy — it decompressed every entry into
    /// `[ZipEntry]` in RAM before a single byte was written, so a 60 MB ROM zip sat
    /// at 0% progress (and a multi-hundred-MB memory spike) for the entire
    /// decompression, then jumped straight to 100%.
    ///
    /// SWCompression remains the fallback for platforms where `ZipArchive` is
    /// unavailable, and remains the backend for `listEntries(at:)`.
    public func extract(
        at source: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard FileManager.default.fileExists(atPath: source.path) else {
                        throw ArchiveError.extractionFailed("ZIP file does not exist: \(source.path)")
                    }
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: source.path),
                       let size = attrs[.size] as? Int64, size == 0 {
                        throw ArchiveError.extractionFailed("ZIP file is empty: \(source.lastPathComponent)")
                    }
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

                    #if canImport(ZipArchive)
                    try Self.streamingExtract(source: source, destination: destination, progress: progress) { url in
                        continuation.yield(url)
                    }
                    #else
                    try Self.inMemoryExtract(source: source, destination: destination, progress: progress) { url in
                        continuation.yield(url)
                    }
                    #endif
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // AsyncThrowingStream's `Task {}` is unstructured: a consumer that
            // breaks out of `for try await` would otherwise leave the extraction
            // running to completion. Terminating the stream now cancels it, which
            // the SSZipArchive delegate observes between entries.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    #if canImport(ZipArchive)
    /// Streaming extraction via SSZipArchive.
    ///
    /// Contract preserved from the old SWCompression loop:
    /// - directories are never yielded (SSZipArchive still reports them, we filter),
    /// - zip-slip is impossible: SSZipArchive's `_sanitizedPath` re-roots every entry
    ///   at `file:///` and standardizes it before appending to `destination`, which
    ///   subsumes the old `..`/`.` component strip; we keep the destination-prefix
    ///   guard as defence in depth before yielding,
    /// - extracted files keep `NSFileProtectionNone` (the old `.noFileProtection`
    ///   write option) so cores can read ROMs while the device is locked,
    /// - `progress()` is driven per entry and always ends at 1.0 on success.
    private static func streamingExtract(
        source: URL,
        destination: URL,
        progress: @escaping @Sendable (Double) -> Void,
        onFile: @escaping (URL) -> Void
    ) throws {
        let delegate = ZipStreamDelegate(destinationPath: destination.path, onFile: onFile)
        var unzipError: NSError?
        let success = SSZipArchive.unzipFile(
            atPath: source.path,
            toDestination: destination.path,
            preserveAttributes: false,
            overwrite: true,
            // 0 = do NOT recursively unzip nested `.zip` entries; the importer
            // handles zip-in-zip itself and expects the inner archive on disk.
            nestedZipLevel: 0,
            password: nil,
            error: &unzipError,
            delegate: delegate,
            progressHandler: { _, _, entryNumber, total in
                let fraction = Double(entryNumber + 1) / Double(max(total, 1))
                progress(min(max(fraction, 0), 1))
            },
            completionHandler: nil
        )

        if delegate.wasCancelled {
            throw CancellationError()
        }
        guard success else {
            throw ArchiveError.extractionFailed(
                unzipError?.localizedDescription ?? "Failed to extract ZIP: \(source.lastPathComponent)"
            )
        }
        progress(1.0)
    }
    #endif

    /// Whole-archive-in-RAM extraction via SWCompression. Only used where
    /// `ZipArchive` is unavailable, and by nothing on Apple platforms.
    private static func inMemoryExtract(
        source: URL,
        destination: URL,
        progress: @escaping @Sendable (Double) -> Void,
        onFile: @escaping (URL) -> Void
    ) throws {
        try autoreleasepool {
            let data = try Data(contentsOf: source)
            let entries = try ZipContainer.open(container: data)
            let fileEntries = entries.filter { $0.info.type != .directory }
            let total = fileEntries.count

            for (i, entry) in fileEntries.enumerated() {
                try Task.checkCancellation()
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
                    onFile(fullPath)
                }
                progress(Double(i + 1) / Double(max(total, 1)))
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

    /// Simple synchronous unzip.
    ///
    /// Shares the streaming SSZipArchive path with `extract(at:to:progress:)` so it
    /// no longer buffers the whole archive in RAM (and gains zip-slip sanitisation,
    /// which the old SWCompression implementation lacked entirely).
    public static func unzip(at source: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        #if canImport(ZipArchive)
        try streamingExtract(source: source, destination: destination, progress: { _ in }, onFile: { _ in })
        #else
        try inMemoryExtract(source: source, destination: destination, progress: { _ in }, onFile: { _ in })
        #endif
    }
}

#if canImport(ZipArchive)
/// Bridges SSZipArchive's per-entry ObjC callbacks into the extraction stream.
///
/// Selectors are spelled out with `@objc(...)` because `SSZipArchiveDelegate`
/// methods are `@optional`: a Swift signature that doesn't map to the exact
/// selector compiles fine and is then simply never called.
private final class ZipStreamDelegate: NSObject, SSZipArchiveDelegate {
    private let destinationPath: String
    private let onFile: (URL) -> Void
    /// Set when we aborted the unzip because the enclosing Task was cancelled.
    /// SSZipArchive reports a cancelled run as `success == NO` with a nil error,
    /// so we need our own flag to tell cancellation from a real failure.
    private(set) var wasCancelled = false

    init(destinationPath: String, onFile: @escaping (URL) -> Void) {
        self.destinationPath = destinationPath
        self.onFile = onFile
        super.init()
    }

    /// Returning `false` breaks SSZipArchive's unzip loop between entries — the
    /// only cancellation point the library offers.
    @objc(zipArchiveShouldUnzipFileAtIndex:totalFiles:archivePath:fileInfo:)
    func zipArchiveShouldUnzipFile(
        at fileIndex: Int,
        totalFiles: Int,
        archivePath: String,
        fileInfo: unz_file_info
    ) -> Bool {
        if Task.isCancelled {
            wasCancelled = true
            return false
        }
        return true
    }

    @objc(zipArchiveDidUnzipFileAtIndex:totalFiles:archivePath:unzippedFilePath:)
    func zipArchiveDidUnzipFile(
        at fileIndex: Int,
        totalFiles: Int,
        archivePath: String,
        unzippedFilePath: String
    ) {
        // SSZipArchive reports directory entries too; the old loop filtered them
        // out via `entry.info.type != .directory`.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: unzippedFilePath, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return }
        // Defence in depth against zip-slip, mirroring the old prefix guard.
        guard unzippedFilePath.hasPrefix(destinationPath) else { return }
        #if os(iOS) || os(tvOS) || os(visionOS)
        // The old write used `.noFileProtection`; SSZipArchive's `fopen` inherits
        // the container default, so restore NSFileProtectionNone explicitly.
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.none],
            ofItemAtPath: unzippedFilePath
        )
        #endif
        onFile(URL(fileURLWithPath: unzippedFilePath))
    }
}
#endif
