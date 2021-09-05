//
//  DDLogLevel+CustomStringConvertable.swift
//  JM Core
//
//  Created by Joseph Mattiello on 3/14/19.
//  Copyright © 2019 JM. All rights reserved.
//

import Foundation
import NSLogger
import CocoaLumberjackSwift

extension DDLogLevel {
    var nsloggerLevel: NSLogger.Logger.Level {
        switch self {
        case .error: return .error
        case .warning: return .warning
        case .info: return .info
        case .debug: return .debug
        case .verbose: return .verbose
        default: return .info
        }
    }
}

extension DDLogLevel: CustomStringConvertible {
    public var description: String {
        switch self {
        case .all: return "All"
        case .verbose: return "Verbose"
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warn"
        case .error: return "Error"
        case .off: return "Off"
        @unknown default:
            fatalError()
        }
    }
}

extension DDLogFlag {
    var nsloggerLevel: NSLogger.Logger.Level {
        return self.toLogLevel().nsloggerLevel
    }
}
