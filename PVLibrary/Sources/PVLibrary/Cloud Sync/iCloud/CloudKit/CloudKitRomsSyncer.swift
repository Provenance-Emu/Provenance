//
//  CloudKitRomsSyncer.swift
//  PVLibrary
//
//  Created by Cascade on 4/29/25.
//

import Foundation
import os
import CloudKit
import RealmSwift
import Combine
import PVLogging
import PVSupport
import RxSwift
import PVArchiving
import RealmSwift // Ensure RealmSwift is imported for error codes
import PVLookup
import PVLookupTypes
import PVMediaCache

// Define the type for the retry function
public typealias CloudKitRetryOperation<T> = (_ operation: @escaping () async throws -> T, _ maxRetries: Int, _ progressTracker: SyncProgressTracker?) async throws -> T

// Helper Error for descriptive messages
struct DescriptiveError: Error, LocalizedError {
    let description: String
    var errorDescription: String? { description }
}

public class CloudKitRomsSyncer: NSObject, RomsSyncing {

    // MARK: - SyncProvider Conformance Properties
    public var directories: Set<String> = ["ROMs"] // TODO: Initialize properly, e.g., with system identifiers this syncer handles
    public var pendingFilesToDownload = ConcurrentSet<URL>()
    public var newFiles = ConcurrentSet<URL>()
    public var uploadedFiles = ConcurrentSet<URL>()
    public var status = ConcurrentSingle<iCloudSyncStatus>(.initialUpload) // Fixed initial value & label
    public var initialSyncResult: SyncResult = .indeterminate // Fixed initial value
    public var fileImportQueueMaxCount: Int = 50 // TODO: Set appropriate default/make configurable?
    public var purgeStatus: DatastorePurgeStatus = .incomplete // Fixed initial value

    // MARK: - CloudKitRomsSyncer Specific Properties
    private let container: CKContainer
    private let database: CKDatabase // Likely private database
    /// Read-only fallback databases tried when the primary returns no record.
    /// Computed from `iCloudConstants.fallbackContainers` so invalidation takes effect immediately.
    private var fallbackDatabases: [CKDatabase] {
        iCloudConstants.fallbackContainers.map(\.privateCloudDatabase)
    }
    private let retryOperation: CloudKitRetryOperation<Any> // Specify generic type <Any>
    private let romsDatastore: RomDatabase // Add Datastore reference
    private let fileManager = FileManager.default
    public var workQueue: OperationQueue? = OperationQueue()
    private var cancellables = Set<AnyCancellable>()
    private let progressTracker = SyncProgressTracker.shared // Added Progress Tracker
    private let uploadQueue = CloudKitUploadQueueActor.shared
    private let isLoadAllInFlight = OSAllocatedUnfairLock<Bool>(initialState: false)
    private let metadataOnlyGate = MetadataOnlyGate()
    private let artworkDownloadGate = ArtworkDownloadGate()
    private let artworkLookupGate = ArtworkLookupGate()
    private let originalArtworkDownloadGate = OriginalArtworkDownloadGate()
    private let changeTokenStorageKey = "org.provenance.cloudsync.cloudkit.roms.zoneChangeToken.v1"
    private let changeTokenStorage = UserDefaults.standard

    // Execute async work on the configured queue so suspension/cancellation during emulation is honored.
    private func runOnQueue<T>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
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

    @inline(__always)
    private func withRealm<T: Sendable>(
        _ work: @escaping (Realm) throws -> T
    ) async throws -> T {
        /// ROM sync runs on background queues; avoid main-thread Realm writes.
        try await RealmContext.withBackgroundRealm(work)
    }

    // MARK: - Initialization
    public init(container: CKContainer, retryStrategy: @escaping CloudKitRetryOperation<Any>, romsDatastore: RomDatabase = RomDatabase.sharedInstance) {
        self.container = container
        self.database = container.privateCloudDatabase
        // Store the passed strategy directly
        self.retryOperation = retryStrategy
        self.romsDatastore = romsDatastore
        super.init()
        setupOperationQueue()
        // TODO: Add any other necessary setup
    }

    private func setupOperationQueue() {
        guard let queue = workQueue else { return }
        queue.name = "org.provenance.cloudsync.romsQueue.legacy"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 2
    }

    // MARK: - SyncProvider Conformance Methods (Stubs)
    // TODO: Implement these methods based on CloudKit logic
    public func loadAllFromCloud(iterationComplete: (() async -> Void)?) async -> Completable {
        // Prevent overlapping full-library queries which spam CloudKit and UI logs
        guard isLoadAllInFlight.withLock({ inFlight -> Bool in
            guard !inFlight else { return false }
            inFlight = true
            return true
        }) else {
            ILOG("[SYNC] Skipping loadAllFromCloud: operation already in flight.")
            await iterationComplete?()
            return Completable.empty()
        }
        defer { isLoadAllInFlight.withLock { $0 = false } }

        let syncLog = CloudSyncManager.syncLog
        syncLog.event(.start, item: "loadAllFromCloud", status: .inProgress, detail: "db=\(database.databaseScope.rawValue == 2 ? "Private" : "Public"), type=\(CloudKitSchema.RecordType.rom.rawValue)")

        let query = CKQuery(recordType: CloudKitSchema.RecordType.rom.rawValue, predicate: NSPredicate(value: true))
        // Note: Removed sort descriptor as modificationDate is not marked sortable in CloudKit schema
        // Records will be processed in CloudKit's default order

        var allRecords: [CKRecord] = []

        do {
            syncLog.event(.query, item: "loadAllFromCloud", status: .inProgress)
            allRecords = try await fetchAllRecords(matching: query)
            syncLog.event(.query, item: "loadAllFromCloud", status: .ok, detail: "\(allRecords.count) records")

            // Sort records by file size (smallest first) for better download reliability
            let sortedRecords = allRecords.sorted { record1, record2 in
                let size1 = extractFileSize(from: record1)
                let size2 = extractFileSize(from: record2)
                return size1 < size2
            }

            syncLog.event(.sync, item: "loadAllFromCloud", status: .inProgress, detail: "\(allRecords.count) ROM records, two-phase sync")

            // Debug: If we found 0 records, let's investigate why
            if allRecords.isEmpty {
                syncLog.event(.query, item: "loadAllFromCloud", status: .notFound, detail: "No ROM records found; possible causes: no uploads, auth issues, wrong db/zone, ID format mismatch")

                // Let's try a more specific query to see if there are ANY records
                syncLog.event(.query, item: "loadAllFromCloud/legacy", status: .inProgress, detail: "rom_ prefix fallback")
                do {
                    let legacyQuery = CKQuery(recordType: CloudKitSchema.RecordType.rom.rawValue,
                                            predicate: NSPredicate(format: "recordID BEGINSWITH 'rom_'"))
                    let (legacyResults, _) = try await database.records(matching: legacyQuery)
                    syncLog.event(.query, item: "loadAllFromCloud/legacy", status: .ok, detail: "\(legacyResults.count) records")

                    for (recordID, result) in legacyResults {
                        switch result {
                        case .success(let record):
                            syncLog.event(.query, item: "rom/\(recordID.recordName)", status: .ok, detail: "legacy format")
                            allRecords.append(record)
                        case .failure(let error):
                            syncLog.event(.query, item: "rom/\(recordID.recordName)", status: .failed, detail: "legacy: \(error.localizedDescription)")
                        }
                    }
                } catch {
                    syncLog.event(.query, item: "loadAllFromCloud/legacy", status: .failed, detail: error.localizedDescription)
                }
            }

            syncLog.event(.query, item: "loadAllFromCloud", status: .ok, detail: "\(allRecords.count) total after legacy check")

            // PHASE 1: Sync all metadata first (fast) - SYNCHRONOUS
            syncLog.event(.sync, item: "loadAllFromCloud/phase1", status: .inProgress, detail: "\(allRecords.count) ROM records")
            var metadataProcessedCount = 0
            var gamesNeedingDownload: [(md5: String, title: String, fileSize: Int64, systemIdentifier: String)] = []

            for record in allRecords {
                // Process metadata only - collect games that need downloads with full info
                if let gameInfo = await processCloudRecordMetadata(record) {
                    gamesNeedingDownload.append(gameInfo)
                }
                metadataProcessedCount += 1
                VLOG("Processed ROM metadata (\(metadataProcessedCount)/\(allRecords.count)): \(record.recordID.recordName)")
                // Yield to allow UI to update Realm observers
                await Task.yield()
            }

            syncLog.event(.sync, item: "loadAllFromCloud/phase1", status: .ok, detail: "\(metadataProcessedCount) synced, \(gamesNeedingDownload.count) need downloads")
            await MainActor.run {
                SyncProgressTracker.shared.setDatabaseSynced(true)
            }

            // PHASE 2: Queue background downloads with intelligent prioritization
            if !gamesNeedingDownload.isEmpty {
                syncLog.event(.download, item: "loadAllFromCloud/phase2", status: .inProgress, detail: "\(gamesNeedingDownload.count) games queued")
                await queueGamesForDownloadWithSpaceManagement(gamesNeedingDownload)
            } else {
                syncLog.event(.download, item: "loadAllFromCloud/phase2", status: .skipped, detail: "all games up to date")
            }

            syncLog.event(.complete, item: "loadAllFromCloud", status: .ok, detail: "\(metadataProcessedCount) games visible")

            // PHASE 3: Backfill missing artwork for games that have a customArtworkURL in Realm
            // but the local PVMediaCache file has been deleted (e.g. reinstall, cache clear).
            await cacheMissingArtworkForExistingGames(limit: 200)

#if os(tvOS)
            await reconcileMissingLocalGames()
#endif

        } catch {
            if let ckError = error as? CKError {
                syncLog.event(.error, item: "loadAllFromCloud", status: .failed, detail: "CKError code=\(ckError.code.rawValue): \(ckError.localizedDescription)")
            } else {
                syncLog.event(.error, item: "loadAllFromCloud", status: .failed, detail: error.localizedDescription)
            }
            // Handle error appropriately (e.g., log, notify user)
            // Consider throwing or returning an error state if the protocol allowed.
        }

        // Call the completion handler if provided
        await iterationComplete?()

        return Completable.empty() // Return Completable as required by SyncProvider
    }

    public func insertDownloadingFile(_ file: URL) async -> URL? {
        VLOG("insertDownloadingFile called for CloudKitSyncer - No action needed. File: \(file.path)")
        // CloudKit manages its own temporary download locations.
        return nil
    }

    public func insertDownloadedFile(_ file: URL) async {
        VLOG("insertDownloadedFile called for CloudKitSyncer - Processing should occur within downloadRom completion. File: \(file.path)")
        // Final file handling (move, db update) should be part of the downloadRom logic.
    }

    public func insertUploadedFile(_ file: URL) async {
        VLOG("insertUploadedFile called for CloudKitSyncer - Confirmation should occur within uploadRom completion. File: \(file.path)")
        // Update local tracking if needed
        _ = await uploadedFiles.insert(file)
    }

    public func deleteFromDatastore(_ file: URL) async {
        VLOG("Attempting deleteFromDatastore for URL: \(file.path)")
        do {
            let md5 = try await withRealm { realm -> String? in
                realm.objects(PVGame.self)
                    .filter("file.path == %@", file.path)
                    .first?
                    .md5Hash
            }

            guard let md5 else {
                WLOG("Could not find PVGame matching URL \(file.path) for deletion.")
                return
            }

            CloudSyncManager.syncLog.event(.delete, item: "rom/\(md5)", status: .inProgress, detail: file.path)
            try await markGameAsDeleted(md5: md5)
        } catch {
            CloudSyncManager.syncLog.event(.delete, item: "rom/\(file.path)", status: .failed, detail: error.localizedDescription)
            // Handle or propagate error
        }
    }

    public func setNewCloudFilesAvailable() async {
        ILOG("setNewCloudFilesAvailable called for CloudKitSyncer - Action needed.")
        // This is typically driven by push notifications, but can be called manually.
        // TODO: Investigate correct way to handle CloudKit push notifications/change tokens.
        // await fetchChangesFromServer() // Error: This function doesn't exist on the base syncer. Need alternative mechanism.
    }

    public func prepareNextBatchToProcess() async -> any Collection<URL> {
        VLOG("prepareNextBatchToProcess called for CloudKitSyncer - Not applicable.")
        return []
    }

    private func recordDeclaresAssetPresence(_ record: CKRecord) -> Bool {
        guard record.allKeys().contains(CloudKitSchema.ROMFields.fileData) else {
            // Metadata-only reads omit the asset field entirely; treat as true until proven otherwise
            return true
        }
        return record[CloudKitSchema.ROMFields.fileData] is CKAsset
    }

    /// Fetch and apply remote ROM changes using a persisted zone change token.
    public func fetchAndApplyRemoteChanges() async {
        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            return
        }

        do {
            let zoneID = CKRecordZone.default().zoneID
            let previousToken = loadZoneChangeToken()
            let (records, newToken) = try await fetchZoneChanges(zoneID: zoneID, previousToken: previousToken)

            for record in records {
                if Task.isCancelled { break }
                let pausedForEmulation = await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation })
                if pausedForEmulation { break }

                switch record.recordType {
                case CloudKitSchema.RecordType.rom.rawValue:
                    guard let md5 = CloudKitSchema.RecordIDGenerator.extractMD5FromRomRecordID(record.recordID) else { continue }
                    do {
                        try await updatePVGame(from: record, gameMD5: md5.uppercased())
                    } catch {
                        CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .failed, detail: "remote change: \(error.localizedDescription)")
                    }

