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
    @inline(__always)
    private func withRealm<T: Sendable>(
        _ work: @escaping (Realm) throws -> T
    ) async throws -> T {
        try await RealmContext.withRealm(work)
    }

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
            let records = try await fetchSaveStateMetadataRecords()
            DLOG("Fetched \(records.count) save state metadata records from CloudKit")
            return records
        } catch {
            ELOG("Failed to fetch save state records: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchSaveStateMetadataRecords() async throws -> [CKRecord] {
        if CloudSyncManager.shared.isPausedForEmulation {
            ILOG("[SYNC] Emulation pause active, skipping save state metadata query")
            return []
        }

        return try await runSaveStateQueue { [self] in
            var allRecords: [CKRecord] = []
            var cursor: CKQueryOperation.Cursor?
            let desiredKeys = [
                CloudKitSchema.SaveStateFields.filename,
                CloudKitSchema.SaveStateFields.systemIdentifier,
                CloudKitSchema.SaveStateFields.gameID,
                CloudKitSchema.SaveStateFields.coreIdentifier,
                CloudKitSchema.SaveStateFields.coreVersion,
                CloudKitSchema.SaveStateFields.fileSize,
                CloudKitSchema.SaveStateFields.lastUploadedDate,
                CloudKitSchema.SaveStateFields.directory,
                CloudKitSchema.SaveStateFields.imageAsset
            ]

            repeat {
                let (batch, nextCursor): ([CKRecord], CKQueryOperation.Cursor?) = try await withCheckedThrowingContinuation { continuation in
                    let operation: CKQueryOperation
                    if let cursor = cursor {
                        operation = CKQueryOperation(cursor: cursor)
                    } else {
                        let query = CKQuery(recordType: CloudKitSchema.RecordType.saveState.rawValue, predicate: NSPredicate(value: true))
                        operation = CKQueryOperation(query: query)
                    }

                    operation.desiredKeys = desiredKeys
                    operation.resultsLimit = 100

                    var batchRecords: [CKRecord] = []
                    operation.recordFetchedBlock = { record in
                        batchRecords.append(record)
                    }

                    operation.queryCompletionBlock = { cursor, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: (batchRecords, cursor))
                        }
                    }

                    self.privateDatabase.add(operation)
                }

                allRecords.append(contentsOf: batch)
                cursor = nextCursor
            } while cursor != nil

            return allRecords
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

    /// Route save-state CloudKit work through the pausable queue.
    private func runSaveStateQueue<T>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await runOnQueue(work)
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
              let url = file.url, let game = saveState.game else {
            return nil
        }

        // For CloudKit, we create a virtual path that represents the record
        let systemPath = (game.systemIdentifier as NSString)
        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String

        // Create a URL with a custom scheme to represent CloudKit records
        // This is just for internal tracking, not an actual file URL
        var components = URLComponents()
        components.scheme = "cloudkit"
        components.host = "saves"
        components.path = "/\(systemDir)/\(url.lastPathComponent)"

        return components.url
    }

    private func stableGameIdentifier(for game: PVGame) -> String {
        return game.md5Hash.uppercased()
    }

    private func resolveGame(for record: CKRecord, realm: Realm) -> PVGame? {
        if let identifier = record[CloudKitSchema.SaveStateFields.gameID] as? String {
            let normalized = identifier.uppercased()
            if let md5Match = realm.object(ofType: PVGame.self, forPrimaryKey: normalized) {
                return md5Match
            }
            if let uuidMatch = realm.objects(PVGame.self).filter("id == %@", identifier).first {
                return uuidMatch
            }
        }

        if let filename = record[CloudKitSchema.SaveStateFields.filename] as? String,
           let md5Candidate = filename.components(separatedBy: ".").first,
           !md5Candidate.isEmpty {
            let normalized = md5Candidate.uppercased()
            if let md5Match = realm.object(ofType: PVGame.self, forPrimaryKey: normalized) {
                return md5Match
            }
        }

        return nil
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
                    // Check if paused for emulation
                    if await CloudSyncManager.shared.isPausedForEmulation {
                        ILOG("CloudKitSaveStatesSyncer: Skipping uploadSaveState - paused for emulation")
                        observer(.completed)
                        return
                    }

                    // Upload the file to CloudKit
                    guard let game = saveState.game else {
                        // Game unlinked for whatever reason
                        WLOG("SaveState missing game, skipping.")
                        return
                    }
                    let systemPath = (game.systemIdentifier as NSString)
                    let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
                    let filename = saveState.file?.fileName ?? "savestate_\(saveState.id)"
                    let gameIdentifier = self.stableGameIdentifier(for: game)
                    let recordID = CloudKitSchema.RecordIDGenerator.saveStateRecordID(gameID: gameIdentifier, filename: filename)

                    // Create the record with all required fields
                    let record = CKRecord(recordType: CloudKitSchema.RecordType.saveState.rawValue, recordID: recordID)

                    // Populate CloudKit fields according to schema
                    record[CloudKitSchema.SaveStateFields.filename] = filename
                    record[CloudKitSchema.SaveStateFields.directory] = "Saves"
                    record[CloudKitSchema.SaveStateFields.systemIdentifier] = game.systemIdentifier
                    record[CloudKitSchema.SaveStateFields.gameID] = gameIdentifier
                    if let core = saveState.core {
                        record[CloudKitSchema.SaveStateFields.coreIdentifier] = core.identifier
                        let version = saveState.createdWithCoreVersion ?? core.projectVersion
                        record[CloudKitSchema.SaveStateFields.coreVersion] = version
                    } else if let version = saveState.createdWithCoreVersion {
                        record[CloudKitSchema.SaveStateFields.coreVersion] = version
                    } else {
                        WLOG("Uploading save state \(filename) without core metadata.")
                    }
                    record[CloudKitSchema.SaveStateFields.lastUploadedDate] = saveState.date
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

                    ILOG("""
                        [SYNC] ✅ SAVE STATE UPLOAD SUCCESS: \(filename)
                           RecordID: \(savedRecord.recordID.recordName), GameID: \(gameIdentifier), System: \(game.systemIdentifier)
                        """)

                    // Update local save state with CloudKit metadata
                    try await self.withRealm { realm in
                        try realm.write {
                            guard let thawed = saveState.thaw() else {
                                ELOG("Thaw of save state failed")
                                return
                            }
                            thawed.cloudRecordID = savedRecord.recordID.recordName
                            thawed.lastUploadedDate = savedRecord.modificationDate ?? Date()
                        }
                    }

                    await self.insertUploadedFile(localURL)
                    DLOG("[SYNC] Save state upload complete: \(filename)")
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
                    guard let game = saveState.game else {
                        WLOG("saveState.game == nil, skipping.")
                        return
                    }
                    // Find the record for this save state
                    let filename = saveState.file?.fileName ?? "savestate_\(saveState.id)"
                    let gameIdentifier = self.stableGameIdentifier(for: game)
                    let recordID: CKRecord.ID
                    if let cloudRecordName = saveState.cloudRecordID {
                        recordID = CKRecord.ID(recordName: cloudRecordName)
                    } else {
                        recordID = CloudKitSchema.RecordIDGenerator.saveStateRecordID(gameID: gameIdentifier, filename: filename)
                    }
                    let privateDatabase = self.container.privateCloudDatabase

                    do {
                        let record = try await self.fetchSaveStateRecordWithProgress(recordID: recordID)

                        guard let asset = record["fileData"] as? CKAsset,
                              let fileURL = asset.fileURL else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "Save state file not found in CloudKit"])
                        }

                        // Get system directory
                        guard let systemIdentifier = record[CloudKitSchema.SaveStateFields.systemIdentifier] as? String,
                              let filename = record[CloudKitSchema.SaveStateFields.filename] as? String else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid save state record data"])
                        }
                        let systemDir = (systemIdentifier as NSString).components(separatedBy: "/").last ?? systemIdentifier

                        // Create local file path
                        let documentsURL = URL.documentsPath
                        let directoryURL = documentsURL
                            .appendingPathComponent("Saves")
                            .appendingPathComponent(systemDir)
                            .appendingPathComponent(gameIdentifier)
                        let destinationURL = directoryURL.appendingPathComponent(filename)

                        // Create directory if needed
                        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

                        // Copy file from asset to local storage
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try await FileManager.default.removeItem(at: destinationURL)
                        }

                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                        await self.insertDownloadedFile(destinationURL)

                        // Update save state's file reference and sync timestamps
                        let cloudModDate = record.modificationDate ?? Date()
                        try await self.withRealm { realm in
                            try realm.write {
                                guard let thawed = saveState.thaw() else {
                                    ELOG("Thaw of SaveState failed")
                                    return
                                }
                                let file = PVFile(withURL: destinationURL, relativeRoot: .documents)
                                thawed.file = file
                                thawed.isDownloaded = true
                                // Update lastUploadedDate to match cloud record's modification date
                                // This prevents re-downloading on subsequent syncs
                                thawed.lastUploadedDate = cloudModDate
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
                        guard let game = saveState.game else {
                            WLOG("SaveState.game == nil, skipping.")
                            return
                        }
                        // If record not found by ID, try searching by game identifier and filename
                        let systemPath = (game.systemIdentifier as NSString)
                        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
                        let filename = saveState.file?.fileName ?? "savestate_\(saveState.id)"
                        let identifierCandidates = Array(Set([gameIdentifier, game.id]))

                        // Create query
                        let predicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K IN %@ AND %K == %@",
                                                    CloudKitSchema.SaveStateFields.directory,
                                                    "Saves",
                                                    CloudKitSchema.SaveStateFields.systemIdentifier,
                                                    systemDir,
                                                    CloudKitSchema.SaveStateFields.gameID,
                                                    identifierCandidates,
                                                    CloudKitSchema.SaveStateFields.filename,
                                                    filename)
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
                        let directoryURL = documentsURL
                            .appendingPathComponent("Saves")
                            .appendingPathComponent(systemDir)
                            .appendingPathComponent(gameIdentifier)
                        let destinationURL = directoryURL.appendingPathComponent(filename)

                        // Create directory if needed
                        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

                        // Copy file from asset to local storage
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try await FileManager.default.removeItem(at: destinationURL)
                        }

                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                        await self.insertDownloadedFile(destinationURL)

                        // Update save state's file reference and sync timestamps
                        let cloudModDate = record.modificationDate ?? Date()
                        try await self.withRealm { realm in
                            try realm.write {
                                guard let thawed = saveState.thaw() else {
                                    ELOG("Save state thaw failed")
                                    return
                                }
                                let file = PVFile(withURL: destinationURL, relativeRoot: .documents)
                                thawed.file = file
                                thawed.isDownloaded = true
                                // Update lastUploadedDate to match cloud record's modification date
                                // This prevents re-downloading on subsequent syncs
                                thawed.lastUploadedDate = cloudModDate
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

    /// Fetch a save-state CloudKit record while reporting real progress to `SyncProgressTracker` when the download is being managed by `CloudKitDownloadQueue`.
    private func fetchSaveStateRecordWithProgress(recordID: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            let op = CKFetchRecordsOperation(recordIDs: [recordID])
            op.qualityOfService = .userInitiated

            let kind = SyncProgressTracker.DownloadKind.saveState(recordID: recordID.recordName)

            op.perRecordProgressBlock = { _, progress in
                Task { @MainActor in
                    guard let active = SyncProgressTracker.shared.activeDownloads.first(where: { $0.kind == kind }) else { return }
                    let bytes = Int64(Double(active.fileSize) * progress)
                    SyncProgressTracker.shared.updateDownloadProgress(kind: kind, bytesDownloaded: bytes)
                }
            }

            var fetched: CKRecord?
            op.perRecordResultBlock = { _, result in
                if case let .success(record) = result {
                    fetched = record
                }
            }

            op.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    if let record = fetched {
                        continuation.resume(returning: record)
                    } else {
                        continuation.resume(throwing: CloudSyncError.genericError("CloudKit record fetch succeeded but record was nil (\(recordID.recordName))"))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            self.container.privateCloudDatabase.add(op)
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
                    ILOG("[SYNC] Loading all save state records from CloudKit...")
                    await CloudKitSyncAnalytics.shared.startSync(operation: "Load SaveStates")

                    // Fetch all save state records
                    let records = await self.getAllRecords()
                    ILOG("[SYNC] Found \(records.count) save state records in CloudKit")

                    // Process each record
                    for record in records {
                        await self.processCloudRecord(record)
                    }

                    // Call iteration complete callback
                    await iterationComplete?()

                    await self.setNewCloudFilesAvailable()
                    DLOG("Completed loading save state records from CloudKit")
                    await CloudKitSyncAnalytics.shared.recordSuccessfulSync()
                    observer(.completed)
                } catch {
                    ELOG("Error loading save state records from CloudKit: \(error.localizedDescription)")
                    await CloudKitSyncAnalytics.shared.recordFailedSync(error: error)
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }

            return Disposables.create()
        }
    }

    /// Quickly fetches save-state metadata and updates the local Realm without downloading assets.
    /// Uses batch processing for optimal speed with large libraries.
    /// - Returns: Number of records processed.
    @discardableResult
    public func syncMetadataOnly() async -> Int {
        if let queue = workQueue {
            return await withCheckedContinuation { continuation in
                let op = BlockOperation()
                op.addExecutionBlock { [weak self, weak op] in
                    guard let self, let op, !op.isCancelled else {
                        continuation.resume(returning: 0)
                        return
                    }
                    Task {
                        let result = await self.syncMetadataOnlyBody()
                        continuation.resume(returning: result)
                    }
                }
                queue.addOperation(op)
            }
        } else {
            return await syncMetadataOnlyBody()
        }
    }

    private func syncMetadataOnlyBody() async -> Int {
        if CloudSyncManager.shared.isPausedForEmulation {
            ILOG("[SYNC] Save state metadata sync skipped (paused for emulation)")
            return 0
        }
        let startTime = Date()
        ILOG("[SYNC] Starting save state metadata-only sync...")

        do {
            let records = try await fetchSaveStateMetadataRecords()
            ILOG("[SYNC] Fetched \(records.count) save state records from CloudKit in \(String(format: "%.1f", Date().timeIntervalSince(startTime)))s")

            // Process in batches with concurrency
            let batchSize = 30
            let batches = stride(from: 0, to: records.count, by: batchSize).map {
                Array(records[$0..<Swift.min($0 + batchSize, records.count)])
            }
            var processedCount = 0
            var batchIndex = 0

            for batch in batches {
                batchIndex += 1
                if Task.isCancelled || CloudSyncManager.shared.isPausedForEmulation { break }

                // Process batch concurrently
                await withTaskGroup(of: Void.self) { group in
                    for record in batch {
                        group.addTask { [self] in
                            await self.processCloudRecord(record)
                        }
                    }
                }

                processedCount += batch.count

                // Log progress every 5 batches (150 records)
                if batchIndex % 5 == 0 {
                    ILOG("[SYNC] Save state progress: \(processedCount)/\(records.count) records processed...")
                }
            }

            let elapsed = Date().timeIntervalSince(startTime)
            let rate = elapsed > 0 ? Double(records.count) / elapsed : 0
            ILOG("[SYNC] Save state metadata sync complete in \(String(format: "%.1f", elapsed))s: \(records.count) records (\(String(format: "%.1f", rate)) records/sec)")
            return records.count
        } catch {
            ELOG("[SYNC] Save state metadata sync failed: \(error.localizedDescription)")
            return 0
        }
    }

    /// Process a CloudKit record and determine if it should be downloaded
    /// - Parameter record: The CloudKit record to process
    private func processCloudRecord(_ record: CKRecord) async {
        guard let filename = record[CloudKitSchema.SaveStateFields.filename] as? String,
              let _ = record[CloudKitSchema.SaveStateFields.systemIdentifier] as? String else {
            WLOG("[SYNC] Save state record missing required fields: \(record.recordID.recordName)")
            return
        }

        if CloudSyncManager.shared.isPausedForEmulation {
            ILOG("[SYNC] Emulation pause active, skipping save state record: \(record.recordID.recordName)")
            return
        }

        // Extract original save state ID and preferred core metadata from JSON/record
        let originalSaveStateID = extractSaveStateIDFromMetadata(record)
        let coreHint = extractCoreInfoFromMetadata(record)
        let cloudRecordID = record.recordID.recordName

        ILOG("[SYNC] Processing save state record: \(cloudRecordID), filename: \(filename), originalID: \(originalSaveStateID ?? "none")")

        do {
            // Step 1: Sync Realm work - find game and existing save state
            // Check by: 1) original ID from metadata, 2) cloudRecordID, 3) filename
            let (frozenGame, existingSaveState): (PVGame?, PVSaveState?) = try await self.withRealm { [self] realm in
                guard let realmGame = self.resolveGame(for: record, realm: realm) else {
                    WLOG("[SYNC] Game not found locally for save state record: \(cloudRecordID)")
                    return (nil, nil)
                }

                // Try to find existing save state by multiple criteria
                var existing: PVSaveState? = nil

                // First, try by original ID (most reliable)
                if let originalID = originalSaveStateID {
                    existing = realm.object(ofType: PVSaveState.self, forPrimaryKey: originalID)
                    if existing != nil {
                        ILOG("[SYNC] Found existing save state by original ID: \(originalID)")
                    }
                }

                // Second, try by cloudRecordID
                if existing == nil {
                    existing = realm.objects(PVSaveState.self)
                        .filter("cloudRecordID == %@", cloudRecordID)
                        .first
                    if existing != nil {
                        ILOG("[SYNC] Found existing save state by cloudRecordID: \(cloudRecordID)")
                    }
                }

                // Third, try by filename within the game's save states
                if existing == nil {
                    existing = realmGame.saveStates.first(where: { $0.file?.fileName == filename })
                    if existing != nil {
                        ILOG("[SYNC] Found existing save state by filename: \(filename)")
                    }
                }

                if existing == nil {
                    ILOG("[SYNC] No existing save state found, will create new one")
                }

                return (realmGame.freeze(), existing?.freeze())
            }

            guard let frozenGame = frozenGame else { return }

            var targetSaveState: PVSaveState?
            var needsRomDownload = false

            // Step 2: Handle existing or create new (async work)
            if let existingSaveState = existingSaveState {
                ILOG("[SYNC] Handling existing save state: \(existingSaveState.id)")
                await self.refreshLocalDownloadState(for: existingSaveState)
                await self.handleSaveStateConflict(existingSaveState, cloudRecord: record, preferredCoreID: coreHint.coreID, preferredCoreVersion: coreHint.coreVersion)
                targetSaveState = existingSaveState
                // If the game isn't downloaded locally, flag for ROM download
                if existingSaveState.game?.isDownloaded == false {
                    needsRomDownload = true
                }

                // Ensure cloudRecordID is set if it wasn't before
                if existingSaveState.cloudRecordID == nil || existingSaveState.cloudRecordID!.isEmpty {
                    do {
                        try await self.withRealm { realm in
                            try realm.write {
                                if let thawed = existingSaveState.thaw() {
                                    thawed.cloudRecordID = cloudRecordID
                                    ILOG("[SYNC] Updated cloudRecordID for existing save state: \(existingSaveState.id)")
                                }
                            }
                        }
                    } catch {
                        WLOG("[SYNC] Failed to update cloudRecordID for save state \(existingSaveState.id): \(error.localizedDescription)")
                    }
                }
            } else if let newSaveState = await self.createSaveStateFromCloudRecord(record, game: frozenGame, originalID: originalSaveStateID, preferredCoreID: coreHint.coreID, preferredCoreVersion: coreHint.coreVersion) {
                ILOG("[SYNC] Created new save state: \(newSaveState.id)")
                await self.markSaveStateForDownload(newSaveState, cloudRecord: record)
                targetSaveState = newSaveState
                // New save states from cloud need the ROM downloaded
                needsRomDownload = true
            }

            // Step 3: Apply metadata and cache artwork
            if let targetSaveState = targetSaveState {
                await applyCoreMetadata(from: record,
                                        to: targetSaveState,
                                        preferredCoreID: coreHint.coreID,
                                        preferredCoreVersion: coreHint.coreVersion)
                if record[CloudKitSchema.SaveStateFields.imageAsset] as? CKAsset != nil {
                    await cacheSaveStateArtworkAsset(from: record, for: targetSaveState)
                }

                // Queue ROM download if required and available
                if needsRomDownload,
                   let romsSyncer = CloudSyncManager.shared.romsSyncer as? CloudKitRomsSyncer {
                    let md5 = targetSaveState.game?.md5Hash ?? ""
                    if !md5.isEmpty {
                        Task.detached {
                            do {
                                try await romsSyncer.downloadGame(md5: md5)
                                ILOG("[SYNC] Queued ROM download for save state: \(targetSaveState.id) (md5: \(md5))")
                            } catch {
                                WLOG("[SYNC] Failed to queue ROM download for md5 \(md5): \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        } catch {
            ELOG("[SYNC] Error processing save state record \(record.recordID.recordName): \(error.localizedDescription)")
        }
    }

    /// Extract the original save state ID from the metadata JSON in a CloudKit record
    private func extractSaveStateIDFromMetadata(_ record: CKRecord) -> String? {
        guard let metadataJSON = record[CloudKitSchema.SaveStateFields.metadataJSON] as? String,
              let jsonData = metadataJSON.data(using: .utf8) else {
            return nil
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let id = json["id"] as? String {
                return id
            }
        } catch {
            WLOG("[SYNC] Failed to parse metadata JSON for save state ID: \(error.localizedDescription)")
        }

        return nil
    }

    /// Extract core identifier/version hints from metadata JSON if available
    private func extractCoreInfoFromMetadata(_ record: CKRecord) -> (coreID: String?, coreVersion: String?) {
        guard let metadataJSON = record[CloudKitSchema.SaveStateFields.metadataJSON] as? String,
              let jsonData = metadataJSON.data(using: .utf8) else {
            // Fall back to record fields
            let recordCoreID = (record[CloudKitSchema.SaveStateFields.coreIdentifier] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let recordCoreVersion = (record[CloudKitSchema.SaveStateFields.coreVersion] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (recordCoreID, recordCoreVersion)
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // Try several common keys for core identifier/version
                let coreID = (json["coreIdentifier"] as? String)
                    ?? (json["coreID"] as? String)
                    ?? (json["core"] as? String)
                    ?? (json["core_id"] as? String)

                let coreVersion = (json["coreVersion"] as? String)
                    ?? (json["version"] as? String)
                    ?? (json["core_version"] as? String)

                let trimmedID = coreID?.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedVersion = coreVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (trimmedID, trimmedVersion)
            }
        } catch {
            WLOG("[SYNC] Failed to parse core info from metadata JSON: \(error.localizedDescription)")
        }

        // Fallback to record fields
        let recordCoreID = (record[CloudKitSchema.SaveStateFields.coreIdentifier] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let recordCoreVersion = (record[CloudKitSchema.SaveStateFields.coreVersion] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (recordCoreID, recordCoreVersion)
    }

    /// Handle a remote change notification for a save state record
    /// - Parameter recordID: The CloudKit record identifier
    public func handleRemoteSaveStateChange(recordID: CKRecord.ID) async throws {
        do {
            let record = try await privateDatabase.record(for: recordID)
            await processCloudRecord(record)
            await setNewCloudFilesAvailable()
        } catch let error as CKError where error.code == .unknownItem {
            await deleteLocalSaveState(recordID: recordID)
        }
    }

    /// Delete a local save state when the CloudKit record is removed
    /// - Parameter recordID: Record identifier to remove
    private func deleteLocalSaveState(recordID: CKRecord.ID) async {
        guard let identifiers = CloudKitSchema.RecordIDGenerator.extractFromSaveStateRecordID(recordID) else {
            return
        }

        do {
            try await self.withRealm { realm in
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: identifiers.gameID) else {
                    return
                }

                if let orphanedSaveState = game.saveStates.first(where: { $0.file?.fileName == identifiers.filename }) {
                    try realm.write {
                        realm.delete(orphanedSaveState)
                    }
                    ILOG("Deleted local save state \(identifiers.filename) after CloudKit removal.")
                }
            }
        } catch {
            ELOG("Failed to delete local save state for \(recordID.recordName): \(error.localizedDescription)")
        }
    }

    /// Handle conflict between local and cloud save state
    /// - Parameters:
    ///   - localSaveState: The local save state
    ///   - cloudRecord: The CloudKit record
    private func handleSaveStateConflict(_ localSaveState: PVSaveState, cloudRecord: CKRecord, preferredCoreID: String? = nil, preferredCoreVersion: String? = nil) async {
        guard let cloudModificationDate = cloudRecord.modificationDate else {
            // If we can't determine dates, prefer cloud version
            await self.markSaveStateForDownload(localSaveState, cloudRecord: cloudRecord)
            return
        }

        // If already downloaded and cloudRecordID matches, check if we're already in sync
        let cloudRecordID = cloudRecord.recordID.recordName
        let localRecordedDate = localSaveState.lastUploadedDate ?? localSaveState.date
        let localFileDate: Date? = {
            guard let fileURL = localSaveState.file?.url,
                  FileManager.default.fileExists(atPath: fileURL.path),
                  let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let mtime = attrs[.modificationDate] as? Date else {
                return nil
            }
            return mtime
        }()

        // Use the freshest local timestamp (Realm lastUploadedDate vs filesystem mtime)
        let localBaseline = max(localRecordedDate, localFileDate ?? localRecordedDate)

        if localSaveState.isDownloaded,
           localSaveState.cloudRecordID == cloudRecordID {
            // Compare with tolerance of 1s
            let timeDifference = cloudModificationDate.timeIntervalSince(localBaseline)
            if timeDifference <= 1.0 {
                DLOG("Save state already synced and up to date (diff \(String(format: "%.1f", timeDifference))s): \(localSaveState.file?.fileName ?? "unknown")")
                // Normalize lastUploadedDate to cloud mod date to prevent future drift
                try? await self.withRealm { realm in
                    if let live = realm.object(ofType: PVSaveState.self, forPrimaryKey: localSaveState.id) {
                        try realm.write {
                            live.lastUploadedDate = cloudModificationDate
                        }
                    }
                }
                return
            }
        }

        let timeDifference = cloudModificationDate.timeIntervalSince(localBaseline)

        // Use most recent version - add small tolerance for date comparison
        if timeDifference > 1.0 {
            DLOG("Cloud save state is newer by \(String(format: "%.1f", timeDifference) ) s, marking for download: \(localSaveState.file?.fileName ?? "unknown")")
            await self.markSaveStateForDownload(localSaveState, cloudRecord: cloudRecord)
            // Also apply preferred core metadata if known
            await self.applyCoreMetadata(from: cloudRecord, to: localSaveState, preferredCoreID: preferredCoreID, preferredCoreVersion: preferredCoreVersion)
        } else {
            DLOG("Local save state is newer or same (diff: \(String(format: "%.1f", timeDifference))s), keeping local: \(localSaveState.file?.fileName ?? "unknown")")
            // Local is newer, could upload to cloud if needed
        }
    }

    /// Create a new save state entry from a CloudKit record
    /// - Parameters:
    ///   - record: The CloudKit record
    ///   - game: The game this save state belongs to
    private func createSaveStateFromCloudRecord(_ record: CKRecord, game: PVGame, originalID: String? = nil, preferredCoreID: String? = nil, preferredCoreVersion: String? = nil) async -> PVSaveState? {
        guard let filename = record[CloudKitSchema.SaveStateFields.filename] as? String else {
            return nil
        }
        let stableIdentifier = stableGameIdentifier(for: game)
        let fallbackGameID = game.id
        let systemDir = (game.systemIdentifier as NSString).components(separatedBy: "/").last ?? game.systemIdentifier

        do {
            return try await self.withRealm { realm in
                // Check one more time if save state with this ID already exists
                if let originalID = originalID,
                   let existing = realm.object(ofType: PVSaveState.self, forPrimaryKey: originalID) {
                    ILOG("[SYNC] Save state with ID \(originalID) already exists, returning existing")
                    return existing.freeze()
                }

                // Create the save state
                let saveState = PVSaveState()

                // Use original ID if provided, otherwise keep the default UUID
                if let originalID = originalID {
                    saveState.id = originalID
                    ILOG("[SYNC] Creating save state with original ID: \(originalID)")
                }

                let realmGame = realm.object(ofType: PVGame.self, forPrimaryKey: stableIdentifier)
                    ?? realm.object(ofType: PVGame.self, forPrimaryKey: fallbackGameID)

                guard let localGame = realmGame else {
                    ELOG("[SYNC] CreateSaveState: Unable to resolve local game for identifier \(stableIdentifier)")
                    return nil
                }

                try realm.write {
                    saveState.game = localGame
                    saveState.cloudRecordID = record.recordID.recordName
                    saveState.isDownloaded = false
                    if let resolvedCore = self.resolveCore(from: record,
                                                          realm: realm,
                                                          fallbackSystem: localGame.system,
                                                          preferredCoreID: preferredCoreID) {
                        saveState.core = resolvedCore
                    } else if let fallbackCore = localGame.system?.cores.first {
                        saveState.core = fallbackCore
                        WLOG("CreateSaveState: Falling back to first core for \(filename)")
                    } else {
                        WLOG("CreateSaveState: No core mapping available for \(filename)")
                    }

                // Use the cloud record's modificationDate for lastUploadedDate
                // This ensures consistency with the conflict detection logic
                if let modified = record.modificationDate {
                    saveState.lastUploadedDate = modified
                    // Use the custom field for the actual save state creation date if available
                    if let creationDate = record[CloudKitSchema.SaveStateFields.lastUploadedDate] as? Date {
                        saveState.date = creationDate
                    } else {
                        saveState.date = modified
                    }
                } else if let creationDate = record[CloudKitSchema.SaveStateFields.lastUploadedDate] as? Date {
                    saveState.date = creationDate
                    saveState.lastUploadedDate = creationDate
                }
                    if let version = preferredCoreVersion,
                       !version.isEmpty {
                        saveState.createdWithCoreVersion = version
                    } else if let version = record[CloudKitSchema.SaveStateFields.coreVersion] as? String,
                              !version.isEmpty {
                        saveState.createdWithCoreVersion = version
                    } else if let projectVersion = saveState.core?.projectVersion,
                              !projectVersion.isEmpty {
                        saveState.createdWithCoreVersion = projectVersion
                    } else {
                        saveState.createdWithCoreVersion = "Unknown"
                    }

                    let documentsURL = URL.documentsPath
                    let directoryURL = documentsURL
                        .appendingPathComponent("Saves")
                        .appendingPathComponent(systemDir)
                        .appendingPathComponent(stableIdentifier)
                    let fileURL = directoryURL.appendingPathComponent(filename)

                    let file = PVFile(withURL: fileURL, relativeRoot: .documents)
                    saveState.file = file

                    realm.add(saveState)
                }

                // Freeze AFTER the write transaction completes
                DLOG("Created save state entry for download: \(filename)")
                return saveState.freeze()
            }
        } catch {
            ELOG("Error creating save state from cloud record: \(error.localizedDescription)")
            return nil
        }
    }

    private func resolveCore(from record: CKRecord, realm: Realm, fallbackSystem: PVSystem?, preferredCoreID: String? = nil) -> PVCore? {
        // Preferred core from metadata JSON takes priority
        if let preferred = preferredCoreID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !preferred.isEmpty,
           let matched = realm.object(ofType: PVCore.self, forPrimaryKey: preferred) {
            return matched
        }

        // Next, use the CloudKit record field
        if let rawIdentifier = record[CloudKitSchema.SaveStateFields.coreIdentifier] as? String {
            let coreIdentifier = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            if !coreIdentifier.isEmpty,
               let matchedCore = realm.object(ofType: PVCore.self, forPrimaryKey: coreIdentifier) {
                return matchedCore
            }
        }

        if let system = fallbackSystem,
           let preferredID = system.userPreferredCoreID,
           let preferredCore = realm.object(ofType: PVCore.self, forPrimaryKey: preferredID) {
            return preferredCore
        }

        if let systemCore = fallbackSystem?.cores.first {
            return systemCore
        }

        return nil
    }

    private func applyCoreMetadata(from record: CKRecord, to frozenSaveState: PVSaveState, preferredCoreID: String? = nil, preferredCoreVersion: String? = nil) async {
        do {
            try await RealmContext.withBackgroundRealm { realm in
                guard let liveSaveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: frozenSaveState.id) else {
                    return
                }

                let resolvedCore = self.resolveCore(from: record,
                                                    realm: realm,
                                                    fallbackSystem: liveSaveState.game?.system,
                                                    preferredCoreID: preferredCoreID)

                let incomingVersion: String? = {
                    if let version = preferredCoreVersion, !version.isEmpty { return version }
                    if let version = record[CloudKitSchema.SaveStateFields.coreVersion] as? String, !version.isEmpty { return version }
                    return nil
                }()

                try realm.write {
                    if let resolvedCore {
                        liveSaveState.core = resolvedCore
                    } else if liveSaveState.core == nil,
                              let fallbackCore = liveSaveState.game?.system?.cores.first {
                        liveSaveState.core = fallbackCore
                        WLOG("SaveState \(liveSaveState.id) missing core; assigned fallback \(fallbackCore.identifier)")
                    }

                    if let version = incomingVersion {
                        liveSaveState.createdWithCoreVersion = version
                    } else if let projectVersion = liveSaveState.core?.projectVersion,
                              !projectVersion.isEmpty {
                        liveSaveState.createdWithCoreVersion = projectVersion
                    } else if liveSaveState.createdWithCoreVersion == nil {
                        liveSaveState.createdWithCoreVersion = "Unknown"
                    }
                }
            }
        } catch {
            ELOG("Failed to update core metadata for save state \(frozenSaveState.id): \(error.localizedDescription)")
        }
    }

    /// Mark a save state for download from CloudKit
    /// - Parameters:
    ///   - saveState: The save state to download
    ///   - cloudRecord: The CloudKit record
    private func markSaveStateForDownload(_ saveState: PVSaveState, cloudRecord: CKRecord) async {
        if CloudSyncManager.shared.isPausedForEmulation {
            ILOG("[SYNC] Emulation pause active, skipping save state download queue for: \(cloudRecord.recordID.recordName)")
            return
        }

        let frozenSaveState = saveState.freeze()
        let recordID = cloudRecord.recordID.recordName
        let declaredFileSize = cloudRecord[CloudKitSchema.SaveStateFields.fileSize] as? Int64
        let systemIdentifier = (cloudRecord[CloudKitSchema.SaveStateFields.systemIdentifier] as? String) ??
            frozenSaveState.game?.systemIdentifier ??
            "Saves"
        let title = frozenSaveState.userDescription ??
            frozenSaveState.game?.title ??
            (frozenSaveState.file?.fileName ?? "Save State")

        // Short-circuit if we already have this record locally and it's fresh
        if let cloudMod = cloudRecord.modificationDate {
            do {
                let needsDownload = try await RealmContext.withBackgroundRealm { realm -> Bool in
                    guard let live = realm.object(ofType: PVSaveState.self, forPrimaryKey: frozenSaveState.id) else {
                        return true
                    }
                    let fileURL = live.file?.url
                    let exists = fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                    guard exists else { return true }

                    let mtime: Date? = {
                        guard let path = fileURL?.path,
                              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                              let d = attrs[.modificationDate] as? Date else { return nil }
                        return d
                    }()

                    let baseline = max(live.lastUploadedDate ?? live.date, mtime ?? live.date)
                    let diff = cloudMod.timeIntervalSince(baseline)
                    return diff > 1.0
                }
                if !needsDownload {
                    DLOG("[SYNC] Save state already present and up to date, skipping download queue: \(recordID)")
                    return
                }
            } catch {
                WLOG("Failed freshness check for save state \(recordID): \(error.localizedDescription)")
            }
        }

        do {
            try await self.withRealm { realm in
                guard let live = frozenSaveState.thaw() else {
                    ELOG("[SYNC] Save state thaw failed for marking download")
                    return
                }

                let applyChanges: (PVSaveState) -> Void = { target in
                    target.isDownloaded = false
                    target.cloudRecordID = recordID
                }

                if realm.isInWriteTransaction {
                    applyChanges(live)
                } else {
                    try realm.write {
                        applyChanges(live)
                    }
                }
            }
        } catch {
            ELOG("[SYNC] Failed to mark save state for download: \(error.localizedDescription)")
            return // Can't queue download if we couldn't update the record
        }

        // Avoid duplicating queued downloads
        let alreadyQueued = await MainActor.run {
            SyncProgressTracker.shared.alreadyQueued(saveStateRecordID: recordID)
        }
        guard !alreadyQueued else {
            VLOG("Save state \(recordID) already queued for download")
            return
        }

        do {
            let targetSize = declaredFileSize ?? Int64(frozenSaveState.fileSize)
            try await CloudKitDownloadQueue.shared.queueSaveStateDownload(
                recordID: recordID,
                title: title,
                fileSize: targetSize,
                systemIdentifier: systemIdentifier,
                priority: .high
            )
            ILOG("Queued save state download: \(title) [\(recordID)]")
        } catch {
            await errorHandler.handle(error: error)
        }
    }

    /// Normalize local flags for an existing save state based on filesystem state.
    /// Ensures we do not re-queue downloads when the file already exists locally.
    private func refreshLocalDownloadState(for frozenSaveState: PVSaveState) async {
        do {
            try await RealmContext.withBackgroundRealm { realm in
                guard let live = realm.object(ofType: PVSaveState.self, forPrimaryKey: frozenSaveState.id) else {
                    return
                }

                let fileURL = live.file?.url
                let exists = fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false

                try realm.write {
                    live.isDownloaded = exists

                    guard exists, let path = fileURL?.path,
                          let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                          let mtime = attrs[.modificationDate] as? Date else {
                        return
                    }

                    if let recorded = live.lastUploadedDate {
                        if mtime > recorded {
                            live.lastUploadedDate = mtime
                        }
                    } else {
                        live.lastUploadedDate = mtime
                    }
                }
            }
        } catch {
            WLOG("Failed to refresh local download state for save state \(frozenSaveState.id): \(error.localizedDescription)")
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
                    let saveStatesNeedingUpload = try await self.withRealm { realm in
                        realm.objects(PVSaveState.self)
                            .filter("cloudRecordID == nil OR lastUploadedDate == nil")
                            .map { $0.freeze() }
                    }

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
                    let saveStatesNeedingDownload = try await self.withRealm { realm in
                        realm.objects(PVSaveState.self)
                            .filter("isDownloaded == false AND cloudRecordID != nil")
                            .map { $0.freeze() }
                    }

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

    /// Decide if artwork should be refreshed based on local presence and freshness
    private func shouldRefreshArtwork(existingURL: URL?, record: CKRecord) -> Bool {
        guard let existingURL,
              FileManager.default.fileExists(atPath: existingURL.path) else {
            return true
        }
        let recordModDate = record.modificationDate
        let localModDate = (try? FileManager.default.attributesOfItem(atPath: existingURL.path)[.modificationDate] as? Date) ?? nil
        if let recordModDate,
           let localModDate,
           recordModDate <= localModDate.addingTimeInterval(0.5) {
            return false
        }
        return true
    }

    private func replaceFileAtomically(from source: URL, to destination: URL) throws {
        let tempURL = destination.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: source, to: tempURL)
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: tempURL)
    }

    /// Download and save artwork asset for a save state
    /// - Parameters:
    ///   - record: The CloudKit record containing the artwork asset
    ///   - saveState: The save state to update with artwork
    ///   - saveStateURL: The local URL of the save state file
    private func downloadSaveStateArtworkAsset(from record: CKRecord, for saveState: PVSaveState, saveStateURL: URL) async throws {
        if CloudSyncManager.shared.isPausedForEmulation {
            ILOG("[SYNC] Emulation pause active, skipping artwork download for: \(saveState.id)")
            return
        }

        // Check if there's an artwork asset to download
        guard let artworkAsset = record[CloudKitSchema.SaveStateFields.imageAsset] as? CKAsset,
              let assetFileURL = artworkAsset.fileURL else {
            DLOG("No artwork asset to download for save state: \(saveState.id)")
            return
        }

        do {
            let saveStateDirectory = saveStateURL.deletingLastPathComponent()
            let artworkFilename = saveStateURL.deletingPathExtension().appendingPathExtension("png").lastPathComponent
            let artworkURL = saveStateDirectory.appendingPathComponent(artworkFilename)

            guard shouldRefreshArtwork(existingURL: artworkURL, record: record) else {
                DLOG("Artwork up to date for save state: \(saveState.id)")
                return
            }

            try replaceFileAtomically(from: assetFileURL, to: artworkURL)

            try await self.withRealm { realm in
                try realm.write {
                    guard let thawed = saveState.thaw() else {
                        ELOG("Failed to thaw save state for artwork update")
                        return
                    }
                    let imageFile = PVImageFile(withURL: artworkURL, relativeRoot: .documents)
                    thawed.image = imageFile
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

    private func cacheSaveStateArtworkAsset(from record: CKRecord, for frozenSaveState: PVSaveState) async {
        guard let artworkAsset = record[CloudKitSchema.SaveStateFields.imageAsset] as? CKAsset,
              let assetFileURL = artworkAsset.fileURL else {
            return
        }

        if CloudSyncManager.shared.isPausedForEmulation {
            ILOG("[SYNC] Emulation pause active, skipping artwork cache for: \(record.recordID.recordName)")
            return
        }

        let filename = record[CloudKitSchema.SaveStateFields.filename] as? String

        let targetSaveState = frozenSaveState.freeze()

        let targetURL: URL? = {
            if let url = targetSaveState.file?.url {
                return url
            } else if let game = targetSaveState.game {
                let systemDir = (game.systemIdentifier as NSString).components(separatedBy: "/").last ?? game.systemIdentifier
                let identifier = stableGameIdentifier(for: game)
                let fallbackName = filename ?? "\(identifier).svs"
                return URL.documentsPath
                    .appendingPathComponent("Saves")
                    .appendingPathComponent(systemDir)
                    .appendingPathComponent(identifier)
                    .appendingPathComponent(fallbackName)
            } else {
                return nil
            }
        }()

        guard let saveStateURL = targetURL else { return }

        let saveStateDirectory = saveStateURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: saveStateDirectory, withIntermediateDirectories: true)
        } catch {
            ELOG("Failed to create save state artwork directory: \(error.localizedDescription)")
        }

        let artworkFilename = saveStateURL.deletingPathExtension().appendingPathExtension("png").lastPathComponent
        let artworkURL = saveStateDirectory.appendingPathComponent(artworkFilename)

        do {
            guard shouldRefreshArtwork(existingURL: artworkURL, record: record) else {
                DLOG("Artwork cache is current for save state \(targetSaveState.id)")
                return
            }

            try replaceFileAtomically(from: assetFileURL, to: artworkURL)

            try await self.withRealm { realm in
                try realm.write {
                    guard let liveSaveState = targetSaveState.thaw() else { return }
                    let imageFile = PVImageFile(withURL: artworkURL, relativeRoot: .documents)
                    liveSaveState.image = imageFile
                }
            }
            DLOG("Cached artwork for save state \(targetSaveState.id)")
        } catch {
            ELOG("Failed to cache save state artwork: \(error.localizedDescription)")
        }
    }

    private func resolveSaveStateReference(_ reference: ThreadSafeReference<PVSaveState>) async -> PVSaveState? {
        do {
            return try await self.withRealm { realm in
                realm.resolve(reference)
            }
        } catch {
            ELOG("Failed to resolve save state reference: \(error.localizedDescription)")
            return nil
        }
    }
}
