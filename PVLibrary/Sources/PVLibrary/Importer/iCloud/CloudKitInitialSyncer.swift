//
//  CloudKitInitialSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
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
    private let container = CKContainer(identifier: iCloudConstants.containerIdentifier)
    
    /// Private database
    private let privateDatabase: CKDatabase
    
    /// Sync progress publisher
    private let syncProgressSubject = CurrentValueSubject<InitialSyncProgress, Never>(InitialSyncProgress())
    
    /// Sync progress publisher
    public var syncProgressPublisher: AnyPublisher<InitialSyncProgress, Never> {
        syncProgressSubject.eraseToAnyPublisher()
    }
    
    /// Current sync progress
    @Published public private(set) var syncProgress = InitialSyncProgress()
    
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
            // Check if we have any records in CloudKit
            let query = CKQuery(recordType: CloudKitSchema.RecordType.rom, predicate: NSPredicate(value: true))
            let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: 1)
            
            // If we have no records, we need an initial sync
            return results.isEmpty
        } catch {
            ELOG("Error checking if initial sync is needed: \(error.localizedDescription)")
            return true // Assume we need initial sync if we can't check
        }
    }
    
    /// Perform initial sync of all local files to CloudKit
    /// - Returns: Number of records synced
    @discardableResult
    public func performInitialSync() async -> Int {
        guard !isInitialSyncInProgress else {
            DLOG("Initial sync already in progress")
            return 0
        }
        
        // Set sync in progress
        isInitialSyncInProgress = true
        
        // Reset progress
        var progress = InitialSyncProgress()
        await MainActor.run {
            syncProgressSubject.send(progress)
        }
        
        DLOG("""
             Starting initial CloudKit sync...
             This will upload all local files to CloudKit.
             """)
        
        // Start analytics tracking
        await CloudKitSyncAnalytics.shared.startSync(operation: "Initial CloudKit Sync")
        
        do {
            // Sync ROMs
            let romCount = await syncAllROMs()
            progress.romsTotal = romCount
            progress.romsCompleted = romCount
            await MainActor.run {
                syncProgressSubject.send(progress)
            }
            
            // Sync save states
            let saveStateCount = await syncAllSaveStates()
            progress.saveStatesTotal = saveStateCount
            progress.saveStatesCompleted = saveStateCount
            await MainActor.run {
                syncProgressSubject.send(progress)
            }
            
            // Sync BIOS files
            let biosCount = await syncAllBIOSFiles()
            progress.biosTotal = biosCount
            progress.biosCompleted = biosCount
            await MainActor.run {
                syncProgressSubject.send(progress)
            }
            
            // Sync all non-database files (Battery States, Screenshots, DeltaSkins)
            let nonDatabaseFileCounts = await syncAllNonDatabaseFiles()
            
            // Extract individual counts for logging
            let batteryStateCount = nonDatabaseFileCounts["Battery States"] ?? 0
            let screenshotCount = nonDatabaseFileCounts["Screenshots"] ?? 0
            let deltaSkinCount = nonDatabaseFileCounts["DeltaSkins"] ?? 0
            
            // Calculate total
            let totalCount = romCount + saveStateCount + biosCount + batteryStateCount + screenshotCount + deltaSkinCount
            
            // Complete progress
            progress.isComplete = true
            await MainActor.run {
                syncProgressSubject.send(progress)
            }
            
            // Set sync complete
            isInitialSyncInProgress = false
            
            // Record successful sync
            await CloudKitSyncAnalytics.shared.recordSuccessfulSync()
            
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
            
            return totalCount
        } catch {
            // Set sync complete
            isInitialSyncInProgress = false
            
            // Record failed sync
            CloudKitSyncAnalytics.shared.recordFailedSync(error: error)
            
            ELOG("Error performing initial CloudKit sync: \(error.localizedDescription)")
            return 0
        }
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
            let realm = RomDatabase.sharedInstance.realm
            let games = realm.objects(PVGame.self)
            
            DLOG("Found \(games.count) ROMs in Realm")
            
            // Update progress
            var progress = await MainActor.run { syncProgressSubject.value }
            progress.romsTotal = games.count
            await MainActor.run {
                syncProgressSubject.send(progress)
            }
            
            // Create CloudKit syncer
            let errorHandler = CloudSyncErrorHandler()
            let syncer = CloudKitRomsSyncer(errorHandler: errorHandler)
            
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
                
                // Get ROM file path
                let romPath = game.romPath
                guard let romURL = URL(string: romPath) else {
                    WLOG("ROM has no valid file path: \(game.title) (\(game.md5))")
                    continue
                }
                
                // Check if file exists
                guard FileManager.default.fileExists(atPath: romURL.path) else {
                    WLOG("ROM file does not exist: \(romURL.path)")
                    continue
                }
                
                do {
                    // Upload ROM to CloudKit
                    DLOG("Uploading ROM \(index + 1)/\(games.count): \(game.title)")
                    let record = try await syncer.uploadFile(romURL)
                    
                    // Update Realm object with CloudKit record ID
                    try await realm.asyncWrite {
                        game.cloudRecordID = record.recordID.recordName
                    }
                    
                    syncedCount += 1
                    
                    // Update progress
                    progress.romsCompleted += 1
                    await MainActor.run {
                        syncProgressSubject.send(progress)
                    }
                    
                    DLOG("Successfully uploaded ROM: \(game.title) (\(game.md5))")
                } catch {
                    ELOG("Error uploading ROM \(game.title): \(error.localizedDescription)")
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
            let realm = RomDatabase.sharedInstance.realm
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
            let syncer = CloudKitSaveStatesSyncer(directories: ["Saves", "Save States"], errorHandler: errorHandler)
            
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
                    let record = try await syncer.uploadFile(fileURL)
                    
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
            let realm = RomDatabase.sharedInstance.realm
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
            let syncer = CloudKitBIOSSyncer(directories: ["BIOS"], errorHandler: errorHandler)
            
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
                let biosDirectory = PVEmulatorConfiguration.biosPath(forSystemIdentifier: bios.system.identifier)
                guard let fileName = bios.file?.fileName else {
                    WLOG("BIOS file has no filename")
                    continue
                }
                let fileURL = biosDirectory.appendingPathComponent(fileName)
                
                // Check if file exists
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    WLOG("BIOS file does not exist: \(fileURL.path)")
                    continue
                }
                
                do {
                    // Upload BIOS file to CloudKit
                    DLOG("Uploading BIOS file \(index + 1)/\(biosFiles.count): \(bios.file?.fileName ?? "")")
                    let record = try await syncer.uploadFile(fileURL)
                    
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
            let syncer = CloudKitNonDatabaseSyncer(errorHandler: errorHandler)
            
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
    
    /// Helper method to sync a list of files and update progress
    /// - Parameters:
    ///   - files: Array of file URLs to sync
    ///   - syncer: The syncer to use for uploading
    ///   - progressUpdater: Closure that updates the progress with the completed count
    /// - Returns: Number of files successfully synced
    private func syncFiles(_ files: [URL], using syncer: CloudKitSyncer, progressUpdater: @escaping (Int) -> InitialSyncProgress) async -> Int {
        var syncedCount = 0
        
        for (index, fileURL) in files.enumerated() {
            do {
                // Upload file to CloudKit
                DLOG("Uploading file \(index + 1)/\(files.count): \(fileURL.lastPathComponent)")
                
                // Check if file exists
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    WLOG("File does not exist: \(fileURL.path)")
                    continue
                }
                
                // Upload file
                _ = try await syncer.uploadFile(fileURL)
                
                syncedCount += 1
                
                // Update progress
                let updatedProgress = progressUpdater(syncedCount)
                await MainActor.run {
                    syncProgressSubject.send(updatedProgress)
                }
                
                DLOG("Successfully uploaded file: \(fileURL.lastPathComponent)")
            } catch {
                ELOG("Error uploading file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        return syncedCount
    }
}

public struct InitialSyncProgress {
    /// Total number of ROMs to sync
    public var romsTotal: Int = 0
    
    /// Number of ROMs synced
    public var romsCompleted: Int = 0
    
    /// Total number of save states to sync
    public var saveStatesTotal: Int = 0
    
    /// Number of save states synced
    public var saveStatesCompleted: Int = 0
    
    /// Total number of BIOS files to sync
    public var biosTotal: Int = 0
    
    /// Number of BIOS files synced
    public var biosCompleted: Int = 0
    
    /// Total number of battery states to sync
    public var batteryStatesTotal: Int = 0
    
    /// Number of battery states synced
    public var batteryStatesCompleted: Int = 0
    
    /// Total number of screenshots to sync
    public var screenshotsTotal: Int = 0
    
    /// Number of screenshots synced
    public var screenshotsCompleted: Int = 0
    
    /// Total number of Delta skins to sync
    public var deltaSkinsTotal: Int = 0
    
    /// Number of Delta skins synced
    public var deltaSkinsCompleted: Int = 0
    
    /// Whether the sync is complete
    public var isComplete: Bool = false
    
    /// Overall progress (0.0 - 1.0)
    public var overallProgress: Double {
        let total = Double(romsTotal + saveStatesTotal + biosTotal + batteryStatesTotal + screenshotsTotal + deltaSkinsTotal)
        let completed = Double(romsCompleted + saveStatesCompleted + biosCompleted + batteryStatesCompleted + screenshotsCompleted + deltaSkinsCompleted)
        
        guard total > 0 else { return 0 }
        return completed / total
    }
}
