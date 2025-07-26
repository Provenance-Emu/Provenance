//
//  CloudSyncManager.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import PVLogging
import PVPrimitives
import PVFileSystem
import PVRealm
import RealmSwift
import Defaults
import PVSettings
import CloudKit
import RxSwift

/// Represents the current state of the Cloud Sync process.
extension CloudSyncManager {
    public enum SyncStatus: Equatable {
        /// Idle - no sync in progress
        case idle

        /// Syncing - general sync in progress (use more specific states if possible)
        case syncing

        /// Initial sync - first-time sync or checking all records
        case initialSync

        /// Uploading - upload in progress
        case uploading

        /// Downloading - download in progress
        case downloading

        /// Initializing - sync providers are being set up
        case initializing

        /// Error - sync encountered an error
        case error(Error)

        /// Disabled - sync is turned off in settings
        case disabled

        public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                (.syncing, .syncing),
                (.initialSync, .initialSync),
                (.uploading, .uploading),
                (.downloading, .downloading),
                (.initializing, .initializing),
                (.disabled, .disabled):
                return true
            case let (.error(lhsError), .error(rhsError)):
                // Optionally compare errors more specifically if needed
                return (lhsError as NSError).domain == (rhsError as NSError).domain &&
                (lhsError as NSError).code == (rhsError as NSError).code
            default:
                return false
            }
        }
    }
}

/// Manager for cloud sync operations
/// Handles initialization and coordination of sync providers
public class CloudSyncManager {
    // MARK: - Properties

    /// Shared instance
    public static let shared = CloudSyncManager(container: iCloudConstants.container)

    /// ROM syncer
    public var romsSyncer: RomsSyncing?

    /// Save states syncer
    public var saveStatesSyncer: SaveStatesSyncing?

    /// Non-database syncer for files like BIOS, Battery States, Screenshots, and DeltaSkins
    public var nonDatabaseSyncer: CloudKitNonDatabaseSyncer?

    /// Error handler
    public let errorHandler = CloudSyncErrorHandler()

    /// Disposable for subscriptions
    private var disposeBag = DisposeBag()
    private var cancellables = Set<AnyCancellable>()

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
        registerForNotifications()
        setupObservers()

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
        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Start syncing
    /// - Returns: Async function completes when initial sync is done (or immediately if not needed/disabled)
    public func startSync() async {
        guard Defaults[.iCloudSync] else {
            DLOG("iCloud sync disabled, skipping startSync.")
            updateSyncStatus(.disabled)
            return
        }

        // Initialize sync providers if needed
        if romsSyncer == nil || saveStatesSyncer == nil || nonDatabaseSyncer == nil {
            ILOG("Initializing sync providers...")
            initializeSyncProviders()
        }

        guard romsSyncer != nil || saveStatesSyncer != nil || nonDatabaseSyncer != nil else {
            ELOG("Sync providers failed to initialize. Aborting sync.")
            updateSyncStatus(.error(CloudSyncError.missingDependency))
            return
        }

        updateSyncStatus(.syncing)
        DLOG("Performing initial sync check and potentially syncing all local files to CloudKit...")
        updateSyncStatus(.initialSync)

        var hasErrors = false
        var lastError: Error?
        
        // Perform initial sync (this checks if needed internally unless forced)
        do {
            let syncCount = await CloudKitInitialSyncer.shared.performInitialSync(forceSync: false)
            DLOG("CloudKit initial sync completed - potentially uploaded \(syncCount) new records.")
        } catch {
            ELOG("CloudKit initial sync failed: \(error.localizedDescription)")
            hasErrors = true
            lastError = error
            await errorHandler.handle(error: error)
        }

        // Fetch remote changes from CloudKit only if initial sync didn't fail
        if !hasErrors {
            DLOG("Fetching remote changes from CloudKit...")
            updateSyncStatus(.downloading)
            await fetchRemoteChanges()
        }

        // Update status based on results
        if hasErrors {
            ELOG("Sync completed with errors")
            if let error = lastError {
                updateSyncStatus(.error(CloudSyncError.cloudKitError(error)))
            }
        } else if syncStatus != .error(CloudSyncError.cloudKitError(lastError ?? CloudSyncError.unknown)) {
            // Only set to idle if we're not already in an error state from fetchRemoteChanges
            updateSyncStatus(.idle)
            DLOG("Initial sync phase completed successfully.")
        }
    }

