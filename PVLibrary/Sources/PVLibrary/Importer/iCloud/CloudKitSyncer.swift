//
//  CloudKitSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import Combine
import PVLogging
import PVSupport
import RealmSwift
import RxRealm
import RxSwift
import PVPrimitives
import PVFileSystem
import PVRealm

#if os(tvOS)
/// CloudKit-based sync provider for tvOS
/// Implements the SyncProvider protocol to provide a consistent interface
/// with the iCloudContainerSyncer used on iOS/macOS
public class CloudKitSyncer: SyncProvider {
    // MARK: - Properties
    
    public lazy var pendingFilesToDownload: ConcurrentSet<URL> = []
    public lazy var newFiles: ConcurrentSet<URL> = []
    public lazy var uploadedFiles: ConcurrentSet<URL> = []
    public let directories: Set<String>
    public let fileManager: FileManager = .default
    public let notificationCenter: NotificationCenter
    public var status: iCloudSyncStatus = .initialUpload
    public let errorHandler: CloudSyncErrorHandler
    public var initialSyncResult: SyncResult = .indeterminate
    public var fileImportQueueMaxCount = 1000
    public var purgeStatus: DatastorePurgeStatus = .incomplete
    
    // CloudKit specific properties
    internal let container: CKContainer
    internal let privateDatabase: CKDatabase
    private var subscriptionToken: AnyCancellable?
    
    // MARK: - Initialization
    
    /// Initialize a new CloudKit syncer
    /// - Parameters:
    ///   - directories: Set of directories to sync
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(directories: Set<String>, notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        self.notificationCenter = notificationCenter
        self.directories = directories
        self.errorHandler = errorHandler
        
        // Initialize CloudKit container
        self.container = CKContainer(identifier: "iCloud.com.provenance-emu.provenance")
        self.privateDatabase = container.privateCloudDatabase
        
        // Register with the syncer store
        CloudKitSyncerStore.shared.register(syncer: self)
        
        // Set up CloudKit subscription for changes
        setupSubscription()
    }
    
    deinit {
        // Unregister from the syncer store
        CloudKitSyncerStore.shared.unregister(syncer: self)
        subscriptionToken?.cancel()
    }
    
    // MARK: - SyncProvider Protocol Implementation
    
