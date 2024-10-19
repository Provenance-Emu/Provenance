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

extension FileManager {
    func removeItem(at url: URL) async throws {
        try await Task {
            try self.removeItem(at: url)
        }.value
    }
}

public typealias PVExtractionStartedHandler = (URL) -> Void
public typealias PVExtractionUpdatedHandler = (URL, Int, Int, Float) -> Void
public typealias PVExtractionCompleteHandler = ([URL]?) -> Void

public extension NSNotification.Name {
    static let PVArchiveInflationFailed = NSNotification.Name("PVArchiveInflationFailedNotification")
}

@Observable
public final class DirectoryWatcher {
    private let watchedDirectory: URL
    private let extractionStartedHandler: PVExtractionStartedHandler?
    private let extractionUpdatedHandler: PVExtractionUpdatedHandler?
    private let extractionCompleteHandler: PVExtractionCompleteHandler?

    private var dispatchSource: DispatchSourceFileSystemObject?
    private let serialQueue = DispatchQueue(label: "org.provenance-emu.provenance.serialExtractorQueue")

    private var previousContents: Set<URL> = []
    private var unzippedFiles: [URL] = []

    private let extractors: [ArchiveType: ArchiveExtractor] = [
        .zip: ZipExtractor(),
        .sevenZip: SevenZipExtractor()
    ]

    public init(directory: URL,
                extractionStartedHandler: PVExtractionStartedHandler? = nil,
                extractionUpdatedHandler: PVExtractionUpdatedHandler? = nil,
                extractionCompleteHandler: PVExtractionCompleteHandler? = nil) {
        self.watchedDirectory = directory
        self.extractionStartedHandler = extractionStartedHandler
        self.extractionUpdatedHandler = extractionUpdatedHandler
        self.extractionCompleteHandler = extractionCompleteHandler

        createDirectoryIfNeeded()
        processExistingArchives()
    }

    private func createDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: watchedDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            DLOG("Unable to create directory at: \(watchedDirectory.path), because: \(error.localizedDescription)")
        }
    }

    private func processExistingArchives() {
        Task {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: watchedDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                for file in contents where Extensions.archiveExtensions.contains(file.pathExtension.lowercased()) {
                    await extractArchive(at: file)
                }
            } catch {
                ELOG("Error processing existing archives: \(error.localizedDescription)")
            }
        }
    }

    public func startMonitoring() {
        DLOG("Start Monitoring \(watchedDirectory.path)")
        stopMonitoring()

        let fileDescriptor = open(watchedDirectory.path, O_EVTONLY)

        dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: serialQueue)

        dispatchSource?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }

        dispatchSource?.setCancelHandler {
            close(fileDescriptor)
        }

        dispatchSource?.resume()
        triggerInitialImport()
    }

    private func handleFileSystemEvent() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: watchedDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            let newContents = Set(contents).subtracting(previousContents)

            for file in newContents where isValidFile(file) {
                watchFile(at: file)
            }

            previousContents = Set(contents)
        } catch {
            ELOG("Error handling file system event: \(error.localizedDescription)")
        }
    }

    private func isValidFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        return !filename.starts(with: ".") && !url.path.contains("_MACOSX") && filename != "0"
    }

    private func triggerInitialImport() {
        let triggerPath = watchedDirectory.appendingPathComponent("0")
        do {
            try "0".write(to: triggerPath, atomically: false, encoding: .utf8)
            try FileManager.default.removeItem(at: triggerPath)
        } catch {
            ELOG("Error triggering initial import: \(error.localizedDescription)")
        }
    }

    public func stopMonitoring() {
        DLOG("Stop Monitoring \(watchedDirectory.path)")
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    private func watchFile(at path: URL) {
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
                    await self.extractArchive(at: path)
                }
            }
        } else {
            DirectoryWatcher.handlerQueue.async {
                self.extractionCompleteHandler?([path])
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

    static var handlerQueue: DispatchQueue {
        .main
    }

    public func extractArchive(at filePath: URL) async {
        guard !filePath.path.contains("MACOSX"),
              FileManager.default.fileExists(atPath: filePath.path) else {
            return
        }

        guard let archiveType = ArchiveType(rawValue: filePath.pathExtension.lowercased()),
              let extractor = extractors[archiveType] else {
            startMonitoring()
            return
        }

        DirectoryWatcher.handlerQueue.async { [weak self] in
            self?.extractionStartedHandler?(filePath)
        }

        do {
            let extractedFiles = try await extractor.extract(at: filePath, to: watchedDirectory)

            try await FileManager.default.removeItem(at: filePath)

            DirectoryWatcher.handlerQueue.async { [weak self] in
                self?.extractionCompleteHandler?(extractedFiles)
            }

            unzippedFiles.removeAll()
            delayedStartMonitoring()
        } catch {
            ELOG("Extraction error: \(error.localizedDescription)")
            DirectoryWatcher.handlerQueue.async { [weak self] in
                self?.extractionCompleteHandler?(nil)
                NotificationCenter.default.post(name: .PVArchiveInflationFailed, object: self)
            }
            startMonitoring()
        }
    }

    private func delayedStartMonitoring() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            self.startMonitoring()
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

func delay(_ duration: TimeInterval, operation: @escaping () async -> Void) async {
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    await operation()
}
