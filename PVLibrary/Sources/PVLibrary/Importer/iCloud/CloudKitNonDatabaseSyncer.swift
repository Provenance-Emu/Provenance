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
                    // Only include records for our managed directories
                    if let directory = record["directory"] as? String,
                       self.directories.contains(directory) {
                        return record
                    }
                    return nil
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
    
    /// Get the count of records for a specific record type and directory
    /// - Parameters:
    ///   - recordType: The record type to count
    ///   - directory: The directory to filter by
    /// - Returns: The count of records
    public func getRecordCount(for recordType: String, withDirectory directory: String) async -> Int {
        do {
            // Create a query for files in the specified directory
            let predicate = NSPredicate(format: "directory == %@", directory)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            
            // Execute the query
            let (records, _) = try await privateDatabase.records(matching: query, resultsLimit: 100)
            
            // Count the records
            let count = records.count
            DLOG("Found \(count) records of type \(recordType) in directory \(directory)")
            
            return count
        } catch {
            ELOG("Error getting record count for \(recordType) in directory \(directory): \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Get all files in the specified directory, including all nested subdirectories
    /// - Parameter directory: The directory to get files from
    /// - Returns: Array of file URLs
    public func getAllFiles(in directory: String) async -> [URL] {
        var allFiles: [URL] = []
        
        // Get the documents directory
        let documentsURL = URL.documentsPath
        let directoryURL = documentsURL.appendingPathComponent(directory)
        
        DLOG("Scanning directory: \(directoryURL.path)")
        
        do {
            // Get all files recursively
            if FileManager.default.fileExists(atPath: directoryURL.path) {
                // Use recursive enumeration to get all files in the directory and subdirectories
                if let enumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        // Check if it's a regular file (not a directory)
                        var isDirectory: ObjCBool = false
                        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                            DLOG("Found file: \(fileURL.path)")
                            allFiles.append(fileURL)
                        }
                    }
                }
                
                DLOG("Found \(allFiles.count) files in \(directory) and its subdirectories")
            } else {
                DLOG("Directory does not exist: \(directoryURL.path)")
            }
        } catch {
            ELOG("Error getting files in directory \(directory): \(error.localizedDescription)")
        }
        
        return allFiles
    }
    
    /// Get the relative path of a file within its parent directory
    /// - Parameters:
    ///   - fileURL: The file URL
    ///   - directoryURL: The parent directory URL
    /// - Returns: The relative path as a string
    private func getRelativePath(for fileURL: URL, in directoryURL: URL) -> String {
        // Get the path components of both URLs
        let fileComponents = fileURL.pathComponents
        let dirComponents = directoryURL.pathComponents
        
        // Find where they diverge
        var relativePath = ""
        if fileComponents.count > dirComponents.count {
            // Extract the components that are unique to the file path
            let relativeComponents = fileComponents.suffix(from: dirComponents.count)
            relativePath = relativeComponents.joined(separator: "/")
        } else {
            // Fallback to just the filename if something went wrong
            relativePath = fileURL.lastPathComponent
        }
        
        return relativePath
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
    
    /// Force sync all files in the specified directory
    /// - Parameter directory: The directory to sync
    /// - Returns: Completable that completes when the sync is done
    public func forceSyncFiles(in directory: String) -> Completable {
        return Completable.create { [weak self] observer in
            Task {
                guard let self = self else {
                    observer(.completed)
                    return
                }
                
                do {
                    // Get all files in the directory
                    let files = await self.getAllFiles(in: directory)
                    let directoryURL = URL.documentsPath.appendingPathComponent(directory)
                    
                    var syncCount = 0
                    
                    // Upload each file
                    for file in files {
                        do {
                            // Get the relative path for the file within its directory
                            let relativePath = self.getRelativePath(for: file, in: directoryURL)
                            
                            DLOG("Uploading file with relative path: \(relativePath)")
                            
                            // Create a custom record with the relative path
                            let recordType = CloudKitSchema.RecordType.file
                            let recordID = CKRecord.ID(recordName: "\(directory)_\(relativePath)")
                            let record = CKRecord(recordType: recordType, recordID: recordID)
                            record["directory"] = directory
                            record["filename"] = relativePath
                            record["fileData"] = CKAsset(fileURL: file)
                            record["lastModified"] = Date()
                            record["relativePath"] = relativePath
                            
                            // Save the record to CloudKit
                            _ = try await self.privateDatabase.save(record)
                            
                            // Track analytics
                            let fileSize: Int64
                            if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                               let size = attributes[.size] as? Int64 {
                                fileSize = size
                            } else {
                                fileSize = 0
                            }
                            
                            await CloudKitSyncAnalytics.shared.recordSuccessfulSync(bytesUploaded: fileSize)
                            
                            syncCount += 1
                            DLOG("Uploaded file: \(relativePath)")
                        } catch {
                            ELOG("Error uploading file \(file.lastPathComponent): \(error.localizedDescription)")
                        }
                    }
                    
                    DLOG("Completed force sync for \(syncCount) files in \(directory)")
                    observer(.completed)
                } catch {
                    ELOG("Error during force sync for directory \(directory): \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
}
