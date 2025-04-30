//
//  CloudSyncLogManager.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/28/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import Combine
import CloudKit
import os.log

/// Log level for cloud sync operations
public enum CloudLogLevel: String, Codable {
    case debug
    case info
    case warning
    case error
    case verbose
}

/// A log entry from the cloud sync system
public struct CloudSyncLogEntry {
    /// The timestamp of the log entry
    public let timestamp: Date

    /// The message of the log entry
    public let message: String

    /// The log level
    public let level: CloudLogLevel

    /// The sync operation type
    public let operation: SyncOperationType

    /// The file path if applicable
    public let filePath: String?

    /// The sync provider type
    public let provider: SyncProviderType

    /// Initialize a new CloudSyncLogEntry
    public init(
        timestamp: Date,
        message: String,
        level: CloudLogLevel,
        operation: SyncOperationType = .unknown,
        filePath: String? = nil,
        provider: SyncProviderType = .unknown
    ) {
        self.timestamp = timestamp
        self.message = message
        self.level = level
        self.operation = operation
        self.filePath = filePath
        self.provider = provider
    }

    /// Types of sync operations
    public enum SyncOperationType: String, Codable {
        case upload
        case download
        case delete
        case conflict
        case metadata
        case initialization
        case completion
        case error
        case unknown
    }

    /// Types of sync providers
    public enum SyncProviderType: String, Codable {
        case cloudKit
        case iCloudDrive
        case unknown
    }
}

/// Manages cloud sync logs, providing access to historical sync operations
public class CloudSyncLogManager {
    /// Shared instance for accessing the log manager
    public static let shared = CloudSyncLogManager()

    /// The file URL for the sync log file
    private let syncLogFileURL: URL

    /// In-memory cache of recent log entries
    private var recentLogEntries: [CloudSyncLogEntry] = []
    private let maxCachedEntries = 100
    /// Queue for synchronizing access to recentLogEntries
    private let logEntriesQueue = DispatchQueue(label: "com.provenance.cloudsynclogmanager.logEntriesQueue")

    /// Publishers for sync events
    public let syncEventPublisher = PassthroughSubject<CloudSyncLogEntry, Never>()

    /// Subscribers for notifications
    private var subscribers = Set<AnyCancellable>()

    /// Initialize the CloudSyncLogManager
    private init() {
        // Get the logs directory in the app's container
        let fileManager = FileManager.default
        let logsDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)

