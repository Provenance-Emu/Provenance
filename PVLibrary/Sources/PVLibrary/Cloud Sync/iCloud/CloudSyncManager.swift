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
import RxRealm

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
        Task.detached { @MainActor in
            self.setupObservers()
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
        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - CloudKit Settings Integration

    /// Check if sync should be allowed based on current device conditions and user settings
    private func shouldAllowSync() async -> Bool {
        // Check if background sync is disabled and app is in background
        let cloudKitBackgroundSync = Defaults[.cloudKitBackgroundSync]
        if !cloudKitBackgroundSync, await isAppInBackground() {
            DLOG("Background sync disabled, skipping sync")
            return false
        }

        // Check low power mode setting
        let cloudKitRespectLowPowerMode = Defaults[.cloudKitRespectLowPowerMode]
        if  cloudKitRespectLowPowerMode, ProcessInfo.processInfo.isLowPowerModeEnabled {
            DLOG("Low power mode enabled and respect setting is on, skipping sync")
            return false
        }

        // Check charging requirement
        let cloudKitSyncOnlyWhenCharging = Defaults[.cloudKitSyncOnlyWhenCharging]
        if  cloudKitSyncOnlyWhenCharging, !(await isDeviceCharging()) {
            DLOG("Device not charging and charging requirement enabled, skipping sync")
            return false
        }

        // Check network conditions
        if !(await isNetworkAvailableForSync()) {
            DLOG("Network not available for sync based on user settings")
            return false
        }

        return true
    }

    /// Check if the current network connection is suitable for sync based on user settings
    private func isNetworkAvailableForSync() async -> Bool {
        let networkMode = Defaults[.cloudKitSyncNetworkMode]

        // For now, we'll assume network is available if any mode is selected
        // In a real implementation, you would check actual network type (WiFi/Cellular)
        switch networkMode {
        case .wifiAndCellular:
            return true // Allow both
        case .wifiOnly:
            // Would need to check if current connection is WiFi
            // For now, assume true - implement actual WiFi detection as needed
            return true
        case .cellularOnly:
            // Would need to check if current connection is cellular
            // For now, assume true - implement actual cellular detection as needed
            return true
        }
    }

    /// Check if the app is currently in background
    private func isAppInBackground() async -> Bool {
        return await MainActor.run {
            UIApplication.shared.applicationState == .background
        }
    }

    /// Check if the device is currently charging
    private func isDeviceCharging() async -> Bool {
#if os(tvOS)
        return true
#else

        return await MainActor.run {
            UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        }
#endif
    }

    /// Check if a file should be synced based on content type settings
    private func shouldSyncContent(type: CloudKitSyncContentType) -> Bool {
        let userContentType = Defaults[.cloudKitSyncContentType]

        switch userContentType {
        case .all:
            return true
        case .saveStatesOnly:
            return type == .saveStatesOnly
        case .romsOnly:
            return type == .romsOnly
        case .metadataOnly:
            return type == .metadataOnly
        }
    }

    /// Check if a file size is acceptable for current network conditions
    private func isFileSizeAcceptableForNetwork(_ fileSize: Int64) -> Bool {
        let networkMode = Defaults[.cloudKitSyncNetworkMode]
        let maxCellularSize = Defaults[.cloudKitMaxCellularFileSize]

        // If WiFi only or WiFi+Cellular, allow any size on WiFi
        // If cellular only or WiFi+Cellular on cellular, check size limit
        switch networkMode {
        case .wifiAndCellular:
            // Would need to detect actual network type
            // For now, apply cellular limit as conservative approach
            return fileSize <= maxCellularSize
        case .wifiOnly:
            return true // No size limit on WiFi
        case .cellularOnly:
            return fileSize <= maxCellularSize
        }
    }

    /// Get the maximum number of concurrent operations based on user settings
    private func getMaxConcurrentOperations() -> Int {
        return Defaults[.cloudKitMaxConcurrentUploads]
    }

    /// Check if files should be compressed based on user settings
    private func shouldCompressFiles() -> Bool {
        return Defaults[.cloudKitCompressFiles]
    }

    /// Check if local files should be deleted after successful upload
    private func shouldDeleteLocalAfterUpload() -> Bool {
        return Defaults[.cloudKitDeleteLocalAfterUpload]
    }

    /// Check if failed uploads should be retried
    private func shouldRetryFailedUploads() -> Bool {
        return Defaults[.cloudKitRetryFailedUploads]
    }

    /// Get the maximum number of retry attempts
    private func getMaxRetryAttempts() -> Int {
        return Defaults[.cloudKitMaxRetryAttempts]
    }

    /// Check if conflicts should be auto-resolved
    private func shouldAutoResolveConflicts() -> Bool {
        return Defaults[.cloudKitAutoResolveConflicts]
    }

    /// Check if sync notifications should be shown
    private func shouldShowSyncNotifications() -> Bool {
        return Defaults[.cloudKitShowSyncNotifications]
    }

    /// Get the sync frequency interval in seconds
    private func getSyncFrequencyInterval() -> TimeInterval? {
        let frequency = Defaults[.cloudKitSyncFrequency]
        return frequency.timeInterval
    }

    // MARK: - Content Type Enum for Settings Integration

    private enum CloudKitSyncContentType {
        case saveStatesOnly
        case romsOnly
        case metadataOnly
    }

    // MARK: - Helper Methods for Settings Integration

    /// Show a sync notification if notifications are enabled
    private func showSyncNotification(message: String) async {
        guard shouldShowSyncNotifications() else { return }

        await MainActor.run {
            // In a real implementation, you would show a proper notification
            // For now, we'll just log it
            ILOG("Sync Notification: \(message)")

            // You could integrate with UNUserNotificationCenter here
            // let content = UNMutableNotificationContent()
            // content.title = "CloudKit Sync"
            // content.body = message
            // ...
        }
    }

    /// Delete local save state file after successful upload
    private func deleteLocalSaveStateFile(_ saveState: PVSaveState) async {
        guard shouldDeleteLocalAfterUpload() else { return }

        do {
            if let fileURL = saveState.file?.url {
                try await FileManager.default.removeItem(at: fileURL)
                DLOG("Deleted local save state file: \(fileURL.lastPathComponent)")
            }
        } catch {
            ELOG("Failed to delete local save state file: \(error)")
        }
    }

    /// Format byte count into human-readable string
    private func formatByteCount(_ byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteCount)
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

        // Check if sync is allowed based on current conditions
        guard await shouldAllowSync() else {
            DLOG("Sync not allowed due to current conditions (network, power, etc.)")
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

        // Check for missing ROM files at startup
        Task.detached {
            await self.checkForMissingROMFiles(force: false)
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
    public func uploadROM(for game: PVGame) async throws {
        guard let game = game.thaw() else {
            ELOG("Failed to thaw game: \(game.title)")
            return
        }

        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer else {
            DLOG("Sync disabled or syncer not available. Skipping ROM upload.")
            return
        }

        // Check if sync is allowed based on current conditions
        guard await shouldAllowSync() else {
            DLOG("Sync not allowed due to current conditions, skipping ROM upload")
            return
        }

        // Check if ROM content should be synced based on user settings
        guard shouldSyncContent(type: .romsOnly) else {
            DLOG("ROM sync disabled by user content type settings")
            return
        }

        let md5 = game.md5Hash

        // Check file size if it exists
        if let romPath = PVEmulatorConfiguration.path(forGame: game),
           let fileSize = try? FileManager.default.attributesOfItem(atPath: romPath.path)[.size] as? Int64 {
            guard isFileSizeAcceptableForNetwork(fileSize) else {
                DLOG("ROM file too large for current network settings: \(formatByteCount(fileSize))")
                return
            }
        }

        updateSyncStatus(.uploading, info: ["type": "ROM", "title": game.title])

        var retryCount = 0
        let maxRetries = shouldRetryFailedUploads() ? getMaxRetryAttempts() : 1
        let title = game.title

        while retryCount < maxRetries {
            do {
                try await romsSyncer.uploadGame(md5)
                DLOG("Successfully uploaded ROM: \(title)")

                // Show notification if enabled
                if shouldShowSyncNotifications() {
                    await showSyncNotification(message: "Uploaded ROM: \(title)")
                }

                updateSyncStatus(.idle)
                return
            } catch {
                retryCount += 1
                ELOG("Failed to upload ROM \(title) (attempt \(retryCount)/\(maxRetries)): \(error)")

                if retryCount >= maxRetries {
                    updateSyncStatus(.error(error))
                    throw error
                } else {
                    // Wait before retry (exponential backoff)
                    let delay = TimeInterval(retryCount * 2)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
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
            try await romsSyncer.downloadGame(md5: game.md5Hash ?? "") // Need downloadGame on protocol/syncer
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

        // Check if sync is allowed based on current conditions
        guard await shouldAllowSync() else {
            DLOG("Sync not allowed due to current conditions, skipping save state upload")
            return
        }

        // Check if save state content should be synced based on user settings
        guard shouldSyncContent(type: .saveStatesOnly) else {
            DLOG("Save state sync disabled by user content type settings")
            return
        }

        // Check file size if it exists
        if let saveStatePath = saveState.file?.url,
           let fileSize = try? FileManager.default.attributesOfItem(atPath: saveStatePath.path)[.size] as? Int64 {
            guard isFileSizeAcceptableForNetwork(fileSize) else {
                DLOG("Save state file too large for current network settings: \(formatByteCount(fileSize))")
                return
            }
        }

        updateSyncStatus(.uploading, info: ["type": "Save State", "game": saveState.game.title])

        var retryCount = 0
        let maxRetries = shouldRetryFailedUploads() ? getMaxRetryAttempts() : 1

        while retryCount < maxRetries {
            do {
                // Use the direct async method from CloudKitSaveStatesSyncer
                try await saveStatesSyncer.uploadSaveState(for: saveState)
                DLOG("Successfully uploaded save state for game: \(saveState.game.title)")

                // Show notification if enabled
                if shouldShowSyncNotifications() {
                    await showSyncNotification(message: "Uploaded save state for: \(saveState.game.title)")
                }

                // Delete local file if requested by user
                if shouldDeleteLocalAfterUpload() {
                    await deleteLocalSaveStateFile(saveState)
                }

                updateSyncStatus(.idle)
                return
            } catch {
                retryCount += 1
                ELOG("Failed to upload save state for game \(saveState.game.title) (attempt \(retryCount)/\(maxRetries)): \(error)")

                if retryCount >= maxRetries {
                    updateSyncStatus(.error(error))
                    throw error
                } else {
                    // Wait before retry (exponential backoff)
                    let delay = TimeInterval(retryCount * 2)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
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
        let saveState = saveState.freeze()

        updateSyncStatus(.downloading, info: ["type": "Save State", "game": saveState.game.title])
        do {
            // Ensure downloadSaveState exists, handle Completable return
            // Assuming Completable has an extension like .toAsync()
            ILOG("Downloading save state for game: \(saveState.game.title)")
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
        
        // TODO: Support partial init

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

        // Observe new PVSaveState creation using RxRealm
        setupSaveStateObserver()

        // Observe game additions/deletions (Realm Notifications)
        // Keep existing Realm notifications for game changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleGameAdded(_:)), name: Notification.Name.PVGameImported, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleGameWillBeDeleted(_:)), name: .PVGameWillBeDeleted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSaveStateAdded(_:)), name: Notification.Name.PVSaveStateSaved, object: nil)

        // Add observer for app returning from background
        notificationTokens.append(
            NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.checkForMissingROMFiles(force: false)
                }
            }
        )
    }

    /// Set up RxRealm observer for new PVSaveState creation
    private func setupSaveStateObserver() {
        do {
            let realm = try Realm()

            // Observe all PVSaveState objects for insertions
            Observable.collection(from: realm.objects(PVSaveState.self))
                .distinctUntilChanged()
                .scan(([] as [PVSaveState], [] as [PVSaveState])) { (previous: ([PVSaveState], [PVSaveState]), current: Results<PVSaveState>) -> ([PVSaveState], [PVSaveState]) in
                    return (previous.1, Array(current))
                }
                .filter { (previous, current) in
                    // Only proceed if we have a previous state (skip initial emission)
                    return !previous.isEmpty
                }
                .map { (previous, current) -> [PVSaveState] in
                    // Find newly added save states
                    let previousIDs = Set(previous.map { $0.id })
                    return current.filter { !previousIDs.contains($0.id) }
                }
                .filter { newSaveStates in
                    // Only proceed if there are actually new save states
                    return !newSaveStates.isEmpty
                }
                .subscribe(onNext: { [weak self] newSaveStates in
                    guard let self = self else { return }

                    // Only upload if iCloud sync is enabled
                    guard Defaults[.iCloudSync] else {
                        DLOG("iCloud sync disabled, skipping automatic save state upload")
                        return
                    }

                    for saveState in newSaveStates {
                        ILOG("New save state detected: \(saveState.file?.fileName ?? "unknown") for game \(saveState.game.title)")

                        // Upload asynchronously
                        Task {
                            do {
                                try await self.uploadSaveState(for: saveState)
                                ILOG("Successfully uploaded new save state: \(saveState.file?.fileName ?? "unknown")")
                            } catch {
                                ELOG("Failed to upload new save state \(saveState.file?.fileName ?? "unknown"): \(error.localizedDescription)")
                                await self.errorHandler.handle(error: error)
                            }
                        }
                    }
                }, onError: { [weak self] error in
                    ELOG("Error in save state observer: \(error.localizedDescription)")
                    Task {
                        await self?.errorHandler.handle(error: error)
                    }
                })
                .disposed(by: disposeBag)

            DLOG("RxRealm save state observer setup complete")

        } catch {
            ELOG("Failed to setup save state observer: \(error.localizedDescription)")
        }
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
                let realm = try await Realm(queue: nil)
                
                if let md5 = md5 {
                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) ?? realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())  else {
                        ELOG("Game with MD5 \(md5) not found for upload")
                        return
                    }

                    ILOG("Found imported game: \(game.title) (MD5: \(game.md5Hash ?? "N/A")). Uploading to CloudKit...")


                    // Upload the game using the existing upload method
                    try await uploadROM(for: game.freeze())

                    ILOG("Successfully uploaded newly imported game: \(game.title)")
                } else if let fileName = fileName {
                    guard let game = realm.objects(PVGame.self).filter("romPath CONTAINS[c] %@", fileName).first else {
                        ELOG("Game with filename \(fileName) not found for upload")
                        return
                    }

                    ILOG("Found imported game: \(game.title) (MD5: \(game.md5Hash ?? "N/A")). Uploading to CloudKit...")

                    // Upload the game using the existing upload method
                    try await uploadROM(for: game.freeze())

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

    // MARK: - Missing ROM File Detection

    /// Checks all PVGame objects to verify if their local files exist
    /// If a file doesn't exist locally or lacks a CloudKit record, mark it for sync
    /// - Parameter force: Force check even for games that are already marked as not downloaded
    @MainActor
    public func checkForMissingROMFiles(force: Bool) async {
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer else {
            DLOG("iCloud sync disabled or syncer not available. Skipping missing ROM file check.")
            return
        }

        ILOG("Checking for missing ROM files...")
        updateSyncStatus(.syncing, info: ["action": "checking_missing_files"])

        let fileManager = FileManager.default
        var markedGamesCount = 0

        do {
//            let realm = await try Realm()
            let database = RomDatabase.sharedInstance

            // Get all games from database
            let games = database.allGames //realm.objects(PVGame.self)
            DLOG("Checking \(games.count) games for missing files")

            // Process in batches to avoid excessive memory usage
            let batchSize = 50
            let totalGames = games.count

            for batchStart in stride(from: 0, to: totalGames, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, totalGames)
                let batch = Array(games[batchStart..<batchEnd])

                for game in batch {
                    // Skip games that are already marked as not downloaded unless forced
                    if !force && !game.isDownloaded {
                        continue
                    }

                    // Check if the file exists locally
                    var threadSafeGame = game.freeze()
                    let fileExists = await checkIfGameFileExists(threadSafeGame)

                    // Check if a CloudKit record exists for this game
                    var recordExists = false
                    let md5 = game.md5Hash
                    if !md5.isEmpty {
                        recordExists = await checkIfCloudRecordExists(md5: md5, syncer: romsSyncer)
                    }

                    // If the file doesn't exist locally but a record exists in CloudKit
                    // OR if the game is marked as downloaded but the file is missing
                    // THEN mark it for sync
                    if (!fileExists && recordExists) || (game.isDownloaded && !fileExists) {
                        await markGameForSync(game: threadSafeGame, realm: database.realm)
                        markedGamesCount += 1
                    }
                    // If no CloudKit record exists but we have a local file, mark for upload
                    else if fileExists && !recordExists && game.md5Hash != nil {
                        ILOG("Game \(game.title) has local file but no CloudKit record. Marking for upload.")
                        Task {
                            do {
                                try await uploadROM(for: game.freeze())
                                ILOG("Successfully marked \(game.title) for upload.")
                            } catch {
                                ELOG("Failed to mark \(game.title) for upload: \(error.localizedDescription)")
                            }
                        }
                    }
                }

                // Small delay to prevent UI blocking
//                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

        } catch {
            ELOG("Error checking for missing ROM files: \(error.localizedDescription)")
            updateSyncStatus(.error(error))
            return
        }

        ILOG("Missing ROM file check complete. Marked \(markedGamesCount) games for sync.")
        updateSyncStatus(.idle)
    }

    /// Check if a game's file exists locally
    /// - Parameter game: The game to check
    /// - Returns: True if the file exists, false otherwise
    private func checkIfGameFileExists(_ game: PVGame) async -> Bool {
        guard let url = game.file?.url else {
            VLOG("Game \(game.title) has no file URL.")
            return false
        }

        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: url.path)

        if !exists {
            VLOG("File not found for game \(game.title): \(url.path)")
        }

        return exists
    }

    /// Check if a CloudKit record exists for the game
    /// - Parameters:
    ///   - md5: The MD5 hash of the game
    ///   - syncer: The ROM syncer to use
    /// - Returns: True if a record exists, false otherwise
    private func checkIfCloudRecordExists(md5: String, syncer: RomsSyncing) async -> Bool {
        // Create record ID based on the MD5 hash using schema's conventions
        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)

        do {
            // Using CloudKitRomsSyncer's existing method to fetch record
            if let syncer = syncer as? CloudKitRomsSyncer {
                let record = try await syncer.fetchRecord(recordID: recordID)
                return record != nil
            }
            return false
        } catch {
            // Handle record not found gracefully without logging errors for expected cases
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                VLOG("No CloudKit record found for game with MD5 \(md5)")
                return false
            }

            WLOG("Error checking CloudKit record for game with MD5 \(md5): \(error.localizedDescription)")
            return false
        }
    }

    /// Mark a game as needing sync (not downloaded)
    /// - Parameters:
    ///   - game: The game to mark
    ///   - realm: The Realm instance to use
    private func markGameForSync(game: PVGame, realm: Realm) async {
        guard let game = game.thaw() else {
            ELOG("Game failed to unthaw.")
            return
        }
        do {
            try realm.write {
                // Mark as not downloaded (file is missing locally)
                game.isDownloaded = false
                // Mark as requiring sync (needs to be downloaded from cloud)
                game.requiresSync = true
                // Clear last sync date since we need to re-sync
                game.lastCloudSyncDate = nil
            }
            ILOG("Marked game \(game.title) (MD5: \(game.md5Hash ?? "N/A")) as needing sync (isDownloaded=false, requiresSync=true)")
        } catch {
            ELOG("Failed to mark game \(game.title) as needing sync: \(error.localizedDescription)")
        }
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
