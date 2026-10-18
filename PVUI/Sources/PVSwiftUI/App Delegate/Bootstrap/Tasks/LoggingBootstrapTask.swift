//
//  LoggingBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVLookup

/// Initialises the shared ``PVLogging`` instance and routes PVLookup's log
/// messages into it.
///
/// All other tasks that emit log output should declare `BootstrapKey.logging`
/// as a dependency so that logging is ready before they run.
struct LoggingBootstrapTask: BootstrapTask {
    var name: String { "Logging" }
    var dependencies: [String] { [] }
    var provisions: [String] { [BootstrapKey.logging] }

    /// PVLookup's messages are forwarded from here. PVLogging's `log()` holds
    /// four `Logger` interpolations, each reserving a large stack buffer in a
    /// Debug build; called at the bottom of a deep lookup on a Swift-concurrency
    /// thread (512 KB stack) that overflowed in iFly. A serial queue keeps the
    /// order and runs the call on a shallow stack.
    private static let lookupLogQueue = DispatchQueue(label: "org.provenance-emu.PVLookupLog", qos: .utility)

    func execute() async throws {
        _ = PVLogging.shared
        // PVLookup is a URL package and can't depend on PVLogging; until this
        // runs it logs to os_log.
        let queue = Self.lookupLogQueue
        PVLookupLog.handler = { level, message, file, function, line in
            queue.async {
                switch level {
                case .debug: DLOG(message, file: file, function: function, line: line)
                case .info: ILOG(message, file: file, function: function, line: line)
                case .warning: WLOG(message, file: file, function: function, line: line)
                case .error: ELOG(message, file: file, function: function, line: line)
                }
            }
        }
    }
}
