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

    /// BIOS syncer
    public var biosSyncer: BIOSSyncing?

    /// Non-database syncer for files like BIOS, Battery States, Screenshots, and DeltaSkins
    public var nonDatabaseSyncer: CloudKitNonDatabaseSyncer?

    /// Error handler
    public let errorHandler = CloudSyncErrorHandler()

    /// Disposable for subscriptions
    private var disposeBag = DisposeBag()
    private var cancellables = Set<AnyCancellable>()
    private var saveStateToken: NotificationToken?
    private let saveStateObserverQueue = DispatchQueue(label: "org.provenance.cloudsync.savestates.observer", qos: .utility)

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

    /// Flag to indicate if sync operations should be paused (e.g., during emulation)
    @Published public private(set) var isPausedForEmulation: Bool = false

    /// Notification tokens
    private var notificationTokens: [NSObjectProtocol] = []
    private var integrityAuditTask: Task<Void, Never>?
    private var metadataBootstrapTask: Task<Void, Never>?
    /// Track active async tasks so they can be cancelled on emulation pause
    private var activeSyncTasks: [Task<Void, Never>] = []
    private let activeTasksLock = NSLock()

    /// Throttle for status updates to prevent flooding the UI
    private var lastStatusUpdate: Date = .distantPast
    private var lastStatusSent: SyncStatus = .idle
    private let statusUpdateThrottleInterval: TimeInterval = 0.5 // minimum seconds between status updates

    /// Operation queues for pausable/cancellable work
    private let metadataQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "org.provenance.cloudsync.metadataQueue"
        q.qualityOfService = .utility
        q.maxConcurrentOperationCount = 1
        return q
    }()
    private let romsQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "org.provenance.cloudsync.romsQueue"
        q.qualityOfService = .utility
        return q
    }()
    private let saveStatesQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "org.provenance.cloudsync.saveStatesQueue"
        q.qualityOfService = .utility
        return q
    }()
    private let biosQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "org.provenance.cloudsync.biosQueue"
        q.qualityOfService = .utility
        return q
    }()
    private let nonDbQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "org.provenance.cloudsync.nonDbQueue"
        q.qualityOfService = .utility
        return q
    }()

    /// CloudKit Container
    private let container: CKContainer

    /// Observes local PVGame changes to forward metadata edits to CloudKit.
    private var localGameSyncMonitor: LocalGameSyncMonitor?

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
            startMetadataBootstrap(reason: "startup")
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

    // MARK: - Task Tracking

    private func trackSyncTask(_ task: Task<Void, Never>) {
        activeTasksLock.lock()
        activeSyncTasks.append(task)
        activeTasksLock.unlock()
    }

    private func cancelAllActiveSyncTasks() {
        activeTasksLock.lock()
        let tasks = activeSyncTasks
        activeSyncTasks.removeAll()
        activeTasksLock.unlock()
        tasks.forEach { $0.cancel() }
    }

    private func enqueueMetadataWork(_ work: @escaping @Sendable () async -> Void) {
        let op = BlockOperation()
        op.addExecutionBlock { [weak self, weak op] in
            guard let self, let op, !op.isCancelled else { return }
            let task = Task {
                if Task.isCancelled || self.isPausedForEmulation { return }
                await work()
            }
            self.trackSyncTask(task)
        }
        metadataQueue.addOperation(op)
    }

    // MARK: - CloudKit Settings Integration

    /// Check if sync should be allowed based on current device conditions and user settings
    private func shouldAllowSync() async -> Bool {
        // Check if paused for emulation
        if isPausedForEmulation {
            DLOG("Sync paused for emulation, skipping sync")
            return false
        }

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
        var maxCellularSizeBytes = Int64(Defaults[.cloudKitMaxCellularFileSize])
        // Backward-compat: if value looks like MB (very small number), convert to bytes
        if maxCellularSizeBytes > 0 && maxCellularSizeBytes <= 1000 {
            maxCellularSizeBytes *= 1024 * 1024
        }

        switch networkMode {
        case .wifiAndCellular:
            // Conservative path previously applied cellular cap always; relax it to only cap truly tiny thresholds
            return fileSize <= maxCellularSizeBytes
        case .wifiOnly:
            return true
        case .cellularOnly:
            return fileSize <= maxCellularSizeBytes
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

    /// Whether ROM metadata/content should be synced for the current content preference.
    private func shouldSyncROMContent() -> Bool {
        switch Defaults[.cloudKitSyncContentType] {
        case .all, .romsOnly, .metadataOnly:
            return true
        case .saveStatesOnly:
            return false
        }
    }

    /// Whether save state metadata/content should be synced for the current content preference.
    private func shouldSyncSaveStateContent() -> Bool {
        switch Defaults[.cloudKitSyncContentType] {
        case .all, .saveStatesOnly, .metadataOnly:
            return true
        case .romsOnly:
            return false
        }
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
        // Hard guard: never start sync while emulation is paused
        if isPausedForEmulation {
            DLOG("[SYNC] startSync called while paused for emulation; skipping.")
            return
        }

        guard Defaults[.iCloudSync] else {
            DLOG("[SYNC] iCloud sync disabled, skipping startSync.")
            updateSyncStatus(.disabled)
            return
        }

        // Check if sync is allowed based on current conditions
        guard await shouldAllowSync() else {
            DLOG("[SYNC] Sync not allowed due to current conditions (network, power, etc.)")
            return
        }

        ILOG("[SYNC] Starting CloudKit sync...")

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

        startMetadataBootstrap(reason: "start-sync")

        // Kick off remote changes fetch IMMEDIATELY to populate Realm with PVGame metadata on fresh installs
        updateSyncStatus(.downloading)
        enqueueMetadataWork { [weak self] in
            await self?.fetchRemoteChanges()
        }

        // Check for missing ROM files at startup (non-blocking)
        enqueueMetadataWork { [weak self] in
            await self?.checkForMissingROMFiles(force: false)
        }

        // Proceed with initial sync (uploads) in parallel
        updateSyncStatus(.initialSync)

        var hasErrors = false
        var lastError: Error?

        // Perform initial sync (this checks if needed internally unless forced)
        do {
            let syncCount = await CloudKitInitialSyncer.shared?.performInitialSync(forceSync: false)
            DLOG("CloudKit initial sync completed - potentially uploaded \(syncCount) new records.")
        } catch {
            ELOG("CloudKit initial sync failed: \(error.localizedDescription)")
            hasErrors = true
            lastError = error
            await errorHandler.handle(error: error)
        }

        // Update status based on results (do not cancel ongoing remote fetch)
        if hasErrors {
            ELOG("Sync completed with errors")
            if let error = lastError {
                updateSyncStatus(.error(CloudSyncError.cloudKitError(error)))
            }
        } else if syncStatus != .error(CloudSyncError.cloudKitError(lastError ?? CloudSyncError.unknown)) {
            updateSyncStatus(.idle)
            DLOG("Initial sync phase completed successfully (remote fetch may still be in progress).")
        }
    }

    /// Fetch only remote changes without doing initial sync
    /// Useful for responding to CloudKit notifications
    public func fetchRemoteChangesOnly() async {
        if isPausedForEmulation {
            DLOG("[SYNC] fetchRemoteChangesOnly called while paused for emulation; skipping.")
            return
        }

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

        enqueueMetadataWork { [weak self] in
            await self?.fetchRemoteChanges()
        }

        updateSyncStatus(.idle)
        DLOG("Remote fetch complete.")
    }

    /// Upload a ROM file to the cloud
    /// - Parameter game: The game to upload
    /// - Returns: Async function that completes when the upload is done or throws an error
    public func uploadROM(for game: PVGame) async throws {
//        guard let game = game.thaw() else {
//            ELOG("Failed to thaw game: \(game.title)")
//            return
//        }

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

        if game.contentless {
            DLOG("Skipping CloudKit ROM upload for contentless placeholder game: \(game.title)")
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
                scheduleIntegrityAudit(reason: "post-rom-upload", delay: 1.0)
                return
            } catch let error as CloudSyncError {
                retryCount += 1

                // Provide specific error messages based on error type
                let errorMessage: String
                switch error {
                case .invalidData:
                    errorMessage = "Upload failed: Invalid or corrupted game data. Please verify the ROM file is valid."
                case .assetTooLarge(let size, let maxSize):
                    let sizeMB = Double(size) / (1024 * 1024)
                    let maxMB = Double(maxSize) / (1024 * 1024)
                    errorMessage = "Upload failed: File size (\(String(format: "%.1f", sizeMB))MB) exceeds CloudKit limit (\(String(format: "%.1f", maxMB))MB)"
                case .fileSystemError(let underlyingError):
                    errorMessage = "Upload failed: File system error - \(underlyingError.localizedDescription)"
                case .cloudKitError(let underlyingError):
                    if let ckError = underlyingError as? CKError {
                        var baseMessage = "Upload failed: CloudKit error"
                        baseMessage += " (code: \(ckError.code.rawValue))"

                        switch ckError.code {
                        case .invalidArguments:
                            baseMessage = "Upload failed: Invalid CloudKit record structure. The game data may be corrupted."
                        case .limitExceeded:
                            baseMessage = "Upload failed: File exceeds CloudKit size limits (500MB max)"
                        case .networkUnavailable, .networkFailure:
                            baseMessage = "Upload failed: Network unavailable. Please check your internet connection."
                        case .partialFailure:
                            baseMessage = "Upload failed: Partial failure"
                            if let partialErrors = ckError.partialErrorsByItemID {
                                baseMessage += " - \(partialErrors.count) items failed"
                                for (itemID, itemError) in partialErrors.prefix(3) {
                                    let recordIDString: String
                                    if let recordID = itemID as? CKRecord.ID {
                                        recordIDString = recordID.recordName
                                    } else {
                                        recordIDString = "\(itemID)"
                                    }

                                    if let itemCKError = itemError as? CKError {
                                        baseMessage += "\n  \(recordIDString): code \(itemCKError.code.rawValue) - \(itemCKError.localizedDescription)"
                                    } else {
                                        baseMessage += "\n  \(recordIDString): \(itemError.localizedDescription)"
                                    }
                                }
                                if partialErrors.count > 3 {
                                    baseMessage += "\n  ... and \(partialErrors.count - 3) more"
                                }
                            }
                        case .serviceUnavailable:
                            baseMessage = "Upload failed: CloudKit service unavailable. Please try again later."
                        case .requestRateLimited:
                            baseMessage = "Upload failed: Rate limited"
                            if let retryAfter = ckError.retryAfterSeconds {
                                baseMessage += " - Retry after \(retryAfter) seconds"
                            }
                        case .quotaExceeded:
                            baseMessage = "Upload failed: iCloud storage quota exceeded"
                        default:
                            baseMessage += " - \(ckError.localizedDescription)"
                            if let retryAfter = ckError.retryAfterSeconds {
                                baseMessage += " (Retry after \(retryAfter) seconds)"
                            }
                        }
                        errorMessage = baseMessage
                    } else {
                        errorMessage = "Upload failed: CloudKit error - \(underlyingError.localizedDescription)"
                    }
                default:
                    errorMessage = "Upload failed: \(error.localizedDescription)"
                }

                ELOG("Failed to upload ROM \(title) (attempt \(retryCount)/\(maxRetries)): \(errorMessage)")

                if retryCount >= maxRetries {
                    updateSyncStatus(.error(error))
                    // Re-throw with more descriptive error
                    throw CloudSyncError.genericError(errorMessage)
                } else {
                    // Wait before retry (exponential backoff)
                    let delay = TimeInterval(retryCount * 2)
                    DLOG("Retrying upload for \(title) after \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                retryCount += 1
                ELOG("Failed to upload ROM \(title) (attempt \(retryCount)/\(maxRetries)): \(error.localizedDescription)")

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

    // MARK: - Artwork Sync

    /// Sync custom artwork for a game to CloudKit
    /// Call this after saving custom artwork locally to upload it to the cloud
    /// - Parameters:
    ///   - game: The game with updated artwork
    ///   - artworkKey: The PVMediaCache key for the artwork
    /// - Returns: True if artwork was successfully synced
    @discardableResult
    public func syncArtwork(for game: PVGame, artworkKey: String) async throws -> Bool {
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer as? CloudKitRomsSyncer else {
            DLOG("Sync disabled or CloudKit syncer not available. Skipping artwork sync.")
            return false
        }

        // Check if sync is allowed
        guard await shouldAllowSync() else {
            DLOG("Sync not allowed due to current conditions, skipping artwork sync")
            return false
        }

        let md5 = game.md5Hash
        guard !md5.isEmpty else {
            ELOG("Cannot sync artwork: game has no MD5 hash")
            return false
        }

        ILOG("Syncing custom artwork for game: \(game.title), key: \(artworkKey)")

        do {
            var success = false

            // Check if game has a local ROM file
            let hasLocalFile = game.isDownloaded && game.file?.url != nil &&
                FileManager.default.fileExists(atPath: game.file?.url?.path ?? "")

            if hasLocalFile {
                // Full upload with ROM and artwork
                try await romsSyncer.uploadGame(md5)
                success = true
            } else {
                // Artwork-only update (for cloud-synced games without local ROM)
                success = try await romsSyncer.updateArtworkOnly(for: game, artworkKey: artworkKey)
            }

            if success {
                // Post notification that artwork was synced
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .PVGameArtworkDidUpdate,
                        object: nil,
                        userInfo: [
                            PVNotificationUserInfoKeys.gameMD5Key: md5,
                            PVNotificationUserInfoKeys.artworkURLKey: artworkKey
                        ]
                    )
                }
                ILOG("Successfully synced artwork for game: \(game.title)")
            }
            return success
        } catch {
            ELOG("Failed to sync artwork for game \(game.title): \(error.localizedDescription)")
            throw error
        }
    }

    /// Sync custom artwork for a game by MD5 (safe for background threads)
    @discardableResult
    public func syncArtwork(forMD5 md5: String, artworkKey: String) async throws -> Bool {
        guard !md5.isEmpty else {
            ELOG("Cannot sync artwork: missing MD5")
            return false
        }
        let frozenGame = await MainActor.run {
            RomDatabase.sharedInstance.game(withMD5: md5)?.freeze()
        }
        guard let frozenGame else {
            ELOG("Cannot sync artwork: game not found for MD5 \(md5)")
            return false
        }
        return try await syncArtwork(for: frozenGame, artworkKey: artworkKey)
    }

    /// Sync artwork for multiple games in batch
    /// - Parameter gameMD5s: Array of game MD5 hashes to sync artwork for
    /// - Returns: Number of games successfully synced
    @discardableResult
    public func syncArtworkBatch(gameMD5s: [String]) async -> Int {
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer as? CloudKitRomsSyncer else {
            DLOG("Sync disabled or CloudKit syncer not available. Skipping batch artwork sync.")
            return 0
        }

        // Check if sync is allowed
        guard await shouldAllowSync() else {
            DLOG("Sync not allowed due to current conditions, skipping batch artwork sync")
            return 0
        }

        ILOG("Starting batch artwork sync for \(gameMD5s.count) games")
        var successCount = 0

        for md5 in gameMD5s {
            guard let game = await MainActor.run(body: {
                RomDatabase.sharedInstance.game(withMD5: md5)
            }) else {
                WLOG("Game not found for MD5: \(md5)")
                continue
            }

            // Only sync if game has custom artwork
            guard !game.customArtworkURL.isEmpty else {
                continue
            }

            do {
                // Check if game has local file for full upload, otherwise artwork-only
                let hasLocalFile = game.isDownloaded && game.file?.url != nil &&
                    FileManager.default.fileExists(atPath: game.file?.url?.path ?? "")

                if hasLocalFile {
                    try await romsSyncer.uploadGame(md5)
                } else {
                    _ = try await romsSyncer.updateArtworkOnly(for: game, artworkKey: game.customArtworkURL)
                }
                successCount += 1

                // Small delay between uploads to avoid rate limiting
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            } catch {
                ELOG("Failed to sync artwork for game \(game.title): \(error.localizedDescription)")
            }
        }

        if successCount > 0 {
            // Post batch notification
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .PVGameArtworkDidUpdate,
                    object: nil,
                    userInfo: ["batchCount": successCount]
                )
            }
        }

        ILOG("Batch artwork sync complete: \(successCount)/\(gameMD5s.count) games synced")
        return successCount
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
            // Always update local state
            self.syncStatus = status
            self.currentSyncInfo = info

            // Throttle publishing to prevent flooding subscribers
            // Exception: always publish .idle status immediately
            let now = Date()
            let timeSinceLastUpdate = now.timeIntervalSince(self.lastStatusUpdate)
            let statusChanged = status != self.lastStatusSent

            if status == .idle || timeSinceLastUpdate >= self.statusUpdateThrottleInterval || statusChanged {
                self.lastStatusUpdate = now
                self.lastStatusSent = status
                self.syncStatusSubject.send(status)
            }
        }
    }

    /// Schedule a background audit to verify CloudKit asset state and record integrity
    private func scheduleIntegrityAudit(reason: String, delay: TimeInterval = 2.0) {
        guard integrityAuditTask == nil else { return }
        guard Defaults[.iCloudSync],
              let romSyncer = romsSyncer as? CloudKitRomsSyncer else {
            return
        }

        integrityAuditTask = Task.detached(priority: .background) { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            // First, audit assets (quick check for missing files)
            await romSyncer.auditCloudAssets()

            // Then, audit record integrity (check for incomplete metadata)
            // Only run occasionally to avoid excessive API calls
            if Bool.random() || reason.contains("manual") {
                await romSyncer.auditAndRepairIncompleteRecords()
            }

            await MainActor.run {
                self?.integrityAuditTask = nil
            }
        }

        DLOG("Scheduled CloudKit integrity audit (\(reason))")
    }

    /// Manually trigger a full integrity audit including record repair
    public func runFullIntegrityAudit() async {
        guard Defaults[.iCloudSync],
              let romSyncer = romsSyncer as? CloudKitRomsSyncer else {
            WLOG("[SYNC] Cannot run audit - sync disabled or no ROM syncer")
            return
        }

        ILOG("[SYNC] Starting manual full integrity audit...")
        await romSyncer.auditCloudAssets()
        await romSyncer.auditAndRepairIncompleteRecords()
        ILOG("[SYNC] Manual full integrity audit complete")
    }

    /// Run BIOS CloudKit audit to diagnose sync issues
    /// - Returns: Audit result containing details about BIOS sync state
    public func runBIOSAudit() async -> BIOSAuditResult? {
        guard Defaults[.iCloudSync] else {
            WLOG("[SYNC] Cannot run BIOS audit - sync disabled")
            return nil
        }

        ILOG("[SYNC] Starting BIOS audit...")
        let syncer = CloudKitBIOSSyncer(
            container: iCloudConstants.container,
            directories: ["BIOS"],
            errorHandler: errorHandler
        )
        let result = await syncer.auditBIOSCloudRecords()
        ILOG("[SYNC] BIOS audit complete")
        return result
    }

    /// Repair BIOS sync issues by re-uploading problematic files
    /// - Returns: Number of BIOS files re-uploaded
    public func repairBIOSSync() async -> Int {
        guard Defaults[.iCloudSync] else {
            WLOG("[SYNC] Cannot repair BIOS sync - sync disabled")
            return 0
        }

        ILOG("[SYNC] Starting BIOS sync repair...")
        let syncer = CloudKitBIOSSyncer(
            container: iCloudConstants.container,
            directories: ["BIOS"],
            errorHandler: errorHandler
        )
        let count = await syncer.repairBIOSSync()
        ILOG("[SYNC] BIOS sync repair complete: \(count) files re-uploaded")
        return count
    }

    /// Force BIOS download from CloudKit (re-syncs metadata and downloads missing files)
    public func forceBIOSDownload() async {
        guard Defaults[.iCloudSync] else {
            WLOG("[SYNC] Cannot force BIOS download - sync disabled")
            return
        }

        ILOG("[SYNC] Starting forced BIOS download...")
        let syncer = CloudKitBIOSSyncer(
            container: iCloudConstants.container,
            directories: ["BIOS"],
            errorHandler: errorHandler
        )

        // First sync metadata
        _ = await syncer.syncMetadataOnly()

        // Then force download all missing files
        await syncer.downloadMissingBIOSFiles()

        ILOG("[SYNC] Forced BIOS download complete")
    }

    /// Fast targeted download of a single BIOS file from CloudKit
    /// - Parameters:
    ///   - filename: The BIOS filename to download
    ///   - expectedMD5: The expected MD5 hash (used for record ID prediction)
    ///   - systemIdentifier: The system identifier (e.g., "com.provenance.psx")
    /// - Returns: True if the BIOS was downloaded successfully
    public func downloadSingleBIOS(filename: String, expectedMD5: String, systemIdentifier: String) async -> Bool {
        guard Defaults[.iCloudSync] else {
            WLOG("[BIOS FAST] Cannot download - sync disabled")
            return false
        }

        ILOG("[BIOS FAST] Starting targeted download for: \(filename)")

        let syncer = CloudKitBIOSSyncer(
            container: iCloudConstants.container,
            directories: ["BIOS"],
            errorHandler: errorHandler
        )

        // Try multiple record ID formats in order of likelihood
        let md5Prefix = String(expectedMD5.prefix(8)).uppercased()
        let recordIDCandidates = [
            // Most common format: systemID_filename_md5prefix
            "\(systemIdentifier)_\(filename)_\(md5Prefix)",
            // Simple format: systemID_filename
            "\(systemIdentifier)_\(filename)",
            // Legacy format: bios_filename
            "bios_\(filename)",
            // Just filename
            filename
        ]

        for recordID in recordIDCandidates {
            DLOG("[BIOS FAST] Trying recordID: \(recordID)")

            if await syncer.tryDownloadBIOSByRecordID(recordID, filename: filename, systemIdentifier: systemIdentifier) {
                ILOG("[BIOS FAST] ✓ Successfully downloaded \(filename) using recordID: \(recordID)")
                return true
            }
        }

        // If direct lookup failed, try a targeted query by filename
        DLOG("[BIOS FAST] Direct lookup failed, trying filename query...")
        if await syncer.tryDownloadBIOSByFilename(filename, systemIdentifier: systemIdentifier) {
            ILOG("[BIOS FAST] ✓ Successfully downloaded \(filename) via filename query")
            return true
        }

        WLOG("[BIOS FAST] Failed to download BIOS: \(filename)")
        return false
    }

    /// Kick off a fast metadata-only bootstrap for ROMs and save states
    private func startMetadataBootstrap(reason: String) {
        Task { @MainActor in
            guard Defaults[.iCloudSync] else { return }
            guard metadataBootstrapTask == nil else {
                DLOG("Metadata bootstrap already in progress, skipping (\(reason)).")
                return
            }

            metadataBootstrapTask = Task { [weak self] in
                await self?.performMetadataBootstrap(reason: reason)
            }
        }
    }

    private func performMetadataBootstrap(reason: String) async {
        defer {
            Task { @MainActor in
                self.metadataBootstrapTask = nil
            }
        }

        guard Defaults[.iCloudSync] else { return }

        // Capture current syncers
        let romSyncer = self.romsSyncer as? CloudKitRomsSyncer
        let saveStatesSyncer = self.saveStatesSyncer as? CloudKitSaveStatesSyncer
        let biosSyncer = self.biosSyncer as? CloudKitBIOSSyncer

        guard romSyncer != nil || saveStatesSyncer != nil || biosSyncer != nil else {
            DLOG("Metadata bootstrap skipped (\(reason)) - no CloudKit syncers available.")
            return
        }

        ILOG("[SYNC] Metadata bootstrap has syncers: ROMs=\(romSyncer != nil), SaveStates=\(saveStatesSyncer != nil), BIOS=\(biosSyncer != nil)")

        ILOG("[SYNC] Starting CloudKit metadata bootstrap (\(reason))")

        var totalProcessed = 0

        // Process ROM metadata first so save states can resolve games reliably on fresh installs.
        if let romSyncer = romSyncer, shouldSyncROMContent() {
            let count = await romSyncer.syncMetadataOnly()
            totalProcessed += count
        } else {
            DLOG("[SYNC] Skipping ROM metadata bootstrap due to content settings.")
        }

        if let saveStatesSyncer = saveStatesSyncer, shouldSyncSaveStateContent() {
            let count = await saveStatesSyncer.syncMetadataOnly()
            totalProcessed += count
        } else {
            DLOG("[SYNC] Skipping save-state metadata bootstrap due to content settings.")
        }

        // BIOS metadata is independent of ROM/save-state ordering.
        if let biosSyncer = biosSyncer {
            totalProcessed += await biosSyncer.syncMetadataOnly()
        }

        ILOG("[SYNC] Metadata bootstrap finished (\(reason)) - processed \(totalProcessed) records.")
    }

    // MARK: - Private Methods

    /// Fetch remote changes from CloudKit
    private func fetchRemoteChanges() async {
        DLOG("Starting to fetch remote changes from CloudKit...")

        var hasErrors = false
        var lastError: Error?

        // Fetch ROM changes
        if let romsSyncer = romsSyncer, shouldSyncROMContent() {
            do {
                DLOG("Fetching remote ROM changes (zone change token incremental)...")
                await CloudKitSyncerStore.shared.refreshRomRemoteChanges()
                DLOG("Finished applying remote ROM changes")
            } catch {
                ELOG("Error fetching remote ROM changes: \(error.localizedDescription)")
                hasErrors = true
                lastError = error
                await errorHandler.handle(error: error)
            }
        } else {
            DLOG("ROM syncer not available or ROM content disabled; skipping ROM fetch.")
        }

        // Fetch Save State changes
        if let saveStatesSyncer = saveStatesSyncer, shouldSyncSaveStateContent() {
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
            DLOG("Save states syncer not available or save-state content disabled; skipping save-state fetch.")
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
        var syncMode = Defaults[.iCloudSyncMode]

        // Ensure tvOS always uses CloudKit
        #if os(tvOS)
        if !syncMode.isCloudKit {
            WLOG("tvOS does not support iCloud Drive. Switching to CloudKit mode.")
            syncMode = .cloudKit
            Defaults[.iCloudSyncMode] = .cloudKit
        }
        #endif

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
        self.romsSyncer?.workQueue = romsQueue

        if let ckRomsSyncer = self.romsSyncer as? CloudKitRomsSyncer {
            if localGameSyncMonitor == nil {
                localGameSyncMonitor = LocalGameSyncMonitor(romsSyncer: ckRomsSyncer)
            }
            localGameSyncMonitor?.startMonitoring()
        } else {
            localGameSyncMonitor?.stopMonitoring()
            localGameSyncMonitor = nil
        }

        // 2. Initialize Save States Syncer using factory
        self.saveStatesSyncer = SyncProviderFactory.createSaveStatesSyncProvider(
            notificationCenter: .default,
            errorHandler: errorHandler
        )
        self.saveStatesSyncer?.workQueue = saveStatesQueue

        // 3. Initialize BIOS Syncer using factory
        self.biosSyncer = SyncProviderFactory.createBIOSSyncProvider(
            notificationCenter: .default,
            errorHandler: errorHandler
        )
        self.biosSyncer?.workQueue = biosQueue
        ILOG("[SYNC] BIOS syncer initialized: \(self.biosSyncer != nil ? "SUCCESS" : "FAILED")")

        // 4. Initialize Non-Database Syncer (CloudKit only for now)
        // Non-database syncer should exclude BIOS so BIOS files are handled only by the BIOS syncer.
        var nonDBSyncDirectories: Set<String> = [
            "Battery States",
            "Screenshots"
//            "RetroArch"
        ]
        if DeltaSkinSyncSupport.isEnabled {
            nonDBSyncDirectories.insert(DeltaSkinSyncSupport.directoryName)
        }
        self.nonDatabaseSyncer = SyncProviderFactory.createNonDatabaseSyncProvider(
            container: container,
            for: nonDBSyncDirectories,
            notificationCenter: .default,
            errorHandler: errorHandler
        )
        self.nonDatabaseSyncer?.workQueue = nonDbQueue

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

            startMetadataBootstrap(reason: "providers-initialized")
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleSaveStateWillBeDeleted(_:)), name: .PVSaveStateWillBeDeleted, object: nil)
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleSaveStateWillBeDeleted(_:)), name: .PVSaveStateWillBeDeleted, object: nil)

        // Add observer for app returning from background
        notificationTokens.append(
            NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await CloudKitSyncerStore.shared.refreshRomRemoteChanges()
                    await self.checkForMissingROMFiles(force: false)
                }
            }
        )

        notificationTokens.append(
            NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleIntegrityAudit(reason: "app background")
            }
        )
    }

    /// Set up RxRealm observer for new PVSaveState creation
    private func setupSaveStateObserver() {
        saveStateObserverQueue.async { [weak self] in
            guard let self else { return }
            do {
                _ = try Realm()
            } catch {
                ELOG("Failed to initialize Realm for save state observer: \(error.localizedDescription)")
                return
            }

            let realm: Realm
            do {
                realm = try Realm()
            } catch {
                ELOG("Failed to open Realm for save state observer: \(error.localizedDescription)")
                return
            }

            let results = realm.objects(PVSaveState.self)
            self.saveStateToken = results.observe(on: self.saveStateObserverQueue) { [weak self] change in
                guard let self else { return }

                if CloudKitRemoteApplyGuard.isApplyingRemoteChanges {
                    return
                }

                guard Defaults[.iCloudSync] else { return }

                switch change {
                case .initial:
                    return
                case .update(let collection, _, let insertions, _):
                    guard !insertions.isEmpty else { return }

                    let newSaveStates = insertions.compactMap { idx -> PVSaveState? in
                        guard idx < collection.count else { return nil }
                        let ss = collection[idx]
                        guard !ss.isInvalidated else { return nil }
                        if let cloudRecordID = ss.cloudRecordID, !cloudRecordID.isEmpty { return nil }
                        return ss.freeze()
                    }

                    guard !newSaveStates.isEmpty else { return }

                    for saveState in newSaveStates {
                        let title = saveState.game?.title ?? "Unknown"
                        Task {
                            await CloudKitUploadQueueActor.shared.enqueueSaveStateUpload(
                                saveStateID: saveState.id,
                                gameTitle: title,
                                priority: .high
                            )
                        }
                    }
                case .error(let error):
                    ELOG("Error in save state observer: \(error.localizedDescription)")
                    Task { [weak self] in
                        await self?.errorHandler.handle(error: error)
                    }
                }
            }
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
            startMetadataBootstrap(reason: "settings-toggle")
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
            localGameSyncMonitor?.stopMonitoring()
            localGameSyncMonitor = nil
            updateSyncStatus(.disabled)
        }
    }

    /// Checks CloudKit account status and initiates setup if needed.
    private func checkAccountStatusAndSetupIfNeeded() async {
        DLOG("Checking CloudKit account status...")

        do {
            let accountStatus = try await container.accountStatus()

            // Log account status for debugging
            ILOG("CloudKit account status: \(accountStatus.rawValue)")

            switch accountStatus {
            case .available:
                ILOG("CloudKit account is available. Proceeding with sync setup.")
                // Verify container identifier is configured
                guard container.containerIdentifier != nil else {
                    ELOG("CloudKit container identifier is nil. Check Info.plist configuration.")
                    updateSyncStatus(.error(CloudSyncError.missingDependency))
                    return
                }

                // Account is good, proceed with sync
                await startSync()

            case .noAccount:
                WLOG("No iCloud account configured. CloudKit sync will be disabled.")
                updateSyncStatus(.error(CloudSyncError.noAccount))
                // Post notification for UI to show helpful message
                NotificationCenter.default.post(name: .iCloudSyncAccountNotAvailable, object: nil)

            case .restricted:
                WLOG("iCloud account is restricted (e.g., parental controls). CloudKit sync will be disabled.")
                updateSyncStatus(.error(CloudSyncError.accountRestricted))
                NotificationCenter.default.post(name: .iCloudSyncAccountRestricted, object: nil)

            case .couldNotDetermine:
                WLOG("Could not determine iCloud account status. This may be temporary.")
                updateSyncStatus(.error(CloudSyncError.accountStatusUnknown))
                // Retry after a short delay
                Task {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    await checkAccountStatusAndSetupIfNeeded()
                }

            case .temporarilyUnavailable:
                WLOG("iCloud account temporarily unavailable. Will retry in 30 seconds.")
                updateSyncStatus(.error(CloudSyncError.accountTemporarilyUnavailable))

                // Schedule a retry after a delay
                Task {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    await checkAccountStatusAndSetupIfNeeded()
                }

            @unknown default:
                WLOG("Unknown iCloud account status: \(accountStatus.rawValue). CloudKit sync disabled.")
                updateSyncStatus(.error(CloudSyncError.accountStatusUnknown))
            }

        } catch {
            ELOG("Failed to check CloudKit account status: \(error.localizedDescription)")

            // Provide more specific error handling
            if let ckError = error as? CKError {
                switch ckError.code {
                case .networkUnavailable, .networkFailure:
                    WLOG("Network unavailable while checking CloudKit account status.")
                    updateSyncStatus(.error(CloudSyncError.cloudKitError(error)))
                case .serviceUnavailable:
                    WLOG("CloudKit service unavailable. Will retry later.")
                    updateSyncStatus(.error(CloudSyncError.cloudKitError(error)))
                    Task {
                        try await Task.sleep(nanoseconds: 30_000_000_000)
                        await checkAccountStatusAndSetupIfNeeded()
                    }
                default:
                    updateSyncStatus(.error(CloudSyncError.cloudKitError(error)))
                }
            } else {
                updateSyncStatus(.error(CloudSyncError.cloudKitError(error)))
            }
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

        DLOG("Game imported notification received: \(fileName ?? "nil") \(md5 ?? "nil")")

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let game = await self.resolveImportedGame(md5: md5, fileName: fileName) else {
                if let md5 {
                    DLOG("Game with MD5 \(md5) not found for upload (after waiting)")
                } else if let fileName {
                    DLOG("Game with filename \(fileName) not found for upload (after waiting)")
                } else {
                    DLOG("Missing fileName or md5 in gameAdded notification")
                }
                return
            }

            // Skip contentless placeholder games
            if game.contentless {
                DLOG("Skipping CloudKit upload for contentless placeholder game: \(game.title)")
                return
            }

            // Skip games that came from CloudKit (they already have a cloud record and no local file)
            if !game.isDownloaded {
                DLOG("Skipping CloudKit upload for game without local file: \(game.title) (isDownloaded=false)")
                return
            }

            // Skip games that already have a cloud record and haven't been modified locally
            // (this prevents re-uploading games that were just synced from CloudKit)
            if let cloudRecordID = game.cloudRecordID, !cloudRecordID.isEmpty, game.hasCloudAssets {
                DLOG("Skipping CloudKit upload for game already synced: \(game.title) (cloudRecordID=\(cloudRecordID))")
                return
            }

            // Verify the local file actually exists before attempting upload
            if let fileURL = game.file?.url {
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    DLOG("Skipping CloudKit upload: local file does not exist for game \(game.title) at \(fileURL.path)")
                    return
                }
            } else {
                DLOG("Skipping CloudKit upload: game \(game.title) has no file reference")
                return
            }

            let frozenGame = game.freeze()
            ILOG("Uploading newly imported game to CloudKit: \(frozenGame.title) (MD5: \(frozenGame.md5Hash))")

            do {
                try await self.uploadROM(for: frozenGame)
                ILOG("Successfully uploaded newly imported game: \(frozenGame.title)")
            } catch {
                ELOG("Failed to upload newly imported game \(frozenGame.title): \(error.localizedDescription)")
                await self.errorHandler.handle(error: error)
                self.updateSyncStatus(.error(error))
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

    @objc private func handleSaveStateWillBeDeleted(_ notification: Notification) {
        guard Defaults[.iCloudSync],
              let saveStatesSyncer = saveStatesSyncer as? CloudKitSaveStatesSyncer,
              let cloudRecordID = notification.userInfo?["cloudRecordID"] as? String else { return }
        DLOG("Save state will be deleted, removing from CloudKit: \(cloudRecordID)")
        Task {
            do {
                try await saveStatesSyncer.deleteSaveStateFromCloudKit(cloudRecordID: cloudRecordID)
            } catch {
                ELOG("Failed to delete save state from CloudKit: \(error.localizedDescription)")
                await errorHandler.handle(error: error)
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
    //@MainActor
    public func checkForMissingROMFiles(force: Bool) async {
        guard Defaults[.iCloudSync], let romsSyncer = romsSyncer else {
            DLOG("iCloud sync disabled or syncer not available. Skipping missing ROM file check.")
            return
        }

        ILOG("Checking for missing ROM files...")
        updateSyncStatus(.syncing, info: ["action": "checking_missing_files"])

        let fileManager = FileManager.default
        var markedGamesCount = 0
        let isPausedForEmulation = self.isPausedForEmulation

        do {
            // Filter out contentless games (virtual entries for systems that boot without ROMs)
            let frozenGames: [PVGame]
            do {
                frozenGames = try await RealmContext.withRealm { realm in
                    Array(realm.objects(PVGame.self)
                        .filter("contentless == false")
                        .map { $0.freeze() })
                }
            } catch {
                ELOG("[SYNC] Failed to fetch games for missing file check: \(error.localizedDescription)")
                return
            }
            DLOG("Checking \(frozenGames.count) games for missing files (excluding contentless)")

            let batchSize = 50
            let totalGames = frozenGames.count
            for batchStart in stride(from: 0, to: totalGames, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, totalGames)
                let batch = Array(frozenGames[batchStart..<batchEnd])
                var md5sToMarkForSync: [String] = []

                for frozenGame in batch {
                    let game = frozenGame
                    // Skip games that are already marked as not downloaded unless forced
                    if !force && !game.isDownloaded {
                        continue
                    }

                    // Check if the file exists locally
                    let fileExists = await checkIfGameFileExists(game)

                    // Check if a CloudKit record exists for this game.
                    //
                    // IMPORTANT:
                    // - Do NOT fetch per-game records from CloudKit here (that will hammer CK and keep the app busy for minutes).
                    // - Use local state. ROM metadata bootstrap / remote change fetch is responsible for populating cloudRecordID.
                    //
                    // When emulation is running, CloudKit fetches are intentionally suppressed; treat record existence as "unknown".
                    let recordExists: Bool
                    if isPausedForEmulation {
                        recordExists = true
                    } else {
                        recordExists = (game.cloudRecordID?.isEmpty == false)
                    }

                    // If the file doesn't exist locally but a record exists in CloudKit
                    // OR if the game is marked as downloaded but the file is missing
                    // THEN mark it for sync
                    if (!fileExists && recordExists) || (game.isDownloaded && !fileExists) {
                        md5sToMarkForSync.append(game.md5Hash.uppercased())
                        markedGamesCount += 1
                    }
                }

                if !md5sToMarkForSync.isEmpty {
                    await markGamesForSync(md5s: md5sToMarkForSync)
                }

                // Yield to let the system breathe during long scans
                try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
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
            DLOG("Game \(game.title) has no file URL.")
            return false
        }

        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: url.path)

        if !exists {
            DLOG("File not found for game \(game.title): \(url.path)")
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
                DLOG("No CloudKit record found for game with MD5 \(md5)")
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
    @MainActor
    private func markGameForSync(game: PVGame) {
        let realm = RomDatabase.sharedInstance.realm

        // Get live game reference on main thread
        let liveGame: PVGame? = game.isFrozen ? game.thaw() : realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash)

        guard let gameToUpdate = liveGame else {
            ELOG("Game failed to resolve for sync marking.")
            return
        }

        do {
            try realm.write {
                // Mark as not downloaded (file is missing locally)
                gameToUpdate.isDownloaded = false
                // Mark as requiring sync (needs to be downloaded from cloud)
                gameToUpdate.requiresSync = true
                // Clear last sync date since we need to re-sync
                gameToUpdate.lastCloudSyncDate = nil
            }
            ILOG("Marked game \(gameToUpdate.title) (MD5: \(gameToUpdate.md5Hash ?? "N/A")) as needing sync (isDownloaded=false, requiresSync=true)")
        } catch {
            ELOG("Failed to mark game \(gameToUpdate.title) as needing sync: \(error.localizedDescription)")
        }
    }

    /// Batch-mark games as needing sync (file missing locally, but CloudKit record is expected to exist).
    /// This avoids per-game MainActor hops and per-game Realm write commits.
    private func markGamesForSync(md5s: [String]) async {
        guard !md5s.isEmpty else { return }

        do {
            try await RealmContext.withBackgroundRealm { realm in
                try CloudKitRemoteApplyGuard.withApplyingRemoteChanges {
                    try realm.write {
                        for md5 in md5s {
                            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) else { continue }
                            game.isDownloaded = false
                            game.requiresSync = true
                            game.lastCloudSyncDate = nil
                        }
                    }
                }
            }
        } catch {
            ELOG("Failed to batch mark games for sync (count=\(md5s.count)): \(error.localizedDescription)")
        }
    }

    // MARK: - Imported Game Resolution Helpers

    @MainActor
    private func resolveImportedGame(md5: String?, fileName: String?, timeout: TimeInterval = 5) async -> PVGame? {
        if let md5 = md5?.uppercased() {
            let predicate = NSPredicate(format: "md5Hash == %@", md5)
            if let game = await waitForGame(matching: predicate, timeout: timeout) {
                return game
            }
        }

        if let fileName = fileName {
            let predicate = NSPredicate(format: "romPath CONTAINS[c] %@", fileName)
            if let game = await waitForGame(matching: predicate, timeout: timeout) {
                return game
            }
        }

        return nil
    }

    @MainActor
    private func waitForGame(matching predicate: NSPredicate, timeout: TimeInterval) async -> PVGame? {
        let realm = RomDatabase.sharedInstance.realm
        let results = realm.objects(PVGame.self).filter(predicate)

        if let existing = results.first {
            return existing
        }

        return await withCheckedContinuation { continuation in
            var token: NotificationToken?
            var hasResumed = false

            func finish(with game: PVGame?) {
                guard !hasResumed else { return }
                hasResumed = true
                token?.invalidate()
                continuation.resume(returning: game)
            }

            token = results.observe { change in
                switch change {
                case .initial(let collection), .update(let collection, _, _, _):
                    if let game = collection.first {
                        finish(with: game)
                    }
                case .error(let error):
                    ELOG("Realm observation error while waiting for game: \(error.localizedDescription)")
                    finish(with: nil)
                }
            }

            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await MainActor.run {
                    if !hasResumed {
                        WLOG("Timed out waiting for ROM to appear in Realm (predicate: \(predicate.predicateFormat))")
                        finish(with: nil)
                    }
                }
            }
        }
    }

    // MARK: - Emulation Pause/Resume

    /// Pauses sync operations during emulation for better performance
    /// Called when emulation starts
    @MainActor
    public func pauseForEmulation() {
        guard !isPausedForEmulation else { return }

        ILOG("CloudSyncManager: Pausing sync operations for emulation")
        isPausedForEmulation = true

        // Cancel any in-progress sync tasks
        metadataBootstrapTask?.cancel()
        integrityAuditTask?.cancel()
        cancelAllActiveSyncTasks()

        metadataQueue.isSuspended = true
        romsQueue.isSuspended = true
        saveStatesQueue.isSuspended = true
        biosQueue.isSuspended = true
        nonDbQueue.isSuspended = true

        metadataQueue.cancelAllOperations()
        romsQueue.cancelAllOperations()
        saveStatesQueue.cancelAllOperations()
        biosQueue.cancelAllOperations()
        nonDbQueue.cancelAllOperations()
    }

    /// Resumes sync operations after emulation ends
    /// Called when emulation stops and user returns to library
    @MainActor
    public func resumeFromEmulation() {
        guard isPausedForEmulation else { return }

        ILOG("CloudSyncManager: Resuming sync operations after emulation")
        isPausedForEmulation = false

        metadataQueue.isSuspended = false
        romsQueue.isSuspended = false
        saveStatesQueue.isSuspended = false
        biosQueue.isSuspended = false
        nonDbQueue.isSuspended = false

        // Resume background sync tasks if enabled
        if Defaults[.iCloudSync] {
            // Restart metadata bootstrap to catch any changes that occurred during emulation
            startMetadataBootstrap(reason: "emulationEnd")
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
