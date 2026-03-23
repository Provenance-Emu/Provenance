//
//  CloudKitInitialSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import PVLogging
import PVRealm
import RealmSwift
import Combine
import PVFileSystem
import RxSwift
import RxCocoa

/// Represents a failed upload that can be retried
private struct RetryableUpload {
    enum UploadType {
        case rom(md5: String)
        case saveState(id: String)
        case bios(id: String)
        case nonDatabase(path: String)
    }

    let type: UploadType
    let error: Error
    var attemptCount: Int
    let firstAttemptDate: Date

    init(type: UploadType, error: Error) {
        self.type = type
        self.error = error
        self.attemptCount = 1
        self.firstAttemptDate = Date()
    }

    var canRetry: Bool {
        return attemptCount < 3 && Date().timeIntervalSince(firstAttemptDate) < 300 // 5 minutes max
    }

    var nextRetryDelay: TimeInterval {
        switch attemptCount {
        case 1: return 5   // 5 seconds
        case 2: return 15  // 15 seconds
        default: return 30 // 30 seconds
        }
    }
}

/// A class responsible for performing the initial sync of all local files to CloudKit
public actor CloudKitInitialSyncer {
    // MARK: - Properties

    /// Shared instance; nil when not configured or when configuration failed (e.g. no CloudKit container).
    public static var shared: CloudKitInitialSyncer?

    /// CloudKit container (initial sync requires `iCloudConstants.container` to be available).
    private let container: CKContainer

    /// Private database
    private let privateDatabase: CKDatabase
    private let romsSyncer: RomsSyncing
    private let saveStatesSyncer: SaveStatesSyncing
    private let nonDatabaseSyncer: NonDatabaseFileSyncing

    // Retry queue for failed uploads
    private var retryQueue: [RetryableUpload] = []
    private let maxRetryAttempts = 3
    private let retryDelaySeconds: [TimeInterval] = [5, 15, 30] // Exponential backoff

    /// Sync progress publisher
    private let syncProgressSubject = CurrentValueSubject<CloudKitInitialSyncProgress, Never>(CloudKitInitialSyncProgress())

    /// Sync progress publisher
    public var syncProgressPublisher: AnyPublisher<CloudKitInitialSyncProgress, Never> {
        syncProgressSubject.eraseToAnyPublisher()
    }

    /// Current sync progress
    @Published public private(set) var syncProgress = CloudKitInitialSyncProgress()

    /// Whether an initial sync is in progress
    @Published public private(set) var isInitialSyncInProgress = false

        // MARK: - Initialization

    /// Initialize with dependency injection.
    /// - Parameters:
    ///   - romsSyncer: The ROM syncer to use
    ///   - saveStatesSyncer: The save states syncer to use
    ///   - nonDatabaseSyncer: The non-database file syncer to use
    /// - Throws: `CloudSyncError.cloudKitContainerUnavailable` when `iCloudConstants.container` is nil (no CloudKit entitlement / invalid setup).
    public init(
        romsSyncer: RomsSyncing,
        saveStatesSyncer: SaveStatesSyncing,
        nonDatabaseSyncer: NonDatabaseFileSyncing
    ) throws {
        guard let cloudContainer = iCloudConstants.container else {
            WLOG("[CloudKitInitialSyncer] Cannot initialize — iCloudConstants.container is nil (CloudKit entitlement missing, or bundle / NSUbiquitousContainers misconfigured). Initial batch sync will be unavailable; other sync paths may still work.")
            throw CloudSyncError.cloudKitContainerUnavailable
        }
        self.container = cloudContainer
        privateDatabase = cloudContainer.privateCloudDatabase

        self.romsSyncer = romsSyncer
        self.saveStatesSyncer = saveStatesSyncer
        self.nonDatabaseSyncer = nonDatabaseSyncer

        // Subscribe to progress updates
        syncProgressSubject
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncProgress)
    }

    /// Configures the shared instance. Resets `shared` to nil before attempting creation; leaves nil on failure.
    /// - Parameters:
    ///   - romsSyncer: The ROM syncer to use
    ///   - saveStatesSyncer: The save states syncer to use
    ///   - nonDatabaseSyncer: The non-database file syncer to use
    /// - Throws: Same as ``init(romsSyncer:saveStatesSyncer:nonDatabaseSyncer:)``.
    public static func configureShared(
        romsSyncer: RomsSyncing,
        saveStatesSyncer: SaveStatesSyncing,
        nonDatabaseSyncer: NonDatabaseFileSyncing
    ) throws {
        shared = nil
        shared = try CloudKitInitialSyncer(
            romsSyncer: romsSyncer,
            saveStatesSyncer: saveStatesSyncer,
            nonDatabaseSyncer: nonDatabaseSyncer
        )
        DLOG("[CloudKitInitialSyncer] Shared instance configured successfully.")
    }

    // MARK: - Public Methods

    /// Check if initial sync is needed
    /// - Returns: True if initial sync is needed, false otherwise
    public func isInitialSyncNeeded() async -> Bool {
        /// Determine initial sync necessity from LOCAL datastore state (Realm), not CloudKit state.
        /// If there are no local items that would be uploaded, skip initial sync to avoid heavy launch work.
        do {
            return try await RealmContext.withBackgroundRealm { realm in
                let hasUnsyncedROMs = !realm.objects(PVGame.self)
                    .filter("""
                        contentless == false AND
                        isDownloaded == true AND
                        (cloudRecordID == nil OR cloudRecordID == '' OR hasCloudAssets == false)
                    """)
                    .isEmpty

                if hasUnsyncedROMs { return true }

                let hasUnsyncedSaveStates = !realm.objects(PVSaveState.self)
                    .filter("cloudRecordID == nil OR cloudRecordID == ''")
                    .isEmpty

                if hasUnsyncedSaveStates { return true }

                let hasUnsyncedBIOS = !realm.objects(PVBIOS.self)
                    .filter("cloudRecordID == nil OR cloudRecordID == ''")
                    .isEmpty

                return hasUnsyncedBIOS
            }
        } catch {
            WLOG("[isInitialSyncNeeded] Unable to query Realm: \(error.localizedDescription). Skipping initial sync for safety.")
            return false
        }
    }

    /// Helper function to add timeout to async operations
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: The async operation to perform
    /// - Returns: The result of the operation
    /// - Throws: TimeoutError if the operation times out
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }

            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            // Return the first result or throw the first error
            let result = try await group.next()
            // Cancel the remaining task
            group.cancelAll()

            // Unwrap the result (should never be nil since we added at least one task)
            return result!
        }
    }

    /// Perform initial sync of all local files to CloudKit
    /// - Returns: Number of records synced
    /// Perform initial sync of all local files to CloudKit
    /// - Parameter forceSync: If true, will perform sync even if it's not needed
    /// - Returns: Number of records synced
    @discardableResult
    public func performInitialSync(forceSync: Bool = false) async -> Int {
        DLOG("🚀 [performInitialSync] Starting initial sync (forceSync: \(forceSync))")

        // Check if sync is already in progress
        guard !isInitialSyncInProgress else {
            ILOG("⏸️ [performInitialSync] Initial sync already in progress")
            return 0
        }

        // Check if sync is needed (unless forced)
        if !forceSync {
            DLOG("🔍 [performInitialSync] Checking if initial sync is needed...")
            let syncNeeded = await isInitialSyncNeeded()
            DLOG("🔍 [performInitialSync] isInitialSyncNeeded result: \(syncNeeded)")
            if !syncNeeded {
                ILOG("⏭️ [performInitialSync] Initial sync not needed, skipping")
                return 0
            }
        } else {
            DLOG("🔄 [performInitialSync] Force sync enabled, skipping sync needed check")
        }

        // Set sync in progress
        isInitialSyncInProgress = true

        // Reset progress
        var progress = CloudKitInitialSyncProgress()
        await MainActor.run {
            syncProgressSubject.send(progress)
        }

        DLOG("""
             Starting initial CloudKit sync...
             This will upload all local files to CloudKit.
             """)

        // Start analytics tracking
        await CloudKitSyncAnalytics.shared.startSync(operation: "Initial CloudKit Sync")

        // Track overall success
        var overallSuccess = true
        var totalCount = 0

        // Sync ROMs with timeout protection
        var romCount = 0
        do {
            let romSyncTask = Task {
                await syncAllROMs(forceSync: forceSync)
            }

            romCount = try await withTimeout(seconds: 300) { // 5-minute timeout
                await romSyncTask.value
            }

            progress.romsTotal = romCount
            progress.romsCompleted = romCount
            await MainActor.run {
                syncProgressSubject.send(progress)
            }

            DLOG("Successfully synced \(romCount) ROMs")
            totalCount += romCount
        } catch is TimeoutError {
            ELOG("ROM sync timed out after 5 minutes")
            overallSuccess = false
            // Continue with other sync operations
        } catch {
            ELOG("Error syncing ROMs: \(error.localizedDescription)")
            overallSuccess = false
            // Continue with other sync operations
        }

        // Sync save states with timeout protection
        DLOG("🔄 Starting save state sync section...")
        var saveStateCount = 0
        do {
            DLOG("🔄 Creating save state sync task...")
            let saveStateSyncTask = Task {
                DLOG("🔄 Executing syncAllSaveStates(forceSync: \(forceSync))...")
                let result = await syncAllSaveStates(forceSync: forceSync)
                DLOG("🔄 syncAllSaveStates completed with result: \(result)")
                return result
            }

            DLOG("🔄 Awaiting save state sync task with timeout...")
            saveStateCount = try await withTimeout(seconds: 300) { // 5-minute timeout
                await saveStateSyncTask.value
            }

            progress.saveStatesTotal = saveStateCount
            DLOG("✅ Successfully synced \(saveStateCount) save states")
            totalCount += saveStateCount
        } catch is TimeoutError {
            ELOG("❌ Save state sync timed out after 5 minutes")
            overallSuccess = false
            // Continue with other sync operations
        } catch {
            ELOG("❌ Error syncing save states: \(error.localizedDescription)")
            ELOG("❌ Error type: \(type(of: error))")
            overallSuccess = false
            // Continue with other sync operations
        }

        // Sync BIOS files with timeout protection
        var biosCount = 0
        do {
            let biosSyncTask = Task {
                await syncAllBIOSFiles(forceSync: forceSync)
            }

            biosCount = try await withTimeout(seconds: 180) { // 3-minute timeout
                await biosSyncTask.value
            }

            progress.biosTotal = biosCount
            progress.biosCompleted = biosCount
            await MainActor.run {
                syncProgressSubject.send(progress)
            }

            DLOG("Successfully synced \(biosCount) BIOS files")
            totalCount += biosCount
        } catch is TimeoutError {
            ELOG("BIOS sync timed out after 3 minutes")
            overallSuccess = false
            // Continue with other sync operations
        } catch {
            ELOG("Error syncing BIOS files: \(error.localizedDescription)")
            overallSuccess = false
            // Continue with other sync operations
        }

        // Sync all non-database files with timeout protection
        var nonDatabaseFileCounts: [String: Int] = [:]
        do {
            let nonDbSyncTask = Task {
                await syncAllNonDatabaseFiles(forceSync: forceSync)
            }

            nonDatabaseFileCounts = try await withTimeout(seconds: 300) { // 5-minute timeout
                await nonDbSyncTask.value
            }

            // Extract individual counts for logging
            let batteryStateCount = nonDatabaseFileCounts["Battery States"] ?? 0
            let screenshotCount = nonDatabaseFileCounts["Screenshots"] ?? 0
            let deltaSkinCount = DeltaSkinSyncSupport.isEnabled ? (nonDatabaseFileCounts[DeltaSkinSyncSupport.directoryName] ?? 0) : 0

            DLOG("Successfully synced \(batteryStateCount) battery states, \(screenshotCount) screenshots, and \(deltaSkinCount) Delta skins")
            totalCount += batteryStateCount + screenshotCount + deltaSkinCount
        } catch is TimeoutError {
            ELOG("Non-database file sync timed out after 5 minutes")
            overallSuccess = false
        } catch {
            ELOG("Error syncing non-database files: \(error.localizedDescription)")
            overallSuccess = false
        }

        // Complete progress
        progress.isComplete = true
        await MainActor.run {
            syncProgressSubject.send(progress)
        }

        // Process retry queue after main sync
        await processRetryQueue()

        // Set sync complete
        isInitialSyncInProgress = false

        // Record sync result
        if overallSuccess {
            await CloudKitSyncAnalytics.shared.recordSuccessfulSync()

            // Extract individual counts for logging
            let batteryStateCount = nonDatabaseFileCounts["Battery States"] ?? 0
            let screenshotCount = nonDatabaseFileCounts["Screenshots"] ?? 0
            let deltaSkinCount = DeltaSkinSyncSupport.isEnabled ? (nonDatabaseFileCounts[DeltaSkinSyncSupport.directoryName] ?? 0) : 0

            var statusMessage = """
                 Initial CloudKit sync completed successfully.
                 Synced \(totalCount) total records:
                 - \(romCount) ROMs
                 - \(saveStateCount) save states
                 - \(biosCount) BIOS files
                 - \(batteryStateCount) battery state files
                 - \(screenshotCount) screenshot files
                 """
            if DeltaSkinSyncSupport.isEnabled {
                statusMessage += "\n                 - \(deltaSkinCount) Delta skin files"
            }
            DLOG("\(statusMessage)\n                 ")
            await CloudKitSyncAnalytics.shared.recordSuccessfulSync()
        } else {
            // Record partial success
            let error = NSError(domain: "com.provenance.cloudkit", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Partial sync failure"])
            await CloudKitSyncAnalytics.shared.recordFailedSync(error: error)

            ELOG("""
                 Initial CloudKit sync completed with some errors.
                 Synced \(totalCount) records successfully, but some operations failed.
                 See previous log messages for specific errors.
                 """)

            await CloudKitSyncAnalytics.shared.recordFailedSync(error: error)
        }

        return totalCount
    }

    // MARK: - Retry Queue Management

    /// Adds a failed upload to the retry queue
    private func addToRetryQueue(_ upload: RetryableUpload) {
        retryQueue.append(upload)
        WLOG("Added failed upload to retry queue: \(upload.type) (attempt \(upload.attemptCount))")
    }

    /// Processes the retry queue, attempting to retry failed uploads
    private func processRetryQueue() async {
        guard !retryQueue.isEmpty else { return }

        ILOG("Processing retry queue with \(retryQueue.count) failed uploads")

        var completedRetries: [Int] = []

        for (index, var upload) in retryQueue.enumerated() {
            guard upload.canRetry else {
                ELOG("Upload exceeded retry limits: \(upload.type)")
                completedRetries.append(index)
                continue
            }

            // Wait for retry delay
            let delay = upload.nextRetryDelay
            VLOG("Retrying upload after \(delay)s delay: \(upload.type)")
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            upload.attemptCount += 1

            do {
                // Attempt retry based on upload type
                switch upload.type {
                case .rom(let md5):
                    if let romSyncer = romsSyncer as? CloudKitRomsSyncer {
                        do {
                            let romInfo = try await RealmContext.withRealm({ realm -> (String, URL)? in
                                guard
                                    let game = realm.objects(PVGame.self)
                                        .filter("md5Hash == %@", md5.uppercased())
                                        .first,
                                    let fileURL = game.file?.url
                                else {
                                    return nil
                                }
                                return (game.title, fileURL)
                            })
                            if let romInfo = romInfo {
                                let taskId = await romSyncer.queueROMUpload(
                                    md5: md5.uppercased(),
                                    gameTitle: romInfo.0,
                                    filePath: romInfo.1,
                                    priority: .high
                                )
                                DLOG("Queued ROM retry upload: \(romInfo.0) (\(md5)) - Task ID: \(taskId)")
                            } else {
                                WLOG("[SYNC] Game not found for ROM retry: \(md5)")
                            }
                        } catch {
                            ELOG("[SYNC] Failed to fetch game for ROM retry \(md5): \(error.localizedDescription)")
                        }
                    } else {
                        try await romsSyncer.uploadGame(md5.uppercased())
                    }
                    completedRetries.append(index)

                case .saveState(let id):
                    do {
                        let saveState = try await RealmContext.withRealm({ realm in
                            realm.object(ofType: PVSaveState.self, forPrimaryKey: id)?.freeze()
                        })
                        if let saveState = saveState {
                            try await saveStatesSyncer.uploadSaveState(for: saveState).toAsync()
                            ILOG("[SYNC] Successfully retried save state upload: \(id)")
                        } else {
                            WLOG("[SYNC] Save state not found for retry: \(id)")
                        }
                    } catch {
                        ELOG("[SYNC] Failed to fetch save state for retry \(id): \(error.localizedDescription)")
                    }
                    completedRetries.append(index)

                case .bios(let id):
                    // BIOS syncer not implemented yet, skip for now
                    WLOG("BIOS syncer not implemented, skipping retry: \(id)")
                    completedRetries.append(index)

                case .nonDatabase(let path):
                    // Non-database files are harder to retry individually
                    // For now, just remove from queue
                    WLOG("Skipping non-database file retry: \(path)")
                    completedRetries.append(index)
                }

            } catch {
                WLOG("Retry attempt \(upload.attemptCount) failed for \(upload.type): \(error.localizedDescription)")

                if upload.attemptCount >= maxRetryAttempts {
                    ELOG("Upload failed after \(maxRetryAttempts) attempts: \(upload.type)")
                    completedRetries.append(index)
                } else {
                    // Update the upload in the queue with new attempt count
                    retryQueue[index] = upload
                }
            }
        }

        // Remove completed retries using a Set for safe lookup
        // (index-based removal can crash if queue was mutated during async processing)
        let completedSet = Set(completedRetries)
        retryQueue = retryQueue.enumerated()
            .filter { !completedSet.contains($0.offset) }
            .map { $0.element }

        if !retryQueue.isEmpty {
            WLOG("\(retryQueue.count) uploads remain in retry queue")
        } else {
            ILOG("Retry queue processed successfully")
        }
    }

    // MARK: - Private Methods

    /// Sync all ROMs to CloudKit
    /// - Parameter forceSync: If true, upload all ROMs regardless of existing cloudRecordID
    /// - Returns: Number of ROMs synced
    // TODO: I would prefer this not be main actor, but realm keeps crashing, even making a local realm @JoeMatt
    @MainActor
    private func syncAllROMs(forceSync: Bool = false) async -> Int {
        ILOG("[SYNC] Syncing all ROMs to CloudKit (forceSync: \(forceSync))...")

        do {
            let realm = RomDatabase.sharedInstance.realm
            let realmGames = realm.objects(PVGame.self).filter("contentless == false")
            let unsortedGames = Array(realmGames) // Convert to array to avoid Realm invalidation issues

            // Sort games by file size (smallest first) for better reliability
            let games = unsortedGames.sorted { game1, game2 in
                let size1 = game1.fileSize
                let size2 = game2.fileSize
                return size1 < size2
            }

            ILOG("[SYNC] Found \(games.count) ROMs in Realm, sorted by file size (smallest first)")

            // Update progress
            var progress = await MainActor.run { syncProgressSubject.value }
            progress.romsTotal = games.count
            await MainActor.run {
                syncProgressSubject.send(progress)
            }

            // Use the injected ROM syncer

            // Sync each ROM
            var syncedCount = 0
            // Batch progress sends: only update UI every N items to avoid flooding the main
            // actor with thousands of trivial updates (e.g. 1953 already-synced ROMs).
            let progressBatchSize = 50
            DLOG("Starting to process \(games.count) ROMs...")

            for (index, game) in games.enumerated() {
                DLOG("Processing ROM \(index + 1)/\(games.count): \(game.title) (\(game.md5Hash ?? "no-md5"))")
                // Skip logic: only skip if not forcing sync AND record has cloudRecordID
                if !forceSync && game.cloudRecordID != nil && !game.cloudRecordID!.isEmpty {
                    VLOG("ROM already synced: \(game.title) (\(game.md5Hash))")
                    progress.romsCompleted += 1
                    syncedCount += 1
                    // Batch: only send progress every N skipped items to avoid main-thread flooding
                    if progress.romsCompleted % progressBatchSize == 0 {
                        syncProgressSubject.send(progress)
                    }
                    continue
                }

                if forceSync {
                    DLOG("Force sync: uploading ROM regardless of existing cloudRecordID: \(game.title) (\(game.md5Hash))")
                } else {
                    DLOG("No cloudRecordID found, uploading ROM: \(game.title) (\(game.md5Hash))")
                }

                do {
                    // Queue the upload instead of blocking sync
                    if let romSyncer = romsSyncer as? CloudKitRomsSyncer,
                       let romURL = game.file?.url {
                        let taskId = await romSyncer.queueROMUpload(
                            md5: game.md5Hash,
                            gameTitle: game.title,
                            filePath: romURL,
                            priority: .normal
                        )
                        DLOG("Queued ROM upload: \(game.title) (\(game.md5Hash)) - Task ID: \(taskId)")
                    } else {
                        // Fallback to direct upload if queueing fails
                        try await romsSyncer.uploadGame(game.md5Hash)
                    }

                    syncedCount += 1
                    DLOG("Successfully initiated upload for ROM: \(game.title) (\(game.md5Hash))")

                } catch let error as CloudSyncError {
                    if case .alreadyExists = error {
                         // If the record already exists (e.g., from a previous partial sync),
                         // we can count it as 'synced' for the initial sync purpose.
                         // We might want to verify the asset exists too, but for initial sync,
                         // assuming the record existing is enough.
                         WLOG("ROM \(game.title) (\(game.md5Hash)) record already exists in CloudKit. Skipping initial upload.")
                         syncedCount += 1 // Count it as done for initial sync progress
                    } else {
                        ELOG("Error uploading ROM \(game.title) (\(game.md5Hash)): \(error.localizedDescription)")

                        // Add to retry queue for later processing
                        let md5 = game.md5Hash
                        let retryUpload = RetryableUpload(type: .rom(md5: md5), error: error)
                        await addToRetryQueue(retryUpload)
                    }

                } catch {
                    ELOG("Error uploading ROM \(game.title) (\(game.md5Hash)): \(error.localizedDescription)")

                    // Add to retry queue for later processing
                    let md5 = game.md5Hash
                    let retryUpload = RetryableUpload(type: .rom(md5: md5), error: error)
                    await addToRetryQueue(retryUpload)
                }

                // Update progress on uploads (always send for actual uploads since they're infrequent)
                progress.romsCompleted += 1
                syncProgressSubject.send(progress)
            }
            // Flush final progress after loop
            syncProgressSubject.send(progress)

            DLOG("Completed ROM sync: \(syncedCount) of \(games.count) ROMs synced")
            return syncedCount
        } catch {
            ELOG("Error syncing ROMs: \(error.localizedDescription)")
            return 0
        }
    }

    /// Sync all save states to CloudKit
    /// - Parameter forceSync: If true, upload all save states regardless of existing cloudRecordID
    /// - Returns: Number of save states synced
    // TODO: I would prefer this not be main actor, but realm keeps crashing, even making a local realm @JoeMatt
    @MainActor
    private func syncAllSaveStates(forceSync: Bool = false) async -> Int {
        ILOG("[SYNC] Starting save state sync to CloudKit (forceSync: \(forceSync))...")
        DLOG("[SYNC] saveStatesSyncer type: \(type(of: saveStatesSyncer))")

        do {
            let realm = RomDatabase.sharedInstance.realm
            let saveStates = Array(realm.objects(PVSaveState.self)) // Convert to array to avoid invalidation

            ILOG("[SYNC] Found \(saveStates.count) save states in Realm")

            // Update progress
            var progress = await MainActor.run { syncProgressSubject.value }
            progress.saveStatesTotal = saveStates.count
            await MainActor.run {
                syncProgressSubject.send(progress)
            }

            // Use the injected save states syncer

                        // Sync each save state
            var syncedCount = 0
            for (index, saveState) in saveStates.enumerated() {
                // Skip logic: only skip if not forcing sync AND record has cloudRecordID
                if !forceSync && saveState.cloudRecordID != nil && !saveState.cloudRecordID!.isEmpty {
                    VLOG("Save state already synced: \(saveState.fileName)")

                    // Update progress
                    progress.saveStatesCompleted += 1
                    await MainActor.run {
                        syncProgressSubject.send(progress)
                    }

                    syncedCount += 1
                    continue
                }

                if forceSync {
                    DLOG("Force sync: uploading save state regardless of existing cloudRecordID: \(saveState.fileName)")
                } else {
                    DLOG("No cloudRecordID found, uploading save state: \(saveState.fileName)")
                }

                do {
                    // Upload save state using the protocol method
                    DLOG("Uploading save state \(index + 1)/\(saveStates.count): \(saveState.fileName)")
                    try await saveStatesSyncer.uploadSaveState(for: saveState).toAsync()

                    syncedCount += 1

                    // Update progress
                    progress.saveStatesCompleted += 1
                    await MainActor.run {
                        syncProgressSubject.send(progress)
                    }

                    DLOG("Successfully uploaded save state: \(saveState.fileName)")
                } catch {
                    ELOG("Error uploading save state \(saveState.fileName): \(error.localizedDescription)")

                    // Add to retry queue for later processing
                    let retryUpload = RetryableUpload(type: .saveState(id: saveState.id), error: error)
                    await addToRetryQueue(retryUpload)
                }
            }

            DLOG("Completed save state sync: \(syncedCount) of \(saveStates.count) save states synced")
            return syncedCount
        } catch {
            ELOG("Error syncing save states: \(error.localizedDescription)")
            return 0
        }
    }

    /// Sync all BIOS files to CloudKit
    /// - Parameter forceSync: If true, upload all BIOS files regardless of existing cloudRecordID
    /// - Returns: Number of BIOS files synced
    // TODO: I would prefer this not be main actor, but realm keeps crashing, even making a local realm @JoeMatt
    @MainActor
    private func syncAllBIOSFiles(forceSync: Bool = false) async -> Int {
        if CloudSyncManager.shared.isPausedForEmulation {
            ILOG("[BIOS SYNC] Skipping BIOS sync - paused for emulation")
            return 0
        }

        DLOG("Syncing all BIOS files to CloudKit...")

        do {
            let realm = RomDatabase.sharedInstance.realm
            let biosFiles = Array(realm.objects(PVBIOS.self))

            DLOG("Found \(biosFiles.count) BIOS files in Realm")

            // Update progress
            var progress = await MainActor.run { syncProgressSubject.value }
            progress.biosTotal = biosFiles.count
            await MainActor.run {
                syncProgressSubject.send(progress)
            }

            // Create CloudKit syncer with proper managed directories
            let errorHandler = CloudSyncErrorHandler()
            // Initialize with "BIOS" as the managed directory
            let syncer = CloudKitBIOSSyncer(container: container, directories: ["BIOS"], errorHandler: errorHandler)

            // Sync each BIOS file
            var syncedCount = 0
            for (index, bios) in biosFiles.enumerated() {
                let biosFilename = bios.file?.fileName ?? bios.expectedFilename

                // Skip if already synced - ALWAYS verify the record has asset
                if let existingRecordID = bios.cloudRecordID, !existingRecordID.isEmpty {
                    // Always verify the cloud record actually has a file asset
                    // This ensures records without assets get re-uploaded
                    DLOG("[BIOS SYNC] Verifying CloudKit asset for: \(biosFilename) (recordID: \(existingRecordID))")
                    let hasValidAsset = await verifyBIOSCloudAsset(recordID: existingRecordID, filename: biosFilename)
                    if !hasValidAsset {
                        let sanitizedRecordID = Self.sanitizeRecordNameComponent(existingRecordID)
                        if sanitizedRecordID != existingRecordID,
                           await verifyBIOSCloudAsset(recordID: sanitizedRecordID, filename: biosFilename) {
                            ILOG("[BIOS SYNC] ✓ Found BIOS asset under sanitized recordID: \(sanitizedRecordID)")
                            try? await realm.asyncWrite {
                                bios.cloudRecordID = sanitizedRecordID
                            }
                            progress.biosCompleted += 1
                            await MainActor.run { syncProgressSubject.send(progress) }
                            syncedCount += 1
                            continue
                        }
                        WLOG("[BIOS SYNC] Record \(existingRecordID) missing asset, will re-upload: \(biosFilename)")
                        // Clear the recordID so it gets re-uploaded below
                        try? await realm.asyncWrite {
                            bios.cloudRecordID = nil
                        }
                    } else {
                        ILOG("[BIOS SYNC] ✓ Verified asset exists for: \(biosFilename)")
                        progress.biosCompleted += 1
                        await MainActor.run { syncProgressSubject.send(progress) }
                        syncedCount += 1
                        continue
                    }
                }

                // Get BIOS file path
                guard let fileURL = bios.file?.url else {
                    WLOG("BIOS \(bios.expectedFilename) missing PVFile reference; skipping")
                    continue
                }

                guard let system = bios.system else {
                    ELOG("BIOS file has no system")
                    continue
                }
                // Check if file exists
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    WLOG("BIOS file does not exist at PVFile URL: \(fileURL.path)")
                    continue
                }

                do {
                    // Upload BIOS file to CloudKit
                    ILOG("[BIOS SYNC] Uploading BIOS file \(index + 1)/\(biosFiles.count): \(biosFilename)")
                    let parentDirectoryName = fileURL.deletingLastPathComponent().lastPathComponent
                    let systemID = SystemIdentifier(rawValue: parentDirectoryName)
                    let record = try await syncer.uploadFile(fileURL, gameID: nil as String?, systemID: systemID)

                    // Verify the upload actually has the asset
                    let hasAsset = record["fileData"] as? CKAsset != nil
                    ILOG("[BIOS SYNC] Upload complete for \(biosFilename): recordID=\(record.recordID.recordName), hasAsset=\(hasAsset)")

                    // Update Realm object with CloudKit record ID
                    try await realm.asyncWrite {
                        bios.cloudRecordID = record.recordID.recordName
                    }

                    syncedCount += 1

                    // Update progress
                    progress.biosCompleted += 1
                    await MainActor.run {
                        syncProgressSubject.send(progress)
                    }

                    ILOG("[BIOS SYNC] Successfully uploaded BIOS file: \(biosFilename), recordID: \(record.recordID.recordName)")
                } catch {
                    ELOG("[BIOS SYNC] Error uploading BIOS file \(biosFilename): \(error.localizedDescription)")
                }
            }

            ILOG("[BIOS SYNC] Completed BIOS sync: \(syncedCount) of \(biosFiles.count) BIOS files synced")
            return syncedCount
        } catch {
            ELOG("Error syncing BIOS files: \(error.localizedDescription)")
            return 0
        }
    }

    /// Verify that a CloudKit record for a BIOS file has a valid asset
    /// - Parameters:
    ///   - recordID: The CloudKit record ID
    ///   - filename: The filename (for logging)
    /// - Returns: True if the record exists and has a valid fileData asset
    private func verifyBIOSCloudAsset(recordID: String, filename: String) async -> Bool {
        let ckRecordID = CKRecord.ID(recordName: recordID)

        do {
            let record = try await container.privateCloudDatabase.record(for: ckRecordID)

            // Check if record has fileData asset
            if let asset = record["fileData"] as? CKAsset {
                // Check if asset has a valid file URL (it's cached locally after fetch)
                if let fileURL = asset.fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                    DLOG("[BIOS SYNC] Verified asset exists for \(filename): \(fileURL.path)")
                    return true
                } else {
                    // Asset exists but file might not be downloaded yet - still consider it valid
                    // CloudKit will download it when needed
                    DLOG("[BIOS SYNC] Asset exists for \(filename) but not yet downloaded locally")
                    return true
                }
            } else {
                WLOG("[BIOS SYNC] Record \(recordID) has no fileData asset for \(filename)")
                return false
            }
        } catch let ckError as CKError where ckError.code == .unknownItem {
            WLOG("[BIOS SYNC] Record not found in CloudKit for \(filename): \(recordID)")
            return false
        } catch {
            ELOG("[BIOS SYNC] Error verifying asset for \(filename): \(error.localizedDescription)")
            return false
        }
    }

    /// Normalize record name components for CloudKit record IDs
    nonisolated private static func sanitizeRecordNameComponent(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "_")
    }

    /// Sync all non-database files to CloudKit (Battery States, Screenshots, DeltaSkins)
    /// - Parameter forceSync: If true, upload all files regardless of existing records
    /// - Returns: Dictionary mapping directory names to sync counts
    private func syncAllNonDatabaseFiles(forceSync: Bool = false) async -> [String: Int] {
        DLOG("Syncing all non-database files to CloudKit...")

        do {
            // Use the injected non-database syncer
            // Get all files in all directories
            let allFiles = await nonDatabaseSyncer.getAllFiles()

            // Initialize results dictionary
            var syncCounts: [String: Int] = [:]

            // Update progress with total counts
            var progress = await MainActor.run { syncProgressSubject.value }

            // Process Battery States

            if let batteryStateFiles = allFiles["Battery States"]?.filter({ url in
                !url.pathDecoded.contains("DolphinData") &&
                !url.pathDecoded.contains("SaveStates")
            }) {
                progress.batteryStatesTotal = batteryStateFiles.count
                syncCounts["Battery States"] = await syncFiles(batteryStateFiles, using: nonDatabaseSyncer, progressUpdater: { completedCount in
                    progress.batteryStatesCompleted = completedCount
                    return progress
                })
            }

            // Process Screenshots
            if let screenshotFiles = allFiles["Screenshots"] {
                progress.screenshotsTotal = screenshotFiles.count
                syncCounts["Screenshots"] = await syncFiles(screenshotFiles, using: nonDatabaseSyncer, progressUpdater: { completedCount in
                    progress.screenshotsCompleted = completedCount
                    return progress
                })
            }

            // Process DeltaSkins
            if DeltaSkinSyncSupport.isEnabled,
               let deltaSkinFiles = allFiles[DeltaSkinSyncSupport.directoryName] {
                progress.deltaSkinsTotal = deltaSkinFiles.count
                syncCounts[DeltaSkinSyncSupport.directoryName] = await syncFiles(deltaSkinFiles, using: nonDatabaseSyncer, progressUpdater: { completedCount in
                    progress.deltaSkinsCompleted = completedCount
                    return progress
                })
            }

            // Log results and record analytics
            for (directory, count) in syncCounts {
                DLOG("Completed \(directory) sync: \(count) files synced")

                // Record analytics for each directory type
                DLOG("Recording analytics for \(directory) sync: \(count) files")
                await CloudKitSyncAnalytics.shared.recordSuccessfulSync()
            }

            return syncCounts
        } catch {
            ELOG("Error syncing non-database files: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Helper method to sync a list of files and update progress using batch processing
    /// - Parameters:
    ///   - files: Array of file URLs to sync
    ///   - syncer: The syncer to use for uploading
    ///   - progressUpdater: Closure that updates the progress with the completed count
    /// - Returns: Number of files successfully synced
    private func syncFiles(_ files: [URL], using syncer: any SyncProvider, progressUpdater: @escaping (Int) -> CloudKitInitialSyncProgress) async -> Int {
        // Respect emulation pause: skip non-database uploads during emulation
        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            WLOG("[INITIAL SYNC] Skipping file sync batch because sync is paused for emulation")
            return 0
        }

        var syncedCount = 0
        let totalFiles = files.count

        // Define batch size based on file count
        let batchSize = min(20, max(5, totalFiles / 10)) // Adaptive batch size
        DLOG("Using batch size of \(batchSize) for \(totalFiles) files")

        // Process files in batches
        for batchStart in stride(from: 0, to: files.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, files.count)
            let batch = Array(files[batchStart..<batchEnd])
            let batchRange = "\(batchStart + 1)-\(batchEnd)/\(totalFiles)"

            DLOG("Processing batch \(batchRange) with \(batch.count) files")

            // Create a task group for parallel processing within the batch
            var batchSuccessCount = 0
            var batchErrors: [String: Error] = [:]

            await withTaskGroup(of: (URL, Bool, Error?).self) { group in
                // Add tasks for each file in the batch
                for fileURL in batch {
                    group.addTask {
                        // Abort early if emulation pause engaged after the batch started
                        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
                            return (fileURL, false, CloudSyncError.genericError("Sync paused for emulation"))
                        }

                        // Check if file exists
                        guard FileManager.default.fileExists(atPath: fileURL.path) else {
                            WLOG("File does not exist: \(fileURL.path)")
                            return (fileURL, false, NSError(domain: "FileSystem", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"]))
                        }

                        do {
                            // Upload file
                            let parentDirectoryName = fileURL.deletingLastPathComponent().lastPathComponent
                            let systemID = SystemIdentifier(rawValue: parentDirectoryName)
                            // Cast to CloudKitNonDatabaseSyncer since we know it implements uploadFile
                            if let cloudKitSyncer = syncer as? CloudKitNonDatabaseSyncer {
                                _ = try await cloudKitSyncer.uploadFile(fileURL, gameID: nil as String?, systemID: systemID)
                                return (fileURL, true, nil)
                            } else {
                                return (fileURL, false, NSError(domain: "SyncError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Syncer does not support uploadFile"]))
                            }
                        } catch {
                            return (fileURL, false, error)
                        }
                    }
                }

                // Process results as they complete
                for await (fileURL, success, error) in group {
                    if success {
                        batchSuccessCount += 1
                        VLOG("Successfully uploaded file: \(fileURL.lastPathComponent)")
                    } else if let error = error {
                        batchErrors[fileURL.lastPathComponent] = error
                        ELOG("Error uploading file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }

            // Update total synced count
            syncedCount += batchSuccessCount

            // Log batch results
            DLOG("Batch \(batchRange) completed: \(batchSuccessCount)/\(batch.count) files successful, \(batchErrors.count) errors")

            // Update progress after each batch
            let updatedProgress = progressUpdater(syncedCount)
            await MainActor.run {
                syncProgressSubject.send(updatedProgress)
            }

            // Provide a summary of errors if any
            if !batchErrors.isEmpty {
                let errorSummary = batchErrors.keys.prefix(5).joined(separator: ", ")
                ELOG("Batch had \(batchErrors.count) errors. First few: \(errorSummary)\(batchErrors.count > 5 ? "..." : "")")
            }
        }

        return syncedCount
    }
}
