//
//  CloudKitSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import RealmSwift
import PVSystems
import RegexBuilder
import RxRealm
import RxSwift
import PVLogging
import PVSupport
import Combine
import PVFileSystem
import PVRealm
import CryptoKit

/// CloudKit-based sync provider for all OS's
/// Implements the SyncProvider protocol to provide a consistent interface
/// with the `iCloudContainerSyncer` used on iOS/macOS
public class CloudKitSyncer: SyncProvider {
    // MARK: - Local Schema Definitions (Replacing CloudKitSchema)

    // Record Types
    enum RecordType {
        static let rom = "ROM"
        static let saveState = "SaveState"
        static let bios = "BIOS"
        static let file = "File" // Used by NonDatabaseSyncer, potentially relevant here indirectly?
        // Add others if needed by CloudKitSyncer subclasses
    }

    // Common File Attributes (Potentially used by multiple record types)
    enum FileAttributes {
        static let fileData = "fileData"      // CKAsset containing the file data
        static let lastModified = "lastModified"    // Date last modified
        static let fileSize = "fileSize"              // File size in bytes
        static let md5 = "md5"                // MD5 hash of the file
        static let system = "system" // String identifier for the related PVSystem
        static let gameID = "gameID" // String identifier for the related PVGame
        static let directory = "directory"        // Original directory (less likely used for synced records?)
        static let filename = "filename"        // Original filename (less likely used for synced records?)
        // Attributes below might be less common across all types
    }

    // ROM Specific Attributes (Extends common attributes)
    enum ROMAttributes {
        // Uses FileAttributes: fileData, lastModified, fileSize, md5, system, gameID
        static let title = "title"              // String title
        static let systemIdentifier = "systemIdentifier" // String identifier for the related PVSystem
        // Add other PVGame fields synced: isFavorite, importDate?, etc.
    }

    // SaveState Specific Attributes (Extends common attributes)
    enum SaveStateAttributes {
        // Uses FileAttributes: fileData, lastModified, fileSize, gameID
        static let description = "description"      // String description
        // Add other PVSaveState fields synced: date?, lastOpened?
    }

    // BIOS Specific Attributes (Extends common attributes)
    enum BIOSAttributes {
        // Uses FileAttributes: fileData, lastModified, fileSize, md5, system
        static let expectedFilename = "expectedFilename" // String expected filename
        static let descriptionText = "descriptionText" // String description
        static let expectedSize = "expectedSize"    // Int expected size
        static let optional = "optional"          // Bool if BIOS is optional
        // Add other PVBIOS fields synced
    }

    // MARK: - Properties

    public lazy var pendingFilesToDownload: ConcurrentSet<URL> = []
    public lazy var newFiles: ConcurrentSet<URL> = []
    public lazy var uploadedFiles: ConcurrentSet<URL> = []

    /// Optional operation queue for pausable/cancellable scheduling
    public var workQueue: OperationQueue?

    /// Execute work on the configured operation queue if present, otherwise run inline.
    /// This allows all IO (network/file) to be serialized/suspended with emulation pauses.
    @discardableResult
    internal func runOnQueue<T>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        guard let queue = workQueue else {
            return try await work()
        }

