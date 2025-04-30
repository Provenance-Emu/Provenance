//
//  CloudSyncManager.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import PVLogging
import PVPrimitives
import PVFileSystem
import PVRealm
import RealmSwift
import RxSwift
import Defaults
import PVSettings
import CloudKit

/// Manager for cloud sync operations
/// Handles initialization and coordination of sync providers
public class CloudSyncManager {
    // MARK: - Properties
    
    /// Shared instance
    public static let shared = CloudSyncManager(container: iCloudConstants.container)
    
    /// ROM syncer
    internal var romsSyncer: RomsSyncing?
    
    /// Save states syncer
    internal var saveStatesSyncer: SaveStatesSyncing?
    
    /// BIOS syncer
    internal var biosSyncer: BIOSSyncing?
    
    /// Non-database syncer for files like Battery States, Screenshots, and DeltaSkins
    internal var nonDatabaseSyncer: CloudKitNonDatabaseSyncer?
    
    /// Error handler
    private let errorHandler = CloudSyncErrorHandler()
    
    /// Disposable for subscriptions
    private var disposeBag = DisposeBag()
    
    /// Publisher for sync status changes
    private let syncStatusSubject = PassthroughSubject<SyncStatus, Never>()
    
    /// Publisher for sync status
    public var syncStatusPublisher: AnyPublisher<SyncStatus, Never> {
        syncStatusSubject.eraseToAnyPublisher()
    }
    
    /// Current sync status
    @Published public private(set) var syncStatus: SyncStatus = .idle
    
    /// Current sync info - used to provide additional context about the current operation
    @Published public var currentSyncInfo: [String: Any]? = nil
    
    /// Notification tokens
    private var notificationTokens: [NSObjectProtocol] = []
    
    /// CloudKit Container
    private let container: CKContainer
    
    // MARK: - Initialization
    
    /// Private initializer for singleton
    private init(container: CKContainer) {
        self.container = container
        
        Task { [weak self] in
            // Register for notifications
            await self?.registerForNotifications()
        }
        
        // Initialize sync providers if iCloud sync is enabled
        if Defaults[.iCloudSync] {
            initializeSyncProviders()
        }
    }
    
