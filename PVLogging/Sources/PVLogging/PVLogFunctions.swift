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

extension os.Logger: @retroactive Sendable {
    /// Stable subsystem identifier for all Provenance modules.
    /// Using a static string rather than Bundle.main.bundleIdentifier ensures
    /// correctness in unit tests and extension targets where the bundle ID may differ.
    public static let provenanceSubsystem = "com.provenance-emu.provenance"

    /// Logs the view cycles like a view that appeared.
    public static let viewCycle = Logger(subsystem: provenanceSubsystem, category: "viewcycle")

    /// All logs related to tracking and analytics.
    public static let statistics = Logger(subsystem: provenanceSubsystem, category: "statistics")

    /// All logs related to networking.
    public static let networking = Logger(subsystem: provenanceSubsystem, category: "network")

    /// All logs related to video processing and rendering.
    public static let video = Logger(subsystem: provenanceSubsystem, category: "video")

    /// All logs related to audio processing and rendering.
    public static let audio = Logger(subsystem: provenanceSubsystem, category: "audio")

    /// All logs related to libraries and databases.
    public static let database = Logger(subsystem: provenanceSubsystem, category: "database")

    /// General logs
    /// - Note: This is the default logger.
    public static let general = Logger(subsystem: provenanceSubsystem, category: "general")

    /// All logs related to emulator core execution.
    public static let emulator = Logger(subsystem: provenanceSubsystem, category: "emulator")

    /// All logs related to UI and navigation.
    public static let ui = Logger(subsystem: provenanceSubsystem, category: "ui")

    /// All logs related to game controller input.
    public static let controller = Logger(subsystem: provenanceSubsystem, category: "controller")

    /// All logs related to save states.
    public static let saveState = Logger(subsystem: provenanceSubsystem, category: "savestate")

    /// All logs related to the game library.
    public static let library = Logger(subsystem: provenanceSubsystem, category: "library")
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

    /// Stable subsystem identifier for all Provenance modules.
    public static let provenanceSubsystem = "com.provenance-emu.provenance"

    /// Logs the view cycles like a view that appeared.
    public static let viewCycle = PVLogCategory(subsystem: provenanceSubsystem, category: "viewcycle")

    /// All logs related to tracking and analytics.
    public static let statistics = PVLogCategory(subsystem: provenanceSubsystem, category: "statistics")

    /// All logs related to networking.
    public static let networking = PVLogCategory(subsystem: provenanceSubsystem, category: "network")

    /// All logs related to video processing and rendering.
    public static let video = PVLogCategory(subsystem: provenanceSubsystem, category: "video")

    /// All logs related to audio processing and rendering.
    public static let audio = PVLogCategory(subsystem: provenanceSubsystem, category: "audio")

    /// All logs related to libraries and databases.
    public static let database = PVLogCategory(subsystem: provenanceSubsystem, category: "database")

    /// General logs
    /// - Note: This is the default logger.
    public static let general = PVLogCategory(subsystem: provenanceSubsystem, category: "general")

    /// All logs related to emulator core execution.
    public static let emulator = PVLogCategory(subsystem: provenanceSubsystem, category: "emulator")

    /// All logs related to UI and navigation.
    public static let ui = PVLogCategory(subsystem: provenanceSubsystem, category: "ui")

    /// All logs related to game controller input.
    public static let controller = PVLogCategory(subsystem: provenanceSubsystem, category: "controller")

    /// All logs related to save states.
    public static let saveState = PVLogCategory(subsystem: provenanceSubsystem, category: "savestate")

    /// All logs related to the game library.
    public static let library = PVLogCategory(subsystem: provenanceSubsystem, category: "library")
}
#endif

/// current Date/Time stamp using the ISO-8601 format and the device's time zone
public var currentDatTimeStamp: String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}

/// Central log function. Writes to OSLog and routes to PVLogPublisher.
/// All convenience macros (DLOG/ILOG/etc.) funnel through here to avoid double-logging.
@inlinable
public func log(_ message: @autoclosure () -> String,
                level: LogLevel = .debug,
                category: PVLogCategory = .general,
                file: String = #fileID,
                function: String = #function,
                line: Int = #line) {
    let msg = message()
    // Extract just the filename from "Module/Filename.swift" (#fileID format) or full path
    let fileName: String
    if let slash = file.lastIndex(of: "/") {
        fileName = String(file[file.index(after: slash)...])
    } else {
        fileName = file
    }

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
    let logMessage = "\(emoji) \(fileName):\(line) - \(function): \(msg)"

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

    // Route to PVLogPublisher for in-app log viewer (no OSLog re-emission)
    let categoryName = PVLogPublisher.categoryName(from: category)
    PVLogPublisher.shared.storeEntry(
        message: msg,
        level: level,
        categoryName: categoryName,
        file: fileName,
        function: function,
        line: line
    )
}

// MARK: - Convenience Macros

@inlinable
public func DLOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #fileID, function: String = #function, line: Int = #line) {
    #if DEBUG
    log(message(), level: .debug, category: category, file: file, function: function, line: line)
    #endif
}

@inlinable
public func ILOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #fileID, function: String = #function, line: Int = #line) {
    log(message(), level: .info, category: category, file: file, function: function, line: line)
}

@inlinable
public func ELOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #fileID, function: String = #function, line: Int = #line) {
    log(message(), level: .error, category: category, file: file, function: function, line: line)
}

@inlinable
public func WLOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #fileID, function: String = #function, line: Int = #line) {
    log(message(), level: .warning, category: category, file: file, function: function, line: line)
}

@inlinable
public func VLOG(_ message: @autoclosure () -> String, category: PVLogCategory = .general, file: String = #fileID, function: String = #function, line: Int = #line) {
    #if DEBUG
    log(message(), level: .verbose, category: category, file: file, function: function, line: line)
    #endif
}

// MARK: - ObjC Bridge

#if canImport(ObjectiveC)
@objc
public final class PVLoggingObjC: NSObject {
    @objc
    public static func Vlog(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        VLOG(message, file: file, function: function, line: line)
    }

    @objc
    public static func Dlog(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        DLOG(message, file: file, function: function, line: line)
    }

    @objc
    public static func Ilog(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        ILOG(message, file: file, function: function, line: line)
    }

    @objc
    public static func Elog(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        ELOG(message, file: file, function: function, line: line)
    }

    @objc
    public static func Wlog(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        WLOG(message, file: file, function: function, line: line)
    }
}
#endif
