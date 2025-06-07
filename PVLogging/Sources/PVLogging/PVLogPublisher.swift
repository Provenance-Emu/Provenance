//
//  PVLogPublisher.swift
//  PVLogging
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import OSLog

/// A modern Combine-based publisher for PVLogging
public final class PVLogPublisher {
    // MARK: - Singleton
    
    // MARK: - Private Properties
    
    /// Serial queue for thread-safe access to logs
    private let logsQueue = DispatchQueue(label: "com.provenance.logging.storage", qos: .utility)
    
    /// In-memory cache of recent logs
    private var recentLogs: [LogEntry] = []
    
    /// Maximum number of logs to keep in memory
    private let maxLogCount = 2000
    
    /// Shared instance
    nonisolated(unsafe)
    public static let shared = PVLogPublisher()
    
    // MARK: - Properties
    
    /// Subject that publishes log entries
    private let logSubject = PassthroughSubject<LogEntry, Never>()
    
    /// Publisher for log entries
    public var logPublisher: AnyPublisher<LogEntry, Never> {
        logSubject.eraseToAnyPublisher()
    }
    
    // No storage property needed with this approach
    
    // MARK: - Initialization
    
    private init() {
        // Set up any initial configuration
    }
    
    // MARK: - Public Methods
    
    /// Log a message with the specified level
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - category: The log category
    ///   - file: The file where the log was called from
    ///   - function: The function where the log was called from
    ///   - line: The line number where the log was called from
    public func log(
        _ message: String,
        level: LogLevel,
        category: Logger = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        
        // Extract category name from the Logger
        let categoryName = getCategoryName(from: category)
        
        // Create the log entry
        let entry = LogEntry(
            message: message,
            level: level,
            category: categoryName,
            timestamp: Date(),
            file: fileName,
            function: function,
            line: line
        )
        
        // Publish the log entry immediately
        logSubject.send(entry)
        
        // Store the log entry asynchronously on a serial queue
        logsQueue.async { [weak self, entry] in
            guard let self = self else { return }
            
            // Add to recent logs
            self.recentLogs.append(entry)
            
            // Trim if needed
            if self.recentLogs.count > self.maxLogCount {
                self.recentLogs = Array(self.recentLogs.suffix(self.maxLogCount))
            }
        }
        
        // Also log to system console
        let osLogType: OSLogType
        switch level {
        case .verbose:
            osLogType = .debug
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warning:
            osLogType = .error
        case .error:
            osLogType = .fault
        }
        
        category.log(level: osLogType, "\(fileName):\(function):\(line) - \(message)")
    }
    
    /// Get recent logs, optionally filtered by level
    /// - Parameter level: Optional minimum log level to filter by
    /// - Returns: Array of log entries
    public func getRecentLogs(minLevel: LogLevel? = nil) -> [LogEntry] {
        // Use the serial queue to safely access logs
        return logsQueue.sync { [self] in
            if let minLevel = minLevel {
                return recentLogs.filter { $0.level.rawValue >= minLevel.rawValue }
            } else {
                return recentLogs
            }
        }
    }
    
    /// Clear all cached logs
    public func clearLogs() {
        logsQueue.async { [weak self] in
            self?.recentLogs.removeAll()
        }
    }
    
    /// Extract category name from Logger
    private func getCategoryName(from logger: Logger) -> String {
        // Since Logger is a struct and we can't access its category directly,
        // we'll use a string representation to determine the category
        let loggerDescription = String(describing: logger)
        
        if loggerDescription.contains("viewcycle") { return "viewcycle" }
        if loggerDescription.contains("statistics") { return "statistics" }
        if loggerDescription.contains("network") { return "network" }
        if loggerDescription.contains("video") { return "video" }
        if loggerDescription.contains("audio") { return "audio" }
        if loggerDescription.contains("database") { return "database" }
        return "general" // Default category
    }
}

// MARK: - Log Entry

/// Represents a single log entry
public struct LogEntry: Identifiable, Equatable, Sendable {
    /// Unique identifier
    public let id = UUID()
    
    /// Log message
    public let message: String
    
    /// Log level
    public let level: LogLevel
    
    /// Log category
    public let category: String
    
    /// Timestamp when the log was created
    public let timestamp: Date
    
    /// Source file
    public let file: String
    
    /// Source function
    public let function: String
    
    /// Source line number
    public let line: Int
    
    /// Formatted timestamp string
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    /// Short description for display
    public var shortDescription: String {
        "[\(level.shortName)] \(message)"
    }
    
    /// Full description including source information
    public var fullDescription: String {
        "[\(formattedTimestamp)] [\(level.shortName)] [\(category)] \(file):\(function):\(line) - \(message)"
    }
    
    public static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Log Level

/// Log level enum
public enum LogLevel: Int, Comparable, Sendable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    
    /// Short name for display
    public var shortName: String {
        switch self {
        case .verbose:
            return "V"
        case .debug:
            return "D"
        case .info:
            return "I"
        case .warning:
            return "W"
        case .error:
            return "E"
        }
    }
    
    /// Full name for display
    public var name: String {
        switch self {
        case .verbose:
            return "Verbose"
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
    }
    
    /// Color for display
    public var color: String {
        switch self {
        case .verbose:
            return "gray"
        case .debug:
            return "blue"
        case .info:
            return "green"
        case .warning:
            return "orange"
        case .error:
            return "red"
        }
    }
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Convenience Extensions

/// Extension to add convenience methods to the existing log functions
public extension PVLogPublisher {
    /// Log a verbose message
    func verbose(
        _ message: String,
        category: Logger = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .verbose, category: category, file: file, function: function, line: line)
    }
    
    /// Log a debug message
    func debug(
        _ message: String,
        category: Logger = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// Log an info message
    func info(
        _ message: String,
        category: Logger = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    func warning(
        _ message: String,
        category: Logger = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message
    func error(
        _ message: String,
        category: Logger = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
}
