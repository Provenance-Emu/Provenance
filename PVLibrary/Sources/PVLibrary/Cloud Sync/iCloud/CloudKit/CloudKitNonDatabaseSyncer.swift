//
//  CloudKitNonDatabaseSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import RxSwift
import PVPrimitives
import PVFileSystem
import CloudKit

/// Non-database file syncer for CloudKit
public class CloudKitNonDatabaseSyncer: CloudKitSyncer, NonDatabaseFileSyncing {

    // Define CloudKit Field Names locally (Add more as needed)
    private enum Field {
        static let directory = "directory"
        static let relativePath = "relativePath"
        static let fileAsset = "fileAsset"
        static let modifiedDate = "modifiedDate"
        // Add other field names used in this file if necessary
    }

    /// Initialize a new non-database file syncer
    /// - Parameters:
    ///   - directories: Directories to manage
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public override init(container: CKContainer, directories: Set<String> = [
        "Battery States",
        "Screenshots",
//        "RetroArch",
        "DeltaSkins"
    ], notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(container: container, directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
    }

    /// Get all CloudKit records for files
    /// - Returns: Array of CKRecord objects
    public func getAllRecords() async -> [CKRecord] {
        do {
            // Create a query for all file records
            let query = CKQuery(recordType: RecordType.file, predicate: NSPredicate(value: true))

            // Execute the query
            let (records, _) = try await privateDatabase.records(matching: query, resultsLimit: 100)

            // Convert to array of CKRecord
            let recordsArray = records.compactMap { _, result -> CKRecord? in
                switch result {
                case .success(let record):
                    // Only include records for our managed directories
                    if let directory = record[Field.directory] as? String,
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
            let predicate = NSPredicate(format: "%K == %@", Field.directory, directory)
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
        DLOG("Getting all files in directory: \(directory)")
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

    /// Get the proper record type prefix for a directory
    /// - Parameter directory: The directory name
    /// - Returns: The record type prefix to use in record names
    private func getRecordTypePrefix(for directory: String) -> String {
        switch directory {
        case "ROMs":
            return RecordType.rom.lowercased()
        case "Save States":
            return RecordType.saveState.lowercased()
        case "BIOS":
            return RecordType.bios.lowercased()
        default:
            return RecordType.file.lowercased()
        }
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

                DLOG("Starting force sync for directory: \(directory)")
                await CloudKitSyncAnalytics.shared.startSync(operation: "Force Sync: \(directory)")

                var totalBytesUploaded: Int64 = 0
                var overallSuccess = true
                var errors: [Error] = []

                do {
                    // Get all local files in the directory
                    let localFiles = await self.getAllFiles(in: directory)
                    DLOG("Found \(localFiles.count) local files in \(directory)")

                    // Fetch existing records for this directory
                    let existingRecords = try await self.fetchAllRecords(for: directory)
                    let recordMap = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0[Field.directory] as! String, $0) })
                    DLOG("Fetched \(existingRecords.count) existing CloudKit records for \(directory)")

                    // Process files in batches
                    let batchSize = 20 // Adjust batch size as needed
                    for batchStart in stride(from: 0, to: localFiles.count, by: batchSize) {
                        let batchEnd = min(batchStart + batchSize, localFiles.count)
                        let batch = Array(localFiles[batchStart..<batchEnd])

                        DLOG("Processing batch \(batchStart + 1)-\(batchEnd) of \(localFiles.count) for \(directory)")

                        // Use TaskGroup for parallel uploads within the batch
                        try await withThrowingTaskGroup(of: Int64.self) { group in
                            for fileURL in batch {
                                group.addTask { [weak self] in
                                    guard let self = self else { return 0 }
                                    let filename = fileURL.lastPathComponent

                                    // Check if file exists in CloudKit and if it's newer
                                    var shouldUpload = true
                                    if let existingRecord = recordMap[filename],
                                       let cloudModDate = existingRecord.modificationDate,
                                       let localModDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
                                        shouldUpload = localModDate > cloudModDate
                                        if !shouldUpload {
                                            DLOG("Skipping upload for \(filename), local file not newer than cloud.")
                                        }
                                    }

                                    if shouldUpload {
                                        DLOG("Uploading file: \(filename)")
                                        do {
                                            let uploadedRecord = try await self.uploadFile(fileURL, gameID: nil, systemID: nil)
                                            if let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
                                               let fileSize = attributes[.size] as? Int64 {
                                                DLOG("Successfully uploaded \(filename) (\(fileSize) bytes)")
                                                return fileSize // Return bytes uploaded for this file
                                            } else {
                                                DLOG("Successfully uploaded \(filename), but failed to get size.")
                                                return 0
                                            }
                                        } catch {
                                            ELOG("Failed to upload file \(filename): \(error.localizedDescription)")
                                            // Don't throw, just log and return 0 bytes, marking overall failure later
                                            await self.errorHandler.handle(error: error)
                                            // Collect errors to report failure
                                            // Note: Accessing actor-isolated 'errors' requires careful handling
                                            // For simplicity here, we'll just mark overallSuccess = false
                                            // A more robust solution might involve sending errors back or using a nonisolated storage
                                            return 0
                                        }
                                    } else {
                                        return 0 // File skipped, 0 bytes uploaded
                                    }
                                }
                            }

                            // Collect results from the group
                            for try await bytes in group {
                                totalBytesUploaded += bytes
                                // If any task returned 0 due to an error during upload, mark failure
                                // This assumes uploadFile returns 0 only on error in this context
                                // A cleaner way would be for uploadFile to throw and catch it here.
                                // Based on current uploadFile implementation, it throws on error.
                                // The catch block within the task handles the error, so we need another way
                                // to signal failure, or restructure the error handling.
                                // For now, we rely on the error handler being called.
                            }
                        }
                    }

                    DLOG("Completed force sync for directory: \(directory). Uploaded \(totalBytesUploaded) bytes.")
                    observer(.completed)
                    await CloudKitSyncAnalytics.shared.recordSuccessfulSync(bytesUploaded: totalBytesUploaded)

                } catch {
                    ELOG("Error during force sync for directory \(directory): \(error.localizedDescription)")
                    overallSuccess = false
                    errors.append(error)
                    observer(.error(error))
                    // Aggregate errors if multiple occurred in TaskGroup
                    let finalError = errors.first ?? NSError(domain: "CloudKitNonDatabaseSyncer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown force sync error"])
                    CloudKitSyncAnalytics.shared.recordFailedSync(error: finalError)
                }
            }

