//
//  ImportProgressViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/26/25.
//

import Combine
import Defaults
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
    
    /// Timer for hiding the view after a delay
    private var hideTimer: AnyCancellable?
    
    /// Debounce timer for updates to prevent flickering
    private var debounceTimer: Timer?
    
    /// File recovery state
    @Published var fileRecoveryState: FileRecoveryState = .idle
    @Published var fileRecoveryProgress: ProgressInfo?
    
    /// CloudKit activity flag
    private var cloudKitIsActive: Bool = false
    
    /// Subscriptions for sync tracking
    private var syncSubscriptions = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize the view model with a game importer
    public init(gameImporter: any GameImporting) {
        self.gameImporter = gameImporter
        
        // Set up queue subscription
        setupQueueSubscription(gameImporter: gameImporter)
        
        // Set up CloudKit subscriptions if iCloud sync is enabled
        if Defaults[.iCloudSync] {
            setupCloudKitSubscriptions()
        }
        
        // Set up notification observers
        setupNotificationObservers()
        
        // Start animations
        startAnimations()
        startAnimation()  // For progress bars
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
    
    /// Start animations for progress bars
    public func startAnimation() {
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
    }
    
    /// Start animations for glow effects
    public func startAnimations() {
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
            
            // Remove any existing progress bars with the same detail text
            self.activeProgressBars.removeAll(where: { $0.detail == detail })
            
            // Create a new progress info with the updated values
            let progressInfo = ProgressInfo(current: current, total: total, detail: detail)
            
            // Add the new progress bar
            self.activeProgressBars.append(progressInfo)
            
            // Show the view when there are active progress bars
            self.shouldShow = true
            
            // Debounce updates to prevent flickering
            self.debounceUpdate()
        }
    }
    
    /// Remove a progress bar by ID
    public func removeProgress(id: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove progress bars with matching detail
            self.activeProgressBars.removeAll(where: { $0.detail == id })
            
            // Schedule hiding the view if there are no more progress bars
            if self.activeProgressBars.isEmpty && self.logMessages.isEmpty {
                self.scheduleHideAfterDelay()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Schedule hiding the view after a delay
    private func scheduleHideAfterDelay() {
        // Cancel any existing hide timer
        hideTimer?.cancel()
        
        // Create a new timer to hide the view after 5 seconds
        hideTimer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Only hide if there are no active progress bars or sync activities
                if self.activeProgressBars.isEmpty && !self.isSyncing && self.importQueueItems.isEmpty {
                    self.shouldShow = false
                }
                
                // Cancel the timer after it fires once
                self.hideTimer?.cancel()
            }
    }
    
    /// Handle debouncing of updates to prevent flickering
    private func debounceUpdate() {
        // Cancel any existing debounce timer
        debounceTimer?.invalidate()
        
        // Create a new timer to update the UI after a short delay
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Force a UI update by triggering objectWillChange
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    /// Set up CloudKit subscriptions
    private func setupCloudKitSubscriptions() {
        // Get the syncers from the store
        guard let syncers = getSyncers() else {
            ELOG("ImportProgressViewModel: No syncers available")
            return
        }
        
        // Track sync status for each syncer
        for syncer in syncers {
            // Since SyncProvider doesn't have the required publishers yet,
            // we'll set up a basic implementation that doesn't rely on those properties
            
            // Set default status values on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Set default status
                self.syncStatus = .idle
                self.isSyncing = false
                self.pendingUploads = 0
                self.pendingDownloads = 0
                self.newFilesCount = 0
            }
            
            // Subscribe to relevant notifications instead
            setupSyncNotificationObservers()
        }
    }
    
    /// Set up notification observers for sync status updates
    private func setupSyncNotificationObservers() {
        let nc = NotificationCenter.default
        
        // CloudKit sync status notifications
        nc.publisher(for: .cloudKitInitialSyncStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.syncStatus = .syncing
                self.isSyncing = true
                self.shouldShow = true
            }
            .store(in: &syncSubscriptions)
        
        nc.publisher(for: .cloudKitInitialSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.syncStatus = .idle
                self.isSyncing = false
                
                if self.activeProgressBars.isEmpty && self.importQueueItems.isEmpty {
                    self.scheduleHideAfterDelay()
                }
            }
            .store(in: &syncSubscriptions)
    }
    
    /// Set up notification observers
    private func setupNotificationObservers() {
        let nc = NotificationCenter.default
        
        // File recovery notifications
        nc.publisher(for: Notification.Name("iCloudFileRecoveryStarted"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                self.fileRecoveryState = .inProgress
                self.addLogMessage("iCloud file recovery started", type: .info)
                
                // Create a new progress info for file recovery
                let fileRecoveryInfo = ProgressInfo(current: 0, total: 100, detail: "File Recovery")
                
                // Update our stored progress info
                self.fileRecoveryProgress = fileRecoveryInfo
                
                // Remove any existing file recovery progress bars
                self.activeProgressBars.removeAll(where: { $0.detail == "File Recovery" })
                
                // Add the new progress bar
                self.activeProgressBars.append(fileRecoveryInfo)
            }
            .store(in: &cancellables)
            
        nc.publisher(for: Notification.Name("iCloudFileRecoveryProgress"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                guard let userInfo = notification.userInfo,
                       let progress = userInfo["progress"] as? Double,
                       let current = userInfo["current"] as? Int,
                       let total = userInfo["total"] as? Int else {
                    return
                }
                
                // Create a new progress info
                let newProgressInfo = ProgressInfo(current: current, total: total, detail: "File Recovery")
                
                // Update our stored progress info
                self.fileRecoveryProgress = newProgressInfo
                
                // Remove any existing file recovery progress bars
                self.activeProgressBars.removeAll(where: { $0.detail == "File Recovery" })
                
                // Add the new progress bar
                self.activeProgressBars.append(newProgressInfo)
                
                // Add a log message for significant progress
                if current % 10 == 0 || current == total {
                    self.addLogMessage("Recovered \(current) of \(total) files", type: .info)
                }
            }
            .store(in: &cancellables)
        
        nc.publisher(for: Notification.Name("iCloudFileRecoveryCompleted"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                guard let userInfo = notification.userInfo,
                      let count = userInfo["count"] as? Int else {
                    return
                }
                
                // Update state and remove progress bar
                self.fileRecoveryState = .complete
                self.removeProgress(id: "File Recovery")
                self.fileRecoveryProgress = nil
                
                // Add a completion log message
                self.addLogMessage("File recovery completed: \(count) files recovered", type: .success)
            }
            .store(in: &cancellables)
        
        nc.publisher(for: Notification.Name("iCloudFileRecoveryFailed"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                guard let userInfo = notification.userInfo,
                      let error = userInfo["error"] as? Error else {
                    return
                }
                
                // Update state and remove progress bar
                self.fileRecoveryState = .error
                self.removeProgress(id: "File Recovery")
                self.fileRecoveryProgress = nil
                
                // Add an error log message
                self.addLogMessage("File recovery failed: \(error.localizedDescription)", type: .error)
            }
            .store(in: &cancellables)
        
        // Temporary file cleanup notifications
        nc.publisher(for: Notification.Name("TemporaryFileCleanupStarted"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.addLogMessage("Temporary file cleanup started", type: .info)
            }
            .store(in: &cancellables)
        
        nc.publisher(for: Notification.Name("TemporaryFileCleanupCompleted"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                guard let userInfo = notification.userInfo,
                      let count = userInfo["count"] as? Int else {
                    return
                }
                
                // Add a completion log message
                self.addLogMessage("Temporary file cleanup completed: \(count) files removed", type: .success)
            }
            .store(in: &cancellables)
    }
    
    /// Set up subscription to the game importer's queue
    private func setupQueueSubscription(gameImporter: any GameImporting) {
        // Subscribe to the game importer's queue
        gameImporter.importQueuePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self = self else { return }
                self.importQueueItems = items
                
                // Show the view when there are items in the queue
                if !items.isEmpty {
                    self.shouldShow = true
                } else if self.activeProgressBars.isEmpty && !self.isSyncing {
                    self.scheduleHideAfterDelay()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Get the syncers from the store
    private func getSyncers() -> [any SyncProvider]? {
        // Get the actual syncer instances from the store
        return CloudKitSyncerStore.shared.activeSyncers
    }
}
