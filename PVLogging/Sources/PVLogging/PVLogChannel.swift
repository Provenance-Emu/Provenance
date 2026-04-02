//
//  PVLogChannel.swift
//  PVLogging
//
//  Created by Joseph Mattiello on 4/1/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

// MARK: - Log Event

/// A structured log event with typed fields for machine-readable output.
///
/// Unlike free-form `LogEntry` messages, events carry structured metadata
/// (action, item, status, duration, size) that can be queried and aggregated.
public struct PVLogEvent: Sendable {
    public let timestamp: Date
    public let action: Action
    public let item: String
    public let status: Status
    public let detail: String?
    public let duration: TimeInterval?
    public let size: Int?

    public enum Action: String, Sendable {
        case upload = "UP"
        case download = "DN"
        case query = "QRY"
        case skip = "SKIP"
        case delete = "DEL"
        case check = "CHK"
        case retry = "RETRY"
        case sync = "SYNC"
        case error = "ERR"
        case start = "START"
        case complete = "DONE"
    }

    public enum Status: String, Sendable {
        case ok = "OK"
        case skipped = "SKIP"
        case failed = "FAIL"
        case pending = "PEND"
        case inProgress = "PROG"
        case notFound = "NOTFOUND"
        case exists = "EXISTS"
        case cancelled = "CANCEL"
    }

    public init(
        action: Action,
        item: String,
        status: Status,
        detail: String? = nil,
        duration: TimeInterval? = nil,
        size: Int? = nil
    ) {
        self.timestamp = Date()
        self.action = action
        self.item = item
        self.status = status
        self.detail = detail
        self.duration = duration
        self.size = size
    }

    /// Compact single-line format: `[UP] rom/ABC123 OK 1.2s 4.5MB reason=already_synced`
    public var compactDescription: String {
        var parts = ["[\(action.rawValue)]", item, status.rawValue]
        if let duration {
            parts.append(String(format: "%.1fs", duration))
        }
        if let size {
            parts.append(Self.formatSize(size))
        }
        if let detail {
            parts.append(detail)
        }
        return parts.joined(separator: " ")
    }

    private static func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return String(format: "%.1fKB", Double(bytes) / 1024) }
        return String(format: "%.1fMB", Double(bytes) / (1024 * 1024))
    }
}

// MARK: - Channel Summary

/// Snapshot of a channel's activity counters.
public struct PVLogChannelSummary: Sendable {
    public let channelName: String
    public let totalEvents: Int
    public let errorCount: Int
    public let lastEventTime: Date?
    public let counters: [String: Int]

    /// Compact multi-line summary for debugging.
    public var description: String {
        var lines = ["=== \(channelName) ==="]
        lines.append("Events: \(totalEvents), Errors: \(errorCount)")
        if let last = lastEventTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            lines.append("Last: \(formatter.string(from: last))")
        }
        for (key, value) in counters.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(key): \(value)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Log Channel

/// A named, filterable log channel with optional file output.
///
/// Channels provide isolated logging for subsystems that generate high-volume
/// or structured output (CloudKit sync, import pipeline, emulator cores).
/// Each channel maintains its own ring buffer and optionally writes to a
/// dedicated log file.
///
/// Usage:
/// ```swift
/// let syncLog = PVLogChannel("cloudkit-sync", fileOutput: true)
/// syncLog.event(.upload, item: "rom/ABC123", status: .ok, duration: 1.2, size: 4_500_000)
/// syncLog.info("Initial sync started")
/// syncLog.error("Upload failed: network timeout")
///
/// // Get summary
/// let summary = syncLog.summary()
/// print(summary.description)
///
/// // Read log file
/// if let contents = syncLog.readLogFile() { ... }
/// ```
///
/// Thread safety: all mutable state is protected by `NSLock`.
public final class PVLogChannel: @unchecked Sendable {

    // MARK: - Properties

    /// Channel name used in log prefixes and file names.
    public let name: String

    /// Whether this channel writes to a dedicated file.
    public let fileOutputEnabled: Bool

    /// Maximum entries in the ring buffer.
    public let maxEntries: Int

