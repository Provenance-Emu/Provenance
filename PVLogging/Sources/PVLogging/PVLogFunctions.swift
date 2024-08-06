//
//  PVLogFunctions.swift
//  
//
//  Created by Joseph Mattiello on 1/17/23.
//

import OSLog

@available(iOS 14.0, tvOS 14.0, *)
extension Logger: Sendable {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static let subsystem: String = Bundle.main.bundleIdentifier ?? ""

    /// Logs the view cycles like a view that appeared.
    @usableFromInline
    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")

    /// All logs related to tracking and analytics.
    @usableFromInline
    static let statistics = Logger(subsystem: subsystem, category: "statistics")

    /// All logs related to tracking and analytics.
    @usableFromInline
    static let networking = Logger(subsystem: subsystem, category: "network")

    /// All logs related to video processing and rendering.
    @usableFromInline
    static let video = Logger(subsystem: subsystem, category: "video")

    /// All logs related to audio processing and rendering.
    @usableFromInline
    static let audio = Logger(subsystem: subsystem, category: "audio")

    /// All logs related to  libraries and databases.
    @usableFromInline
    static let database = Logger(subsystem: subsystem, category: "database")

    /// General logs
    @usableFromInline
    static let general = Logger(subsystem: subsystem, category: "general")
}

@usableFromInline
let USE_PVLOG_ENTRY: Bool = false

@_transparent
public func DLOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    if #available(iOS 14.0, tvOS 14.0, *), !USE_PVLOG_ENTRY {
        Logger.general.debug( "\(logEntry.offset)@[\(logEntry.functionString):\(logEntry.lineNumberString)] \(logEntry.text)\n\(file)")
    } else {
        PVLogging.shared.add(logEntry)
    }
}

@_transparent
public func ILOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    if #available(iOS 14.0, tvOS 14.0, *), !USE_PVLOG_ENTRY {
        Logger.general.info( "\(logEntry.offset)@[\(logEntry.functionString):\(logEntry.lineNumberString)] \(logEntry.text)\n\(file)")
    } else {
        PVLogging.shared.add(logEntry)
    }
}

@_transparent
public func WLOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    if #available(iOS 14.0, tvOS 14.0, *), !USE_PVLOG_ENTRY {
        Logger.general.warning( "\(logEntry.offset)@[\(logEntry.functionString):\(logEntry.lineNumberString)] \(logEntry.text)\n\(file)")
    } else {
        PVLogging.shared.add(logEntry)
    }
}

@_transparent
public func VLOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    if #available(iOS 14.0, tvOS 14.0, *), !USE_PVLOG_ENTRY {
        Logger.general.trace( "\(logEntry.offset)@[\(logEntry.functionString):\(logEntry.lineNumberString)] \(logEntry.text)\n\(file)")
    } else {
        PVLogging.shared.add(logEntry)
    }
}

@_transparent
public func ELOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = false) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    if #available(iOS 14.0, tvOS 14.0, *), !USE_PVLOG_ENTRY {
        Logger.general.error( "\(logEntry.offset)@[\(logEntry.functionString):\(logEntry.lineNumberString)] \(logEntry.text)\n\(file)")
    } else {
        PVLogging.shared.add(logEntry)
    }
}

@_transparent
fileprivate func CurrentFileName(_ fileName: StaticString = #file) -> String {
    var str = String(describing: fileName)
    if let idx = str.range(of: "/", options: .backwards)?.upperBound {
        str = String(str.suffix(from: idx))
    }
    if let idx = str.range(of: ".", options: .backwards)?.lowerBound {
        str = String(str.prefix(through: idx))
    }
    return str
}
