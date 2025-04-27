//
//  ImportProgressViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/26/25.
//

import Combine
import Defaults
import Foundation
import PVLibrary
import PVLogging
import PVPrimitives
import PVSettings
import PVThemes
import PVUIBase
import Perception
import SwiftUI

/// View model for the ImportProgressView
public class ImportProgressViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Active progress bars to display
    @Published var activeProgressBars: [ProgressInfo] = []
    
    /// Log messages to display
    @Published var logMessages: [StatusMessage] = []
    
    /// Maximum number of log messages to keep in memory
    private let maxStoredMessages = 50
    
    /// Import queue items
    @Published var importQueueItems: [ImportQueueItem] = []
    
    /// Track iCloud sync activity
    @Published var pendingDownloads = 0
    @Published var pendingUploads = 0
    @Published var newFilesCount = 0
    @Published var isSyncing = false
    
    /// The current sync status
    @Published var syncStatus: SyncStatus = .idle
    
    /// Initial sync progress
    @Published var initialSyncProgress: InitialSyncProgress? = nil
    
    /// Animation properties
    @Published var glowOpacity: Double = 0.7
    @Published var animatedProgressOffset: CGFloat = 0
    
    /// Flag to show/hide the view
    @Published var shouldShow: Bool = false
    
    // MARK: - Private Properties
    
    /// The game importer to track
    private let gameImporter: any GameImporting
    
    /// Subscriptions for tracking
    private var cancellables = Set<AnyCancellable>()
    
    // Timers for debouncing and hiding
    private var debounceTimer: Timer?
    private var hideTimer: AnyCancellable?
    
    /// File recovery state
    @Published var fileRecoveryState: FileRecoveryState = .idle
    @Published var fileRecoveryProgress: ProgressInfo?
    private let fileRecoveryProgressID = "icloud-file-recovery"
    
    /// CloudKit activity flag
    @Published private(set) var cloudKitIsActive: Bool = false
    
    /// Subscriptions for sync tracking
    private var syncSubscriptions = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize the view model with a game importer
    public init(gameImporter: GameImporting = GameImporter.shared) {
        self.gameImporter = gameImporter
        setupCloudKitSubscriptions()
        setupNotificationObservers()
        
        // Initial check for recovery state - Removed direct access
        // self.fileRecoveryState = iCloudSync.shared.fileRecoveryState
        if self.fileRecoveryState == .inProgress {
            // This block likely won't execute now unless the default state changes
            // or is updated *before* this check by one of the setup methods.
            // Consider if this logic needs adjustment based on subscription timing.
            // Corrected argument labels: id, current, total, detail
            self.fileRecoveryProgress = ProgressInfo(id: fileRecoveryProgressID, current: 0, total: 0, detail: "Recovering Files...")
            self.addLogMessage("File recovery started.")
        }
        
        // Start animations
        startAnimations()
        
        // Ensure the view is visible when there are active operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Check if we have any active operations from other view models
            self.checkForExistingOperations()
        }
    }
    
    // MARK: - Public Methods
    
    /// Set up tracking for the view model
    public func setupTracking(iCloudEnabled: Bool) {
        ILOG("ImportProgressViewModel: Setting up tracking with iCloud: \(iCloudEnabled)")
        
        // Clean up existing subscriptions
        syncSubscriptions.removeAll()
        
        // Setup CloudKit subscriptions if iCloud is enabled
        if iCloudEnabled {
            setupCloudKitSubscriptions()
        }
    }
    
    /// Start animations for progress bars and glow effects
    public func startAnimations() {
        // Create a repeating animation for the progress bars
        Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                withAnimation(.linear(duration: 0.05)) {
                    self.animatedProgressOffset = (self.animatedProgressOffset + 1).truncatingRemainder(dividingBy: 20)
                }
            }
            .store(in: &cancellables)
        
        // Create a repeating animation for the glow effect
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.glowOpacity = self.glowOpacity == 0.7 ? 1.0 : 0.7
                }
            }
            .store(in: &cancellables)
    }
    
    /// Clean up resources when the view disappears
    public func cleanup() {
        ILOG("ImportProgressViewModel: Cleaning up resources")
        cancellables.removeAll()
        syncSubscriptions.removeAll()
        hideTimer?.cancel()
        debounceTimer?.invalidate()
    }
    
    /// Add a log message to the view
    public func addLogMessage(_ message: String, type: StatusMessage.MessageType = .info) {
        let statusMessage = StatusMessage(message: message, type: type)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.logMessages.insert(statusMessage, at: 0)
            
            // Keep only the most recent messages
            if self.logMessages.count > self.maxStoredMessages {
                self.logMessages = Array(self.logMessages.prefix(self.maxStoredMessages))
            }
            
            // Show the view when there are messages
            self.shouldShow = true
            
            // Schedule hiding the view after a delay
            self.scheduleHideAfterDelay()
        }
    }
    
    /// Update a progress bar or create a new one
    public func updateProgress(id: String, detail: String?, current: Int, total: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let progressInfo = ProgressInfo(id: id, current: current, total: total, detail: detail ?? id)
            
            // Update progress tracking
            if let index = self.activeProgressBars.firstIndex(where: { $0.id == id }) {
                // Update existing progress bar only if values changed
                if self.activeProgressBars[index].current != current || self.activeProgressBars[index].total != total || self.activeProgressBars[index].detail != detail {
                    self.activeProgressBars[index] = progressInfo
                    DLOG("Updated existing progress bar: \(id) - \(current)/\(total)")
                    self.objectWillChange.send() // Send update only if changed
                    self.debounceUpdate() // Debounce if changes occur
                }
            } else {
                // Add a new progress bar
                self.activeProgressBars.append(progressInfo)
                DLOG("Added new progress bar: \(id) - \(current)/\(total)")
                self.objectWillChange.send()
                self.debounceUpdate()
            }
            
            // Ensure the view is shown when there's activity
            self.updateShowState()
        }
    }
    
    /// Remove a progress bar by ID
    public func removeProgress(id: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let initialCount = self.activeProgressBars.count
            self.activeProgressBars.removeAll { $0.id == id }
            if self.activeProgressBars.count < initialCount {
                DLOG("Removed progress bar with ID: \(id)")
                self.objectWillChange.send()
                self.updateShowState() // Update visibility after removal
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Schedule hiding the view after a delay
    private func scheduleHideAfterDelay() {
        // Cancel any existing hide timer
        hideTimer?.cancel()
        
        // Only hide if there are no active items
        if self.activeProgressBars.isEmpty && self.logMessages.isEmpty {
            DLOG("Scheduling hide timer for ImportProgressView")
            
            // Schedule a new hide timer
            hideTimer = Timer.publish(every: 3.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Double-check that we still have no active items before hiding
                    if self.activeProgressBars.isEmpty && self.logMessages.isEmpty {
                        DLOG("Hiding ImportProgressView")
                        self.shouldShow = false
                        self.objectWillChange.send()
                    } else {
                        DLOG("Canceling hide - new items appeared")
                    }
                    
                    self.hideTimer?.cancel()
                    self.hideTimer = nil
                }
        }
    }
    
    /// Handle debouncing of updates to prevent flickering
    private func debounceUpdate() {
        debounceTimer?.invalidate()
        
        // Use a longer debounce interval for CloudKit operations to prevent flickering
        let debounceInterval: TimeInterval = cloudKitIsActive ? 1.0 : 0.1
        
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DLOG("Debounced update for ImportProgressViewModel with interval: \(debounceInterval)")
            self.objectWillChange.send()
        }
    }
    
    /// Check for existing operations from other view models
    private func checkForExistingOperations() {
        DLOG("Checking for existing operations from other view models")
        
        // Post a request for status updates
        NotificationCenter.default.post(name: Notification.Name("RequestProgressUpdates"), object: nil)
        
        // Check if we have any active progress bars
        if !activeProgressBars.isEmpty {
            DLOG("Found \(activeProgressBars.count) active progress bars")
            shouldShow = true
            objectWillChange.send()
        }
        
        // Check if there are any active file recovery operations
        if fileRecoveryState == .inProgress {
            shouldShow = true
        }
        
        // Check if there are any active CloudKit operations
        if cloudKitIsActive {
            shouldShow = true
        }
        
        // Check if there are any items in the import queue
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let queue = await self.gameImporter.importQueue
            if !queue.isEmpty {
                self.importQueueItems = queue
                self.shouldShow = true
                self.updateImportQueueProgress()
            }
        }
    }
    
    /// Refresh the import queue from the GameImporter
    @MainActor
    private func refreshImportQueue() async {
        DLOG("Refreshing import queue")
        let queue = await gameImporter.importQueue
        self.importQueueItems = queue
        self.updateImportQueueProgress()
        self.shouldShow = !queue.isEmpty || !self.activeProgressBars.isEmpty
    }
    
    /// Update progress bars based on the current import queue
    @MainActor
    private func updateImportQueueProgress() {
        // Remove any existing import queue progress bars
        activeProgressBars.removeAll { $0.id.hasPrefix("import-") }
        
        // Add a progress bar for each import queue item
        for (index, item) in importQueueItems.enumerated() {
            let fileName = item.url.lastPathComponent
            let progressId = "import-\(index)"
            
            // For each item, create a progress bar
            let detail = "Importing: \(fileName)"
            updateProgress(id: progressId, detail: detail, current: 0, total: 1)
            
            // Add a log message for new items
            if !logMessages.contains(where: { $0.message.contains(fileName) }) {
                addLogMessage("Queued for import: \(fileName)")
            }
        }
    }
    
    /// Set up CloudKit subscriptions
    private func setupCloudKitSubscriptions() {
        ILOG("Setting up CloudKit subscriptions for ImportProgressViewModel")
        // Check if iCloud sync is enabled
        guard Defaults[.iCloudSync] else {
            WLOG("iCloud Sync not enabled, skipping CloudKit subscriptions.")
            return
        }
        
        // Clear existing sync subscriptions to avoid duplicates
        syncSubscriptions.removeAll()
        cloudKitIsActive = false // Reset active state
        
        // Setup CloudKit subscriptions
        CloudSyncManager.shared.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                
                // Update activity flag based on overall status
                let isActive: Bool
                var statusText: String = ""
                
                switch status {
                case .idle:
                    isActive = false
                case .syncing:
                    isActive = true
                    statusText = "Syncing..."
                case .initialSync:
                    isActive = true
                    statusText = "Performing Initial Sync..."
                case .uploading:
                    isActive = true
                    statusText = "Uploading..."
                case .downloading:
                    isActive = true
                    statusText = "Downloading..."
                case .error(let error):
                    isActive = false // Or true if you want to show error state
                    ELOG("CloudSyncManager reported error: \(error.localizedDescription)")
                case .disabled:
                    isActive = false
                    statusText = "CloudKit Disabled"
                }
                
                // If changing from inactive to active, update immediately
                if !self.cloudKitIsActive && isActive {
                    self.cloudKitIsActive = true
                    self.debounceUpdate()
                } 
                // If changing from active to inactive, delay to prevent flickering
                else if self.cloudKitIsActive && !isActive {
                    // Delay deactivation to prevent flickering during rapid sync operations
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        guard let self = self else { return }
                        // Only deactivate if no new sync has started
                        if status == .idle || status == .disabled || status == .error(nil) {
                            self.cloudKitIsActive = false
                            self.debounceUpdate()
                        }
                    }
                }
                
                // Optionally, update a specific progress bar or show general status text
                // Example: Create/update a general 'cloud-status' progress item
                if isActive {
                    self.updateProgress(id: "cloud-status", detail: statusText, current: 1, total: 1)
                } else {
                    self.removeProgress(id: "cloud-status")
                }
                
                self.updateShowState()
            }
            .store(in: &syncSubscriptions)
        
        ILOG("CloudKit subscriptions set up.")
    }
    
    /// Set up notification observers for progress updates
    private func setupNotificationObservers() {
        let nc = NotificationCenter.default
        
        // Listen for progress updates (e.g., cache management, downloads)
        nc.publisher(for: .cacheManagementProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleProgressUpdate(notification: notification, identifier: "cache-management", defaultDetail: "Cache Management")
            }
            .store(in: &cancellables)
        
        nc.publisher(for: .downloadProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleProgressUpdate(notification: notification, identifier: "download", defaultDetail: "Downloading")
            }
            .store(in: &cancellables)
        
        // Observe individual files pending recovery (adds to a list, maybe)
        nc.publisher(for: iCloudSync.iCloudFilePendingRecovery)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let filename = notification.userInfo?["filename"] as? String {
                    // Optionally update UI or track pending files
                    self?.addLogMessage("File pending recovery: \(filename)")
                    VLOG("File pending recovery: \(filename)")
                }
            }
            .store(in: &cancellables)
        
        // Listen for ROM scanning progress
        nc.publisher(for: .romScanningProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleProgressUpdate(notification: notification, identifier: "rom-scan", defaultDetail: "Scanning ROMs")
            }
            .store(in: &cancellables)
        
        nc.publisher(for: .romScanningCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleProgressCompletion(notification: notification, identifier: "rom-scan", completionDetail: "ROM Scan Finished")
            }
            .store(in: &cancellables)
        
        // Listen for iCloud File Recovery progress
        setupFileRecoverySubscriptions()
        
        // Track GameImporter queue changes
        setupGameImporterTracking()
    }
    
    /// Sets up subscriptions specifically for iCloud file recovery notifications.
    private func setupFileRecoverySubscriptions() {
        let nc = NotificationCenter.default
        let recoveryID = self.fileRecoveryProgressID
        
        // Observe file recovery started
        nc.publisher(for: iCloudSync.iCloudFileRecoveryStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.fileRecoveryState = .inProgress
                    self.updateProgress(id: recoveryID, detail: "Recovering Files...", current: 0, total: 0) // Start progress at 0
                    self.addLogMessage("File recovery started.")
                }
            }
            .store(in: &cancellables)
        
        // Observe file recovery progress
        nc.publisher(for: iCloudSync.iCloudFileRecoveryProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                // Only update if recovery is actually in progress
                guard self.fileRecoveryState == .inProgress else {
                    VLOG("Received recovery progress notification but state is not .inProgress (\(self.fileRecoveryState)), ignoring.")
                    return
                }
                
                if let progressInfo = self.parseProgressInfo(from: notification, identifier: recoveryID, defaultDetail: "File Recovery") {
                    Task { @MainActor in
                        self.fileRecoveryProgress = progressInfo
                        self.updateProgress(id: progressInfo.id, detail: progressInfo.detail, current: progressInfo.current, total: progressInfo.total)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe file recovery completion
        nc.publisher(for: iCloudSync.iCloudFileRecoveryCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.fileRecoveryState = .complete
                    self.removeProgress(id: recoveryID)
                    self.addLogMessage("File recovery completed.")
                }
            }
            .store(in: &cancellables)
        
        // Observe file recovery errors
        nc.publisher(for: iCloudSync.iCloudFileRecoveryError)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.fileRecoveryState = .error
                    self.removeProgress(id: recoveryID)
                    let errorDetail = notification.userInfo?["error"] as? String ?? "Unknown file recovery error"
                    self.addLogMessage("File recovery error: \(errorDetail)")
                }
            }
            .store(in: &cancellables)
    }
    
    /// Set up tracking for the GameImporter's queue and status changes
    private func setupGameImporterTracking() {
        ILOG("Setting up GameImporter tracking")
        
        // Subscribe to the importQueuePublisher to get real-time updates
        Task {
            let gameImporter = self.gameImporter
            
            gameImporter.importQueuePublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] queueItems in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        DLOG("Received import queue update: \(queueItems.count) items")
                        self.importQueueItems = queueItems
                        self.updateImportQueueProgress()
                        self.shouldShow = !queueItems.isEmpty || !self.activeProgressBars.isEmpty
                    }
                }
                .store(in: &cancellables)
            
            // Initial refresh
            await refreshImportQueue()
        }
        
        // Listen for import started notifications
        NotificationCenter.default.publisher(for: Notification.Name("ImportStarted"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let path = notification.object as? String {
                    self.addLogMessage("Import started: \(URL(fileURLWithPath: path).lastPathComponent)")
                } else {
                    self.addLogMessage("Import started")
                }
                self.shouldShow = true
            }
            .store(in: &cancellables)
        
        // Listen for import completed notifications
        NotificationCenter.default.publisher(for: Notification.Name("ImportCompleted"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let success = notification.userInfo?["success"] as? Bool, !success {
                    if let error = notification.userInfo?["error"] as? Error {
                        self.addLogMessage("Import failed: \(error.localizedDescription)", type: .error)
                    } else {
                        self.addLogMessage("Import failed", type: .error)
                    }
                } else {
                    self.addLogMessage("Import completed successfully")
                }
            }
            .store(in: &cancellables)
    }
    
    
    /// Updates the `shouldShow` property based on current activity.
    private func updateShowState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // View should show if there are active progress bars or recent log messages
            let shouldBeVisible = !self.activeProgressBars.isEmpty || self.cloudKitIsActive
            
            if self.shouldShow != shouldBeVisible {
                DLOG("Updating shouldShow from \(self.shouldShow) to \(shouldBeVisible). Active Bars: \(self.activeProgressBars.count), CloudKit Active: \(self.cloudKitIsActive)")
                self.shouldShow = shouldBeVisible
                self.objectWillChange.send()
            }
            
            // Schedule hiding only if it should be hidden and no operations are active
            if !self.shouldShow && self.activeProgressBars.isEmpty && !self.cloudKitIsActive {
                self.scheduleHideAfterDelay() // Hide after 3 seconds if truly idle
            } else {
                // If it should be showing, cancel any pending hide timer
                self.hideTimer?.cancel()
                self.hideTimer = nil
            }
        }
    }
    
    /// Handles updates from ProgressInfo notifications.
    private func handleProgressUpdate(progressInfo: ProgressInfo) {
        updateProgress(id: progressInfo.id, detail: progressInfo.detail, current: progressInfo.current, total: progressInfo.total)
        self.updateShowState()
    }
    
    /// Handles completion from ProgressInfo notifications.
    private func handleProgressCompletion(progressInfo: ProgressInfo) {
        removeProgress(id: progressInfo.id)
        self.updateShowState()
    }
    
    /// Handles generic progress update notifications.
    /// - Parameters:
    ///   - notification: The notification containing progress info.
    ///   - identifier: The unique ID for this progress item.
    ///   - defaultDetail: A default description if the notification doesn't provide one.
    private func handleProgressUpdate(notification: Notification, identifier: String, defaultDetail: String) {
        if let progressInfo = parseProgressInfo(from: notification, identifier: identifier, defaultDetail: defaultDetail) {
            Task { @MainActor [weak self] in
                self?.updateProgress(id: progressInfo.id, detail: progressInfo.detail, current: progressInfo.current, total: progressInfo.total)
            }
        }
    }
    
    /// Handles generic progress completion notifications.
    /// - Parameters:
    ///   - notification: The notification indicating completion.
    ///   - identifier: The unique ID of the progress item to remove.
    ///   - completionDetail: A message to log upon completion.
    private func handleProgressCompletion(notification: Notification, identifier: String, completionDetail: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.removeProgress(id: identifier)
            self.addLogMessage("\(completionDetail).") // Ensure this matches signature
            VLOG("Progress completed for \(identifier). Notification: \(notification.name.rawValue)")
        }
    }
    
    /// Parses `ProgressInfo` from a notification's `userInfo` dictionary.
    /// - Returns: A `ProgressInfo` object if parsing is successful, otherwise `nil`.
    private func parseProgressInfo(from notification: Notification, identifier: String, defaultDetail: String) -> ProgressInfo? {
        // Attempt to extract ProgressInfo directly if it's the object
        if let progressInfo = notification.object as? ProgressInfo {
            return progressInfo
        }
        
        // Fallback: Extract from userInfo dictionary using standard keys
        guard let userInfo = notification.userInfo,
              // Use standard string keys
              let current = userInfo["current"] as? Int,
              let total = userInfo["total"] as? Int else {
            WLOG("Could not parse ProgressInfo from notification userInfo: \(notification.userInfo ?? [:])")
            return nil // Missing essential info
        }
        
        // Get ID, defaulting to the passed identifier if missing
        let id = userInfo["id"] as? String ?? identifier
        
        // Detail is optional
        let detail = userInfo["detail"] as? String ?? defaultDetail
        
        // Use the correct initializer, casting Double to Int as confirmed by definition
        return ProgressInfo(id: id, current: current, total: total, detail: detail)
    }
}
