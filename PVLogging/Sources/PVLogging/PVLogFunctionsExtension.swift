//
//  PVLogFunctionsExtension.swift
//  PVLogging
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import OSLog

/// Extension to connect the existing log functions with the new PVLogPublisher
@inlinable
public func VLOG(_ message: @autoclosure () -> String,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
    let msg = message()
    log(msg, level: .debug, category: .general, file: file, function: function, line: line)
    
    // Also send to the publisher
    PVLogPublisher.shared.verbose(msg, file: file, function: function, line: line)
}

@inlinable
public func DLOG(_ message: @autoclosure () -> String,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
    let msg = message()
    log(msg, level: .debug, category: .general, file: file, function: function, line: line)
    
    // Also send to the publisher
    PVLogPublisher.shared.debug(msg, file: file, function: function, line: line)
}

@inlinable
public func ILOG(_ message: @autoclosure () -> String,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
    let msg = message()
    log(msg, level: .info, category: .general, file: file, function: function, line: line)
    
    // Also send to the publisher
    PVLogPublisher.shared.info(msg, file: file, function: function, line: line)
}

@inlinable
public func WLOG(_ message: @autoclosure () -> String,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
    let msg = message()
    log(msg, level: .error, category: .general, file: file, function: function, line: line)
    
    // Also send to the publisher
    PVLogPublisher.shared.warning(msg, file: file, function: function, line: line)
}

@inlinable
public func ELOG(_ message: @autoclosure () -> String,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
    let msg = message()
    log(msg, level: .fault, category: .general, file: file, function: function, line: line)
    
    // Also send to the publisher
    PVLogPublisher.shared.error(msg, file: file, function: function, line: line)
}