        return try await withCheckedThrowingContinuation { continuation in
            let op = BlockOperation()
            op.addExecutionBlock { [weak op] in
                guard let op, !op.isCancelled else {
                    continuation.resume(throwing: CloudSyncError.genericError("Operation cancelled"))
                    return
                }
                Task {
                    do {
                        if Task.isCancelled { throw CloudSyncError.genericError("Task cancelled") }
                        let result = try await work()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            queue.addOperation(op)
        }
    }

    // File type extensions
    private let saveStateExtensions = ["svs"]

    // Use the existing biosCache from RomDatabase
    public let directories: Set<String>
    public let fileManager: FileManager = .default
    public let notificationCenter: NotificationCenter
    public var status: ConcurrentSingle<iCloudSyncStatus> = .init(.initialUpload)
    public let errorHandler: CloudSyncErrorHandler
    public var initialSyncResult: SyncResult = .indeterminate
    public var fileImportQueueMaxCount = 1000
    public var purgeStatus: DatastorePurgeStatus = .incomplete

    // CloudKit specific properties
    internal let container: CKContainer
    internal let privateDatabase: CKDatabase
    private var subscriptionToken: AnyCancellable?

    /// The CloudKit record type for this syncer
    /// Subclasses should override this property

    /// Batch processing configuration
    public struct BatchConfig {
        /// Maximum number of files to process in a single batch
        public var maxBatchSize: Int = 20

        /// Minimum number of files to process in a single batch
        public var minBatchSize: Int = 5

        /// Whether to use parallel processing within batches
        public var useParallelProcessing: Bool = true
    }

    /// Default batch configuration
    public var batchConfig = BatchConfig()
    public var recordType: String {
        return getRecordType()
    }

    // MARK: - Initialization

    /// Initialize a new CloudKit syncer
    /// - Parameters:
    ///   - container: CloudKit container
    ///   - directories: Set of directories to sync
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(container: CKContainer, directories: Set<String>, notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler = CloudSyncErrorHandler()) {
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
        self.directories = directories
        self.notificationCenter = notificationCenter
        self.errorHandler = errorHandler

        // Initialize CloudKit schema
        Task {
            _ = await CloudKitSchema.initializeSchema(in: privateDatabase)
        }

        // Register with the syncer store
        CloudKitSyncerStore.shared.register(syncer: self)
    }

    deinit {
        // Unregister from the syncer store
        CloudKitSyncerStore.shared.unregister(syncer: self)
        subscriptionToken?.cancel()
    }

    // MARK: - SyncProvider Protocol Implementation

    /// Load all files from cloud storage
    /// - Parameter iterationComplete: Callback when iteration is complete
    /// - Returns: Completable that completes when all files are loaded
    public func loadAllFromCloud(iterationComplete: (() async -> Void)?) async -> Completable {
        DLOG("Loading all records from CloudKit for \(recordType)")

        // Start analytics tracking
        await CloudKitSyncAnalytics.shared.startSync(operation: "Load All: \(recordType)")

        return Completable.create { [weak self] completable in
            guard let self = self else {
                completable(.completed)
                return Disposables.create()
            }

            Task {
                do {
                    // Fetch all records from CloudKit
                    let records = try await self.fetchAllRecords()
                    DLOG("Fetched \(records.count) records from CloudKit")

                    // For ROM records, prioritize creating database entries first
                    if self.recordType == CloudKitSyncer.RecordType.rom || self.recordType == "Game" {
                        DLOG("Creating database entries for \(records.count) ROM records")
                        // Create database entries for all ROMs first to ensure they appear in the UI
                        for record in records {
                            // Extract directory and filename with fallbacks
                            if let directory = record["directory"] as? String,
                               let filename = record["filename"] as? String {
                                await self.createDatabaseEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: false)
                            }
                        }
                        DLOG("Completed creating database entries for ROMs")
                    }

                    // Process records in batches
                    await self.processRecordsInBatches(records)

                    // Call iteration complete callback
                    await iterationComplete?()

                    // Set initial sync result and notify
                    self.initialSyncResult = .success
                    self.notificationCenter.post(name: .iCloudSyncCompleted, object: self)

                    DLOG("Completed loading all records from CloudKit")
                    completable(.completed)

                    // Record successful sync
                    await CloudKitSyncAnalytics.shared.recordSuccessfulSync()
                } catch {
                    ELOG("Error loading records from CloudKit: \(error.localizedDescription)")
                    // Record failure
                    await CloudKitSyncAnalytics.shared.recordFailedSync(error: error)
                    await self.errorHandler.handle(error: error)
                    self.initialSyncResult = .saveFailure
                    completable(.error(error))
                }
            }

            return Disposables.create()
        }
    }

    @inline(__always)
    private func withBackgroundRealm<T: Sendable>(
        _ work: @escaping (Realm) throws -> T
    ) async throws -> T {
        /// Syncers run on background queues; avoid main-thread Realm writes.
        try await RealmContext.withBackgroundRealm(work)
    }

    /// Process records in batches to improve efficiency and reduce notifications
    /// - Parameter records: Array of CloudKit records to process
    private func processRecordsInBatches(_ records: [CKRecord]) async {
        let totalRecords = records.count
        if totalRecords == 0 {
            DLOG("No records to process")
            return
        }

        // Calculate batch size based on total records
        let adaptiveBatchSize = min(batchConfig.maxBatchSize, max(batchConfig.minBatchSize, totalRecords / 10))
        DLOG("Processing \(totalRecords) records in batches of size \(adaptiveBatchSize)")

        // Group records by directory for more efficient processing
        let recordsByDirectory = Dictionary(grouping: records) { record -> String in
            return record["directory"] as? String ?? "unknown"
        }

        var processedCount = 0

        // Process each directory group separately
        for (directory, directoryRecords) in recordsByDirectory {
            DLOG("Processing \(directoryRecords.count) records for directory: \(directory)")

            // Update sync info for UI
            let syncInfo: [String: Any] = [
                "fileType": directory,
                "total": directoryRecords.count,
                "completed": 0,
                "batchProcessing": true
            ]

            await MainActor.run {
                CloudSyncManager.shared.currentSyncInfo = syncInfo
            }

            // Process in batches
            for batchStart in stride(from: 0, to: directoryRecords.count, by: adaptiveBatchSize) {
                let batchEnd = min(batchStart + adaptiveBatchSize, directoryRecords.count)
                let batch = Array(directoryRecords[batchStart..<batchEnd])
                let batchRange = "\(batchStart + 1)-\(batchEnd)/\(directoryRecords.count)"

                DLOG("Processing batch \(batchRange) for \(directory)")

                // Process batch
                if batchConfig.useParallelProcessing {
                    // Process in parallel with task group
                    await processRecordBatchInParallel(batch, directory: directory)
                } else {
                    // Process sequentially
                    for record in batch {
                        await processRecord(record)
                    }
                }

                // Update processed count
                processedCount += batch.count

                // Update sync info for UI
                let updatedSyncInfo: [String: Any] = [
                    "fileType": directory,
                    "total": directoryRecords.count,
                    "completed": batchEnd,
                    "batchProcessing": true
                ]

                await MainActor.run {
                    CloudSyncManager.shared.currentSyncInfo = updatedSyncInfo
                }

                // Short delay between batches to allow UI to update
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }

        // Clear sync info when done
        await MainActor.run {
            CloudSyncManager.shared.currentSyncInfo = nil
        }
    }

    /// Process a batch of records in parallel using a task group
    /// - Parameters:
    ///   - records: The batch of records to process
    ///   - directory: The directory these records belong to
    private func processRecordBatchInParallel(_ records: [CKRecord], directory: String) async {
        // Create a task group for parallel processing
        await withTaskGroup(of: Void.self) { group in
            for record in records {
                group.addTask {
                    await self.processRecord(record)
                }
            }

            // Wait for all tasks to complete
            for await _ in group {
                // Do nothing, just wait for completion
            }
        }
    }

    /// Fetch all records from CloudKit
    /// - Returns: Array of CloudKit records
    internal func fetchAllRecords() async throws -> [CKRecord] {
        return try await runOnQueue { [self] in
            try await fetchRecordsForDirectories()
        }
    }

    /// Fetch records of the primary type (`.file`) for a specific directory from the private database.
    /// - Parameter directory: The directory name to filter records by.
    /// - Returns: An array of CKRecord objects matching the directory.
    internal func fetchAllRecords(for directory: String) async throws -> [CKRecord] {
        return try await runOnQueue { [self] in
            try await fetchAllRecords(recordType: CloudKitSyncer.RecordType.file, directory: directory)
        }
    }

    /// Fetches all records of a specific type, optionally filtered by directory, from the private database.
    /// Handles pagination automatically.
    /// - Parameter recordType: The type of records to fetch.
    /// - Parameter directory: The directory name to filter records by.
    /// - Returns: An array of CKRecord objects matching the type and directory.
    internal func fetchAllRecords(recordType: String? = nil, directory: String? = nil) async throws -> [CKRecord] {
        if let queue = workQueue {
            return try await withCheckedThrowingContinuation { continuation in
                let op = BlockOperation()
                op.addExecutionBlock { [weak self, weak op] in
                    guard let self, let op, !op.isCancelled else {
                        continuation.resume(throwing: CloudSyncError.genericError("Operation cancelled"))
                        return
                    }
                    Task {
                        do {
                            if Task.isCancelled || CloudSyncManager.shared.isPausedForEmulation {
                                throw CloudSyncError.pausedForEmulation
                            }
                            let result = try await self.fetchAllRecords(recordType: recordType, directory: directory, bypassQueue: true)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                queue.addOperation(op)
            }
        }

        return try await fetchAllRecords(recordType: recordType, directory: directory, bypassQueue: true)
    }

    /// Internal variant that assumes caller handled queueing
    private func fetchAllRecords(recordType: String? = nil, directory: String? = nil, bypassQueue: Bool) async throws -> [CKRecord] {
        // Base predicate
        let basePredicate = NSPredicate(value: true)
        let finalPredicate: NSPredicate

        // If a directory is specified, add a predicate to filter by directory
        if let directory = directory {
            let directoryPredicate = NSPredicate(format: "directory == %@", directory)
            finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, directoryPredicate])
        } else {
            finalPredicate = basePredicate
        }

        // Create the query with the final predicate
        let query = CKQuery(recordType: recordType ?? self.recordType, predicate: finalPredicate)

        // We want all fields
        #if os(tvOS)
        let desiredKeys = ["directory", "filename", "title", "md5", "system", "description", "gameID", "systemIdentifier", "fileSize", "lastModified"]
        #else
        let desiredKeys = ["directory", "filename", "title", "md5", "system", "description", "gameID", "systemIdentifier", "fileSize", "lastModified", "fileData"]
        #endif

        // Use pagination to handle large record sets
        var allRecords: [CKRecord] = []
        var currentCursor: CKQueryOperation.Cursor? = nil

        repeat {
            let (records, cursor) = try await fetchRecordBatch(query: query, cursor: currentCursor, desiredKeys: desiredKeys)
            allRecords.append(contentsOf: records)
            currentCursor = cursor

            DLOG("Fetched \(records.count) records, total: \(allRecords.count)\(cursor != nil ? ", more available" : "")")
        } while currentCursor != nil

        return allRecords
    }

    /// Fetch a batch of records
    /// - Parameters:
    ///   - query: The CloudKit query
    ///   - cursor: Optional cursor for pagination
    ///   - desiredKeys: The keys to fetch
    /// - Returns: Tuple of records and next cursor
    private func fetchRecordBatch(query: CKQuery, cursor: CKQueryOperation.Cursor?, desiredKeys: [String]) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        // Use a continuation to handle the async operation
        return try await withCheckedThrowingContinuation { continuation in
            var batchRecords: [CKRecord] = []

            // Create the appropriate operation
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }

            // Configure the operation
            operation.desiredKeys = desiredKeys
            operation.resultsLimit = 100

            // Process each record
            operation.recordFetchedBlock = { record in
                batchRecords.append(record)
            }

            // Handle completion
            operation.queryCompletionBlock = { cursor, error in
                if let error = error {
                    ELOG("Error fetching records: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (batchRecords, cursor))
                }
            }

            // Add the operation to the database
            privateDatabase.add(operation)
        }
    }

    /// Insert a file that is being downloaded
    /// - Parameter file: URL of the file
    /// - Returns: URL of the file or nil if already being uploaded
    public func insertDownloadingFile(_ file: URL) async -> URL? {
        guard await !uploadedFiles.contains(file) else {
            return nil
        }
        await pendingFilesToDownload.insert(file)
        return file
    }

    /// Insert a file that has been downloaded
    /// - Parameter file: URL of the file
    public func insertDownloadedFile(_ file: URL) async {
        await pendingFilesToDownload.remove(file)
    }

    /// Insert a file that has been uploaded
    /// - Parameter file: URL of the file
    public func insertUploadedFile(_ file: URL) async {
        await uploadedFiles.insert(file)

        // Log the upload to CloudSyncLogManager
        CloudSyncLogManager.shared.logSyncOperation(
            "Uploaded file: \(file.lastPathComponent)",
            level: .info,
            operation: .upload,
            filePath: file.path,
            provider: .cloudKit
        )
    }

    /// Delete a file from the datastore
    /// - Parameter file: URL of the file
    public func deleteFromDatastore(_ file: URL) async {
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
                await errorHandler.handle(error: error)
            }
        }
    }

    /// Notify that new cloud files are available
    public func setNewCloudFilesAvailable() async {
        if await pendingFilesToDownload.isEmpty {
            await status.set(value: .filesAlreadyMoved)
            DLOG("Set status to \(status) and removing all uploaded files in \(directories)")
            await uploadedFiles.removeAll()
        }

        // Post notification that new files are available
        DLOG("New CloudKit files available")
        notificationCenter.post(name: Notification.Name("NewCloudFilesAvailable"), object: self)
    }