        // Create the logs directory if it doesn't exist
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }

        // Set the sync log file URL
        syncLogFileURL = logsDirectory.appendingPathComponent("cloud_sync.log")

        // Create the log file if it doesn't exist
        if !fileManager.fileExists(atPath: syncLogFileURL.path) {
            fileManager.createFile(atPath: syncLogFileURL.path, contents: nil)
        }

        // Set up notification observers
        setupNotificationObservers()

        // Log initialization
        logSyncOperation(
            "CloudSyncLogManager initialized",
            level: .info,
            operation: .initialization,
            provider: .unknown
        )
    }

    /// Set up notification observers for sync events
    private func setupNotificationObservers() {
        // CloudKit sync notifications
        NotificationCenter.default.publisher(for: .iCloudSyncStarted)
            .sink { [weak self] notification in
                self?.handleSyncStarted(notification: notification, provider: .cloudKit)
            }
            .store(in: &subscribers)

        NotificationCenter.default.publisher(for: .iCloudSyncCompleted)
            .sink { [weak self] notification in
                self?.handleSyncCompleted(notification: notification, provider: .cloudKit)
            }
            .store(in: &subscribers)

        NotificationCenter.default.publisher(for: .iCloudSyncFailed)
            .sink { [weak self] notification in
                self?.handleSyncFailed(notification: notification, provider: .cloudKit)
            }
            .store(in: &subscribers)

        NotificationCenter.default.publisher(for: .iCloudSyncEnabled)
            .sink { [weak self] _ in
                self?.logSyncOperation(
                    "iCloud sync enabled",
                    level: .info,
                    operation: .initialization,
                    provider: .unknown
                )
            }
            .store(in: &subscribers)

        NotificationCenter.default.publisher(for: .iCloudSyncDisabled)
            .sink { [weak self] _ in
                self?.logSyncOperation(
                    "iCloud sync disabled",
                    level: .info,
                    operation: .initialization,
                    provider: .unknown
                )
            }
            .store(in: &subscribers)

        // iCloud Drive specific notifications
        #if !os(tvOS) // No Cloud Drive on tvOS
        NotificationCenter.default.publisher(for: iCloudDriveSync.iCloudFileDownloaded)
            .sink { [weak self] notification in
                self?.handleFileDownloaded(notification: notification)
            }
            .store(in: &subscribers)

        NotificationCenter.default.publisher(for: iCloudDriveSync.iCloudFileUploaded)
            .sink { [weak self] notification in
                self?.handleFileUploaded(notification: notification)
            }
            .store(in: &subscribers)

        NotificationCenter.default.publisher(for: iCloudDriveSync.iCloudFileDeleted)
            .sink { [weak self] notification in
                self?.handleFileDeleted(notification: notification)
            }
            .store(in: &subscribers)

        NotificationCenter.default.publisher(for: iCloudDriveSync.iCloudFileRecoveryError)
            .sink { [weak self] notification in
                self?.handleFileRecoveryError(notification: notification)
            }
            .store(in: &subscribers)
        #endif
    }

    // MARK: - Notification Handlers

    private func handleSyncStarted(notification: Notification, provider: CloudSyncLogEntry.SyncProviderType) {
        let operation = notification.userInfo?["operation"] as? String ?? "Unknown operation"
        logSyncOperation(
            "Started sync operation: \(operation)",
            level: .info,
            operation: .initialization,
            provider: provider
        )
    }

    private func handleSyncCompleted(notification: Notification, provider: CloudSyncLogEntry.SyncProviderType) {
        let operation = notification.userInfo?["operation"] as? String ?? "Unknown operation"
        let bytesDownloaded = notification.userInfo?["bytesDownloaded"] as? Int64 ?? 0
        let bytesUploaded = notification.userInfo?["bytesUploaded"] as? Int64 ?? 0

        var message = "Completed sync operation: \(operation)"
        if bytesDownloaded > 0 || bytesUploaded > 0 {
            let downloadedStr = ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
            let uploadedStr = ByteCountFormatter.string(fromByteCount: bytesUploaded, countStyle: .file)
            message += " (Downloaded: \(downloadedStr), Uploaded: \(uploadedStr))"
        }

        logSyncOperation(
            message,
            level: .info,
            operation: .completion,
            provider: provider
        )
    }

    private func handleSyncFailed(notification: Notification, provider: CloudSyncLogEntry.SyncProviderType) {
        let operation = notification.userInfo?["operation"] as? String ?? "Unknown operation"
        let error = notification.userInfo?["error"] as? Error
        let errorMessage = error?.localizedDescription ?? "Unknown error"

        logSyncOperation(
            "Failed sync operation: \(operation) - Error: \(errorMessage)",
            level: .error,
            operation: .error,
            provider: provider
        )
    }

    private func handleFileDownloaded(notification: Notification) {
        if let fileURL = notification.userInfo?["fileURL"] as? URL {
            logSyncOperation(
                "Downloaded file: \(fileURL.lastPathComponent)",
                level: .info,
                operation: .download,
                filePath: fileURL.path,
                provider: .iCloudDrive
            )
        }
    }

    private func handleFileUploaded(notification: Notification) {
        if let fileURL = notification.userInfo?["fileURL"] as? URL {
            logSyncOperation(
                "Uploaded file: \(fileURL.lastPathComponent)",
                level: .info,
                operation: .upload,
                filePath: fileURL.path,
                provider: .iCloudDrive
            )
        }
    }

    private func handleFileDeleted(notification: Notification) {
        if let fileURL = notification.userInfo?["fileURL"] as? URL {
            logSyncOperation(
                "Deleted file: \(fileURL.lastPathComponent)",
                level: .info,
                operation: .delete,
                filePath: fileURL.path,
                provider: .iCloudDrive
            )
        }
    }

    private func handleFileRecoveryError(notification: Notification) {
        if let fileURL = notification.userInfo?["fileURL"] as? URL,
           let error = notification.userInfo?["error"] as? Error {
            logSyncOperation(
                "Error recovering file \(fileURL.lastPathComponent): \(error.localizedDescription)",
                level: .error,
                operation: .error,
                filePath: fileURL.path,
                provider: .iCloudDrive
            )
        }
    }

    // MARK: - Logging Methods

    /// Log a sync operation
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - operation: The type of operation
    ///   - filePath: The file path if applicable
    ///   - provider: The sync provider type
    public func logSyncOperation(
        _ message: String,
        level: CloudLogLevel = .info,
        operation: CloudSyncLogEntry.SyncOperationType = .unknown,
        filePath: String? = nil,
        provider: CloudSyncLogEntry.SyncProviderType = .unknown
    ) {
        // Create log entry
        let entry = CloudSyncLogEntry(
            timestamp: Date(),
            message: message,
            level: level,
            operation: operation,
            filePath: filePath,
            provider: provider
        )

        // Add to in-memory cache
        addToRecentLogs(entry)

        // Publish the event
        syncEventPublisher.send(entry)

        // Write to log file
        writeToLogFile(entry)

        // Also log to system log
        switch level {
        case .debug:
            DLOG(message)
        case .info:
            ILOG(message)
        case .warning:
            WLOG(message)
        case .error:
            ELOG(message)
        case .verbose:
            VLOG(message)
        }
    }

    /// Add a log entry to the in-memory cache
    private func addToRecentLogs(_ entry: CloudSyncLogEntry) {
        logEntriesQueue.async { [weak self] in
            guard let self = self else { return }
            self.recentLogEntries.append(entry)
            if self.recentLogEntries.count > self.maxCachedEntries {
                self.recentLogEntries.removeFirst(self.recentLogEntries.count - self.maxCachedEntries)
            }
        }
    }

    /// Write a log entry to the log file
    private func writeToLogFile(_ entry: CloudSyncLogEntry) {
        // Format: [LEVEL] [TIMESTAMP] [PROVIDER] [OPERATION] MESSAGE
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = dateFormatter.string(from: entry.timestamp)

        let logLine = "[\(entry.level.rawValue.uppercased())] [\(timestamp)] [\(entry.provider.rawValue)] [\(entry.operation.rawValue)] \(entry.message)\n"

        if let data = logLine.data(using: String.Encoding.utf8) {
            do {
                // Use a new file handle for each write to avoid issues with concurrent access
                let fileHandle = try FileHandle(forWritingTo: syncLogFileURL)
                defer {
                    try? fileHandle.close()
                }

                // Seek to end and append
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            } catch {
                ELOG("Error writing to sync log file: \(error.localizedDescription)")

                // Try the fallback approach of just writing the file directly
                if let existingData = try? Data(contentsOf: syncLogFileURL) {
                    var newData = existingData
                    newData.append(data)
                    try? newData.write(to: syncLogFileURL, options: .atomic)
                }
            }
        }
    }

    /// Synchronously retrieves the recent log entries from the in-memory cache.
    /// Ensures thread safety by using the logEntriesQueue.
    public func getRecentLogEntriesSync() -> [CloudSyncLogEntry] {
        var entries: [CloudSyncLogEntry] = []
        logEntriesQueue.sync {
            // Return a copy to avoid mutations outside the queue
            entries = self.recentLogEntries
        }
        return entries
    }

    /// Get sync logs from memory and file if needed
    /// - Parameters:
    ///   - maxEntries: The maximum number of entries to return
    ///   - logTypes: The log types to include (nil for all)
    ///   - operations: The operations to include (nil for all)
    ///   - searchText: The search text to filter by (nil for no text filter)
    ///   - dateRange: The date range to filter by (nil for all dates)
    /// - Returns: An array of CloudSyncLogEntry objects
    public func getSyncLogs(
        maxEntries: Int = 100,
        logTypes: [CloudLogLevel]? = nil,
        operations: [CloudSyncLogEntry.SyncOperationType]? = nil,
        searchText: String? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) async throws -> [CloudSyncLogEntry] {
        // If we have enough recent logs in memory, use those
        // Synchronize read access to recentLogEntries
        var entries: [CloudSyncLogEntry] = []
        logEntriesQueue.sync {
            entries = self.recentLogEntries
        }

        // If we don't have enough entries in memory, read from the log file
        if entries.count < maxEntries {
            do {
                let data = try Data(contentsOf: syncLogFileURL)
                guard let logString = String(data: data, encoding: .utf8) else {
                    return entries
                }

                // Parse log entries from file
                let fileEntries = parseLogEntries(from: logString)

                // Combine with in-memory entries, remove duplicates
                var allEntries = Set(entries)
                allEntries.formUnion(fileEntries)
                entries = Array(allEntries)
            } catch {
                ELOG("Error reading sync log file: \(error.localizedDescription)")
                // Continue with what we have in memory
            }
        }

        // Apply filters
        var filteredEntries = entries

        // Filter by log type if specified
        if let logTypes = logTypes, !logTypes.isEmpty {
            filteredEntries = filteredEntries.filter { logTypes.contains($0.level) }
        }

        // Filter by operation if specified
        if let operations = operations, !operations.isEmpty {
            filteredEntries = filteredEntries.filter { operations.contains($0.operation) }
        }

        // Filter by search text if specified
        if let searchText = searchText, !searchText.isEmpty {
            filteredEntries = filteredEntries.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.filePath?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        // Filter by date range if specified
        if let dateRange = dateRange {
            filteredEntries = filteredEntries.filter { dateRange.contains($0.timestamp) }
        }

        // Sort by timestamp (newest first) and limit to maxEntries
        return filteredEntries
            .sorted(by: { $0.timestamp > $1.timestamp })
            .prefix(maxEntries)
            .map { $0 } // Convert ArraySlice to Array
    }

    /// Clear all sync logs
    public func clearSyncLogs() throws {
        // Clear in-memory cache (synchronized)
        logEntriesQueue.async { [weak self] in
            self?.recentLogEntries.removeAll()
        }

        // Delete the log file
        try FileManager.default.removeItem(at: syncLogFileURL)

        // Create a new empty log file
        FileManager.default.createFile(atPath: syncLogFileURL.path, contents: nil)

        // Log that logs were cleared
        logSyncOperation("Sync logs cleared", level: .info, operation: .metadata)
    }

    /// Parse log entries from a log string
    /// - Parameter logString: The log string to parse
    /// - Returns: An array of CloudSyncLogEntry objects
    private func parseLogEntries(from logString: String) -> [CloudSyncLogEntry] {
        // Split the log string into lines
        let lines = logString.components(separatedBy: .newlines)

        // Parse each line into a log entry
        return lines.compactMap { line -> CloudSyncLogEntry? in
            // Skip empty lines
            guard !line.isEmpty else { return nil }

            // Parse the log entry
            // Format: [LEVEL] [TIMESTAMP] [PROVIDER] [OPERATION] MESSAGE
            let components = line.components(separatedBy: "] ")
            guard components.count >= 4 else { return nil }

            // Extract the log level
            let levelString = components[0].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            guard let level = CloudLogLevel(rawValue: levelString.lowercased()) else { return nil }

            // Extract the timestamp
            let timestampString = components[1].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            guard let timestamp = dateFormatter.date(from: timestampString) else { return nil }

            // Extract provider
            let providerString = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            let provider = CloudSyncLogEntry.SyncProviderType(rawValue: providerString.lowercased()) ?? .unknown

            // Extract operation
            let operationString = components[3].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            let operation = CloudSyncLogEntry.SyncOperationType(rawValue: operationString.lowercased()) ?? .unknown

            // Extract the message
            let message = components.dropFirst(4).joined(separator: "] ")

            // Extract file path if present in the message
            var filePath: String? = nil
            if let filePathMatch = message.range(of: "file: ([^\\s]+)", options: .regularExpression) {
                // Extract the file path from the match
                let start = filePathMatch.lowerBound
                let end = filePathMatch.upperBound
                filePath = String(message[start..<end])
            }

            return CloudSyncLogEntry(
                timestamp: timestamp,
                message: message,
                level: level,
                operation: operation,
                filePath: filePath,
                provider: provider
            )
        }
    }
}

// MARK: - Hashable Conformance

extension CloudSyncLogEntry: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(message)
        hasher.combine(level.rawValue)
        hasher.combine(operation.rawValue)
        hasher.combine(filePath)
        hasher.combine(provider.rawValue)
    }

    public static func == (lhs: CloudSyncLogEntry, rhs: CloudSyncLogEntry) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
               lhs.message == rhs.message &&
               lhs.level == rhs.level &&
               lhs.operation == rhs.operation &&
               lhs.filePath == rhs.filePath &&
               lhs.provider == rhs.provider
    }
}
