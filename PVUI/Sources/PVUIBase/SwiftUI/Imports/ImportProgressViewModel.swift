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

    // MARK: - Private Properties

    private let gameImporter: any GameImporting
    private var cancellables = Set<AnyCancellable>()
    private var cloudKitCancellables = Set<AnyCancellable>()
    private var hideTimer: AnyCancellable?

    /// User's preference for enabling iCloud Sync, passed from the View
    private var iCloudSyncEnabledSetting: Bool = Defaults[.iCloudSync]

    private let maxStoredMessages = 50
    private let fileRecoveryProgressID = "icloud-file-recovery"

    // MARK: - Initialization

    public init(gameImporter: any GameImporting = GameImporter.shared) {
        self.gameImporter = gameImporter
        ILOG("ImportProgressViewModel initialized with GameImporter and iCloud Sync setting: \(iCloudSyncEnabledSetting)")

        // Consolidated setup call
        setupPrimarySubscriptions()

        // REMOVE THIS BLOCK - Replaced by notification listeners and initial state in setupFileRecoveryNotificationListeners
        // if iCloudSync.shared.fileRecoveryState == .inProgress {
        //     self.fileRecoveryState = .inProgress
        //     // If we know total files, we can set up progress here, or wait for notification
        // }
    }

    // MARK: - Public Methods for View Interaction

    /// Called by the View (e.g., onAppear) to pass the current iCloud sync setting.
    public func setupTracking(iCloudEnabled: Bool) {
        ILOG("ImportProgressViewModel: setupTracking with iCloudEnabled: \(iCloudEnabled)")
        let oldSetting = self.iCloudSyncEnabledSetting
        self.iCloudSyncEnabledSetting = iCloudEnabled

        if oldSetting != iCloudEnabled {
            // iCloud setting changed, re-evaluate CloudKit subscriptions and status
            cloudKitCancellables.forEach { $0.cancel() } // Assuming a marker interface or specific check

            if iCloudEnabled {
                setupCloudKitSubscriptions()
                Task {
                    // Potentially trigger a re-check of sync status if needed
                    // For example, if CloudSyncManager has a method to refresh its status
                    refreshInitialSyncStatus()
                }
            } else {
                // If iCloud is now disabled by user preference, clear related states
                self.isSyncing = false
                self.syncStatus = .disabled
                self.initialSyncProgress = nil
                // Consider canceling any active CloudKit operations if possible and appropriate
            }
        }
        checkHideCondition()
    }

    public func cleanup() {
        ILOG("ImportProgressViewModel: Cleaning up.")
        cancellables.removeAll()
        cloudKitCancellables.removeAll()
        hideTimer?.cancel()
    }

    /// Add a log message (newer feature)
    public func addLogMessage(_ message: String, type: StatusMessageManager.StatusMessage.MessageType = .info) {
        let statusMessage = StatusMessageManager.StatusMessage(message: message, type: type)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.logMessages.insert(statusMessage, at: 0)
            if self.logMessages.count > self.maxStoredMessages {
                self.logMessages = Array(self.logMessages.prefix(self.maxStoredMessages))
            }
            self.updateShouldShow()
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
        setupGameImporterSubscription()
        setupCloudKitSubscriptions()
        setupFileRecoveryNotificationListeners() // Sets initial state from iCloudDriveSync notifications
        setupTracking(iCloudEnabled: iCloudSyncEnabledSetting) // Pass the iCloud setting
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
                var statusCounts: [ImportQueueItem.ImportStatus: Int] = [:]
                for item in queue {
                    statusCounts[item.status, default: 0] += 1
                }
                ILOG("Import queue received via Publisher. Count: \(queue.count). Statuses: \(statusCounts.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")

                self.importQueueItems = queue // Update the @Published property

                // Calculate if any imports are active (not all are success or failure)
                let activeImports = !queue.isEmpty && !queue.allSatisfy { $0.status == .success || $0.status == .failure }
                if self.isImporting != activeImports {
                    self.isImporting = activeImports
                    ILOG("isImporting toggled to: \(self.isImporting) (from Publisher)")
                }
                self.updateShouldShow()
            }
            .store(in: &cancellables)

        // Also fetch initial queue state if needed, or rely purely on publisher
        Task { [weak self, weak concreteImporter] in
            guard let self = self, let concreteImporter = concreteImporter else { return }
            let queue = await concreteImporter.importQueue
            await MainActor.run {
                // Detailed logging for initial fetch if different
                var statusCounts: [ImportQueueItem.ImportStatus: Int] = [:]
                for item in queue {
                    statusCounts[item.status, default: 0] += 1
                }
                ILOG("Import queue received via Task. Count: \(queue.count). Statuses: \(statusCounts.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")
                
                self.importQueueItems = queue
                let activeImports = !queue.isEmpty && !queue.allSatisfy { $0.status == .success || $0.status == .failure }
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
            .store(in: &cloudKitCancellables)

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

    @objc private func handleFileRecoveryStarted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.fileRecoveryState = .inProgress // PVPrimitives.FileRecoveryState.inProgress
            // Initialize progress. If totalFiles is 0, this indicates it's indeterminate or starting.
            let totalFiles = notification.userInfo?["totalFilesToRecover"] as? Int ?? 0
            self.fileRecoveryProgress = ProgressInfo(id: "fileRecovery", current: 0, total: totalFiles, detail: "Preparing recovery...")
            self.addLogMessage("iCloud file recovery started.", type: .info)
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
                 self.addLogMessage("Recovery: \(message)", type: .progress) // Use .progress type if available
            }
            self.updateShouldShow()
        }
    }

    @objc private func handleFileRecoveryCompleted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.fileRecoveryState = .complete // Use PVPrimitives.FileRecoveryState.complete
            self?.fileRecoveryProgress = nil
            self?.addLogMessage("iCloud file recovery completed successfully.", type: .success)
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
            self?.addLogMessage(errorMessage, type: .error) // Log the constructed error message
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

    /// Sets up a timer to hide the view if conditions are met.
    private func setupHideTimer() {
        hideTimer?.cancel() // Cancel any existing timer
        hideTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.checkHideCondition(triggeredByTimer: true)
        } // Removed .store(in: &cancellables) as hideTimer is already AnyCancellable?
    }

    /// Stop the hide timer.
    private func stopHideTimer() {
        hideTimer?.cancel()
    }

    // MARK: - Visibility Logic (shouldShow)

    private func checkHideCondition(triggeredByTimer: Bool = false) {
        // Condition 1: Active import items (not all success or failure)
        let activeImports = !importQueueItems.isEmpty && !importQueueItems.allSatisfy { $0.status == .success || $0.status == .failure }

        // Condition 2: iCloud Syncing (if user has it enabled in settings)
        let activeCloudSync = iCloudSyncEnabledSetting && self.isSyncing

        // Condition 3: New features - active progress bars (non-import related)
        let activeMiscProgress = !activeProgressBars.isEmpty

        // Condition 4: New features - log messages present
        let hasLogMessages = !logMessages.isEmpty

        // Condition 5: New features - file recovery active
        let activeFileRecovery = fileRecoveryState != .idle

        // Condition 6: Initial Sync progress is ongoing
        let initialSyncOngoing = iCloudSyncEnabledSetting && (initialSyncProgress != nil && (initialSyncProgress?.overallProgress ?? 1.0) < 1.0)


        let shouldBeVisible = activeImports || activeCloudSync || activeMiscProgress || hasLogMessages || activeFileRecovery || initialSyncOngoing

        DLOG("CheckHideCondition: activeImports=\(activeImports), activeCloudSync=\(activeCloudSync) (enabled=\(iCloudSyncEnabledSetting), isSyncing=\(isSyncing)), activeMiscProgress=\(activeMiscProgress), hasLogMessages=\(hasLogMessages), activeFileRecovery=\(activeFileRecovery), initialSyncOngoing=\(initialSyncOngoing). ==> shouldBeVisible=\(shouldBeVisible)")


        if shouldBeVisible {
            if !self.shouldShow { self.shouldShow = true }
            hideTimer?.cancel() // Activity detected, cancel any pending hide
        } else {
            // No direct activity, schedule hide if not already hidden
            if self.shouldShow { // Only schedule hide if currently shown
                 if triggeredByTimer { // Timer fired, and still no activity
                    self.shouldShow = false
                } else {
                    setupHideTimer()
                }
            }
        }
    }

    public func refreshInitialSyncStatus() {
        ILOG("refreshInitialSyncStatus called")
        // CloudSyncManager.shared.forceRefreshState() // Removed: forceRefreshState does not exist
        // Instead, rely on existing publishers or re-evaluate how to trigger a state update if necessary.
        // For now, this function might not do anything if CloudSyncManager handles its state internally.
    }

    private func updateShouldShow() {
        let newShouldShow = isImporting || 
                            isSyncing || 
                            (fileRecoveryState != .idle && fileRecoveryState != .complete) || // Adapted: no .notStarted, use .complete
                            !logMessages.isEmpty || 
                            importProgress != nil || 
                            initialSyncProgress != nil || 
                            (fileRecoveryProgress != nil && (fileRecoveryProgress?.current ?? 0) < (fileRecoveryProgress?.total ?? 0))

        if self.shouldShow != newShouldShow {
            self.shouldShow = newShouldShow
            ILOG("ImportProgressView shouldShow toggled to: \(self.shouldShow) based on: isImporting=\(isImporting), isSyncing=\(isSyncing), fileRecoveryState=\(fileRecoveryState), logMessages.isEmpty=\(logMessages.isEmpty), importProgress=\(String(describing: importProgress)), initialSyncProgress=\(String(describing: initialSyncProgress)), fileRecoveryProgress=\(String(describing: fileRecoveryProgress))")
        }
    }

    deinit {
        ILOG("ImportProgressViewModel deinitialized.")
        cleanup()
    }
}