    /// Prepare the next batch of files to process
    /// - Returns: Collection of URLs to process
    public func prepareNextBatchToProcess() async -> any Collection<URL> {
        let newFilesCount = await newFiles.count
        DLOG("\(directories): newFiles: (\(newFilesCount)):")
        let nextFilesToProcess = await newFiles.prefix(fileImportQueueMaxCount)

        // Remove processed files from the new files set
        for file in nextFilesToProcess {
            await newFiles.remove(file)
        }

        return nextFilesToProcess
    }

    // MARK: - Helper Methods

    /// Check if a string is a UUID
    /// - Parameter string: The string to check
    /// - Returns: True if the string is a UUID
    private func isUUID(_ string: String) -> Bool {
        let uuidPattern = #"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"#
        return string.range(of: uuidPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - CloudKit Specific Methods

    /// Static flag to track if we've already logged the initialization for this session
    private static var hasLoggedInitialization = false

    /// Initialize the CloudKit schema
    private func initializeCloudKitSchema() async {
        // Only log the first time for each session to reduce log spam
        let shouldLog = !CloudKitSyncer.hasLoggedInitialization

        if shouldLog {
            DLOG("Initializing CloudKit schema for syncer with directories: \(directories)")
            CloudKitSyncer.hasLoggedInitialization = true
        }

        let success = await CloudKitSchema.initializeSchema(in: privateDatabase)

        // Only log success/failure if we're the first to log initialization
        if shouldLog {
            if success {
                DLOG("CloudKit schema initialized successfully")
            } else {
                ELOG("Failed to initialize CloudKit schema")
            }
        }
    }

    /// Set up CloudKit subscriptions for changes
    private func setupSubscriptions() {
        for directory in directories {
            let subscriptionID = "com.provenance-emu.provenance.directory.\(directory)"
            let predicate = NSPredicate(format: "%K == %@", "directory", directory)

            // Determine the record type based on the directory
            let recordType = getRecordType()

            let subscription = CKQuerySubscription(
                recordType: recordType,
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo

            Task {
                do {
                    try await privateDatabase.save(subscription)
                    DLOG("Created CloudKit subscription for directory: \(directory)")
                } catch {
                    ELOG("Failed to create CloudKit subscription: \(error.localizedDescription)")
                    await errorHandler.handle(error: error)
                }
            }

            // Set up notification handler for remote notifications
            subscriptionToken = NotificationCenter.default.publisher(for: .CKAccountChanged)
                .sink { [weak self] _ in
                    Task {
                        await self?.handleCloudKitAccountChanged()
                    }
                }
        }
    }

    /// Handle CloudKit account changes
    private func handleCloudKitAccountChanged() async {
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
                await errorHandler.handle(error: error)
            }
        }
    }

    /// Fetch records for all directories this syncer is responsible for
    /// - Returns: Array of CKRecord objects
    private func fetchRecordsForDirectories() async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []

        for directory in directories {
            let predicate = NSPredicate(format: "directory == %@", directory)
            let query = CKQuery(recordType: recordType, predicate: predicate)

            let (results, _) = try await privateDatabase.records(matching: query)
            let records = results.compactMap { _, result in
                try? result.get()
            }

            allRecords.append(contentsOf: records)
        }

        return allRecords
    }

    /// Sync only metadata from CloudKit without downloading files
    /// This allows showing all available ROMs across devices without downloading them
    /// - Parameter recordType: The record type to sync (optional, defaults to the class's recordType)
    /// - Returns: The number of records synced
    public func syncMetadataOnly(recordType: String? = nil) async -> Int {
        // Start tracking analytics for this operation
        let typeToSync = recordType ?? self.recordType
        await CloudKitSyncAnalytics.shared.startSync(operation: "Syncing \(typeToSync) metadata")

        do {
            // Fetch all records with only the required metadata fields
            let desiredKeys = [CloudKitSyncer.FileAttributes.filename,
                               CloudKitSyncer.FileAttributes.directory,
                               CloudKitSyncer.FileAttributes.lastModified]

            let records = try await fetchAllRecords(recordType: typeToSync)

            // Update local database based on metadata
            for record in records {
                if let directory = record["directory"] as? String,
                   let filename = record["filename"] as? String {
                    // Mark the corresponding local file as synced (if it exists)
                    // This requires finding the local representation (e.g., Realm object)
                    // For now, we'll just log it
                    DLOG("Found metadata for: \(directory)/\(filename)")
                    // TODO: Update local database status if necessary
                    // Example: await updateLocalStatusFor(directory: directory, filename: filename, status: .synced)
                }
                // Check if the object exists in Realm before marking as synced
                // Consider adding a check here if needed
            }

            // Record successful metadata sync
            await CloudKitSyncAnalytics.shared.recordSuccessfulSync()

            DLOG("Synced metadata for \(records.count) \(typeToSync) records")
            return records.count
        } catch {
            ELOG("Error syncing metadata for \(typeToSync): \(error.localizedDescription)")
            // Record failed metadata sync
            await CloudKitSyncAnalytics.shared.recordFailedSync(error: error)
            await errorHandler.handle(error: error)
            return 0
        }
    }

    /// Fetch metadata records from CloudKit without downloading file assets
    /// - Parameter recordType: The record type to fetch
    /// - Returns: Array of CloudKit records
    private func fetchMetadataRecords(recordType: String? = nil) async throws -> [CKRecord] {
        // Create a query for all records of this type
        let query = CKQuery(recordType: recordType ?? self.recordType, predicate: NSPredicate(value: true))

        // We want all fields except fileData to minimize data transfer
        let desiredKeys = ["directory", "filename", "title", "md5", "system", "description", "gameID", "systemIdentifier", "fileSize", "lastModified"]

        // Use pagination to handle large record sets
        var allRecords: [CKRecord] = []
        var currentCursor: CKQueryOperation.Cursor? = nil

        repeat {
            let (records, cursor) = try await fetchMetadataRecordBatch(query: query, cursor: currentCursor, desiredKeys: desiredKeys)
            allRecords.append(contentsOf: records)
            currentCursor = cursor

            DLOG("Fetched \(records.count) metadata records, total: \(allRecords.count)\(cursor != nil ? ", more available" : "")")
        } while currentCursor != nil

        return allRecords
    }

    /// Fetch a batch of metadata records
    /// - Parameters:
    ///   - query: The CloudKit query
    ///   - cursor: Optional cursor for pagination
    ///   - desiredKeys: The keys to fetch (excluding file data)
    /// - Returns: Tuple of records and next cursor
    private func fetchMetadataRecordBatch(query: CKQuery, cursor: CKQueryOperation.Cursor?, desiredKeys: [String]) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        return try await withCheckedThrowingContinuation { continuation in
            var batchRecords: [CKRecord] = []

            // Create the appropriate operation
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }

            // Configure the operation
            operation.desiredKeys = desiredKeys
            operation.resultsLimit = 100

            // Process each record
            operation.recordFetchedBlock = { record in
                batchRecords.append(record)
            }

