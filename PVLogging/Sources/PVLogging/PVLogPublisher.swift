//
//  PVLogPublisher.swift
//  PVLogging
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(OSLog)
import OSLog
#endif

/// A Combine- and AsyncStream-based publisher for PVLogging.
///
/// Thread safety: all mutable state is protected by `NSLock` (faster than
/// `DispatchQueue.async` on the hot logging path). The class is marked
/// `@unchecked Sendable` because the lock guarantees safety across threads
/// without requiring `async`/`await` at every call site.
public final class PVLogPublisher: @unchecked Sendable {
    // MARK: - Singleton

    /// Shared instance.
    public static let shared = PVLogPublisher()

    // MARK: - Private Storage

    /// Lock protecting `recentLogs` and stream continuations.
    private let logsLock = NSLock()

    /// In-memory ring buffer of recent log entries.
    private var recentLogs: [LogEntry] = []

    /// Maximum number of entries kept in memory.
    private let maxLogCount = 2000

    // MARK: - Per-Category Level Filtering

    /// Minimum log levels per category name. Defaults to `.verbose` (log everything).
    private var categoryMinLevels: [String: LogLevel] = [:]

    /// Lock protecting `categoryMinLevels`.
    private let filterLock = NSLock()

    // MARK: - AsyncStream Support

    /// Active AsyncStream continuations keyed by their UUID.
    private var streamContinuations: [UUID: AsyncStream<LogEntry>.Continuation] = [:]

    /// Lock protecting `streamContinuations`.
    private let continuationsLock = NSLock()

    // MARK: - Combine Support

    #if canImport(Combine)
    /// Subject that publishes each log entry to Combine subscribers.
    private let logSubject = PassthroughSubject<LogEntry, Never>()

    /// Combine publisher for log entries.
    public var logPublisher: AnyPublisher<LogEntry, Never> {
        logSubject.eraseToAnyPublisher()
    }
    #endif

    // MARK: - Initialization

    private init() {}

    // MARK: - Category Name Resolution

    /// Derive a human-readable category name from a `PVLogCategory`.
    ///
    /// On Apple platforms `os.Logger` does not expose its category string
    /// directly, so we inspect the description and match against all known
    /// Provenance categories. For custom loggers outside this set the fallback
    /// is `"general"`.
    public static func categoryName(from category: PVLogCategory) -> String {
        #if canImport(OSLog)
        let desc = String(describing: category)
        // Map known categories (order: most specific first to avoid false matches)
        let knownCategories = [
            "viewcycle", "statistics", "network", "video", "audio",
            "database", "emulator", "controller", "savestate", "library", "ui", "general"
        ]
        for name in knownCategories where desc.contains(name) {
            return name
        }
        return "general"
        #else
        return category.categoryName
        #endif
    }

    // MARK: - Public Logging API

    /// Log a message with full control over all fields.
    ///
    /// Unlike the global `log()` function this method **also** writes to OSLog,
    /// making it suitable for callers that bypass the global logging functions
    /// (e.g. direct use of `PVLogPublisher` in UI code).
    public func log(
        _ message: String,
        level: LogLevel,
        category: PVLogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName: String
        if let slash = file.lastIndex(of: "/") {
            fileName = String(file[file.index(after: slash)...])
        } else {
            fileName = file
        }
        let categoryName = Self.categoryName(from: category)

        // Apply per-category filter before emitting to OSLog so noisy categories
        // are suppressed globally, not just in the in-memory viewer/streams.
        guard shouldLog(level: level, forCategory: categoryName) else { return }

        #if canImport(OSLog)
        let osLogType: OSLogType
        switch level {
        case .verbose, .debug: osLogType = .debug
        case .info: osLogType = .info
        case .warning: osLogType = .default
        case .error: osLogType = .fault
        }
        category.log(
            level: osLogType,
            "\(fileName, privacy: .public):\(function, privacy: .public):\(line, privacy: .public) - \(message, privacy: .public)"
        )
        #endif

        storeEntry(message: message, level: level, categoryName: categoryName,
                   file: fileName, function: function, line: line)
    }

    // MARK: - Internal Storage (used by global log())

    /// Store a log entry without re-emitting to OSLog.
    ///
    /// This is called by the global `log()` function in `PVLogFunctions.swift`,
    /// which has already written to OSLog. Keeping the paths separate avoids
    /// double-logging when the convenience macros are used.
    public func storeEntry(
        message: String,
        level: LogLevel,
        categoryName: String,
        file: String,
        function: String,
        line: Int
    ) {
        // Apply per-category level filter
        guard shouldLog(level: level, forCategory: categoryName) else { return }

        let entry = LogEntry(
            message: message,
            level: level,
            category: categoryName,
            timestamp: Date(),
            file: file,
            function: function,
            line: line
        )

        // Publish via Combine
        #if canImport(Combine)
        logSubject.send(entry)
        #endif

        // Publish to all active AsyncStreams
        continuationsLock.lock()
        let continuations = Array(streamContinuations.values)
        continuationsLock.unlock()
        for continuation in continuations {
            continuation.yield(entry)
        }

        // Append to ring buffer
        logsLock.lock()
        recentLogs.append(entry)
        if recentLogs.count > maxLogCount {
            recentLogs = Array(recentLogs.suffix(maxLogCount))
        }
        logsLock.unlock()
    }

    // MARK: - AsyncStream API