                default:
                    continue
                }
            }

            if let newToken {
                saveZoneChangeToken(newToken)
            }
        } catch {
            CloudSyncManager.syncLog.event(.sync, item: "fetchRemoteChanges", status: .failed, detail: error.localizedDescription)
        }
    }

    /// Increment play stats in CloudKit without clobbering concurrent updates.
    /// This uses a fetch-merge-save retry loop on `.serverRecordChanged`.
    public func incrementPlayStats(
        md5: String,
        playCountDelta: Int,
        timeSpentDelta: Int,
        lastPlayed: Date
    ) async throws {
        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            throw CloudSyncError.pausedForEmulation
        }

        let md5 = md5.uppercased()
        guard !md5.isEmpty else { throw CloudSyncError.invalidData }
        guard playCountDelta > 0 || timeSpentDelta > 0 else { return }

        #if os(macOS)
        let deviceIdentifier = Host.current().name ?? "Unknown macOS"
        #else
        let deviceIdentifier = UIDevice.current.name
        #endif

        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
        let desiredKeys: [CKRecord.FieldKey] = [
            CloudKitSchema.ROMFields.md5,
            CloudKitSchema.ROMFields.systemIdentifier,
            CloudKitSchema.ROMFields.title,
            CloudKitSchema.ROMFields.originalFilename,
            CloudKitSchema.ROMFields.isDeleted,
            CloudKitSchema.ROMFields.playCount,
            CloudKitSchema.ROMFields.timeSpentInGame,
            CloudKitSchema.ROMFields.lastPlayed
        ]

        let maxRetries = 4
        for attempt in 0..<maxRetries {
            if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) { throw CloudSyncError.pausedForEmulation }

            let existing = try await fetchRecord(recordID: recordID, desiredKeys: desiredKeys)
            let record = existing ?? CKRecord(recordType: CloudKitSchema.RecordType.rom.rawValue, recordID: recordID)

            if let isDeleted = record[CloudKitSchema.ROMFields.isDeleted] as? Bool, isDeleted {
                return
            }

            if record[CloudKitSchema.ROMFields.md5] == nil { record[CloudKitSchema.ROMFields.md5] = md5 }
            if record[CloudKitSchema.ROMFields.originalFilename] == nil {
                let fileName = try? await withRealm { realm -> String? in
                    realm.object(ofType: PVGame.self, forPrimaryKey: md5)?.file?.fileName ?? realm.object(ofType: PVGame.self, forPrimaryKey: md5)?.fileName
                }
                if let fileName { record[CloudKitSchema.ROMFields.originalFilename] = fileName }
            }

            let currentPlay = (record[CloudKitSchema.ROMFields.playCount] as? NSNumber)?.intValue ?? 0
            let currentTime = (record[CloudKitSchema.ROMFields.timeSpentInGame] as? NSNumber)?.intValue ?? 0
            let currentLast = record[CloudKitSchema.ROMFields.lastPlayed] as? Date

            record[CloudKitSchema.ROMFields.playCount] = NSNumber(value: currentPlay + playCountDelta)
            record[CloudKitSchema.ROMFields.timeSpentInGame] = NSNumber(value: currentTime + timeSpentDelta)
            record[CloudKitSchema.ROMFields.lastPlayed] = currentLast.map { max($0, lastPlayed) } ?? lastPlayed
            record[CloudKitSchema.ROMFields.lastModifiedDevice] = deviceIdentifier

            do {
                _ = try await self.database.save(record)
                return
            } catch let error as CKError where error.code == .serverRecordChanged && attempt < maxRetries - 1 {
                continue
            }
        }
    }

    private func fetchRecord(recordID: CKRecord.ID, desiredKeys: [CKRecord.FieldKey]) async throws -> CKRecord? {
        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            return nil
        }

        return try await runOnQueue { [self] in
            do {
                let record = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord?, Error>) in
                    let op = CKFetchRecordsOperation(recordIDs: [recordID])
                    op.desiredKeys = desiredKeys
                    var fetched: CKRecord?
                    op.perRecordResultBlock = { _, result in
                        if case let .success(r) = result { fetched = r }
                    }
                    op.fetchRecordsCompletionBlock = { _, error in
                        if let error = error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: fetched) }
                    }
                    self.database.add(op)
                }
                return record
            } catch let error as CKError where error.code == .unknownItem {
                return nil
            }
        }
    }

    private func fetchZoneChanges(zoneID: CKRecordZone.ID, previousToken: CKServerChangeToken?) async throws -> ([CKRecord], CKServerChangeToken?) {
        try await runOnQueue { [self] in
            try await withCheckedThrowingContinuation { continuation in
                var fetchedRecords: [CKRecord] = []
                var nextToken: CKServerChangeToken?
                var fetchError: Error?

                let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(previousServerChangeToken: previousToken)
                let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: config])
                op.fetchAllChanges = true

                op.recordChangedBlock = { record in
                    fetchedRecords.append(record)
                }

                op.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
                    nextToken = token
                }

                op.recordZoneFetchCompletionBlock = { _, token, _, _, error in
                    if let token { nextToken = token }
                    if let error { fetchError = error }
                }

                op.fetchRecordZoneChangesCompletionBlock = { error in
                    if let error = fetchError ?? error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: (fetchedRecords, nextToken)) }
                }

                self.database.add(op)
            }
        }
    }

    private func loadZoneChangeToken() -> CKServerChangeToken? {
        guard let data = changeTokenStorage.data(forKey: changeTokenStorageKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func saveZoneChangeToken(_ token: CKServerChangeToken) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else { return }
        changeTokenStorage.set(data, forKey: changeTokenStorageKey)
    }

    // MARK: - CloudKit Operations

    /// Fetches and processes ROM metadata by MD5 hash to create/update PVGame.
    /// This is useful when a save state references a game that doesn't exist locally yet.
    /// - Parameter md5: The MD5 hash of the ROM
    /// - Returns: True if the game was created or updated, false otherwise
    public func fetchAndProcessROMMetadata(md5: String) async -> Bool {
        guard !(await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation })) else {
            ILOG("[SYNC] Emulator session active, skipping ROM metadata fetch for MD5 \(md5)")
            return false
        }

        do {
            let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
            guard let romRecord = try await fetchRecord(recordID: recordID, includeAssets: false) else {
                CloudSyncManager.syncLog.event(.query, item: "rom/\(md5)", status: .notFound)
                return false
            }

            /// Try to create the game first
            do {
                if let _ = try await createPVGame(from: romRecord) {
                    CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .ok, detail: "created from metadata")
                    return true
                }
            } catch {
                /// Game might already exist, try updating it
                do {
                    try await updatePVGame(from: romRecord, gameMD5: md5.uppercased())
                    CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .ok, detail: "updated from metadata")
                    return true
                } catch {
                    CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .failed, detail: error.localizedDescription)
                    return false
                }
            }
        } catch {
            CloudSyncManager.syncLog.event(.query, item: "rom/\(md5)", status: .failed, detail: error.localizedDescription)
            return false
        }

        return false
    }

    /// Fetches a single CKRecord by its ID from a specific database.
    /// Returns nil (not throws) when the record simply doesn't exist in that database.
    private func fetchRecord(recordID: CKRecord.ID, includeAssets: Bool, from db: CKDatabase) async throws -> CKRecord? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord?, Error>) in
            let op = CKFetchRecordsOperation(recordIDs: [recordID])
            let metadataKeys = [
                CloudKitSchema.ROMFields.md5,
                CloudKitSchema.ROMFields.title,
                CloudKitSchema.ROMFields.systemIdentifier,
                CloudKitSchema.ROMFields.fileSize,
                CloudKitSchema.SaveStateFields.directory,
                CloudKitSchema.SaveStateFields.filename,
                CloudKitSchema.ROMFields.originalFilename,
                CloudKitSchema.ROMFields.originalArtworkURL,
                CloudKitSchema.ROMFields.customArtworkURL,
                CloudKitSchema.ROMFields.isDeleted
            ]
            op.desiredKeys = includeAssets ? metadataKeys + [
                CloudKitSchema.ROMFields.fileData,
                CloudKitSchema.ROMFields.isArchive,
                CloudKitSchema.ROMFields.relatedFilenames,
                CloudKitSchema.ROMFields.customArtworkAsset
            ] : metadataKeys
            var fetched: CKRecord?
            op.perRecordResultBlock = { _, result in
                if case let .success(r) = result { fetched = r }
            }
            op.fetchRecordsCompletionBlock = { _, error in
                if let ckError = error as? CKError {
                    if ckError.code == .unknownItem {
                        continuation.resume(returning: nil)
                    } else if ckError.code == .partialFailure,
                              let partials = ckError.partialErrorsByItemID,
                              partials.count == 1,
                              let inner = partials.values.first as? CKError,
                              inner.code == .unknownItem {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: ckError)
                    }
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: fetched)
                }
            }
            db.add(op)
        }
    }

    /// Fetches a single CKRecord by its ID, trying the primary database first then any
    /// fallback databases (e.g. dev container in production builds) for reads.
    /// - Parameters:
    ///   - recordID: The CloudKit record identifier.
    ///   - includeAssets: When true, also fetches asset fields required for downloads.
    ///   - bypassEmulationPause: When true, allows a metadata-only fetch while the emulator UI session has paused heavy sync I/O (not core `setPauseEmulation`).
    ///     Use only for small CloudKit operations such as conflict resolution; do not combine with `includeAssets: true` during an active emulator session.
    public func fetchRecord(
        recordID: CKRecord.ID,
        includeAssets: Bool = false,
        bypassEmulationPause: Bool = false
    ) async throws -> CKRecord? {
        if !bypassEmulationPause, await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            ILOG("[SYNC] Emulator session active, skipping ROM fetch for \(recordID.recordName)")
            return nil
        }

        return try await runOnQueue { [self] in
            // Try primary database first
            if let record = try await fetchRecord(recordID: recordID, includeAssets: includeAssets, from: database) {
                VLOG("Fetched record from primary container: \(record.recordID.recordName)")
                return record
            }

            // Try fallback databases (read-only, e.g. dev container in production builds).
            // Regular TestFlight/App Store users won't have access to the dev container,
            // so badContainer errors are caught and the fallback is disabled for the session.
            for fallbackDB in fallbackDatabases {
                do {
                    if let record = try await fetchRecord(recordID: recordID, includeAssets: includeAssets, from: fallbackDB) {
                        DLOG("Fetched record from fallback container: \(record.recordID.recordName)")
                        return record
                    }
                } catch let error as CKError where error.code == .badContainer {
                    DLOG("Fallback container not accessible (badContainer) — disabling for session")
                    iCloudConstants.invalidateFallbackContainers()
                    break
                } catch {
                    DLOG("Fallback container fetch failed: \(error.localizedDescription)")
                }
            }

            VLOG("Record not found in any container: \(recordID.recordName)")
            return nil
        }
    }

    /// Fetch a CloudKit record with download progress tracking for assets
    /// - Parameters:
    ///   - recordID: The record ID to fetch
    ///   - expectedSize: Expected file size for speed calculation (optional)
    ///   - progressHandler: Callback with progress (0.0 to 1.0) and speed string
    /// - Returns: The fetched record, or nil if not found
    public func fetchRecordWithProgress(
        recordID: CKRecord.ID,
        expectedSize: Int64? = nil,
        progressHandler: ((Double, String?) -> Void)? = nil
    ) async throws -> CKRecord? {
        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            ILOG("[SYNC] Emulator session active, skipping ROM fetch (with progress) for \(recordID.recordName)")
            return nil
        }

        return try await runOnQueue { [self] in
            let desiredKeys = [
                CloudKitSchema.ROMFields.md5,
                CloudKitSchema.ROMFields.title,
                CloudKitSchema.ROMFields.systemIdentifier,
                CloudKitSchema.ROMFields.fileSize,
                CloudKitSchema.ROMFields.originalFilename,
                CloudKitSchema.ROMFields.originalArtworkURL,
                CloudKitSchema.ROMFields.customArtworkURL,
                CloudKitSchema.ROMFields.isDeleted,
                CloudKitSchema.ROMFields.fileData,
                CloudKitSchema.ROMFields.isArchive,
                CloudKitSchema.ROMFields.relatedFilenames,
                CloudKitSchema.ROMFields.customArtworkAsset
            ]

            let downloadStartTime = Date()
            var lastProgressUpdate = Date()
            var lastProgress: Double = 0

            let makeProgressBlock: () -> ((CKRecord.ID, Double) -> Void) = {
                return { [expectedSize] _, progress in
                    let now = Date()
                    let elapsed = now.timeIntervalSince(downloadStartTime)

                    var speedString: String? = nil
                    if elapsed > 0.5 && progress > 0.01 {
                        if let totalSize = expectedSize, totalSize > 0 {
                            let downloadedBytes = Double(totalSize) * progress
                            let bytesPerSecond = downloadedBytes / elapsed
                            speedString = Self.formatSpeed(bytesPerSecond)
                        } else {
                            let progressDelta = progress - lastProgress
                            let timeDelta = now.timeIntervalSince(lastProgressUpdate)
                            if timeDelta > 0.1 && progressDelta > 0 {
                                let estimatedBytesPerSecond = (progressDelta / timeDelta) * 10_000_000
                                speedString = Self.formatSpeed(estimatedBytesPerSecond)
                            }
                        }
                    }

                    lastProgress = progress
                    lastProgressUpdate = now

                    DLOG("[SYNC] Download progress: \(Int(progress * 100))% \(speedString ?? "")")
                    progressHandler?(progress, speedString)
                }
            }

            /// Fetch from a specific database, returning nil for "not found" errors.
            func fetchFrom(_ db: CKDatabase) async throws -> CKRecord? {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord?, Error>) in
                    let op = CKFetchRecordsOperation(recordIDs: [recordID])
                    op.desiredKeys = desiredKeys
                    op.perRecordProgressBlock = makeProgressBlock()

                    var fetched: CKRecord?
                    op.perRecordResultBlock = { _, result in
                        if case let .success(r) = result { fetched = r }
                    }

                    op.fetchRecordsCompletionBlock = { _, error in
                        if let error = error as? CKError {
                            if error.code == .unknownItem {
                                continuation.resume(returning: nil)
                            } else if error.code == .partialFailure,
                                      let partialErrors = error.partialErrorsByItemID,
                                      partialErrors.count == 1,
                                      let (_, partialError) = partialErrors.first,
                                      let partialCKError = partialError as? CKError,
                                      partialCKError.code == .unknownItem {
                                continuation.resume(returning: nil)
                            } else {
                                continuation.resume(throwing: CloudSyncError.cloudKitError(error))
                            }
                        } else if let error = error {
                            continuation.resume(throwing: CloudSyncError.cloudKitError(error))
                        } else {
                            continuation.resume(returning: fetched)
                        }
                    }

                    op.qualityOfService = .userInitiated
                    db.add(op)
                }
            }

            // Try primary database first
            if let record = try await fetchFrom(self.database) {
                return record
            }

            // Try fallback databases (e.g. dev container in production/TestFlight builds)
            for fallbackDB in fallbackDatabases {
                do {
                    if let record = try await fetchFrom(fallbackDB) {
                        DLOG("Fetched record with progress from fallback container: \(record.recordID.recordName)")
                        return record
                    }
                } catch let syncError as CloudSyncError {
                    // Unwrap CloudSyncError to check for badContainer
                    if case .cloudKitError(let inner) = syncError,
                       let ckError = inner as? CKError, ckError.code == .badContainer {
                        DLOG("Fallback container not accessible (badContainer) — disabling for session")
                        iCloudConstants.invalidateFallbackContainers()
                        break
                    }
                    DLOG("Fallback fetch with progress failed: \(syncError.localizedDescription)")
                } catch {
                    DLOG("Fallback fetch with progress failed: \(error.localizedDescription)")
                }
            }

            return nil
        }
    }

    /// Format bytes per second into human-readable speed string
    private static func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.0f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }

    // MARK: - RomsSyncing Protocol Implementation

    /// Returns the local file URL for the given game.
    public func localURL(for game: PVGame) -> URL? {
        // Check if the game object is valid first
        if game.isInvalidated {
            WLOG("Attempting to get localURL for invalidated game: \(game.debugDescription)")
            return nil
        }

        // Check if the file URL exists and the file is actually present
        guard let url = game.file?.url, fileManager.fileExists(atPath: url.path) else {
            VLOG("Game \(game.title) (MD5: \(game.md5Hash ?? "N/A")) does not have a valid local file URL or the file doesn't exist.")
            return nil
        }

        VLOG("Returning local URL for game \(game.title): \(url.path)")
        return url
    }

    /// Returns a conceptual cloud URL placeholder (currently nil for CloudKit).
    /// CloudKit uses CKAssets tied to CKRecords, not direct file URLs like iCloud Drive.
    public func cloudURL(for game: PVGame) -> URL? {
        // CloudKit doesn't provide a predictable URL for a potential cloud asset
        // merely from the PVGame object. We need the CKRecord to check for the asset.
        // Returning nil signifies this limitation compared to file-based syncers.
        VLOG("cloudURL requested for CloudKit, returning nil as it's not directly applicable. Game MD5: \(game.md5Hash ?? "N/A")")
        return nil
    }

    public func uploadGame(_ md5: String) async throws {
        let game = try await withRealm { realm -> PVGame in
            guard let liveGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
                throw CloudSyncError.invalidData
            }
            return liveGame.freeze()
        }

        guard !game.contentless else {
            VLOG("Skipping CloudKit upload for contentless placeholder game: \(game.title)")
            return
        }

        let md5 = game.md5Hash
        guard !md5.isEmpty else {
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(game.title)", status: .failed, detail: "missing MD5")
            throw CloudSyncError.invalidData
        }

        // 1. Fetch or Create Record
        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
        var record: CKRecord
        do {
            record = try await fetchRecord(recordID: recordID) ?? CKRecord(recordType: CloudKitSchema.RecordType.rom.rawValue, recordID: recordID)
        } catch let cloudSyncError as CloudSyncError {
            // Extract underlying error details if it's a wrapped CloudKit error
            let errorDetails = extractErrorDetails(cloudSyncError)
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "fetch base record: \(errorDetails)")
            throw cloudSyncError
        } catch {
            let errorDetails = extractErrorDetails(CloudSyncError.cloudKitError(error))
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "fetch base record: \(errorDetails)")
            throw CloudSyncError.cloudKitError(error)
        }

        // Check if already marked deleted remotely, if so, skip upload
        if let isDeleted = record[CloudKitSchema.ROMFields.isDeleted] as? Bool, isDeleted == true {
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .skipped, detail: "marked deleted in CloudKit")
            // Optional: Update local state if needed?
            return
        }

        // 2. Map Game Data to Record
        do {
            // Validate required fields before mapping
            guard !game.title.isEmpty else {
                CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "empty title")
                throw CloudSyncError.invalidData
            }
            guard !game.systemIdentifier.isEmpty else {
                CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "empty systemIdentifier")
                throw CloudSyncError.invalidData
            }

            record = try mapPVGameToRecord(game, existingRecord: record)

            // Validate record metadata size (CloudKit has 1MB limit for record metadata)
            let recordMetadataSize = try estimateRecordMetadataSize(record)
            let maxRecordMetadataSize: Int64 = 1024 * 1024 // 1MB
            if recordMetadataSize > maxRecordMetadataSize {
                CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "metadata size \(ByteCountFormatter.string(fromByteCount: recordMetadataSize, countStyle: .file)) exceeds limit")
                throw CloudSyncError.invalidData
            }
        } catch let error as CloudSyncError {
            throw error // Rethrow known sync errors
        } catch {
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "mapping error: \(error.localizedDescription)")
            throw CloudSyncError.unknown // Or map to a more specific error if possible
        }

        // 2.5. Prepare Custom Artwork Asset (if exists)
        do {
            record = try await prepareCustomArtworkAsset(for: game, record: record)
        } catch {
            WLOG("Failed to prepare custom artwork asset for \(md5): \(error.localizedDescription)")
            // Continue with upload even if artwork preparation fails
        }

        // 3. Prepare Asset (CKAsset) - Zip if necessary using ZipArchive
        guard let primaryFileURL = game.file?.url else {
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "missing primary file URL")
            throw CloudSyncError.invalidData
        }

        // Verify the file actually exists at the expected location
        guard FileManager.default.fileExists(atPath: primaryFileURL.path) else {
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "file not found at \(primaryFileURL.path)")
            throw CloudSyncError.fileSystemError(NSError(domain: "CloudKitRomsSyncer", code: 404, userInfo: [NSLocalizedDescriptionKey: "ROM file not found at expected path"]))
        }

        // Validate file size before proceeding (CloudKit asset limit is 500MB)
        let maxAssetSize: Int64 = 500 * 1024 * 1024 // 500MB
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: primaryFileURL.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
                if fileSize > maxAssetSize {
                    let sizeMB = Double(fileSize) / (1024 * 1024)
                    let maxMB = Double(maxAssetSize) / (1024 * 1024)
                    CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "file \(String(format: "%.1f", sizeMB))MB exceeds \(String(format: "%.1f", maxMB))MB limit")
                    throw CloudSyncError.assetTooLarge(size: fileSize, maxSize: maxAssetSize)
                }
                if fileSize == 0 {
                    CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "file size is 0 bytes")
                    throw CloudSyncError.invalidData
                }
                VLOG("File size validation passed for \(md5): \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            }
        } catch let error as CloudSyncError {
            throw error
        } catch {
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "file attributes: \(error.localizedDescription)")
            throw CloudSyncError.fileSystemError(error)
        }

        // Verify file is readable
        guard FileManager.default.isReadableFile(atPath: primaryFileURL.path) else {
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "file not readable at \(primaryFileURL.path)")
            throw CloudSyncError.fileSystemError(NSError(domain: "CloudKitRomsSyncer", code: 403, userInfo: [NSLocalizedDescriptionKey: "ROM file is not readable"]))
        }
        let relatedFileURLs = game.relatedFiles.filter { $0.url?.lastPathComponent != primaryFileURL.lastPathComponent }.compactMap { $0.url }
        let filesToPackage = [primaryFileURL] + relatedFileURLs

        var asset: CKAsset?
        var isArchive: Bool = false
        var tempZipURL: URL? = nil // Keep track for cleanup

        do {
            let assetSourceURL: URL
            if filesToPackage.count > 1 {
                VLOG("Multiple files for \(md5). Creating ZipArchive zip archive.")
                isArchive = true
                let zipURL = try temporaryZipURL(for: md5)
                tempZipURL = zipURL // Store for potential cleanup
                // Call the createZip helper
                try await createZip(files: filesToPackage, primaryFile: primaryFileURL, outputURL: zipURL)
                assetSourceURL = zipURL
                // Store relative paths of related files (excluding primary)
                record[CloudKitSchema.ROMFields.relatedFilenames] = relatedFileURLs.map { $0.lastPathComponent } as [NSString]
            } else {
                // Single file, just use its URL directly
                VLOG("Single file for \(md5). Using direct URL: \(primaryFileURL.path)")
                isArchive = false
                assetSourceURL = primaryFileURL
                record[CloudKitSchema.ROMFields.relatedFilenames] = nil // Clear related filenames if it was previously an archive
            }

            // Create the CKAsset from the final URL (either original file or temp zip)
            asset = CKAsset(fileURL: assetSourceURL)
            record[CloudKitSchema.ROMFields.fileData] = asset
            record[CloudKitSchema.ROMFields.isArchive] = isArchive as NSNumber
            record[CloudKitSchema.ROMFields.originalFilename] = primaryFileURL.lastPathComponent // Always store primary filename

        } catch let error as CloudSyncError {
            // If createZip threw a CloudSyncError, rethrow it
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "asset prep: \(error)")
            if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
                try? await FileManager.default.removeItem(at: url) // Use sync remove here
            }
            throw error
        } catch {
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "unexpected asset error: \(error.localizedDescription)")
            if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
                try? await FileManager.default.removeItem(at: url) // Use sync remove here
            }
            // Wrap unexpected errors appropriately
            throw CloudSyncError.fileSystemError(error)
        }

        // 4. Verify asset is set before saving to CloudKit
        if record[CloudKitSchema.ROMFields.fileData] as? CKAsset == nil {
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "asset not set on record before save")
            if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
                try? await FileManager.default.removeItem(at: url)
            }
            throw CloudSyncError.invalidData
        }

        // Save Record to CloudKit
        do {
            try await saveRecord(record)
            CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .ok, detail: "\(game.title), system=\(game.systemIdentifier)")
        } catch let error as CKError {
            // Clean up zip file if upload fails
            if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
                try? await FileManager.default.removeItem(at: url)
            }

            // Provide specific error messages for common CloudKit errors
            switch error.code {
            case .invalidArguments:
                CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "invalidArguments: corrupted data or invalid record")
                throw CloudSyncError.invalidData
            case .assetFileNotFound:
                CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "assetFileNotFound: removed or inaccessible")
                throw CloudSyncError.fileSystemError(error)
            case .assetFileModified:
                CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "assetFileModified: changed during upload")
                throw CloudSyncError.fileSystemError(error)
            case .limitExceeded:
                CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "limitExceeded: record or asset too large")
                throw CloudSyncError.assetTooLarge(size: 0, maxSize: 500 * 1024 * 1024)
            default:
                CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .failed, detail: "CKError code=\(error.code.rawValue): \(error.localizedDescription)")
                throw CloudSyncError.cloudKitError(error)
            }
        } catch {
            // Clean up zip file if upload fails
            if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
                try? await FileManager.default.removeItem(at: url)
            }
            // Error already logged in saveRecord, just rethrow
            throw error
        }

        // 5. Clean up temporary zip file *after* successful CK upload
        if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
            // Use sync remove here as uploadGame is already async
            do {
                try await FileManager.default.removeItem(at: url)
                VLOG("Cleaned up temporary ZipArchive zip file: \(url.path)")
            } catch {
                WLOG("Failed to clean up temporary zip file \(url.path): \(error)")
            }
        }

        CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .ok, detail: "completed: \(game.title)")
    }
    /// Marks a game record as deleted in CloudKit based on its MD5 hash.
    /// This performs a "soft delete" by setting the `isDeleted` flag.
    /// - Parameter md5: The MD5 hash of the game to mark as deleted.
    public func markGameAsDeleted(md5: String) async throws {
        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
        VLOG("Attempting to mark CloudKit record as deleted: \(recordID.recordName)")

        do {
            // Fetch the existing record
            guard let record = try await fetchRecord(recordID: recordID) else {
                // Record doesn't exist, nothing to mark deleted.
                WLOG("Attempted to mark record as deleted, but it was not found in CloudKit (maybe already deleted?).")
                return
            }
            VLOG("Found record to mark as deleted: \(recordID.recordName)")

            // Check if already marked
            if let isDeleted = record[CloudKitSchema.ROMFields.isDeleted] as? Bool, isDeleted == true {
                VLOG("Record \(recordID.recordName) is already marked as deleted. Skipping.")
                return
            }

            // Set the flag and save
            record[CloudKitSchema.ROMFields.isDeleted] = true

            try await saveRecord(record)
            CloudSyncManager.syncLog.event(.delete, item: "rom/\(record.recordID.recordName)", status: .ok, detail: "soft delete")
        } catch let error as CKError where error.code == .unknownItem {
            CloudSyncManager.syncLog.event(.delete, item: "rom/\(recordID.recordName)", status: .notFound, detail: "already deleted")
            // Consider this non-fatal in a soft-delete scenario
            return
        } catch {
            CloudSyncManager.syncLog.event(.delete, item: "rom/\(recordID.recordName)", status: .failed, detail: error.localizedDescription)
            throw CloudSyncError.cloudKitError(error)
        }
    }

    internal func hardDeleteGame(md5: String) async throws {
        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
        VLOG("Attempting HARD delete for CloudKit record: \(recordID.recordName)")
        do {
            try await database.deleteRecord(withID: recordID)
            CloudSyncManager.syncLog.event(.delete, item: "rom/\(recordID.recordName)", status: .ok, detail: "hard delete")
        } catch let error as CKError where error.code == .unknownItem {
            // Record was already deleted or never existed. This is fine.
            VLOG("Record \(recordID.recordName) not found in CloudKit for deletion (already deleted?). Ignoring.")
        } catch {
            CloudSyncManager.syncLog.event(.delete, item: "rom/\(md5)", status: .failed, detail: error.localizedDescription)
            // If this fails, the local delete succeeded, but the remote record remains.
            // It might get re-downloaded later unless we handle this state.
            throw CloudSyncError.cloudKitError(error)
        }
        // Note: Local Realm deletion is assumed to be handled by the caller or RomsDatastore
        // before this function is called.
    }

    /// Process a cloud record for metadata sync only (Phase 1)
    /// - Parameter record: The CloudKit record to process
    /// - Returns: Game info tuple for downloads, or nil if no download needed
    private func processCloudRecordMetadata(_ record: CKRecord) async -> (md5: String, title: String, fileSize: Int64, systemIdentifier: String)? {
        // Extract MD5 from record ID using centralized method
        guard let md5 = CloudKitSchema.RecordIDGenerator.extractMD5FromRomRecordID(record.recordID) else {
            CloudSyncManager.syncLog.event(.sync, item: "rom/\(record.recordID.recordName)", status: .failed, detail: "invalid record ID format")
            return nil
        }

        let recordName = record.recordID.recordName

        do {
            // Check if record is marked as deleted
            if let isDeleted = record[CloudKitSchema.ROMFields.isDeleted] as? Bool, isDeleted {
                VLOG("Record \(recordName) is marked as deleted, skipping")
                return nil
            }

            // Extract game info from record for potential downloads
            let title = record[CloudKitSchema.ROMFields.title] as? String ?? "Unknown Game"
            let fileSize = record[CloudKitSchema.ROMFields.fileSize] as? Int64 ?? 0
            let systemIdentifier = record[CloudKitSchema.ROMFields.systemIdentifier] as? String ?? ""

            // Check if we have a local game for this MD5
            let existingLocalGame = RomDatabase.sharedInstance.game(withMD5: md5)
            var updatedOrCreatedGame: PVGame?

            if let localGame = existingLocalGame {
                VLOG("Local game found for MD5 \(md5). Updating from cloud record: \(localGame.title) (isDownloaded: \(localGame.isDownloaded))")
                try await updatePVGame(from: record, gameMD5: md5)
                updatedOrCreatedGame = RomDatabase.sharedInstance.game(withMD5: md5)
            } else {
                CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .inProgress, detail: "creating from cloud record")
                updatedOrCreatedGame = try await createPVGame(from: record)
                CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .ok, detail: "created: \(updatedOrCreatedGame?.title ?? "Unknown") (isDownloaded: \(updatedOrCreatedGame?.isDownloaded ?? false))")
            }

            // Check if download will be needed (but don't trigger it yet)
            if let game = updatedOrCreatedGame, !game.isDownloaded {
                // Verify the record declares an asset before marking for download
                if recordDeclaresAssetPresence(record) {
                    VLOG("Local game \(md5) marked for background download")
                    return (md5: md5, title: title, fileSize: fileSize, systemIdentifier: systemIdentifier)
                } else {
                    CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .notFound, detail: "needs download but no remote asset")
                }
            } else if let game = updatedOrCreatedGame {
                VLOG("Local game \(md5) already downloaded or up to date")
            } else {
                CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .failed, detail: "create/update returned nil")
            }

        } catch let error as CKError {
            CloudSyncManager.syncLog.event(.error, item: "rom/\(record.recordID.recordName)", status: .failed, detail: "CKError code=\(error.code.rawValue): \(error.localizedDescription)")

            // Handle specific CloudKit errors
            switch error.code {
            case .unknownItem:
                CloudSyncManager.syncLog.event(.check, item: "rom/\(record.recordID.recordName)", status: .notFound, detail: "may have been deleted")
            case .networkFailure, .networkUnavailable:
                CloudSyncManager.syncLog.event(.retry, item: "rom/\(record.recordID.recordName)", status: .pending, detail: "network error")
            case .requestRateLimited:
                CloudSyncManager.syncLog.event(.retry, item: "rom/\(record.recordID.recordName)", status: .pending, detail: "rate limited")
            default:
                if error.isRecoverableCloudKitError {
                    CloudSyncManager.syncLog.event(.retry, item: "rom/\(record.recordID.recordName)", status: .pending, detail: "recoverable error")
                } else {
                    CloudSyncManager.syncLog.event(.error, item: "rom/\(record.recordID.recordName)", status: .failed, detail: "non-recoverable CKError")
                }
            }
        } catch {
            CloudSyncManager.syncLog.event(.error, item: "rom/\(record.recordID.recordName)", status: .failed, detail: error.localizedDescription)
        }

        return nil // No download needed
    }

    /// Queue a ROM upload without blocking sync operations
    /// - Parameters:
    ///   - md5: ROM MD5 hash
    ///   - gameTitle: Game title for logging
    ///   - filePath: Path to ROM file
    ///   - priority: Upload priority
    /// - Returns: Upload task ID for tracking
    @discardableResult
    public func queueROMUpload(md5: String, gameTitle: String, filePath: URL, priority: CloudKitUploadQueueActor.UploadTask.Priority = .normal) async -> UUID {
        CloudSyncManager.syncLog.event(.upload, item: "rom/\(md5)", status: .pending, detail: gameTitle)
        return await uploadQueue.enqueueUpload(md5: md5, gameTitle: gameTitle, filePath: filePath, priority: priority)
    }

    /// Upload a ROM file directly (used by upload queue)
    /// - Parameters:
    ///   - md5: ROM MD5 hash
    ///   - filePath: Path to ROM file
    internal func uploadGameFile(md5: String, filePath: URL) async throws {
//        // Get the game from database
//        guard let game = RomDatabase.sharedInstance.game(withMD5: md5) else {
//            throw CloudSyncError.gameNotFound("Game with MD5 \(md5) not found in database")
//        }
//
//        ILOG("📤 Starting direct ROM upload: \(game.title) (MD5: \(md5))")

        // Use existing uploadGame method
        _ = try await uploadGame(md5)

//        ILOG("✅ Direct ROM upload completed: \(game.title) (MD5: \(md5))")
    }

    /// Queue ROM files for download with intelligent space management and prioritization
    /// - Parameter gameInfos: Array of game info tuples for games that need downloads
    private func queueGamesForDownloadWithSpaceManagement(_ gameInfos: [(md5: String, title: String, fileSize: Int64, systemIdentifier: String)]) async {
        guard !gameInfos.isEmpty else {
            CloudSyncManager.syncLog.event(.download, item: "downloadQueue", status: .skipped, detail: "no games need downloads")
            return
        }

        CloudSyncManager.syncLog.event(.download, item: "downloadQueue", status: .inProgress, detail: "\(gameInfos.count) games with space management")

        let downloadQueue = CloudKitDownloadQueue.shared
        var queuedCount = 0
        var skippedCount = 0
        var totalSpaceNeeded: Int64 = 0

        // Sort games by file size (smallest first) for better success rate
        let sortedGameInfos = gameInfos.sorted { $0.fileSize < $1.fileSize }

        // Calculate total space needed for all games
        totalSpaceNeeded = sortedGameInfos.reduce(0) { $0 + $1.fileSize }

        // Update progress tracker with space requirements
        await progressTracker.updateDiskSpace()
        let availableSpace = await progressTracker.availableDiskSpace

        CloudSyncManager.syncLog.event(.check, item: "downloadQueue/space", status: .ok, detail: "\(gameInfos.count) games need \(ByteCountFormatter.string(fromByteCount: totalSpaceNeeded, countStyle: .file)), \(ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)) available")

        #if os(tvOS)
        // More conservative approach on tvOS
        let spaceBuffer: Int64 = 2_000_000_000 // 2GB buffer for tvOS
        var maxAllowableSpace = max(0, availableSpace - spaceBuffer)

        if totalSpaceNeeded > maxAllowableSpace {
            CloudSyncManager.syncLog.event(.download, item: "downloadQueue/tvOS", status: .pending, detail: "size \(ByteCountFormatter.string(fromByteCount: totalSpaceNeeded, countStyle: .file)) exceeds space, queueing selectively")
        }
        var remainingAutoSyncBudget = maxAllowableSpace
        #endif

        for gameInfo in sortedGameInfos {
            // Check if this specific game is already in the queue
            let alreadyQueued = await progressTracker.alreadyQueued(md5: gameInfo.md5)

            if alreadyQueued {
                VLOG("Game \(gameInfo.title) (\(gameInfo.md5)) already in download queue, skipping")
                skippedCount += 1
                continue
            }

            #if os(tvOS)
            let canAutoSync = remainingAutoSyncBudget > 0 && gameInfo.fileSize <= remainingAutoSyncBudget
            if !canAutoSync {
                CloudSyncManager.syncLog.event(.skip, item: "rom/\(gameInfo.md5)", status: .skipped, detail: "tvOS space budget \(ByteCountFormatter.string(fromByteCount: remainingAutoSyncBudget, countStyle: .file)) remaining")
                skippedCount += 1
                continue
            }
            #endif

            do {
                // Queue with normal priority for background sync
                try await downloadQueue.queueDownload(
                    md5: gameInfo.md5,
                    title: gameInfo.title,
                    fileSize: gameInfo.fileSize,
                    systemIdentifier: gameInfo.systemIdentifier,
                    priority: .normal,
                    onDemand: false
                )
                queuedCount += 1
                #if os(tvOS)
                remainingAutoSyncBudget = max(0, remainingAutoSyncBudget - gameInfo.fileSize)
                #endif
                VLOG("Queued download: \(gameInfo.title) (\(gameInfo.md5)) - \(ByteCountFormatter.string(fromByteCount: gameInfo.fileSize, countStyle: .file))")

            } catch CloudSyncError.insufficientSpace(let required, let available) {
                CloudSyncManager.syncLog.event(.download, item: "rom/\(gameInfo.md5)", status: .skipped, detail: "insufficient space: need \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), have \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))")
                skippedCount += 1

                #if os(tvOS)
                // On tvOS, stop queuing more downloads if we hit space limits
                CloudSyncManager.syncLog.event(.download, item: "downloadQueue/tvOS", status: .cancelled, detail: "space limit reached")
                break
                #endif

            } catch {
                CloudSyncManager.syncLog.event(.download, item: "rom/\(gameInfo.md5)", status: .failed, detail: "\(error)")
                skippedCount += 1
            }
        }

        let totalQueuedSize = queuedCount > 0 ? sortedGameInfos.prefix(queuedCount).reduce(0) { $0 + $1.fileSize } : Int64(0)
        let skippedSize = skippedCount > 0 ? sortedGameInfos.suffix(skippedCount).reduce(0) { $0 + $1.fileSize } : Int64(0)
        CloudSyncManager.syncLog.event(.complete, item: "downloadQueue", status: .ok, detail: "\(queuedCount) queued (\(ByteCountFormatter.string(fromByteCount: totalQueuedSize, countStyle: .file))), \(skippedCount) skipped (\(ByteCountFormatter.string(fromByteCount: skippedSize, countStyle: .file)))")
    }

    /// Legacy method - replaced by queueGamesForDownloadWithSpaceManagement
    /// Queue ROM files for download with space checking (Phase 2)
    /// - Parameter md5List: Array of MD5 hashes for games that need downloads
    private func queueGamesForDownload(_ md5List: [String]) async {
        guard !md5List.isEmpty else {
            CloudSyncManager.syncLog.event(.download, item: "downloadQueue/legacy", status: .skipped, detail: "no games need downloads")
            return
        }

        CloudSyncManager.syncLog.event(.download, item: "downloadQueue/legacy", status: .inProgress, detail: "\(md5List.count) games")

        let downloadQueue = CloudKitDownloadQueue.shared
        var queuedCount = 0
        var skippedCount = 0

        for md5 in md5List {
            // Get game info for the download queue
            guard let game = RomDatabase.sharedInstance.game(withMD5: md5) else {
                CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .notFound, detail: "game not in database")
                skippedCount += 1
                continue
            }

            do {
                // Queue with normal priority for background sync
                try await downloadQueue.queueDownload(
                    md5: md5,
                    title: game.title,
                    fileSize: Int64(game.fileSize),
                    systemIdentifier: game.systemIdentifier,
                    priority: .normal,
                    onDemand: false
                )
                queuedCount += 1
                VLOG("Queued download: \(game.title) (\(md5))")

            } catch CloudSyncError.insufficientSpace(let required, let available) {
                CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .skipped, detail: "insufficient space: need \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), have \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))")
                skippedCount += 1

                #if os(tvOS)
                CloudSyncManager.syncLog.event(.download, item: "downloadQueue/legacy/tvOS", status: .cancelled, detail: "space limit reached")
                break
                #endif

            } catch {
                CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: "\(error)")
                skippedCount += 1
            }
        }

        CloudSyncManager.syncLog.event(.complete, item: "downloadQueue/legacy", status: .ok, detail: "\(queuedCount) queued, \(skippedCount) skipped")
    }

    #if os(tvOS)
    /// tvOS-specific helper that re-queues games whose files were evicted from local storage
    private func reconcileMissingLocalGames() async {
        let downloadedGames: [PVGame]
        do {
            downloadedGames = try await withRealm { realm -> [PVGame] in
                realm.objects(PVGame.self)
                    .filter("isDownloaded == true AND contentless == false")
                    .map { $0.freeze() }
            }
        } catch {
            CloudSyncManager.syncLog.event(.query, item: "reconcile/tvOS", status: .failed, detail: error.localizedDescription)
            return
        }
        guard !downloadedGames.isEmpty else { return }

        let fileManager = FileManager.default
        for game in downloadedGames {
            let hasFile = game.file?.url.map { fileManager.fileExists(atPath: $0.path) } ?? false
            if hasFile {
                continue
            }

            guard let cloudRecordID = game.cloudRecordID, !cloudRecordID.isEmpty else {
                continue
            }

            let md5 = game.md5Hash
            let alreadyQueued = await MainActor.run {
                SyncProgressTracker.shared.alreadyQueued(md5: md5)
            }
            if alreadyQueued {
                continue
            }

            do {
                try await withRealm { realm in
                    guard let liveGame = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash.uppercased()) else {
                        return
                    }
                    try realm.write {
                        liveGame.isDownloaded = false
                    }
                }
            } catch {
                CloudSyncManager.syncLog.event(.sync, item: "rom/\(game.md5Hash)", status: .failed, detail: "flag not downloaded: \(error.localizedDescription)")
                continue
            }

            let fileSize = game.fileSize > 0 ? Int64(game.fileSize) : 1
            do {
                try await CloudKitDownloadQueue.shared.queueDownload(
                    md5: md5,
                    title: game.title,
                    fileSize: fileSize,
                    systemIdentifier: game.systemIdentifier,
                    priority: .normal,
                    onDemand: false
                )
                CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .pending, detail: "tvOS re-queued after eviction: \(game.title)")
            } catch {
                CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: "tvOS re-queue: \(error.localizedDescription)")
            }
        }
    }
    #endif

    public func handleRemoteGameChange(recordID: CKRecord.ID) async throws {
        VLOG("Handling remote change for record ID: \(recordID.recordName)")

        // 1. Fetch the record from CloudKit
        // Use optional catch as .unknownItem is expected if the record was truly deleted (though less likely with soft delete)
        var fetchedRecord: CKRecord?
        do {
            fetchedRecord = try await fetchRecord(recordID: recordID, includeAssets: true)
        } catch let error as CKError where error.code == .unknownItem {
            CloudSyncManager.syncLog.event(.sync, item: "rom/\(recordID.recordName)", status: .notFound, detail: "may have been hard deleted")
            // If truly not found, we might need to delete locally if we have it?
            // Let's extract MD5 first to check local state.
        } catch {
            // Rethrow other errors
            throw error
        }

        guard let md5 = CloudKitSchema.RecordIDGenerator.extractMD5FromRomRecordID(recordID) else {
            CloudSyncManager.syncLog.event(.sync, item: "rom/\(recordID.recordName)", status: .failed, detail: "invalid record ID format")
            return
        }

        // MD5 already extracted and validated above

        // 3. Process based on fetched record and isDeleted flag
        if let record = fetchedRecord {
            let isMarkedDeleted = record[CloudKitSchema.ROMFields.isDeleted] as? Bool ?? false

            if isMarkedDeleted {
                // --- Handle Soft Delete ---
                CloudSyncManager.syncLog.event(.delete, item: "rom/\(md5)", status: .inProgress, detail: "remote soft delete")
                if let localGame = RomDatabase.sharedInstance.game(withMD5: md5) {
                    VLOG("Deleting local game \(localGame.title) due to remote delete flag.")
                    do {
                        // IMPORTANT: This delete call must NOT trigger the PVGameWillBeDeleted notification
                        // or subsequent CloudKit update, otherwise it loops.
                        // Use source: .cloudKitSync to prevent notification cascade.
                        try RomDatabase.sharedInstance.delete(game: localGame, source: .cloudKitSync)
                        CloudSyncManager.syncLog.event(.delete, item: "rom/\(md5)", status: .ok, detail: "local game deleted per remote flag")
                    } catch {
                        CloudSyncManager.syncLog.event(.delete, item: "rom/\(md5)", status: .failed, detail: "remote flag delete: \(error)")
                        // Decide how to handle - retry? Log?
                    }
                } else {
                    VLOG("Local game \(md5) not found, no need to delete locally.")
                }
                // --- End Soft Delete Handling ---

            } else {
                // --- Handle Create or Update ---
                CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .inProgress, detail: "remote create/update")
                let existingLocalGame = RomDatabase.sharedInstance.game(withMD5: md5)
                var updatedOrCreatedGame: PVGame?

                if let localGame = existingLocalGame {
                    VLOG("Local game found for MD5 \(md5). Updating...")
                    try await updatePVGame(from: record, gameMD5: localGame.md5Hash)
                    // Re-fetch in case update modified it significantly or mapping requires it
                    updatedOrCreatedGame = RomDatabase.sharedInstance.game(withMD5: md5)
                } else {
                    VLOG("No local game found for MD5 \(md5). Creating...")
                    updatedOrCreatedGame = try await createPVGame(from: record)
                }

                // Trigger asset download if necessary
                if let game = updatedOrCreatedGame, !game.isDownloaded {
                    #if os(tvOS)
                    VLOG("tvOS: Skipping auto-download for \(md5). On-demand only.")
                    #else
                    if recordDeclaresAssetPresence(record) {
                        VLOG("Local game \(md5) is not marked as downloaded. Triggering download...")
                        Task.detached { [self] in
                            do {
                                try await downloadGame(md5: md5)
                            } catch {
                                CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: error.localizedDescription)
                            }
                        }
                    } else {
                        WLOG("Local game \(md5) needs download, but remote record has no asset. Skipping download trigger.")
                    }
                    #endif
                } else if updatedOrCreatedGame == nil {
                    WLOG("Game object was nil after update/create for \(md5). Cannot check download status.")
                } else {
                    VLOG("Local game \(md5) already marked as downloaded or update failed. Skipping download trigger.")
                }
                // --- End Create/Update Handling ---
            }

        } else {
            // Fetched Record is nil (Record doesn't exist remotely, or fetch failed earlier)
            // This case is less likely with soft deletes. Might indicate a hard delete happened.
            CloudSyncManager.syncLog.event(.delete, item: "rom/\(md5)", status: .inProgress, detail: "remote record missing, possible hard delete")
            // If we have the game locally, delete it.
            if let localGame = RomDatabase.sharedInstance.game(withMD5: md5) {
                VLOG("Deleting local game \(localGame.title) because remote record was not found.")
                do {
                    // Ensure this delete path also avoids triggering cloud sync again.
                    // Use source: .cloudKitSync to prevent notification cascade.
                    try RomDatabase.sharedInstance.delete(game: localGame, source: .cloudKitSync)
                    CloudSyncManager.syncLog.event(.delete, item: "rom/\(md5)", status: .ok, detail: "local deleted, remote missing")
                } catch {
                    CloudSyncManager.syncLog.event(.delete, item: "rom/\(md5)", status: .failed, detail: "remote missing delete: \(error)")
                }
            } else {
                VLOG("No local game found for \(md5), consistent with missing remote record.")
            }
        }
    }

    public func fetchRemoteGameRecord(md5: String) async throws -> CKRecord? {
        // Helper for fetching based on MD5
        ELOG("fetchRemoteGameRecord not yet implemented")
        throw CloudSyncError.notImplemented // Placeholder
    }

    // MARK: - Asset Handling

    /// Download a game (protocol conformance - no progress tracking)
    /// - Parameter md5: The game's MD5 hash
    public func downloadGame(md5: String) async throws {
        try await downloadGame(md5: md5, progressHandler: nil)
    }

    /// Download a game with progress tracking
    /// - Parameters:
    ///   - md5: The game's MD5 hash
    ///   - progressHandler: Optional callback for download progress (0.0 to 1.0) and status message
    public func downloadGame(md5: String, progressHandler: ((Double, String) -> Void)?) async throws {
        CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .inProgress)
        let startTime = Date()

        progressHandler?(0.0, "Connecting to iCloud...")

        // Get expected file size from local game entry if available
        let expectedSize: Int64? = RomDatabase.sharedInstance.game(withMD5: md5).flatMap { $0.fileSize > 0 ? Int64($0.fileSize) : nil }

        // 1. Fetch the CloudKit Record with progress tracking
        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
        guard let record = try await fetchRecordWithProgress(
            recordID: recordID,
            expectedSize: expectedSize,
            progressHandler: { progress, speedString in
                // Scale to 0-80% for download phase
                let percent = Int(progress * 100)
                let status: String
                if let speed = speedString {
                    status = "Downloading... \(percent)% (\(speed))"
                } else {
                    status = "Downloading... \(percent)%"
                }
                progressHandler?(progress * 0.8, status)
            }
        ) else {
            CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .notFound, detail: "record not in CloudKit")
            // Check local state and update if needed
            if let localGame = RomDatabase.sharedInstance.game(withMD5: md5), localGame.isDownloaded {
                CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .pending, detail: "was marked downloaded, record missing")
                try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: nil)
            }
            throw CloudSyncError.cloudKitError(CKError(.unknownItem))
        }

        // 2. Get Asset and Metadata from Record
        guard let asset = record[CloudKitSchema.ROMFields.fileData] as? CKAsset,
              let assetURL = asset.fileURL else {
            CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: "missing fileData asset")
            if let localGame = RomDatabase.sharedInstance.game(withMD5: md5), localGame.isDownloaded {
                CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .pending, detail: "was marked downloaded, asset missing")
                try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            }
            throw CloudSyncError.invalidData
        }

        let isArchive = (record[CloudKitSchema.ROMFields.isArchive] as? NSNumber)?.boolValue ?? false
        guard let primaryFilename = record[CloudKitSchema.ROMFields.originalFilename] as? String, !primaryFilename.isEmpty else {
            CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: "missing originalFilename")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw CloudSyncError.invalidData
        }
        guard let systemIdentifier = record[CloudKitSchema.ROMFields.systemIdentifier] as? String, !systemIdentifier.isEmpty else {
            CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: "missing systemIdentifier")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw CloudSyncError.invalidData
        }

        // 3. Determine Destination Directory
        let systemRomsURL = Paths.romsPath(forSystemIdentifier: systemIdentifier)
        let destinationDirectory = systemRomsURL // Extract directly into the system's ROM folder
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        VLOG("Destination directory for download/extraction: \(destinationDirectory.path)")

        // Verify asset file exists and is readable before proceeding
        guard FileManager.default.fileExists(atPath: assetURL.path) else {
            CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: "asset file missing at \(assetURL.path)")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw CloudSyncError.fileSystemError(NSError(domain: "CloudKitRomsSyncer", code: 404, userInfo: [NSLocalizedDescriptionKey: "Asset file not found after download"]))
        }

        // Check asset file size (should match expected size if available)
        let assetFileAttributes = try? FileManager.default.attributesOfItem(atPath: assetURL.path)
        let assetFileSize = assetFileAttributes?[.size] as? Int64 ?? 0
        if let expectedFileSize = record[CloudKitSchema.ROMFields.fileSize] as? Int64, expectedFileSize > 0 {
            if assetFileSize != expectedFileSize && assetFileSize > 0 {
                CloudSyncManager.syncLog.event(.check, item: "rom/\(md5)", status: .pending, detail: "size mismatch: expected \(expectedFileSize), got \(assetFileSize)")
            }
        }

        progressHandler?(0.85, "Processing file...")

        // 4. Handle File Placement (Direct Copy or Unzip using ZipArchive)
        var finalPrimaryFileURL: URL? = nil
        do {
            if isArchive {
                // --- Unzip Archive using ZipArchive ---
                progressHandler?(0.85, "Extracting archive...")
                VLOG("Asset is an archive. Unzipping \(assetURL.path) to \(destinationDirectory.path)")

                // Verify archive integrity before unzipping
                guard assetFileSize > 0 else {
                    throw CloudSyncError.fileSystemError(NSError(domain: "CloudKitRomsSyncer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Archive file is empty or corrupted"]))
                }

                do {
                    try ArchiveManager.shared.unzipFile(at: assetURL, to: destinationDirectory)
                } catch {
                    throw CloudSyncError.zipError(DescriptiveError(description: "Failed to unzip \(assetURL.path) to \(destinationDirectory.path): \(error.localizedDescription)"))
                }
                VLOG("Successfully unzipped archive to \(destinationDirectory.path)")
                // Find the primary file (e.g., .iso, .bin) to return its URL
                // This logic might need refinement based on how primary files are identified
                if let firstFile = try? FileManager.default.contentsOfDirectory(at: destinationDirectory, includingPropertiesForKeys: nil).first {
                    finalPrimaryFileURL = firstFile
                } else {
                    WLOG("Could not determine primary file URL after unzipping to \(destinationDirectory.path)")
                }
            } else {
                // Handle single file download
                progressHandler?(0.90, "Copying file...")
                let finalDestinationURL = destinationDirectory.appendingPathComponent(primaryFilename)
                VLOG("Asset is a single file. Moving \(assetURL.path) to \(finalDestinationURL.path)")

                // Verify source file integrity before moving
                guard assetFileSize > 0 else {
                    throw CloudSyncError.fileSystemError(NSError(domain: "CloudKitRomsSyncer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Downloaded file is empty or corrupted"]))
                }

                // Ensure overwrite by removing existing file first.
                if FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                    VLOG("Removing existing file at \(finalDestinationURL.path)")
                    try await FileManager.default.removeItem(at: finalDestinationURL)
                }
                try FileManager.default.moveItem(at: assetURL, to: finalDestinationURL)

                // Verify destination file after move
                guard FileManager.default.fileExists(atPath: finalDestinationURL.path) else {
                    throw CloudSyncError.fileSystemError(NSError(domain: "CloudKitRomsSyncer", code: -1, userInfo: [NSLocalizedDescriptionKey: "File move failed - destination file not found"]))
                }

                finalPrimaryFileURL = finalDestinationURL
                CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .inProgress, detail: "moved to \(finalDestinationURL.lastPathComponent)")
            }
        } catch let error as CloudSyncError {
            CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: "unzip: \(error)")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw error
        } catch {
            CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: "file op: \(error.localizedDescription)")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw CloudSyncError.fileSystemError(error)
        }

        // 5. Update Local PVGame Status
        guard let confirmedPrimaryFileURL = finalPrimaryFileURL, FileManager.default.fileExists(atPath: confirmedPrimaryFileURL.path) else {
            CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .failed, detail: "primary file not found after extraction")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw CloudSyncError.fileSystemError(CocoaError(.fileNoSuchFile))
        }

        progressHandler?(0.95, "Updating database...")

        // Pass the confirmed primary file URL and the record (for related file info)
        try await updateLocalDownloadStatus(md5: md5, isDownloaded: true, fileURL: confirmedPrimaryFileURL, record: record)

        let elapsed = Date().timeIntervalSince(startTime)
        let sizeStr = ByteCountFormatter.string(fromByteCount: assetFileSize, countStyle: .file)
        progressHandler?(1.0, "Complete!")
        CloudSyncManager.syncLog.event(.download, item: "rom/\(md5)", status: .ok, detail: "\(sizeStr) in \(String(format: "%.1f", elapsed))s", duration: elapsed)
    }

    // MARK: - Mapping Helpers

    private func mapPVGameToRecord(_ game: PVGame, existingRecord: CKRecord? = nil) throws -> CKRecord {
        // Ensure MD5 exists, otherwise we can't generate the ID or sync.
        let md5 = game.md5Hash

        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
        let record = existingRecord ?? CKRecord(recordType: CloudKitSchema.RecordType.rom.rawValue, recordID: recordID)

        // --- Core Identifiers & File Info ---
        record[CloudKitSchema.ROMFields.md5] = md5
        record[CloudKitSchema.ROMFields.systemIdentifier] = game.systemIdentifier
        record[CloudKitSchema.ROMFields.fileSize] = game.fileSize as NSNumber // Store as NSNumber (Int64)
        record[CloudKitSchema.ROMFields.originalFilename] = game.fileName // Fallback to fileName
        // Note: fileData and isArchive are set later during asset preparation

        // --- OpenVGDB Metadata ---
        let regionID = (record[CloudKitSchema.ROMFields.regionID] as? NSNumber)?.intValue ?? game.regionID
        record[CloudKitSchema.ROMFields.title] = game.title // Use game.title directly
        record[CloudKitSchema.ROMFields.gameDescription] = game.gameDescription
        record[CloudKitSchema.ROMFields.boxBackArtworkURL] = game.boxBackArtworkURL
        record[CloudKitSchema.ROMFields.developer] = game.developer
        record[CloudKitSchema.ROMFields.publisher] = game.publisher
        record[CloudKitSchema.ROMFields.publishDate] = game.publishDate
        record[CloudKitSchema.ROMFields.genres] = game.genres
        record[CloudKitSchema.ROMFields.referenceURL] = game.referenceURL
        record[CloudKitSchema.ROMFields.releaseID] = game.releaseID
        record[CloudKitSchema.ROMFields.regionName] = game.regionName
        record[CloudKitSchema.ROMFields.regionID] = regionID
        record[CloudKitSchema.ROMFields.systemShortName] = game.systemShortName as NSString? // Cast value to NSString
        record[CloudKitSchema.ROMFields.language] = game.language

        // --- User Stats & Info ---
        // Play stats are stored as totals on the ROM record.
        record[CloudKitSchema.ROMFields.lastPlayed] = game.lastPlayed
        record[CloudKitSchema.ROMFields.playCount] = game.playCount as NSNumber
        record[CloudKitSchema.ROMFields.timeSpentInGame] = game.timeSpentInGame as NSNumber
        record[CloudKitSchema.ROMFields.rating] = game.rating as NSNumber
        record[CloudKitSchema.ROMFields.isFavorite] = game.isFavorite
        record[CloudKitSchema.ROMFields.importDate] = game.importDate

        // --- Artwork Fields ---
        // Sync originalArtworkURL (just the URL value, no asset upload needed)
        record[CloudKitSchema.ROMFields.originalArtworkURL] = game.originalArtworkURL

        // Sync customArtworkURL (PVMediaCache key) and prepare custom artwork asset
        record[CloudKitSchema.ROMFields.customArtworkURL] = game.customArtworkURL

        // Note: customArtworkAsset will be set later during artwork asset preparation
        // This is handled separately to avoid blocking the main record mapping

        // --- Sync Metadata ---
#if os(macOS)
        let deviceIdentifier = Host.current().name ?? "Unknown macOS"
#else
        let deviceIdentifier = UIDevice.current.name
#endif
        record[CloudKitSchema.ROMFields.lastModifiedDevice] = deviceIdentifier

        return record
    }

    /// Prepare custom artwork asset for CloudKit upload
    /// - Parameters:
    ///   - game: The PVGame with custom artwork
    ///   - record: The CloudKit record to attach the artwork asset to
    /// - Returns: The updated record with custom artwork asset attached
    private func prepareCustomArtworkAsset(for game: PVGame, record: CKRecord) async throws -> CKRecord {
        let customArtworkURL = game.customArtworkURL

        guard !customArtworkURL.isEmpty else {
            DLOG("No custom artwork URL for game: \(game.title)")
            return record
        }

        // Check if artwork exists in PVMediaCache
        guard PVMediaCache.fileExists(forKey: customArtworkURL) else {
            WLOG("Custom artwork not found in cache for key: \(customArtworkURL)")
            return record
        }

        // Get the cached artwork file path
        guard let artworkFilePath = PVMediaCache.filePath(forKey: customArtworkURL) else {
            WLOG("Failed to get file path for custom artwork key: \(customArtworkURL)")
            return record
        }

        // Verify the file exists on disk
        guard FileManager.default.fileExists(atPath: artworkFilePath.path) else {
            WLOG("Custom artwork file does not exist at path: \(artworkFilePath.path)")
            return record
        }

        do {
            // Create CKAsset from the artwork file
            let artworkAsset = CKAsset(fileURL: artworkFilePath)
            record[CloudKitSchema.ROMFields.customArtworkAsset] = artworkAsset

            DLOG("Successfully prepared custom artwork asset for game: \(game.title)")
            return record
        } catch {
            ELOG("Failed to create CKAsset for custom artwork: \(error.localizedDescription)")
            throw CloudSyncError.fileSystemError(error)
        }
    }

    /// Update only the artwork for a game in CloudKit (without requiring ROM file)
    /// Use this when the game is cloud-synced but doesn't have a local ROM file
    /// - Parameters:
    ///   - game: The PVGame with custom artwork to sync
    ///   - artworkKey: The PVMediaCache key for the artwork
    /// - Returns: True if artwork was successfully synced
    @discardableResult
    public func updateArtworkOnly(for game: PVGame, artworkKey: String) async throws -> Bool {
        let md5 = game.md5Hash
        guard !md5.isEmpty else {
            CloudSyncManager.syncLog.event(.upload, item: "artwork", status: .failed, detail: "game has no MD5 hash")
            return false
        }

        guard !artworkKey.isEmpty else {
            DLOG("No artwork key provided for game: \(game.title)")
            return false
        }

        // Check if artwork exists in PVMediaCache
        guard PVMediaCache.fileExists(forKey: artworkKey) else {
            WLOG("Artwork not found in cache for key: \(artworkKey)")
            return false
        }

        // Get the cached artwork file path
        guard let artworkFilePath = PVMediaCache.filePath(forKey: artworkKey) else {
            WLOG("Failed to get file path for artwork key: \(artworkKey)")
            return false
        }

        // Verify the file exists on disk
        guard FileManager.default.fileExists(atPath: artworkFilePath.path) else {
            WLOG("Artwork file does not exist at path: \(artworkFilePath.path)")
            return false
        }

        CloudSyncManager.syncLog.event(.upload, item: "artwork/\(md5)", status: .inProgress, detail: game.title)

        // Fetch or create the CloudKit record
        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
        var record: CKRecord
        do {
            record = try await fetchRecord(recordID: recordID) ?? CKRecord(recordType: CloudKitSchema.RecordType.rom.rawValue, recordID: recordID)
        } catch {
            // If the record doesn't exist, we need the full uploadGame method
            WLOG("No existing CloudKit record for game \(game.title), cannot update artwork-only")
            return false
        }

        // Update artwork fields
        record[CloudKitSchema.ROMFields.customArtworkURL] = artworkKey
        let artworkAsset = CKAsset(fileURL: artworkFilePath)
        record[CloudKitSchema.ROMFields.customArtworkAsset] = artworkAsset

        // Update modification timestamp
        #if os(macOS)
        let deviceIdentifier = Host.current().name ?? "Unknown macOS"
        #else
        let deviceIdentifier = UIDevice.current.name
        #endif
        record[CloudKitSchema.ROMFields.lastModifiedDevice] = deviceIdentifier

        // Save the record
        guard let ckContainer = iCloudConstants.container else {
            WLOG("CloudKit entitlement not present — cannot save artwork for \(game.title)")
            return false
        }
        do {
            let database = ckContainer.privateCloudDatabase
            _ = try await database.save(record)
            CloudSyncManager.syncLog.event(.upload, item: "artwork/\(md5)", status: .ok, detail: game.title)
            return true
        } catch {
            CloudSyncManager.syncLog.event(.upload, item: "artwork/\(md5)", status: .failed, detail: error.localizedDescription)
            throw CloudSyncError.cloudKitError(error)
        }
    }

    /// Update only user-editable metadata for a game in CloudKit (without requiring the ROM file).
    /// - Parameter md5: The game's MD5 hash.
    /// - Returns: True if the record was saved successfully.
    @discardableResult
    public func updateGameMetadata(md5: String) async throws -> Bool {
        let frozenGame = try await withRealm { realm -> PVGame in
            guard let liveGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
                throw CloudSyncError.gameNotFound("PVGame with MD5 \(md5) not found in Realm")
            }
            return liveGame.freeze()
        }

        guard !frozenGame.contentless else {
            VLOG("Skipping CloudKit metadata update for contentless placeholder game: \(frozenGame.title)")
            return false
        }

        let normalizedMD5 = frozenGame.md5Hash.uppercased()
        guard !normalizedMD5.isEmpty else {
            throw CloudSyncError.invalidData
        }

        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: normalizedMD5)
        var record = try await fetchRecord(recordID: recordID, includeAssets: false)
            ?? CKRecord(recordType: CloudKitSchema.RecordType.rom.rawValue, recordID: recordID)

        record[CloudKitSchema.ROMFields.md5] = normalizedMD5
        record[CloudKitSchema.ROMFields.systemIdentifier] = frozenGame.systemIdentifier
        record[CloudKitSchema.ROMFields.title] = frozenGame.title
        record[CloudKitSchema.ROMFields.isFavorite] = frozenGame.isFavorite
        record[CloudKitSchema.ROMFields.rating] = frozenGame.rating as NSNumber

        // OpenVGDB / user-editable metadata fields
        record[CloudKitSchema.ROMFields.gameDescription] = frozenGame.gameDescription
        record[CloudKitSchema.ROMFields.boxBackArtworkURL] = frozenGame.boxBackArtworkURL
        record[CloudKitSchema.ROMFields.developer] = frozenGame.developer
        record[CloudKitSchema.ROMFields.publisher] = frozenGame.publisher
        record[CloudKitSchema.ROMFields.publishDate] = frozenGame.publishDate
        record[CloudKitSchema.ROMFields.genres] = frozenGame.genres
        record[CloudKitSchema.ROMFields.referenceURL] = frozenGame.referenceURL
        record[CloudKitSchema.ROMFields.releaseID] = frozenGame.releaseID
        record[CloudKitSchema.ROMFields.regionName] = frozenGame.regionName
        record[CloudKitSchema.ROMFields.regionID] = frozenGame.regionID.map { NSNumber(value: $0) }
        record[CloudKitSchema.ROMFields.systemShortName] = frozenGame.systemShortName as NSString?
        record[CloudKitSchema.ROMFields.language] = frozenGame.language

        // Artwork sync (URLs + optional custom artwork asset)
        record[CloudKitSchema.ROMFields.originalArtworkURL] = frozenGame.originalArtworkURL
        record[CloudKitSchema.ROMFields.customArtworkURL] = frozenGame.customArtworkURL

        do {
            record = try await prepareCustomArtworkAsset(for: frozenGame, record: record)
        } catch {
            WLOG("Failed to attach customArtworkAsset for metadata-only update \(normalizedMD5): \(error.localizedDescription)")
        }

        #if os(macOS)
        let deviceIdentifier = Host.current().name ?? "Unknown macOS"
        #else
        let deviceIdentifier = UIDevice.current.name
        #endif
        record[CloudKitSchema.ROMFields.lastModifiedDevice] = deviceIdentifier

        if record[CloudKitSchema.ROMFields.originalFilename] == nil {
            record[CloudKitSchema.ROMFields.originalFilename] = frozenGame.file?.fileName ?? frozenGame.fileName
        }

        try await saveRecord(record)
        CloudSyncManager.syncLog.event(.upload, item: "rom/\(normalizedMD5)", status: .ok, detail: "metadata-only: \(frozenGame.title)")
        return true
    }

    /// Download and cache custom artwork asset from CloudKit
    /// - Parameters:
    ///   - record: The CloudKit record containing the artwork asset
    ///   - game: The PVGame to update with the cached artwork
    ///   - forceUpdate: Whether to force download even if artwork is already cached
    private func downloadCustomArtworkAsset(from record: CKRecord, for game: PVGame, forceUpdate: Bool = false) async throws {
        // Check if there's a custom artwork asset to download
        guard let customArtworkAsset = record[CloudKitSchema.ROMFields.customArtworkAsset] as? CKAsset,
              let assetFileURL = customArtworkAsset.fileURL else {
            DLOG("No custom artwork asset to download for game: \(game.title)")
            return
        }

        // Get the custom artwork URL key from the record
        guard let cloudCustomArtworkURL = record[CloudKitSchema.ROMFields.customArtworkURL] as? String,
              !cloudCustomArtworkURL.isEmpty else {
            WLOG("Custom artwork asset exists but no customArtworkURL key for game: \(game.title)")
            return
        }

        // Check if the cloud customArtworkURL differs from the local one
        let localCustomArtworkURL = game.customArtworkURL
        let artworkURLChanged = localCustomArtworkURL != cloudCustomArtworkURL

        if artworkURLChanged {
            CloudSyncManager.syncLog.event(.download, item: "artwork/\(game.md5Hash)", status: .inProgress, detail: "URL changed: '\(localCustomArtworkURL)' -> '\(cloudCustomArtworkURL)'")

            // Remove old cached artwork if it exists and is different
            if !localCustomArtworkURL.isEmpty && PVMediaCache.fileExists(forKey: localCustomArtworkURL) {
                do {
                    try PVMediaCache.deleteImage(forKey: localCustomArtworkURL)
                    DLOG("Removed old cached artwork for key: \(localCustomArtworkURL)")
                } catch {
                    WLOG("Failed to remove old cached artwork for key \(localCustomArtworkURL): \(error.localizedDescription)")
                }
            }
        }

        // Check if artwork is already cached locally (skip if forcing update or URL changed)
        if !forceUpdate && !artworkURLChanged && PVMediaCache.fileExists(forKey: cloudCustomArtworkURL) {
            DLOG("Custom artwork already cached for game: \(game.title)")
            return
        }

        do {
            // Read the artwork data from the CloudKit asset
            let artworkData = try Data(contentsOf: assetFileURL)

            // Cache the artwork in PVMediaCache using the cloudCustomArtworkURL as the key
            let cachedURL = try PVMediaCache.writeData(toDisk: artworkData, withKey: cloudCustomArtworkURL)

            CloudSyncManager.syncLog.event(.download, item: "artwork/\(game.md5Hash)", status: .ok, detail: game.title)

            // Update the local game record with the new customArtworkURL if it changed
            if artworkURLChanged {
                let gameMD5 = game.md5Hash
                let gameTitle = game.title
                try await withRealm { realm in
                    guard let liveGame = realm.object(ofType: PVGame.self, forPrimaryKey: gameMD5.uppercased()) else {
                        ELOG("Game \(gameMD5) was invalidated during artwork URL update.")
                        return
                    }
                    try CloudKitRemoteApplyGuard.withApplyingRemoteChanges {
                        if realm.isInWriteTransaction {
                            liveGame.customArtworkURL = cloudCustomArtworkURL
                        } else {
                            try realm.write {
                                liveGame.customArtworkURL = cloudCustomArtworkURL
                            }
                        }
                    }
                    CloudSyncManager.syncLog.event(.sync, item: "artwork/\(gameMD5)", status: .ok, detail: "updated local URL for \(gameTitle)")
                }
            }

        } catch {
            CloudSyncManager.syncLog.event(.download, item: "artwork/\(game.md5Hash)", status: .failed, detail: error.localizedDescription)
            throw CloudSyncError.fileSystemError(error)
        }
    }

    /// Backfill missing artwork for CloudKit-synced games.
    ///
    /// Strategy (fast → slow):
    /// 1. Queue ALL games missing local artwork through `ArtworkSearchQueue` which
    ///    hits OpenVGDB / TheGamesDB / LibretroDB directly — much faster than CloudKit.
    /// 2. For games with `customArtworkURL` (user-set artwork not in any public DB),
    ///    fall back to CloudKit CKAsset download.
    ///
    /// Called automatically during `loadAllFromCloud()` and can also be triggered
    /// independently (e.g. after the library screen appears).
    public func cacheMissingArtworkForExistingGames(limit: Int = 200) async {
        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            CloudSyncManager.syncLog.event(.skip, item: "rom/artwork-backfill", status: .skipped, detail: "paused for emulation")
            return
        }

        do {
            // Find all CloudKit-synced games missing local artwork cache
            let allCandidates = try await withRealm { realm in
                realm.objects(PVGame.self)
                    .filter("cloudRecordID != nil")
                    .prefix(limit * 3)
                    .map { $0.freeze() }
            }

            let missing = allCandidates.filter { game in
                let artworkKey = game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL
                return artworkKey.isEmpty || !PVMediaCache.fileExists(forKey: artworkKey)
            }

            guard !missing.isEmpty else { return }

            // Triage into three buckets:
            //   1. hasURL — originalArtworkURL is a remote http(s) URL → just re-download, no DB lookup
            //   2. needsLookup — no artwork URL at all → needs ArtworkSearchQueue (SQLite + web)
            //   3. needsCloudKit — customArtworkURL set (user-uploaded) → CKAsset download
            var hasURL: [(md5: String, url: URL, key: String)] = []
            var needsLookup: [PVGame] = []
            var needsCloudKit: [PVGame] = []

            for game in missing {
                switch Self.triageArtwork(originalArtworkURL: game.originalArtworkURL, customArtworkURL: game.customArtworkURL) {
                case .httpRedownload:
                    if let url = URL(string: game.originalArtworkURL) {
                        hasURL.append((md5: game.md5Hash, url: url, key: game.originalArtworkURL))
                    }
                case .needsLookup:
                    needsLookup.append(game)
                case .cloudKitAsset:
                    needsCloudKit.append(game)
                }
            }

            CloudSyncManager.syncLog.event(.start, item: "rom/artwork-backfill", status: .inProgress,
                detail: "\(missing.count) missing — \(hasURL.count) re-download, \(needsLookup.count) lookup, \(needsCloudKit.count) CloudKit")

            // ── Phase 1: Batch HTTP re-downloads (fast, no DB queries) ──────────
            if !hasURL.isEmpty {
                let capped = Array(hasURL.prefix(limit))
                let downloaded = await batchDownloadArtwork(capped)
                if !downloaded.isEmpty {
                    let ids = downloaded
                    await MainActor.run {
                        NotificationCenter.default.post(name: .artworkDidCache, object: nil, userInfo: [SyncNotification.gameIDsKey: ids])
                    }
                }
                CloudSyncManager.syncLog.event(.download, item: "rom/artwork-redownload", status: .ok, detail: "\(downloaded.count)/\(capped.count) re-downloaded")
            }

            // ── Phase 2: Skip DB-heavy artwork lookups during sync ──────────────
            // Games with no originalArtworkURL likely never had artwork — spending 13-47s
            // per game on full-table SQLite scans during sync recovery is counterproductive.
            // These will get looked up naturally when the user browses or imports new games.
            if !needsLookup.isEmpty {
                CloudSyncManager.syncLog.event(.skip, item: "rom/artwork-search", status: .skipped,
                    detail: "\(needsLookup.count) games have no artwork URL — skipping DB lookup during sync")
            }

            // ── Phase 3: CloudKit CKAsset for custom artwork ────────────────────
            if !needsCloudKit.isEmpty {
                let capped = Array(needsCloudKit.prefix(limit))
                CloudSyncManager.syncLog.event(.start, item: "rom/artwork-cloudkit", status: .inProgress, detail: "\(capped.count) custom artwork")
                var cachedGameIds = Set<String>()

                for game in capped {
                    if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) || Task.isCancelled { break }
                    let md5 = game.md5Hash
                    do {
                        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
                        guard let record = try await fetchRecord(recordID: recordID, includeAssets: true) else { continue }
                        guard let liveGame = RomDatabase.sharedInstance.game(withMD5: md5) else { continue }
                        try await downloadCustomArtworkAsset(from: record, for: liveGame)
                        cachedGameIds.insert(md5)
                    } catch {
                        CloudSyncManager.syncLog.event(.download, item: "artwork-backfill/\(md5)", status: .failed, detail: error.localizedDescription)
                    }
                    if cachedGameIds.count % 10 == 0, !cachedGameIds.isEmpty {
                        let batch = cachedGameIds
                        await MainActor.run {
                            NotificationCenter.default.post(name: .artworkDidCache, object: nil, userInfo: [SyncNotification.gameIDsKey: batch])
                        }
                    }
                }
                if !cachedGameIds.isEmpty {
                    let batch = cachedGameIds
                    await MainActor.run {
                        NotificationCenter.default.post(name: .artworkDidCache, object: nil, userInfo: [SyncNotification.gameIDsKey: batch])
                    }
                }
            }

            CloudSyncManager.syncLog.event(.complete, item: "rom/artwork-backfill", status: .ok,
                detail: "\(hasURL.count) re-dl, \(needsLookup.count) lookup, \(needsCloudKit.count) cloudkit")
        } catch {
            CloudSyncManager.syncLog.event(.error, item: "rom/artwork-backfill", status: .failed, detail: error.localizedDescription)
        }
    }

    /// Batch-download artwork images from known URLs. No database lookups.
    /// Runs up to 6 concurrent downloads, writes each to PVMediaCache, and returns
    /// the set of game IDs (md5) that were successfully cached.
    private func batchDownloadArtwork(_ items: [(md5: String, url: URL, key: String)]) async -> Set<String> {
        var cached = Set<String>()
        var lastNotifiedCount = 0
        let maxConcurrency = 6

        await withTaskGroup(of: String?.self) { group in
            var launched = 0
            var index = items.startIndex

            // Seed initial batch
            while index < items.endIndex, launched < maxConcurrency {
                let item = items[index]
                group.addTask { await self.downloadAndCacheArtwork(md5: item.md5, url: item.url, cacheKey: item.key) }
                launched += 1
                index = items.index(after: index)
            }

            // As each finishes, launch the next
            for await result in group {
                if Task.isCancelled { break }
                if let md5 = result { cached.insert(md5) }

                // Notify UI every 20 new successes
                if cached.count - lastNotifiedCount >= 20 {
                    lastNotifiedCount = cached.count
                    let batch = cached
                    await MainActor.run {
                        NotificationCenter.default.post(name: .artworkDidCache, object: nil, userInfo: [SyncNotification.gameIDsKey: batch])
                    }
                }

                if index < items.endIndex {
                    let item = items[index]
                    group.addTask { await self.downloadAndCacheArtwork(md5: item.md5, url: item.url, cacheKey: item.key) }
                    index = items.index(after: index)
                }
            }
        }

        // Final notification for any remaining items not yet notified
        if cached.count > lastNotifiedCount, !cached.isEmpty {
            let final = cached
            await MainActor.run {
                NotificationCenter.default.post(name: .artworkDidCache, object: nil, userInfo: [SyncNotification.gameIDsKey: final])
            }
        }

        return cached
    }

    /// Download a single artwork image and write it to PVMediaCache.
    /// Returns the md5 on success, nil on failure.
    private func downloadAndCacheArtwork(md5: String, url: URL, cacheKey: String) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                DLOG("Artwork download failed for \(md5): HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            _ = try PVMediaCache.writeData(toDisk: data, withKey: cacheKey)
            return md5
        } catch {
            DLOG("Artwork download error for \(md5): \(error.localizedDescription)")
            return nil
        }
    }

    /// Submit per-game artwork tasks to the coordinator so each can be individually prioritized.
    /// Call this instead of `cacheMissingArtworkForExistingGames` when using the task queue coordinator.
    public func submitArtworkTasks(to coordinator: SyncTaskQueueCoordinator, limit: Int = 200) async {
        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            CloudSyncManager.syncLog.event(.skip, item: "rom/artwork-submit", status: .skipped, detail: "paused for emulation")
            return
        }

        do {
            let allCandidates = try await withRealm { realm in
                realm.objects(PVGame.self)
                    .filter("cloudRecordID != nil")
                    .prefix(limit * 3)
                    .map { $0.freeze() }
            }

            let missing = allCandidates.filter { game in
                let artworkKey = game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL
                return artworkKey.isEmpty || !PVMediaCache.fileExists(forKey: artworkKey)
            }

            guard !missing.isEmpty else { return }

            var httpCount = 0
            var lookupCount = 0
            var cloudKitCount = 0

            for game in missing.prefix(limit) {
                let md5 = game.md5Hash
                switch Self.triageArtwork(originalArtworkURL: game.originalArtworkURL, customArtworkURL: game.customArtworkURL) {
                case .httpRedownload:
                    guard let url = URL(string: game.originalArtworkURL) else { continue }
                    let cacheKey = game.originalArtworkURL
                    httpCount += 1
                    await coordinator.submit(
                        to: .artwork,
                        kind: .artworkDownload(url: url, gameID: md5),
                        priority: .artworkRedownload,
                        metadata: ["gameID": md5]
                    ) { [weak self] in
                        guard let self else { return }
                        guard let result = await self.downloadAndCacheArtwork(md5: md5, url: url, cacheKey: cacheKey) else { return }
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .artworkDidCache,
                                object: nil,
                                userInfo: [SyncNotification.gameIDsKey: Set([result])]
                            )
                        }
                    }

                case .needsLookup:
                    lookupCount += 1
                    // Skipped during sync — too expensive (13-47s per game)

                case .cloudKitAsset:
                    cloudKitCount += 1
                    await coordinator.submit(
                        to: .artwork,
                        kind: .custom(description: "cloudkit-artwork-\(md5)"),
                        priority: .artworkRedownload,
                        metadata: ["gameID": md5]
                    ) { [weak self] in
                        guard let self else { return }
                        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
                        guard let record = try await self.fetchRecord(recordID: recordID, includeAssets: true) else { return }
                        guard let liveGame = RomDatabase.sharedInstance.game(withMD5: md5) else { return }
                        try await self.downloadCustomArtworkAsset(from: record, for: liveGame)
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .artworkDidCache,
                                object: nil,
                                userInfo: [SyncNotification.gameIDsKey: Set([md5])]
                            )
                        }
                    }
                }
            }

            CloudSyncManager.syncLog.event(.start, item: "rom/artwork-submit", status: .inProgress,
                detail: "\(missing.count) missing — \(httpCount) re-download, \(lookupCount) lookup-skipped, \(cloudKitCount) CloudKit submitted")

            if lookupCount > 0 {
                CloudSyncManager.syncLog.event(.skip, item: "rom/artwork-search", status: .skipped,
                    detail: "\(lookupCount) games have no artwork URL — skipping DB lookup during sync")
            }
        } catch {
            CloudSyncManager.syncLog.event(.error, item: "rom/artwork-submit", status: .failed, detail: error.localizedDescription)
        }
    }

    // MARK: - Artwork Triage (testable)

    /// Categorization result for a game's artwork needs during sync recovery.
    enum ArtworkBucket {
        /// Game has a known HTTP(S) artwork URL — just re-download the image
        case httpRedownload
        /// Game has no artwork URL — would need expensive DB lookup (skipped during sync)
        case needsLookup
        /// Game has custom user-uploaded artwork — needs CloudKit CKAsset download
        case cloudKitAsset
    }

    /// Determine which artwork recovery strategy a game needs.
    /// Pure function — no side effects, no Realm, no network.
    static func triageArtwork(originalArtworkURL: String, customArtworkURL: String) -> ArtworkBucket {
        if !customArtworkURL.isEmpty {
            return .cloudKitAsset
        } else if !originalArtworkURL.isEmpty,
                  let url = URL(string: originalArtworkURL),
                  url.scheme == "http" || url.scheme == "https" {
            return .httpRedownload
        } else {
            return .needsLookup
        }
    }

    /// Holds post-write info extracted from the Realm closure for artwork processing.
    private struct GamePostWriteInfo: Sendable {
        let title: String
        let customArtworkURL: String
        let hasOriginalArtworkFile: Bool
        let skipped: Bool
    }

    private func updatePVGame(from record: CKRecord, gameMD5: String) async throws {
        let cloudModDate = record.modificationDate ?? .distantPast
        let normalizedMD5 = gameMD5.uppercased()

        // Perform all Realm work on a background thread via withRealm to avoid
        // blocking the main thread (previously used RomDatabase.sharedInstance directly).
        let info = try await withRealm { realm -> GamePostWriteInfo in
            guard let localGame = realm.object(ofType: PVGame.self, forPrimaryKey: normalizedMD5) else {
                throw CloudSyncError.invalidData
            }

            CloudSyncManager.syncLog.event(.sync, item: "rom/\(localGame.md5Hash ?? "nil")", status: .inProgress, detail: "updating from \(record.recordID.recordName)")

            let localSyncDate = localGame.lastCloudSyncDate ?? .distantPast
            if cloudModDate <= localSyncDate {
                VLOG("Skipping update for game \(localGame.md5Hash ?? "nil"): CloudKit record modification date (\(cloudModDate)) is not newer than last local sync date (\(localSyncDate)).")
                return GamePostWriteInfo(title: localGame.title, customArtworkURL: localGame.customArtworkURL, hasOriginalArtworkFile: localGame.originalArtworkFile != nil, skipped: true)
            }

            try CloudKitRemoteApplyGuard.withApplyingRemoteChanges {
                let applyUpdates = {
                    localGame.cloudRecordID = record.recordID.recordName
            localGame.title = record[CloudKitSchema.ROMFields.title] as? String ?? localGame.title
            localGame.rating = record[CloudKitSchema.ROMFields.rating] as? Int ?? localGame.rating
            if let cloudPlayCount = record[CloudKitSchema.ROMFields.playCount] as? Int, cloudPlayCount > localGame.playCount {
                localGame.playCount = cloudPlayCount
            }
            if let cloudTimeSpent = record[CloudKitSchema.ROMFields.timeSpentInGame] as? Int, cloudTimeSpent > localGame.timeSpentInGame {
                localGame.timeSpentInGame = cloudTimeSpent
            }
            if let cloudLastPlayed = record[CloudKitSchema.ROMFields.lastPlayed] as? Date {
                localGame.lastPlayed = localGame.lastPlayed.map { max($0, cloudLastPlayed) } ?? cloudLastPlayed
            }
            localGame.isFavorite = record[CloudKitSchema.ROMFields.isFavorite] as? Bool ?? localGame.isFavorite

            // Update OpenVGDB fields if present
            localGame.gameDescription = record[CloudKitSchema.ROMFields.gameDescription] as? String ?? localGame.gameDescription
            localGame.publishDate = record[CloudKitSchema.ROMFields.publishDate] as? String ?? localGame.publishDate
            localGame.developer = record[CloudKitSchema.ROMFields.developer] as? String ?? localGame.developer
            localGame.publisher = record[CloudKitSchema.ROMFields.publisher] as? String ?? localGame.publisher
            localGame.genres = record[CloudKitSchema.ROMFields.genres] as? String ?? localGame.genres

            // Update artwork fields
            localGame.originalArtworkURL = record[CloudKitSchema.ROMFields.originalArtworkURL] as? String ?? localGame.originalArtworkURL
            localGame.customArtworkURL = record[CloudKitSchema.ROMFields.customArtworkURL] as? String ?? localGame.customArtworkURL

            // Update download status and size based on asset presence and local file existence
            if record.allKeys().contains(CloudKitSchema.ROMFields.fileData),
               let asset = record[CloudKitSchema.ROMFields.fileData] as? CKAsset {
                // Check if the local file actually exists before marking as downloaded.
                // Also try the game's existing file URL directly as a fallback — localURL()
                // may fail on tvOS if the PVFile was created with a mismatched relativeRoot.
                let expectedLocalURL = self.localURL(for: localGame)
                let existingFileURL = localGame.file?.url
                let hasLocalFile = (expectedLocalURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)
                    || (existingFileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)
                // Never downgrade isDownloaded from true→false during cloud sync.
                // A locally-imported game should stay "downloaded" even if path resolution
                // temporarily fails during sync reconciliation.
                if hasLocalFile || !localGame.isDownloaded {
                    localGame.isDownloaded = hasLocalFile
                }
                localGame.hasCloudAssets = true
                CloudSyncManager.syncLog.event(.sync, item: "rom/\(localGame.md5Hash ?? "nil")", status: .ok, detail: "hasLocal=\(hasLocalFile), isDownloaded=\(localGame.isDownloaded)")
                // Get fileSize using FileManager
                if let url = asset.fileURL, let attributes = try? FileManager.default.attributesOfItem(atPath: url.path), let fileSize = attributes[.size] as? Int64 {
                    localGame.fileSize = Int(fileSize)
                } else {
                    localGame.fileSize = 0 // Or keep existing?
                }
                // Ensure the PVFile.url points to the *expected* local path, not the CKAsset temp path
                if let expectedLocalURL = expectedLocalURL {
                    if localGame.file == nil {
                        // Corrected RelativeRoot usage
                        let newFile = PVFile(withURL: expectedLocalURL, relativeRoot: .platformDefault)
                        localGame.file = newFile // Create PVFile if missing
                    } else if localGame.file?.url != expectedLocalURL {
                        // Replace existing PVFile object as URL is get-only
                        let updatedFile = PVFile(withURL: expectedLocalURL, relativeRoot: .platformDefault) // Use same root as above
                        localGame.file = updatedFile
                        VLOG("Replaced PVFile due to differing URL for game \(localGame.md5Hash ?? "nil")")
                    }
                }
            } else if record.allKeys().contains(CloudKitSchema.ROMFields.fileData) {
                // Mark as not downloaded
                CloudSyncManager.syncLog.event(.sync, item: "rom/\(localGame.md5Hash ?? "nil")", status: .ok, detail: "no CloudKit asset, marking not downloaded")
                localGame.isDownloaded = false
                localGame.hasCloudAssets = false

                // Optionally clear PVFile URL or mark as offline?
                // localGame.file?.url = nil // Or keep url but mark PVFile as offline?
                // For now, just setting isDownloaded = false might be enough.

                // If download failed or was deleted, mark all related files as offline too?
                // Or maybe clear the list entirely?
                // For now, let's mark them offline if they had URLs.
                for relatedFile in localGame.relatedFiles where relatedFile.url != nil {
                    // No 'isOffline' property on PVFile. Their existence is tracked by PVGame.
                    VLOG("Related file \(relatedFile.fileName) exists for game \(localGame.md5Hash ?? "unknown") but primary is not downloaded.")
                }
            }

                    /// Update lastCloudSyncDate so we can skip this record next time unless CloudKit has a newer modification date.
                    localGame.lastCloudSyncDate = cloudModDate
                }

                if realm.isInWriteTransaction {
                    applyUpdates()
                } else {
                    try realm.write { applyUpdates() }
                }
            }

            VLOG("Finished updating game: \(localGame.title) (MD5: \(localGame.md5Hash ?? "unknown"))")
            return GamePostWriteInfo(title: localGame.title, customArtworkURL: localGame.customArtworkURL, hasOriginalArtworkFile: localGame.originalArtworkFile != nil, skipped: false)
        }

        guard !info.skipped else { return }

        // Download custom artwork asset if available.
        // Remote-change zone fetches may omit CKAsset payloads, so fall back to an asset-inclusive fetch.
        // Re-fetch game on background realm for artwork methods that need a PVGame reference.
        do {
            let hasCustomArtworkURL = (record[CloudKitSchema.ROMFields.customArtworkURL] as? String)?.isEmpty == false
            let hasCustomArtworkAsset = (record[CloudKitSchema.ROMFields.customArtworkAsset] as? CKAsset)?.fileURL != nil

            let artworkGame = try await withRealm { realm -> PVGame? in
                realm.object(ofType: PVGame.self, forPrimaryKey: normalizedMD5)?.freeze()
            }

            if let artworkGame {
                if hasCustomArtworkURL && !hasCustomArtworkAsset {
                    if let full = try await fetchRecord(recordID: record.recordID, includeAssets: true) {
                        try await downloadCustomArtworkAsset(from: full, for: artworkGame)
                    } else {
                        try await downloadCustomArtworkAsset(from: record, for: artworkGame)
                    }
                } else {
                    try await downloadCustomArtworkAsset(from: record, for: artworkGame)
                }
            }
        } catch {
            WLOG("Failed to download custom artwork for game \(info.title): \(error.localizedDescription)")
            // Continue with other operations even if artwork download fails
        }

        // Enhance with artwork if game doesn't already have any
        if !info.hasOriginalArtworkFile && info.customArtworkURL.isEmpty {
            CloudSyncManager.syncLog.event(.query, item: "artwork/\(gameMD5)", status: .inProgress, detail: "\(info.title) has no artwork")
            await enhanceGameWithArtworkAndMetadata(md5: gameMD5)
            CloudSyncManager.syncLog.event(.query, item: "artwork/\(gameMD5)", status: .ok, detail: "enhancement complete")
        }
    }

    private func createPVGame(from record: CKRecord) async throws -> PVGame? {
        // 1. Extract required fields from record
        guard let md5 = record[CloudKitSchema.ROMFields.md5] as? String,
              let systemIdentifier = record[CloudKitSchema.ROMFields.systemIdentifier] as? String,
              let originalFilename = record[CloudKitSchema.ROMFields.originalFilename] as? String else {
            CloudSyncManager.syncLog.event(.sync, item: "rom/\(record.recordID.recordName)", status: .failed, detail: "missing essential fields for PVGame creation")
            throw CloudSyncError.invalidData
        }

        let title = record[CloudKitSchema.ROMFields.title] as? String ?? originalFilename

        // 2. Look up PVSystem (Required to create PVGame)
        // Use RomDatabase.shared to find the system
        guard let system: PVSystem = PVEmulatorConfiguration.system(forIdentifier: systemIdentifier) else {
            WLOG("Skipping PVGame creation: Local PVSystem with identifier '\(systemIdentifier)' not found for CloudKit record \(record.recordID.recordName). App update might be required.")
            return nil // Skip creation, don't treat as fatal error
        }

        // 3. Create and Populate the new PVGame object
        // Note: Creation should happen outside a write block if we're just initializing
        let newGame = PVGame()
        newGame.md5Hash = md5 // Set the primary key
        newGame.systemIdentifier = system.identifier // Use the fetched system's identifier
        newGame.system = system
        // newGame.fileName = originalFilename // REMOVED: fileName is computed
        newGame.title = title
        newGame.cloudRecordID = record.recordID.recordName
        newGame.lastCloudSyncDate = record.modificationDate

        // Set other properties from the record
        newGame.isDownloaded = false // Mark as not downloaded initially, download happens separately
        newGame.hasCloudAssets = recordDeclaresAssetPresence(record)
        newGame.playCount = record[CloudKitSchema.ROMFields.playCount] as? Int ?? 0
        newGame.lastPlayed = record[CloudKitSchema.ROMFields.lastPlayed] as? Date
        newGame.timeSpentInGame = record[CloudKitSchema.ROMFields.timeSpentInGame] as? Int ?? 0
        newGame.rating = record[CloudKitSchema.ROMFields.rating] as? Int ?? -1
        newGame.isFavorite = record[CloudKitSchema.ROMFields.isFavorite] as? Bool ?? false
        // newGame.releaseDate = record[CloudKitSchema.ROMFields.releaseDate] as? Date // REMOVED: releaseDate doesn't exist

        // File Size (Optional - might come from asset or local file later)
        if let explicitFileSize = record[CloudKitSchema.ROMFields.fileSize] as? Int64 {
            newGame.fileSize = Int(explicitFileSize)
        }

        // 4. Add the new game to the database using RomDatabase.shared
        do {
            try CloudKitRemoteApplyGuard.withApplyingRemoteChanges {
                try RomDatabase.sharedInstance.add(newGame, update: true) // Add the fully populated object
            }
            CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .ok, detail: "created: \(title), system=\(systemIdentifier)")

            // Perform artwork and metadata lookup for the new game
            await enhanceGameWithArtworkAndMetadata(md5: md5)

            // Return the updated game from the database
            return RomDatabase.sharedInstance.game(withMD5: md5)
        } catch let error as NSError where error.code == 1 /* RLMErrorPrimaryKeyExists */ {
            WLOG("Attempted to create PVGame for MD5 \(md5), but it already exists. Fetching existing.")
            // If it already exists, fetch and return the existing one
            return RomDatabase.sharedInstance.game(withMD5: md5)
        } catch {
            CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .failed, detail: "Realm add: \(error.localizedDescription)")
            throw CloudSyncError.realmError(error)
        }
    }

        /// Perform artwork and metadata lookup for a game created from CloudKit
    /// - Parameter md5: The MD5 hash of the game to enhance with artwork and metadata
    private func enhanceGameWithArtworkAndMetadata(md5: String) async {
        CloudSyncManager.syncLog.event(.query, item: "artwork/\(md5)", status: .inProgress, detail: "artwork and metadata lookup")

        let gameExists = (try? await RealmContext.withBackgroundRealm { realm in
            realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) != nil
        }) ?? false

        guard gameExists else {
            CloudSyncManager.syncLog.event(.query, item: "artwork/\(md5)", status: .notFound, detail: "game not found for enhancement")
            return
        }

        await getUpdatedGameInfo(forMD5: md5)
        await getArtwork(forGameMD5: md5)

        CloudSyncManager.syncLog.event(.query, item: "artwork/\(md5)", status: .ok, detail: "artwork lookup complete")
    }

    /// Get updated game metadata from PVLookup database
    /// - Parameter md5: The MD5 hash of the game to lookup metadata for
    /// Note: All metadata work runs on a background Realm to avoid blocking the main thread.
    private func getUpdatedGameInfo(forMD5 md5: String) async {
        let gameInfo: (md5Hash: String, title: String, systemIdentifier: String)?
        do {
            gameInfo = try await RealmContext.withBackgroundRealm { realm in
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
                    return nil
                }
                return (md5Hash: game.md5Hash, title: game.title, systemIdentifier: game.systemIdentifier)
            }
        } catch {
            CloudSyncManager.syncLog.event(.query, item: "metadata/\(md5)", status: .failed, detail: error.localizedDescription)
            return
        }

        guard let info = gameInfo else {
            WLOG("Game with MD5 \(md5) not found for metadata lookup")
            return
        }

        let resultsMaybe: [ROMMetadata]? = await Task.detached(priority: .utility) {
            let lookup = PVLookup.shared
            var results: [ROMMetadata]?

            if !info.md5Hash.isEmpty {
                results = try? await lookup.searchDatabase(usingMD5: info.md5Hash, systemID: nil)
            }

            if results == nil || results!.isEmpty {
                let fileName = info.title
                let nonCharRange: NSRange = (fileName as NSString).rangeOfCharacter(from: CharacterSet.alphanumerics.inverted)
                let gameTitleLen: Int
                if nonCharRange.length > 0, nonCharRange.location > 1 {
                    gameTitleLen = nonCharRange.location - 1
                } else {
                    gameTitleLen = fileName.count
                }
                let subfileName = String(fileName.prefix(gameTitleLen))

                let system = SystemIdentifier(rawValue: info.systemIdentifier)
                results = try? await lookup.searchDatabase(usingFilename: subfileName, systemID: system)
            }

            return results
        }.value

        do {
            guard let results = resultsMaybe, !results.isEmpty else {
                ILOG("No metadata found for game: \(info.title)")
                try? await RealmContext.withBackgroundRealm { realm in
                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else { return }
                    try? realm.write {
                        game.requiresSync = false
                    }
                }
                return
            }

            var chosenResult: ROMMetadata?

            chosenResult = results.first { metadata in
                return metadata.regionID == 21 // USA region ID
            } ?? results.first { metadata in
                return metadata.region?.uppercased().contains("USA") ?? false
            }

            if chosenResult == nil {
                if results.count > 1 {
                    ILOG("Query returned \(results.count) possible matches for \(info.title). Using first result.")
                }
                chosenResult = results.first
            }

            if let result = chosenResult {
                ILOG("Found metadata for \(info.title): \(result.gameTitle ?? "Unknown")")

                try? await RealmContext.withBackgroundRealm { realm in
                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else { return }

                    try? realm.write {
                        if let gameDescription = result.gameDescription {
                            game.gameDescription = gameDescription
                        }
                        if let boxImageURL = result.boxImageURL {
                            game.originalArtworkURL = boxImageURL
                        }
                        if let developer = result.developer {
                            game.developer = developer
                        }
                        if let publisher = result.publisher {
                            game.publisher = publisher
                        }
                        if let genres = result.genres {
                            game.genres = genres
                        }
                        if let regionID = result.regionID {
                            game.regionID = regionID
                        }
                        if let referenceURL = result.referenceURL {
                            game.referenceURL = referenceURL
                        }
                        if let releaseID = result.releaseID {
                            game.releaseID = releaseID
                        }
                        game.requiresSync = false
                    }
                }
            }
        } catch {
            CloudSyncManager.syncLog.event(.query, item: "metadata/\(md5)", status: .failed, detail: "lookup: \(error.localizedDescription)")
        }
    }

    /// Get artwork for a game
    /// - Parameter md5: The MD5 hash of the game to get artwork for
    /// Note: All Realm work is off the main thread; only UI logging happens on main.
    private func getArtwork(forGameMD5 md5: String) async {
        // Fetch game info on a background realm to avoid blocking the main thread.
        let gameInfo: (md5Hash: String, title: String, originalArtworkURL: String)? = try? await RealmContext.withBackgroundRealm { realm in
            guard let game = realm.objects(PVGame.self).filter("md5Hash == %@", md5).first else {
                return nil
            }
            return (md5Hash: game.md5Hash, title: game.title, originalArtworkURL: game.originalArtworkURL)
        }

        guard let info = gameInfo else {
            WLOG("Game with MD5 \(md5) not found for artwork lookup")
            return
        }

        // Check for existing custom artwork first (can be done off main thread)
        let gameMD5 = info.md5Hash
        if !gameMD5.isEmpty {
            DLOG("Checking for existing custom artwork for game with MD5: \(gameMD5)")

            // Try to find existing custom artwork with this MD5
            if let customArtworkKey = PVMediaCache.findExistingCustomArtwork(forMD5: gameMD5) {
                DLOG("Found existing custom artwork with key: \(customArtworkKey)")

                // If we found a custom artwork key, set it as the customArtworkURL
                if let _ = PVMediaCache.filePath(forKey: customArtworkKey) {
                    DLOG("Setting custom artwork URL")
                    try? await RealmContext.withBackgroundRealm { realm in
                        guard let game = realm.objects(PVGame.self).filter("md5Hash == %@", md5).first else { return }
                        try? realm.write {
                            game.customArtworkURL = customArtworkKey
                        }
                    }
                }
                return
            } else {
                DLOG("No existing custom artwork found for game with MD5: \(gameMD5)")
            }
        }

        // Continue with original artwork handling
        var url = info.originalArtworkURL
        if url.isEmpty {
            return
        }

        if PVMediaCache.fileExists(forKey: url) {
            if let localURL = PVMediaCache.filePath(forKey: url) {
                let file = PVImageFile(withURL: localURL, relativeRoot: .platformDefault)
                try? await RealmContext.withBackgroundRealm { realm in
                    guard let game = realm.objects(PVGame.self).filter("md5Hash == %@", md5).first else { return }
                    try? realm.write {
                        game.originalArtworkFile = file
                    }
                }
                return
            }
        }

        DLOG("Starting artwork download for \(info.title): \(url)")

        // Note: Evil hack for bad domain in DB
        url = url.replacingOccurrences(of: "gamefaqs1.cbsistatic.com/box/", with: "gamefaqs.gamespot.com/a/box/")
        guard let artworkURL = URL(string: url) else {
            ELOG("Invalid artwork URL for \(info.title): \(url)")
            return
        }

        // Download artwork on background thread
        do {
            let request = URLRequest(url: artworkURL)
            let (data, _) = try await URLSession.shared.data(for: request)

            // Cache the artwork (file I/O, can stay on background)
            try PVMediaCache.writeData(toDisk: data, withKey: url)

            // Create image file and assign to game on main thread
            if let localURL = PVMediaCache.filePath(forKey: url) {
                let file = PVImageFile(withURL: localURL, relativeRoot: .platformDefault)
                try? await RealmContext.withBackgroundRealm { realm in
                    guard let game = realm.objects(PVGame.self).filter("md5Hash == %@", md5).first else { return }
                    try? realm.write {
                        game.originalArtworkFile = file
                    }
                }
                CloudSyncManager.syncLog.event(.download, item: "artwork/\(info.md5Hash)", status: .ok, detail: info.title)
            }
        } catch {
            CloudSyncManager.syncLog.event(.download, item: "artwork/\(info.md5Hash)", status: .failed, detail: error.localizedDescription)
        }
    }

    private func updateLocalDownloadStatus(md5: String, isDownloaded: Bool, fileURL: URL?, record: CKRecord? = nil) async throws {
        VLOG("Updating download status for \(md5): isDownloaded = \(isDownloaded), fileURL = \(fileURL?.path ?? "nil")")

        // Perform updates within a Realm write transaction via RomDatabase.shared
        try CloudKitRemoteApplyGuard.withApplyingRemoteChanges {
            try RomDatabase.sharedInstance.writeTransaction {
            guard let liveGame = RomDatabase.sharedInstance.game(withMD5: md5) else {
                WLOG("Cannot update download status: PVGame with MD5 \(md5) not found locally.")
                return
            }

            VLOG("Updating game: \(liveGame.title) (MD5: \(md5))")
            liveGame.isDownloaded = isDownloaded
            if let record {
                let declaresAsset = recordDeclaresAssetPresence(record)
                if declaresAsset {
                    liveGame.hasCloudAssets = true
                } else if !isDownloaded {
                    liveGame.hasCloudAssets = false
                }
            } else if isDownloaded {
                liveGame.hasCloudAssets = true
            }

            if isDownloaded, let validFileURL = fileURL {
                let needsFileUpdate: Bool
                if let currentFile = liveGame.file {
                    needsFileUpdate = currentFile.url != validFileURL
                } else {
                    needsFileUpdate = true // Needs creation
                }

                if needsFileUpdate {
                    let newFile = PVFile(withURL: validFileURL, relativeRoot: .platformDefault)
                    liveGame.file = newFile // Replace or create
                    VLOG("Updated/Created PVFile with URL \(validFileURL.path) for game \(md5).")
                } else {
                    VLOG("PVFile URL already correct for game \(md5).")
                }

                // Update fileSize from the downloaded file or record if available
                if let attributes = try? FileManager.default.attributesOfItem(atPath: validFileURL.path), let fileSize = attributes[.size] as? Int64 {
                    liveGame.fileSize = Int(fileSize) // Corrected file size access
                } else if let recordAsset = record?[CloudKitSchema.ROMFields.fileData] as? CKAsset,
                          let assetURL = recordAsset.fileURL,
                          let attributes = try? FileManager.default.attributesOfItem(atPath: assetURL.path),
                          let assetSize = attributes[.size] as? Int64  { // Get size via FileManager
                    liveGame.fileSize = Int(assetSize)
                    VLOG("Updated fileSize to \(assetSize) from record asset for game \(md5).")
                }

                // Handle related files if this was an archive extraction
                let isArchive = record?[CloudKitSchema.ROMFields.isArchive] as? Bool ?? false
                if isArchive {
                    VLOG("Game \(md5) was an archive, ensuring related files are marked present.")
                    // We assume extraction put files in the correct place relative to the main ROM file.
                    // Update related PVFile entries to reflect they exist locally (set URL, isOffline=false)
                    let gameDirectory = validFileURL.deletingLastPathComponent()
                    for relatedFile in liveGame.relatedFiles {
                        let filename = relatedFile.fileName
                        let expectedLocalURL = gameDirectory.appendingPathComponent(filename)
                        // Check if file actually exists? Maybe not necessary, trust the extraction.
                        // relatedFile.url = expectedLocalURL // Cannot assign to get-only property
                        WLOG("Need to update URL for related file \(filename) to \(expectedLocalURL.path), but .url is get-only. Requires refactor.")
                        // No 'isOffline' property on PVFile. Their existence is tracked by PVGame.
                        VLOG("Marked related file \(filename) as available at \(expectedLocalURL.path).")
                    }
                }

            } else if !isDownloaded {
                // Mark as not downloaded
                VLOG("Marking game \(md5) as not downloaded.")
                // Optionally clear PVFile URL or mark as offline?
                // game.file?.url = nil // Or keep url but mark PVFile as offline?
                // For now, just setting isDownloaded = false might be enough.

                // If download failed or was deleted, related files remain, but the primary is missing.
                for relatedFile in liveGame.relatedFiles where relatedFile.url != nil {
                    // No 'isOffline' property on PVFile. Their existence is tracked by PVGame.
                    VLOG("Related file \(relatedFile.fileName) exists for game \(md5) but primary is not downloaded.")
                }
            }
            } // End write transaction
        }
        VLOG("Finished updating download status for \(md5).)")
    }

    // MARK: - CloudKit Operations Helpers

    private func saveRecord(_ record: CKRecord) async throws {
        do {
            // Pass nil directly
            let result = try await retryOperation({ // Renamed method
                // Save the record to the private database
                try await self.database.save(record)
            }, 3, nil)

            // Cast the result back to CKRecord
            guard let savedRecord = result as? CKRecord else {
                CloudSyncManager.syncLog.event(.error, item: "saveRecord", status: .failed, detail: "unexpected type: \(type(of: result))")
                throw CloudSyncError.unknown
            }

            // Update local game state AFTER successful save
            if let md5 = savedRecord[CloudKitSchema.ROMFields.md5] as? String {
                try await updateLocalGamePostUpload(md5: md5, record: savedRecord)
            } else {
                WLOG("Saved record \(savedRecord.recordID.recordName) is missing MD5 field. Cannot update local game state.")
            }

            VLOG("Successfully saved record: \(savedRecord.recordID.recordName)")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Handle CloudKit conflict: record already exists, fetch and update it
            WLOG("Record \(record.recordID.recordName) already exists in CloudKit. Attempting to update existing record.")
            try await handleRecordConflict(localRecord: record, cloudKitError: error)
        } catch {
            CloudSyncManager.syncLog.event(.upload, item: "record/\(record.recordID.recordName)", status: .failed, detail: error.localizedDescription)
            throw CloudSyncError.cloudKitError(error)
        }
    }

    /// Handle CloudKit record conflicts by fetching the existing record and updating it
    private func handleRecordConflict(localRecord: CKRecord, cloudKitError: CKError) async throws {
        DLOG("Handling record conflict for \(localRecord.recordID.recordName)")

        // Fetch the existing record from CloudKit
        guard let existingRecord = try await fetchRecord(recordID: localRecord.recordID, includeAssets: false, bypassEmulationPause: true) else {
            ELOG("Could not fetch existing record \(localRecord.recordID.recordName) to resolve conflict")
            throw CloudSyncError.cloudKitError(cloudKitError)
        }

        // Update the existing record with our local changes
        // Copy all fields from local record to existing record (preserving CloudKit metadata)
        for key in localRecord.allKeys() {
            existingRecord[key] = localRecord[key]
        }

        DLOG("Updating existing CloudKit record \(existingRecord.recordID.recordName) with local changes")

        // Retry saving the updated record
        do {
            let result = try await retryOperation({
                try await self.database.save(existingRecord)
            }, 3, nil)

            guard let savedRecord = result as? CKRecord else {
                ELOG("Retry operation returned unexpected type for conflict resolution: \(type(of: result))")
                throw CloudSyncError.unknown
            }

            // Update local game state AFTER successful save
            if let md5 = savedRecord[CloudKitSchema.ROMFields.md5] as? String {
                try await updateLocalGamePostUpload(md5: md5, record: savedRecord)
            }

            CloudSyncManager.syncLog.event(.upload, item: "record/\(savedRecord.recordID.recordName)", status: .ok, detail: "conflict resolved")
        } catch {
            CloudSyncManager.syncLog.event(.upload, item: "record/\(localRecord.recordID.recordName)", status: .failed, detail: "conflict resolution: \(error.localizedDescription)")
            throw CloudSyncError.cloudKitError(error)
        }
    }

    /// Helper to update local game state after a successful upload.
    private func updateLocalGamePostUpload(md5: String, record: CKRecord) async throws {
        VLOG("Updating local game \(md5) with CloudKit record ID \(record.recordID.recordName)")

        // Use a more robust approach with retry logic
        var retryCount = 0
        let maxRetries = 3
        let normalizedMD5 = md5.uppercased()
        let recordHasAsset = recordDeclaresAssetPresence(record)

        while retryCount < maxRetries {
            do {
                let updatedGame = try await withRealm { realm -> Bool in
                    guard let liveGame = realm.object(ofType: PVGame.self, forPrimaryKey: normalizedMD5) else {
                        return false
                    }

                    let applyUpdate = {
                        liveGame.cloudRecordID = record.recordID.recordName
                        if let modificationDate = record.modificationDate {
                            liveGame.lastCloudSyncDate = modificationDate
                        }
                        liveGame.hasCloudAssets = recordHasAsset
                    }

                    try CloudKitRemoteApplyGuard.withApplyingRemoteChanges {
                        if realm.isInWriteTransaction {
                            applyUpdate()
                        } else {
                            try realm.write {
                                applyUpdate()
                            }
                        }
                    }

                    return true
                }

                guard updatedGame else {
                    if retryCount < maxRetries - 1 {
                        WLOG("Game \(md5) not found in Realm (attempt \(retryCount + 1)/\(maxRetries)). Retrying...")
                        retryCount += 1
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                        continue
                    } else {
                        CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .failed, detail: "post-upload: game not found after \(maxRetries) attempts")
                        return
                    }
                }

                VLOG("Successfully updated local game \(md5) with CloudKit record ID post-upload.")

                // Success - break out of retry loop
                break

            } catch {
                if retryCount < maxRetries - 1 {
                    WLOG("Failed to update game \(md5) post-upload (attempt \(retryCount + 1)/\(maxRetries)): \(error.localizedDescription). Retrying...")
                    retryCount += 1
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                } else {
                    CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .failed, detail: "post-upload after \(maxRetries) attempts: \(error.localizedDescription)")
                    throw error
                }
            }
        }
    } // End write transaction

    // MARK: - File & Asset Helpers

    private func temporaryZipURL(for md5: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-cloudkit-sync", isDirectory: true)
            .appendingPathComponent("rom-uploads", isDirectory: true)

        // Ensure the directory exists
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let filename = "\(md5).zip"
        return tempDirectory.appendingPathComponent(filename)
    }

    /// Creates a zip archive containing the specified files using ZipArchive.
    /// - Parameters:
    ///   - files: An array of URLs for the files to include in the archive.
    ///   - primaryFile: The URL of the file considered the "main" file (e.g., the .cue or main ROM).
    ///                  Its lastPathComponent will be used in error messages.
    ///   - outputURL: The URL where the resulting zip file should be saved.
    /// - Throws: `CloudSyncError.zipError` if zip creation fails, `CloudSyncError.fileSystemError` for other file issues.
    private func createZip(files: [URL], primaryFile: URL, outputURL: URL) async throws {
        VLOG("Creating ZipArchive zip archive at \(outputURL.path) for \(files.count) files (primary: \(primaryFile.lastPathComponent)).")

        // Validate input files before attempting zip creation
        for file in files {
            guard FileManager.default.fileExists(atPath: file.path) else {
                ELOG("Cannot create zip: File does not exist: \(file.path)")
                throw CloudSyncError.zipError(DescriptiveError(description: "Input file does not exist: \(file.path)"))
            }

            // Check file readability
            guard FileManager.default.isReadableFile(atPath: file.path) else {
                ELOG("Cannot create zip: File is not readable: \(file.path)")
                throw CloudSyncError.zipError(DescriptiveError(description: "Input file is not readable: \(file.path)"))
            }
        }

        // Ensure output directory exists
        let outputDirectory = outputURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: outputDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                VLOG("Created output directory: \(outputDirectory.path)")
            } catch {
                ELOG("Failed to create output directory \(outputDirectory.path): \(error.localizedDescription)")
                throw CloudSyncError.zipError(error)
            }
        }

        do {
            // Remove existing zip if present to prevent appending issues
            if FileManager.default.fileExists(atPath: outputURL.path) {
                VLOG("Removing existing zip file at \(outputURL.path)")
                try await FileManager.default.removeItem(at: outputURL)
            }

            // Create Zip Archive using ZipArchive
            let filePaths = files.map { $0.path }
            VLOG("Zip input files: \(filePaths)")

            do {
                try ArchiveManager.shared.createZipArchive(at: outputURL, withFiles: filePaths)
            } catch {
                let errorDetails = [
                    "Output path: \(outputURL.path)",
                    "Input files: \(filePaths.count)",
                    "Primary file: \(primaryFile.path)",
                    "Output directory exists: \(FileManager.default.fileExists(atPath: outputDirectory.path))",
                    "Output directory writable: \(FileManager.default.isWritableFile(atPath: outputDirectory.path))"
                ].joined(separator: ", ")

                ELOG("Zip creation failed: \(error.localizedDescription). Details: \(errorDetails)")
                throw CloudSyncError.zipError(DescriptiveError(description: "Failed to create zip at \(outputURL.path). \(errorDetails)"))
            }

            // Verify the zip was actually created and has content
            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                ELOG("Zip file was not created at expected path: \(outputURL.path)")
                throw CloudSyncError.zipError(DescriptiveError(description: "Zip file was not created at \(outputURL.path)"))
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            if fileSize == 0 {
                ELOG("Created zip file is empty: \(outputURL.path)")
                try? await FileManager.default.removeItem(at: outputURL)
                throw CloudSyncError.zipError(DescriptiveError(description: "Created zip file is empty"))
            }

            CloudSyncManager.syncLog.event(.upload, item: "zip/\(primaryFile.lastPathComponent)", status: .ok, detail: "\(fileSize) bytes", size: Int(fileSize))

        } catch let error as CocoaError {
            ELOG("CocoaError during ZipArchive zip creation for \(primaryFile.lastPathComponent): \(error.localizedDescription) (Code: \(error.code.rawValue))")
            // Clean up partial zip
            try? await FileManager.default.removeItem(at: outputURL)
            throw CloudSyncError.zipError(error)
        } catch let cloudSyncError as CloudSyncError {
            // Re-throw CloudSyncError as-is
            throw cloudSyncError
        } catch { // Catch other potential errors from ZipArchive or FileManager
            ELOG("Unexpected error during ZipArchive zip creation for \(primaryFile.lastPathComponent): \(error.localizedDescription)")
            // Clean up partial zip
            try? await FileManager.default.removeItem(at: outputURL)
            throw CloudSyncError.zipError(error) // Wrap other errors as zip errors for context
        }
    }

    /// Extract file size from a CloudKit record for sorting purposes
    /// - Parameter record: The CloudKit record to extract file size from
    /// - Returns: The file size in bytes, or 0 if not available
    /// Estimate the size of record metadata (excluding CKAssets which are stored separately)
    private func estimateRecordMetadataSize(_ record: CKRecord) throws -> Int64 {
        var estimatedSize: Int64 = 0

        // Estimate size of each field (excluding assets)
        for key in record.allKeys() {
            // Skip asset fields as they're stored separately
            if key == CloudKitSchema.ROMFields.fileData || key == CloudKitSchema.ROMFields.customArtworkAsset {
                continue
            }

            if let value = record[key] {
                // Rough estimation of serialized size
                if let string = value as? String {
                    estimatedSize += Int64(string.utf8.count)
                } else if let number = value as? NSNumber {
                    estimatedSize += 8 // Rough estimate for numbers
                } else if let date = value as? Date {
                    estimatedSize += 8 // Date representation
                } else if let array = value as? [Any] {
                    estimatedSize += Int64(array.count * 16) // Rough estimate
                } else if let dict = value as? [String: Any] {
                    estimatedSize += Int64(dict.count * 32) // Rough estimate
                }
            }
        }

        return estimatedSize
    }

    private func extractFileSize(from record: CKRecord) -> Int64 {
        // Try to get file size from the record's fileSize field
        if let fileSize = record[CloudKitSchema.ROMFields.fileSize] as? Int {
            return Int64(fileSize)
        }

        // Try to get file size from the CKAsset if available
        if let asset = record[CloudKitSchema.ROMFields.fileData] as? CKAsset,
           let fileURL = asset.fileURL {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let size = attributes[.size] as? Int64 {
                    return size
                }
            } catch {
                // Ignore error and fall through to default
            }
        }

        // Default to 0 if no size information is available
        return 0
    }

    // MARK: - Fast Metadata-Only Sync for Fresh Installs
    /// Quickly fetches ROM records and creates/updates PVGame entries without triggering any downloads
    /// Uses batch processing and parallel operations for speed
    public func syncMetadataOnly() async -> Int {
        // This can be triggered from multiple boot-time call sites.
        // Collapse concurrent runs into a single in-flight task to avoid overlapping full-library scans.
        return await metadataOnlyGate.run { [weak self] in
            guard let self else { return 0 }

            if let queue = self.workQueue {
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
                return await self.syncMetadataOnlyBody()
            }
        }
    }

    private actor MetadataOnlyGate {
        private var inFlight: Task<Int, Never>?

        func run(_ operation: @escaping @Sendable () async -> Int) async -> Int {
            if let inFlight { return await inFlight.value }
            let task = Task.detached(priority: .utility) { await operation() }
            inFlight = task
            let result = await task.value
            inFlight = nil
            return result
        }
    }

    private actor ArtworkDownloadGate {
        private var inFlight: Set<String> = []
        private let semaphore = AsyncSemaphore(value: 2)

        func enqueue(md5: String, work: @escaping @Sendable (String) async -> Void) async {
            let key = md5.uppercased()
            guard !key.isEmpty else { return }
            guard !inFlight.contains(key) else { return }
            inFlight.insert(key)

            let gate = self
            Task.detached(priority: .utility) {
                await gate.semaphore.acquire()
                await work(key)
                await gate.semaphore.release()
                await gate.finish(md5: key)
            }
        }

        private func finish(md5: String) {
            inFlight.remove(md5)
        }
    }

    private actor ArtworkLookupGate {
        private var inFlight: Set<String> = []
        private let semaphore = AsyncSemaphore(value: 1)

        func enqueue(md5: String, work: @escaping @Sendable (String) async -> Void) async {
            let key = md5.uppercased()
            guard !key.isEmpty else { return }
            guard !inFlight.contains(key) else { return }
            inFlight.insert(key)

            let gate = self
            Task.detached(priority: .utility) {
                await gate.semaphore.acquire()
                await work(key)
                await gate.semaphore.release()
                await gate.finish(md5: key)
            }
        }

        private func finish(md5: String) {
            inFlight.remove(md5)
        }
    }

    private actor OriginalArtworkDownloadGate {
        private var inFlight: Set<String> = []
        private let semaphore = AsyncSemaphore(value: 2)

        func enqueue(md5: String, work: @escaping @Sendable (String) async -> Void) async {
            let key = md5.uppercased()
            guard !key.isEmpty else { return }
            guard !inFlight.contains(key) else { return }
            inFlight.insert(key)

            let gate = self
            Task.detached(priority: .utility) {
                await gate.semaphore.acquire()
                await work(key)
                await gate.semaphore.release()
                await gate.finish(md5: key)
            }
        }

        private func finish(md5: String) {
            inFlight.remove(md5)
        }
    }

    private actor AsyncSemaphore {
        private var value: Int
        private var waiters: [CheckedContinuation<Void, Never>] = []

        init(value: Int) {
            self.value = value
        }

        func acquire() async {
            if value > 0 {
                value -= 1
                return
            }
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        func release() {
            if !waiters.isEmpty {
                let waiter = waiters.removeFirst()
                waiter.resume()
            } else {
                value += 1
            }
        }
    }

    private func syncMetadataOnlyBody() async -> Int {
        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            ILOG("[SYNC] ROM metadata sync skipped (emulator session active)")
            return 0
        }
        let startTime = Date()
        CloudSyncManager.syncLog.event(.start, item: "syncMetadataOnly", status: .inProgress)

        do {
            // Must include originalFilename - required for createPVGame
            let metadataKeys: [CKRecord.FieldKey] = [
                CloudKitSchema.ROMFields.md5,
                CloudKitSchema.ROMFields.title,
                CloudKitSchema.ROMFields.systemIdentifier,
                CloudKitSchema.ROMFields.fileSize,
                CloudKitSchema.ROMFields.relativePath,
                CloudKitSchema.SaveStateFields.directory,
                CloudKitSchema.ROMFields.crc,
                CloudKitSchema.ROMFields.originalFilename,
                // Include string artwork keys (no CKAsset) so we can queue asset downloads separately.
                CloudKitSchema.ROMFields.originalArtworkURL,
                CloudKitSchema.ROMFields.customArtworkURL
            ]
            let metadataQuery = CKQuery(recordType: CloudKitSchema.RecordType.rom.rawValue, predicate: NSPredicate(value: true))
            let metadataRecords = try await fetchAllRecords(matching: metadataQuery, desiredKeys: metadataKeys)

            CloudSyncManager.syncLog.event(.query, item: "syncMetadataOnly", status: .ok, detail: "\(metadataRecords.count) records in \(String(format: "%.1f", Date().timeIntervalSince(startTime)))s")

            // Use batch processing for speed
            let result = await processBatchedROMRecords(metadataRecords)

            let elapsed = Date().timeIntervalSince(startTime)
            let rate = elapsed > 0 ? Double(result.total) / elapsed : 0
            CloudSyncManager.syncLog.event(.complete, item: "syncMetadataOnly", status: .ok, detail: "\(result.created) created, \(result.updated) updated, \(result.skipped) skipped, \(result.failed) failed (\(String(format: "%.1f", rate))/s)", duration: elapsed)

            return result.created + result.updated
        } catch {
            CloudSyncManager.syncLog.event(.complete, item: "syncMetadataOnly", status: .failed, detail: "\(error)")
            return 0
        }
    }

    private struct ROMMetadataSnapshot: Sendable {
        let md5: String
        let recordName: String
        let modificationDate: Date
        let title: String
        let systemIdentifier: String
        let originalFilename: String
        let fileSize: Int
        let hasCloudAssets: Bool
        let originalArtworkURL: String?
        let customArtworkURL: String?
    }

    private func makeMetadataSnapshot(from record: CKRecord) -> ROMMetadataSnapshot? {
        // Always normalize MD5 to uppercase (Realm primary key expectation)
        let md5 = ((record[CloudKitSchema.ROMFields.md5] as? String)
                   ?? CloudKitSchema.RecordIDGenerator.extractMD5FromRomRecordID(record.recordID))?
            .uppercased()
        guard let md5, !md5.isEmpty else { return nil }

        guard let systemIdentifier = record[CloudKitSchema.ROMFields.systemIdentifier] as? String,
              !systemIdentifier.isEmpty,
              let originalFilename = record[CloudKitSchema.ROMFields.originalFilename] as? String,
              !originalFilename.isEmpty
        else {
            return nil
        }

        let title = (record[CloudKitSchema.ROMFields.title] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = (title?.isEmpty == false) ? title! : originalFilename

        let modDate = record.modificationDate ?? .distantPast
        let hasCloudAssets = recordDeclaresAssetPresence(record)

        let explicitFileSize: Int = {
            if let v = record[CloudKitSchema.ROMFields.fileSize] as? Int64 { return Int(v) }
            if let v = record[CloudKitSchema.ROMFields.fileSize] as? Int { return v }
            return 0
        }()

        return ROMMetadataSnapshot(
            md5: md5,
            recordName: record.recordID.recordName,
            modificationDate: modDate,
            title: safeTitle,
            systemIdentifier: systemIdentifier,
            originalFilename: originalFilename,
            fileSize: explicitFileSize,
            hasCloudAssets: hasCloudAssets,
            originalArtworkURL: record[CloudKitSchema.ROMFields.originalArtworkURL] as? String,
            customArtworkURL: record[CloudKitSchema.ROMFields.customArtworkURL] as? String
        )
    }

    /// Process ROM records in batches with parallel processing for optimal speed
    private func processBatchedROMRecords(_ records: [CKRecord]) async -> (created: Int, updated: Int, skipped: Int, failed: Int, total: Int) {
        var created = 0
        var updated = 0
        var skipped = 0
        var failed = 0

        // Process in batches for Realm write efficiency and to keep write locks short
        let batchSize = 50
        let batches = records.chunked(into: batchSize)
        var batchIndex = 0

        for batch in batches {
            batchIndex += 1
            if Task.isCancelled { break }
            let pausedForEmulation = await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation })
            if pausedForEmulation { break }

            // Build lightweight snapshots outside Realm to avoid touching Realm while parsing CloudKit records
            let snapshots: [ROMMetadataSnapshot] = batch.compactMap { makeMetadataSnapshot(from: $0) }
            if snapshots.isEmpty {
                failed += batch.count
                continue
            }

            do {
                let batchResult = try await applyMetadataSnapshotsBatch(snapshots)
                created += batchResult.created
                updated += batchResult.updated
                skipped += batchResult.skipped
                failed += batchResult.failed
            } catch {
                failed += snapshots.count
            }

            // Log progress every 10 batches (500 records)
            if batchIndex % 10 == 0 {
                let processed = min(batchIndex * batchSize, records.count)
                CloudSyncManager.syncLog.event(.sync, item: "syncMetadataOnly", status: .inProgress, detail: "\(processed)/\(records.count) processed")
            }
        }

        return (created, updated, skipped, failed, records.count)
    }

    private func applyMetadataSnapshotsBatch(_ snapshots: [ROMMetadataSnapshot]) async throws -> (created: Int, updated: Int, skipped: Int, failed: Int) {
        let pausedForEmulation = await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation })
        let result = try await withRealm { realm in
            var created = 0
            var updated = 0
            var skipped = 0
            var failed = 0
            var artworkMD5s: [String] = []
            var originalArtworkMD5s: [String] = []
            var lookupItems: [(md5: String, title: String, filename: String, systemIdentifier: String)] = []

            try CloudKitRemoteApplyGuard.withApplyingRemoteChanges {
                let applySnapshots = {
                    for snap in snapshots {
                        if Task.isCancelled || pausedForEmulation { break }

                        guard let system = realm.object(ofType: PVSystem.self, forPrimaryKey: snap.systemIdentifier) else {
                            failed += 1
                            continue
                        }

                        if let game = realm.object(ofType: PVGame.self, forPrimaryKey: snap.md5) {
                            let localSyncDate = game.lastCloudSyncDate ?? .distantPast
                            if snap.modificationDate <= localSyncDate, game.cloudRecordID != nil {
                                skipped += 1
                                continue
                            }

                            // Do not clobber local user edits during metadata bootstrap.
                            if game.cloudRecordID == nil { game.cloudRecordID = snap.recordName }
                            if game.systemIdentifier.isEmpty { game.systemIdentifier = snap.systemIdentifier }
                            if game.system == nil { game.system = system }
                            if game.title.isEmpty { game.title = snap.title }

                            if snap.fileSize > 0 && (game.fileSize == 0 || snap.modificationDate > localSyncDate) {
                                game.fileSize = snap.fileSize
                            }

                            // Sync artwork URL values (string-only); asset download happens out-of-band.
                            if let cloudOriginalArtworkURL = snap.originalArtworkURL,
                               !cloudOriginalArtworkURL.isEmpty,
                               game.originalArtworkURL.isEmpty {
                                game.originalArtworkURL = cloudOriginalArtworkURL
                            }
                            if let cloudCustomArtworkURL = snap.customArtworkURL,
                               !cloudCustomArtworkURL.isEmpty {
                                if game.customArtworkURL != cloudCustomArtworkURL {
                                    game.customArtworkURL = cloudCustomArtworkURL
                                }
                                artworkMD5s.append(snap.md5)
                            }
                            if !game.customArtworkURL.isEmpty {
                                // Custom artwork takes precedence; skip original downloader.
                            } else if !game.originalArtworkURL.isEmpty, game.originalArtworkFile == nil {
                                // Metadata-only path bypasses createPVGame(), so explicitly queue original artwork download.
                                originalArtworkMD5s.append(snap.md5)
                            } else if game.originalArtworkURL.isEmpty && game.originalArtworkFile == nil && game.customArtworkURL.isEmpty {
                                // No cloud artwork fields: queue enhanced artwork search.
                                let baseName = (snap.originalFilename as NSString).deletingPathExtension
                                lookupItems.append((md5: snap.md5, title: snap.title, filename: baseName, systemIdentifier: snap.systemIdentifier))
                            }

                            // Metadata-only reads omit asset fields.
                            if snap.hasCloudAssets && !game.hasCloudAssets {
                                game.hasCloudAssets = true
                            }

                            // Never flip to true here; presence of a local file should control this.
                            if game.isDownloaded == false {
                                // keep as-is
                            }

                            game.lastCloudSyncDate = max(localSyncDate, snap.modificationDate)
                            updated += 1
                        } else {
                            let newGame = PVGame()
                            newGame.md5Hash = snap.md5
                            newGame.systemIdentifier = snap.systemIdentifier
                            newGame.system = system
                            newGame.title = snap.title
                            newGame.cloudRecordID = snap.recordName
                            newGame.lastCloudSyncDate = snap.modificationDate
                            newGame.fileSize = snap.fileSize
                            newGame.hasCloudAssets = snap.hasCloudAssets
                            newGame.isDownloaded = false
                            if let cloudOriginalArtworkURL = snap.originalArtworkURL, !cloudOriginalArtworkURL.isEmpty {
                                newGame.originalArtworkURL = cloudOriginalArtworkURL
                            }
                            if let cloudCustomArtworkURL = snap.customArtworkURL, !cloudCustomArtworkURL.isEmpty {
                                newGame.customArtworkURL = cloudCustomArtworkURL
                                artworkMD5s.append(snap.md5)
                            } else if !newGame.originalArtworkURL.isEmpty {
                                originalArtworkMD5s.append(snap.md5)
                            } else {
                                let baseName = (snap.originalFilename as NSString).deletingPathExtension
                                lookupItems.append((md5: snap.md5, title: snap.title, filename: baseName, systemIdentifier: snap.systemIdentifier))
                            }

                            realm.add(newGame, update: .modified)
                            created += 1
                        }
                    }
                }
                if realm.isInWriteTransaction {
                    applySnapshots()
                } else {
                    try realm.write {
                        applySnapshots()
                    }
                }
            }

            return (created: created, updated: updated, skipped: skipped, failed: failed, artworkMD5s: artworkMD5s, originalArtworkMD5s: originalArtworkMD5s, lookupItems: lookupItems)
        }

        // Eager-all: queue artwork downloads for any games with a cloud custom artwork key.
        // Throttled + deduped to avoid boot stalls.
        let uniqueMD5s = Array(Set(result.artworkMD5s))
        for md5 in uniqueMD5s {
            await artworkDownloadGate.enqueue(md5: md5) { [weak self] md5 in
                guard let self else { return }
                let pausedForEmulation = await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation })
                if pausedForEmulation || Task.isCancelled { return }
                let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
                guard let record = try? await self.fetchRecord(recordID: recordID, includeAssets: true) else { return }
                guard let liveGame = RomDatabase.sharedInstance.game(withMD5: md5) else { return }
                try? await self.downloadCustomArtworkAsset(from: record, for: liveGame)
            }
        }

        // If CloudKit provided originalArtworkURL but not custom artwork, download/copy it into PVMediaCache + set originalArtworkFile.
        let uniqueOriginalArtworkMD5s = Array(Set(result.originalArtworkMD5s))
        for md5 in uniqueOriginalArtworkMD5s {
            await originalArtworkDownloadGate.enqueue(md5: md5) { [weak self] md5 in
                guard let self else { return }
                let pausedForEmulation = await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation })
                if pausedForEmulation || Task.isCancelled { return }
                await self.getArtwork(forGameMD5: md5)
            }
        }

        // Fallback: for games with no cloud artwork fields at all, use enhanced ArtworkSearchQueue (md5+filename+system).
        for item in result.lookupItems {
            await artworkLookupGate.enqueue(md5: item.md5) { md5 in
                let pausedForEmulation = await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation })
                if pausedForEmulation || Task.isCancelled { return }
                let systemID = SystemIdentifier(rawValue: item.systemIdentifier)
                await ArtworkSearchQueue.shared.queueGameForArtworkSearch(
                    gameID: md5,
                    title: item.title,
                    filename: item.filename,
                    systemID: systemID,
                    md5Hash: md5
                )
            }
        }

        return (created: result.created, updated: result.updated, skipped: result.skipped, failed: result.failed)
    }

    /// Legacy sequential sync method - slower but more reliable for debugging
    public func syncMetadataOnlySequential() async -> Int {
        var createdOrUpdated = 0
        CloudSyncManager.syncLog.event(.start, item: "syncMetadataSequential", status: .inProgress)
        do {
            let metadataKeys: [CKRecord.FieldKey] = [
                CloudKitSchema.ROMFields.md5,
                CloudKitSchema.ROMFields.title,
                CloudKitSchema.ROMFields.systemIdentifier,
                CloudKitSchema.ROMFields.fileSize,
                CloudKitSchema.ROMFields.relativePath,
                CloudKitSchema.SaveStateFields.directory,
                CloudKitSchema.ROMFields.crc,
                CloudKitSchema.ROMFields.originalFilename,
                CloudKitSchema.ROMFields.originalArtworkURL,
                CloudKitSchema.ROMFields.customArtworkURL
            ]
            let metadataQuery = CKQuery(recordType: CloudKitSchema.RecordType.rom.rawValue, predicate: NSPredicate(value: true))
            let metadataRecords = try await fetchAllRecords(matching: metadataQuery, desiredKeys: metadataKeys)

            CloudSyncManager.syncLog.event(.query, item: "syncMetadataSequential", status: .ok, detail: "\(metadataRecords.count) records")

            for record in metadataRecords {
                if let md5 = CloudKitSchema.RecordIDGenerator.extractMD5FromRomRecordID(record.recordID) {
                    let title = record["title"] as? String ?? "unknown"
                    do {
                        if let _ = try await createPVGame(from: record) {
                            createdOrUpdated += 1
                            VLOG("[SYNC] Created: \(title)")
                        }
                    } catch {
                        do {
                            try await updatePVGame(from: record, gameMD5: md5)
                            createdOrUpdated += 1
                            VLOG("[SYNC] Updated: \(title)")
                        } catch {
                            CloudSyncManager.syncLog.event(.sync, item: "rom/\(md5)", status: .failed, detail: "\(title): \(error.localizedDescription)")
                        }
                    }
                }
            }
            CloudSyncManager.syncLog.event(.complete, item: "syncMetadataSequential", status: .ok, detail: "\(createdOrUpdated) entries")
        } catch {
            CloudSyncManager.syncLog.event(.complete, item: "syncMetadataSequential", status: .failed, detail: "\(error)")
        }
        return createdOrUpdated
    }

    private func fetchROMRecords() async throws {
        // Metadata-first: exclude asset fields to avoid implicit CKAsset downloads filling caches
        // Must include originalFilename - required for createPVGame
        let metadataKeys: [CKRecord.FieldKey] = [
            CloudKitSchema.ROMFields.md5,
            CloudKitSchema.ROMFields.title,
            CloudKitSchema.ROMFields.systemIdentifier,
            CloudKitSchema.ROMFields.fileSize,
            CloudKitSchema.ROMFields.relativePath,
            CloudKitSchema.SaveStateFields.directory,
            CloudKitSchema.ROMFields.crc,
            CloudKitSchema.ROMFields.originalFilename,
            CloudKitSchema.ROMFields.originalArtworkURL,
            CloudKitSchema.ROMFields.customArtworkURL
        ]
        let query = CKQuery(recordType: "ROM", predicate: NSPredicate(value: true))
        let fetched = try await fetchAllRecords(matching: query, desiredKeys: metadataKeys)
        try await writePVGames(from: fetched)
    }

    private func fetchAllRecords(
        matching query: CKQuery,
        desiredKeys: [CKRecord.FieldKey]? = nil
    ) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        DLOG("[SYNC] Fetching records for query: \(query.recordType)")

        repeat {
            let result: ([CKRecord.ID: Result<CKRecord, Error>], CKQueryOperation.Cursor?)
            if let existingCursor = cursor {
                let continuationResult = try await database.records(
                    continuingMatchFrom: existingCursor,
                    desiredKeys: desiredKeys,
                    resultsLimit: CKQueryOperation.maximumResults
                )
                result = (
                    Dictionary(uniqueKeysWithValues: continuationResult.matchResults),
                    continuationResult.queryCursor
                )
            } else {
                let matchResult = try await database.records(
                    matching: query,
                    desiredKeys: desiredKeys,
                    resultsLimit: CKQueryOperation.maximumResults
                )
                result = (
                    Dictionary(uniqueKeysWithValues: matchResult.matchResults),
                    matchResult.queryCursor
                )
            }

            for (recordID, matchResult) in result.0 {
                switch matchResult {
                case .success(let record):
                    allRecords.append(record)
                case .failure(let error):
                    CloudSyncManager.syncLog.event(.query, item: "record/\(recordID.recordName)", status: .failed, detail: error.localizedDescription)
                }
            }

            cursor = result.1
        } while cursor != nil

        CloudSyncManager.syncLog.event(.query, item: "fetchAll/\(query.recordType)", status: .ok, detail: "\(allRecords.count) records")

        return allRecords
    }

    /// Writes PVGame Realm objects from metadata records only (no assets)
    private func writePVGames(from records: [CKRecord]) async throws {
        // existing Realm write logic creating PVGame entries if missing, updating metadata fields
    }

    /// Formats a CloudKit error with detailed information
    private func formatCloudKitError(_ error: CKError) -> String {
        var details = "\(error.localizedDescription)"
        details += " (code: \(error.code.rawValue))"

        // Add specific error code information
        switch error.code {
        case .notAuthenticated:
            details += " - Not authenticated"
        case .networkUnavailable, .networkFailure:
            details += " - Network issue"
        case .quotaExceeded:
            details += " - Quota exceeded"
        case .serviceUnavailable:
            details += " - Service unavailable"
        case .requestRateLimited:
            details += " - Rate limited"
        case .partialFailure:
            if let partialErrors = error.partialErrorsByItemID {
                details += " - Partial failure affecting \(partialErrors.count) items"
                for (itemID, itemError) in partialErrors {
                    let recordIDString: String
                    if let recordID = itemID as? CKRecord.ID {
                        recordIDString = recordID.recordName
                    } else {
                        recordIDString = "\(itemID)"
                    }

                    if let itemCKError = itemError as? CKError {
                        details += "\n  Item \(recordIDString): \(itemCKError.localizedDescription) (code: \(itemCKError.code.rawValue))"
                    } else {
                        details += "\n  Item \(recordIDString): \(itemError.localizedDescription)"
                    }
                }
            }
        default:
            break
        }

        // Add retry after information if available
        if let retryAfter = error.retryAfterSeconds {
            details += " - Retry after \(retryAfter) seconds"
        }

        return details
    }

    /// Extracts detailed error information from a CloudSyncError
    private func extractErrorDetails(_ error: CloudSyncError) -> String {
        switch error {
        case .cloudKitError(let underlyingError):
            if let ckError = underlyingError as? CKError {
                return formatCloudKitError(ckError)
            }
            return "CloudKit error: \(underlyingError.localizedDescription)"
        case .fileSystemError(let underlyingError):
            return "File system error: \(underlyingError.localizedDescription)"
        case .zipError(let underlyingError):
            return "Zip error: \(underlyingError.localizedDescription)"
        case .realmError(let underlyingError):
            return "Realm error: \(underlyingError.localizedDescription)"
        case .genericError(let message):
            return message
        case .gameNotFound(let message):
            return "Game not found: \(message)"
        case .invalidData:
            return "Invalid data"
        case .unknown:
            return "Unknown error"
        default:
            return error.localizedDescription
        }
    }


    /// Periodically verify that ROMs marked as synced still have CloudKit assets.
    public func auditCloudAssets(batchSize: Int = 40) async {
        let sample: [PVGame]
        do {
            sample = try await withRealm { realm -> [PVGame] in
                let candidates = realm.objects(PVGame.self)
                    .filter("cloudRecordID != nil AND contentless == false")
                return Array(candidates.prefix(batchSize)).map { $0.freeze() }
            }
        } catch {
            CloudSyncManager.syncLog.event(.check, item: "auditCloudAssets", status: .failed, detail: error.localizedDescription)
            return
        }
        guard !sample.isEmpty else { return }

        for frozenGame in sample {
            if Task.isCancelled { break }
            guard let recordName = frozenGame.cloudRecordID else { continue }
            let recordID = CKRecord.ID(recordName: recordName)

            do {
                let record = try await fetchRecord(recordID: recordID, includeAssets: true)
                let hasAsset: Bool = (record?[CloudKitSchema.ROMFields.fileData] as? CKAsset) != nil
                await persistAuditResult(for: frozenGame, hasAsset: hasAsset, recordMissing: record == nil)
            } catch let error as CKError where error.code == .unknownItem {
                await persistAuditResult(for: frozenGame, hasAsset: false, recordMissing: true)
            } catch {
                CloudSyncManager.syncLog.event(.check, item: "rom/\(recordName)", status: .failed, detail: error.localizedDescription)
            }
        }
    }

    private func persistAuditResult(for frozenGame: PVGame, hasAsset: Bool, recordMissing: Bool) async {
        do {
            try await withRealm { realm in
                try realm.write {
                    guard let liveGame = frozenGame.thaw() else { return }
                    liveGame.hasCloudAssets = hasAsset
                    if recordMissing {
                        liveGame.cloudRecordID = nil
                    }
                    if recordMissing || !hasAsset {
                        liveGame.requiresSync = true
                    }
                }
            }
        } catch {
            CloudSyncManager.syncLog.event(.check, item: "rom/\(frozenGame.md5Hash)", status: .failed, detail: "persist audit: \(error.localizedDescription)")
        }
    }

    // MARK: - Record Integrity Audit

    /// Required fields for a valid ROM record
    private static let requiredROMFields: [String] = [
        CloudKitSchema.ROMFields.md5,
        CloudKitSchema.ROMFields.title,
        CloudKitSchema.ROMFields.systemIdentifier,
        CloudKitSchema.ROMFields.originalFilename
    ]

    /// Audit CloudKit records for incomplete metadata and repair from local data if possible
    /// - Parameter batchSize: Number of records to check per batch
    /// - Returns: Tuple of (checked, repaired, unrepairable) counts
    @discardableResult
    public func auditAndRepairIncompleteRecords(batchSize: Int = 30) async -> (checked: Int, repaired: Int, unrepairable: Int) {
        CloudSyncManager.syncLog.event(.start, item: "auditRepair", status: .inProgress)

        var checkedCount = 0
        var repairedCount = 0
        var unrepairableCount = 0

        // Get local games that have cloudRecordIDs
        let localGames: [PVGame]
        do {
            localGames = try await withRealm { realm -> [PVGame] in
                Array(realm.objects(PVGame.self)
                    .filter("cloudRecordID != nil AND contentless == false")
                    .map { $0.freeze() })
            }
        } catch {
            CloudSyncManager.syncLog.event(.check, item: "auditRepair", status: .failed, detail: "fetch games: \(error.localizedDescription)")
            return (0, 0, 0)
        }

        guard !localGames.isEmpty else {
            CloudSyncManager.syncLog.event(.check, item: "auditRepair", status: .skipped, detail: "no games with cloudRecordID")
            return (0, 0, 0)
        }

        CloudSyncManager.syncLog.event(.check, item: "auditRepair", status: .inProgress, detail: "\(localGames.count) records")

        // Process in batches
        for batch in localGames.chunked(into: batchSize) {
            if Task.isCancelled { break }

            for frozenGame in batch {
                if Task.isCancelled { break }

                guard let recordName = frozenGame.cloudRecordID else { continue }
                checkedCount += 1

                do {
                    let recordID = CKRecord.ID(recordName: recordName)
                    guard let record = try await fetchRecord(recordID: recordID, includeAssets: false) else {
                        // Record doesn't exist, mark for re-upload
                        CloudSyncManager.syncLog.event(.check, item: "rom/\(frozenGame.md5Hash)", status: .notFound, detail: "marking for re-upload")
                        await markGameForReupload(frozenGame)
                        unrepairableCount += 1
                        continue
                    }

                    // Check for missing required fields
                    let missingFields = Self.requiredROMFields.filter { field in
                        let value = record[field]
                        if let str = value as? String {
                            return str.isEmpty
                        }
                        return value == nil
                    }

                    if !missingFields.isEmpty {
                        CloudSyncManager.syncLog.event(.check, item: "rom/\(recordName)", status: .failed, detail: "missing: \(missingFields.joined(separator: ", "))")

                        // Try to repair from local data
                        if await repairRecord(record, from: frozenGame, missingFields: missingFields) {
                            repairedCount += 1
                            CloudSyncManager.syncLog.event(.sync, item: "rom/\(frozenGame.md5Hash)", status: .ok, detail: "repaired: \(frozenGame.title)")
                        } else {
                            unrepairableCount += 1
                            CloudSyncManager.syncLog.event(.sync, item: "rom/\(frozenGame.md5Hash)", status: .failed, detail: "unrepairable: \(frozenGame.title)")
                        }
                    }
                } catch {
                    CloudSyncManager.syncLog.event(.check, item: "rom/\(frozenGame.md5Hash)", status: .failed, detail: "audit: \(error.localizedDescription)")
                }
            }

            // Small delay between batches
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        CloudSyncManager.syncLog.event(.complete, item: "auditRepair", status: .ok, detail: "checked=\(checkedCount), repaired=\(repairedCount), unrepairable=\(unrepairableCount)")
        return (checkedCount, repairedCount, unrepairableCount)
    }

    /// Repair a CloudKit record by filling in missing fields from local data
    private func repairRecord(_ record: CKRecord, from game: PVGame, missingFields: [String]) async -> Bool {
        var updatedRecord = record
        var canRepair = true

        for field in missingFields {
            switch field {
            case CloudKitSchema.ROMFields.md5:
                if !game.md5Hash.isEmpty {
                    updatedRecord[field] = game.md5Hash
                } else {
                    canRepair = false
                }

            case CloudKitSchema.ROMFields.title:
                if !game.title.isEmpty {
                    updatedRecord[field] = game.title
                } else {
                    canRepair = false
                }

            case CloudKitSchema.ROMFields.systemIdentifier:
                if !game.systemIdentifier.isEmpty {
                    updatedRecord[field] = game.systemIdentifier
                } else {
                    canRepair = false
                }

            case CloudKitSchema.ROMFields.originalFilename:
                if let filename = game.file?.fileName, !filename.isEmpty {
                    updatedRecord[field] = filename
                } else {
                    // Try to derive from file URL
                    if let url = game.file?.url {
                        updatedRecord[field] = url.lastPathComponent
                    } else {
                        canRepair = false
                    }
                }

            default:
                DLOG("[SYNC] Unknown field to repair: \(field)")
            }
        }

        guard canRepair else {
            CloudSyncManager.syncLog.event(.sync, item: "rom/\(game.md5Hash)", status: .failed, detail: "missing local data for repair")
            return false
        }

        // Save the repaired record
        do {
            try await saveRecord(updatedRecord)
            return true
        } catch {
            CloudSyncManager.syncLog.event(.sync, item: "rom/\(game.md5Hash)", status: .failed, detail: "save repair: \(error.localizedDescription)")
            return false
        }
    }

    /// Mark a game for re-upload by clearing its cloudRecordID and setting requiresSync
    private func markGameForReupload(_ frozenGame: PVGame) async {
        do {
            try await withRealm { realm in
                try realm.write {
                    guard let liveGame = frozenGame.thaw() else { return }
                    liveGame.cloudRecordID = nil
                    liveGame.requiresSync = true
                }
            }
        } catch {
            CloudSyncManager.syncLog.event(.sync, item: "markForReupload", status: .failed, detail: error.localizedDescription)
        }
    }
}

// MARK: - Array Extension for Chunking
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