            // Handle completion
            operation.queryCompletionBlock = { cursor, error in
                if let error = error {
                    ELOG("Error fetching metadata records: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (batchRecords, cursor))
                }
            }

            // Add the operation to the database
            privateDatabase.add(operation)
        }
    }

    /// Process a CloudKit record
    /// - Parameter record: The CloudKit record to process
    private func processRecord(_ record: CKRecord) async {
        // Extract directory and filename with fallbacks
        let directory: String
        if let directoryValue = record["directory"] as? String {
            directory = directoryValue
        } else if record.recordType == CloudKitSyncer.RecordType.rom || record.recordType == "Game" {
            // For ROMs, use a default directory if missing
            let system = record["system"] as? String ?? "Unknown"
            directory = "roms/\(system)"
            WLOG("Missing directory for ROM record, using: \(directory)")
        } else {
            ELOG("Invalid CloudKit record: missing directory field")
            return
        }

        // Extract filename with fallbacks
        let filename: String
        if let filenameValue = record["filename"] as? String {
            filename = filenameValue
        } else if let titleValue = record["title"] as? String {
            // Use title as filename if available
            let fileExt = record.recordType == CloudKitSyncer.RecordType.rom ? ".rom" : ".dat"
            filename = titleValue.replacingOccurrences(of: " ", with: "_") + fileExt
            WLOG("Missing filename for record, using title: \(filename)")
        } else {
            // Last resort: use record ID as filename
            filename = record.recordID.recordName + ".dat"
            WLOG("Missing both filename and title, using record ID: \(filename)")
        }

        DLOG("Processing record: \(record.recordID.recordName) - Directory: \(directory), Filename: \(filename)")

        // Check if this is a metadata-only sync or a full file sync
        if let fileAsset = record["fileData"] as? CKAsset, let fileURL = fileAsset.fileURL {
            // This is a full file sync - download the file
            await downloadFile(from: fileURL, to: directory, filename: filename, record: record)
        } else {
            // This is a metadata-only sync - just create the database entry
            // For ROMs, we always want to create database entries even without file data
            await createDatabaseEntryFromRecord(record, directory: directory, filename: filename)

            if record.recordType == CloudKitSyncer.RecordType.rom || record.recordType == "Game" {
                DLOG("Created database entry for ROM: \(filename) (metadata only)")
            }
        }
    }

    /// Download a file from CloudKit
    /// - Parameters:
    ///   - fileURL: The source file URL
    ///   - directory: The destination directory
    ///   - filename: The filename
    ///   - record: The CloudKit record
    private func downloadFile(from fileURL: URL, to directory: String, filename: String, record: CKRecord) async {
        if let queue = workQueue {
            await withCheckedContinuation { continuation in
                let op = BlockOperation()
                op.addExecutionBlock { [weak self, weak op] in
                    guard let self, let op, !op.isCancelled else {
                        continuation.resume()
                        return
                    }
                    Task {
                        await self.downloadFileBody(from: fileURL, to: directory, filename: filename, record: record)
                        continuation.resume()
                    }
                }
                queue.addOperation(op)
            }
        } else {
            await downloadFileBody(from: fileURL, to: directory, filename: filename, record: record)
        }
    }

    private func downloadFileBody(from fileURL: URL, to directory: String, filename: String, record: CKRecord) async {
        // Log the download start
        CloudSyncLogManager.shared.logSyncOperation(
            "Starting download of file: \(filename) from CloudKit",
            level: .debug,
            operation: .download,
            filePath: fileURL.path,
            provider: .cloudKit
        )

        // Start analytics tracking *only* if not already tracked by downloadFileOnDemand
        // We assume downloadFileOnDemand sets its own tracking.
        // If CloudKitSyncAnalytics is already syncing, this specific download won't start a new op.
        // Note: This might need refinement if downloads can happen concurrently outside 'loadAllFromCloud'.
        let shouldStartTracking = await !CloudKitSyncAnalytics.shared.isSyncing
        if shouldStartTracking {
            await CloudKitSyncAnalytics.shared.startSync(operation: "Download: \(filename)")
        }

        let destinationDirectory = URL.documentsPath.appendingPathComponent(directory, isDirectory: true)
        let destinationURL = destinationDirectory.appendingPathComponent(filename)

        var downloadedFileSize: Int64 = 0
        var success = false
        var downloadError: Error?

        do {
            // Create directory if needed
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            // Copy file from asset to local storage
            try fileManager.copyItem(at: fileURL, to: destinationURL)

            // Get downloaded file size
            if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
               let fileSize = attributes[.size] as? Int64 {
                downloadedFileSize = fileSize
            }

            DLOG("Successfully downloaded \(filename) to \(destinationURL.path)")
            CloudSyncLogManager.shared.logSyncOperation(
                "Completed download of file: \(filename)",
                level: .info,
                operation: .download,
                filePath: destinationURL.path,
                provider: .cloudKit
            )

            // Mark file as downloaded in database (if applicable)
            await createDatabaseEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: true)

            // Send notification for UI update
            DispatchQueue.main.async {
                self.notificationCenter.post(name: iCloudDriveSync.iCloudFileDownloaded, object: self, userInfo: ["fileURL": destinationURL])
            }
            success = true
        } catch {
            ELOG("Error downloading file \(filename) from CloudKit: \(error.localizedDescription)")
            CloudSyncLogManager.shared.logSyncOperation(
                "Failed to download file: \(filename) - Error: \(error.localizedDescription)",
                level: .error,
                operation: .error,
                filePath: fileURL.path,
                provider: .cloudKit
            )
            await errorHandler.handle(error: error)
            downloadError = error
        }

        // Record analytics *only* if we started tracking in this function
        if shouldStartTracking {
            if success {
                await CloudKitSyncAnalytics.shared.recordSuccessfulSync(bytesDownloaded: downloadedFileSize)
            } else {
                await CloudKitSyncAnalytics.shared.recordFailedSync(error: downloadError ?? NSError(domain: "CloudKitSyncer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown download error"]))
            }
        }
    }

    /// Process a CloudKit record and create the appropriate database entry
    /// - Parameter record: The CloudKit record to process
    internal func processCloudKitRecord(_ record: CKRecord) async {
        // Log record information
        VLOG("Processing CloudKit record: \(record.recordID.recordName) of type: \(record.recordType)")

        // Log all available fields for debugging
        let availableFields = record.allKeys().joined(separator: ", ")
        VLOG("Available fields in record: \(availableFields)")

        // Extract the filename from the record - try multiple possible field names
        var filename: String?
        if let filenameValue = record["filename"] as? String {
            filename = filenameValue
        } else if let filenameValue = record["filename"] as? String {
            filename = filenameValue
        } else {
            let recordName = record.recordID.recordName
            // Use record name as fallback if it doesn't look like a UUID
            if !isUUID(recordName) {
                filename = recordName
                WLOG("Using record name as filename: \(recordName)")
            }
        }

        // If we still don't have a filename, log and handle the record
        if filename == nil {
            WLOG("Record missing filename: \(record.recordID.recordName)")

            // If it's a test record (UUID-like name), delete it to prevent future sync issues
            let recordName = record.recordID.recordName
            if isUUID(recordName) {
                Task {
                    do {
                        DLOG("Deleting invalid test record: \(recordName)")
                        try await privateDatabase.deleteRecord(withID: record.recordID)
                    } catch {
                        ELOG("Failed to delete invalid test record: \(error.localizedDescription)")
                    }
                }
            }

            // Try to process the record anyway if it's a BIOS record
            if record.recordType == CloudKitSyncer.RecordType.bios {
                DLOG("Attempting to process BIOS record despite missing filename")
                filename = "unknown_bios_\(record.recordID.recordName ?? UUID().uuidString)"
            } else {
                return
            }
        }

        VLOG("Processing record for file: \(filename!)")

        // Determine the directory based on record type
        let directory: String
        switch record.recordType {
        case CloudKitSyncer.RecordType.rom:
            directory = "roms"
        case CloudKitSyncer.RecordType.saveState:
            directory = "saves"
        case CloudKitSyncer.RecordType.bios:
            directory = "bios"
        case "Game": // Handle legacy record type
            directory = "roms"
            DLOG("Converting legacy 'Game' record type to 'ROM'")
        default:
            WLOG("Unknown record type: \(record.recordType) - attempting to process anyway")
            // Try to determine directory from record fields
            if let dirFromRecord = record["directory"] as? String {
                directory = dirFromRecord.lowercased()
            } else {
                directory = "unknown"
            }
        }

        // Create database entry (metadata only, not downloading the file yet)
        await createDatabaseEntryFromRecord(record, directory: directory, filename: filename!, isDownloaded: false)
    }

    /// Create a database entry from a CloudKit record
    /// - Parameters:
    ///   - record: The CloudKit record
    ///   - directory: The directory
    ///   - filename: The filename
    ///   - isDownloaded: Whether the file is downloaded locally
    private func createDatabaseEntryFromRecord(_ record: CKRecord, directory: String, filename: String, isDownloaded: Bool = false) async {
        // This method will create or update a Realm entry based on the CloudKit record
        // The implementation will depend on your Realm model structure

        // Log record details for debugging
        VLOG("Creating database entry for record: \(record.recordID.recordName) of type: \(record.recordType) in directory: \(directory)")

        switch record.recordType {
        case CloudKitSyncer.RecordType.rom, "Game": // Handle both current and legacy record types
            DLOG("Processing as ROM record")
            await createROMEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: isDownloaded)

        case CloudKitSyncer.RecordType.saveState:
            DLOG("Processing as SaveState record")
            await createSaveStateEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: isDownloaded)

        case CloudKitSyncer.RecordType.bios:
            DLOG("Processing as BIOS record")
            await createBIOSEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: isDownloaded)

        default:
            WLOG("Encountered unknown record type: \(record.recordType)")

            // Try to determine the appropriate handler based on directory
            if directory.lowercased().contains("rom") {
                DLOG("Processing unknown record type as ROM based on directory")
                await createROMEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: isDownloaded)
            } else if directory.lowercased().contains("save") || directory.lowercased().contains("state") {
                DLOG("Processing unknown record type as SaveState based on directory")
                await createSaveStateEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: isDownloaded)
            } else if directory.lowercased().contains("bios") {
                DLOG("Processing unknown record type as BIOS based on directory")
                await createBIOSEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: isDownloaded)
            } else {
                DLOG("Unable to determine record type from directory, skipping database entry creation")
            }
        }
    }

    /// Create a ROM database entry from a CloudKit record
    /// - Parameters:
    ///   - record: The CloudKit record
    ///   - directory: The directory
    ///   - filename: The filename
    ///   - isDownloaded: Whether the file is downloaded locally
    private func createROMEntryFromRecord(_ record: CKRecord, directory: String, filename: String, isDownloaded: Bool) async {
        // Extract metadata from the record with fallbacks for different field names
        // This handles potential schema differences between devices

        // Get title with fallbacks
        let title: String
        if let titleValue = record["title"] as? String {
            title = titleValue
        } else {
            title = filename.components(separatedBy: ".").first ?? filename
        }

        // Get MD5 with fallbacks
        let md5: String
        if let md5Value = record["md5"] as? String {
            md5 = md5Value
        } else if let md5Value = record["md5Hash"] as? String {
            md5 = md5Value
        } else {
            // Generate a unique identifier if MD5 is missing
            md5 = UUID().uuidString
            WLOG("Missing MD5 for ROM record, generated UUID: \(md5)")
        }

        // Get system with fallbacks
        let system: String
        if let systemValue = record["system"] as? String {
            system = systemValue
        } else if let systemValue = record["systemIdentifier"] as? String {
            system = systemValue
        } else {
            // Try to determine system from directory
            system = directory.components(separatedBy: "/").last ?? "Unknown"
            WLOG("Missing system for ROM record, using directory: \(system)")
        }

        // Get file size with fallbacks
        let fileSize: Int64
        if let sizeValue = record["fileSize"] as? Int64 {
            fileSize = sizeValue
        } else if let sizeValue = record["size"] as? Int64 {
            fileSize = sizeValue
        } else {
            fileSize = 0
            WLOG("Missing file size for ROM record")
        }

        DLOG("Processing ROM record - Title: \(title), System: \(system), MD5: \(md5), Size: \(fileSize)")

        // Log the record ID for debugging
        DLOG("Record ID: \(record.recordID.recordName)")

        // Get the system identifier from the system name
        let systemId = systemIdentifier(fromDirectory: system) ?? .Unknown
        let systemIdentifier = systemId.rawValue

        let recordHasAsset = recordHasAssetFlag(record, assetKey: CloudKitSyncer.FileAttributes.fileData)

        do {
            try await withBackgroundRealm { realm in
                try realm.write {
                    // Check if the game already exists
                    let recordID = record.recordID.recordName
                    var game: PVGame?

                    // Try to find by cloudRecordID first
                    game = realm.objects(PVGame.self).filter("cloudRecordID == %@", recordID).first

                    // If not found and we have MD5, try to find by MD5
                    if game == nil, !md5.isEmpty {
                        game = realm.objects(PVGame.self).filter("md5Hash == %@", md5).first
                    }

                    // If no existing game found, create a new one
                    if game == nil {
                        let newGame = PVGame()
                        newGame.md5Hash = md5

                        let systemDir = systemIdentifier.isEmpty ? system : systemIdentifier
                        newGame.romPath = "\(systemDir)/\(filename)"
                        newGame.cloudRecordID = record.recordID.recordName
                        newGame.isDownloaded = isDownloaded
                        newGame.hasCloudAssets = recordHasAsset

                        if let systemObj = realm.objects(PVSystem.self).filter("identifier == %@", systemIdentifier).first {
                            newGame.system = systemObj
                            newGame.systemIdentifier = systemIdentifier
                        }

                        newGame.title = title
                        newGame.fileSize = Int(fileSize)

                        realm.add(newGame)
                        DLOG("Created ROM entry for \(title)")
                    } else if let existingGame = game {
                        existingGame.title = title
                        existingGame.fileSize = Int(fileSize)
                        existingGame.cloudRecordID = recordID
                        existingGame.isDownloaded = isDownloaded
                        existingGame.hasCloudAssets = recordHasAsset

                        if existingGame.romPath.isEmpty || !existingGame.romPath.contains(systemIdentifier) {
                            let systemDir = systemIdentifier.isEmpty ? system : systemIdentifier
                            existingGame.romPath = "\(systemDir)/\(filename)"
                            DLOG("Updated ROM path: \(existingGame.romPath)")
                        }

                        DLOG("Updated ROM entry for \(title)")
                    }
                }
            }
        } catch {
            ELOG("Error creating/updating ROM entry: \(error.localizedDescription)")
        }
    }

    /// Get SystemIdentifier from directory name
    /// - Parameter directoryName: The directory name (usually the system folder name)
    /// - Returns: The SystemIdentifier or nil if not found
    private func systemIdentifier(fromDirectory directoryName: String) -> SystemIdentifier? {
        // First try to match by systemName (which is the short name like "SNES")
        if let system = SystemIdentifier.allCases.first(where: { $0.systemName.lowercased() == directoryName.lowercased() }) {
            return system
        }

        // Then try to match by the last component of the raw value (e.g., "snes" from "com.provenance.snes")
        if let system = SystemIdentifier.allCases.first(where: {
            $0.rawValue.components(separatedBy: ".").last?.lowercased() == directoryName.lowercased()
        }) {
            return system
        }

        return SystemIdentifier(rawValue: directoryName)
    }

    /// Create a SaveState database entry from a CloudKit record
    /// - Parameters:
    ///   - record: The CloudKit record
    ///   - directory: The directory
    ///   - filename: The filename
    ///   - isDownloaded: Whether the file is downloaded locally
    private func createSaveStateEntryFromRecord(_ record: CKRecord, directory: String, filename: String, isDownloaded: Bool) async {
        // Extract metadata from the record
        let description: String = record["description"] as? String ?? filename
        let recordID = record.recordID.recordName
        guard let gameID = record["gameID"] as? String,
              let fileSize = record["fileSize"] as? Int64
        else {
            ELOG("Missing metadata for save state record: \(record.recordID.recordName)")
            return
        }

        do {
            try await withBackgroundRealm { realm in
                try realm.write {
                    // Check if the save state already exists
                    var saveState: PVSaveState?

                    // Try to find by cloudRecordID first
                    saveState = realm.objects(PVSaveState.self).filter("cloudRecordID == %@", recordID).first

                // If not found and we have MD5, try to find by filename
                if saveState == nil {
                    // Look for a save state with a file that matches this filename
                    let saveStates = realm.objects(PVSaveState.self)
                    for state in saveStates {
                        if let file = state.file, (file.partialPath as NSString).lastPathComponent == filename {
                            saveState = state
                            break
                        }
                    }
                }

                    // If no existing save state found, we need a game to associate it with
                    if saveState == nil {
                        if let game = realm.object(ofType: PVGame.self, forPrimaryKey: gameID) {
                            let file = PVFile()
                            file.partialPath = filename

                        // Find a core that can handle this save state
                        if let core = realm.objects(PVCore.self).filter("supportsSystem == %@", game.systemIdentifier).first {
                            // Create a new save state
                            let newSaveState = PVSaveState()
                            newSaveState.game = game
                            newSaveState.core = core
                            newSaveState.file = file
                            newSaveState.userDescription = description
                            newSaveState.cloudRecordID = recordID
                            newSaveState.isDownloaded = isDownloaded
                            newSaveState.fileSize = Int(fileSize)

                            // Add to Realm
                            realm.add(newSaveState)
                            DLOG("Created SaveState entry for \(description)")
                        }
                        } else {
                            DLOG("Could not create SaveState entry for \(description) - no matching game found")
                        }
                    } else if let existingSaveState = saveState {
                        existingSaveState.userDescription = description
                        existingSaveState.cloudRecordID = recordID
                        existingSaveState.isDownloaded = isDownloaded
                        existingSaveState.fileSize = Int(fileSize)
                        DLOG("Updated SaveState entry for \(description)")
                    }
                }
            }
        } catch {
            ELOG("Error creating/updating SaveState entry: \(error.localizedDescription)")
        }
    }

    /// Create a BIOS database entry from a CloudKit record
    /// - Parameters:
    ///   - record: The CloudKit record
    ///   - directory: The directory
    ///   - filename: The filename
    ///   - isDownloaded: Whether the file is downloaded locally
    private func createBIOSEntryFromRecord(_ record: CKRecord, directory: String, filename: String, isDownloaded: Bool) async {
        // Extract metadata from the record
        let description = record["description"] as? String ?? filename
        let recordID = record.recordID.recordName

        // Extract system identifier - use a default if missing
        let systemIdentifier = record["system"] as? String ?? "Unknown"

        // Extract file size - use a default if missing
        let fileSize: Int64
        if let size = record["fileSize"] as? Int64 {
            fileSize = size
        } else {
            // Try to get size from the file asset
            if let asset = record["fileData"] as? CKAsset,
               let fileURL = asset.fileURL,
               let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? NSNumber {
                fileSize = size.int64Value
            } else {
                fileSize = 0
            }
        }

        // Extract MD5 - this is optional
        let md5 = record["md5"] as? String ?? ""

        do {
            try await withBackgroundRealm { realm in
                try realm.write {
                    // Check if the BIOS already exists
                    var bios: PVBIOS?

                    bios = realm.objects(PVBIOS.self).filter("cloudRecordID == %@", recordID).first

                    if bios == nil, !md5.isEmpty {
                        bios = realm.objects(PVBIOS.self).filter("expectedMD5 == %@", md5).first
                    }

                    if bios == nil {
                        bios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", filename).first
                    }

                    if bios == nil {
                        let newBios = PVBIOS()
                        newBios.expectedFilename = filename

                        if let systemObj = realm.objects(PVSystem.self).filter("identifier == %@", systemIdentifier).first {
                            newBios.system = systemObj
                        }

                        let file = PVFile()
                        file.partialPath = filename
                        newBios.file = file

                        newBios.descriptionText = description
                        if !md5.isEmpty {
                            newBios.expectedMD5 = md5.uppercased()
                        }
                        newBios.expectedSize = Int(fileSize)
                        newBios.cloudRecordID = recordID
                        newBios.isDownloaded = isDownloaded
                        newBios.fileSize = Int(fileSize)

                        realm.add(newBios)
                        DLOG("Created BIOS entry for \(description)")
                    } else if let existingBios = bios {
                        existingBios.descriptionText = description
                        if !md5.isEmpty {
                            existingBios.expectedMD5 = md5.uppercased()
                        }
                        existingBios.expectedSize = Int(fileSize)
                        existingBios.cloudRecordID = recordID
                        existingBios.isDownloaded = isDownloaded
                        existingBios.fileSize = Int(fileSize)
                        DLOG("Updated BIOS entry for \(description)")
                    }
                }
            }
        } catch {
            ELOG("Error creating/updating BIOS entry: \(error.localizedDescription)")
        }
    }

    /// Download a file on demand from CloudKit
    /// - Parameter recordName: The record name to download
    /// - Returns: The local URL of the downloaded file
    public func downloadFileOnDemand(recordName: String) async throws -> URL {
        // Start tracking analytics for this operation
        await CloudKitSyncAnalytics.shared.startSync(operation: "Downloading file")

        return try await SyncProgressTracker.shared.trackOperation(operation: "Downloading file") { progressTracker in
            // Use retry strategy for CloudKit operations
            do {
                let result = try await CloudKitRetryStrategy.retryCloudKitOperation(
                    operation: { [weak self] in
                        guard let self = self else { throw NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Syncer deallocated"]) }

                        DLOG("Requesting on-demand download for record: \(recordName)")
                        await progressTracker.updateProgress(0.1)

                        // Create a record ID from the record name
                        let recordID = CKRecord.ID(recordName: recordName)

                        // Fetch the record from CloudKit
                        Task { @MainActor in
                            progressTracker.currentOperation = "Fetching record details..."
                        }
                        let record = try await self.privateDatabase.record(for: recordID)
                        DLOG("Retrieved record of type: \(record.recordType)")

                        await progressTracker.updateProgress(0.3)

                        // Extract required fields from the record
                        guard let directory = record["directory"] as? String,
                              let filename = record["filename"] as? String,
                              let fileAsset = record["fileData"] as? CKAsset,
                              let fileURL = fileAsset.fileURL else {
                            ELOG("Record missing required fields - directory: \(record["directory"] != nil), filename: \(record["filename"] != nil), fileData: \(record["fileData"] != nil)")
                            throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "Record does not contain required file data"])
                        }

                        // Get file size for progress reporting
                        let fileSize: Int64
                        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                           let size = attributes[.size] as? Int64 {
                            fileSize = size
                            let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                            Task { @MainActor in
                                progressTracker.currentOperation = "Downloading \(filename) (\(fileSizeString))..."
                            }
                        } else {
                            fileSize = 0
                            Task { @MainActor in
                                progressTracker.currentOperation = "Downloading \(filename)..."
                            }
                        }

                        await progressTracker.updateProgress(0.4)

                        // Create destination path
                        let documentsURL = URL.documentsPath
                        let directoryURL = documentsURL.appendingPathComponent(directory)
                        var destinationURL = directoryURL.appendingPathComponent(filename)

                        // Check if we have a relative path in the record to preserve subdirectory structure
                        if let relativePath = record["relativePath"] as? String, !relativePath.isEmpty {
                            DLOG("Found relative path in record: \(relativePath)")

                            // If relativePath contains the filename at the end, use the parent directory
                            let relativePathComponents = relativePath.components(separatedBy: "/")
                            if relativePathComponents.last == filename {
                                // Create the subdirectory path
                                let subdirectoryComponents = relativePathComponents.dropLast()
                                if !subdirectoryComponents.isEmpty {
                                    let subdirectoryPath = subdirectoryComponents.joined(separator: "/")
                                    let subdirectoryURL = directoryURL.appendingPathComponent(subdirectoryPath)

                                    // Create the subdirectory
                                    do {
                                        try FileManager.default.createDirectory(at: subdirectoryURL, withIntermediateDirectories: true)
                                        destinationURL = subdirectoryURL.appendingPathComponent(filename)
                                        DLOG("Created subdirectory: \(subdirectoryURL.path)")
                                    } catch {
                                        ELOG("Error creating subdirectory: \(error.localizedDescription)")
                                    }
                                }
                            } else {
                                // Just append the relative path to the directory URL
                                let fullPath = directoryURL.appendingPathComponent(relativePath)
                                destinationURL = fullPath

                                // Create parent directory if needed
                                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            }
                        }

                        DLOG("Preparing to download file to: \(destinationURL.path)")

                        // Create directory if needed
                        if !FileManager.default.fileExists(atPath: destinationURL.deletingLastPathComponent().path) {
                            DLOG("Creating directory: \(destinationURL.deletingLastPathComponent().path)")
                            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        }

                        await progressTracker.updateProgress(0.5)

                        // Remove existing file if needed
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            DLOG("Removing existing file at: \(destinationURL.path)")
                            try await FileManager.default.removeItem(at: destinationURL)
                        }

                        await progressTracker.updateProgress(0.6)

                        // Copy file from CloudKit asset to local storage
                        DLOG("Copying file from CloudKit asset (\(fileURL.path)) to local storage (\(destinationURL.path))")
                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)

                        await progressTracker.updateProgress(0.8)

                        // Get file size for logging
                        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                        let downloadedFileSize = attributes[.size] as? Int64 ?? 0
                        let fileSizeString = ByteCountFormatter.string(fromByteCount: downloadedFileSize, countStyle: .file)
                        DLOG("Downloaded file size: \(fileSizeString)")

                        // Update database to mark file as downloaded
                        Task { @MainActor in
                            progressTracker.currentOperation = "Updating database..."
                        }
                        await progressTracker.updateProgress(0.9)
                        await self.createDatabaseEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: true)

                        DLOG("Successfully downloaded file on demand: \(filename)")
                        await progressTracker.updateProgress(1.0)

                        // Record analytics
                        await CloudKitSyncAnalytics.shared.recordSuccessfulSync(bytesDownloaded: downloadedFileSize)
                        return destinationURL
                    },
                    progressTracker: progressTracker
                )

                return result
            } catch {
                // Record analytics for failed operation
                await CloudKitSyncAnalytics.shared.recordFailedSync(error: error)
                throw error
            }
        }
    }

    /// Upload a local file to CloudKit
    /// - Parameters:
    ///   - file: The URL of the file to upload.
    ///   - gameID: Optional game identifier to associate with the record.
    ///   - systemID: Optional system identifier to associate with the record.
    /// - Returns: The saved CloudKit record.
    public func uploadFile(_ file: URL, gameID: String? = nil, systemID: SystemIdentifier? = nil) async throws -> CKRecord {
        return try await runOnQueue {
        // Respect emulation pause: do not upload while emulation is running
        if CloudSyncManager.shared.isPausedForEmulation {
            WLOG("CloudKitSyncer: Upload skipped during emulation pause for file: \(file.lastPathComponent)")
            throw CloudSyncError.genericError("Sync paused for emulation")
        }

        // Start tracking analytics for this upload
        let filename = file.lastPathComponent
        DLOG("Initiating upload for file: \(filename)")

        return try await SyncProgressTracker.shared.trackOperation(operation: "Uploading \(filename)") { progressTracker in
            // Use retry strategy for CloudKit operations
            do {
                let result = try await CloudKitRetryStrategy.retryCloudKitOperation(
                    operation: { [weak self] in
                        guard let self = self else { throw NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Syncer deallocated"]) }

                        await progressTracker.updateProgress(0.1)
                        Task { @MainActor in
                            progressTracker.currentOperation = "Preparing \(filename)..."
                        }

                        // Ensure file exists before proceeding
                        guard self.fileManager.fileExists(atPath: file.path) else {
                            WLOG("File does not exist, cannot upload: \(file.path)")
                            throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "File not found for upload"])
                        }

                        // Get file attributes
                        guard let attributes = try? self.fileManager.attributesOfItem(atPath: file.path),
                              let size = attributes[.size] as? NSNumber,
                              let modifiedDate = attributes[.modificationDate] as? Date else {
                            ELOG("Failed to get attributes for file: \(file.path)")
                            throw NSError(domain: "com.provenance-emu.provenance", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get file attributes"])
                        }

                        // Resolve the top-level sync directory (e.g., "DeltaSkins", "ROMs", "BIOS")
                        let pathComponents = file.pathComponents
                        guard let baseIndex = pathComponents.firstIndex(where: { self.directories.contains($0) }),
                              baseIndex < pathComponents.count - 1 else {
                            ELOG("Unable to resolve base sync directory for \(file.path)")
                            throw NSError(domain: "com.provenance-emu.provenance", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid sync path"])
                        }

                        let directory = pathComponents[baseIndex]
                        let relativePath = pathComponents.suffix(from: baseIndex + 1).joined(separator: "/")
                        let filename = relativePath

                        // Find existing record or create new one
                        await progressTracker.updateProgress(0.2)
                        Task { @MainActor in
                            progressTracker.currentOperation = "Checking for existing record..."
                        }
                        var record: CKRecord
                        if let existingRecord = try? await self.findRecordForFile(file) {
                            // Update existing record
                            await progressTracker.updateProgress(0.3)
                            Task { @MainActor in
                                progressTracker.currentOperation = "Updating existing record..."
                            }
                            record = existingRecord

                            // Check if local file is newer than cloud record's modification date
                            // Use a 1-second tolerance to account for date precision issues
                            if let cloudModifiedDate = record["lastModified"] as? Date {
                                let timeDifference = modifiedDate.timeIntervalSince(cloudModifiedDate)
                                if timeDifference <= 1.0 {
                                    DLOG("Local file \(filename) is not newer than cloud version (diff: \(String(format: "%.1f", timeDifference))s). Skipping upload.")
                                    return record // No need to upload
                                }
                                DLOG("Local file \(filename) is newer than cloud by \(String(format: "%.1f", timeDifference))s, will update.")
                            }
                            VLOG("Updating existing record for \(filename)")
                        } else {
                            DLOG("No existing record found for \(filename), creating new one.")
                            // Create new record with a DETERMINISTIC record ID based on directory and filename
                            // This prevents duplicate uploads of the same file
                            await progressTracker.updateProgress(0.3)
                            Task { @MainActor in
                                progressTracker.currentOperation = "Creating new record..."
                            }
                            // Use deterministic ID format: directory_filename_MD5prefix (or just directory_filename)
                            // Calculate MD5 prefix for uniqueness if file is small, otherwise just use directory_filename
                            let md5Prefix: String
                            if size.int64Value < 50_000_000, // Only calculate MD5 for files under 50MB
                               let fileData = try? Data(contentsOf: file, options: .mappedIfSafe) {
                                let hash = Insecure.MD5.hash(data: fileData)
                                md5Prefix = "_" + hash.prefix(4).map { String(format: "%02hhx", $0) }.joined().uppercased()
                            } else {
                                md5Prefix = ""
                            }
                            let recordFilename = sanitizeRecordNameComponent(filename)
                            let recordID = CKRecord.ID(recordName: "\(directory)_\(recordFilename)\(md5Prefix)")
                            record = CKRecord(recordType: self.recordType, recordID: recordID)
                            VLOG("Creating new record for \(filename) with ID: \(recordID.recordName)")
                        }

                        // Populate record fields
                        record["filename"] = filename as CKRecordValue
                        record["directory"] = directory as CKRecordValue
                        record["fileSize"] = size as CKRecordValue
                        record["lastModified"] = modifiedDate as CKRecordValue

                        // --- START: Use parameters directly ---
                        record["gameID"] = gameID as CKRecordValue?
                        record["system"] = systemID?.rawValue as CKRecordValue?

                        // Optional: Set description based on available info
                        var descriptionParts: [String] = []
                        if let filename = record["filename"] as? String { descriptionParts.append(filename) }
                        if let systemID = systemID { descriptionParts.append("for \(systemID.rawValue)") }
                        if !descriptionParts.isEmpty {
                            record["description"] = descriptionParts.joined(separator: " ") as CKRecordValue
                        }
                        // --- END: Use parameters directly ---

                        // Associate the file asset
                        let asset = CKAsset(fileURL: file)
                        record["fileData"] = asset

                        // Save the record
                        await progressTracker.updateProgress(0.4)
                        Task { @MainActor in
                            progressTracker.currentOperation = "Saving record to CloudKit..."
                        }
                        let savedRecord = try await self.privateDatabase.save(record)
                        VLOG("Successfully saved record for \(filename)")
                        await progressTracker.updateProgress(1.0)

                        // Log successful upload
                        CloudSyncLogManager.shared.logSyncOperation(
                            "Completed upload of file: \(filename)",
                            level: .info,
                            operation: .upload,
                            filePath: file.path,
                            provider: .cloudKit
                        )
                        await CloudKitSyncAnalytics.shared.recordSuccessfulSync(bytesUploaded: size.int64Value)

                        return savedRecord
                    },
                    progressTracker: progressTracker
                )

                return result
            } catch {
                // Log failed upload
                CloudSyncLogManager.shared.logSyncOperation(
                    "Failed upload of file: \(file.lastPathComponent). Error: \(error.localizedDescription)",
                    level: .error,
                    operation: .error,
                    filePath: file.path,
                    provider: .cloudKit
                )
                // Record analytics for failed operation
                await CloudKitSyncAnalytics.shared.recordFailedSync(error: error)
                throw error
            }
        }
        }
    }

    /// Calculate the relative path for a file within a directory
    /// - Parameters:
    ///   - file: The file URL
    ///   - directory: The base directory name (e.g., "Saves", "BIOS", "com.provenance.snes")
    /// - Returns: The relative path string, or nil if calculation fails
    private func calculateRelativePath(for file: URL, in directory: String) -> String? {
        // Known subdirectories that files might be stored in
        let knownSubdirectories = [
            "Battery States",
            "Save States",
            "Saves",
            "Screenshots",
            "BIOS",
            "ROMs",
            "DeltaSkins"
        ]

        let candidateRoots: [URL] = {
            var roots: [URL] = [URL.documentsPath]
            if URL.cachesPath != URL.documentsPath {
                roots.append(URL.cachesPath)
            }
            return roots
        }()

        let fileComponents = file.standardizedFileURL.pathComponents

        // First, try direct path (directory directly under root)
        for root in candidateRoots {
            let directoryURL = root.appendingPathComponent(directory)
            let directoryComponents = directoryURL.standardizedFileURL.pathComponents

            guard fileComponents.count > directoryComponents.count else {
                continue
            }

            if Array(fileComponents.prefix(directoryComponents.count)) == directoryComponents {
                let relativeComponents = fileComponents.suffix(from: directoryComponents.count)
                let relativePath = relativeComponents.joined(separator: "/")
                DLOG("Calculated relative path: \(relativePath) for file: \(file.path) in directory: \(directory) using root \(root.path)")
                return relativePath
            }
        }

        // Second, try with known subdirectories (e.g., root/Battery States/directory/file)
        for root in candidateRoots {
            for subdir in knownSubdirectories {
                let directoryURL = root.appendingPathComponent(subdir).appendingPathComponent(directory)
                let directoryComponents = directoryURL.standardizedFileURL.pathComponents

                guard fileComponents.count > directoryComponents.count else {
                    continue
                }

                if Array(fileComponents.prefix(directoryComponents.count)) == directoryComponents {
                    let relativeComponents = fileComponents.suffix(from: directoryComponents.count)
                    let relativePath = relativeComponents.joined(separator: "/")
                    DLOG("Calculated relative path: \(relativePath) for file: \(file.path) in directory: \(directory) via subdirectory \(subdir) using root \(root.path)")
                    return relativePath
                }
            }
        }

        // Third, check if the file is in a known subdirectory and calculate full relative path from there
        for root in candidateRoots {
            for subdir in knownSubdirectories {
                let subdirURL = root.appendingPathComponent(subdir)
                let subdirComponents = subdirURL.standardizedFileURL.pathComponents

                if fileComponents.count > subdirComponents.count,
                   Array(fileComponents.prefix(subdirComponents.count)) == subdirComponents {
                    // File is within this subdirectory, calculate relative path from subdirectory
                    let relativeComponents = fileComponents.suffix(from: subdirComponents.count)
                    let relativePath = relativeComponents.joined(separator: "/")
                    DLOG("Calculated relative path from subdirectory: \(relativePath) for file: \(file.path) in subdirectory \(subdir)")
                    return relativePath
                }
            }
        }

        WLOG("File path does not start with an expected directory path. File: \(file.path), Directory Component: \(directory)")

        // Fallback: if the file lives directly inside any candidate directory, just return the filename
        for root in candidateRoots {
            let directoryURL = root.appendingPathComponent(directory)
            if file.deletingLastPathComponent().standardizedFileURL == directoryURL.standardizedFileURL {
                return file.lastPathComponent
            }
        }

        return nil
    }

    /// Normalize record name components for CloudKit record IDs
    private func sanitizeRecordNameComponent(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "_")
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

        // Calculate the relative path for the file
        // This will include any subdirectories between the main directory and the filename
        var relativePath = ""

        // If there are subdirectories between the main directory and the filename
        if directoryIndex < directoryComponents.count - 2 {
            // Get all components after the main directory but before the filename
            let subdirectoryComponents = directoryComponents[(directoryIndex + 1)..<(directoryComponents.count - 1)]
            // Join them with path separators
            let subdirectoryPath = subdirectoryComponents.joined(separator: "/")
            // Combine with the filename
            relativePath = "\(subdirectoryPath)/\(file.lastPathComponent)"
        } else {
            // No subdirectories, just use the filename
            relativePath = file.lastPathComponent
        }

        let filename = relativePath
        let sanitizedFilename = sanitizeRecordNameComponent(filename)

        // Try to find record by deterministic ID first (faster than query)
        // Try both with and without MD5 prefix since older uploads may not have it
        let baseRecordName = "\(directory)_\(filename)"
        let sanitizedBaseRecordName = "\(directory)_\(sanitizedFilename)"
        let deterministicRecordNames = Array(Set([baseRecordName, sanitizedBaseRecordName]))
        for recordName in deterministicRecordNames {
            let deterministicID = CKRecord.ID(recordName: recordName)
            if let record = try? await privateDatabase.record(for: deterministicID) {
                DLOG("Found existing record by deterministic ID: \(deterministicID.recordName)")
                return record
            }
        }

        // Also try with MD5 prefix pattern (for files uploaded with the new format)
        // Calculate MD5 prefix for the file and try that ID
        let fileURL = file
        if let fileData = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
           fileData.count < 50_000_000 { // Only for files under 50MB
            let hash = Insecure.MD5.hash(data: fileData)
            let md5Prefix = "_" + hash.prefix(4).map { String(format: "%02hhx", $0) }.joined().uppercased()
            let md5RecordNames = deterministicRecordNames.map { "\($0)\(md5Prefix)" }
            for recordName in md5RecordNames {
                let md5RecordID = CKRecord.ID(recordName: recordName)
                if let record = try? await privateDatabase.record(for: md5RecordID) {
                    DLOG("Found existing record by MD5 ID: \(md5RecordID.recordName)")
                    return record
                }
            }
        }

        // Query for existing records with matching directory and filename (fallback)
        let predicate = NSPredicate(format: "directory == %@ AND filename == %@", directory, filename)

        // Search multiple record types since records may be stored as different types
        let recordTypes = [getRecordType(), "File", "BIOS"]
        for recordType in Set(recordTypes) { // Use Set to avoid duplicate queries
            let query = CKQuery(recordType: recordType, predicate: predicate)

            do {
                let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: 1)
                let records = results.compactMap { _, result in
                    try? result.get()
                }

                if let existingRecord = records.first {
                    DLOG("Found existing record by query: \(existingRecord.recordID.recordName) (type: \(recordType))")
                    return existingRecord
                }
            } catch let error as CKError where error.code == .unknownItem {
                // Record type doesn't exist yet, continue to next type
                continue
            }
        }

        return nil
    }

    /// Get the record type based on the syncer's directories
    /// - Returns: The CloudKit record type
    internal func getRecordType() -> String {
        if directories.contains("ROMs") {
            return "ROM"
        } else if directories.contains("Save States") {
            return "SaveState"
        } else if directories.contains("BIOS") {
            return "BIOS"
        } else {
            // Default record type
            return "File"
        }
    }

    /// Check if a file is a ROM file (currently based on directory being a SystemIdentifier)
    private func isROMFile(_ file: URL) -> Bool {
        // A file is considered a ROM if its parent directory name maps to a SystemIdentifier
        // AND it's not a BIOS file.
        // This assumes ROMs are stored directly under their respective system folders.
        let parentDirectoryName = file.deletingLastPathComponent().lastPathComponent
        let isSystemDirectory = SystemIdentifier(rawValue: parentDirectoryName) != nil
        return isSystemDirectory && !isBIOSFile(file)
    }

    private func isBIOSFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent.lowercased()
        return RomDatabase.biosFilenamesCache.contains(filename)
    }

    /// Get the number of records in CloudKit for this syncer
    /// - Returns: The number of records
    public func getRecordCount() async -> Int {
        do {
            // Ensure the CloudKit schema is initialized first
            await initializeCloudKitSchema()

            DLOG("Getting record count for record type: \(recordType)")

            // Now that we have properly configured the CloudKit schema with queryable fields,
            // we can use a simple predicate that will work
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

            // Use pagination to handle large record sets
            return try await countRecordsWithPagination(query: query)
        } catch {
            ELOG("Error getting record count for \(recordType): \(error.localizedDescription)")
            return 0
        }
    }

    /// Count records with pagination to handle large record sets
    /// - Parameter query: The CloudKit query to execute
    /// - Returns: The total count of records
    private func countRecordsWithPagination(query: CKQuery) async throws -> Int {
        var totalCount = 0
        var currentCursor: CKQueryOperation.Cursor? = nil

        // Continue fetching records until we've processed all pages
        repeat {
            let (count, cursor) = try await fetchRecordBatch(query: query, cursor: currentCursor)
            totalCount += count
            currentCursor = cursor

            if let cursor = cursor {
                DLOG("Fetched batch of \(count) records for \(recordType), total so far: \(totalCount), continuing with next batch")
            } else {
                DLOG("Fetched final batch of \(count) records for \(recordType), total: \(totalCount)")
            }
        } while currentCursor != nil

        return totalCount
    }

    /// Fetch a batch of records and return the count and next cursor
    /// - Parameters:
    ///   - query: The CloudKit query to execute
    ///   - cursor: The optional cursor for pagination
    /// - Returns: A tuple containing the count of records in this batch and the next cursor (if any)
    private func fetchRecordBatch(query: CKQuery, cursor: CKQueryOperation.Cursor?) async throws -> (Int, CKQueryOperation.Cursor?) {
        // Use a continuation to handle the async operation
        return try await withCheckedThrowingContinuation { continuation in
            var batchCount = 0

            // Create the appropriate operation
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }

            // Configure the operation
            operation.desiredKeys = [] // We don't need any field data, just the count
            operation.resultsLimit = 100 // Fetch in reasonable batches

            // Count each record
            operation.recordFetchedBlock = { _ in
                batchCount += 1
            }

            // Handle completion
            operation.queryCompletionBlock = { cursor, error in
                if let error = error {
                    ELOG("Error fetching records for \(self.recordType): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (batchCount, cursor))
                }
            }

            // Add the operation to the database
            privateDatabase.add(operation)
        }
    }

    private func recordHasAssetFlag(_ record: CKRecord, assetKey: String) -> Bool {
        guard record.allKeys().contains(assetKey) else {
            // Metadata-only fetches omit the asset key entirely; treat as unknown/assumed true
            return true
        }
        return (record[assetKey] as? CKAsset) != nil
    }
}
