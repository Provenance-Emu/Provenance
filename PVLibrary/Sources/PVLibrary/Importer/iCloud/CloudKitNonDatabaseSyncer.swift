//
//  CloudKitNonDatabaseSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import RxSwift
import PVPrimitives
import PVFileSystem
import CloudKit

/// Protocol for non-database file sync operations
public protocol NonDatabaseFileSyncing: SyncProvider {
    /// Get all files in the specified directories
    /// - Returns: Array of file URLs
    func getAllFiles(in directory: String) async -> [URL]
    
    /// Check if a file is downloaded locally
    /// - Parameter filename: The filename to check
    /// - Returns: True if the file is downloaded locally
    func isFileDownloaded(filename: String, in directory: String) async -> Bool
}

/// Non-database file syncer for CloudKit
public class CloudKitNonDatabaseSyncer: CloudKitSyncer, NonDatabaseFileSyncing {
    
    /// Initialize a new non-database file syncer
    /// - Parameters:
    ///   - directories: Directories to manage
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public override init(directories: Set<String> = ["Battery States", "Screenshots", "RetroArch", "DeltaSkins"], notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
    }
    
    /// Get all CloudKit records for files
    /// - Returns: Array of CKRecord objects
    public func getAllRecords() async -> [CKRecord] {
        do {
            // Create a query for all file records
            let query = CKQuery(recordType: CloudKitSchema.RecordType.file, predicate: NSPredicate(value: true))
            
            // Execute the query
            let (records, _) = try await privateDatabase.records(matching: query, resultsLimit: 100)
            
            // Convert to array of CKRecord
            let recordsArray = records.compactMap { _, result -> CKRecord? in
                switch result {
                case .success(let record):
                    return record
                case .failure(let error):
                    ELOG("Error fetching file record: \(error.localizedDescription)")
                    return nil
                }
            }
            
            DLOG("Fetched \(recordsArray.count) file records from CloudKit")
            return recordsArray
        } catch {
            ELOG("Failed to fetch file records: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get all files in the specified directory
    /// - Parameter directory: The directory to get files from
    /// - Returns: Array of file URLs
    public func getAllFiles(in directory: String) async -> [URL] {
        var allFiles: [URL] = []
        
        // Get the documents directory
        let documentsURL = URL.documentsPath
        let directoryURL = documentsURL.appendingPathComponent(directory)
        
        do {
            // Get all files recursively
            if FileManager.default.fileExists(atPath: directoryURL.path) {
                // Get all files in the directory
                let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                
                // Add files to the list
                allFiles.append(contentsOf: fileURLs)
                
                // Get subdirectories
                let subdirectories = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                
                // Process each subdirectory
                for subdirectoryURL in subdirectories {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: subdirectoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        // Get files in subdirectory
                        let subdirectoryFiles = try FileManager.default.contentsOfDirectory(at: subdirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                        allFiles.append(contentsOf: subdirectoryFiles)
                    }
                }
            } else {
                DLOG("Directory does not exist: \(directoryURL.path)")
            }
        } catch {
            ELOG("Error getting files in directory \(directory): \(error.localizedDescription)")
        }
        
        return allFiles
    }
    
    /// Get all files in all managed directories
    /// - Returns: Dictionary mapping directory names to arrays of file URLs
    public func getAllFiles() async -> [String: [URL]] {
        var result: [String: [URL]] = [:]
        
        for directory in directories {
            let files = await getAllFiles(in: directory)
            result[directory] = files
        }
        
        return result
    }
    
    /// Check if a file is downloaded locally
    /// - Parameters:
    ///   - filename: The filename to check
    ///   - directory: The directory to check in
    /// - Returns: True if the file is downloaded locally
    public func isFileDownloaded(filename: String, in directory: String) async -> Bool {
        // Get the documents directory
        let documentsURL = URL.documentsPath
        let directoryURL = documentsURL.appendingPathComponent(directory)
        let fileURL = directoryURL.appendingPathComponent(filename)
        
        // Check if file exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return true
        }
        
        // Check in subdirectories
        do {
            if FileManager.default.fileExists(atPath: directoryURL.path) {
                let subdirectories = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                
                for subdirectoryURL in subdirectories {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: subdirectoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        let subdirectoryFileURL = subdirectoryURL.appendingPathComponent(filename)
                        if FileManager.default.fileExists(atPath: subdirectoryFileURL.path) {
                            return true
                        }
                    }
                }
            }
        } catch {
            ELOG("Error checking subdirectories for file \(filename): \(error.localizedDescription)")
        }
        
        return false
    }
}
