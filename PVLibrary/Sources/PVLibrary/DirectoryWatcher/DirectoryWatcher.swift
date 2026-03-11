//
//  DirectoryWatcher.swift
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

import Foundation
import os
import PVLogging
import PVEmulatorCore
import PVFileSystem
@_exported import PVSupport
import SWCompression
@_exported import ZipArchive
import Combine
import Observation
import PVLibrary

/// Extension for FileManager to remove an item asynchronously
extension FileManager {
    func removeItem(at url: URL) async throws {
        try await Task {
            ILOG("Removing item at: \(url.path)")
            try self.removeItem(at: url)
            ILOG("Successfully removed item at: \(url.path)")
        }.value
    }
}

/// The status of the extraction process
public enum ExtractionStatus: Equatable {
    case idle
    case started(path: URL)
    case updated(path: URL)
    case completed(paths: [URL])
    case startedArchive(path: URL)
    case updatedArchive(path: URL)
    case completedArchive(paths: [URL])
    case failed(error: Error)

    public static func == (lhs: ExtractionStatus, rhs: ExtractionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.started(lhsPath), .started(rhsPath)):
            return lhsPath == rhsPath
        case let (.updated(lhsPath), .updated(rhsPath)):
            return lhsPath == rhsPath
        case let (.completed(lhsPaths), .completed(rhsPaths)):
            return lhsPaths == rhsPaths
        default:
            return false
        }
    }
}

/// Notification names for the directory watcher
public extension NSNotification.Name {
    static let PVArchiveInflationFailed = Notification.Name("PVArchiveInflationFailedNotification")
    static let archiveExtractionStarted = Notification.Name("archiveExtractionStarted")
    static let archiveExtractionProgress = Notification.Name("archiveExtractionProgress")
    static let archiveExtractionCompleted = Notification.Name("archiveExtractionCompleted")
    static let archiveExtractionFailed = Notification.Name("archiveExtractionFailed")
}

import Perception

/// Options for configuring the DirectoryWatcher
public struct DirectoryWatcherOptions {
    /// Whether to scan subdirectories for changes
    public let includeSubdirectories: Bool
    let allowedPaths: [URL]      // Only watch these paths and their subdirectories (if enabled)
    let excludedPaths: [URL]     // Explicitly exclude these paths

    public init(
        includeSubdirectories: Bool = false,
        allowedPaths: [URL] = [],
        excludedPaths: [URL] = []
    ) {
        self.includeSubdirectories = includeSubdirectories
        self.allowedPaths = allowedPaths
        self.excludedPaths = excludedPaths
    }
}

/// A class that watches a directory for changes and handles file operations
///
/// The DirectoryWatcher monitors a specified directory for new files and changes,
/// handling archive extraction and file processing automatically.
@Perceptible
public final class DirectoryWatcher: ObservableObject {

    private let watcherManager: FileWatcherManager
    private let watchedDirectory: URL
    private let options: DirectoryWatcherOptions

    /// The dispatch source for the file system object
    private var dispatchSource: DispatchSourceFileSystemObject?
    /// The serial queue for the extractor
    /// Track files currently being extracted to prevent concurrent extraction attempts.
    /// Protected by `extractingFilesLock` via `withLock`.
    private var extractingFiles: Set<URL> = []
    /// Thread-safe guard for `extractingFiles`. Uses `OSAllocatedUnfairLock` (iOS 16+).
    private let extractingFilesLock = OSAllocatedUnfairLock<Void>()
    private let serialQueue = DispatchQueue(label: "org.provenance-emu.provenance.serialExtractorQueue")
    /// Buffered events to replay after emulation pause
    private var bufferedEvents: [URL] = []
    /// Track if we're currently flushing buffered events to avoid re-entrancy
    private var isFlushingBufferedEvents = false
    /// Track if paused for emulation
    private var isPausedForEmulation = false

    /// The extractors for the supported archive types
    private let extractors: [ArchiveType: ArchiveExtractor] = [
        .zip: ZipExtractor(),
        .sevenZip: SevenZipExtractor(),
        .tar: TarExtractor(),
        .bzip2: BZip2Extractor(),
        .gzip: GZipExtractor(),
        .lzh: LzhExtractor(),
        .xz: XZExtractor(),
        .rar: RarExtractor()
    ]

    /// The current extraction progress
    public var extractionProgress: Double = 0

    /// The current extraction status
    public var extractionStatus: ExtractionStatus = .idle
//    #if !os(tvOS)
//    @ObservationIgnored
//    #endif
    private var statusContinuation: AsyncStream<ExtractionStatus>.Continuation?

    /// A sequence of extraction statuses
    public var extractionStatusSequence: AsyncStream<ExtractionStatus> {
        AsyncStream { continuation in
            statusContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                self.statusContinuation = nil
            }
        }
    }

//    #if os(tvOS)
//    private var completedFilesContinuation: AsyncStream<[URL]>.Continuation?
//    #else
//    @ObservationIgnored
    private var completedFilesContinuation: AsyncStream<[URL]>.Continuation?