    /// Whether events are also forwarded to PVLogPublisher.
    public let forwardToPublisher: Bool

    // MARK: - Private State

    private let lock = NSLock()
    private var events: [PVLogEvent] = []
    private var messages: [ChannelMessage] = []
    private var counters: [String: Int] = [:]
    private var errorCount: Int = 0
    private var totalEvents: Int = 0
    private var lastEventTime: Date?

    /// File handle for log output.
    private var fileHandle: FileHandle?
    private let fileLock = NSLock()
    private var logFilePath: String?

    /// Maximum log file size before rotation (1MB).
    private static let maxFileSize: UInt64 = 1_024 * 1_024

    private static let timestampFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        return fmt
    }()

    // MARK: - Init

    /// Create a log channel.
    ///
    /// - Parameters:
    ///   - name: Channel name (used in log prefix and file name). Use kebab-case: `"cloudkit-sync"`.
    ///   - fileOutput: Write to `Documents/Logs/<name>.log`. Default `false`.
    ///   - maxEntries: Ring buffer size. Default 500.
    ///   - forwardToPublisher: Also send messages to `PVLogPublisher`. Default `true`.
    public init(
        _ name: String,
        fileOutput: Bool = false,
        maxEntries: Int = 500,
        forwardToPublisher: Bool = true
    ) {
        self.name = name
        self.fileOutputEnabled = fileOutput
        self.maxEntries = maxEntries
        self.forwardToPublisher = forwardToPublisher

        if fileOutput {
            setupFileOutput()
        }
    }

    deinit {
        fileLock.lock()
        fileHandle?.closeFile()
        fileLock.unlock()
    }

    // MARK: - Structured Event Logging

    /// Log a structured event.
    public func event(
        _ action: PVLogEvent.Action,
        item: String,
        status: PVLogEvent.Status,
        detail: String? = nil,
        duration: TimeInterval? = nil,
        size: Int? = nil
    ) {
        let event = PVLogEvent(
            action: action,
            item: item,
            status: status,
            detail: detail,
            duration: duration,
            size: size
        )

        let line = "[\(name)] \(event.compactDescription)"

        lock.lock()
        events.append(event)
        if events.count > maxEntries {
            events.removeFirst(events.count - maxEntries)
        }
        totalEvents += 1
        lastEventTime = event.timestamp
        if status == .failed {
            errorCount += 1
        }
        // Increment action counter
        let counterKey = "\(action.rawValue).\(status.rawValue)"
        counters[counterKey, default: 0] += 1
        lock.unlock()

        writeToFile(event.timestamp, line)

        if forwardToPublisher {
            let level: LogLevel = (status == .failed) ? .warning : .info
            PVLogPublisher.shared.storeEntry(
                message: line,
                level: level,
                categoryName: name,
                file: "",
                function: "",
                line: 0
            )
        }
    }

    // MARK: - Free-form Message Logging

    /// Log a free-form message at the given level.
    public func log(_ message: String, level: LogLevel = .info) {
        let msg = ChannelMessage(timestamp: Date(), message: message, level: level)

        lock.lock()
        messages.append(msg)
        if messages.count > maxEntries {
            messages.removeFirst(messages.count - maxEntries)
        }
        if level == .error { errorCount += 1 }
        totalEvents += 1
        lastEventTime = msg.timestamp
        lock.unlock()

        let line = "[\(name)] [\(level.shortName)] \(message)"
        writeToFile(msg.timestamp, line)

        if forwardToPublisher {
            PVLogPublisher.shared.storeEntry(
                message: line,
                level: level,
                categoryName: name,
                file: "",
                function: "",
                line: 0
            )
        }
    }

    /// Convenience: log at info level.
    public func info(_ message: String) { log(message, level: .info) }
    /// Convenience: log at warning level.
    public func warning(_ message: String) { log(message, level: .warning) }
    /// Convenience: log at error level.
    public func error(_ message: String) { log(message, level: .error) }
    /// Convenience: log at debug level.
    public func debug(_ message: String) { log(message, level: .debug) }

    // MARK: - Query

