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

public enum ExtractionStatus {
    case idle
    case started(path: URL)
    case updated(path: URL)
    case completed(paths: [URL])
}

public extension NSNotification.Name {
    static let PVArchiveInflationFailed = NSNotification.Name("PVArchiveInflationFailedNotification")
}

@Observable
public final class DirectoryWatcher {
    private let watchedDirectory: URL

    private var dispatchSource: DispatchSourceFileSystemObject?
    private let serialQueue = DispatchQueue(label: "org.provenance-emu.provenance.serialExtractorQueue")

    private var previousContents: Set<URL> = []
    private var unzippedFiles: [URL] = []

    private let extractors: [ArchiveType: ArchiveExtractor] = [
        .zip: ZipExtractor(),
        .sevenZip: SevenZipExtractor(),
        .tar: TarExtractor(),
        .bzip2: BZip2Extractor(),
        .gzip: GZipExtractor()
    ]

    public var extractionStatus: ExtractionStatus = .idle

    public init(directory: URL) {
        self.watchedDirectory = directory

        createDirectoryIfNeeded()
        processExistingArchives()
    }

    public func startMonitoring() throws {
        DLOG("Start Monitoring \(watchedDirectory.path)")
        stopMonitoring()

        let fileDescriptor = open(watchedDirectory.path, O_EVTONLY)

        dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: serialQueue)

        dispatchSource?.setEventHandler { [weak self] in
            do {
                try self?.handleFileSystemEvent()
            } catch {
                ELOG("Error handling file system event: \(error)")
            }
        }

        dispatchSource?.setCancelHandler {
            close(fileDescriptor)
        }

        dispatchSource?.resume()
        try triggerInitialImport()
    }


    public func stopMonitoring() {
        DLOG("Stop Monitoring \(watchedDirectory.path)")
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    static var handlerQueue: DispatchQueue {
        .global(qos: .utility)
    }

    public func extractArchive(at filePath: URL) async throws {
        guard !filePath.path.contains("MACOSX"),
              FileManager.default.fileExists(atPath: filePath.path) else {
            return
        }

        guard let archiveType = ArchiveType(rawValue: filePath.pathExtension.lowercased()),
              let extractor = extractors[archiveType] else {
            try startMonitoring()
            return
        }

        extractionStatus = .started(path: filePath)

        do {
            var extractedFiles: [URL] = []
            for try await extractedFile in extractor.extract(at: filePath, to: watchedDirectory) {
                extractedFiles.append(extractedFile)
                extractionStatus = .updated(path: extractedFile)
            }

            try await FileManager.default.removeItem(at: filePath)

            extractionStatus = .completed(paths: extractedFiles)

            unzippedFiles.removeAll()
            delayedStartMonitoring()
        } catch {
            ELOG("Extraction error: \(error.localizedDescription)")
            DirectoryWatcher.handlerQueue.async {
                NotificationCenter.default.post(name: .PVArchiveInflationFailed, object: self)
            }
            try startMonitoring()
        }
    }


    private func delayedStartMonitoring() {
        Task {
            try await delay(2) {
                try self.startMonitoring()
            }
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

    func handleFileSystemEvent() throws {
        let contents = try FileManager.default.contentsOfDirectory(at: watchedDirectory,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        let newContents = Set(contents).subtracting(previousContents)

        newContents.filter( {isValidFile($0)} ).forEach { file in
            watchFile(at: file)
        }

        previousContents = Set(contents)
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

    func watchFile(at path: URL) {
        DLOG("Start watching \(path.lastPathComponent)")

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
              let filesize = attributes[.size] as? UInt64 else {
            ELOG("Error getting file attributes for \(path.path)")
            return
        }

        let userInfo: [String: Any] = ["path": path, "filesize": filesize, "wasZeroBefore": false]
        DispatchQueue.main.async { [weak self] in
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] timer in
                self?.checkFileProgress(timer)
            }
        }
    }

    @objc private func checkFileProgress(_ timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: Any],
              let path = userInfo["path"] as? URL,
              let previousFilesize = userInfo["filesize"] as? UInt64,
              FileManager.default.fileExists(atPath: path.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
              let currentFilesize = attributes[.size] as? UInt64 else {
            return
        }

        let wasZeroBefore = userInfo["wasZeroBefore"] as? Bool ?? false
        let sizeHasntChanged = previousFilesize == currentFilesize

        if sizeHasntChanged && (currentFilesize > 0 || wasZeroBefore) {
            handleCompletedFile(at: path)
        } else {
            scheduleNextCheck(for: path, currentFilesize: currentFilesize)
        }
    }

    private func handleCompletedFile(at path: URL) {
        if Extensions.archiveExtensions.contains(path.pathExtension) {
            serialQueue.async {
                Task {
                    try await self.extractArchive(at: path)
                }
            }
        } else {
            DirectoryWatcher.handlerQueue.async {
                self.extractionStatus = .completed(paths: [path])
            }
        }
    }

    private func scheduleNextCheck(for path: URL, currentFilesize: UInt64) {
        let newUserInfo: [String: Any] = [
            "path": path,
            "filesize": currentFilesize,
            "wasZeroBefore": currentFilesize == 0
        ]
        Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(checkFileProgress(_:)), userInfo: newUserInfo, repeats: false)
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

func delay(_ duration: TimeInterval, operation: @escaping () async throws -> Void) async rethrows {
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    try await operation()
}