//    #endif

    /// A sequence of completed files
    public var completedFilesSequence: AsyncStream<[URL]> {
        AsyncStream { continuation in
            completedFilesContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                self.completedFilesContinuation = nil
            }
        }
    }

    /// Initialize the directory watcher with a directory and options
    public init(directory: URL, options: DirectoryWatcherOptions = DirectoryWatcherOptions()) {
        self.watchedDirectory = directory
        self.options = options
        self.watcherManager = FileWatcherManager(label: "org.provenance-emu.provenance.fileWatcherManager")
        ILOG("DirectoryWatcher initialized with directory: \(directory.path), includeSubdirectories: \(options.includeSubdirectories)")
        createDirectoryIfNeeded()
        Task {
            processExistingArchives()
        }
    }

    /// Start monitoring the directory for changes
    public func startMonitoring() throws {
        ILOG("Starting monitoring for directory: \(watchedDirectory.path)")
        stopMonitoring()
        let fileDescriptor = open(watchedDirectory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            ILOG("Failed to open file descriptor for directory: \(watchedDirectory.path)")
            throw NSError(domain: POSIXError.errorDomain, code: Int(errno))
        }

        dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: serialQueue)
        dispatchSource?.setEventHandler { [weak self] in
            Task {
                await self?.handleFileSystemEvent()
            }
        }
        dispatchSource?.setCancelHandler {
            ILOG("Closing file descriptor for directory: \(self.watchedDirectory.path)")
            close(fileDescriptor)
        }
        dispatchSource?.resume()
        ILOG("Monitoring started for directory: \(watchedDirectory.path)")
    }

    /// Stop monitoring the directory for changes
    public func stopMonitoring(includingFileWatchers: Bool = false) {
        ILOG("Stopping monitoring for directory: \(watchedDirectory.path)")
        dispatchSource?.cancel()
        dispatchSource = nil
        if includingFileWatchers {
            Task {
                let paths = await watcherManager.getWatchedPaths()
                paths.forEach { stopWatchingFile(at: $0) }
            }
        }
        ILOG("Monitoring stopped for directory: \(watchedDirectory.path)")
    }

    public func isWatchingFile(at path: URL) async -> Bool {
        let isWatching = await watcherManager.isWatching(path)
        VLOG("Checked if watching file: \(path.lastPathComponent), result: \(isWatching)")
        return isWatching
    }

    public func isWatchingAnyFile() async -> Bool {
        return await !watcherManager.hasActiveWatchers()
    }

    /// Extract an archive from a file path
    public func extractArchive(at filePath: URL) async throws {
        // Check if this file is already being extracted; register it if not.
        let isAlreadyExtracting = extractingFilesLock.withLock { () -> Bool in
            guard !extractingFiles.contains(filePath) else { return true }
            extractingFiles.insert(filePath)
            return false
        }

        guard !isAlreadyExtracting else {
            ILOG("Archive \(filePath.lastPathComponent) is already being extracted, skipping duplicate attempt")
            return
        }

        defer {
            // Remove from extracting set when done
            extractingFilesLock.withLock { extractingFiles.remove(filePath) }
        }

        ILOG("Starting archive extraction for file: \(filePath.path)")
        stopWatchingFile(at: filePath)

        // Wait for file to stabilize using kqueue-based dispatch source monitoring.
        // Replaces fixed 200ms poll + retry loop with event-driven detection.
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            ILOG("Archive file no longer exists: \(filePath.path)")
            return
        }

        let isStable = await FileStabilityChecker.waitForStability(at: filePath)
        if !isStable {
            WLOG("File \(filePath.lastPathComponent) did not stabilize within timeout, attempting extraction anyway")
        }

        guard FileManager.default.fileExists(atPath: filePath.path) else {
            ILOG("Archive file no longer exists after stability wait: \(filePath.path)")
            return
        }

        // Bounded retry readability + signature check after stability wait.
        try await verifyArchiveReadable(at: filePath, isStable: isStable)

        guard !filePath.path.contains("MACOSX") else {
            ILOG("Skipping MACOSX file: \(filePath.path)")
            return
        }

        // Detect actual archive type from file signature (not just extension)
        // This handles cases where files have wrong extensions (e.g., .zip file that's actually 7z)
        let detectedArchiveType: ArchiveType?
        if let fileHandle = try? FileHandle(forReadingFrom: filePath) {
            let signature = fileHandle.readData(ofLength: 4)
            fileHandle.closeFile()

            // Detect archive type from signature
            if signature.count >= 2 {
                if signature[0] == 0x50 && signature[1] == 0x4B {
                    // ZIP signature: PK (0x50 0x4B)
                    detectedArchiveType = .zip
                    ILOG("Detected ZIP archive from signature: \(filePath.lastPathComponent)")
                } else if signature.count >= 4 && signature[0] == 0x37 && signature[1] == 0x7A && signature[2] == 0xBC && signature[3] == 0xAF {
                    // 7z signature: 37 7A BC AF
                    detectedArchiveType = .sevenZip
                    ILOG("Detected 7z archive from signature (file has .\(filePath.pathExtension) extension): \(filePath.lastPathComponent)")
                } else {
                    // Try extension-based detection as fallback (handles lzh, lha, bzip2, gzip, xz, etc.)
                    detectedArchiveType = ArchiveType.from(fileExtension: filePath.pathExtension)
                    if detectedArchiveType != nil {
                        ILOG("Using extension-based detection for \(filePath.lastPathComponent): \(detectedArchiveType!.rawValue)")
                    }
                }
            } else {
                detectedArchiveType = ArchiveType.from(fileExtension: filePath.pathExtension)
            }
        } else {
            // Fallback to extension-based detection if we can't read the file
            detectedArchiveType = ArchiveType.from(fileExtension: filePath.pathExtension)
        }

        guard let archiveType = detectedArchiveType else {
            ILOG("Unsupported archive type for: \(filePath.pathExtension) - \(filePath.lastPathComponent)")
            return
        }

        guard let extractor = extractors[archiveType] else {
            ILOG("No extractor available for archive type: \(archiveType.rawValue) - \(filePath.lastPathComponent)")
            return
        }

        // Check file size for 7z files before attempting extraction
        // This provides a clearer error message than waiting for the extractor to fail
        if archiveType == .sevenZip {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path),
               let fileSize = attributes[.size] as? Int64 {
                let maxSize: Int64 = 1_000_000_000 // 1GB
                if fileSize > maxSize {
                    let sizeMB = fileSize / 1_000_000
                    let maxMB = maxSize / 1_000_000
                    let error = ArchiveError.extractionFailed("7z file is too large (\(sizeMB) MB). Maximum supported size is \(maxMB) MB. Please extract manually or use ZIP format for larger archives.")
                    ELOG("Cannot extract 7z file \(filePath.lastPathComponent): \(error.localizedDescription)")
                    updateExtractionStatus(.failed(error: error))
                    throw error
                } else if fileSize > 500_000_000 { // 500MB
                    let sizeMB = fileSize / 1_000_000
                    WLOG("7z file \(filePath.lastPathComponent) is large (\(sizeMB) MB). Extraction may use significant memory.")
                }
            }
        }

        // Check if archive should be kept as-is (for systems that support archives directly)
        // Only check for ZIP files (7z files should always be extracted)
        if archiveType == .zip {
            let zipChecker = ArchiveZipSupportChecker.shared
            let (shouldKeepAsIs, systemID) = await zipChecker.shouldKeepArchiveAsIs(filePath)

            if shouldKeepAsIs, let systemID = systemID {
                ILOG("Archive \(filePath.lastPathComponent) supports zip-as-ROM for system \(systemID.rawValue) - moving directly to system folder")
                try await handleZipAsROM(filePath: filePath, systemID: systemID)
                return
            }
        }

        do {
            // Log file size before starting extraction
            if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path),
               let fileSize = attributes[.size] as? Int64 {
                let sizeMB = fileSize / 1_000_000
                ILOG("Starting extraction of \(archiveType.rawValue) archive: \(filePath.lastPathComponent) (size: \(sizeMB) MB)")
            }

            updateExtractionStatus(.startedArchive(path: filePath))

            // Post notification that extraction has started
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .archiveExtractionStarted,
                    object: nil,
                    userInfo: [
                        "path": filePath.path,
                        "filename": filePath.lastPathComponent,
                        "timestamp": Date()
                    ]
                )
            }

            // Extract to temp directory that's NOT watched by file scanner
            // This prevents race conditions where files are detected mid-extraction
            let tempExtractionDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ArchiveExtraction")
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempExtractionDir, withIntermediateDirectories: true, attributes: nil)

            var extractedFiles: [URL] = []
            for try await extractedFile in extractor.extract(at: filePath, to: tempExtractionDir, progress: { progress in
                ILOG("Extraction progress for \(filePath.lastPathComponent): \(Int(progress * 100))%")
                self.extractionProgress = progress

                // Post notification for extraction progress
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: .archiveExtractionProgress,
                        object: nil,
                        userInfo: [
                            "progress": progress,
                            "path": filePath.path,
                            "filename": filePath.lastPathComponent,
                            "timestamp": Date()
                        ]
                    )
                }
            }) {
                extractedFiles.append(extractedFile)
                updateExtractionStatus(.updatedArchive(path: extractedFile))
                ILOG("Extracted file: \(extractedFile.path)")
            }

            updateExtractionStatus(.completedArchive(paths: extractedFiles))
            ILOG("Archive extraction completed for file: \(filePath.path)")

            // Post notification that extraction has completed
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .archiveExtractionCompleted,
                    object: nil,
                    userInfo: [
                        "paths": extractedFiles.map { $0.path },
                        "count": extractedFiles.count,
                        "originalPath": filePath.path,
                        "originalFilename": filePath.lastPathComponent,
                        "timestamp": Date()
                    ]
                )
            }

            // Sort extracted files, prioritizing .m3u and .cue files
            let sortedFiles = sortExtractedFiles(extractedFiles)

            // Move files FLATLY to the watched directory (no subdirectory structure)
            // This ensures files are immediately available for import without race conditions
            let moveResult = await moveExtractedFilesFlat(sortedFiles, from: tempExtractionDir, to: watchedDirectory)

            if !moveResult.moved.isEmpty {
                completedFilesContinuation?.yield(moveResult.moved)
            }

            if moveResult.isComplete {
                // All files moved — safe to delete archive and temp dir
                do {
                    try await FileManager.default.removeItem(at: filePath)
                    ILOG("Deleted original archive after successful move: \(filePath.lastPathComponent)")
                } catch {
                    ELOG("Failed to delete original archive \(filePath.lastPathComponent): \(error.localizedDescription)")
                }
                do {
                    try FileManager.default.removeItem(at: tempExtractionDir)
                } catch {
                    ELOG("Failed to clean up temp extraction directory \(tempExtractionDir.lastPathComponent): \(error.localizedDescription)")
                }
            } else {
                // Archive NOT deleted — preserved alongside temp dir for retry
                WLOG("Partial move: \(moveResult.failedCount) file(s) remain in \(tempExtractionDir.path), archive preserved at \(filePath.path)")
                let partialError = ArchiveError.extractionFailed(
                    "\(moveResult.failedCount) file(s) could not be moved from temp directory"
                )
                updateExtractionStatus(.failed(error: partialError))
                await postArchiveExtractionFailed(
                    error: partialError, filePath: filePath,
                    movedCount: moveResult.moved.count,
                    failedCount: moveResult.failedCount)
                throw partialError
            }
        } catch {
            // Log detailed error information
            let errorDescription = error.localizedDescription
            ELOG("Error during archive extraction of \(filePath.lastPathComponent): \(errorDescription)")

            // If it's an ArchiveError, log additional details
            if let archiveError = error as? ArchiveError {
                switch archiveError {
                case .extractionFailed(let message):
                    ELOG("ArchiveError.extractionFailed: \(message)")
                case .fileTooLarge:
                    ELOG("ArchiveError.fileTooLarge")
                case .invalidArchive:
                    ELOG("ArchiveError.invalidArchive")
                }
            }

            // Log file size if available
            if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path),
               let fileSize = attributes[.size] as? Int64 {
                let sizeMB = fileSize / 1_000_000
                ELOG("Failed archive file size: \(sizeMB) MB")
            }

            updateExtractionStatus(.failed(error: error))

            // Post notification that extraction has failed
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .archiveExtractionFailed,
                    object: nil,
                    userInfo: [
                        "error": error.localizedDescription,
                        "path": filePath.path,
                        "filename": filePath.lastPathComponent,
                        "timestamp": Date()
                    ]
                )
            }

            throw error
        }
    }

    /// Handle zip files that should be kept as-is (for systems like MAME that support zip directly)
    private func handleZipAsROM(filePath: URL, systemID: SystemIdentifier) async throws {
        let systemRomsDirectory = Paths.romsPath(forSystemIdentifier: systemID)
        let destinationURL = systemRomsDirectory.appendingPathComponent(filePath.lastPathComponent)

        // Create system directory if needed
        try FileManager.default.createDirectory(at: systemRomsDirectory, withIntermediateDirectories: true, attributes: nil)

        // Check if file already exists at destination
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            ILOG("Zip file \(filePath.lastPathComponent) already exists at destination, removing source")
            try await FileManager.default.removeItem(at: filePath)
            completedFilesContinuation?.yield([destinationURL])
            return
        }

        // Move zip directly to system folder
        try FileManager.default.moveItem(at: filePath, to: destinationURL)
        ILOG("Moved zip-as-ROM \(filePath.lastPathComponent) directly to system folder \(systemID.rawValue)")

        // Trigger import for the moved file
        Task {
            await GameImporter.shared.addImports(forPaths: [destinationURL], targetSystem: systemID)
            ILOG("Triggered import for zip-as-ROM \(filePath.lastPathComponent) in system \(systemID.rawValue)")
        }

        completedFilesContinuation?.yield([destinationURL])
    }

    /// Result of a batch file-move operation.
    struct BatchMoveResult {
        /// Files that were successfully moved to the destination.
        let moved: [URL]
        /// Number of files that failed to move.
        let failedCount: Int
        /// `true` when every file was moved successfully.
        var isComplete: Bool { failedCount == 0 }
    }

    /// Posts the `archiveExtractionFailed` notification on the main actor.
    private func postArchiveExtractionFailed(
        error: Error, filePath: URL, movedCount: Int, failedCount: Int
    ) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .archiveExtractionFailed, object: nil, userInfo: [
                "error": error.localizedDescription,
                "path": filePath.path,
                "filename": filePath.lastPathComponent,
                "movedCount": movedCount,
                "failedCount": failedCount,
                "timestamp": Date()
            ])
        }
    }

    /// Verifies that an archive file is readable and has a recognizable
    /// signature, retrying a bounded number of times with backoff to handle
    /// transient file locks that may outlast the stability quiesce interval.
    private func verifyArchiveReadable(at filePath: URL, isStable: Bool) async throws {
        let maxAttempts = isStable ? 2 : 3
        var fileSize: Int64 = 0

        for attempt in 1...maxAttempts {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path),
               let size = attributes[.size] as? Int64, size > 0 {
                fileSize = size
                ILOG("Archive file \(filePath.lastPathComponent) has size: \(size) bytes")
                if let fileHandle = try? FileHandle(forReadingFrom: filePath) {
                    let signature = fileHandle.readData(ofLength: 4)
                    fileHandle.closeFile()
                    let isZip = signature.count >= 2
                        && signature[0] == 0x50 && signature[1] == 0x4B
                    let is7z = signature.count >= 4
                        && signature[0] == 0x37 && signature[1] == 0x7A
                        && signature[2] == 0xBC && signature[3] == 0xAF
                    if isZip || is7z {
                        ILOG("Archive \(filePath.lastPathComponent) has valid \(isZip ? "ZIP" : "7z") signature")
                    } else {
                        let hex = signature.prefix(4)
                            .map { String(format: "%02X", $0) }.joined(separator: " ")
                        ILOG("Archive \(filePath.lastPathComponent) signature (\(hex)) not ZIP/7z, using extension detection")
                    }
                    ILOG("Archive \(filePath.lastPathComponent) verified readable on attempt \(attempt)")
                    return
                }
            }
            if attempt < maxAttempts {
                let delay: UInt64 = isStable ? 200_000_000 : 400_000_000
                WLOG("Archive \(filePath.lastPathComponent) not readable (attempt \(attempt)/\(maxAttempts)), retrying...")
                try? await Task.sleep(nanoseconds: delay)
            }
        }

        let description = "Archive file not readable after \(maxAttempts) attempt(s): "
            + "\(filePath.lastPathComponent) (size: \(fileSize) bytes)"
        ELOG("Failed to verify archive readiness after retries: \(filePath.path)")
        throw NSError(domain: "DirectoryWatcher", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: description])
    }

    /// Moves extracted files to the destination directory, flattening any
    /// subdirectory structure. Individual move failures are logged but do
    /// not abort the batch — successfully moved files are still returned
    /// alongside the failure count so callers can decide how to proceed.
    private func moveExtractedFilesFlat(
        _ files: [URL],
        from sourceDir: URL,
        to destinationDir: URL
    ) async -> BatchMoveResult {
        var movedFiles: [URL] = []
        var failedCount = 0
        for file in files {
            let fileName = file.lastPathComponent
            let destinationURL = destinationDir.appendingPathComponent(fileName)

            var finalDestinationURL = destinationURL
            var counter = 1
            while FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                let nameWithoutExt = destinationURL.deletingPathExtension().lastPathComponent
                let ext = destinationURL.pathExtension
                finalDestinationURL = destinationDir.appendingPathComponent("\(nameWithoutExt)_\(counter).\(ext)")
                counter += 1
            }

            do {
                try FileManager.default.moveItem(at: file, to: finalDestinationURL)
                movedFiles.append(finalDestinationURL)
                ILOG("Moved extracted file flatly: \(fileName) -> \(finalDestinationURL.lastPathComponent)")
            } catch {
                failedCount += 1
                ELOG("Failed to move extracted file \(fileName): \(error.localizedDescription)")
            }
        }
        if failedCount > 0 {
            ELOG("Batch move: \(failedCount)/\(files.count) failure(s). Source dir preserved: \(sourceDir.path)")
        }
        return BatchMoveResult(moved: movedFiles, failedCount: failedCount)
    }

    private func sortExtractedFiles(_ files: [URL]) -> [URL] {
        let priorityExtensions = ["m3u", "cue"]
        return files.sorted { file1, file2 in
            let ext1 = file1.pathExtension.lowercased()
            let ext2 = file2.pathExtension.lowercased()

            if priorityExtensions.contains(ext1) && !priorityExtensions.contains(ext2) {
                return true
            } else if !priorityExtensions.contains(ext1) && priorityExtensions.contains(ext2) {
                return false
            } else {
                return file1.lastPathComponent < file2.lastPathComponent
            }
        }
    }

    private func moveExtractedFiles(_ files: [URL], from sourceDir: URL, to destinationDir: URL) async throws -> [URL] {
        var movedFiles: [URL] = []
        for file in files {
            let destinationURL = destinationDir.appendingPathComponent(file.lastPathComponent)
            try FileManager.default.moveItem(at: file, to: destinationURL)
            movedFiles.append(destinationURL)
        }
        return movedFiles
    }

    /// Update the extraction status
    private func updateExtractionStatus(_ newStatus: ExtractionStatus) {
        extractionStatus = newStatus
        statusContinuation?.yield(newStatus)
        ILOG("Extraction status updated: \(newStatus)")
    }

    /// Schedule a delayed start of monitoring
    public func delayedStartMonitoring() {
        ILOG("Scheduling delayed start of monitoring")
        Task {
            try await delay(2) {
                try self.startMonitoring()
            }
        }
    }

    /// Stop watching a file
    private func stopWatchingFile(at path: URL) {
        ILOG("Stopping watch for file: \(path.lastPathComponent)")
        Task {
            await watcherManager.removeWatcher(for: path)
            ILOG("File watcher removed for: \(path.lastPathComponent)")
        }
    }

    /// Cleanup nonexistent file watchers
    private func cleanupNonexistentFileWatchers() {
        ILOG("Starting cleanup of nonexistent file watchers")
        Task {
            let paths = await watcherManager.getWatchedPaths()
            for path in paths {
                if !FileManager.default.fileExists(atPath: path.path) {
                    stopWatchingFile(at: path)
                    ILOG("Removed watcher for nonexistent file: \(path.lastPathComponent)")
                }
            }
        }
        ILOG("Finished cleanup of nonexistent file watchers")
    }

    private func processArchive(at url: URL) {
        ILOG("Processing archive: \(url.lastPathComponent) - passing to GameImporter for BIOS detection and extraction")

        // Archive extraction is now handled by GameImporter, which will:
        // 1. Check if the archive is a BIOS file first
        // 2. If BIOS, move it to BIOS folder as-is
        // 3. If not BIOS, extract and import contents
        // This ensures BIOS files are never incorrectly extracted

        // Verify file still exists before yielding (it may have been moved during import)
        guard FileManager.default.fileExists(atPath: url.path) else {
            ILOG("Archive \(url.lastPathComponent) no longer exists (likely moved during import), skipping")
            Task {
                await watcherManager.removeWatcher(for: url)
            }
            return
        }

        // Pass archive to GameImporter like any other file
        // GameImporter will handle BIOS detection and extraction
        completedFilesContinuation?.yield([url])
    }

    private func processNonArchive(at url: URL) {
        ILOG("Processing non-archive file: \(url.lastPathComponent)")

        // Verify file still exists before yielding (it may have been moved during import)
        guard FileManager.default.fileExists(atPath: url.path) else {
            ILOG("File \(url.lastPathComponent) no longer exists (likely moved during import), skipping")
            Task {
                await watcherManager.removeWatcher(for: url)
            }
            return
        }

        completedFilesContinuation?.yield([url])
    }

    private func processFile(at url: URL) {
        ILOG("Processing file: \(url.path)")

        // Safety check: ensure this is actually a file, not a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            WLOG("Skipping directory or non-existent file: \(url.lastPathComponent)")
            // Stop watching if file doesn't exist or is a directory
            Task {
                await watcherManager.removeWatcher(for: url)
            }
            return
        }

        // Check if file is still in Imports folder (it may have been moved during import)
        let isInImportsFolder = url.path.contains("/Imports/")
        if isInImportsFolder {
            // Verify file still exists in Imports folder before processing
            // This prevents processing files that have already been moved by GameImporter
            guard FileManager.default.fileExists(atPath: url.path) else {
                ILOG("File \(url.lastPathComponent) no longer exists in Imports folder (likely moved during import), skipping processing")
                Task {
                    await watcherManager.removeWatcher(for: url)
                }
                return
            }
        }

        // Handle archives and other files
        if isArchive(url) {
            processArchive(at: url)
        } else {
            processNonArchive(at: url)
        }
    }

    private func handleCompletedFile(at path: URL) {
        ILOG("Handling completed file: \(path.lastPathComponent)")
        processFile(at: path)
    }
}

