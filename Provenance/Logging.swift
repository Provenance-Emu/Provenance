//
//  Logging.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/12/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

public enum LogLevel: Int {
    case trace = 0
    case debug
    case info
    case warn
    case error
}

private let startDate = Date()

#if DEBUG
let LOG_LEVEL: LogLevel = .debug
#else
let LOG_LEVEL: LogLevel = .debug
#endif

public func VLOG(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    _LogMessage(message, file: file, function: function, line: line, level: .trace)
}

public func DLOG(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    _LogMessage(message, file: file, function: function, line: line, level: .debug)
}

public func ILOG(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    _LogMessage(message, file: file, function: function, line: line, level: .info)
}

public func WLOG(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    _LogMessage(message, file: file, function: function, line: line, level: .warn)
}

public func ELOG(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    _LogMessage(message, file: file, function: function, line: line, level: .error)
}

private func _LogMessage(_ message: @autoclosure () -> String, file: StaticString, function: StaticString, line: UInt, level: LogLevel) {
    guard level.rawValue >= LOG_LEVEL.rawValue else {
        return
    }

    let icon: String
    let levelString: String
    switch level {

    case .trace:
        icon = "🔀"
        levelString = ""

    case .debug:
        icon = "🔹"
        levelString = "Debug"

    case .info:
        icon = "🔸"
        levelString = "Info"

    case .warn:
        icon = "⚠️"
        levelString = "Warning"

    case .error:
        icon = "❗"
        levelString = "Error"
    }

    let fileName = (String(describing: file) as NSString).lastPathComponent
    let messageString = message()

    let logString = "\(Int(floor(startDate.timeIntervalSinceNow * -1))) \(icon) [\(levelString)] \(fileName):\(line) \(function)\n  ↪︎ \(messageString)\n"

    print(logString)
}