    deinit {
        // Unregister from notifications
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    // MARK: - Public Methods
    
    /// Start syncing
    /// - Returns: Completable that completes when initial sync is done
    @discardableResult
    public func startSync() async -> Completable {
        guard Defaults[.iCloudSync] else {
            return Completable.empty()
        }
        
        // Initialize sync providers if not already initialized
        if romsSyncer == nil || saveStatesSyncer == nil || biosSyncer == nil {
            initializeSyncProviders()
        }
        
        // Update sync status
        updateSyncStatus(.syncing)
        
        // Always perform an initial sync to ensure all local files are in CloudKit
        DLOG("Performing full sync of local files to CloudKit")
        updateSyncStatus(.initialSync)
        
        // Force a sync of all local files to CloudKit
        let syncCount = await CloudKitInitialSyncer.shared.performInitialSync(forceSync: true)
        DLOG("CloudKit sync completed - synced \(syncCount) records")
        
        // Create completables for each sync provider
        let completables: [Completable] = [
            await romsSyncer?.loadAllFromCloud(iterationComplete: nil) ?? Completable.empty(),
            await saveStatesSyncer?.loadAllFromCloud(iterationComplete: nil) ?? Completable.empty(),
            await biosSyncer?.loadAllFromCloud(iterationComplete: nil) ?? Completable.empty()
        ]
        
        // Combine completables
        let combined = Completable.concat(completables)
        
        // Handle completion
        return combined
            .do(onError: { [weak self] error in
                ELOG("Sync failed: \(error.localizedDescription)")
                self?.updateSyncStatus(.error(error))
            }, onCompleted: { [weak self] in
                DLOG("Sync completed successfully")
                self?.updateSyncStatus(.idle)
            })
    }
    
    /// Upload a ROM file to the cloud
    /// - Parameter game: The game to upload
    /// - Returns: Completable that completes when the upload is done
    public func uploadROM(for game: PVGame) -> Completable {
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer else {
            return Completable.empty()
        }
        
        return romsSyncer.uploadROM(for: game)
            .do(onError: { [weak self] error in
                ELOG("Failed to upload ROM: \(error.localizedDescription)")
                self?.updateSyncStatus(.error(error))
            }, onCompleted: { [weak self] in
                DLOG("Successfully uploaded ROM: \(game.title)")
                self?.updateSyncStatus(.idle)
            })
    }
    
    /// Download a ROM file from the cloud
    /// - Parameter game: The game to download
    /// - Returns: Completable that completes when the download is done
    public func downloadROM(for game: PVGame) -> Completable {
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer else {
            return Completable.empty()
        }
        
        updateSyncStatus(.downloading)
        
        return romsSyncer.downloadROM(for: game)
            .do(onError: { [weak self] error in
                ELOG("Failed to download ROM: \(error.localizedDescription)")
                self?.updateSyncStatus(.error(error))
            }, onCompleted: { [weak self] in
                DLOG("Successfully downloaded ROM: \(game.title)")
                self?.updateSyncStatus(.idle)
            })
    }
    
    /// Upload a save state to the cloud
    /// - Parameter saveState: The save state to upload
    /// - Returns: Completable that completes when the upload is done
    public func uploadSaveState(for saveState: PVSaveState) -> Completable {
        guard Defaults[.iCloudSync], let saveStatesSyncer = saveStatesSyncer else {
            return Completable.empty()
        }
        
        updateSyncStatus(.uploading)
        
        return saveStatesSyncer.uploadSaveState(for: saveState)
            .do(onError: { [weak self] error in
                ELOG("Failed to upload save state: \(error.localizedDescription)")
                self?.updateSyncStatus(.error(error))
            }, onCompleted: { [weak self] in
                DLOG("Successfully uploaded save state for game: \(saveState.game.title)")
                self?.updateSyncStatus(.idle)
            })
    }
    
    /// Download a save state from the cloud
    /// - Parameter saveState: The save state to download
    /// - Returns: Completable that completes when the download is done
    public func downloadSaveState(for saveState: PVSaveState) -> Completable {
        guard Defaults[.iCloudSync], let saveStatesSyncer = saveStatesSyncer else {
            return Completable.empty()
        }
        
        updateSyncStatus(.downloading)
        
        return saveStatesSyncer.downloadSaveState(for: saveState)
            .do(onError: { [weak self] error in
                ELOG("Failed to download save state: \(error.localizedDescription)")
                self?.updateSyncStatus(.error(error))
            }, onCompleted: { [weak self] in
                DLOG("Successfully downloaded save state for game: \(saveState.game.title)")
                self?.updateSyncStatus(.idle)
            })
    }
    
    /// Get the local URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The local URL for the ROM file
    public func localROMURL(for game: PVGame) -> URL? {
        return romsSyncer?.localURL(for: game)
    }
    
    /// Get the cloud URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The cloud URL for the ROM file
    public func cloudROMURL(for game: PVGame) -> URL? {
        return romsSyncer?.cloudURL(for: game)
    }
    
    /// Get the local URL for a save state
    /// - Parameter saveState: The save state to get the URL for
    /// - Returns: The local URL for the save state file
    public func localSaveStateURL(for saveState: PVSaveState) -> URL? {
        return saveStatesSyncer?.localURL(for: saveState)
    }
    
    /// Get the cloud URL for a save state
    /// - Parameter saveState: The save state to get the URL for
    /// - Returns: The cloud URL for the save state file
    public func cloudSaveStateURL(for saveState: PVSaveState) -> URL? {
        return saveStatesSyncer?.cloudURL(for: saveState)
    }
    
    // MARK: - Private Methods
    
    /// Initialize sync providers
    private func initializeSyncProviders() {
        // Create error handler
        let syncErrorHandler = CloudSyncErrorHandler()
        
        // Create ROM syncer using factory
        romsSyncer = SyncProviderFactory.createROMSyncProvider(
            container: container,
            notificationCenter: NotificationCenter.default,
            errorHandler: syncErrorHandler
        )
        
        // Create save states syncer using factory
        saveStatesSyncer = SyncProviderFactory.createSaveStatesSyncProvider(
            notificationCenter: NotificationCenter.default,
            errorHandler: syncErrorHandler
        )
        
        // Create BIOS syncer using factory
        biosSyncer = SyncProviderFactory.createBIOSSyncProvider(
            notificationCenter: NotificationCenter.default,
            errorHandler: syncErrorHandler
        )
        
        // Create non-database syncer for Battery States, Screenshots, and DeltaSkins
        let nonDatabaseDirectories: Set<String> = ["Battery States", "Screenshots", "RetroArch", "DeltaSkins"]
        nonDatabaseSyncer = SyncProviderFactory.createNonDatabaseSyncProvider(
            container: container,
            for: nonDatabaseDirectories,
            notificationCenter: NotificationCenter.default,
            errorHandler: syncErrorHandler
        )
        
        DLOG("Initialized cloud sync providers")
    }
    
    /// Register for notifications
    private func registerForNotifications() async {
        // Register for iCloud sync enabled/disabled notifications
        let enabledToken = NotificationCenter.default.addObserver(
            forName: .iCloudSyncEnabled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleSyncEnabled()
            }
        }
        
        let disabledToken = NotificationCenter.default.addObserver(
            forName: .iCloudSyncDisabled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSyncDisabled()
        }
        
        // Register for game added/deleted notifications
        let gameAddedToken = NotificationCenter.default.addObserver(
            forName: .GameAdded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let game = notification.object as? PVGame {
                self?.handleGameAdded(game)
            }
        }
        
        let gameDeletedToken = NotificationCenter.default.addObserver(
            forName: .GameDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let game = notification.object as? PVGame {
                Task {
                    await self?.handleGameDeleted(game)
                }
            }
        }
        
        // Register for save state added/deleted notifications
        let saveStateAddedToken = NotificationCenter.default.addObserver(
            forName: .SaveStateAdded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let saveState = notification.object as? PVSaveState {
                self?.handleSaveStateAdded(saveState)
            }
        }
        
        let saveStateDeletedToken = NotificationCenter.default.addObserver(
            forName: .SaveStateDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let saveState = notification.object as? PVSaveState {
                Task {
                    await self?.handleSaveStateDeleted(saveState)
                }
            }
        }
        
        // Store tokens for cleanup
        notificationTokens = [
            enabledToken,
            disabledToken,
            gameAddedToken,
            gameDeletedToken,
            saveStateAddedToken,
            saveStateDeletedToken
        ]
    }
    
