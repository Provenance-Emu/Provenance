//
//  PVLogging.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/10/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

public protocol PVLoggingEventProtocol: NSObjectProtocol {
    func updateHistory(_ sender: PVLogging)
}

public protocol PVLoggingEntity: AnyObject {
    /**
     *  Obtain paths of any file logs
     *
     *  @return List of file paths, with newest as the first
     */
    var logFilePaths: [String]? { get }
    
    /**
     *  Writes any async logs
     */
    func flushLogs()
    
    //    /**
    //     *  Array of info for the log files such as zie and modification date
    //     *
    //     *  @return Sorted list of info dicts, newest first
    //     */
    //    var logFileInfos: [DDLogFileInfo]? { get }
}

public final
class PVLogging: NSObject {
    
    public private(set) var startupTime: Date = Date()
    
    public private(set) var history: [NSObject] = [NSObject]()
    public private(set) var listeners = [any PVLoggingEventProtocol]()
    
    private var loggingEntity: (any PVLoggingEntity)?
    
    // MARK: Singleton methods
    
    public static let shared = { return PVLogging() }()
    
    public
    class func logNSURLCacheUsage() {
        let mb2b: Float = 1024*1024;
        
        let defaultCache = URLCache.shared
        let defaultCacheSizeMemory: Float = Float(defaultCache.memoryCapacity)
        let defaultCacheSizeDisk  : Float = Float(defaultCache.diskCapacity)
        let usedCacheMemory       : Float = Float(defaultCache.currentMemoryUsage)
        let usedCacheDisk         : Float = Float(defaultCache.currentDiskUsage)
        ILOG(String(format:"Current cache policy\n\tMemory: %2.2fMB (%2.2f) used\tDisk: %2.2fMB (%2.2f) used",
                    defaultCacheSizeMemory/mb2b, usedCacheMemory/mb2b, defaultCacheSizeDisk/mb2b, usedCacheDisk/mb2b))
    }
    
    
    // Virtual methods. No defaults implimentation. You must override these in
    // subclasses
    // MARK: - Virtual Methods
    
    public var logFilePaths: [String]? {
        return loggingEntity?.logFilePaths
    }
    
    public func flushLogs() {
        loggingEntity?.flushLogs()
    }
    
    // MARK: - Listeners
    public func register(listener delegate: any PVLoggingEventProtocol) {
        listeners.append(delegate)
    }
    
    
    public func removeListner(listener delegate: any PVLoggingEventProtocol) {
        listeners.removeAll(where: { $0.hash == delegate.hash })
    }
    
    
    public func notifyListeners() {
        listeners.forEach {
            $0.updateHistory(self)
        }
    }
    
    
    // MARK:  - String
    public var historyString: String {
        return history.map {
            if let hist = $0 as? PVLogEntry {
                return hist.text
            } else {
                return $0.description
            }
        }.joined(separator: "\n")
    }
    
    public var htmlString: String {
        return history.map {
            if let hist = $0 as? PVLogEntry {
                return "\(hist.htmlString)\n<br>"
            } else {
                return "\($0)\n<br>"
            }
        }.joined()
    }
    
    //Gets the iOS version number
    public var systemVersionAsAnInteger: Int = {
        var index: Float = 0
        var version = 0

		#if os(macOS)
		let digits = ["1","2","3"]
		#else
        let digits = UIDevice.current.systemVersion.components(separatedBy: ".")
		#endif
        digits.enumerated().forEach {
            if $0 > 2 { return }
            let multiplier = Int(powf(100, 2-index).rounded())
            version = version + ((Int($1) ?? 1) * multiplier)
        }
        
        return version;
    }()
    
    /**
     This method is responsible for writing the device type, iOS version,
     and the App version.
     */
    public func writeLocalInfo() {
        //        struct utsname systemInfo;
        //        uname(&systemInfo);
        //
        //        NSString *appName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
        //        NSString *appId = [[NSBundle mainBundle] infoDictionary][@"CFBundleIdentifier"];
        //        NSString *buildVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
        //        NSString *appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
        //
        //        NSString *os = @(systemInfo.sysname);
        //        NSString *machine = @(systemInfo.machine);
        //
        //
        //        NSString *gitBranch = [[NSBundle mainBundle] infoDictionary][@"GitBranch"];
        //        NSString *gitTag = [[NSBundle mainBundle] infoDictionary][@"GitTag"];
        //        NSString *gitDate = [[NSBundle mainBundle] infoDictionary][@"GitDate"];
        //
        //
        //        NSString *systemName = [[UIDevice currentDevice] systemName];
        //
        //        NSMutableString *info = [NSMutableString new];
        //
        //        [info appendString:@"\n---------------- App Load ----------------------\n"];
        //        [info appendFormat:@"Load date: %@\n",[NSDate date]];
        //        [info appendFormat:@"App: %@\n",appName];
        //        [info appendFormat:@"System: %@ %@\n", os, machine];
        //        [info appendFormat:@"Device: %@\n", [UIDevice currentDevice].modelName];
        //        [info appendFormat:@"%@ Version: %@\n",systemName, [UIDevice currentDevice].systemVersion];
        //        [info appendFormat:@"App Id: %@\n",appId];
        //        [info appendFormat:@"App Version: %@\n",appVersion];
        //        [info appendFormat:@"Build #: %@\n",buildVersion];
        //
        //        // Append git info if it exists
        //        if (gitBranch && gitBranch.length) {
        //            [info appendFormat:@"Git Branch: %@\n",gitBranch];
        //        }
        //
        //        if (gitTag && gitTag.length) {
        //            [info appendFormat:@"Git Tag: %@\n",gitTag];
        //        }
        //
        //        if (gitDate && gitDate.length) {
        //            [info appendFormat:@"Git Date: %@\n",gitDate];
        //        }
        //
        //        [info appendString:@"------------------------------------------------"];
        //
        //        ILOG(@"%@",info);
    }
    
    public var newestFileLogContentsAsString: String {
        guard let logs = self.logFilePaths, !logs.isEmpty, let path = logs.first else {
            return "NO logs"
        }
        
        if FileManager.default.fileExists(atPath: path) {
            do {
                return try String(contentsOfFile: path, encoding: .utf8)
            } catch {
                return error.localizedDescription
            }
        } else {
            return "No log \(path)"
        }
    }
}
