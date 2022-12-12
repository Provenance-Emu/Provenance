//  Converted to Swift 5.4 by Swiftify v5.4.24488 - https://swiftify.com/
//
//  PVCocoaLumberJackLogging.m
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

@_exported import CocoaLumberjack
import Foundation

@objc
public class PVCocoaLumberJackLogging: NSObject, PVLoggingEntity {
    private var fileLogger: DDFileLogger = {
        let fileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hour rolling
        fileLogger.doNotReuseLogFiles = true
        fileLogger.logFileManager.maximumNumberOfLogFiles = 5
        return fileLogger
    }()

//    #if canImport(NSLogger)
    private var nsLogger: JMLumberjackNSLogger = {
        return JMLumberjackNSLogger()
    }()
//    #endif
    func enableExtraLogging() {
    }

    @objc
    public override init() {
        super.init()
        // Only log to console if we're running non-appstore build
        // For speed. File logging only is the fastest (async flushing)

#if DEBUG
        // Always enable for debug builds
        DDLog.add(DDOSLogger.sharedInstance, with: .debug)
#else
        DDLog.add(DDOSLogger.sharedInstance, with: .warning)
#endif

        DDLog.add(fileLogger, with: .warning)
// #if canImport(NSLogger)
        #if DEBUG
        DDLog.add(nsLogger, with: .verbose)
        #else
        DDLog.add(nsLogger, with: .debug)
        #endif
// #endif
    }

    public func logFilePaths() -> [String]? {
        return fileLogger.logFileManager.sortedLogFilePaths
    }

    public func logFileInfos() -> [Any]? {
        return fileLogger.logFileManager.sortedLogFileInfos
    }

    public func flushLogs() {
        DDLog.flushLog()
    }
}