public extension DirectoryWatcher {

    /// Check if a file is an archive
    func isArchive(_ url: URL) -> Bool {
        let result = extractors.keys.contains { archiveType in
            url.pathExtension.lowercased() == archiveType.rawValue
        }
        VLOG("Checked if file is archive: \(url.lastPathComponent), result: \(result)")
        return result
    }
}

fileprivate extension DirectoryWatcher {

    /// Create the directory if it doesn't exist
    func createDirectoryIfNeeded() {
        do {
            guard !FileManager.default.fileExists(atPath: watchedDirectory.path) else {
                ILOG("Watched directory already exists at: \(watchedDirectory.path), skipping creation")
                return
            }
            ILOG("Attempting to create directory at: \(watchedDirectory.path)")
            try FileManager.default.createDirectory(at: watchedDirectory, withIntermediateDirectories: true, attributes: nil)
            ILOG("Successfully created directory at: \(watchedDirectory.path)")
        } catch {
            ILOG("Unable to create directory at: \(watchedDirectory.path), because: \(error.localizedDescription)")
        }
    }

    /// Process existing archives and non-archive files
    func processExistingArchives() {
        ILOG("Starting to process existing files")
        Task.detached { [self] in
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: self.watchedDirectory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                ILOG("Found \(contents.count) items in directory: \(self.watchedDirectory)")

                // Filter to only actual files (not directories)
                var filesOnly: [URL] = []
                for item in contents {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory),
                       !isDirectory.boolValue {
                        filesOnly.append(item)
                    }
                }

                // Process all files (archives and non-archives) - pass to GameImporter
                // GameImporter will handle BIOS detection and archive extraction
                for file in filesOnly where isValidFile(file) {
                    let isArchive = Extensions.archiveExtensions.contains(file.pathExtension.lowercased())
                    if isArchive {
                        ILOG("Processing existing archive: \(file.lastPathComponent) - passing to GameImporter for BIOS detection and extraction")
                    } else {
                        ILOG("Processing existing non-archive file: \(file.lastPathComponent)")
                    }
                    // Add to import queue - GameImporter will handle BIOS detection and extraction
                    await GameImporter.shared.addImports(forPaths: [file])
                }

                ILOG("Finished processing existing files")
            } catch {
                ELOG("Error processing existing files: \(error.localizedDescription)")
            }
        }
    }

    /// Handle a file system event
    private func handleFileSystemEvent() async {
        ILOG("Handling file system event for directory: \(watchedDirectory.path)")
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: watchedDirectory,
                includingPropertiesForKeys: nil,
                options: [
                    .skipsHiddenFiles,
                    options.includeSubdirectories ? [] : .skipsSubdirectoryDescendants
                ]
            )
            ILOG("Found \(contents.count) items in directory after file system event (including subdirectories: \(options.includeSubdirectories))")

            // Defer processing during emulation pause, but remember what arrived
            let importerPaused = await MainActor.run { GameImporter.shared.isPausedForEmulation }
            if isPausedForEmulation || CloudSyncManager.shared.isPausedForEmulation || importerPaused {
                bufferedEvents.append(contentsOf: contents)
                ILOG("Deferring directory events while emulation paused. Buffered total: \(bufferedEvents.count)")
                return
            }

            let isImportsFolder = watchedDirectory.path.contains("/Imports/")

            // Filter to only actual files (not directories)
            var filesOnly = contents.filter { item in
                guard isValidFile(item) else { return false }
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory) && !isDirectory.boolValue
            }

            // Merge any buffered events collected during pause
            if !bufferedEvents.isEmpty {
                var seenPaths = Set<String>()
                let merged = filesOnly + bufferedEvents
                filesOnly = merged.compactMap { url in
                    let path = url.path.lowercased()
                    guard !seenPaths.contains(path) else { return nil }
                    seenPaths.insert(path)
                    return url
                }
                bufferedEvents.removeAll()
            }

            for file in filesOnly {
                if await !isWatchingFile(at: file) {
                    ILOG("Starting to watch new file: \(file.lastPathComponent)")

                    // For files in Imports folder, check immediately if they're already stable
                    // This handles cases where files are copied via file browser and are already complete
                    if isImportsFolder {
                        // Small delay to ensure file system has settled
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

                        // Check if file is stable (size hasn't changed)
                        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                           let size = attributes[.size] as? Int64, size > 0 {
                            // Check if size is stable by comparing with a second check after a short delay
                            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                            if let attributes2 = try? FileManager.default.attributesOfItem(atPath: file.path),
                               let size2 = attributes2[.size] as? Int64, size2 == size {
                                // File exists, has content, and size is stable - process immediately
                                ILOG("File \(file.lastPathComponent) appears stable in Imports folder, processing immediately")
                                processFile(at: file)
                                continue
                            }
                        }

                        // If not stable yet, start watching
                        watchFile(at: file)
                    } else {
                        watchFile(at: file)
                    }
                }
            }
            cleanupNonexistentFileWatchers()

        } catch {
            ELOG("Error handling file system event: \(error.localizedDescription)")
        }
    }

    /// Flush buffered directory events after emulation resumes.
    private func flushBufferedEventsIfNeeded() async {
        if isFlushingBufferedEvents { return }
        let importerPaused = await MainActor.run { GameImporter.shared.isPausedForEmulation }
        if isPausedForEmulation || CloudSyncManager.shared.isPausedForEmulation || importerPaused {
            ILOG("Pause flags still set; deferring flush")
            return
        }
        guard !bufferedEvents.isEmpty else { return }
        isFlushingBufferedEvents = true
        ILOG("Flushing \(bufferedEvents.count) buffered directory events after emulation resume for directory: \(watchedDirectory.path)")
        await handleFileSystemEvent()
        isFlushingBufferedEvents = false
    }

    /// Pause watcher for emulation
    public func pauseForEmulation() {
        isPausedForEmulation = true
        ILOG("DirectoryWatcher paused for emulation: \(watchedDirectory.path)")
    }

    /// Resume watcher from emulation pause
    public func resumeFromEmulation() {
        isPausedForEmulation = false
        ILOG("DirectoryWatcher resumed from emulation: \(watchedDirectory.path)")
        Task {
            await flushBufferedEventsIfNeeded()
        }
    }

    /// Check if a file is valid
    func isValidFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        let isValid = !filename.starts(with: ".") && !url.path.contains("_MACOSX") && filename != "0"
        VLOG("Checked if file is valid: \(filename), result: \(isValid)")
        return isValid
    }

    /// Trigger an initial import
    func triggerInitialImport() throws {
        ILOG("Triggering initial import")
        let triggerPath = watchedDirectory.appendingPathComponent("0")
        try "0".write(to: triggerPath, atomically: false, encoding: .utf8)
        try FileManager.default.removeItem(at: triggerPath)
        ILOG("Initial import triggered")
    }

    /// Watch a file
    private func watchFile(at path: URL) {
        Task {
            ILOG("Starting to watch file: \(path.lastPathComponent)")

            // Get initial file attributes
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
                  let initialSize = attributes[.size] as? Int64,
                  let initialModDate = attributes[.modificationDate] as? Date else {
                ELOG("Failed to get initial file attributes for: \(path.lastPathComponent)")
                return
            }

            let fileDescriptor = open(path.path, O_EVTONLY)
            guard fileDescriptor != -1 else {
                ELOG("Error opening file for watching: \(path.path), error: \(String(cString: strerror(errno)))")
                return
            }

            let source = await watcherManager.createFileSystemSource(
                fileDescriptor: fileDescriptor,
                eventMask: [DispatchSource.FileSystemEvent.write, DispatchSource.FileSystemEvent.extend],
                eventHandler: { [weak self] in
                    Task { @MainActor in
                        await self?.handleFileChange(at: path)
                    }
                },
                cancelHandler: {
                    ILOG("Closing file descriptor for file: \(path.lastPathComponent)")
                    close(fileDescriptor)
                }
            )

            source.resume()
            await watcherManager.addWatcher(source,
                                          for: path,
                                          initialSize: initialSize,
                                          modificationDate: initialModDate)

            // Start monitoring file changes
            await monitorFileChanges(for: path)
        }
    }

    private func monitorFileChanges(for path: URL) async {
        ILOG("Starting file change monitoring for: \(path.lastPathComponent)")

        /// Check immediately if file appears stable (for files already complete in Imports folder)
        let isInImportsFolder = path.path.contains("/Imports/")
        if isInImportsFolder {
            /// For files in Imports folder, check immediately - they're typically already complete
            await checkFileStatus(at: path)

            /// If file was processed, exit early
            if await !watcherManager.isWatching(path) {
                ILOG("File change monitoring ended early (file processed): \(path.lastPathComponent)")
                return
            }
        }

        var checkCount = 0
        let maxChecks = isInImportsFolder ? 5 : 30 /// Reduced checks for Imports folder (10 seconds vs 1 minute)

        while checkCount < maxChecks {
            do {
                try await Task.sleep(for: .seconds(2))

                /// Check if we're still watching this file
                guard await watcherManager.isWatching(path) else {
                    ILOG("File watcher removed for: \(path.lastPathComponent)")
                    break
                }

                await checkFileStatus(at: path)

                /// If file was processed, exit early
                if await !watcherManager.isWatching(path) {
                    break
                }

                checkCount += 1

            } catch is CancellationError {
                ILOG("File monitoring cancelled for: \(path.lastPathComponent)")
                break
            } catch {
                ELOG("Error during file monitoring: \(error.localizedDescription)")
                break
            }
        }

        ILOG("File change monitoring ended for: \(path.lastPathComponent)")
    }

    private func handleFileChange(at path: URL) async {
        ILOG("File change detected for: \(path.lastPathComponent)")
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            let currentSize = attributes[.size] as? Int64 ?? 0
            let currentModificationDate = attributes[.modificationDate] as? Date ?? Date()

            await watcherManager.updateFileStatus(
                for: path,
                size: currentSize,
                modificationDate: currentModificationDate
            )

            await checkFileStatus(at: path)
        } catch {
            ELOG("Error handling file change: \(error.localizedDescription)")
            await watcherManager.removeWatcher(for: path)
        }
    }

    private func checkFileStatus(at path: URL) async {
        guard let status = await watcherManager.getFileStatus(for: path) else {
            ELOG("No status found for file: \(path.lastPathComponent)")
            return
        }

        // Check if file still exists before checking status
        // Files in Imports folder may have been moved by GameImporter
        guard FileManager.default.fileExists(atPath: path.path) else {
            ILOG("File \(path.lastPathComponent) no longer exists (likely moved during import), stopping watch")
            await watcherManager.removeWatcher(for: path)
            return
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: path.path)
        let currentSize = attributes?[.size] as? Int64 ?? 0
        let currentModDate = attributes?[.modificationDate] as? Date ?? Date()

        /// If file size hasn't changed, check if it's stable
        let isInImportsFolder = path.path.contains("/Imports/")

        if currentSize > 0 && currentSize == status.size {
            /// For files in Imports folder, be more aggressive - process if size matches and file is readable
            /// For other files, process immediately when size matches (original behavior)
            let shouldProcess: Bool
            if isInImportsFolder {
                /// For Imports folder: process if size matches and modification date is stable (within 0.5s)
                /// This handles files copied via file browser that may have slight timestamp differences
                let timeDiff = abs(currentModDate.timeIntervalSince(status.modificationDate))
                shouldProcess = timeDiff < 0.5 || timeDiff > 3600 // Also handle files older than 1 hour (definitely stable)
            } else {
                /// Original behavior: process immediately when size matches
                shouldProcess = true
            }

            if shouldProcess {
                ILOG("File appears complete, starting processing: \(path.lastPathComponent)")
                processFile(at: path)
                await watcherManager.removeWatcher(for: path)
            }
        }
    }

    private func isBIOSFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent.lowercased()
        return RomDatabase.biosFilenamesCache.contains(filename)
    }
}

