//
// PVLogging.swift
// Created by: Joe Mattiello
// Creation Date: 1/4/23
//

import Foundation
import System
#if canImport(UIKit)
import UIKit
#endif
import os

@_exported import PVLoggingObjC

let LOGGING_STACK_SIZE = 1024
let ISO_TIMEZONE_UTC_FORMAT: String = "Z"
let ISO_TIMEZONE_OFFSET_FORMAT: String = "%+02d%02d"

@objcMembers
public final class PVLogging: NSObject {
    @objc(sharedInstance)
    public static let shared = PVLogging()

    public var entity: PVLoggingEntity?
    public let startupTime: Date = Date()
    
    public private(set) var history = [PVLogEntry]()
    private var listeners = Array<any PVLoggingEventProtocol>()

    // MARK: - Static
    public static var systemVersionAsInteger: Int {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion * 10000 + version.minorVersion * 100 + version.patchVersion
    }

    // MARK: - Init
    public override init() {
        super.init()
        setupLogging()
    }

    public func setupLogging() {
        //        #if canImport(CocoaLumberjackSwift)
        //        entity = PVCocoaLumberJackLogging()
        //        #endif
    }

    // MARK: - Virtual Methods
    /**
     *  Writes any async logs
     */
    public func flushLogs() {
        self.entity?.flushLogs()
    }

    public func enableExtraLogging() {
        entity?.enableExtraLogging()
    }

    /**
     *  Obtain paths of any file logs
     *
     *  @return List of file paths, with newest as the first
     */
    public func logFilePaths() -> [String]? {
        return entity?.logFilePaths
    }

    public func add(_ event: AnyObject) {
        if history.count >= LOGGING_STACK_SIZE {
            history.removeLast()
        }
        let entry: PVLogEntry
        if let event = event as? PVLogEntry {
            entry = event
        } else {
            if let event = event as? String {
                entry = PVLogEntry(message: event)
            } else {
                entry = PVLogEntry(message: "\(event)")
            }
        }
        history.insert(entry, at: 0)
        log(entry)
        PVLogging.shared.notifyListeners()
    }

    @available(iOS 14.0, tvOS 14.0, *)
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!, category: "App")

    fileprivate func log(_ entry: PVLogEntry) {
        // TODO: Add array of "loggers" for os_log, nslogger
        // and iterate through them
//        if #available(iOS 14.0, tvOS 14.0, *) {
//            switch entry.level {
//            case .Debug:
//                Self.logger.log(level: .debug, .init(stringLiteral: entry.string))
//            case .Error:
//                Self.logger.log(level: .error, .init(stringLiteral: entry.string))
//            case .Warn:
//                Self.logger.log(level: .error, .init(stringLiteral: entry.string))
//            case .U:
//                Self.logger.log(level: .fault, .init(stringLiteral: entry.string))
//            case .Info:
//                Self.logger.log(level: .info, .init(stringLiteral: entry.string))
//            }
//        }
    }


    /**
     *  Array of info for the log files such as zie and modification date
     *
     *  @return Sorted list of info dicts, newest first
     */
    public func logFileInfos() -> [Any]? {
        return entity?.logFileInfos
    }
    //
    //    public func logFileData() -> Data? {
    //        return entity?.logFileData()
    //    }
    //
    //    public func logFileDataAsString() -> String? {
    //        return entity?.logFileDataAsString()
    //    }
    //
    //    public func logFileDataAsAttributedString() -> NSAttributedString? {
    //        return entity?.logFileDataAsAttributedString()
    //    }

    // MARK: - Listeners
    @objc(registerListener:)
    public func register(listener: any PVLoggingEventProtocol) {
        listeners.insert(listener, at: 0)
    }

    @objc(removeListener:)
    public func remove(listener: any PVLoggingEventProtocol) {
        //        listeners.removeAll(where: {$0 == listener})
    }

    /**
     *  Notify listerners of log updates
     */
    public func notifyListeners() {
        listeners.forEach { $0.updateHistory(sender: self) }
    }

    // MARK: - Computed
    public var historyString: String {
        return history.map { $0.debugDescription }.joined(separator: "\n")
    }

    public var htmlString: String {
        return history.map { $0.htmlString }.joined(separator: "\n<br>")
    }

    // MARK: - Helpers
    /**
     Write local information about the device to the file log
     */
    public func writeLocalInfo() {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown"
        let appId = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? "Unknown"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let machine = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Unknown"

        let gitBranch = Bundle.main.infoDictionary?["GitBranch"] as? String ?? "Unknown"
        let gitTag = Bundle.main.infoDictionary?["GitTag"] as? String ?? "Unknown"
        let gitDate = Bundle.main.infoDictionary?["GitDate"] as? String ?? "Unknown"

        var info: String = """
        \n---------------- App Load ----------------------\n
        Load date: \(Date())
        App: \(appName)
        System: \(os) \(machine)
        App Id: \(appId)
        App Version: \(appVersion)
        Build #: \(buildVersion)
        """

        // Append git info if it exists
        if !gitBranch.isEmpty {
            info += "Git Branch: \(gitBranch)"
        }
        if !gitTag.isEmpty {
            info += "Git Tag: \(gitTag)"
        }
        if !gitDate.isEmpty {
            info += "Git Date: \(gitDate)"
        }
        info += "----------------------------------------------------------------"
        ILOG(info)
    }

    public func newestFileLogContentsAsString() -> String {
        let logFilePaths = self.entity?.logFilePaths
        if let logFilePath = logFilePaths?.last {
            do {
                let logFileContents = try String(contentsOfFile: logFilePath)
                return logFileContents
            } catch {
                ELOG("Error reading log file: \(error)")
            }
        }
        return ""
    }

    public static func logNSURLCacheUsage() {
        let defaultCache = URLCache.shared
        let defaultCacheSizeMemory = defaultCache.memoryCapacity
        let defaultCacheSizeDisk = defaultCache.diskCapacity
        let defaultCacheSizeMemoryMB = defaultCacheSizeMemory / 1024 / 1024
        let defaultCacheSizeDiskMB = defaultCacheSizeDisk / 1024 / 1024
        let usedCachedMemory = defaultCache.currentMemoryUsage / 1024 / 1024
        let usedDiskCache = defaultCache.currentDiskUsage / 1024 / 1024
        ILOG("URLCache: Memory: \(defaultCacheSizeMemoryMB)MB, Disk: \(defaultCacheSizeDiskMB)MB\nUsed Memory: \(usedCachedMemory)MB, Used Disk: \(usedDiskCache)MB")
    }
}
//
//@_cdecl("PVLog")
//public func PVLog(level: DDLogLevel, flag: DDLogFlag, file: String, function: String?, line: UInt, message: String) {
//    let logMessage = DDLogMessage(message: message,
//                                  level: level,
//                                  flag: flag,
//                                  context: 0,
//                                  file: file,
//                                  function: function,
//                                  line: line,
//                                  tag: nil,
//                                  timestamp: Date())
//    let asynchronous: Bool = level == .error
//    DDLog.sharedInstance.log(asynchronous: asynchronous, message: logMessage)
//}