    /// Fetch only remote changes without doing initial sync
    /// Useful for responding to CloudKit notifications
    public func fetchRemoteChangesOnly() async {
        guard Defaults[.iCloudSync] else {
            DLOG("iCloud sync disabled, skipping fetchRemoteChangesOnly.")
            return
        }

        // Initialize sync providers if needed
        if romsSyncer == nil || saveStatesSyncer == nil || nonDatabaseSyncer == nil {
            initializeSyncProviders()
        }

        guard romsSyncer != nil || saveStatesSyncer != nil || nonDatabaseSyncer != nil else {
            ELOG("Sync providers failed to initialize. Aborting fetch.")
            return
        }

        updateSyncStatus(.downloading)
        DLOG("Fetching remote changes from CloudKit...")

        await fetchRemoteChanges()

        updateSyncStatus(.idle)
        DLOG("Remote fetch complete.")
    }

    /// Upload a ROM file to the cloud
    /// - Parameter game: The game to upload
    /// - Returns: Async function that completes when the upload is done or throws an error
    @MainActor
    public func uploadROM(for md5: String) async throws {
        
        let realm = await try Realm()
        guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
            ELOG("No PVGame found for md5: \(md5.uppercased())")
            return
        }
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer else {
            DLOG("Sync disabled or syncer not available. Skipping ROM upload.")
            return // Or throw an error? Depends on expected behavior
        }

