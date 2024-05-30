//
//  PVLogFunctions.swift
//  
//
//  Created by Joseph Mattiello on 1/17/23.
//

@_transparent
public func DLOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    PVLogging.shared.add(logEntry)
}

@_transparent
public func ILOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    PVLogging.shared.add(logEntry)
}

@_transparent
public func WLOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    PVLogging.shared.add(logEntry)
}

@_transparent
public func VLOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    PVLogging.shared.add(logEntry)
}

@_transparent
public func ELOG(_ message: @autoclosure () -> String, level: PVLogLevel = .defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = false) {
    let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    PVLogging.shared.add(logEntry)

                              //    #if ELOGASSERT
    //    let assertMessage : String = String("\(file):\(line) : \(message())")
    //    assertionFailure(assertMessage)
    //    #endif
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