// MARK: - Utility Functions

extension DirectoryWatcher {
    /// Handle an imported file
    public func handleImportedFile(at url: URL) {
        ILOG("Handling imported file: \(url.lastPathComponent)")
        let secureDoc = url.startAccessingSecurityScopedResource()

        defer {
            if secureDoc {
                url.stopAccessingSecurityScopedResource()
                ILOG("Stopped accessing security scoped resource for file: \(url.lastPathComponent)")
            }
        }

        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(readingItemAt: url, options: .forUploading, error: &error) { (newURL) in
            do {
                let destinationURL = watchedDirectory.appendingPathComponent(newURL.lastPathComponent)
                ILOG("Moving imported file from \(newURL.path) to \(destinationURL.path)")
                try FileManager.default.moveItem(at: newURL, to: destinationURL)

                Task {
                    /// Minimal delay to allow file system to settle (reduced from 1.5s to 0.5s)
                    ILOG("Scheduling import for file: \(destinationURL.lastPathComponent)")
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    // Pass to GameImporter instead of extracting directly
                    // GameImporter will handle BIOS detection and archive extraction
                    await GameImporter.shared.addImports(forPaths: [destinationURL])
                }
            } catch {
                ELOG("Error handling imported file: \(error.localizedDescription)")
            }
        }

        if let error = error {
            ELOG("File coordination error: \(error.localizedDescription)")
        }
    }

}