    /// Get recent structured events, optionally filtered.
    public func recentEvents(action: PVLogEvent.Action? = nil, limit: Int = 50) -> [PVLogEvent] {
        lock.lock()
        let snapshot = events
        lock.unlock()

        var result = snapshot
        if let action {
            result = result.filter { $0.action == action }
        }
        return Array(result.suffix(limit))
    }

    /// Get a summary snapshot of channel activity.
    public func summary() -> PVLogChannelSummary {
        lock.lock()
        let s = PVLogChannelSummary(
            channelName: name,
            totalEvents: totalEvents,
            errorCount: errorCount,
            lastEventTime: lastEventTime,
            counters: counters
        )
        lock.unlock()
        return s
    }

    /// Clear all buffered events and counters.
    public func clear() {
        lock.lock()
        events.removeAll()
        messages.removeAll()
        counters.removeAll()
        errorCount = 0
        totalEvents = 0
        lastEventTime = nil
        lock.unlock()
    }

    // MARK: - File Output

    /// Read the current log file contents as a string.
    public func readLogFile() -> String? {
        guard let path = logFilePath else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// The path to the current log file, if file output is enabled.
    public var currentLogFilePath: String? { logFilePath }

    private func setupFileOutput() {
        let logsDir = Self.logsDirectory()
        try? FileManager.default.createDirectory(atPath: logsDir, withIntermediateDirectories: true)

        let path = (logsDir as NSString).appendingPathComponent("\(name).log")
        logFilePath = path

        // Rotate if needed
        rotateIfNeeded(path: path)

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        fileHandle = FileHandle(forWritingAtPath: path)
        fileHandle?.seekToEndOfFile()

        // Write header
        let header = "--- \(name) log started \(ISO8601DateFormatter().string(from: Date())) ---\n"
        if let data = header.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }

    private func writeToFile(_ timestamp: Date, _ line: String) {
        guard fileOutputEnabled else { return }

        let ts = Self.timestampFormatter.string(from: timestamp)
        let fullLine = "\(ts) \(line)\n"

        fileLock.lock()
        if let data = fullLine.data(using: .utf8) {
            fileHandle?.write(data)
        }
        fileLock.unlock()
    }

    private func rotateIfNeeded(path: String) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attrs[.size] as? UInt64,
              fileSize > Self.maxFileSize else { return }

        let rotatedPath = path + ".1"
        try? FileManager.default.removeItem(atPath: rotatedPath)
        try? FileManager.default.moveItem(atPath: path, toPath: rotatedPath)
    }

    private static func logsDirectory() -> String {
        #if os(tvOS)
        let base = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
        #else
        let base = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
        #endif
        return (base as NSString).appendingPathComponent("Logs")
    }
}

// MARK: - Channel Message (internal)

private struct ChannelMessage: Sendable {
    let timestamp: Date
    let message: String
    let level: LogLevel
}

// MARK: - Channel Registry

/// Global registry of active log channels for discovery and debugging.
public final class PVLogChannelRegistry: @unchecked Sendable {
    public static let shared = PVLogChannelRegistry()

    private let lock = NSLock()
    private var channels: [String: PVLogChannel] = [:]

    private init() {}

    /// Register a channel for global discovery.
    public func register(_ channel: PVLogChannel) {
        lock.lock()
        channels[channel.name] = channel
        lock.unlock()
    }

    /// Unregister a channel.
    public func unregister(_ channel: PVLogChannel) {
        lock.lock()
        channels.removeValue(forKey: channel.name)
        lock.unlock()
    }

    /// Get a registered channel by name.
    public func channel(named name: String) -> PVLogChannel? {
        lock.lock()
        let ch = channels[name]
        lock.unlock()
        return ch
    }

    /// Get all registered channel names.
    public var channelNames: [String] {
        lock.lock()
        let names = Array(channels.keys).sorted()
        lock.unlock()
        return names
    }

    /// Get summaries for all registered channels.
    public func allSummaries() -> [PVLogChannelSummary] {
        lock.lock()
        let chs = Array(channels.values)
        lock.unlock()
        return chs.map { $0.summary() }
    }
}
