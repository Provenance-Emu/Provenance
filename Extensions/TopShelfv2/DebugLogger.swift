//
//  DebugLogger.swift
//  TopShelfv2
//
//  Created by Joseph Mattiello on 4/15/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import os.log

/// A static class to help debug TopShelf loading issues
@objc public class TopShelfDebugLogger: NSObject {
    
    /// Called when the class is loaded by the Objective-C runtime
    @objc public static let shared = TopShelfDebugLogger()
    
    private override init() {
        super.init()
        logClassLoaded()
    }
    
    /// Log that the class was loaded
    private func logClassLoaded() {
        // Log to system log
        os_log("TopShelfDebugLogger class loaded", log: OSLog.default, type: .debug)
        
        // Write to a file in the shared container
        writeToLogFile("TopShelfDebugLogger class loaded at \(Date().description)")
    }
    
    /// Write a message to the log file
    @objc public func writeToLogFile(_ message: String) {
        let fileManager = FileManager.default
        
        // Try multiple app group IDs to ensure we can write somewhere
        let appGroupIDs = [
            "group.org.provenance-emu.provenance",
            "group.org.provenance-emu"
        ]
        
        for appGroupID in appGroupIDs {
            if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                let logFileURL = containerURL.appendingPathComponent("topshelf_debug_log.txt")
                let logMessage = "\(Date().description): \(message)\n"
                
                do {
                    if fileManager.fileExists(atPath: logFileURL.path) {
                        // Append to existing file
                        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                            fileHandle.seekToEndOfFile()
                            if let data = logMessage.data(using: .utf8) {
                                fileHandle.write(data)
                            }
                            fileHandle.closeFile()
                            return
                        }
                    }
                    
                    // Create new file
                    try logMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
                    return
                } catch {
                    os_log("Failed to write to log file in group %@: %@", log: OSLog.default, type: .error, appGroupID, error.localizedDescription)
                    // Continue to try the next app group
                }
            }
        }
        
        // If we get here, we couldn't write to any app group
        os_log("Could not access any app group container", log: OSLog.default, type: .error)
    }
}

// This will ensure the class is loaded when the extension is loaded
@_cdecl("TopShelfDebugLoggerInitialize")
public func TopShelfDebugLoggerInitialize() {
    _ = TopShelfDebugLogger.shared
}
