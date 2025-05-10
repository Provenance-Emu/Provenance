//
//  ImportProgressViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/26/25.
//  Updated by Cascade for enhanced UI/Logic on 2025-05-08.
//

import Combine
import Defaults
import Foundation
import PVLibrary
import PVLogging
import PVPrimitives
import PVSettings
import PVThemes
import SwiftUI
import Perception

public struct CloudKitInitialSyncProgress: Equatable { // Renamed from InitialSyncProgress for clarity if needed
    public var romsCompleted: Int
    public var romsTotal: Int
    public var saveStatesCompleted: Int
    public var saveStatesTotal: Int
    public var biosCompleted: Int
    public var biosTotal: Int
    public var batteryStatesCompleted: Int
    public var batteryStatesTotal: Int
    public var screenshotsCompleted: Int
    public var screenshotsTotal: Int
    public var deltaSkinsCompleted: Int
    public var deltaSkinsTotal: Int

    public var overallProgress: Double {
        let totalCompleted = romsCompleted + saveStatesCompleted + biosCompleted + batteryStatesCompleted + screenshotsCompleted + deltaSkinsCompleted
        let totalItems = romsTotal + saveStatesTotal + biosTotal + batteryStatesTotal + screenshotsTotal + deltaSkinsTotal
        return totalItems > 0 ? Double(totalCompleted) / Double(totalItems) : 0
    }

    public static var DUMMY_FOR_PREVIEW: CloudKitInitialSyncProgress = .init(romsCompleted: 10, romsTotal: 100, saveStatesCompleted: 5, saveStatesTotal: 20, biosCompleted: 1, biosTotal: 2, batteryStatesCompleted: 0, batteryStatesTotal: 0, screenshotsCompleted: 0, screenshotsTotal: 0, deltaSkinsCompleted: 0, deltaSkinsTotal: 0)
}

// ViewModel for ImportProgressView
public class ImportProgressViewModel: ObservableObject {
    // MARK: - Published Properties for UI

    /// Import queue items from GameImporter
    @Published public var importQueueItems: [ImportQueueItem] = []

    /// Messages to display in the log view of ImportProgressView
    @Published public var statusLogMessages: [StatusMessageManager.StatusMessage] = [] {
        didSet {
            ILOG("ImportProgressViewModel: statusLogMessages updated. Count: \(statusLogMessages.count). Last message: \(statusLogMessages.last?.message ?? "N/A")")
        }
    }

    /// Overall iCloud syncing state (derived)
    @Published public var isSyncing: Bool = false

    /// Detailed iCloud sync status
    @Published public var syncStatus: CloudSyncManager.SyncStatus = .idle

    /// Progress for initial iCloud sync
    @Published public var initialSyncProgress: CloudKitInitialSyncProgress? = nil

    /// Active progress bars for other operations (newer feature)
    @Published public var activeProgressBars: [ProgressInfo] = []

    /// Log messages (newer feature)
    @Published public var logMessages: [StatusMessageManager.StatusMessage] = []

    /// iCloud File recovery state (newer feature)
    @Published public var fileRecoveryState: PVPrimitives.FileRecoveryState = .idle
    @Published public var fileRecoveryProgress: ProgressInfo?

    /// Controls the visibility of the ImportProgressView
    @Published public var shouldShow: Bool = false

    /// Animation properties from old UI
    @Published public var glowOpacity: Double = 0.7
    @Published public var animatedProgressOffset: CGFloat = 0 // For progress bar animation if needed

    @Published public var showOldProgressSystem: Bool = false // If true, shows the older import progress style elements

    // MARK: - Published Properties (Newer Features / Refined)
    @Published public var isImporting: Bool = false // Ensure this is defined
    @Published public var importProgress: ProgressInfo? // Ensure this is defined

    /// Detailed iCloud sync status
    @Published public var iCloudStatusMessage: String = ""

    /// Detailed iCloud sync status
    @Published public var lastErrorMessage: String? // For displaying a persistent error briefly

