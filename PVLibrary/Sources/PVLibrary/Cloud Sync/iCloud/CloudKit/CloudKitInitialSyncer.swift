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

/// A class responsible for performing the initial sync of all local files to CloudKit
public actor CloudKitInitialSyncer {
    // MARK: - Properties

    /// Shared instance
    public static let shared = CloudKitInitialSyncer()

    /// CloudKit container
    private let container = iCloudConstants.container

    /// Private database
    private let privateDatabase: CKDatabase

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

    private init() {
        privateDatabase = container.privateCloudDatabase

        // Subscribe to progress updates
        syncProgressSubject
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncProgress)
    }

    // MARK: - Public Methods

    /// Check if initial sync is needed
    /// - Returns: True if initial sync is needed, false otherwise
    public func isInitialSyncNeeded() async -> Bool {
        do {
            // Check multiple record types, not just ROMs
            for recordTypeRaw in [CloudKitSchema.RecordType.rom.rawValue,
                               CloudKitSchema.RecordType.saveState.rawValue,
                               CloudKitSchema.RecordType.bios.rawValue,
                               CloudKitSchema.RecordType.file.rawValue] {

                DLOG("Checking for existing records of type: \(recordTypeRaw)")
                let query = CKQuery(recordType: recordTypeRaw, predicate: NSPredicate(value: true))

                // Use a task with timeout to prevent hanging if CloudKit is slow to respond
                let checkTask = Task {
                    try await privateDatabase.records(matching: query, resultsLimit: 1)
                }

                do {
                    // Set a 10-second timeout for the query
                    let (results, _) = try await withTimeout(seconds: 10) {
                        try await checkTask.value
                    }

                    // If we find records of any type, we don't need initial sync
                    if !results.isEmpty {
                        DLOG("Found existing \(recordTypeRaw) records, initial sync not needed")
                        return false
                    }
                } catch is TimeoutError {
                    ELOG("Timeout checking for \(recordTypeRaw) records, continuing with other types")
                    // Cancel the task to clean up resources
                    checkTask.cancel()
                    continue
                } catch {
                    ELOG("Error checking for \(recordTypeRaw) records: \(error.localizedDescription)")
                    // Continue checking other record types
                    continue
                }
            }

            // If we get here, we found no records of any type
            DLOG("No existing records found in CloudKit, initial sync needed")
            return true
        } catch {
            ELOG("Error checking if initial sync is needed: \(error.localizedDescription)")
            return true // Assume we need initial sync if we can't check
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
        // Check if sync is already in progress
        guard !isInitialSyncInProgress else {
            ILOG("Initial sync already in progress")
            return 0
        }

        // Check if sync is needed (unless forced)
        if !forceSync {
            let syncNeeded = await isInitialSyncNeeded()
            if !syncNeeded {
                ILOG("Initial sync not needed, skipping")
                return 0
            }
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
                await syncAllROMs()
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
        var saveStateCount = 0
        do {
            let saveStateSyncTask = Task {
                await syncAllSaveStates()
            }

            saveStateCount = try await withTimeout(seconds: 300) { // 5-minute timeout
                await saveStateSyncTask.value
            }

            progress.saveStatesTotal = saveStateCount
            progress.saveStatesCompleted = saveStateCount
            await MainActor.run {
                syncProgressSubject.send(progress)
            }

            DLOG("Successfully synced \(saveStateCount) save states")
            totalCount += saveStateCount
        } catch is TimeoutError {
            ELOG("Save state sync timed out after 5 minutes")
            overallSuccess = false
            // Continue with other sync operations
        } catch {
            ELOG("Error syncing save states: \(error.localizedDescription)")
            overallSuccess = false
            // Continue with other sync operations
        }

        // Sync BIOS files with timeout protection
        var biosCount = 0
        do {
            let biosSyncTask = Task {
                await syncAllBIOSFiles()
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
                await syncAllNonDatabaseFiles()
            }

            nonDatabaseFileCounts = try await withTimeout(seconds: 300) { // 5-minute timeout
                await nonDbSyncTask.value
            }

            // Extract individual counts for logging
            let batteryStateCount = nonDatabaseFileCounts["Battery States"] ?? 0
            let screenshotCount = nonDatabaseFileCounts["Screenshots"] ?? 0
            let deltaSkinCount = nonDatabaseFileCounts["DeltaSkins"] ?? 0

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

        // Set sync complete
        isInitialSyncInProgress = false

        // Record sync result
        if overallSuccess {
            await CloudKitSyncAnalytics.shared.recordSuccessfulSync()

            // Extract individual counts for logging
            let batteryStateCount = nonDatabaseFileCounts["Battery States"] ?? 0
            let screenshotCount = nonDatabaseFileCounts["Screenshots"] ?? 0
            let deltaSkinCount = nonDatabaseFileCounts["DeltaSkins"] ?? 0

            DLOG("""
                 Initial CloudKit sync completed successfully.
                 Synced \(totalCount) total records:
                 - \(romCount) ROMs
                 - \(saveStateCount) save states
                 - \(biosCount) BIOS files
                 - \(batteryStateCount) battery state files
                 - \(screenshotCount) screenshot files
                 - \(deltaSkinCount) Delta skin files
                 """)
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

            CloudKitSyncAnalytics.shared.recordFailedSync(error: error)
        }

        return totalCount
    }

    // MARK: - Private Methods

    /// Sync all ROMs to CloudKit
    /// - Returns: Number of ROMs synced
    // TODO: I would prefer this not be main actor, but realm keeps crashing, even making a local realm @JoeMatt
    @MainActor
    private func syncAllROMs() async -> Int {
        DLOG("Syncing all ROMs to CloudKit...")

        do {
            // Get all ROMs from Realm
            let realm = try! await Realm()
            let games = realm.objects(PVGame.self)

            DLOG("Found \(games.count) ROMs in Realm")

            // Update progress
            var progress = await MainActor.run { syncProgressSubject.value }
            progress.romsTotal = games.count
            await MainActor.run {
                syncProgressSubject.send(progress)
            }

            // Create CloudKit syncer from the shared manager
            guard let syncer = CloudSyncManager.shared.romsSyncer else {
                ELOG("RomsSyncer not available from CloudSyncManager.shared. Aborting ROM initial sync.")
                return 0 // Or throw an error?
            }

            // Sync each ROM
            var syncedCount = 0
            for (index, game) in games.enumerated() {
                // Skip if already synced
                if game.cloudRecordID != nil && !game.cloudRecordID!.isEmpty {
                    VLOG("ROM already synced: \(game.title) (\(game.md5))")

                    // Update progress
                    progress.romsCompleted += 1
                    await MainActor.run {
                        syncProgressSubject.send(progress)
                    }

                    syncedCount += 1
                    continue
                }

                do {
                    try await syncer.uploadGame(game)

                    syncedCount += 1
                    DLOG("Successfully initiated upload for ROM: \(game.title) (\(game.md5))")

                } catch let error as CloudSyncError {
                    if case .alreadyExists = error {
                         // If the record already exists (e.g., from a previous partial sync),
                         // we can count it as 'synced' for the initial sync purpose.
                         // We might want to verify the asset exists too, but for initial sync,
                         // assuming the record existing is enough.
                         WLOG("ROM \(game.title) (\(game.md5)) record already exists in CloudKit. Skipping initial upload.")
                         syncedCount += 1 // Count it as done for initial sync progress
                    } else {
                        ELOG("Error uploading ROM \(game.title) (\(game.md5)): \(error.localizedDescription)")
                        // Error is logged within uploadGame, but we log here too for context
                    }

                } catch {
                    ELOG("Error uploading ROM \(game.title) (\(game.md5)): \(error.localizedDescription)")
                }

                // Update progress (moved outside the try-catch for simplicity, updates regardless of success/failure/skip)
                progress.romsCompleted += 1
                await MainActor.run {
                    syncProgressSubject.send(progress)
                }
            }

            DLOG("Completed ROM sync: \(syncedCount) of \(games.count) ROMs synced")
            return syncedCount
        } catch {
            ELOG("Error syncing ROMs: \(error.localizedDescription)")
            return 0
        }
    }

    /// Sync all save states to CloudKit
    /// - Returns: Number of save states synced
    // TODO: I would prefer this not be main actor, but realm keeps crashing, even making a local realm @JoeMatt
    @MainActor
    private func syncAllSaveStates() async -> Int {
        DLOG("Syncing all save states to CloudKit...")

        do {
            // Get all save states from Realm
            let realm = try! await Realm()
            let saveStates = realm.objects(PVSaveState.self)

            DLOG("Found \(saveStates.count) save states in Realm")

            // Update progress
            var progress = await MainActor.run { syncProgressSubject.value }
            progress.saveStatesTotal = saveStates.count
            await MainActor.run {
                syncProgressSubject.send(progress)
            }

            // Create CloudKit syncer with proper managed directories
            let errorHandler = CloudSyncErrorHandler()
            // Initialize with both "Saves" and "Save States" as managed directories to handle different path formats
            let syncer = CloudKitSaveStatesSyncer(container: container, directories: ["Saves", "Save States"], errorHandler: errorHandler)

            // Sync each save state
            var syncedCount = 0
            for (index, saveState) in saveStates.enumerated() {
                // Skip if already synced
                if saveState.cloudRecordID != nil && !saveState.cloudRecordID!.isEmpty {
                    VLOG("Save state already synced: \(saveState.fileName)")

                    // Update progress
                    progress.saveStatesCompleted += 1
                    await MainActor.run {
                        syncProgressSubject.send(progress)
                    }

                    syncedCount += 1
                    continue
                }

                // Get save state file path
                guard let filePath = saveState.file?.partialPath else {
                    WLOG("Save state has no file path: \(saveState.fileName)")
                    continue
                }

                // Create proper file URL from path
                // First, check if the path is already absolute
                let fileURL: URL
                if filePath.hasPrefix("/") {
                    // Path is already absolute
                    fileURL = URL(fileURLWithPath: filePath)
                } else {
                    // Path is relative, construct from documents directory
                    let documentsURL = URL.documentsPath
                    fileURL = documentsURL.appendingPathComponent(filePath)
                }

                DLOG("Save state file path: \(fileURL.path)")

                // Check if file exists
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    WLOG("Save state file does not exist: \(fileURL.path)")
                    continue
                }

                do {
                    // Upload save state to CloudKit
                    DLOG("Uploading save state \(index + 1)/\(saveStates.count): \(saveState.fileName)")
                    let record = try await syncer.uploadFile(fileURL, gameID: saveState.game.id, systemID: saveState.game.system?.systemIdentifier)

                    // Update Realm object with CloudKit record ID
                    try await realm.asyncWrite {
                        saveState.cloudRecordID = record.recordID.recordName
                    }

                    syncedCount += 1

                    // Update progress
                    progress.saveStatesCompleted += 1
                    await MainActor.run {
                        syncProgressSubject.send(progress)
                    }

                    DLOG("Successfully uploaded save state: \(saveState.fileName)")
                } catch {
                    ELOG("Error uploading save state \(saveState.fileName): \(error.localizedDescription)")
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
    /// - Returns: Number of BIOS files synced
    // TODO: I would prefer this not be main actor, but realm keeps crashing, even making a local realm @JoeMatt
    @MainActor
    private func syncAllBIOSFiles() async -> Int {
        DLOG("Syncing all BIOS files to CloudKit...")

        do {
            // Get all BIOS files from Realm
            let realm = try! await Realm()
            let biosFiles = realm.objects(PVBIOS.self)

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
                // Skip if already synced
                if bios.cloudRecordID != nil && !bios.cloudRecordID!.isEmpty {
                    VLOG("BIOS file already synced: \(bios.file?.fileName ?? "")")

                    // Update progress
                    progress.biosCompleted += 1
                    await MainActor.run {
                        syncProgressSubject.send(progress)
                    }

                    syncedCount += 1
                    continue
                }

                // Get BIOS file path
                guard let fileName = bios.file?.fileName else {
                    WLOG("BIOS file has no filename")
                    continue
                }

                guard let system = bios.system else {
                    ELOG("BIOS file has no system")
                    continue
                }
                let biosDirectory = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system.identifier)

                let fileURL = biosDirectory.appendingPathComponent(fileName)

                // Check if file exists
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    WLOG("BIOS file does not exist: \(fileURL.path)")
                    continue
                }

                do {
                    // Upload BIOS file to CloudKit
                    DLOG("Uploading BIOS file \(index + 1)/\(biosFiles.count): \(bios.file?.fileName ?? "")")
                    let parentDirectoryName = fileURL.deletingLastPathComponent().lastPathComponent
                    let systemID = SystemIdentifier(rawValue: parentDirectoryName)
                    let record = try await syncer.uploadFile(fileURL, gameID: nil, systemID: systemID)

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

                    DLOG("Successfully uploaded BIOS file: \(bios.file?.fileName ?? "")")
                } catch {
                    ELOG("Error uploading BIOS file \(bios.file?.fileName ?? ""): \(error.localizedDescription)")
                }
            }

            DLOG("Completed BIOS sync: \(syncedCount) of \(biosFiles.count) BIOS files synced")
            return syncedCount
        } catch {
            ELOG("Error syncing BIOS files: \(error.localizedDescription)")
            return 0
        }
    }

    /// Sync all non-database files to CloudKit (Battery States, Screenshots, DeltaSkins)
    /// - Returns: Dictionary mapping directory names to sync counts
    private func syncAllNonDatabaseFiles() async -> [String: Int] {
        DLOG("Syncing all non-database files to CloudKit...")

        do {
            // Create CloudKit syncer for non-database files
            let errorHandler = CloudSyncErrorHandler()
            let syncer = CloudKitNonDatabaseSyncer(container: container, errorHandler: errorHandler)

            // Get all files in all directories
            let allFiles = await syncer.getAllFiles()

            // Initialize results dictionary
            var syncCounts: [String: Int] = [:]

            // Update progress with total counts
            var progress = await MainActor.run { syncProgressSubject.value }

            // Process Battery States
            if let batteryStateFiles = allFiles["Battery States"] {
                progress.batteryStatesTotal = batteryStateFiles.count
                syncCounts["Battery States"] = await syncFiles(batteryStateFiles, using: syncer, progressUpdater: { completedCount in
                    progress.batteryStatesCompleted = completedCount
                    return progress
                })
            }

            // Process Screenshots
            if let screenshotFiles = allFiles["Screenshots"] {
                progress.screenshotsTotal = screenshotFiles.count
                syncCounts["Screenshots"] = await syncFiles(screenshotFiles, using: syncer, progressUpdater: { completedCount in
                    progress.screenshotsCompleted = completedCount
                    return progress
                })
            }

            // Process DeltaSkins
            if let deltaSkinFiles = allFiles["DeltaSkins"] {
                progress.deltaSkinsTotal = deltaSkinFiles.count
                syncCounts["DeltaSkins"] = await syncFiles(deltaSkinFiles, using: syncer, progressUpdater: { completedCount in
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
    private func syncFiles(_ files: [URL], using syncer: CloudKitSyncer, progressUpdater: @escaping (Int) -> CloudKitInitialSyncProgress) async -> Int {
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
                        // Check if file exists
                        guard FileManager.default.fileExists(atPath: fileURL.path) else {
                            WLOG("File does not exist: \(fileURL.path)")
                            return (fileURL, false, NSError(domain: "FileSystem", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"]))
                        }

                        do {
                            // Upload file
                            let parentDirectoryName = fileURL.deletingLastPathComponent().lastPathComponent
                            let systemID = SystemIdentifier(rawValue: parentDirectoryName)
                            _ = try await syncer.uploadFile(fileURL, gameID: nil, systemID: systemID)
                            return (fileURL, true, nil)
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
