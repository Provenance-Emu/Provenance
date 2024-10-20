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

extension FileManager {
    func removeItem(at url: URL) async throws {
        try await Task {
            try self.removeItem(at: url)
        }.value
    }
}

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

public extension NSNotification.Name {
    static let PVArchiveInflationFailed = NSNotification.Name("PVArchiveInflationFailedNotification")
}

@Observable
public final class DirectoryWatcher {
    private let watchedDirectory: URL

    private var dispatchSource: DispatchSourceFileSystemObject?
    private let serialQueue = DispatchQueue(label: "org.provenance-emu.provenance.serialExtractorQueue")
    private var fileWatchers: [URL: DispatchSourceFileSystemObject] = [:]


    private let extractors: [ArchiveType: ArchiveExtractor] = [
        .zip: ZipExtractor(),
        .sevenZip: SevenZipExtractor(),
        .tar: TarExtractor(),
        .bzip2: BZip2Extractor(),
        .gzip: GZipExtractor()
    ]

    public var extractionProgress: Double = 0

    public var extractionStatus: ExtractionStatus = .idle
    @ObservationIgnored private var statusContinuation: AsyncStream<ExtractionStatus>.Continuation?

    public var extractionStatusSequence: AsyncStream<ExtractionStatus> {
        AsyncStream { continuation in
            statusContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                self.statusContinuation = nil
            }
        }
    }

    public init(directory: URL) {
        self.watchedDirectory = directory
        createDirectoryIfNeeded()
        processExistingArchives()
        delayedStartMonitoring()
    }

    public func startMonitoring() throws {
        stopMonitoring()
        let fileDescriptor = open(watchedDirectory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { throw NSError(domain: POSIXError.errorDomain, code: Int(errno)) }

        dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: serialQueue)
        dispatchSource?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }
        dispatchSource?.setCancelHandler {
            close(fileDescriptor)
        }
        dispatchSource?.resume()
    }

    public func stopMonitoring() {
        dispatchSource?.cancel()
        dispatchSource = nil
        fileWatchers.keys.forEach { stopWatchingFile(at: $0) }
    }


    public func extractArchive(at filePath: URL) async throws {
        stopMonitoring() // Stop monitoring to avoid interference

        defer {
            Task {
                try? await delay(2) {
                    try self.startMonitoring()
                }
            }
        }

        guard !filePath.path.contains("MACOSX"),
              FileManager.default.fileExists(atPath: filePath.path) else {
            DLOG("Invalid file path or file doesn't exist: \(filePath.path)")
            return
        }

        guard let archiveType = ArchiveType(rawValue: filePath.pathExtension.lowercased()),
              let extractor = extractors[archiveType] else {
            DLOG("Unsupported archive type or no extractor available for: \(filePath.pathExtension)")
            return
        }

        do {
            updateExtractionStatus(.started(path: filePath))

            var extractedFiles: [URL] = []
            for try await extractedFile in extractor.extract(at: filePath, to: watchedDirectory) { progress in
                DLOG("Extraction progress: \(Int(progress * 100))%")
            } {
                extractedFiles.append(extractedFile)
                updateExtractionStatus(.updated(path: extractedFile))
            }

            try await FileManager.default.removeItem(at: filePath)
            updateExtractionStatus(.completed(paths: extractedFiles))
        } catch {
            ELOG("Error during archive extraction: \(error.localizedDescription)")
            // Handle the error appropriately, maybe update the UI or retry the operation
        }
    }

    private func updateExtractionStatus(_ newStatus: ExtractionStatus) {
        extractionStatus = newStatus
        statusContinuation?.yield(newStatus)
    }

    private func delayedStartMonitoring() {
        Task {
            try await delay(2) {
                try self.startMonitoring()
            }
        }
    }

    private func stopWatchingFile(at path: URL) {
        if let watcher = fileWatchers[path] {
            watcher.cancel()
            fileWatchers[path] = nil
            DLOG("Stopped watching file: \(path.lastPathComponent)")
        }
    }

    private func cleanupNonexistentFileWatchers() {
        for path in fileWatchers.keys {
            if !FileManager.default.fileExists(atPath: path.path) {
                stopWatchingFile(at: path)
            }
        }
    }
}