    /// Counts for statusDetailsView
    @Published public var totalImportFileCount: Int = 0
    @Published public var processedFilesCount: Int = 0
    @Published public var newFilesCount: Int = 0
    @Published public var errorFilesCount: Int = 0

    // MARK: - Private Properties

    private var messageExpiryTimers: [UUID: Timer] = [:] // Timers for individual log message expiry
    private var processedSharedMessageIDs = Set<UUID>() // Tracks messages processed from StatusMessageManager
    private var hideViewTimer: Timer? // Timer for delayed hiding of the whole view
    private var cancellables = Set<AnyCancellable>()
    private let gameImporter: any GameImporting
    private let updatesController: PVGameLibraryUpdatesController // Store updatesController

    /// User's preference for enabling iCloud Sync, observed directly via @Default.
    @Default(.iCloudSync) internal var iCloudSyncEnabledSetting: Bool

    private let maxStoredMessages = 50
    private let fileRecoveryProgressID = "icloud-file-recovery"

    // MARK: - Initialization

    public init(gameImporter: any GameImporting = GameImporter.shared, updatesController: PVGameLibraryUpdatesController) {
        self.gameImporter = gameImporter
        self.updatesController = updatesController // Store it
        // iCloudSyncEnabledSetting is now managed by @Default

        // Consolidated setup call
        setupPrimarySubscriptions()

        // Observe changes to iCloudSyncEnabledSetting to re-setup CloudKit subscriptions if necessary
        Defaults.publisher(.iCloudSync)
            .removeDuplicates()
            .sink { [weak self] change in
                guard let self = self else { return }
                ILOG("iCloudSyncEnabledSetting changed to: \(change.newValue)")
                self.reactToiCloudSettingChange(isEnabled: change.newValue)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods for View Interaction

    /// Called by the View (e.g., onAppear) to pass the current iCloud sync setting.
    // setupTracking(iCloudEnabled:) is no longer needed as @Default handles the state.

    public func cleanup() {
        ILOG("ImportProgressViewModel: Cleaning up.")
        cancellables.removeAll()
        messageExpiryTimers.values.forEach { $0.invalidate() } // Invalidate individual message timers
        messageExpiryTimers.removeAll()
        processedSharedMessageIDs.removeAll()
        hideViewTimer?.invalidate() // Ensure timer is cleaned up
    }

    /// Add a log message (newer feature)
    public func addLogMessage(_ message: String, type: StatusMessageManager.StatusMessage.MessageType = .info) {
        let statusMessage = StatusMessageManager.StatusMessage(message: message, type: type)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Prevent duplicate messages if message content and type are identical to the last one, and very recent.
            // This is a simple heuristic.
            if let lastLog = self.logMessages.first, lastLog.message == statusMessage.message, lastLog.type == statusMessage.type {
                if abs(lastLog.timestamp.timeIntervalSinceNow) < 1.0 { // If last identical message was within 1 second
                    ILOG("Skipping duplicate log message: \(message)")
                    return
                }
            }

            self.logMessages.insert(statusMessage, at: 0)
            if self.logMessages.count > self.maxStoredMessages {
                let oldestMessage = self.logMessages.removeLast()
                self.messageExpiryTimers[oldestMessage.id]?.invalidate()
                self.messageExpiryTimers.removeValue(forKey: oldestMessage.id)
                self.processedSharedMessageIDs.remove(oldestMessage.id) // Also clear from processed IDs
            }

            // Cancel any existing timer for this specific message ID (e.g., if it's an update to an existing message concept)
            self.messageExpiryTimers[statusMessage.id]?.invalidate()

            // Start 8-second timer for this new message
            let timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.logMessages.removeAll { $0.id == statusMessage.id }
                self.messageExpiryTimers.removeValue(forKey: statusMessage.id)
                self.processedSharedMessageIDs.remove(statusMessage.id) // Also clear from processed IDs when expired
                self.updateShouldShow() // Re-evaluate overall view visibility
                ILOG("Log message expired and removed: \(statusMessage.message)")
            }
            self.messageExpiryTimers[statusMessage.id] = timer

            self.updateShouldShow() // Update overall view visibility status
        }
    }