    /// Load all files from CloudKit
    /// - Parameter iterationComplete: Callback when iteration is complete
    /// - Returns: Completable that completes when all files are loaded
    public func loadAllFromCloud(iterationComplete: (() -> Void)?) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.completed)
                return Disposables.create()
            }
            
            Task {
                do {
                    // Fetch all records for the directories we're responsible for
                    let records = try await self.fetchRecordsForDirectories()
                    
                    // Process records
                    for record in records {
                        await self.processCloudKitRecord(record)
                    }
                    
                    // Set initial sync result and notify
                    self.initialSyncResult = .success
                    self.notificationCenter.post(name: .iCloudSyncCompleted, object: self)
                    
                    observer(.completed)
                    iterationComplete?()
                } catch {
                    ELOG("CloudKit sync error: \(error.localizedDescription)")
                    self.errorHandler.handle(error: error)
                    self.initialSyncResult = .saveFailure
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// Insert a file that is being downloaded
    /// - Parameter file: URL of the file
    /// - Returns: URL of the file or nil if already being uploaded
    public func insertDownloadingFile(_ file: URL) -> URL? {
        guard !uploadedFiles.contains(file) else {
            return nil
        }
        pendingFilesToDownload.insert(file)
        return file
    }
    
    /// Insert a file that has been downloaded
    /// - Parameter file: URL of the file
    public func insertDownloadedFile(_ file: URL) {
        pendingFilesToDownload.remove(file)
    }
    
    /// Insert a file that has been uploaded
    /// - Parameter file: URL of the file
    public func insertUploadedFile(_ file: URL) {
        uploadedFiles.insert(file)
    }
    
    /// Delete a file from the datastore
    /// - Parameter file: URL of the file
    public func deleteFromDatastore(_ file: URL) {
        Task {
            do {
                // Find and delete the record for this file
                let record = try await findRecordForFile(file)
                if let recordID = record?.recordID {
                    try await privateDatabase.deleteRecord(withID: recordID)
                    DLOG("Deleted CloudKit record for file: \(file.lastPathComponent)")
                }
            } catch {
                ELOG("Failed to delete CloudKit record: \(error.localizedDescription)")
                errorHandler.handle(error: error)
            }
        }
    }
    
    /// Notify that new cloud files are available
    public func setNewCloudFilesAvailable() {
        if pendingFilesToDownload.isEmpty {
            status = .filesAlreadyMoved
            DLOG("Set status to \(status) and removing all uploaded files in \(directories)")
            uploadedFiles.removeAll()
        }
    }
    
    /// Prepare the next batch of files to process
    /// - Returns: Collection of URLs to process
    public func prepareNextBatchToProcess() -> any Collection<URL> {
        DLOG("\(directories): newFiles: (\(newFiles.count)):")
        let nextFilesToProcess = newFiles.prefix(fileImportQueueMaxCount)
        
        // Remove processed files from the new files set
        for file in nextFilesToProcess {
            newFiles.remove(file)
        }
        
        return nextFilesToProcess
    }
    
    // MARK: - CloudKit Specific Methods
    
    /// Set up subscription to CloudKit changes
    private func setupSubscription() {
        // Create a subscription for each directory
        Task {
            do {
                for directory in directories {
                    let predicate = NSPredicate(format: "directory == %@", directory)
                    let subscription = CKQuerySubscription(
                        recordType: "File",
                        predicate: predicate,
                        subscriptionID: "com.provenance-emu.provenance.directory.\(directory)",
                        options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
                    )
                    
                    let notificationInfo = CKSubscription.NotificationInfo()
                    notificationInfo.shouldSendContentAvailable = true
                    subscription.notificationInfo = notificationInfo
                    
                    try await privateDatabase.save(subscription)
                    DLOG("Created CloudKit subscription for directory: \(directory)")
                }
            } catch {
                ELOG("Failed to create CloudKit subscription: \(error.localizedDescription)")
                errorHandler.handle(error: error)
            }
        }
        
        // Set up notification handler for remote notifications
        subscriptionToken = NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                self?.handleCloudKitAccountChanged()
            }
    }
    
    /// Handle CloudKit account changes
    private func handleCloudKitAccountChanged() {
        Task {
            do {
                // Check account status
                let accountStatus = try await container.accountStatus()
                
                switch accountStatus {
                case .available:
                    DLOG("CloudKit account is available, refreshing data")
                    // Load cloud data
                    _ = try? await loadAllFromCloud(iterationComplete: nil).value
                case .noAccount, .restricted, .couldNotDetermine:
                    ELOG("CloudKit account is not available: \(accountStatus)")
                    initialSyncResult = .denied
                @unknown default:
                    ELOG("Unknown CloudKit account status: \(accountStatus)")
                    initialSyncResult = .indeterminate
                }
            } catch {
                ELOG("Error checking CloudKit account status: \(error.localizedDescription)")
                errorHandler.handle(error: error)
            }
        }
    }
    
    /// Fetch records for all directories this syncer is responsible for
    /// - Returns: Array of CKRecord objects
    private func fetchRecordsForDirectories() async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        
        for directory in directories {
            let predicate = NSPredicate(format: "directory == %@", directory)
            let query = CKQuery(recordType: "File", predicate: predicate)
            
            let (results, _) = try await privateDatabase.records(matching: query)
            let records = results.compactMap { _, result in
                try? result.get()
            }
            
            allRecords.append(contentsOf: records)
        }
        
        return allRecords
    }
    
    /// Process a CloudKit record and create local file
    /// - Parameter record: The CloudKit record to process
    private func processCloudKitRecord(_ record: CKRecord) async {
        // Extract file data and metadata from the record
        guard let directory = record["directory"] as? String,
              let filename = record["filename"] as? String,
              let asset = record["fileData"] as? CKAsset,
              let fileURL = asset.fileURL else {
            return
        }
        
        // Create local file path
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directoryURL = documentsURL.appendingPathComponent(directory)
        let destinationURL = directoryURL.appendingPathComponent(filename)
        
        do {
            // Create directory if needed
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            
            // Copy file from asset to local storage
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try await FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            
            // Add to new files for processing
            newFiles.insert(destinationURL)
            DLOG("Processed CloudKit record for file: \(filename) in directory: \(directory)")
        } catch {
            ELOG("Error processing CloudKit record: \(error.localizedDescription)")
            errorHandler.handle(error: error)
        }
    }
    
    /// Find a CloudKit record for a local file
    /// - Parameter file: The local file URL
    /// - Returns: The corresponding CloudKit record, if found
    private func findRecordForFile(_ file: URL) async throws -> CKRecord? {
        // Extract directory and filename
        let directoryComponents = file.pathComponents
        guard let directoryIndex = directoryComponents.firstIndex(where: { directories.contains($0) }),
              directoryIndex < directoryComponents.count - 1 else {
            return nil
        }
        
        let directory = directoryComponents[directoryIndex]
        let filename = file.lastPathComponent
        
        // Create query
        let predicate = NSPredicate(format: "directory == %@ AND filename == %@", directory, filename)
        let query = CKQuery(recordType: "File", predicate: predicate)
        
        // Execute query
        let (results, _) = try await privateDatabase.records(matching: query)
        let records = results.compactMap { _, result in
            try? result.get()
        }
        
        return records.first
    }
    
    /// Upload a local file to CloudKit
    /// - Parameter file: The local file URL to upload
    /// - Returns: The created CloudKit record
    public func uploadFile(_ file: URL) async throws -> CKRecord {
        // Extract directory and filename
        let directoryComponents = file.pathComponents
        guard let directoryIndex = directoryComponents.firstIndex(where: { directories.contains($0) }),
              directoryIndex < directoryComponents.count - 1 else {
            throw NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "File is not in a managed directory"])
        }
        
        let directory = directoryComponents[directoryIndex]
        let filename = file.lastPathComponent
        
        // Check if record already exists
        if let existingRecord = try await findRecordForFile(file) {
            // Update existing record
            existingRecord["fileData"] = CKAsset(fileURL: file)
            existingRecord["lastModified"] = Date()
            
            let updatedRecord = try await privateDatabase.save(existingRecord)
            DLOG("Updated CloudKit record for file: \(filename) in directory: \(directory)")
            return updatedRecord
        } else {
            // Create new record
            let recordID = CKRecord.ID(recordName: "\(directory)_\(filename)")
            let record = CKRecord(recordType: "File", recordID: recordID)
            record["directory"] = directory
            record["filename"] = filename
            record["fileData"] = CKAsset(fileURL: file)
            record["lastModified"] = Date()
            
            let savedRecord = try await privateDatabase.save(record)
            DLOG("Created CloudKit record for file: \(filename) in directory: \(directory)")
            return savedRecord
        }
    }
    
    /// Notify that new cloud files are available
    public override func setNewCloudFilesAvailable() {
        // Post notification that new files are available
        DLOG("New CloudKit files available")
        notificationCenter.post(name: Notification.Name("NewCloudFilesAvailable"), object: self)
    }
    
    /// Prepare the next batch of files to process
    /// - Returns: Collection of URLs to process
    public override func prepareNextBatchToProcess() -> any Collection<URL> {
        let batch = Array(pendingFilesToDownload.prefix(fileImportQueueMaxCount))
        DLOG("Preparing batch of \(batch.count) CloudKit files to process")
        return batch
    }
}
#endif
