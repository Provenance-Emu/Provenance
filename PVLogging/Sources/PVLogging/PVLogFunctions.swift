//
//  PVLogFunctions.swift
//
//
//  Created by Joseph Mattiello on 1/17/23.
//

import OSLog

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

@inlinable
public func log(_ message: @autoclosure () -> String,
                level: OSLogType = .debug,
                category: Logger = .general,
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
    case .fault:
        emoji = "💥"
    default:
        emoji = "📝"
    }
    let logMessage = "\(emoji) \(fileName):\(line) - \(function): \(message())"

    // Log to OSLog
    switch level {
    case .debug:
        category.debug("\(logMessage, privacy: .public)")
    case .info:
        category.info("\(logMessage, privacy: .public)")
    case .error:
        category.error("\(logMessage, privacy: .public)")
    case .fault:
        category.fault("\(logMessage, privacy: .public)")
    default:
        category.log(level: level, "\(logMessage, privacy: .public)")
    }

    /// Print to console in DEBUG builds
    #if DEBUG
    print(logMessage)
    #endif
}

// Update convenience functions to include emojis
@inlinable
public func DLOG(_ message: @autoclosure () -> String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    log(message(), level: .debug, category: category, file: file, function: function, line: line)
    #endif
}

@inlinable
public func ILOG(_ message: @autoclosure () -> String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
    log(message(), level: .info, category: category, file: file, function: function, line: line)
}

@inlinable
public func ELOG(_ message: @autoclosure () -> String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
    log(message(), level: .error, category: category, file: file, function: function, line: line)
}

@inlinable
public func WLOG(_ message: @autoclosure () -> String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
    let warningPrefix = "⚠️"
    log(warningPrefix + " " + message(), level: .info, category: category, file: file, function: function, line: line)
}

@inlinable
public func VLOG(_ message: @autoclosure () -> String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    log("🔬 " + message(), level: .debug, category: category, file: file, function: function, line: line)
    #endif
}
