//
//  PVLogFileManager.swift
//  PVLogging
//
//  Created by Joseph Mattiello on 3/30/26.
//  Copyright 2025 Provenance Emu. All rights reserved.
//
//  Subscribes to PVLogPublisher and writes log entries to date-stamped
//  files in Library/Logs/Provenance/. Rotates when a file exceeds
//  maxFileSize and retains at most maxFileCount files.

import Foundation
#if canImport(Combine)
import Combine
#endif

/// Manages writing PVLogPublisher entries to a rotating set of log files on disk.
///
/// Usage:
/// ```swift
/// PVLogFileManager.shared.startLogging()
/// ```
/// Files are written to `<Library>/Logs/Provenance/session_YYYY-MM-DD_HH-mm-ss.log`.
public final class PVLogFileManager: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = PVLogFileManager()

    // MARK: - Configuration

    /// Directory where log files are stored.
    public var logsDirectory: URL = {
        if let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            return lib.appendingPathComponent("Logs/Provenance")
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("Provenance/Logs")
    }()

    /// Maximum size of a single log file before rotation (default: 2 MB).
    public var maxFileSize: Int64 = 2 * 1024 * 1024

    /// Maximum number of retained log files (default: 10).
    public var maxFileCount: Int = 10

    // MARK: - Private State

    private var currentFileHandle: FileHandle?
    private var currentFileURL: URL?
    private var currentFileSize: Int64 = 0
    private let queue = DispatchQueue(label: "com.provenance.logfilemanager", qos: .utility)
#if canImport(Combine)
    private var cancellable: AnyCancellable?
#endif

    private init() {}

    // MARK: - Public API

    /// Returns true if file logging is currently active.
    public var isLogging: Bool {
#if canImport(Combine)
        queue.sync { cancellable != nil }
#else
        queue.sync { currentFileHandle != nil }
#endif
    }

    /// The URL of the file being written to in the current session, or `nil` if not logging.
    public var currentSessionURL: URL? { queue.sync { currentFileURL } }

    /// Begin writing log entries to disk. Creates a new session log file.
    public func startLogging() {
        queue.async { [self] in
#if canImport(Combine)
            guard cancellable == nil else { return }
#else
            guard currentFileHandle == nil else { return }
#endif
            createDirectory()
            openNewFile()

#if canImport(Combine)
            let localQueue = queue
            cancellable = PVLogPublisher.shared.logPublisher
                .receive(on: localQueue)
                .sink { [weak self] entry in
                    self?.write(entry: entry)
                }
#endif
        }
    }

    /// Stop writing to disk and close the current log file.
    public func stopLogging() {
        queue.async { [self] in
#if canImport(Combine)
            cancellable?.cancel()
            cancellable = nil
#endif
            currentFileHandle?.closeFile()
            currentFileHandle = nil
            currentFileURL = nil
            currentFileSize = 0
        }
    }

    // MARK: - File Listing

    /// Returns all log files sorted by modification date, newest first.
    public func logFiles() -> [URL] {
        createDirectory()
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "log" }
            .sorted {
                let d0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d0 > d1
            }
    }

    /// Deletes a specific log file.
    public func deleteFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    /// Deletes all log files in the logs directory.
    public func deleteAllFiles() {
        for url in logFiles() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Private Helpers

    private func createDirectory() {
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }

    private func openNewFile() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "session_\(formatter.string(from: Date())).log"
        let url = logsDirectory.appendingPathComponent(filename)

        FileManager.default.createFile(atPath: url.path, contents: nil)
        currentFileHandle = try? FileHandle(forWritingTo: url)
        currentFileURL = url
        currentFileSize = 0

        // Write header
        let header = "=== Provenance Log Session ===\nStarted: \(Date())\n\n"
        if let data = header.data(using: .utf8) {
            currentFileHandle?.write(data)
            currentFileSize += Int64(data.count)
        }
    }

    private func write(entry: LogEntry) {
        let line = "[\(entry.formattedTimestamp)] [\(entry.level.name.uppercased())] (\(entry.category)) \(entry.message)\n"
        guard let data = line.data(using: .utf8) else { return }

        currentFileHandle?.write(data)
        currentFileSize += Int64(data.count)

        if currentFileSize >= maxFileSize {
            rotate()
        }
    }

    private func rotate() {
        currentFileHandle?.closeFile()
        currentFileHandle = nil
        currentFileURL = nil
        currentFileSize = 0

        pruneOldFiles()
        openNewFile()
    }

    private func pruneOldFiles() {
        let files = logFiles()
        guard files.count >= maxFileCount else { return }
        // Keep the newest (maxFileCount - 1) so the newly opened file fits
        let toDelete = files.suffix(from: maxFileCount - 1)
        for url in toDelete {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