    /// Create an `AsyncStream` that receives every log entry going forward.
    ///
    /// Multiple streams can coexist; each receives its own copy of every entry.
    /// The stream terminates automatically when the caller's `for await` loop
    /// exits or the stream is cancelled.
    ///
    /// Example:
    /// ```swift
    /// for await entry in PVLogPublisher.shared.makeLogStream() {
    ///     print(entry.fullDescription)
    /// }
    /// ```
    public func makeLogStream() -> AsyncStream<LogEntry> {
        AsyncStream { continuation in
            let id = UUID()
            continuationsLock.lock()
            streamContinuations[id] = continuation
            continuationsLock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.continuationsLock.lock()
                self?.streamContinuations.removeValue(forKey: id)
                self?.continuationsLock.unlock()
            }
        }
    }

    // MARK: - Per-Category Level Filtering

    /// Set the minimum log level for a specific category.
    ///
    /// Entries below this level are dropped before storage and publication.
    /// The default for every category is `.verbose` (log everything).
    ///
    /// Example — suppress verbose/debug in the `audio` category on release:
    /// ```swift
    /// PVLogPublisher.shared.setMinLevel(.info, forCategory: "audio")
    /// ```
    public func setMinLevel(_ level: LogLevel, forCategory category: String) {
        filterLock.lock()
        categoryMinLevels[category] = level
        filterLock.unlock()
    }

    /// Return the current minimum log level for a category.
    public func minLevel(forCategory category: String) -> LogLevel {
        filterLock.lock()
        let level = categoryMinLevels[category]
        filterLock.unlock()
        return level ?? .verbose
    }

    /// Reset per-category filters so all levels are logged.
    public func resetCategoryFilters() {
        filterLock.lock()
        categoryMinLevels.removeAll()
        filterLock.unlock()
    }

    // MARK: - Query API

    /// Return recent log entries, optionally filtered by minimum level.
    public func getRecentLogs(minLevel: LogLevel? = nil) -> [LogEntry] {
        logsLock.lock()
        let snapshot = recentLogs
        logsLock.unlock()
        guard let minLevel else { return snapshot }
        return snapshot.filter { $0.level >= minLevel }
    }

    /// Remove all cached log entries.
    public func clearLogs() {
        logsLock.lock()
        recentLogs.removeAll()
        logsLock.unlock()
    }

    // MARK: - Private Helpers

    private func shouldLog(level: LogLevel, forCategory categoryName: String) -> Bool {
        filterLock.lock()
        let min = categoryMinLevels[categoryName] ?? .verbose
        filterLock.unlock()
        return level >= min
    }
}

// MARK: - Convenience Extensions

public extension PVLogPublisher {
    /// Log at `.verbose` level.
    func verbose(
        _ message: String,
        category: PVLogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .verbose, category: category, file: file, function: function, line: line)
    }

    /// Log at `.debug` level.
    func debug(
        _ message: String,
        category: PVLogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    /// Log at `.info` level.
    func info(
        _ message: String,
        category: PVLogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    /// Log at `.warning` level.
    func warning(
        _ message: String,
        category: PVLogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// Log at `.error` level.
    func error(
        _ message: String,
        category: PVLogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Log Entry

/// A single structured log entry stored in PVLogPublisher's ring buffer.
public struct LogEntry: Identifiable, Equatable, Sendable {
    /// Unique identifier.
    public let id = UUID()

    /// Log message (original, without emoji or source prefix).
    public let message: String

    /// Log level.
    public let level: LogLevel

    /// Category name (e.g. `"audio"`, `"emulator"`).
    public let category: String

    /// Timestamp when the entry was created.
    public let timestamp: Date

    /// Source file name (filename only, not full path).
    public let file: String

    /// Source function name.
    public let function: String

    /// Source line number.
    public let line: Int

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private static let timestampFormatterQueue = DispatchQueue(label: "com.provenance-emu.logging.timestampFormatter")

    /// Formatted timestamp string (`HH:mm:ss.SSS`).
    public var formattedTimestamp: String {
        Self.timestampFormatterQueue.sync {
            Self.timestampFormatter.string(from: timestamp)
        }
    }

    /// Short single-line description: `[W] message`.
    public var shortDescription: String {
        "[\(level.shortName)] \(message)"
    }

    /// Full description including timestamp, category, and source location.
    public var fullDescription: String {
        "[\(formattedTimestamp)] [\(level.shortName)] [\(category)] \(file):\(function):\(line) - \(message)"
    }

    public static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Log Level

/// Severity levels for log entries, ordered from least to most severe.
public enum LogLevel: Int, Comparable, Sendable {
    case verbose = 0
    case debug   = 1
    case info    = 2
    case warning = 3
    case error   = 4

    /// Single-character abbreviation used in short descriptions.
    public var shortName: String {
        switch self {
        case .verbose: return "V"
        case .debug:   return "D"
        case .info:    return "I"
        case .warning: return "W"
        case .error:   return "E"
        }
    }

    /// Human-readable full name.
    public var name: String {
        switch self {
        case .verbose: return "Verbose"
        case .debug:   return "Debug"
        case .info:    return "Info"
        case .warning: return "Warning"
        case .error:   return "Error"
        }
    }

    /// Suggested display color name for UI components.
    public var color: String {
        switch self {
        case .verbose: return "gray"
        case .debug:   return "blue"
        case .info:    return "green"
        case .warning: return "orange"
        case .error:   return "red"
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
