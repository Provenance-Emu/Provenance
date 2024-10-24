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
}

let TIMER_DELAY_IN_SECONDS = 2.0

/// The directory watcher class
@Observable
public final class DirectoryWatcher {
    
    private let watchedDirectory: URL

    /// The dispatch source for the file system object
    private var dispatchSource: DispatchSourceFileSystemObject?
    /// The serial queue for the extractor
    private let serialQueue = DispatchQueue(label: "org.provenance-emu.provenance.serialExtractorQueue")
    /// The file watchers for the files being watched
    private var fileWatchers: [URL: DispatchSourceFileSystemObject] = [:]
    private var lastKnownSizes: [URL: Int64] = [:]
    private var fileTimers: [URL: Timer] = [:]
    private var lastKnownModificationDates: [URL: Date] = [:]

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
    @ObservationIgnored private var statusContinuation: AsyncStream<ExtractionStatus>.Continuation?

    /// A sequence of extraction statuses
    public var extractionStatusSequence: AsyncStream<ExtractionStatus> {
        AsyncStream { continuation in
            statusContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                self.statusContinuation = nil
            }
        }
    }

    @ObservationIgnored private var completedFilesContinuation: AsyncStream<[URL]>.Continuation?

    /// A sequence of completed files
    public var completedFilesSequence: AsyncStream<[URL]> {
        AsyncStream { continuation in
            completedFilesContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                self.completedFilesContinuation = nil
            }
        }
    }

    /// Initialize the directory watcher with a directory
    public init(directory: URL) {
        self.watchedDirectory = directory
        ILOG("DirectoryWatcher initialized with directory: \(directory.path)")
        createDirectoryIfNeeded()
        processExistingArchives()
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
            self?.handleFileSystemEvent()
        }
        dispatchSource?.setCancelHandler {
            ILOG("Closing file descriptor for directory: \(self.watchedDirectory.path)")
            close(fileDescriptor)
        }
        dispatchSource?.resume()
        ILOG("Monitoring started for directory: \(watchedDirectory.path)")
    }

    /// Stop monitoring the directory for changes
    public func stopMonitoring() {
        ILOG("Stopping monitoring for directory: \(watchedDirectory.path)")
        dispatchSource?.cancel()
        dispatchSource = nil
        fileWatchers.keys.forEach { stopWatchingFile(at: $0) }
        ILOG("Monitoring stopped for directory: \(watchedDirectory.path)")
    }


    /// Extract an archive from a file path
    public func extractArchive(at filePath: URL) async throws {
        ILOG("Starting archive extraction for file: \(filePath.path)")
        stopMonitoring() // Stop monitoring to avoid interference

        defer {
            Task {
                ILOG("Scheduling delayed start of monitoring after extraction")
                try? await delay(2) {
                    try self.startMonitoring()
                }
            }
        }

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
            updateExtractionStatus(.started(path: filePath))

            let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)

            var extractedFiles: [URL] = []
            for try await extractedFile in extractor.extract(at: filePath, to: tempDirectory) { progress in
                ILOG("Extraction progress for \(filePath.lastPathComponent): \(Int(progress * 100))%")
                self.extractionProgress = progress
            } {
                extractedFiles.append(extractedFile)
                updateExtractionStatus(.updated(path: extractedFile))
                ILOG("Extracted file: \(extractedFile.path)")
            }

            try await FileManager.default.removeItem(at: filePath)
            updateExtractionStatus(.completed(paths: extractedFiles))
            ILOG("Archive extraction completed for file: \(filePath.path)")

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
            // Handle the error appropriately, maybe update the UI or retry the operation
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
        fileWatchers[path]?.cancel()
        fileWatchers[path] = nil
        fileTimers[path]?.invalidate()
        ILOG("Timer invalidated for file: \(path.lastPathComponent)")
        fileTimers[path] = nil
        lastKnownSizes[path] = nil
        lastKnownModificationDates[path] = nil
        ILOG("File watcher, timer, last known size, and last known modification date removed for: \(path.lastPathComponent)")
    }

    /// Cleanup nonexistent file watchers
    private func cleanupNonexistentFileWatchers() {
        ILOG("Starting cleanup of nonexistent file watchers")
        for path in fileWatchers.keys {
            if !FileManager.default.fileExists(atPath: path.path) {
                stopWatchingFile(at: path)
                ILOG("Removed watcher for nonexistent file: \(path.lastPathComponent)")
            }
        }
        ILOG("Finished cleanup of nonexistent file watchers")
    }
}

public extension DirectoryWatcher {

