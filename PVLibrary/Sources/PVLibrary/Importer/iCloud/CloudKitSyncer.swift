//
//  CloudKitSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
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



/// CloudKit-based sync provider for tvOS
/// Implements the SyncProvider protocol to provide a consistent interface
/// with the iCloudContainerSyncer used on iOS/macOS
public class CloudKitSyncer: SyncProvider {
    // MARK: - Properties
    
    public lazy var pendingFilesToDownload: ConcurrentSet<URL> = []
    public lazy var newFiles: ConcurrentSet<URL> = []
    public lazy var uploadedFiles: ConcurrentSet<URL> = []
    
    // File type extensions
    private let saveStateExtensions = ["sav", "state", "srm", "ss", "st"]
    // TODO: Get this extension list from somewhere
    private let biosExtensions = ["bin", "bios", "rom", "zip"]
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
    public var recordType: String {
        return getRecordType()
    }
    
    // MARK: - Initialization
    
    /// Initialize a new CloudKit syncer
    /// - Parameters:
    ///   - directories: Set of directories to sync
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(directories: Set<String>, notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        // Get the container identifier from the bundle
        let containerIdentifier = iCloudConstants.containerIdentifier
        
        // Initialize CloudKit container and database
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        self.directories = directories
        self.notificationCenter = notificationCenter
        self.errorHandler = errorHandler
        
        // Initialize CloudKit schema and set up subscriptions
        Task {
            // First initialize the schema to ensure record types exist
            await initializeCloudKitSchema()
            
            // Then set up subscriptions
            await setupSubscriptions()
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
    
    /// Load all files from CloudKit
    /// - Parameter iterationComplete: Callback when iteration is complete
    /// - Returns: Completable that completes when all files are loaded
    public func loadAllFromCloud(iterationComplete: (() async -> Void)?) async -> Completable {
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
                    await iterationComplete?()
                } catch {
                    ELOG("CloudKit sync error: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
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
    
    // MARK: - CloudKit Specific Methods
    
    /// Initialize the CloudKit schema
    private func initializeCloudKitSchema() async {
        DLOG("Initializing CloudKit schema for syncer with directories: \(directories)")
        let success = await CloudKitSchema.initializeSchema(in: privateDatabase)
        if success {
            DLOG("CloudKit schema initialized successfully")
        } else {
            ELOG("Failed to initialize CloudKit schema")
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
    /// - Returns: The number of records synced
    public func syncMetadataOnly() async -> Int {
        do {
            // Ensure the CloudKit schema is initialized first
            await initializeCloudKitSchema()
            
            DLOG("Starting metadata-only sync for record type: \(recordType)")
            
            // Fetch all records of this type
            let records = try await fetchMetadataRecords()
            
            // Process each record for metadata only
            var syncedCount = 0
            for record in records {
                // Extract directory and filename
                guard let directory = record["directory"] as? String,
                      let filename = record["filename"] as? String else {
                    continue
                }
                
                // Create database entry without downloading file
                await createDatabaseEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: false)
                syncedCount += 1
            }
            
            DLOG("Completed metadata-only sync for \(recordType): synced \(syncedCount) records")
            return syncedCount
        } catch {
            ELOG("Error during metadata-only sync for \(recordType): \(error.localizedDescription)")
            await errorHandler.handle(error: error)
            return 0
        }
    }
    
    /// Fetch metadata records from CloudKit without downloading file assets
    /// - Returns: Array of CloudKit records
    private func fetchMetadataRecords() async throws -> [CKRecord] {
        // Create a query for all records of this type
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        
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
        // Extract directory and filename
        guard let directory = record["directory"] as? String,
              let filename = record["filename"] as? String else {
            ELOG("Invalid CloudKit record: missing required fields")
            return
        }
        
        // Check if this is a metadata-only sync or a full file sync
        if let fileAsset = record["fileData"] as? CKAsset, let fileURL = fileAsset.fileURL {
            // This is a full file sync - download the file
            await downloadFile(from: fileURL, to: directory, filename: filename, record: record)
        } else {
            // This is a metadata-only sync - just create the database entry
            await createDatabaseEntryFromRecord(record, directory: directory, filename: filename)
        }
    }
    
    /// Download a file from CloudKit
    /// - Parameters:
    ///   - fileURL: The source file URL
    ///   - directory: The destination directory
    ///   - filename: The filename
    ///   - record: The CloudKit record
    private func downloadFile(from fileURL: URL, to directory: String, filename: String, record: CKRecord) async {
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
            await newFiles.insert(destinationURL)
            DLOG("Downloaded file from CloudKit: \(filename) in directory: \(directory)")
            
            // Update database entry to mark file as downloaded
            await createDatabaseEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: true)
        } catch {
            ELOG("Error downloading file from CloudKit: \(error.localizedDescription)")
            await errorHandler.handle(error: error)
        }
    }
    
    /// Create a database entry from a CloudKit record
    /// - Parameters:
    ///   - record: The CloudKit record
    ///   - directory: The directory
    ///   - filename: The filename
    ///   - isDownloaded: Whether the file is downloaded locally
    /// Process a CloudKit record and create the appropriate database entry
    /// - Parameter record: The CloudKit record to process
    private func processCloudKitRecord(_ record: CKRecord) async {
        // Extract the filename and directory from the record
        guard let filename = record[CloudKitSchema.FileAttributes.filename] as? String else {
            ELOG("Record missing filename: \(record.recordID.recordName ?? "unknown")")
            return
        }
        
        // Determine the directory based on record type
        let directory: String
        switch record.recordType {
        case CloudKitSchema.RecordType.rom:
            directory = "roms"
        case CloudKitSchema.RecordType.saveState:
            directory = "saves"
        case CloudKitSchema.RecordType.bios:
            directory = "bios"
        default:
            ELOG("Unknown record type: \(record.recordType)")
            return
        }
        
        // Create database entry (metadata only, not downloading the file yet)
        await createDatabaseEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: false)
    }
    
    private func createDatabaseEntryFromRecord(_ record: CKRecord, directory: String, filename: String, isDownloaded: Bool = false) async {
        // This method will create or update a Realm entry based on the CloudKit record
        // The implementation will depend on your Realm model structure
        
        switch record.recordType {
        case CloudKitSchema.RecordType.rom:
            await createROMEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: isDownloaded)
            
        case CloudKitSchema.RecordType.saveState:
            await createSaveStateEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: isDownloaded)
            
        case CloudKitSchema.RecordType.bios:
            await createBIOSEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: isDownloaded)
            
        default:
            DLOG("Skipping database entry creation for unsupported record type: \(record.recordType)")
        }
    }
    
    /// Create a ROM database entry from a CloudKit record
    /// - Parameters:
    ///   - record: The CloudKit record
    ///   - directory: The directory
    ///   - filename: The filename
    ///   - isDownloaded: Whether the file is downloaded locally
    private func createROMEntryFromRecord(_ record: CKRecord, directory: String, filename: String, isDownloaded: Bool) async {
        // Extract metadata from the record
        guard
            let title: String  = record[CloudKitSchema.ROMAttributes.title] as? String,
                let md5: String = record[CloudKitSchema.FileAttributes.md5] as? String,
                let system: String = record[CloudKitSchema.FileAttributes.system] as? String,
                let fileSize: Int64 = record["fileSize"] as? Int64 else {
            ELOG("Invalid CloudKit record: missing required fields")
            return
        }
        
        // Get the system identifier from the system name if available
        let systemIdentifier: String = getSystemIdentifier(fromName: system)
        
        do {
            // Get the Realm instance
            let realm: Realm = try! await Realm()
            
            // Create or update the ROM entry
            try await realm.write { [self] in
                // Check if the game already exists
                let recordID = record.recordID.recordName
                var game: PVGame?
                
                // Try to find by cloudRecordID first
                game = realm.objects(PVGame.self).filter("cloudRecordID == %@", recordID).first
                
                // If not found and we have MD5, try to find by MD5
                if game == nil, !md5.isEmpty {
                    game = realm.objects(PVGame.self).filter("md5Hash == %@", md5).first
                }
                
                // If still not found, try to find by filename
                if game == nil {
                    game = realm.objects(PVGame.self).filter("romPath CONTAINS %@", filename).first
                }
                
                // If no existing game found, create a new one
                if game == nil {
                    let newGame = PVGame()
                    // Set a valid md5Hash (required as primary key)
                    newGame.md5Hash = md5 ?? UUID().uuidString
                    newGame.romPath = "\(systemIdentifier)/\(filename)"
                    
                    // Set the system if we can find it
                    if let systemObj = realm.objects(PVSystem.self).filter("identifier == %@", systemIdentifier).first {
                        newGame.system = systemObj
                        newGame.systemIdentifier = systemIdentifier
                    }
                    
                    // Set other properties
                    newGame.title = title
                    newGame.fileSize = Int(fileSize)
                    newGame.cloudRecordID = recordID
                    newGame.isDownloaded = isDownloaded
                    
                    // Add to Realm
                    realm.add(newGame)
                    DLOG("Created ROM entry for \(title)")
                } else if let existingGame = game {
                    // Update existing game properties
                    existingGame.title = title
                    existingGame.fileSize = Int(fileSize)
                    existingGame.cloudRecordID = recordID
                    existingGame.isDownloaded = isDownloaded
                    DLOG("Updated ROM entry for \(title)")
                }
            }
        } catch {
            ELOG("Error creating/updating ROM entry: \(error.localizedDescription)")
        }
    }
    
    /// Get system identifier from system name
    /// - Parameter name: The system name
    /// - Returns: The system identifier
    private func getSystemIdentifier(fromName name: String?) -> String {
        guard let name = name?.lowercased() else { return "UNKNOWN" }
        
        // Convert common system names to SystemIdentifier values
        // This uses the proper SystemIdentifier enum from PVSystems
        let systemId: SystemIdentifier?
        
        switch name {
        case "snes", "super nintendo":
            systemId = .SNES
        case "nes", "nintendo":
            systemId = .NES
        case "genesis", "mega drive":
            systemId = .Genesis
        case "gameboy", "gb":
            systemId = .GB
        case "gameboy color", "gbc":
            systemId = .GBC
        case "gameboy advance", "gba":
            systemId = .GBA
        case "nintendo 64", "n64":
            systemId = .N64
        case "playstation", "psx":
            systemId = .PSX
        default:
            // Try to find a matching system identifier
            systemId = SystemIdentifier.allCases.first { $0.systemName.lowercased() == name }
        }
        
        // Return the raw value (which is the system identifier string)
        // or the uppercased name if no match found
        return systemId?.rawValue.components(separatedBy: ".").last ?? name.uppercased()
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
        guard let gameID = record[CloudKitSchema.FileAttributes.gameID] as? String,
              let fileSize = record["fileSize"] as? Int64
              else {
            ELOG("Missing metadata for save state record: \(record.recordID.recordName ?? "unknown")")
            return
        }
        
        do {
            // Get the Realm instance
            let realm = try! await Realm()
            
            // Create or update the SaveState entry
            try await realm.write { [self] in
                // Check if the save state already exists
                var saveState: PVSaveState?
                
                // Try to find by cloudRecordID first
                saveState = realm.objects(PVSaveState.self).filter("cloudRecordID == %@", recordID).first
                
                // If still not found, try to find by filename
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
                    // Find the game by ID
                    if let game = realm.object(ofType: PVGame.self, forPrimaryKey: gameID) {
                        // Create a new PVFile for the save state
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
                    // Update existing save state
                    existingSaveState.userDescription = description
                    existingSaveState.cloudRecordID = recordID
                    existingSaveState.isDownloaded = isDownloaded
                    existingSaveState.fileSize = Int(fileSize)
                    DLOG("Updated SaveState entry for \(description)")
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

        guard let systemIdentifier = record[CloudKitSchema.ROMAttributes.systemIdentifier] as? String,
                let fileSize = record["fileSize"] as? Int64,
              let md5 = record[CloudKitSchema.FileAttributes.md5] as? String else {
            ELOG("Missing metadata for BIOS record: \(record.recordID.recordName ?? "unknown")")
            return
        }
        
        do {
            // Get the Realm instance
            let realm = try! await Realm()
            
            // Create or update the BIOS entry
            try await realm.write { [self] in
                // Check if the BIOS already exists
                var bios: PVBIOS?
                
                // Try to find by cloudRecordID first
                bios = realm.objects(PVBIOS.self).filter("cloudRecordID == %@", recordID).first
                
                // If not found and we have MD5, try to find by MD5
                if bios == nil, !md5.isEmpty {
                    bios = realm.objects(PVBIOS.self).filter("expectedMD5 == %@", md5).first
                }
                
                // If still not found, try to find by filename
                if bios == nil {
                    bios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", filename).first
                }
                
                // If no existing BIOS found, create a new one
                if bios == nil {
                    // Create a new BIOS
                    let newBios = PVBIOS()
                    newBios.expectedFilename = filename
                    
                    // Set the system if we can find it
                    if let systemObj = realm.objects(PVSystem.self).filter("identifier == %@", systemIdentifier).first {
                        newBios.system = systemObj
                    }
                    
                    // Create a file for the BIOS
                    let file = PVFile()
                    file.partialPath = filename
                    newBios.file = file
                    
                    // Set other properties
                    newBios.descriptionText = description
                    if !md5.isEmpty {
                        newBios.expectedMD5 = md5.uppercased()
                    }
                    newBios.expectedSize = Int(fileSize)
                    newBios.cloudRecordID = recordID
                    newBios.isDownloaded = isDownloaded
                    newBios.fileSize = Int(fileSize)
                    
                    // Add to Realm
                    realm.add(newBios)
                    DLOG("Created BIOS entry for \(description)")
                } else if let existingBios = bios {
                    // Update existing BIOS
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
        } catch {
            ELOG("Error creating/updating BIOS entry: \(error.localizedDescription)")
        }
    }
    
    /// Download a file on demand from CloudKit
    /// - Parameters:
    ///   - recordName: The CloudKit record name (usually in format "directory_filename")
    ///   - completion: Completion handler called when download completes
    /// - Returns: A task that can be awaited or cancelled
    @discardableResult
    public func downloadFileOnDemand(recordName: String) async throws -> URL {
        DLOG("Requesting on-demand download for record: \(recordName)")
        
        // Create a record ID from the record name
        let recordID = CKRecord.ID(recordName: recordName)
        
        // Fetch the record from CloudKit
        let record = try await privateDatabase.record(for: recordID)
        
        // Extract required fields from the record
        guard let directory = record[CloudKitSchema.FileAttributes.directory] as? String,
              let filename = record[CloudKitSchema.FileAttributes.filename] as? String,
              let fileAsset = record[CloudKitSchema.FileAttributes.fileData] as? CKAsset,
              let fileURL = fileAsset.fileURL else {
            throw NSError(domain: "com.provenance-emu.provenance", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Record does not contain required file data"])
        }
        
        // Create destination path
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directoryURL = documentsURL.appendingPathComponent(directory)
        let destinationURL = directoryURL.appendingPathComponent(filename)
        
        do {
            // Create directory if needed
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            
            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try await FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy file from CloudKit asset to local storage
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            
            // Update database to mark file as downloaded
            await createDatabaseEntryFromRecord(record, directory: directory, filename: filename, isDownloaded: true)
            
            DLOG("Successfully downloaded file on demand: \(filename)")
            return destinationURL
        } catch {
            ELOG("Error downloading file on demand: \(error.localizedDescription)")
            throw error
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
            
            // Add metadata for on-demand downloads
            addMetadataToRecord(existingRecord, forFile: file, inDirectory: directory)
            
            let updatedRecord = try await privateDatabase.save(existingRecord)
            DLOG("Updated CloudKit record for file: \(filename) in directory: \(directory)")
            return updatedRecord
        } else {
            // Create new record with the appropriate record type
            let recordType = getRecordType()
            let recordID = CKRecord.ID(recordName: "\(directory)_\(filename)")
            let record = CKRecord(recordType: recordType, recordID: recordID)
            record["directory"] = directory
            record["filename"] = filename
            record["fileData"] = CKAsset(fileURL: file)
            record["lastModified"] = Date()
            
            // Add metadata for on-demand downloads
            addMetadataToRecord(record, forFile: file, inDirectory: directory)
            
            let savedRecord = try await privateDatabase.save(record)
            DLOG("Created CloudKit record for file: \(filename) in directory: \(directory)")
            return savedRecord
        }
    }
    
    /// Add metadata to a record for on-demand downloads
    /// - Parameters:
    ///   - record: The CloudKit record to update
    ///   - file: The local file URL
    ///   - directory: The directory containing the file
    private func addMetadataToRecord(_ record: CKRecord, forFile file: URL, inDirectory directory: String) {
        // Extract filename from URL
        let filename = file.lastPathComponent
        
        // Add metadata fields
        record["filename"] = filename as CKRecordValue
        record["directory"] = directory as CKRecordValue
        
        // Add file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let fileSize = attributes[.size] as? NSNumber {
                record["fileSize"] = fileSize
            }
        } catch {
            ELOG("Error getting file size: \(error.localizedDescription)")
        }
        
        // Determine record type and add specific metadata
        let fileExtension = file.pathExtension.lowercased()
        
        if saveStateExtensions.contains(fileExtension) {
            // Save state metadata
            record["description"] = filename as CKRecordValue
            
            // Extract game ID from the save state path if possible
            // Save states are typically stored in a directory structure like:
            // /Saves/[SystemID]/[GameID]/savestate.ext
            let pathComponents = file.pathComponents
            if pathComponents.count >= 3 {
                // The game ID is typically the directory name containing the save state
                let possibleGameID = pathComponents[pathComponents.count - 2]
                record[CloudKitSchema.FileAttributes.gameID] = possibleGameID as CKRecordValue
                DLOG("Added game ID reference: \(possibleGameID) for save state: \(filename)")
            }
        } else if biosExtensions.contains(fileExtension) {
            // BIOS metadata
            record["description"] = filename as CKRecordValue
            
            // Extract system identifier from the BIOS path
            // BIOS files are typically stored in a directory structure like:
            // /BIOS/[SystemID]/bios.bin
            let directoryName = file.deletingLastPathComponent().lastPathComponent
            
            // Try to convert to a proper system identifier
            let systemId = getSystemIdentifier(fromName: directoryName)
            record[CloudKitSchema.ROMAttributes.systemIdentifier] = systemId as CKRecordValue
            DLOG("Added system identifier: \(systemId) for BIOS: \(filename)")
        } else {
            // ROM metadata
            let title = cleanupROMTitle(filename: filename)
            record["title"] = title as CKRecordValue
            
            // Calculate MD5 hash
            if let md5 = calculateMD5(forFile: file) {
                record["md5"] = md5 as CKRecordValue
            }
            
            // Determine system from directory
            record["system"] = directory as CKRecordValue
        }
    }
    
    
    
    /// Clean up ROM title from filename
    /// - Parameter filename: The ROM filename
    /// - Returns: Cleaned up title
    /// Calculate MD5 hash for a file
    /// - Parameter file: The file URL
    /// - Returns: MD5 hash string or nil if calculation failed
    private func calculateMD5(forFile file: URL) -> String? {
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: file.path) else {
                ELOG("File does not exist at path: \(file.path)")
                return nil
            }
            
            // Determine system offset for MD5 calculation
            var offset: UInt = 0
            let directory = file.deletingLastPathComponent().lastPathComponent.lowercased()
            
            // Apply offset for SNES ROMs (they have a header in the first 16 bytes)
            if directory.contains("snes") || directory.contains("super nintendo") {
                offset = 16
            }
            
            // Calculate MD5
            if let md5 = FileManager.default.md5ForFile(at: file, fromOffset: offset), !md5.isEmpty {
                DLOG("Calculated MD5 for \(file.lastPathComponent): \(md5)")
                return md5
            } else {
                ELOG("Failed to calculate MD5 for \(file.path)")
                return nil
            }
        } catch {
            ELOG("Error calculating MD5: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func cleanupROMTitle(filename: String) -> String {
        // Remove file extension
        var title = filename
        if let dotIndex = title.lastIndex(of: ".") {
            title = String(title[..<dotIndex])
        }
        
        // Replace underscores and hyphens with spaces
        title = title.replacingOccurrences(of: "_", with: " ")
        title = title.replacingOccurrences(of: "-", with: " ")
        
        // Remove common ROM naming patterns like (U), [!], etc.
        title = title.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        title = title.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
        
        // Trim whitespace
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return title
    }
    
    /// Extract game ID from save state file
    /// - Parameter file: The save state file URL
    /// - Returns: Game ID if available
    private func extractGameID(from file: URL) -> String? {
        // This is a placeholder - implement based on your save state naming convention
        return nil
    }
    
    /// Extract system identifier from BIOS file
    /// - Parameter file: The BIOS file URL
    /// - Returns: System identifier if available
    private func extractSystemIdentifier(from file: URL) -> String? {
        // This is a placeholder - implement based on your BIOS naming convention
        return nil
    }
    
    // Implementation of SyncProvider methods is already provided above
    
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
            
            // Create the appropriate operation based on whether we have a cursor
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
}
