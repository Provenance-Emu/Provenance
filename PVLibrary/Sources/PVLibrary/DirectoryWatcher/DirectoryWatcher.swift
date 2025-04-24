//
//  DirectoryWatcher.swift
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

import Foundation
import PVLogging
import PVEmulatorCore
import PVFileSystem
@_exported import PVSupport
import SWCompression
@_exported import ZipArchive
import Combine
import Observation

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
    static let PVArchiveInflationFailed = NSNotification.Name("PVArchiveInflationFailedNotification")
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
    private let serialQueue = DispatchQueue(label: "org.provenance-emu.provenance.serialExtractorQueue")

    /// The extractors for the supported archive types
    private let extractors: [ArchiveType: ArchiveExtractor] = [
        .zip: ZipExtractor(),
        .sevenZip: SevenZipExtractor(),
        .tar: TarExtractor(),
        .bzip2: BZip2Extractor(),
        .gzip: GZipExtractor()
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
        ILOG("Checked if watching file: \(path.lastPathComponent), result: \(isWatching)")
        return isWatching
    }

    public func isWatchingAnyFile() async -> Bool {
        return await !watcherManager.hasActiveWatchers()
    }

    /// Extract an archive from a file path
    public func extractArchive(at filePath: URL) async throws {
        ILOG("Starting archive extraction for file: \(filePath.path)")
        stopWatchingFile(at: filePath)
        //stopMonitoring() // Stop monitoring to avoid interference

//        defer {
//            Task {
//                ILOG("Scheduling delayed start of monitoring after extraction")
//                try? await delay(2) {
//                    do {
//                        try self.startMonitoring()
//                    } catch {
//                        ELOG("Error starting monitoring after extraction: \(error.localizedDescription)")
//                    }
//                }
//            }
//        }

        guard !filePath.path.contains("MACOSX"),
              FileManager.default.fileExists(atPath: filePath.path) else {
            ILOG("Invalid file path or file doesn't exist: \(filePath.path)")
            return
        }

        guard let archiveType = ArchiveType(rawValue: filePath.pathExtension.lowercased()),
              let extractor = extractors[archiveType] else {
            ILOG("Unsupported archive type or no extractor available for: \(filePath.pathExtension)")
            return
        }

        do {
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

            let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)

            var extractedFiles: [URL] = []
            for try await extractedFile in extractor.extract(at: filePath, to: tempDirectory, progress: { progress in
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

            try await FileManager.default.removeItem(at: filePath)
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

            // Move files to the watched directory
            let movedFiles = try await moveExtractedFiles(sortedFiles, from: tempDirectory, to: watchedDirectory)

            // Notify about the completed files
            completedFilesContinuation?.yield(movedFiles)

            // Clean up temporary directory
            try await FileManager.default.removeItem(at: tempDirectory)
        } catch {
            ELOG("Error during archive extraction: \(error.localizedDescription)")
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
        ILOG("Processing archive: \(url.lastPathComponent)")
        Task {
            try? await extractArchive(at: url)
        }
    }

    private func processNonArchive(at url: URL) {
        ILOG("Processing non-archive file: \(url.lastPathComponent)")
        completedFilesContinuation?.yield([url])
    }

    private func processFile(at url: URL) {
        ILOG("Processing file: \(url.path)")

        // Check if this is a BIOS file first
        if isBIOSFile(url) {
            ILOG("Found BIOS file: \(url.lastPathComponent)")
            // Don't decompress, just notify the BIOS watcher
            NotificationCenter.default.post(name: .BIOSFileFound, object: url)
            completedFilesContinuation?.yield([url])
            return
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
        ILOG("Checked if file is archive: \(url.lastPathComponent), result: \(result)")
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

    /// Process existing archives
    func processExistingArchives() {
        ILOG("Starting to process existing archives")
        Task.detached {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: self.watchedDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                ILOG("Found \(contents.count) items in directory: \(self.watchedDirectory)")
                for file in contents where Extensions.archiveExtensions.contains(file.pathExtension.lowercased()) {
                    ILOG("Processing existing archive: \(file.lastPathComponent)")
                    try await self.extractArchive(at: file)
                }
                ILOG("Finished processing existing archives")
            } catch {
                ELOG("Error processing existing archives: \(error.localizedDescription)")
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
            await contents.filter(isValidFile).asyncForEach { file in
                if await !isWatchingFile(at: file) {
                    ILOG("Starting to watch new file: \(file.lastPathComponent)")
                    watchFile(at: file)
                }
            }
            cleanupNonexistentFileWatchers()

        } catch {
            ELOG("Error handling file system event: \(error.localizedDescription)")
        }
    }

    /// Check if a file is valid
    func isValidFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        let isValid = !filename.starts(with: ".") && !url.path.contains("_MACOSX") && filename != "0"
        ILOG("Checked if file is valid: \(filename), result: \(isValid)")
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
        var checkCount = 0

        while checkCount < 30 { // Check for up to 1 minute (30 * 2 seconds)
            do {
                try await Task.sleep(for: .seconds(2))

                // Check if we're still watching this file
                guard await watcherManager.isWatching(path) else {
                    ILOG("File watcher removed for: \(path.lastPathComponent)")
                    break
                }

                await checkFileStatus(at: path)
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

        let attributes = try? FileManager.default.attributesOfItem(atPath: path.path)
        let currentSize = attributes?[.size] as? Int64 ?? 0

        // If file size hasn't changed for a while, process it
        if currentSize > 0 && currentSize == status.size {
            ILOG("File appears complete, starting processing: \(path.lastPathComponent)")
            processFile(at: path)
            await watcherManager.removeWatcher(for: path)
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
                    // Delay starting the extraction to allow the file system to settle
                    ILOG("Scheduling delayed extraction for file: \(destinationURL.lastPathComponent)")
                    try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
                    try await self.extractArchive(at: destinationURL)
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

extension Notification.Name {
    static let BIOSFileFound = Notification.Name("BIOSFileFound")
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