    /// Check if a file is an archive
    public func isArchive(_ url: URL) -> Bool {
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
                ILOG("Found \(contents.count) items in directory")
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
    private func handleFileSystemEvent() {
        ILOG("Handling file system event for directory: \(watchedDirectory.path)")
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: watchedDirectory,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            ILOG("Found \(contents.count) items in directory after file system event")
            contents.filter(isValidFile).forEach { file in
                if !isWatchingFile(at: file) {
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
        ILOG("Starting to watch file: \(path.lastPathComponent)")
        let fileDescriptor = open(path.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            ELOG("Error opening file for watching: \(path.path), error: \(String(cString: strerror(errno)))")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor,
                                                               eventMask: [.write, .extend],
                                                               queue: serialQueue)
        source.setEventHandler { [weak self] in
            self?.handleFileChange(at: path)
        }
        source.setCancelHandler {
            ILOG("Closing file descriptor for file: \(path.lastPathComponent)")
            close(fileDescriptor)
        }
        source.resume()
        fileWatchers[path] = source

        // Start a repeating task to check if the file has stopped changing
        Task {
            ILOG("Starting repeating task for file: \(path.lastPathComponent)")
            var checkCount = 0
            while checkCount < 30 { // Check for up to 1 minute (30 * 2 seconds)
                await try Task.sleep(for: .seconds(2))
                ILOG("Repeating task fired for file: \(path.lastPathComponent)")
                await MainActor.run {
                    self.checkFileStatus(at: path)
                }
                checkCount += 1
                if fileWatchers[path] == nil {
                    ILOG("File watcher removed for: \(path.lastPathComponent)")
                    break
                }
            }
            ILOG("Repeating task ended for file: \(path.lastPathComponent)")
        }

        ILOG("File watcher and repeating task set up for: \(path.lastPathComponent)")
    }

    private func handleFileChange(at path: URL) {
        ILOG("File change detected for: \(path.lastPathComponent)")
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            let currentSize = attributes[.size] as? Int64 ?? 0
            ILOG("Current size of changed file \(path.lastPathComponent): \(currentSize)")
        } catch {
            ELOG("Error getting attributes for changed file: \(error)")
        }
        // Reset the timer when the file changes
        fileTimers[path]?.invalidate()
        ILOG("Timer invalidated for file: \(path.lastPathComponent)")
        fileTimers[path] = Timer.scheduledTimer(withTimeInterval: TIMER_DELAY_IN_SECONDS, repeats: true) { [weak self] _ in
            ILOG("New timer fired for file: \(path.lastPathComponent)")
            self?.checkFileStatus(at: path)
        }
        ILOG("New timer scheduled for file: \(path.lastPathComponent)")
    }

    private func checkFileStatus(at path: URL) {
        ILOG("Checking file status for: \(path.lastPathComponent)")
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            let currentSize = attributes[.size] as? Int64 ?? 0
            let currentModificationDate = attributes[.modificationDate] as? Date

            ILOG("Current size of file \(path.lastPathComponent): \(currentSize)")
            ILOG("Current modification date of file \(path.lastPathComponent): \(String(describing: currentModificationDate))")

            if let lastSize = lastKnownSizes[path] {
                ILOG("Last known size of file \(path.lastPathComponent): \(lastSize)")
            } else {
                ILOG("No last known size for file \(path.lastPathComponent)")
            }

            if let lastModDate = lastKnownModificationDates[path] {
                ILOG("Last known modification date of file \(path.lastPathComponent): \(lastModDate)")
            } else {
                ILOG("No last known modification date for file \(path.lastPathComponent)")
            }

            // If the file size and modification date haven't changed in 2 seconds, consider it done
            if let lastSize = lastKnownSizes[path],
               let lastModDate = lastKnownModificationDates[path],
               lastSize == currentSize,
               lastModDate == currentModificationDate {
                ILOG("File upload completed: \(path.lastPathComponent)")
                stopWatchingFile(at: path)
                handleCompletedFile(at: path)
            } else {
                if lastKnownSizes[path] != currentSize {
                    ILOG("File size changed for \(path.lastPathComponent)")
                }
                if lastKnownModificationDates[path] != currentModificationDate {
                    ILOG("File modification date changed for \(path.lastPathComponent)")
                }
                lastKnownSizes[path] = currentSize
                lastKnownModificationDates[path] = currentModificationDate
                VLOG("File still uploading: \(path.lastPathComponent), current size: \(currentSize)")
            }
        } catch {
            ELOG("Error checking file status: \(error)")
            stopWatchingFile(at: path)
        }
    }

    private func handleCompletedFile(at path: URL) {
        ILOG("Handling completed file: \(path.lastPathComponent)")
        if Extensions.archiveExtensions.contains(path.pathExtension.lowercased()) {
            ILOG("Completed file is an archive, starting extraction: \(path.lastPathComponent)")
            Task {
                try await extractArchive(at: path)
            }
        } else {
            ILOG("Completed file is not an archive: \(path.lastPathComponent)")
            updateExtractionStatus(.completed(paths: [path]))
            completedFilesContinuation?.yield([path])
        }
    }

    private func isWatchingFile(at path: URL) -> Bool {
        let isWatching = fileWatchers[path] != nil
        ILOG("Checked if watching file: \(path.lastPathComponent), result: \(isWatching)")
        return isWatching
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
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
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
    public func extractedFilesStream(at path: URL) -> AsyncStream<[URL]> {
        ILOG("Creating extracted files stream for path: \(path.path)")
        return AsyncStream { continuation in
            Task {
                for await status in self.extractionStatusSequence {
                    switch status {
                    case .completed(let paths):
                        ILOG("Extraction completed, yielding paths: \(paths)")
                        continuation.yield(paths)
                    case .updated(let path):
                        ILOG("Extraction updated, yielding path: \(path)")
                        continuation.yield([path])
                    case .started, .idle:
                        ILOG("Extraction status changed to \(status)")
                        break
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