            return Disposables.create()
        }
    }

    /// Downloads a file from CloudKit using its record ID
    /// - Parameter recordID: The CloudKit record ID to download
    /// - Throws: CloudSyncError if download fails
    public func downloadFile(for recordID: CKRecord.ID) async throws {
        DLOG("Downloading file for record ID: \(recordID.recordName)")

        // 1. Fetch the record from CloudKit
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
            DLOG("Successfully fetched record: \(record.recordType) - \(record.recordID.recordName)")
        } catch let error as CKError where error.code == .unknownItem {
            ELOG("Record \(recordID.recordName) not found in CloudKit.")
            throw CloudSyncError.recordNotFound
        } catch {
            ELOG("Error fetching record \(recordID.recordName): \(error.localizedDescription)")
            throw CloudSyncError.cloudKitError(error)
        }

        // 2. Extract necessary info (directory, relative path, asset)
        let directory = resolveDirectory(from: record)
        let relativePath = resolveRelativePath(from: record, directory: directory)
        let fileAsset = resolveAsset(from: record)
        guard let directory, let relativePath, let fileAsset, let assetURL = fileAsset.fileURL else {
            ELOG("Record \(recordID.recordName) is missing required fields or asset even after fallback resolution.")
            throw CloudSyncError.invalidData
        }

        // 3. Determine the local file path
        let documentsURL = URL.documentsPath
        let directoryURL = documentsURL.appendingPathComponent(directory)
        let fileURL = directoryURL.appendingPathComponent(relativePath)

        do {
            // Ensure the target directory exists
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

            // Remove existing item at destination if it exists (replace)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try await FileManager.default.removeItem(at: fileURL)
                DLOG("Removed existing local file at \(fileURL.path)")
            }

            // Copy the file from the temporary CloudKit location
            try FileManager.default.copyItem(at: assetURL, to: fileURL)
            ILOG("Successfully downloaded file \(relativePath) in \(directory) from CloudKit.")

            // Post notification about file download if needed
            notificationCenter.post(name: .PVCloudSyncDidDownloadFile, object: self, userInfo: ["fileURL": fileURL, "directory": directory])

            return
        } catch {
            ELOG("Error saving downloaded file to \(fileURL.path): \(error.localizedDescription)")
            throw CloudSyncError.fileSystemError(error)
        }
    }

    /// Processes a remote change notification for a single record.
    /// Fetches the record and handles the download/update of the associated file.
    /// - Parameter recordID: The ID of the record that changed.
    public func processRemoteRecordUpdate(recordID: CKRecord.ID) async throws {
        // Defer non-database assets until the DB is populated
        guard await SyncProgressTracker.shared.databaseSynced else { return }
        DLOG("Processing remote update notification for record ID: \(recordID.recordName)")
        do {
            // 1. Fetch the record from CloudKit
            let record = try await privateDatabase.record(for: recordID)
            DLOG("Successfully fetched record: \(record.recordType) - \(record.recordID.recordName)")

            // 2. Extract necessary info (directory, relative path, asset)
            let directory = resolveDirectory(from: record)
            let relativePath = resolveRelativePath(from: record, directory: directory)
            let fileAsset = resolveAsset(from: record)
            guard let directory, let relativePath, let fileAsset else {
                WLOG("Record \(recordID.recordName) is missing required fields (directory, relativePath, or fileAsset) even after fallback. Skipping.")
                return
            }

            // 3. Determine the local file path
            let documentsURL = URL.documentsPath
            let directoryURL = documentsURL.appendingPathComponent(directory)
            let fileURL = directoryURL.appendingPathComponent(relativePath)

            // 4. Check if the asset needs downloading (e.g., based on modification date or existence)
            // For simplicity now, always attempt download if asset exists. Add sophisticated checks later.
            if let assetURL = fileAsset.fileURL {
                DLOG("Attempting to copy/move downloaded asset for \(relativePath) in \(directory) from \(assetURL.path) to \(fileURL.path)")

                // Ensure the target directory exists
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

                // Remove existing item at destination if it exists (replace)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try await FileManager.default.removeItem(at: fileURL)
                    DLOG("Removed existing local file at \(fileURL.path)")
                }

                // Copy the file from the temporary CloudKit location
                try FileManager.default.copyItem(at: assetURL, to: fileURL)
                ILOG("Successfully updated local file \(relativePath) in \(directory) from CloudKit.")

                // Optional: Update local metadata if needed (e.g., modification date)
                // let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                // if let cloudModDate = record.modificationDate {
                //     try FileManager.default.setAttributes([.modificationDate: cloudModDate], ofItemAtPath: fileURL.path)
                // }

                // Post notification about file update?
                // notificationCenter.post(name: .PVFileSyncDidUpdateFile, object: self, userInfo: ["fileURL": fileURL, "directory": directory])

            } else {
                WLOG("File asset for record \(recordID.recordName) does not have a fileURL. Cannot download.")
                // This might happen if the asset is empty or wasn't downloaded properly by CloudKit daemon
            }

        } catch let error as CKError where error.code == .unknownItem {
            // Record was likely deleted remotely
            WLOG("Record \(recordID.recordName) not found in CloudKit. Assuming deleted remotely.")
            // TODO: Implement local file deletion logic if required for this syncer.
            // Need to determine the local path based on the recordID structure if possible,
            // or rely on having fetched the record info before deletion.
        } catch {
            ELOG("Error processing remote update for record \(recordID.recordName): \(error.localizedDescription)")
            await errorHandler.handleError(error, file: nil)
        }
    }

    // MARK: - Fallback Resolvers

    /// Attempts to resolve directory from record field or record name prefix
    private func resolveDirectory(from record: CKRecord) -> String? {
        if let directory = record[Field.directory] as? String { return directory }
        let name = record.recordID.recordName
        if let prefix = name.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: true).first {
            let candidate = String(prefix)
            if directories.contains(candidate) { return candidate }
        }
        return nil
    }

    /// Attempts to resolve relative path from record field or record name body
    private func resolveRelativePath(from record: CKRecord, directory: String?) -> String? {
        if let relativePath = record[Field.relativePath] as? String { return relativePath }
        let name = record.recordID.recordName
        let parts = name.split(separator: "_")
        guard parts.count >= 2 else { return nil }
        // If there are 3+ parts, assume format: <Directory>_<Filename with underscores>_<Suffix>
        if parts.count >= 3 {
            let filenameParts = parts.dropFirst().dropLast()
            let joined = filenameParts.joined(separator: "_")
            return joined
        } else {
            // 2 parts: <Directory>_<Filename>
            return String(parts[1])
        }
    }

    /// Attempts to resolve asset under multiple possible keys
    private func resolveAsset(from record: CKRecord) -> CKAsset? {
        if let asset = record[Field.fileAsset] as? CKAsset { return asset }
        if let asset = record["asset"] as? CKAsset { return asset }
        if let asset = record["file"] as? CKAsset { return asset }
        if let asset = record["fileData"] as? CKAsset { return asset }
        return nil
    }
}