    /// Handle iCloud sync enabled
    private func handleSyncEnabled() async {
        DLOG("iCloud sync enabled")
        
        // Initialize sync providers if not already initialized
        if romsSyncer == nil || saveStatesSyncer == nil || biosSyncer == nil {
            initializeSyncProviders()
        }
        
        // Start initial sync
        await startSync()
            .subscribe()
            .disposed(by: disposeBag)
    }
    
    /// Handle iCloud sync disabled
    private func handleSyncDisabled() {
        DLOG("iCloud sync disabled")
        
        // Clear sync providers
        romsSyncer = nil
        saveStatesSyncer = nil
        biosSyncer = nil
        
        // Update sync status
        updateSyncStatus(.disabled)
        
        // Clear disposable
        disposeBag = DisposeBag()
    }
    
    /// Handle game added
    private func handleGameAdded(_ game: PVGame) {
        guard Defaults[.iCloudSync] else {
            return
        }
        
        DLOG("Game added: \(game.title)")
        
        // Upload ROM if auto-sync is enabled
        if Defaults[.autoSyncNewContent] {
            _ = uploadROM(for: game)
                .subscribe()
                .disposed(by: disposeBag)
        }
    }
    
    /// Handle game deleted
    private func handleGameDeleted(_ game: PVGame) async {
        guard Defaults[.iCloudSync] else {
            return
        }
        
        DLOG("Game deleted: \(game.title)")
        
        // Delete ROM from cloud if needed
        if let cloudURL = cloudROMURL(for: game) {
            await romsSyncer?.deleteFromDatastore(cloudURL)
        }
    }
    
    /// Handle save state added
    private func handleSaveStateAdded(_ saveState: PVSaveState) {
        guard Defaults[.iCloudSync] else {
            return
        }
        
        DLOG("Save state added for game: \(saveState.game.title)")
        
        // Upload save state if auto-sync is enabled
        if Defaults[.autoSyncNewContent] {
            _ = uploadSaveState(for: saveState)
                .subscribe()
                .disposed(by: disposeBag)
        }
    }
    
    /// Handle save state deleted
    private func handleSaveStateDeleted(_ saveState: PVSaveState) async {
        guard Defaults[.iCloudSync] else {
            return
        }
        
        DLOG("Save state deleted for game: \(saveState.game.title)")
        
        // Delete save state from cloud if needed
        if let cloudURL = cloudSaveStateURL(for: saveState) {
            await saveStatesSyncer?.deleteFromDatastore(cloudURL)
        }
    }
    
    /// Update sync status
    private func updateSyncStatus(_ status: SyncStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.syncStatus = status
            self?.syncStatusSubject.send(status)
        }
    }
}

/// Sync status
public enum SyncStatus: Equatable {
    /// Idle - no sync in progress
    case idle
    
    /// Syncing - sync in progress
    case syncing
    
    /// Initial sync - first-time sync of all local files
    case initialSync
    
    /// Uploading - upload in progress
    case uploading
    
    /// Downloading - download in progress
    case downloading
    
    /// Error - sync error
    case error(Error)
    
    /// Disabled - sync is disabled
    case disabled
    
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.initialSync, .initialSync), (.uploading, .uploading), (.downloading, .downloading), (.disabled, .disabled):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Notification sent when iCloud sync is enabled
    public static let iCloudSyncEnabled = Notification.Name("iCloudSyncEnabled")
    
    /// Notification sent when iCloud sync is disabled
    public static let iCloudSyncDisabled = Notification.Name("iCloudSyncDisabled")
    
    /// Notification sent when iCloud sync is completed
    public static let iCloudSyncCompleted = Notification.Name("iCloudSyncCompleted")
    
    /// Notification sent when a game is added
    public static let GameAdded = Notification.Name("GameAdded")
    
    /// Notification sent when a game is deleted
    public static let GameDeleted = Notification.Name("GameDeleted")
    
    /// Notification sent when a save state is added
    public static let SaveStateAdded = Notification.Name("SaveStateAdded")
    
    /// Notification sent when a save state is deleted
    public static let SaveStateDeleted = Notification.Name("SaveStateDeleted")
    
    /// Notification sent when a ROM download is completed
    public static let romDownloadCompleted = Notification.Name("romDownloadCompleted")
}