        updateSyncStatus(.uploading, info: ["type": "ROM", "title": game.title])
        do {
            try await romsSyncer.uploadGame(md5)
            DLOG("Successfully uploaded ROM: \(game.title)")
            updateSyncStatus(.idle)
        } catch {
            ELOG("Failed to upload ROM \(game.title): \(error)")
            updateSyncStatus(.error(error))
            throw error // Re-throw the error
        }
    }

    /// Download a ROM file from the cloud
    /// - Parameter game: The game to download
    /// - Returns: Async function that completes when the download is done or throws an error
    public func downloadROM(for game: PVGame) async throws {
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer else {
            DLOG("Sync disabled or syncer not available. Skipping ROM download.")
            return // Or throw?
        }

        updateSyncStatus(.downloading, info: ["type": "ROM", "title": game.title])
        do {
            // Ensure downloadGame exists and is async
            // Assuming downloadGame updates local state implicitly
            try await romsSyncer.downloadGame(md5: game.md5 ?? "") // Need downloadGame on protocol/syncer
            DLOG("Successfully downloaded ROM: \(game.title)")
            updateSyncStatus(.idle)
        } catch {
            ELOG("Failed to download ROM \(game.title): \(error)")
            updateSyncStatus(.error(error))
            throw error
        }
    }

    /// Upload a save state to the cloud
    /// - Parameter saveState: The save state to upload
    /// - Returns: Async function that completes when the upload is done or throws an error
    public func uploadSaveState(for saveState: PVSaveState) async throws {
        guard Defaults[.iCloudSync], let saveStatesSyncer = saveStatesSyncer else {
            DLOG("Sync disabled or syncer not available. Skipping save state upload.")
            return
        }

        updateSyncStatus(.uploading, info: ["type": "Save State", "game": saveState.game.title])
        do {
            // Ensure uploadSaveState exists and is async
            // Assuming Completable has an extension like .toAsync()
            try await saveStatesSyncer.uploadSaveState(for: saveState).toAsync()
            DLOG("Successfully uploaded save state for game: \(saveState.game.title)")
            updateSyncStatus(.idle)
        } catch {
            ELOG("Failed to upload save state for game \(saveState.game.title): \(error)")
            updateSyncStatus(.error(error))
            throw error
        }
    }

    /// Download a save state from the cloud
    /// - Parameter saveState: The save state to download
    /// - Returns: Async function that completes when the download is done or throws an error
    public func downloadSaveState(for saveState: PVSaveState) async throws {
        guard Defaults[.iCloudSync], let saveStatesSyncer = saveStatesSyncer else {
            DLOG("Sync disabled or syncer not available. Skipping save state download.")
            return
        }

        updateSyncStatus(.downloading, info: ["type": "Save State", "game": saveState.game.title])
        do {
            // Ensure downloadSaveState exists, handle Completable return
            // Assuming Completable has an extension like .toAsync()
            try await saveStatesSyncer.downloadSaveState(for: saveState).toAsync()
            DLOG("Successfully downloaded save state for game: \(saveState.game.title)")
            updateSyncStatus(.idle)
        } catch {
            ELOG("Failed to download save state for game \(saveState.game.title): \(error)")
            updateSyncStatus(.error(error))
            throw error
        }
    }

    /// Update the sync status and notify listeners
    /// - Parameter status: The new sync status
    private func updateSyncStatus(_ status: SyncStatus, info: [String: Any]? = nil) {
        Task { @MainActor in // Ensure updates happen on the main thread
            self.syncStatus = status
            self.currentSyncInfo = info
            self.syncStatusSubject.send(status)
        }
    }

    // MARK: - Private Methods

    /// Fetch remote changes from CloudKit
    private func fetchRemoteChanges() async {
        DLOG("Starting to fetch remote changes from CloudKit...")
        
        var hasErrors = false
        var lastError: Error?

        // Fetch ROM changes
        if let romsSyncer = romsSyncer {
            do {
                DLOG("Fetching remote ROM changes...")
                _ = try await romsSyncer.loadAllFromCloud(iterationComplete: nil).toAsync()
                DLOG("Successfully fetched remote ROM changes")
            } catch {
                ELOG("Error fetching remote ROM changes: \(error.localizedDescription)")
                hasErrors = true
                lastError = error
                await errorHandler.handle(error: error)
            }
        } else {
            WLOG("ROM syncer not available for fetching remote changes")
        }

        // Fetch Save State changes
        if let saveStatesSyncer = saveStatesSyncer {
            do {
                DLOG("Fetching remote save state changes...")
                _ = try await saveStatesSyncer.loadAllFromCloud(iterationComplete: nil).toAsync()
                DLOG("Successfully fetched remote save state changes")
            } catch {
                ELOG("Error fetching remote save state changes: \(error.localizedDescription)")
                hasErrors = true
                lastError = error
                await errorHandler.handle(error: error)
            }
        } else {
            WLOG("Save states syncer not available for fetching remote changes")
        }

        // Fetch Non-Database file changes (BIOS, screenshots, etc.)
        if let nonDatabaseSyncer = nonDatabaseSyncer {
            do {
                DLOG("Fetching remote non-database file changes...")
                _ = try await nonDatabaseSyncer.loadAllFromCloud(iterationComplete: nil).toAsync()
                DLOG("Successfully fetched remote non-database file changes")
            } catch {
                ELOG("Error fetching remote non-database file changes: \(error.localizedDescription)")
                hasErrors = true
                lastError = error
                await errorHandler.handle(error: error)
            }
        } else {
            WLOG("Non-database syncer not available for fetching remote changes")
        }
        
        // Update sync status based on results
        if hasErrors {
            ELOG("Completed fetching remote changes with errors")
            if let error = lastError {
                updateSyncStatus(.error(CloudSyncError.cloudKitError(error)))
            }
        } else {
            DLOG("Completed fetching remote changes from CloudKit successfully")
        }
    }

    /// Initialize sync providers
    private func initializeSyncProviders() {
        let syncMode = Defaults[.iCloudSyncMode]
        DLOG("Initializing sync providers for mode: \(syncMode.description)...")
        updateSyncStatus(.initializing)
        
        // Validate CloudKit container configuration
        guard container.containerIdentifier != nil else {
            ELOG("CloudKit container identifier is nil. Check Info.plist configuration.")
            updateSyncStatus(.error(CloudSyncError.missingDependency))
            return
        }
        
        DLOG("CloudKit container validated: \(container.containerIdentifier!)")

        // Use SyncProviderFactory to create syncers based on the selected mode
        // 1. Initialize ROM Syncer using factory
        self.romsSyncer = SyncProviderFactory.createROMSyncProvider(
            container: container,
            notificationCenter: .default,
            errorHandler: errorHandler
        )

        // 2. Initialize Save States Syncer using factory
        self.saveStatesSyncer = SyncProviderFactory.createSaveStatesSyncProvider(
            notificationCenter: .default,
            errorHandler: errorHandler
        )

        // 3. Initialize BIOS Syncer using factory
        // Note: We don't store this directly but it's available through the factory

        // 4. Initialize Non-Database Syncer (CloudKit only for now)
        let nonDBSyncDirectories: Set<String> = [
            "BIOS",
            "Battery States",
            "Screenshots",
//            "RetroArch",
            "DeltaSkins"
        ]
        self.nonDatabaseSyncer = SyncProviderFactory.createNonDatabaseSyncProvider(
            container: container,
            for: nonDBSyncDirectories,
            notificationCenter: .default,
            errorHandler: errorHandler
        )

        // Check if all initializations were successful (optional, depends on initializer throwing)
        if romsSyncer == nil || saveStatesSyncer == nil || nonDatabaseSyncer == nil {
            ELOG("One or more CloudKit sync providers failed to initialize.")
            updateSyncStatus(.error(CloudSyncError.missingDependency)) // Use .missingDependency
            // Optionally clear partially initialized syncers?
            self.romsSyncer = nil
            self.saveStatesSyncer = nil
            self.nonDatabaseSyncer = nil
        } else {
            DLOG("CloudKit sync providers initialized successfully.")

            // Configure CloudKitInitialSyncer with the initialized providers
            CloudKitInitialSyncer.configureShared(
                romsSyncer: romsSyncer!,
                saveStatesSyncer: saveStatesSyncer!,
                nonDatabaseSyncer: nonDatabaseSyncer!
            )
            DLOG("CloudKitInitialSyncer configured with dependency injection.")

            // Don't immediately set to idle, let startSync manage state
            // updateSyncStatus(.idle)
        }
    }

    /// Register for notifications
    private func registerForNotifications() {
        // Remove existing observers first to prevent duplicates if called multiple times
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        notificationTokens.removeAll()

        // Observe when iCloud sync setting changes
        let syncSettingToken = Defaults.publisher(.iCloudSync)
            .sink { [weak self] change in
                guard let self = self else { return }
                ELOG("iCloud Sync setting changed to: \(change.newValue)")
                self.handleSyncSettingChanged(enabled: change.newValue)
            }
            .store(in: &cancellables)

        // Observe game additions/deletions (Realm Notifications)
        // Keep existing Realm notifications for game changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleGameAdded(_:)), name: Notification.Name.PVGameImported, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleGameWillBeDeleted(_:)), name: .PVGameWillBeDeleted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSaveStateAdded(_:)), name: Notification.Name.PVSaveStateSaved, object: nil)
    }

    /// Set up observers for sync setting changes and other relevant events
    private func setupObservers() {
        // Observe iCloud Sync setting changes using Combine
        Defaults.publisher(.iCloudSync)
            .sink { [weak self] change in
                guard let self = self else { return }
                ELOG("iCloud Sync setting changed to: \(change.newValue)")
                self.handleSyncSettingChanged(enabled: change.newValue)
            }
            .store(in: &cancellables)

        // Observe game additions/deletions (Realm Notifications)
        // Keep existing Realm notifications for game changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleGameAdded(_:)), name: Notification.Name.PVGameImported, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleGameWillBeDeleted(_:)), name: .PVGameWillBeDeleted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSaveStateAdded(_:)), name: Notification.Name.PVSaveStateSaved, object: nil)
    }

    /// Handles changes to the iCloud sync setting
    /// - Parameter enabled: Whether iCloud sync is now enabled
    private func handleSyncSettingChanged(enabled: Bool) {
        if enabled {
            ILOG("iCloud Sync Enabled")
            // Re-initialize providers if they weren't already
            if romsSyncer == nil || saveStatesSyncer == nil || nonDatabaseSyncer == nil {
                initializeSyncProviders()
            }
            // Perform account check and potentially start initial sync
            Task { // Wrap async call in Task
                await self.checkAccountStatusAndSetupIfNeeded() // Add self.
            }
        } else {
            ILOG("iCloud Sync Disabled")
            // Clear sync providers and stop any ongoing operations
            // TODO: Implement cancellation logic for ongoing syncs
            romsSyncer = nil
            saveStatesSyncer = nil
            nonDatabaseSyncer = nil
            updateSyncStatus(.disabled)
        }
    }

    /// Checks CloudKit account status and initiates setup if needed.
    private func checkAccountStatusAndSetupIfNeeded() async {
        DLOG("Checking CloudKit account status...")
        
        do {
            let accountStatus = try await container.accountStatus()
            
            switch accountStatus {
            case .available:
                ILOG("CloudKit account is available. Proceeding with sync setup.")
                // Account is good, proceed with sync
                await startSync()
                
            case .noAccount:
                ELOG("No iCloud account configured. CloudKit sync disabled.")
                updateSyncStatus(.error(CloudSyncError.noAccount))
                
            case .restricted:
                ELOG("iCloud account is restricted. CloudKit sync disabled.")
                updateSyncStatus(.error(CloudSyncError.accountRestricted))
                
            case .couldNotDetermine:
                ELOG("Could not determine iCloud account status. CloudKit sync disabled.")
                updateSyncStatus(.error(CloudSyncError.accountStatusUnknown))
                
            case .temporarilyUnavailable:
                WLOG("iCloud account temporarily unavailable. Will retry later.")
                updateSyncStatus(.error(CloudSyncError.accountTemporarilyUnavailable))
                
                // Schedule a retry after a delay
                Task {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    await checkAccountStatusAndSetupIfNeeded()
                }
                
            @unknown default:
                ELOG("Unknown iCloud account status: \(accountStatus). CloudKit sync disabled.")
                updateSyncStatus(.error(CloudSyncError.accountStatusUnknown))
            }
            
        } catch {
            ELOG("Failed to check CloudKit account status: \(error.localizedDescription)")
            updateSyncStatus(.error(CloudSyncError.cloudKitError(error)))
        }
    }

    // MARK: - Notification Handlers
    @MainActor
    @objc private func handleGameAdded(_ notification: Notification) {
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer else {
            DLOG("CloudKit sync disabled or ROM syncer not available. Skipping game upload.")
            return
        }
        
        // Extract filename from notification userInfo
        let fileName = notification.userInfo?[PVNotificationUserInfoKeys.fileNameKey] as? String
        let md5 = notification.userInfo?[PVNotificationUserInfoKeys.md5Key] as? String
        
//        precondition(fileName != nil, "Missing fileName in gameAdded notification")
//        precondition(md5 != nil, "Missing md5 in gameAdded notification")
        
        // Update sync status
        
        ILOG("Game imported: \(fileName ?? "nil") \(md5 ?? "nil"). Uploading to CloudKit...")
        
        Task {
            do {
                // Find the game by filename (since we don't have MD5 in the notification)
                // This is a bit inefficient but necessary given the current notification structure
                let realm = try await Realm()
                
                if let md5 = md5 {
                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) ?? realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())  else {
                        ELOG("Game with MD5 \(md5) not found for upload")
                        return
                    }
                    
                    ILOG("Found imported game: \(game.title) (MD5: \(game.md5Hash ?? "N/A")). Uploading to CloudKit...")
                    
                    // Upload the game using the existing upload method
                    try await uploadROM(for: game.md5Hash)
                    
                    ILOG("Successfully uploaded newly imported game: \(game.title)")
                } else if let fileName = fileName {
                    guard let game = realm.objects(PVGame.self).filter("romPath CONTAINS[c] %@", fileName).first else {
                        ELOG("Game with filename \(fileName) not found for upload")
                        return
                    }
                    
                    ILOG("Found imported game: \(game.title) (MD5: \(game.md5Hash ?? "N/A")). Uploading to CloudKit...")
                    
                    // Upload the game using the existing upload method
                    try await uploadROM(for: game.md5Hash)
                    
                    ILOG("Successfully uploaded newly imported game: \(game.title)")
                } else {
                    ELOG("Missing fileName or md5 in gameAdded notification")
                    return
                }
            } catch {
                ELOG("Failed to upload newly imported game \(fileName): \(error.localizedDescription)")
                await errorHandler.handle(error: error)
                updateSyncStatus(.error(error))
            }
        }
    }

    @objc private func handleGameWillBeDeleted(_ notification: Notification) {
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer, let md5 = notification.userInfo?["md5"] as? String else { return }
        DLOG("Game will be deleted, marking in CloudKit: MD5 \(md5)")
        Task {
            do {
                try await romsSyncer.markGameAsDeleted(md5: md5)
            } catch {
                ELOG("Failed to mark game as deleted in CloudKit (MD5: \(md5)): \(error)")
                await errorHandler.handle(error: error)
                // Update status? Or rely on errorHandler?
                updateSyncStatus(.error(error))
            }
        }
    }

    @objc private func handleSaveStateAdded(_ notification: Notification) {
        guard Defaults[.iCloudSync], let saveState = notification.object as? PVSaveState else { return }
        DLOG("Save state added, uploading: \(saveState.file?.fileName ?? "unknown") for game \(saveState.game.title)")
        Task {
            do {
                try await uploadSaveState(for: saveState)
            } catch {
                // Error already logged and status updated in uploadSaveState
                // errorHandler.handle(error: error) // Potentially redundant if uploadSaveState handles it
            }
        }
    }

    // MARK: - Realm Database Access (Example - adjust as needed)

    // Example accessors - Replace with actual implementation if different
    // Ensure these are accessible from this context
    private var gameDatabase: RomDatabase {
        return RomDatabase.sharedInstance
    }
}

// MARK: - RxSwift to Swift Concurrency Helper (Placeholder)
// TODO: Move this to a more appropriate location (e.g., Utils/Extensions)
extension Completable {
    func toAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let disposable = self.subscribe(
                onCompleted: { continuation.resume() },
                onError: { continuation.resume(throwing: $0) }
            )
            // Note: This basic implementation doesn't handle cancellation propagation.
            // Consider using Task.isCancelled within the Completable if needed,
            // or managing the disposable lifecycle.
            // disposable.dispose() // Don't dispose immediately
        }
    }
}