public extension DirectoryWatcher {

    public func isArchive(_ url: URL) -> Bool {
//        // Method 1: Using ArchiveType
//        if let fileExtension = url.pathExtension.lowercased() as String?,
//           let _ = ArchiveType(rawValue: fileExtension) {
//            return true
//        }

        // Method 2: Using installed extractors
        return extractors.keys.contains { archiveType in
            url.pathExtension.lowercased() == archiveType.rawValue
        }
    }
}

fileprivate extension DirectoryWatcher {

    func createDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: watchedDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            DLOG("Unable to create directory at: \(watchedDirectory.path), because: \(error.localizedDescription)")
        }
    }

    func processExistingArchives() {
        Task.detached {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: self.watchedDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                for file in contents where Extensions.archiveExtensions.contains(file.pathExtension.lowercased()) {
                    try await self.extractArchive(at: file)
                }
            } catch {
                ELOG("Error processing existing archives: \(error.localizedDescription)")
            }
        }
    }

    private func handleFileSystemEvent() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: watchedDirectory,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            contents.filter(isValidFile).forEach { file in
                if !isWatchingFile(at: file) {
                    watchFile(at: file)
                }
            }
            cleanupNonexistentFileWatchers()

        } catch {
            ELOG("Error handling file system event: \(error.localizedDescription)")
        }
    }

    func isValidFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        return !filename.starts(with: ".") && !url.path.contains("_MACOSX") && filename != "0"
    }

    func triggerInitialImport() throws {
        let triggerPath = watchedDirectory.appendingPathComponent("0")
        try "0".write(to: triggerPath, atomically: false, encoding: .utf8)
        try FileManager.default.removeItem(at: triggerPath)
    }

    private func watchFile(at path: URL) {
        let fileDescriptor = open(path.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            ELOG("Error opening file for watching: \(path.path), error: \(String(cString: strerror(errno)))")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: [.write, .extend], queue: serialQueue)
        source.setEventHandler { [weak self] in
            self?.checkFileProgress(at: path)
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }
        source.resume()
        fileWatchers[path] = source
    }

    private func checkFileProgress(at path: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
              let filesize = attributes[.size] as? UInt64 else {
            return
        }

        if filesize > 0 && !isFileChanging(at: path) {
            handleCompletedFile(at: path)
        }
    }

    private func handleCompletedFile(at path: URL) {
        stopWatchingFile(at: path)

        if Extensions.archiveExtensions.contains(path.pathExtension.lowercased()) {
            Task {
                try await extractArchive(at: path)
            }
        } else {
            updateExtractionStatus(.completed(paths: [path]))
        }
    }

    private func isFileChanging(at path: URL) -> Bool {
        // Wait a short time and check if the file size has changed
        Thread.sleep(forTimeInterval: 0.5)
        guard let newAttributes = try? FileManager.default.attributesOfItem(atPath: path.path),
              let newFilesize = newAttributes[.size] as? UInt64 else {
            return false
        }
        return newFilesize != (try? FileManager.default.attributesOfItem(atPath: path.path)[.size] as? UInt64)
    }

    private func isWatchingFile(at path: URL) -> Bool {
        return fileWatchers[path] != nil
    }
}


extension DirectoryWatcher {
    public func handleImportedFile(at url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            ELOG("Failed to access security scoped resource")
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(readingItemAt: url, options: .forUploading, error: &error) { (newURL) in
            do {
                let destinationURL = watchedDirectory.appendingPathComponent(newURL.lastPathComponent)
                try FileManager.default.moveItem(at: newURL, to: destinationURL)

                Task {
                    // Delay starting the extraction to allow the file system to settle
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

public extension DirectoryWatcher {
    public func extractedFilesStream(at path: URL) -> AsyncStream<[URL]> {
        AsyncStream { continuation in
            Task {
                for await status in self.extractionStatusSequence {
                    switch status {
                    case .completed(let paths):
                        continuation.yield(paths)
                    case .updated(let path):
                        continuation.yield([path])
                    case .started, .idle:
                        break
                    }
                }
                continuation.finish()
            }
        }
    }
}

func delay(_ duration: TimeInterval, operation: @escaping () async throws -> Void) async rethrows {
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    try await operation()
}