// MARK: - Utility Functions

func repeatingTimer(interval: TimeInterval, _ operation: @escaping () async -> Void) async {
    while true {
        await operation()
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
}

// MARK: - Timer Sequence
struct TimerSequence: AsyncSequence {
    typealias Element = Date
    let interval: TimeInterval

    struct AsyncIterator: AsyncIteratorProtocol {
        let interval: TimeInterval

        mutating func next() async -> Date? {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            return Date()
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(interval: interval)
    }
}

// MARK: - Extracted Files Stream
public extension DirectoryWatcher {
    /// Create a stream of extracted files
    func extractedFilesStream(at path: URL) -> AsyncStream<[URL]> {
        ILOG("Creating extracted files stream for path: \(path.path)")
        return AsyncStream { continuation in
            Task {
                for await status in self.extractionStatusSequence {
                    switch status {
                    case .completed(let paths):
                        print("Extraction completed, yielding paths: \(paths)")
                        continuation.yield(paths)
                    case .updated(let path):
                        print("Extraction updated, yielding path: \(path)")
                        continuation.yield([path])
                    case .failed(let error):
                        ELOG("Extraction failed with error: \(error)")
                        // Don't yield anything for failed extractions
                    case .started, .idle:
                        print("Extraction status changed to \(status)")
                        break
                    case .startedArchive(path: _):
                        print("Extraction status changed to \(status)")
                    case .updatedArchive(path: let path):
                        print("Extraction updated, yielding path: \(path)")
                    case .completedArchive(paths: let paths):
                        print("Extraction completed, yielding paths: \(paths)")
                    }
                }
                ILOG("Extraction status sequence finished")
                continuation.finish()
            }
        }
    }
}

// MARK: - Delay Function

/// Delay an operation
func delay(_ duration: TimeInterval, operation: @escaping () async throws -> Void) async rethrows {
    ILOG("Delaying operation for \(duration) seconds")
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    try await operation()
    ILOG("Delayed operation completed")
}

private actor FileWatcherManager {
    private struct FileStatus {
        var watcher: DispatchSourceFileSystemObject
        var size: Int64
        var modificationDate: Date

        mutating func update(size: Int64? = nil,
                           modificationDate: Date? = nil,
                           timer: Timer? = nil) {
            if let size = size {
                self.size = size
            }
            if let modificationDate = modificationDate {
                self.modificationDate = modificationDate
            }
        }
    }

    private var fileStatuses: [URL: FileStatus] = [:]
    private let serialQueue: DispatchQueue

    init(label: String) {
        self.serialQueue = DispatchQueue(label: label)
    }

    func addWatcher(_ source: DispatchSourceFileSystemObject,
                   for path: URL,
                   initialSize: Int64,
                   modificationDate: Date) {
        let status = FileStatus(
            watcher: source,
            size: initialSize,
            modificationDate: modificationDate
        )
        fileStatuses[path] = status
    }

    func removeWatcher(for path: URL) {
        if let status = fileStatuses[path] {
            status.watcher.cancel()
        }
        fileStatuses[path] = nil
    }

    func updateFileStatus(for path: URL, size: Int64? = nil, modificationDate: Date? = nil, timer: Timer? = nil) {
        fileStatuses[path]?.update(size: size, modificationDate: modificationDate, timer: timer)
    }

    func getFileStatus(for path: URL) -> (size: Int64, modificationDate: Date)? {
        guard let status = fileStatuses[path] else { return nil }
        return (status.size, status.modificationDate)
    }

    func isWatching(_ path: URL) -> Bool {
        guard let status = fileStatuses[path] else { return false }
        return !status.watcher.isCancelled
    }

    func hasActiveWatchers() -> Bool {
        return !fileStatuses.isEmpty
    }

    func getWatchedPaths() -> [URL] {
        Array(fileStatuses.keys)
    }

    func createFileSystemSource(
        fileDescriptor: Int32,
        eventMask: DispatchSource.FileSystemEvent,
        eventHandler: @escaping () -> Void,
        cancelHandler: @escaping () -> Void
    ) -> DispatchSourceFileSystemObject {
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: eventMask,
            queue: serialQueue
        )

        source.setEventHandler(handler: eventHandler)
        source.setCancelHandler(handler: cancelHandler)

        return source
    }
}

public extension Notification.Name {
    public static let BIOSFileFound = Notification.Name("BIOSFileFound")
}

extension DirectoryWatcher {
    /// Check if a path should be watched based on the options
    func shouldWatchPath(_ path: URL) -> Bool {
        // First check exclusions
        if options.excludedPaths.contains(where: { path.path.hasPrefix($0.path) }) {
            return false
        }

        // If we have allowed paths, check if this path is under one of them
        if !options.allowedPaths.isEmpty {
            return options.allowedPaths.contains(where: { path.path.hasPrefix($0.path) })
        }

        // If no allowed paths specified, watch everything (except excluded)
        return true
    }
}
