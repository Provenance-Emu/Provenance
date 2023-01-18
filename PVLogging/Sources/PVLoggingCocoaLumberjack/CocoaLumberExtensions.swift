//
//  CocoaLumberExtensions.swift
//  Provenance
//
//  Created by Joseph Mattiello on 8/11/15.
//  Copyright © 2015 Joe Mattiello. All rights reserved.
//

@_exported import CocoaLumberjack
@_exported import CocoaLumberjackSwift
@_exported import CocoaLumberjackSwiftSupport

import Foundation

public extension DDLogFlag {
    static func fromLogLevel(_ logLevel: DDLogLevel) -> DDLogFlag {
        return DDLogFlag(rawValue: logLevel.rawValue)
    }

    init(_ logLevel: DDLogLevel) {
        self = DDLogFlag(rawValue: logLevel.rawValue)
    }

    /// returns the log level, or the lowest equivalant.
    func toLogLevel() -> DDLogLevel {
        if let ourValid = DDLogLevel(rawValue: self.rawValue) {
            return ourValid
        } else {
            let logFlag: DDLogFlag = self

            if logFlag.contains(.verbose) {
                return .verbose
            } else if logFlag.contains(.debug) {
                return .debug
            } else if logFlag.contains(.info) {
                return .info
            } else if logFlag.contains(.warning) {
                return .warning
            } else if logFlag.contains(.error) {
                return .error
            } else {
                return .off
            }
        }
    }
}

public var defaultDebugLevel = DDLogLevel.verbose

public func resetDefaultDebugLevel() {
    defaultDebugLevel = DDLogLevel.verbose
}

//
// public func _DDLogMessage(_ message: @autoclosure () -> String, level: DDLogLevel, flag: DDLogFlag, context: Int, file: StaticString, function: StaticString, line: UInt, tag: Any?, asynchronous: Bool, ddlog: DDLog) {
//    if level.rawValue & flag.rawValue != 0 {
//        // Tell the DDLogMessage constructor to copy the C strings that get passed to it.
//        let logMessage = DDLogMessage(message: message(), level: level, flag: flag, context: context, file: String(describing: file), function: String(describing: function), line: line, tag: tag, options: [.copyFile, .copyFunction], timestamp: nil)
//        ddlog.log(asynchronous: asynchronous, message: logMessage)
//    }
// }

public func DLOG(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance) {
    _DDLogMessage(message(), level: level, flag: .debug, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
//    DDLogMessage(message: message(), level: level, flag: .debug, context: context, file: "\(file)", function: "\(function)", line: line, tag: tag, timestamp: Date())
}

public func ILOG(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance) {
    _DDLogMessage(message(), level: level, flag: .info, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

public func WLOG(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance) {
    _DDLogMessage(message(), level: level, flag: .warning, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

public func VLOG(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance) {
    _DDLogMessage(message(), level: level, flag: .verbose, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

public func ELOG(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = false, ddlog: DDLog = DDLog.sharedInstance) {
    _DDLogMessage(message(), level: level, flag: .error, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
//    #if ELOGASSERT
//    let assertMessage : String = String("\(file):\(line) : \(message())")
//    assertionFailure(assertMessage)
//    #endif
}

/// Analogous to the C preprocessor macro `THIS_FILE`.
// public func CurrentFileName(_ fileName: StaticString = #file) -> String {
//    // Using string interpolation to prevent integer overflow warning when using StaticString.stringValue
//    // This double-casting to NSString is necessary as changes to how Swift handles NSPathUtilities requres the string to be an NSString
//    return (("\(fileName)" as NSString).lastPathComponent as NSString).deletingPathExtension
// }

public func CurrentFileName(_ fileName: StaticString = #file) -> String {
    var str = String(describing: fileName)
    if let idx = str.range(of: "/", options: .backwards)?.upperBound {
        str = String(str.suffix(from: idx))
    }
    if let idx = str.range(of: ".", options: .backwards)?.lowerBound {
        str = String(str.prefix(through: idx))
    }
    return str
}

// import Foundation
// import CocoaLumberjack
//
// extension DDLog {
//
//    private struct State {
//        static var logLevel: DDLogLevel = .Debug
//        static var logAsync: Bool = true
//    }
//
//    class var logLevel: DDLogLevel {
//        get { return State.logLevel }
//        set { State.logLevel = newValue }
//    }
//
//    class var logAsync: Bool {
//        get { return (self.logLevel != .Error) && State.logAsync }
//        set { State.logAsync = newValue }
//    }
//
//    class func log(flag: DDLogFlag, @autoclosure message:  () -> String,
//        function: String = __FUNCTION__, file: String = __FILE__,  line: UInt = __LINE__) {
//            if flag.rawValue & logLevel.rawValue != 0 {
//                let logMsg = DDLogMessage(message: message(), level: logLevel, flag: flag, context: 0,
//                    file: file, function: function, line: line,
//                    tag: nil, options: DDLogMessageOptions(rawValue:0), timestamp: nil)
//                DDLog.log(logAsync, message: logMsg)
//            }
//    }
// }
//
// func ELOG(@autoclosure message:  () -> String, function: String = __FUNCTION__,
//    file: String = __FILE__, line: UInt = __LINE__) {
//        DDLog.log(.Error, message: message, function: function, file: file, line: line)
// }
//
// func WLOG(@autoclosure message:  () -> String, function: String = __FUNCTION__,
//    file: String = __FILE__, line: UInt = __LINE__) {
//        DDLog.log(.Warning, message: message, function: function, file: file, line: line)
// }
//
// func ILOG(@autoclosure message:  () -> String, function: String = __FUNCTION__,
//    file: String = __FILE__, line: UInt = __LINE__) {
//        DDLog.log(.Info, message: message, function: function, file: file, line: line)
// }
//
// func DLOG(@autoclosure message:  () -> String, function: String = __FUNCTION__,
//    file: String = __FILE__, line: UInt = __LINE__) {
//        DDLog.log(.Debug, message: message, function: function, file: file, line: line)
// }
//
// func VLOG(@autoclosure message:  () -> String, function: String = __FUNCTION__,
//    file: String = __FILE__, line: UInt = __LINE__) {
//        DDLog.log(.Verbose, message: message, function: function, file: file, line: line)
// }
