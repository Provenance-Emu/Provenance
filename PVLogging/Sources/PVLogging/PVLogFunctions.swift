//
//  PVLogFunctions.swift
//
//
//  Created by Joseph Mattiello on 1/17/23.
//

import Foundation
import Logging

#if canImport(OSLog)
import OSLog

/// On Apple platforms, PVLogCategory is os.Logger
public typealias PVLogCategory = os.Logger

extension os.Logger: Sendable {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static let subsystem: String = Bundle.main.bundleIdentifier ?? ""

    /// Logs the view cycles like a view that appeared.
    public static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")

    /// All logs related to tracking and analytics.
    public static let statistics = Logger(subsystem: subsystem, category: "statistics")

    /// All logs related to tracking and analytics.
    public static let networking = Logger(subsystem: subsystem, category: "network")

    /// All logs related to video processing and rendering.
    public static let video = Logger(subsystem: subsystem, category: "video")

    /// All logs related to audio processing and rendering.
    public static let audio = Logger(subsystem: subsystem, category: "audio")

    /// All logs related to  libraries and databases.
    public static let database = Logger(subsystem: subsystem, category: "database")

    /// General logs
    /// - Note: This is the default logger.
    public static let general = Logger(subsystem: subsystem, category: "general")
}

#else

/// Cross-platform logging category backed by swift-log
public struct PVLogCategory: Sendable {
    /// The underlying swift-log Logger instance
    public let logger: Logging.Logger
    /// Category name for display
    public let categoryName: String

    public init(subsystem: String, category: String) {
        var logger = Logging.Logger(label: "\(subsystem).\(category)")
        logger.logLevel = .trace
        self.logger = logger
        self.categoryName = category
    }

    /// Logs the view cycles like a view that appeared.
    public static let viewCycle = PVLogCategory(subsystem: "provenance", category: "viewcycle")

    /// All logs related to tracking and analytics.
    public static let statistics = PVLogCategory(subsystem: "provenance", category: "statistics")

    /// All logs related to networking.
    public static let networking = PVLogCategory(subsystem: "provenance", category: "network")

    /// All logs related to video processing and rendering.
    public static let video = PVLogCategory(subsystem: "provenance", category: "video")

    /// All logs related to audio processing and rendering.
    public static let audio = PVLogCategory(subsystem: "provenance", category: "audio")

    /// All logs related to libraries and databases.
    public static let database = PVLogCategory(subsystem: "provenance", category: "database")

    /// General logs
    /// - Note: This is the default logger.
    public static let general = PVLogCategory(subsystem: "provenance", category: "general")
}
#endif

/// current Date/Time stamp using the ISO-8601 format and the device's time zone
public var currentDatTimeStamp: String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}

@inlinable
public func log(_ message: @autoclosure () -> String,
                level: LogLevel = .debug,
                category: PVLogCategory = .general,
                file: String = #file,
                function: String = #function,
                line: Int = #line) {
    let fileName = URL(fileURLWithPath: file).lastPathComponent
    let emoji: String
    switch level {
    case .debug:
        emoji = "🔍"
    case .info:
        emoji = "ℹ️"
    case .error:
        emoji = "❌"
    case .warning:
        emoji = "⚠️"
    case .verbose:
        emoji = "🔬"
    }
    let logMessage = "\(emoji) \(currentDatTimeStamp) \(fileName):\(line) - \(function): \(message())"

    #if canImport(OSLog)
    switch level {
    case .debug, .verbose:
        category.debug("\(logMessage, privacy: .public)")
    case .info:
        category.info("\(logMessage, privacy: .public)")
    case .warning:
        category.log(level: .default, "\(logMessage, privacy: .public)")
    case .error:
        category.error("\(logMessage, privacy: .public)")
    }
    #else
    let swiftLogLevel: Logging.Logger.Level
    switch level {
    case .verbose:
        swiftLogLevel = .trace
    case .debug:
        swiftLogLevel = .debug
    case .info:
        swiftLogLevel = .info
    case .warning:
        swiftLogLevel = .warning
    case .error:
        swiftLogLevel = .error
    }
    category.logger.log(level: swiftLogLevel, "\(logMessage)")
    #endif
}

// Update convenience functions to include emojis
@inlinable
public func DLOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let msg = message()
    log(msg, level: .debug, category: category, file: file, function: function, line: line)
    PVLogPublisher.shared.verbose(msg, category: category, file: file, function: function, line: line)
    #endif
}

@inlinable
public func ILOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    let msg = message()
    log(msg, level: .info, category: category, file: file, function: function, line: line)
    PVLogPublisher.shared.info(msg, category: category, file: file, function: function, line: line)
}

@inlinable
public func ELOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    let msg = message()
    log(msg, level: .error, category: category, file: file, function: function, line: line)
    PVLogPublisher.shared.error(msg, category: category, file: file, function: function, line: line)
}

@inlinable
public func WLOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    let msg = message()
    let warningPrefix = "⚠️"
    log(warningPrefix + " " + msg, level: .warning, category: category, file: file, function: function, line: line)
    PVLogPublisher.shared.warning(msg, category: category, file: file, function: function, line: line)
}

@inlinable
public func VLOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let msg = message()
    log(msg, level: .debug, category: category, file: file, function: function, line: line)
    PVLogPublisher.shared.verbose(msg, category: category, file: file, function: function, line: line)
    #endif
}

#if canImport(ObjectiveC)
@objc
public final class PVLoggingObjC: NSObject {
    @objc
    public static func Vlog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        VLOG(message, file: file, function: function, line: line)
    }

    @objc
    public static func Dlog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        DLOG(message, file: file, function: function, line: line)
    }

    @objc
    public static func Ilog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        ILOG(message, file: file, function: function, line: line)
    }

    @objc
    public  static func Elog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        ELOG(message, file: file, function: function, line: line)
    }

    @objc
    public static func Wlog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        WLOG(message, file: file, function: function, line: line)
    }
}
#endif
