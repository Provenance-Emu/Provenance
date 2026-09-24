//
//  QuickLookLog.swift
//  PVQuickLookSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  os.Logger wrapper. PVLogging is not linked here on purpose (keeps the
//  extension dependency graph to Foundation + PVLibrarySnapshot).
//

import Foundation
import os

enum QuickLookLog {
    private static let logger = Logger(subsystem: "org.provenance-emu.provenance", category: "quicklook")

    static func debug(_ message: @autoclosure () -> String) {
        let resolved = message()
        logger.debug("\(resolved, privacy: .public)")
    }

    static func error(_ message: @autoclosure () -> String) {
        let resolved = message()
        logger.error("\(resolved, privacy: .public)")
    }
}