    /// Update or create a progress bar (newer feature)
    public func updateProgress(id: String, detail: String?, current: Int, total: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let progressInfo = ProgressInfo(id: id, current: current, total: total, detail: detail ?? id)
            if let index = self.activeProgressBars.firstIndex(where: { $0.id == id }) {
                if self.activeProgressBars[index] != progressInfo {
                    self.activeProgressBars[index] = progressInfo
                }
            } else {
                self.activeProgressBars.append(progressInfo)
            }
            self.updateShouldShow()
        }
    }

    /// Remove a progress bar (newer feature)
    public func removeProgress(id: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activeProgressBars.removeAll { $0.id == id }
            self.updateShouldShow()
        }
    }

    /// Start animations for retrowave effects (from old UI)
    public func startAnimations() {
        // Glow effect
        Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.glowOpacity = self.glowOpacity == 0.7 ? 1.0 : 0.7
                }
            }
            .store(in: &cancellables)

        // Animated progress offset (if used by a progress bar style)
         Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
             .sink { [weak self] _ in
                 guard let self = self else { return }
                 // This was used for a specific progress bar visual in current view.
                 // The old view had its own GeometryReader based progress.
                 // Keep if new UI elements might use it, or adapt for old progress bar.
                 self.animatedProgressOffset = (self.animatedProgressOffset + 1).truncatingRemainder(dividingBy: 20)
             }
             .store(in: &cancellables)
    }


    // MARK: - Private Subscription Setup Methods

    private func setupPrimarySubscriptions() {
        ILOG("ImportProgressViewModel: Setting up primary subscriptions.")
        setupGameImporterSubscription()
        setupCloudKitSubscriptions()
        setupFileRecoveryNotificationListeners() // Sets initial state from iCloudDriveSync notifications
        setupStatusMessageManagerSubscription() // New subscription for general status messages
        // Initial call to reflect current setting state
        reactToiCloudSettingChange(isEnabled: self.iCloudSyncEnabledSetting)
        ILOG("Primary subscriptions and trackers set up.")
    }

    private func setupGameImporterSubscription() {
        guard let concreteImporter = gameImporter as? GameImporter else {
            ELOG("GameImporter instance not available for direct queue subscription. Import queue will not be shown.")
            // Optionally, set isImporting to false or handle appropriately
            self.isImporting = false
            self.updateShouldShow()
            return
        }

        // Publisher for the import queue
        gameImporter.importQueuePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] queue in
                guard let self = self else { return }

                // Detailed logging of import queue statuses
                var statusCounts: [String: Int] = [:] // Changed key type to String
                for item in queue {
                    statusCounts[item.status.description, default: 0] += 1 // Use description as key
                }
                ILOG("Import queue received via Publisher. Count: \(queue.count). Statuses: \(statusCounts.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")

                self.importQueueItems = queue // Update the @Published property

                // Calculate if any imports are active (not all are success or failure)
                let activeImports = !queue.isEmpty && !queue.allSatisfy { $0.status == .success || $0.status.isFailure } // Use .isFailure
                if self.isImporting != activeImports {
                    self.isImporting = activeImports
                    ILOG("isImporting toggled to: \(self.isImporting) (from Publisher)")
                }
                self.updateShouldShow()

                // Derive counts from the queue
                self.totalImportFileCount = queue.count
                self.processedFilesCount = queue.filter { $0.status != .queued }.count
                self.errorFilesCount = queue.filter { $0.status.isFailure }.count // Use .isFailure
                // Simplification: assume all successful imports are 'new' for now.
                // A more accurate 'new' vs 'updated' would require more info from ImportQueueItem or GameImporter.
                self.newFilesCount = queue.filter { $0.status == .success }.count
            }
            .store(in: &cancellables)

        // Also fetch initial queue state if needed, or rely purely on publisher
        Task { [weak self, weak concreteImporter] in
            guard let self = self, let concreteImporter = concreteImporter else { return }
            let queue = await concreteImporter.importQueue
            await MainActor.run {
                // Detailed logging for initial fetch if different
                var statusCounts: [String: Int] = [:] // Changed key type to String
                for item in queue {
                    statusCounts[item.status.description, default: 0] += 1 // Use description as key
                }
                ILOG("Import queue received via Task. Count: \(queue.count). Statuses: \(statusCounts.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")
                
                self.importQueueItems = queue
                let activeImports = !queue.isEmpty && !queue.allSatisfy { $0.status == .success || $0.status.isFailure } // Use .isFailure
                if self.isImporting != activeImports {
                    self.isImporting = activeImports
                    ILOG("isImporting toggled to: \(self.isImporting) (from Task)")
                }
                self.updateShouldShow()
            }
        }
    }

    private func setupCloudKitSubscriptions() {
        guard iCloudSyncEnabledSetting else {
            ILOG("CloudKit subscriptions skipped, iCloudSync is disabled by user setting.")
            self.isSyncing = false
            self.syncStatus = .disabled
            self.initialSyncProgress = nil
            return
        }
        ILOG("Setting up CloudKit subscriptions.")

        // Overall Sync Status (from CloudSyncManager)
        CloudSyncManager.shared.syncStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] libraryStatus in
                guard let self = self else { return }
                ILOG("CloudSyncManager status received: \(libraryStatus)")
                self.syncStatus = libraryStatus // Direct assignment
                self.isSyncing = self.syncStatus == .syncing || self.syncStatus == .initialSync || self.syncStatus == .uploading || self.syncStatus == .downloading || self.syncStatus == .initializing
                
                // If CloudSyncManager reports initialSync, we might want to show its progress
                // This part needs to align with how CloudKitInitialSyncer and CloudSyncManager report combined progress.
                if libraryStatus == .initialSync {
                    // Potentially fetch/observe CloudKitInitialSyncer.shared.currentProgress if available
                    // or use currentSyncInfo from CloudSyncManager
                    if let info = CloudSyncManager.shared.currentSyncInfo,
                       let romsCompleted = info["romsCompleted"] as? Int,
                       let romsTotal = info["romsTotal"] as? Int,
                       let savesCompleted = info["saveStatesCompleted"] as? Int,
                       let savesTotal = info["saveStatesTotal"] as? Int,
                       let biosCompleted = info["biosCompleted"] as? Int,
                       let biosTotal = info["biosTotal"] as? Int,
                       let batteryCompleted = info["batteryStatesCompleted"] as? Int,
                       let batteryTotal = info["batteryStatesTotal"] as? Int,
                       let screenshotsCompleted = info["screenshotsCompleted"] as? Int,
                       let screenshotsTotal = info["screenshotsTotal"] as? Int,
                       let skinsCompleted = info["deltaSkinsCompleted"] as? Int,
                       let skinsTotal = info["deltaSkinsTotal"] as? Int {
                        self.initialSyncProgress = CloudKitInitialSyncProgress(
                            romsCompleted: romsCompleted, romsTotal: romsTotal,
                            saveStatesCompleted: savesCompleted, saveStatesTotal: savesTotal,
                            biosCompleted: biosCompleted, biosTotal: biosTotal,
                            batteryStatesCompleted: batteryCompleted, batteryStatesTotal: batteryTotal,
                            screenshotsCompleted: screenshotsCompleted, screenshotsTotal: screenshotsTotal,
                            deltaSkinsCompleted: skinsCompleted, deltaSkinsTotal: skinsTotal
                        )
                    } else {
                        // If specific progress isn't in currentSyncInfo, perhaps set a generic one or nil
                         self.initialSyncProgress = nil // Or some placeholder
                    }
                } else if self.syncStatus != .initialSync {
                     self.initialSyncProgress = nil // Clear progress if not in initial sync
                }
                self.updateShouldShow()
            }
            .store(in: &cancellables)

        // Setup File Recovery Listeners
        setupFileRecoveryNotificationListeners()

        // TODO: Add listeners for other CloudKit events if necessary (e.g., specific item uploads/downloads)
    }

    private func setupFileRecoveryNotificationListeners() {
        NotificationCenter.default.removeObserver(self, name: iCloudDriveSync.iCloudFileRecoveryStarted, object: nil)
        NotificationCenter.default.removeObserver(self, name: iCloudDriveSync.iCloudFileRecoveryProgress, object: nil)
        NotificationCenter.default.removeObserver(self, name: iCloudDriveSync.iCloudFileRecoveryCompleted, object: nil)
        NotificationCenter.default.removeObserver(self, name: iCloudDriveSync.iCloudFileRecoveryError, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handleFileRecoveryStarted(_:)), name: iCloudDriveSync.iCloudFileRecoveryStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFileRecoveryProgress(_:)), name: iCloudDriveSync.iCloudFileRecoveryProgress, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFileRecoveryCompleted(_:)), name: iCloudDriveSync.iCloudFileRecoveryCompleted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFileRecoveryError(_:)), name: iCloudDriveSync.iCloudFileRecoveryError, object: nil)
    }

    private func setupStatusMessageManagerSubscription() {
        ILOG("ImportProgressViewModel: Setting up StatusMessageManager subscription.")
        StatusMessageManager.shared.$messages
            .receive(on: DispatchQueue.main)
            .assign(to: &$statusLogMessages)
    }

    @objc private func handleFileRecoveryStarted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.fileRecoveryState = .inProgress // PVPrimitives.FileRecoveryState.inProgress
            // Initialize progress. If totalFiles is 0, this indicates it's indeterminate or starting.
            let totalFiles = notification.userInfo?["totalFilesToRecover"] as? Int ?? 0
            self.fileRecoveryProgress = ProgressInfo(id: "fileRecovery", current: 0, total: totalFiles, detail: "Preparing recovery...")
            // Redundant: self.addLogMessage("iCloud file recovery started.", type: .info)
            self.updateShouldShow()
        }
    }

    @objc private func handleFileRecoveryProgress(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.fileRecoveryState == .inProgress else { return }
            if let userInfo = notification.userInfo,
               let filesProcessed = userInfo["filesProcessed"] as? Int,
               let totalFiles = userInfo["totalFilesToRecover"] as? Int {
                self.fileRecoveryProgress = ProgressInfo(id: "fileRecovery", current: filesProcessed, total: totalFiles, detail: "Recovering: \(filesProcessed)/\(totalFiles)")
                // Optionally, update log messages less frequently to avoid flooding
            } else if let message = notification.userInfo?["message"] as? String {
                 // Redundant: self.addLogMessage("Recovery: \(message)", type: .progress) // Use .progress type if available
            }
            self.updateShouldShow()
        }
    }

    @objc private func handleFileRecoveryCompleted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.fileRecoveryState = .complete // Use PVPrimitives.FileRecoveryState.complete
            self?.fileRecoveryProgress = nil
            // Redundant: self.addLogMessage("iCloud file recovery completed successfully.", type: .success)
            self?.updateShouldShow()
        }
    }

    @objc private func handleFileRecoveryError(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            var errorMessage = "iCloud file recovery encountered an error."
            if let userInfo = notification.userInfo, let error = userInfo[NSUnderlyingErrorKey] as? Error {
                errorMessage += " Details: \(error.localizedDescription)" // Log detailed error
            } else if let message = notification.userInfo?["message"] as? String {
                 errorMessage = message
            }
            self?.fileRecoveryState = .error // Use PVPrimitives.FileRecoveryState.error (no associated value)
            self?.fileRecoveryProgress = nil // Or keep progress to show where it failed?
            // Specific error logging here is good.
            self?.addLogMessage("iCloud file recovery error: \(errorMessage)", type: .error)
            self?.updateShouldShow()
        }
    }

    @objc private func handleCloudKitRecordTransferProgress(_ notification: Notification) {
        // Ensure updates are on the main thread for UI
        DispatchQueue.main.async {
            guard let userInfo = notification.userInfo,
                  let recordType = userInfo["recordType"] as? String,
                  let progress = userInfo["progress"] as? Double else {
                WLOG("Received CloudKitRecordTransferProgress notification with missing user info.")
                return
            }
            // Handle the progress update (e.g., update a dictionary of progresses by recordType)
            // Example: self.cloudKitTransferProgresses[recordType] = progress
            ILOG("CloudKit Transfer Progress for \(recordType): \(progress * 100)%")
            // Optionally, update a general 'shouldShow' flag if this view should appear
            self.updateShouldShow()
        }
    }

    @objc private func handleCloudKitRecordTransferCompleted(_ notification: Notification) {
        // Ensure updates are on the main thread for UI
        DispatchQueue.main.async {
            guard let userInfo = notification.userInfo,
                  let recordType = userInfo["recordType"] as? String,
                  let success = userInfo["success"] as? Bool else {
                WLOG("Received CloudKitRecordTransferCompleted notification with missing user info.")
                return
            }
            
            if success {
                ILOG("CloudKit Transfer Completed for \(recordType).")
                // Example: self.cloudKitTransferProgresses.removeValue(forKey: recordType)
            } else {
                ELOG("CloudKit Transfer Failed for \(recordType).")
                // Handle failure, maybe add to logMessages
                self.addLogMessage("Cloud sync failed for an item: \(recordType)", type: .error)
            }
            // Optionally, update a general 'shouldShow' flag
            self.updateShouldShow()
        }
    }

    // MARK: - Public Computed Properties for View Logic

    /// Determines if importer-specific UI (progress bars, queues) should be shown.
    public var shouldShowImporterSpecificUI: Bool {
        return isImporting ||
               isSyncing ||
               (fileRecoveryState != .idle && fileRecoveryState != .complete) ||
               importProgress != nil ||
               initialSyncProgress != nil ||
               (fileRecoveryProgress != nil && (fileRecoveryProgress?.current ?? 0) < (fileRecoveryProgress?.total ?? 0))
    }

    /// Provides a display string for the current file recovery state.
    public var fileRecoveryStateDisplayString: String {
        switch fileRecoveryState {
        case .idle:
            return "Idle"
        case .inProgress:
            return "In Progress"
        case .complete:
            return "Complete"
        case .error:
            return "Error"
        // Add other cases if they exist in PVPrimitives.FileRecoveryState
        default:
            // Attempt to get a capitalized string from the enum case name if possible,
            // otherwise, a generic description.
            // This requires FileRecoveryState to be CustomStringConvertible or have a way to get its name.
            // For simplicity now, let's assume we'll add specific cases or use a generic one.
            return String(describing: fileRecoveryState).capitalized // Fallback, might need refinement based on actual enum
        }
    }

    // MARK: - Private Helper Methods

    private func updateImportCounts() {
        var total = 0
        var processed = 0
        var new = 0
        var errors = 0

        total = importQueueItems.count

        for item in importQueueItems {
            switch item.status {
            case .processing:
                processed += 1
            case .success:
                processed += 1
                new += 1 // Assuming success means a new import for now
            case .failure:
                processed += 1
                errors += 1
            case .conflict:
                processed += 1 // Conflict means it was processed but needs user action
            case .queued, .partial:
                break // Not yet fully processed or waiting for more info
            @unknown default:
                break // Handle any future cases
            }
        }

        self.totalImportFileCount = total
        self.processedFilesCount = processed
        self.newFilesCount = new
        self.errorFilesCount = errors
    }

    private func reactToiCloudSettingChange(isEnabled: Bool) {
        if isEnabled {
            // Setting became enabled, ensure CloudKit subscriptions are active
            ILOG("iCloud Sync Setting Enabled: Ensuring CloudKit subscriptions are active.")
            setupCloudKitSubscriptions() // This method should be idempotent or handle re-subscription correctly
        } else {
            // Setting became disabled, clear related states and potentially cancel CloudKit activity
            ILOG("iCloud Sync Setting Disabled: Clearing iCloud related states.")
            self.isSyncing = false
            self.syncStatus = .disabled
            self.initialSyncProgress = nil
            // TODO: Consider explicitly canceling active CloudKit operations or subscriptions if CloudSyncManager supports it
            // For now, we'll rely on CloudKitSyncMonitor reacting to the disabled state if it observes it too.
        }
        updateShouldShow() // Re-evaluate visibility based on potential state changes
    }

    // MARK: - Helper to calculate visibility conditions
    private func _recalculateShouldShowConditions() -> Bool {
        // View should show if there's importer-specific activity OR if there are log messages.
        // lastErrorMessage is handled separately if it's meant to be a sticky, non-expiring error.
        return shouldShowImporterSpecificUI || !logMessages.isEmpty
    }

    // MARK: - Helper to update visibility
    private func updateShouldShow() {
        DispatchQueue.main.async { [weak self] in // Ensure UI updates are on main thread
            guard let self = self else { return }

            let conditionsMet = self._recalculateShouldShowConditions()

            if conditionsMet {
                // Conditions to show are met, so make sure view is visible and cancel any hide timer.
                self.hideViewTimer?.invalidate()
                self.hideViewTimer = nil
                if !self.shouldShow {
                    self.shouldShow = true
                    ILOG("ImportProgressViewModel: Conditions met, showing view.")
                }
            } else {
                // Conditions to show are NOT met.
                // If view is currently shown and no hide timer is active, start one.
                if self.shouldShow && self.hideViewTimer == nil {
                    ILOG("ImportProgressViewModel: Conditions NOT met, starting 8s hide timer.")
                    self.hideViewTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        // Re-check conditions one last time before hiding.
                        if !self._recalculateShouldShowConditions() {
                            self.shouldShow = false
                            ILOG("ImportProgressViewModel: Hide timer fired, hiding view.")
                        } else {
                            ILOG("ImportProgressViewModel: Hide timer fired, but conditions re-met. View stays visible.")
                        }
                        self.hideViewTimer = nil // Timer has fired, clear it.
                    }
                } else if !self.shouldShow {
                    // View is already hidden, do nothing.
                } else if self.hideViewTimer != nil {
                    // Timer is already running, do nothing, let it fire.
                    ILOG("ImportProgressViewModel: Conditions NOT met, hide timer already active.")
                }
            }
        }
    }

    /// Toggles the display of the import progress view, primarily for manual intervention or debugging.
    @available(*, deprecated, message: "Manual toggling is generally not recommended. Use conditions like log messages or activity.")
    public func toggleDisplay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let newShouldShow = !self.shouldShow
            if newShouldShow {
                self.shouldShow = true
                ILOG("ImportProgressView toggled ON manually.")
            } else {
                // If toggling off manually, and there are no conditions to keep it open,
                // respect the manual toggle. Otherwise, if conditions *would* keep it open,
                // this manual toggle might be immediately overridden unless we add special logic.
                // For now, simply set shouldShow, but rely on updateShouldShow for proper state.
                self.shouldShow = false
                ILOG("ImportProgressView toggled OFF manually - will re-evaluate on next update.")
            }
            // After manual toggle, it's good to let conditions re-evaluate if it was turned off.
            if !newShouldShow {
                self.updateShouldShow() // This will likely keep it on if conditions are met.
            }
        }
        // Note: The old direct toggle of shouldShow and its log message are replaced by the above logic.
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cancellables.forEach { $0.cancel() }
        messageExpiryTimers.values.forEach { $0.invalidate() } // Invalidate individual message timers
        hideViewTimer?.invalidate() // Ensure overall view hide timer is cleaned up
        ILOG("ImportProgressViewModel deinitialized")
    }
}
