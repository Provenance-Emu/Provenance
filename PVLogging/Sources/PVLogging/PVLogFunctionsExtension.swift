//
//  PVLogFunctionsExtension.swift
//  PVLogging
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//
//  These overloads provide the no-category variants of the convenience macros.
//  The global `log()` function routes to both OSLog and PVLogPublisher, so
//  these simply forward to `log()` without additional publisher calls.
//

import Foundation

@inlinable
public func VLOG(_ message: @autoclosure () -> String,
                 file: String = #fileID,
                 function: String = #function,
                 line: Int = #line) {
    #if DEBUG
    log(message(), level: .verbose, category: .general, file: file, function: function, line: line)
    #endif
}

#if DEBUG
@inlinable
public func DLOG(_ message: @autoclosure () -> String,
                 file: String = #fileID,
                 function: String = #function,
                 line: Int = #line) {
    log(message(), level: .debug, category: .general, file: file, function: function, line: line)
}
#else
@inlinable
public func DLOG(_ message: @autoclosure () -> String,
                 file: String = #fileID,
                 function: String = #function,
                 line: Int = #line) { }
#endif

@inlinable
public func ILOG(_ message: @autoclosure () -> String,
                 file: String = #fileID,
                 function: String = #function,
                 line: Int = #line) {
    log(message(), level: .info, category: .general, file: file, function: function, line: line)
}

@inlinable
public func WLOG(_ message: @autoclosure () -> String,
                 file: String = #fileID,
                 function: String = #function,
                 line: Int = #line) {
    log(message(), level: .warning, category: .general, file: file, function: function, line: line)
}

@inlinable
public func ELOG(_ message: @autoclosure () -> String,
                 file: String = #fileID,
                 function: String = #function,
                 line: Int = #line) {
    log(message(), level: .error, category: .general, file: file, function: function, line: line)
}
