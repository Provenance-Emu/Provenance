//
//  PVCocoaLumberJackLogging.m
//  PVLogging
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

@_exported import CocoaLumberjack
//@_exported import CocoaLumberjackSwiftLogBackend
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

    #if canImport(NSLogger)
    private var nsLogger: JMLumberjackNSLogger = {
        return JMLumberjackNSLogger()
    }()
    #endif
    public func enableExtraLogging() {
    }

    @objc
    public override init() {
        super.init()
        // Only log to console if we're running non-appstore build
        // For speed. File logging only is the fastest (async flushing)

#if DEBUG
        // Always enable for debug builds
        DDLog.add(DDOSLogger.sharedInstance, with: .verbose)
//        DDLog.add(DDTTYLogger.sharedInstance, with: .verbose)
#else
        DDLog.add(DDOSLogger.sharedInstance, with: .info)
#endif

        DDLog.add(fileLogger, with: .warning)
 #if canImport(NSLogger)
        #if DEBUG
        DDLog.add(nsLogger, with: .verbose)
        #else
        DDLog.add(nsLogger, with: .debug)
        #endif
 #endif
        
//        LoggingSystem.bootstrapWithCocoaLumberjack() // Use CocoaLumberjack as swift-log backend
    }

    public var logFilePaths: [String]? {
        return fileLogger.logFileManager.sortedLogFilePaths
    }

    public var logFileInfos: [AnyObject]? {
        return fileLogger.logFileManager.sortedLogFileInfos
    }

    public func flushLogs() {
        DDLog.flushLog()
    }
}
