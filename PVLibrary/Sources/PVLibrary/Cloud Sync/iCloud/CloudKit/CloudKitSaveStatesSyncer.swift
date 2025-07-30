//
//  CloudKitSaveStatesSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import CloudKit
import RxSwift
import RealmSwift

/// Save states syncer for all OS's using CloudKit
public class CloudKitSaveStatesSyncer: CloudKitSyncer, SaveStatesSyncing {
    
    /// Initialize a new save states syncer
    /// - Parameters:
    ///   - directories: Directories to manage (defaults to ["Saves"])
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public override init(container: CKContainer,directories: Set<String> = ["Saves"], notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(container: container, directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
    }
    
    /// Get all CloudKit records for save states
    /// - Returns: Array of CKRecord objects
    public func getAllRecords() async -> [CKRecord] {
        do {
            // Create a query for all save state records
            let query = CKQuery(recordType: CloudKitSchema.RecordType.saveState.rawValue, predicate: NSPredicate(value: true))
            
            // Execute the query
            let (records, _) = try await privateDatabase.records(matching: query, resultsLimit: 100)
            
            // Convert to array of CKRecord
            let recordsArray = records.compactMap { _, result -> CKRecord? in
                switch result {
                case .success(let record):
                    return record
                case .failure(let error):
                    ELOG("Error fetching save state record: \(error.localizedDescription)")
                    return nil
                }
            }
            
            DLOG("Fetched \(recordsArray.count) save state records from CloudKit")
            return recordsArray
        } catch {
            ELOG("Failed to fetch save state records: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Check if a file is downloaded locally
    /// - Parameters:
    ///   - filename: The filename to check
    ///   - system: The system identifier
    ///   - gameID: The game ID
    /// - Returns: True if the file is downloaded locally
    public func isFileDownloaded(filename: String, inSystem system: String, gameID: String? = nil) async -> Bool {
        // Create local file path
        let documentsURL = URL.documentsPath
        var directoryURL = documentsURL.appendingPathComponent("Saves").appendingPathComponent(system)
        
        if let gameID = gameID {
            directoryURL = directoryURL.appendingPathComponent(gameID)
        }
        
        let fileURL = directoryURL.appendingPathComponent(filename)
        
        // Check if file exists
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// The CloudKit record type for save states
    override public var recordType: String {
        return "SaveState"
    }
    

    
    /// Get the local URL for a save state
    /// - Parameter saveState: The save state to get the URL for
    /// - Returns: The local URL for the save state file
    public func localURL(for saveState: PVSaveState) -> URL? {
        guard let file = saveState.file else {
            return nil
        }
        
        return file.url
    }
    
    /// Get the cloud URL for a save state
    /// - Parameter saveState: The save state to get the URL for
    /// - Returns: The cloud URL for the save state file (this is a virtual path for CloudKit)
    public func cloudURL(for saveState: PVSaveState) -> URL? {
        guard let file = saveState.file,
              let url = file.url else {
            return nil
        }
        
        // For CloudKit, we create a virtual path that represents the record
        let systemPath = (saveState.game.systemIdentifier as NSString)
        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
        
        // Create a URL with a custom scheme to represent CloudKit records
        // This is just for internal tracking, not an actual file URL
        var components = URLComponents()
        components.scheme = "cloudkit"
        components.host = "saves"
        components.path = "/\(systemDir)/\(url.lastPathComponent)"
        
        return components.url
    }
    
    /// Upload a save state to CloudKit
    /// - Parameter saveState: The save state to upload
    /// - Returns: Completable that completes when the upload is done
    public func uploadSaveState(for saveState: PVSaveState) -> Completable {
        let saveState = saveState.freeze()
        return Completable.create { [weak self] observer in
            guard let self = self,
                  let localURL = self.localURL(for: saveState) else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save state file"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Upload the file to CloudKit
                    let systemPath = (saveState.game.systemIdentifier as NSString)
                    let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
                    let filename = saveState.file?.fileName ?? "savestate_\(saveState.id)"
                    let recordID = CloudKitSchema.RecordIDGenerator.saveStateRecordID(gameID: saveState.game.id, filename: filename)
                    
                    // Create the record with all required fields
                    let record = CKRecord(recordType: CloudKitSchema.RecordType.saveState.rawValue, recordID: recordID)
                    
                    // Populate CloudKit fields according to schema
                    record[CloudKitSchema.SaveStateFields.filename] = filename
                    record[CloudKitSchema.SaveStateFields.directory] = "Saves"
                    record[CloudKitSchema.SaveStateFields.systemIdentifier] = saveState.game.systemIdentifier
                    record[CloudKitSchema.SaveStateFields.gameID] = saveState.game.id
                    record[CloudKitSchema.SaveStateFields.creationDate] = saveState.date
                    record[CloudKitSchema.SaveStateFields.fileSize] = self.getFileSize(from: localURL)
                    record[CloudKitSchema.SaveStateFields.lastModifiedDevice] = UIDevice.current.identifierForVendor?.uuidString
                    
                    // Create asset from save state file
                    let asset = CKAsset(fileURL: localURL)
                    record[CloudKitSchema.SaveStateFields.fileData] = asset
                    
                    // Prepare save state artwork asset (if exists)
                    if let imageAsset = try await self.prepareSaveStateArtworkAsset(for: saveState) {
                        record[CloudKitSchema.SaveStateFields.imageAsset] = imageAsset
                        DLOG("Added artwork asset for save state: \(filename)")
                    }
                    
                    // Prepare metadata JSON for orphaned save state re-import
                    if let metadataJSON = try await self.prepareSaveStateMetadataJSON(for: saveState) {
                        record[CloudKitSchema.SaveStateFields.metadataJSON] = metadataJSON
                        DLOG("Added metadata JSON for save state: \(filename)")
                    }
                    
                    // Save to CloudKit
                    let privateDatabase = self.container.privateCloudDatabase
                    let savedRecord = try await privateDatabase.save(record)
                    
                    // Update local save state with CloudKit metadata
                    try await MainActor.run {
                        let realm = try Realm()
                        try realm.write {
                            guard let saveState = saveState.thaw() else {
                                ELOG("Thaw of save state failed")
                                return
                            }
                            saveState.cloudRecordID = savedRecord.recordID.recordName
//                            saveState.lastUploadedDate = Date()
                        }
                    }
                    
                    await self.insertUploadedFile(localURL)
                    DLOG("Uploaded save state to CloudKit: \(filename)")
                    observer(.completed)
                } catch let error as CKError {
                    ELOG("CloudKit error uploading save state: \(error.localizedDescription) (Code: \(error.code.rawValue))")
                    
                    // Handle specific CloudKit errors
                    if error.isRecoverableCloudKitError {
                        WLOG("Save state upload failed with recoverable error, will retry automatically")
                    } else {
                        ELOG("Save state upload failed with non-recoverable CloudKit error")
                    }
                    
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                } catch {
                    ELOG("Unexpected error uploading save state to CloudKit: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    func getFileSize(from fileURL: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return (attributes[.size] as? NSNumber)?.int64Value ?? 0
        } catch {
            ELOG("Error getting file size from CKAsset \(fileURL.lastPathComponent): \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Download a save state from CloudKit
    /// - Parameter saveState: The save state to download
    /// - Returns: Completable that completes when the download is done
    public func downloadSaveState(for saveState: PVSaveState) -> Completable {
        let saveState = saveState.freeze()
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save state syncer"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Find the record for this save state
                    let filename = saveState.file?.fileName ?? "savestate_\(saveState.id)"
                    let recordID = CloudKitSchema.RecordIDGenerator.saveStateRecordID(gameID: saveState.game.id, filename: filename)
                    let privateDatabase = self.container.privateCloudDatabase
                    
                    do {
                        let record = try await privateDatabase.record(for: recordID)
                        
                        guard let asset = record["fileData"] as? CKAsset,
                              let fileURL = asset.fileURL else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "Save state file not found in CloudKit"])
                        }
                        
                        // Get system directory
                        guard let systemDir = record["system"] as? String,
                              let filename = record["filename"] as? String else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid save state record data"])
                        }
                        
                        // Create local file path
                        let documentsURL = URL.documentsPath

                        let directoryURL = documentsURL.appendingPathComponent("Saves").appendingPathComponent(systemDir)
                        let destinationURL = directoryURL.appendingPathComponent(filename)
                        
                        // Create directory if needed
                        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                        
                        // Copy file from asset to local storage
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try await FileManager.default.removeItem(at: destinationURL)
                        }
                        
                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                        await self.insertDownloadedFile(destinationURL)
                        
                        // Update save state's file reference if needed
                        if saveState.file == nil {
                            try await MainActor.run {
                                let realm = try Realm()
                                try realm.write {
                                    guard let saveState = saveState.thaw() else {
                                        ELOG("Thaw of SaveState failed")
                                        return
                                    }
                                    let file = PVFile(withURL: destinationURL, relativeRoot: .documents)
                                    saveState.file = file
                                }
                            }
                        }
                        
                        // Download artwork and metadata if available
                        do {
                            try await self.downloadSaveStateArtworkAsset(from: record, for: saveState, saveStateURL: destinationURL)
                        } catch {
                            WLOG("Failed to download artwork for save state \(saveState.id): \(error.localizedDescription)")
                            // Continue with other operations even if artwork download fails
                        }
                        
                        do {
                            try await self.downloadSaveStateMetadataJSON(from: record, saveStateURL: destinationURL)
                        } catch {
                            WLOG("Failed to download metadata JSON for save state \(saveState.id): \(error.localizedDescription)")
                            // Continue with other operations even if metadata download fails
                        }
                        
                        DLOG("Downloaded save state from CloudKit: \(filename)")
                        observer(.completed)
                    } catch {
                        // If record not found by ID, try searching by game ID and filename
                        let systemPath = (saveState.game.systemIdentifier as NSString)
                        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
                        let filename = saveState.file?.fileName ?? "savestate_\(saveState.id)"
                        
                        // Create query
                        let predicate = NSPredicate(format: "directory == %@ AND systemIdentifier == %@ AND gameID == %@ AND filename == %@", 
                                                   "Saves", systemDir, saveState.game.id, filename)
                        let query = CKQuery(recordType: CloudKitSchema.RecordType.saveState.rawValue, predicate: predicate)
                        
                        // Execute query
                        let (results, _) = try await privateDatabase.records(matching: query)
                        let records = results.compactMap { _, result in
                            try? result.get()
                        }
                        
                        guard let record = records.first,
                              let asset = record["fileData"] as? CKAsset,
                              let fileURL = asset.fileURL else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "Save state file not found in CloudKit"])
                        }
                        
                        // Create local file path
                        let documentsURL = URL.documentsPath
                        let directoryURL = documentsURL.appendingPathComponent("Saves").appendingPathComponent(systemDir)
                        let destinationURL = directoryURL.appendingPathComponent(filename)
                        
                        // Create directory if needed
                        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                        
                        // Copy file from asset to local storage
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try await FileManager.default.removeItem(at: destinationURL)
                        }
                        
                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                        await self.insertDownloadedFile(destinationURL)
                        
                        // Update save state's file reference if needed
                        if saveState.file == nil {
                            try await MainActor.run {
                                let realm = try Realm()
                                try realm.write {
                                    guard let saveState = saveState.thaw() else {
                                        ELOG("Save state thaw failed")
                                        return
                                    }
                                    let file = PVFile(withURL: destinationURL, relativeRoot: .documents)
                                    saveState.file = file
                                }
                            }
                        }
                        
                        DLOG("Downloaded save state from CloudKit: \(filename)")
                        observer(.completed)
                    }
                } catch let error as CKError {
                    ELOG("CloudKit error downloading save state: \(error.localizedDescription) (Code: \(error.code.rawValue))")
                    
                    // Handle specific CloudKit errors
                    switch error.code {
                    case .unknownItem:
                        WLOG("Save state record not found in CloudKit, may have been deleted")
                    case .networkFailure, .networkUnavailable:
                        WLOG("Network error downloading save state, will retry automatically")
                    case .requestRateLimited:
                        WLOG("Rate limited downloading save state, will retry after delay")
                    default:
                        if error.isRecoverableCloudKitError {
                            WLOG("Save state download failed with recoverable error, will retry automatically")
                        } else {
                            ELOG("Save state download failed with non-recoverable CloudKit error")
                        }
                    }
                    
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                } catch {
                    ELOG("Unexpected error downloading save state from CloudKit: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// Load all save state records from CloudKit and process them
    /// - Parameter iterationComplete: Callback when iteration is complete
    /// - Returns: Completable that completes when all records are processed
    public override func loadAllFromCloud(iterationComplete: (() async -> Void)? = nil) async -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save states syncer"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    DLOG("Loading all save state records from CloudKit")
                    
                    // Fetch all save state records
                    let records = await self.getAllRecords()
                    DLOG("Found \(records.count) save state records in CloudKit")
                    
                    // Process each record
                    for record in records {
                        await self.processCloudRecord(record)
                    }
                    
                    // Call iteration complete callback
                    await iterationComplete?()
                    
                    await self.setNewCloudFilesAvailable()
                    DLOG("Completed loading save state records from CloudKit")
                    observer(.completed)
                } catch {
                    ELOG("Error loading save state records from CloudKit: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// Process a CloudKit record and determine if it should be downloaded
    /// - Parameter record: The CloudKit record to process
    private func processCloudRecord(_ record: CKRecord) async {
        guard let filename = record[CloudKitSchema.SaveStateFields.filename] as? String,
              let gameID = record[CloudKitSchema.SaveStateFields.gameID] as? String,
              let systemIdentifier = record[CloudKitSchema.SaveStateFields.systemIdentifier] as? String else {
            WLOG("Save state record missing required fields: \(record.recordID.recordName)")
            return
        }
        
        do {
            // Check if we already have this save state locally
            let realm = try await Realm(queue: nil)
            let existingGame = realm.object(ofType: PVGame.self, forPrimaryKey: gameID)
            
            guard let game = existingGame else {
                WLOG("Game not found locally for save state: \(gameID)")
                return
            }
            
            // Check if save state already exists locally
            let existingSaveState = game.saveStates.first { saveState in
                saveState.file?.fileName == filename
            }
            
            if let existingSaveState = existingSaveState {
                // Handle conflict resolution
                await self.handleSaveStateConflict(existingSaveState, cloudRecord: record)
            } else {
                // Create new save state entry and mark for download
                await self.createSaveStateFromCloudRecord(record, game: game)
            }
        } catch {
            ELOG("Error processing save state record \(record.recordID.recordName): \(error.localizedDescription)")
        }
    }
    
    /// Handle conflict between local and cloud save state
    /// - Parameters:
    ///   - localSaveState: The local save state
    ///   - cloudRecord: The CloudKit record
    private func handleSaveStateConflict(_ localSaveState: PVSaveState, cloudRecord: CKRecord) async {
        guard let cloudModificationDate = cloudRecord.modificationDate else {
            // If we can't determine dates, prefer cloud version
            await self.markSaveStateForDownload(localSaveState, cloudRecord: cloudRecord)
            return
        }
        
        let localModificationDate = localSaveState.lastUploadedDate ?? localSaveState.date
        
        // Use most recent version
        if cloudModificationDate > localModificationDate {
            DLOG("Cloud save state is newer, marking for download: \(localSaveState.file?.fileName ?? "unknown")")
            await self.markSaveStateForDownload(localSaveState, cloudRecord: cloudRecord)
        } else {
            DLOG("Local save state is newer or same, keeping local: \(localSaveState.file?.fileName ?? "unknown")")
            // Local is newer, could upload to cloud if needed
        }
    }
    
    /// Create a new save state entry from a CloudKit record
    /// - Parameters:
    ///   - record: The CloudKit record
    ///   - game: The game this save state belongs to
    private func createSaveStateFromCloudRecord(_ record: CKRecord, game: PVGame) async {
        guard let filename = record[CloudKitSchema.SaveStateFields.filename] as? String else {
            return
        }
        
        do {
            try await MainActor.run {
                let realm = try Realm()
                try realm.write {
                    let saveState = PVSaveState()
                    saveState.game = game
                    saveState.cloudRecordID = record.recordID.recordName
                    saveState.isDownloaded = false
                    
                    if let creationDate = record[CloudKitSchema.SaveStateFields.creationDate] as? Date {
                        saveState.date = creationDate
                    }
                    
                    // Create placeholder file entry
                    let documentsURL = URL.documentsPath
                    let systemDir = (game.systemIdentifier as NSString).components(separatedBy: "/").last ?? game.systemIdentifier
                    let directoryURL = documentsURL.appendingPathComponent("Saves").appendingPathComponent(systemDir)
                    let fileURL = directoryURL.appendingPathComponent(filename)
                    
                    let file = PVFile(withURL: fileURL, relativeRoot: .documents)
                    saveState.file = file
                    
                    realm.add(saveState)
                }
            }
            
            DLOG("Created save state entry for download: \(filename)")
        } catch {
            ELOG("Error creating save state from cloud record: \(error.localizedDescription)")
        }
    }
    
    /// Mark a save state for download from CloudKit
    /// - Parameters:
    ///   - saveState: The save state to download
    ///   - cloudRecord: The CloudKit record
    private func markSaveStateForDownload(_ saveState: PVSaveState, cloudRecord: CKRecord) async {
        let saveState = saveState.freeze()
        guard let localURL = self.localURL(for: saveState) else {
            return
        }
        
        // Add to pending downloads
        if await self.insertDownloadingFile(localURL) != nil {
            try? await MainActor.run {
                let realm = try Realm()
                try realm.write {
                    guard let saveState = saveState.thaw() else {
                        ELOG("Save state thaw failed")
                        return
                    }
                    saveState.isDownloaded = false
                    saveState.cloudRecordID = cloudRecord.recordID.recordName
                }
            }
        }
    }
    
    /// Upload all local save states that haven't been uploaded yet
    /// - Returns: Completable that completes when all uploads are done
    public func uploadAllSaveStates() -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save states syncer"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    let realm = try await Realm(queue: nil)
                    let saveStatesNeedingUpload = realm.objects(PVSaveState.self).filter("cloudRecordID == nil OR lastUploadedDate == nil")
                    
                    DLOG("Found \(saveStatesNeedingUpload.count) save states needing upload")
                    
                    for saveState in saveStatesNeedingUpload {
                        // Upload each save state
                        let uploadResult = await self.uploadSaveState(for: saveState).asObservable().asSingle().asCompletable()
                        try await uploadResult.toAsync()
                    }
                    
                    DLOG("Completed uploading all save states")
                    observer(.completed)
                } catch {
                    ELOG("Error uploading save states: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// Download all save states that are marked as not downloaded
    /// - Returns: Completable that completes when all downloads are done
    public func downloadAllSaveStates() -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save states syncer"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    let realm = try await Realm(queue: nil)
                    let saveStatesNeedingDownload = realm.objects(PVSaveState.self).filter("isDownloaded == false AND cloudRecordID != nil")
                    
                    DLOG("Found \(saveStatesNeedingDownload.count) save states needing download")
                    
                    for saveState in saveStatesNeedingDownload {
                        // Download each save state
                        let downloadResult = await self.downloadSaveState(for: saveState).asObservable().asSingle().asCompletable()
                        try await downloadResult.toAsync()
                    }
                    
                    DLOG("Completed downloading all save states")
                    observer(.completed)
                } catch {
                    ELOG("Error downloading save states: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// Sync all save states (upload local, download remote)
    /// - Returns: Completable that completes when sync is done
    public func syncAllSaveStates() -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save states syncer"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    DLOG("Starting complete save states sync")
                    
                    // First load all from cloud to identify what needs to be downloaded
                    let loadResult = await self.loadAllFromCloud()
                    try await loadResult.toAsync()
                    
                    // Upload all local save states that haven't been uploaded
                    let uploadResult = await self.uploadAllSaveStates()
                    try await uploadResult.toAsync()
                    
                    // Download all save states that need downloading
                    let downloadResult = await self.downloadAllSaveStates()
                    try await downloadResult.toAsync()
                    
                    DLOG("Completed complete save states sync")
                    observer(.completed)
                } catch {
                    ELOG("Error during complete save states sync: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    // MARK: - Artwork and Metadata Helpers
    
    /// Prepare save state artwork asset for CloudKit upload
    /// - Parameter saveState: The PVSaveState with potential artwork
    /// - Returns: CKAsset for the artwork if it exists, nil otherwise
    private func prepareSaveStateArtworkAsset(for saveState: PVSaveState) async throws -> CKAsset? {
        guard let imageFile = saveState.image else {
            DLOG("No artwork image for save state: \(saveState.file?.fileName ?? "unknown")")
            return nil
        }
        
        // Get the artwork file path using PVImageFile+Artwork extension
        guard let artworkURL = imageFile.url else {
            DLOG("No cached artwork path for save state: \(saveState.file?.fileName ?? "unknown")")
            return nil
        }
        
        // Verify the artwork file exists
        guard FileManager.default.fileExists(atPath: artworkURL.path) else {
            WLOG("Save state artwork file does not exist at path: \(artworkURL.path)")
            return nil
        }
        
        do {
            // Create CKAsset from the artwork file
            let artworkAsset = CKAsset(fileURL: artworkURL)
            DLOG("Successfully prepared artwork asset for save state: \(saveState.file?.fileName ?? "unknown")")
            return artworkAsset
        } catch {
            ELOG("Failed to create CKAsset for save state artwork: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Prepare save state metadata JSON for orphaned save state re-import
    /// - Parameter saveState: The PVSaveState to create metadata for
    /// - Returns: JSON string containing SavePackage metadata, nil if creation fails
    private func prepareSaveStateMetadataJSON(for saveState: PVSaveState) async throws -> String? {
        do {
            // Create SavePackage using the Packageable protocol
            guard let savePackage = try await saveState.toPackage() else {
                WLOG("Failed to create SavePackage for save state: \(saveState.file?.fileName ?? "unknown")")
                return nil
            }
            
            // Serialize the metadata to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let jsonData = try encoder.encode(savePackage.metadata)
            let jsonString = String(data: jsonData, encoding: .utf8)
            
            DLOG("Successfully prepared metadata JSON for save state: \(saveState.file?.fileName ?? "unknown")")
            return jsonString
        } catch {
            ELOG("Failed to create metadata JSON for save state: \(error.localizedDescription)")
            // Don't throw here - metadata JSON is optional for sync
            return nil
        }
    }
    
    /// Download and save artwork asset for a save state
    /// - Parameters:
    ///   - record: The CloudKit record containing the artwork asset
    ///   - saveState: The save state to update with artwork
    ///   - saveStateURL: The local URL of the save state file
    private func downloadSaveStateArtworkAsset(from record: CKRecord, for saveState: PVSaveState, saveStateURL: URL) async throws {
        // Check if there's an artwork asset to download
        guard let artworkAsset = record[CloudKitSchema.SaveStateFields.imageAsset] as? CKAsset,
              let assetFileURL = artworkAsset.fileURL else {
            DLOG("No artwork asset to download for save state: \(saveState.id)")
            return
        }
        
        do {
            // Create artwork file path in the same directory as the save state
            let saveStateDirectory = saveStateURL.deletingLastPathComponent()
            let artworkFilename = saveStateURL.deletingPathExtension().appendingPathExtension("png").lastPathComponent
            let artworkURL = saveStateDirectory.appendingPathComponent(artworkFilename)
            
            // Remove existing artwork file if it exists
            if FileManager.default.fileExists(atPath: artworkURL.path) {
                try await FileManager.default.removeItem(at: artworkURL)
            }
            
            // Copy artwork from CloudKit asset to local storage
            try FileManager.default.copyItem(at: assetFileURL, to: artworkURL)
            
            // Update save state with artwork reference
            try await MainActor.run {
                let realm = try Realm()
                try realm.write {
                    guard let saveState = saveState.thaw() else {
                        ELOG("Failed to thaw save state for artwork update")
                        return
                    }
                    
                    // Create or update PVImageFile for the artwork
                    let imageFile = PVImageFile(withURL: artworkURL, relativeRoot: .documents)
                    saveState.image = imageFile
                }
            }
            
            DLOG("Successfully downloaded and saved artwork for save state: \(saveState.id) at: \(artworkURL.path)")
        } catch {
            ELOG("Failed to download artwork for save state \(saveState.id): \(error.localizedDescription)")
            throw CloudSyncError.fileSystemError(error)
        }
    }
    
    /// Download and save metadata JSON for orphaned save state re-import
    /// - Parameters:
    ///   - record: The CloudKit record containing the metadata JSON
    ///   - saveStateURL: The local URL of the save state file
    private func downloadSaveStateMetadataJSON(from record: CKRecord, saveStateURL: URL) async throws {
        // Check if there's metadata JSON to download
        guard let metadataJSON = record[CloudKitSchema.SaveStateFields.metadataJSON] as? String,
              !metadataJSON.isEmpty else {
            DLOG("No metadata JSON to download for save state at: \(saveStateURL.path)")
            return
        }
        
        do {
            // Create metadata file path in the same directory as the save state
            let saveStateDirectory = saveStateURL.deletingLastPathComponent()
            let metadataFilename = saveStateURL.deletingPathExtension().appendingPathExtension("json").lastPathComponent
            let metadataURL = saveStateDirectory.appendingPathComponent(metadataFilename)
            
            // Write metadata JSON to file
            try metadataJSON.write(to: metadataURL, atomically: true, encoding: .utf8)
            
            DLOG("Successfully downloaded and saved metadata JSON for save state at: \(metadataURL.path)")
        } catch {
            ELOG("Failed to download metadata JSON for save state at \(saveStateURL.path): \(error.localizedDescription)")
            throw CloudSyncError.fileSystemError(error)
        }
    }
}
