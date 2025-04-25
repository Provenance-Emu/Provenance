//
//  RetroStatusControlViewModel.swift
//  PVUIBase
//
//  Created by Joseph Mattiello on 4/24/25.
//

import Foundation
import PVLibrary // For Notification names, Defaults keys, enums
import PVWebServer // For PVWebServer status
import PVLogging // For Logging
import Combine // For @Published and Cancellables
import SwiftUI // For Color, etc.
#if canImport(PVSupport)
import PVSupport
#endif
import PVPrimitives // For Notification names

// MARK: - Helper Types (Moved from View)

/// Represents an alert message to be displayed
public struct AlertMessage: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let type: AlertType
    public var sound: ButtonSound? = .click // Default sound
    
    /// Defines the type of alert for styling and sound effects
    public enum AlertType: String, CaseIterable, Equatable {
        case info
        case warning
        case error
        case success
        
        var iconName: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return RetroTheme.retroBlue
            case .warning: return .orange
            case .error: return RetroTheme.retroPink
            case .success: return .green
            }
        }
    }
    
    // Equatable conformance
    public static func == (lhs: AlertMessage, rhs: AlertMessage) -> Bool { lhs.id == rhs.id }
}

/// Represents the state of the file recovery process
public enum FileRecoveryState: Equatable {
    case idle
    case inProgress
    case complete
    case error
}

// Detailed error/info structs
public struct FileErrorInfo: Identifiable, Hashable {
    public let id = UUID() // Make sure id is public for Identifiable
    let error: String
    let path: String
    let filename: String
    let timestamp: Date
    let errorType: String? // Specific type like 'timeout', 'access_denied' etc.
}

public struct PendingRecoveryInfo: Identifiable, Hashable {
    public let id = UUID() // Make sure id is public for Identifiable
    let filename: String
    let path: String
    let timestamp: Date
}

// MARK: - RetroStatusControlViewModel Definition

final class RetroStatusControlViewModel: ObservableObject {
    
    // MARK: - Published State
    
    // --- Alerts --- (Kept from previous refactor)
    @Published var currentAlert: AlertMessage? = nil { didSet { showAlert = currentAlert != nil } }
    @Published var showAlert: Bool = false
    
    // --- Basic Progress (Placeholders/Simplified) ---
    // File Import Progress (Example)
    @Published var fileImportProgress: ProgressInfo? = nil
    
    // --- Detailed File Recovery --- (Expanded)
    @Published var fileRecoveryState: FileRecoveryState = .idle
    @Published var fileRecoveryProgressInfo: ProgressInfo? = nil
    @Published var fileRecoverySessionId: String? = nil
    @Published var fileRecoveryStartTime: Date? = nil
    @Published var fileRecoveryBytesProcessed: UInt64 = 0
    @Published var fileRecoveryErrors: [FileErrorInfo] = [] // List of specific recovery errors
    @Published var fileRecoveryRetryQueueCount: Int = 0
    @Published var fileRecoveryRetryAttempt: Int = 0
    
    // --- Detailed Archive Extraction --- (Expanded)
    @Published var archiveExtractionInProgress: Bool = false
    @Published var archiveExtractionProgress: Double = 0.0 // Use Double (0.0 to 1.0)
    @Published var archiveExtractionFilename: String? = nil
    @Published var archiveExtractionStartTime: Date? = nil
    @Published var archiveExtractionExtractedCount: Int = 0
    @Published var archiveExtractionError: FileErrorInfo? = nil // Store last extraction error
    
    // --- File Access Errors --- (New)
    @Published var fileAccessErrors: [FileErrorInfo] = []
    @Published var lastFileAccessErrorTime: Date? = nil
    
    // --- Files Pending Recovery --- (New)
    @Published var pendingRecoveryFiles: [PendingRecoveryInfo] = []
    
    // --- Web Server State --- (Kept, potentially expand later if needed)
    @Published var isWebServerRunning: Bool = false // Covers basic running state
    @Published var webServerIPAddress: String? = nil
    @Published var webServerPort: Int? = nil
    @Published var webServerError: String? = nil // Simple string for now
    @Published var webServerUploadProgress: WebServerUploadInfo? = nil
    
    // --- iCloud Sync General State --- (New)
    @Published var isICloudSyncEnabled: Bool
    @Published var pendingRecoveryFileCount: Int? = nil
    
    // --- Other Progress Types --- (New)
    @Published var romScanningProgress: ProgressInfo? = nil
    @Published var temporaryFileCleanupProgress: ProgressInfo? = nil
    @Published var cacheManagementProgress: ProgressInfo? = nil
    @Published var downloadProgress: ProgressInfo? = nil
    @Published var cloudKitSyncProgress: ProgressInfo? = nil
    
    // --- Temporary Status Message --- (Ensure this exists)
    @Published var temporaryStatusMessage: String? = nil
    
    // --- Status Messages ---
    @Published var messages: [StatusMessage] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var statusMessageCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    public init() {
        ILOG("Initializing RetroStatusControlViewModel")
        self.isICloudSyncEnabled = Defaults[.iCloudSync]
        setupNotificationObservers()
        setupCloudKitSubscriptions() // Set up CloudKit sync subscriptions
        updateWebServerStatus() // Initial check
        // Observe messages from StatusMessageManager directly if needed
        // Or rely on notifications it posts?
        
        // Define handleLatestStatusMessage helper
        
        // Combine pipeline to observe messages from StatusMessageManager
        StatusMessageManager.shared.$messages
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main) // Debounce brief messages
            .sink { [weak self] messages in
                // Store the messages for display
                self?.messages = messages
                
                // Handle the latest non-progress message for alerts/temporary status
                if let latestMessage = messages.last(where: { $0.type != .progress }) {
                    self?.temporaryStatusMessage = latestMessage.message
                    
                    // Convert StatusMessage.MessageType to AlertMessage.AlertType for alerts
                    switch latestMessage.type {
                    case .error:
                        self?.currentAlert = AlertMessage(title: "Error", message: latestMessage.message, type: .error)
                    case .warning:
                        self?.currentAlert = AlertMessage(title: "Warning", message: latestMessage.message, type: .warning)
                    case .success, .info, .progress:
                        // Don't show alerts for these types
                        break
                    }
                }
            }
            .store(in: &cancellables)
        
        // Removed TODO as notifications seem to cover this.
    }
    
    deinit {
        ILOG("RetroStatusControlViewModel Deinitializing")
        // Cancellables are automatically released
    }
    
    // MARK: - Public Methods
    
    /// Triggers a manual iCloud sync operation
    public func triggerManualSync() {
        ILOG("Triggering manual iCloud sync from ViewModel...")
        ButtonSoundGenerator.shared.playSound(.tap)
        
        self.temporaryStatusMessage = "Starting manual iCloud sync..."
        
        // Trigger the sync operation
        Task {
            do {
                // Trigger CloudKit sync via CloudSyncManager
                try await CloudSyncManager.shared.startSync().value
                DLOG("Manual iCloud sync triggered successfully")
                
                // The actual progress and completion will be handled by notification observers
                // that we've already set up in setupNotificationObservers()
            } catch {
                ELOG("Error triggering manual iCloud sync: \(error.localizedDescription)")
                Task { @MainActor in
                    self.temporaryStatusMessage = "Error starting sync: \(error.localizedDescription)"
                    self.triggerAlert(title: "Sync Error", message: error.localizedDescription, type: AlertMessage.AlertType.error)
                }
            }
        }
    }
    
    // MARK: - CloudKit Sync Status
    
    /// Set up subscriptions to CloudKit sync status publishers
    private func setupCloudKitSubscriptions() {
        // Subscribe to sync status changes
        CloudSyncManager.shared.syncStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                
                Task { @MainActor in
                    switch status {
                    case .idle:
                        self.cloudKitSyncProgress = nil
                        self.temporaryStatusMessage = "iCloud sync idle"
                    case .syncing:
                        if self.cloudKitSyncProgress == nil {
                            self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Syncing with iCloud...")
                        }
                    case .initialSync:
                        self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Initial iCloud sync in progress...")
                        self.temporaryStatusMessage = "Starting initial iCloud sync"
                    case .uploading:
                        self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Uploading to iCloud...")
                        self.temporaryStatusMessage = "Uploading to iCloud"
                    case .downloading:
                        self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Downloading from iCloud...")
                        self.temporaryStatusMessage = "Downloading from iCloud"
                    case .error(let error):
                        self.cloudKitSyncProgress = nil
                        self.temporaryStatusMessage = "iCloud sync error: \(error.localizedDescription)"
                        self.triggerAlert(title: "iCloud Sync Error", message: error.localizedDescription, type: AlertMessage.AlertType.error)
                    case .disabled:
                        self.cloudKitSyncProgress = nil
                        self.isICloudSyncEnabled = false
                        self.temporaryStatusMessage = "iCloud sync disabled"
                    }
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to initial sync progress updates if available
        Task {
            do {
                for await progress in try await CloudKitInitialSyncer.shared.syncProgressPublisher.values {
                    await MainActor.run {
                        // Convert the initial sync progress to our ProgressInfo format
                        let total = progress.romsTotal + progress.saveStatesTotal + progress.biosTotal
                        let current = progress.romsCompleted + progress.saveStatesCompleted + progress.biosCompleted
                        
                        let detail = "Syncing ROMs: \(progress.romsCompleted)/\(progress.romsTotal), " +
                        "Saves: \(progress.saveStatesCompleted)/\(progress.saveStatesTotal), " +
                        "BIOS: \(progress.biosCompleted)/\(progress.biosTotal)"
                        
                        self.cloudKitSyncProgress = ProgressInfo(current: current, total: total, detail: detail)
                    }
                }
            } catch {
                ELOG("Error subscribing to initial sync progress: \(error.localizedDescription)")
            }
        }
    }
    
    public func toggleWebServer() {
        ILOG("Toggling web server from ViewModel...")
        ButtonSoundGenerator.shared.playSound(.tap)
        Task {
            let server = PVWebServer.shared
            if self.isWebServerRunning { // Use the @Published property
                server.stopServers()
            } else {
                do {
                    let started = try await server.startServers()
                    if !started {
                        ELOG("Failed to start web server from ViewModel")
                        // Update state to show error?
                        await MainActor.run {
                            self.webServerError = "Failed to start server."
                            self.isWebServerRunning = false
                        }
                    }
                } catch {
                    ELOG("Error starting web server: \(error)")
                    // Update state to show error
                    await MainActor.run { // Ensure UI updates on main thread
                        self.webServerError = error.localizedDescription
                        self.isWebServerRunning = false
                    }
                }
            }
            // Status updates are handled by the notification observer
        }
    }
    
    public func clearMessages() {
        ILOG("Clearing messages.")
        ButtonSoundGenerator.shared.playSound(.tap) // Was .back - .tap seems appropriate
        WLOG("StatusMessageManager does not have a `clearMessages` method. Cannot clear.")
        // Maybe clear local errors too?
        // fileAccessErrors = []
        // fileRecoveryErrors = []
        self.pendingRecoveryFiles = []
    }
    
    public func recoverFiles() {
        ILOG("Manual file recovery requested from ViewModel.")
        ButtonSoundGenerator.shared.playSound(.click2) // Use a valid sound like .click2
        Task {
            await iCloudSync.checkForStuckFilesInICloudDrive()
        }
        Task { @MainActor in
            self.temporaryStatusMessage = "Manual recovery started..."
            self.fileRecoveryState = .inProgress // Set state immediately
        }
    }
    
    public func dismissAlert() {
        // Dismiss the alert by setting it to nil
        self.currentAlert = nil
        self.showAlert = false
        ILOG("Alert dismissed by ViewModel")
    }
    
    // MARK: - Private Logic & Notification Handling
    
    private func setupNotificationObservers() {
        let nc = NotificationCenter.default
        
        // --- Web Server Status --- (Using PVWebServer's notification)
        nc.addObserver(self, selector: #selector(handleWebServerStatusChanged(_:)), name: .webServerStatusChanged, object: nil)
        
        // --- Web Server Upload Progress ---
        nc.addObserver(self, selector: #selector(handleWebServerUploadProgress), name: Notification.Name("PVWebServerUploadProgressNotification"), object: nil)
        
        // --- iCloud File Recovery Notifications --- (Keep existing)
        nc.addObserver(self, selector: #selector(handleFileRecoveryStarted(_:)), name: iCloudSync.iCloudFileRecoveryStarted, object: nil)
        nc.addObserver(self, selector: #selector(handleFileRecoveryProgress(_:)), name: iCloudSync.iCloudFileRecoveryProgress, object: nil)
        nc.addObserver(self, selector: #selector(handleFileRecoveryCompleted(_:)), name: iCloudSync.iCloudFileRecoveryCompleted, object: nil)
        nc.addObserver(self, selector: #selector(handleFileRecoveryError(_:)), name: iCloudSync.iCloudFileRecoveryError, object: nil)
        
        // --- File Pending Recovery --- (iCloudSync)
        nc.addObserver(self, selector: #selector(handleFilePendingRecovery), name: iCloudSync.iCloudFilePendingRecovery, object: nil)
        
        // --- Archive Extraction --- (PVSupport standard notifications)
        nc.addObserver(self, selector: #selector(handleArchiveExtractionStarted), name: .archiveExtractionStarted, object: nil)
        nc.addObserver(self, selector: #selector(handleArchiveExtractionProgress), name: .archiveExtractionProgress, object: nil)
        nc.addObserver(self, selector: #selector(handleArchiveExtractionCompleted), name: .archiveExtractionCompleted, object: nil)
        nc.addObserver(self, selector: #selector(handleArchiveExtractionFailed), name: .archiveExtractionFailed, object: nil)
        
        // --- File Access Error --- (PVSupport standard notification)
        nc.addObserver(self, selector: #selector(handleFileAccessError), name: .fileAccessError, object: nil)
        
        // --- Specific Progress Notifications --- (Use actual Names from PVPrimitives or elsewhere)
        // nc.addObserver(self, selector: #selector(handleFileImportProgress(_:)), name: .PVFileImporterProgress, object: nil) // NOTE: PVFileImporterProgress seems undefined
        nc.addObserver(self, selector: #selector(handleRomScanningStarted(_:)), name: .romScanningStarted, object: nil)
        nc.addObserver(self, selector: #selector(handleRomScanningProgress(_:)), name: .romScanningProgress, object: nil)
        nc.addObserver(self, selector: #selector(handleRomScanningFinished(_:)), name: .romScanningCompleted, object: nil)
        nc.addObserver(self, selector: #selector(handleTempCleanupProgress(_:)), name: .temporaryFileCleanupProgress, object: nil)
        nc.addObserver(self, selector: #selector(handleCacheMgmtProgress(_:)), name: .cacheManagementProgress, object: nil)
        nc.addObserver(self, selector: #selector(handleDownloadProgress(_:)), name: .downloadProgress, object: nil)
        // CloudKit sync notifications
        nc.addObserver(self, selector: #selector(handleCloudKitInitialSyncStarted(_:)), name: .cloudKitInitialSyncStarted, object: nil)
        nc.addObserver(self, selector: #selector(handleCloudKitInitialSyncCompleted(_:)), name: .cloudKitInitialSyncCompleted, object: nil)
        nc.addObserver(self, selector: #selector(handleCloudKitInitialSyncProgress(_:)), name: .cloudKitInitialSyncProgress, object: nil)
        nc.addObserver(self, selector: #selector(handleCloudKitZoneChangesStarted(_:)), name: .cloudKitZoneChangesStarted, object: nil)
        nc.addObserver(self, selector: #selector(handleCloudKitZoneChangesCompleted(_:)), name: .cloudKitZoneChangesCompleted, object: nil)
        nc.addObserver(self, selector: #selector(handleCloudKitRecordTransferStarted(_:)), name: .cloudKitRecordTransferStarted, object: nil)
        nc.addObserver(self, selector: #selector(handleCloudKitRecordTransferCompleted(_:)), name: .cloudKitRecordTransferCompleted, object: nil)
        nc.addObserver(self, selector: #selector(handleCloudKitRecordTransferProgress(_:)), name: .cloudKitRecordTransferProgress, object: nil)
        nc.addObserver(self, selector: #selector(handleCloudKitConflictsDetected(_:)), name: .cloudKitConflictsDetected, object: nil)
        nc.addObserver(self, selector: #selector(handleCloudKitConflictsResolved(_:)), name: .cloudKitConflictsResolved, object: nil)
        currentAlert = nil
        ILOG("Notification observers set up in ViewModel")
    }
    
    private func handleLatestStatusMessage(_ message: StatusMessage?) {
        guard let message = message else {
            currentAlert = nil
            return
        }

        // Convert StatusMessage.MessageType to AlertMessage.AlertType
        let alertType: AlertMessage.AlertType?
        switch message.type { // Use the correct property 'type'
        case .error: alertType = .error
        case .warning: alertType = .warning
        case .success: alertType = .success
        case .info: alertType = .info
        case .progress: alertType = nil // Progress messages shouldn't be alerts
        }

        // Only create an alert if the type maps to one
        if let validAlertType = alertType {
            // StatusMessage doesn't have a title, use a generic one or the type itself
            let title = String(describing: message.type).capitalized
            currentAlert = AlertMessage(title: title, message: message.message, type: validAlertType)
            // triggerAlertSound(type: alertType) // Sound function needs verification/reinstatement
        } else {
            // Don't show an alert for progress messages, etc.
            // Optionally clear the alert if the latest message isn't alert-worthy
            currentAlert = nil
        }
    }
    
    // MARK: - Alert Handling
    
    /// Triggers an alert with the specified title, message, and type
    /// - Parameters:
    ///   - title: The title of the alert
    ///   - message: The message body of the alert
    ///   - type: The type of alert (.info, .success, .warning, .error, .progress)
    private func triggerAlert(title: String, message: String, type: AlertMessage.AlertType) {
        Task { @MainActor in
            self.currentAlert = AlertMessage(title: title, message: message, type: type)
            // Could add sound here if needed
            // ButtonSoundGenerator.shared.playSound(.alert)
        }
    }
    
    // MARK: - File Recovery Handlers
    @objc private func handleFileRecoveryStarted() {
        VLOG("ViewModel: iCloud File Recovery Started")
        self.fileRecoveryState = .inProgress
        self.fileRecoveryProgressInfo = nil // Reset progress at start
    }
    
    @objc private func handleFileRecoveryProgress(notification: Notification) {
        VLOG("ViewModel: iCloud File Recovery Progress Received")
        guard let userInfo = notification.userInfo,
              let currentNum = userInfo["current"] as? NSNumber,
              let totalNum = userInfo["total"] as? NSNumber,
              let message = userInfo["message"] as? String else
        {
            WLOG("""
                 Could not parse iCloud file recovery progress userInfo.
                 Received: \(notification.userInfo ?? [:])
                 """)
            return
        }
        
        let current = currentNum.intValue
        let total = totalNum.intValue
        
        Task { @MainActor in
            self.fileRecoveryProgressInfo = ProgressInfo(current: current, total: total, detail: message)
            // Ensure the overall state reflects progress
            if self.fileRecoveryState != .inProgress { // Check against the main state enum
                self.fileRecoveryState = .inProgress
            }
            // Log the message for debugging
            DLOG("iCloud Recovery Progress: \(current)/\(total) - \(message)")
        }
    }
    
    @objc private func handleFileRecoveryCompleted() {
        VLOG("ViewModel: iCloud File Recovery Completed")
        Task { @MainActor in
            self.fileRecoveryState = .complete // Set main state to complete
            // Optionally update message in progress info
            if var progressInfo = self.fileRecoveryProgressInfo {
                progressInfo.detail = "Recovery complete."
                self.fileRecoveryProgressInfo = progressInfo
            } else {
                self.fileRecoveryProgressInfo = ProgressInfo(current: 0, total: 0, detail: "Recovery complete.") // Provide default completion info
            }
        }
    }
    
    @objc private func handleFileRecoveryError(notification: Notification) {
        VLOG("ViewModel: iCloud File Recovery Error")
        // Extract error message if available
        let errorMessage = (notification.userInfo?["error"] as? Error)?.localizedDescription ?? "An unknown error occurred."
        let fileName = notification.userInfo?["fileName"] as? String ?? "unknown file"
        
        Task { @MainActor in
            self.fileRecoveryState = .error // Set main state to error
            // Update progress info with error message
            if var progressInfo = self.fileRecoveryProgressInfo {
                progressInfo.detail = "Error recovering \(fileName): \(errorMessage)"
                self.fileRecoveryProgressInfo = progressInfo
            } else {
                self.fileRecoveryProgressInfo = ProgressInfo(current: 0, total: 0, detail: "Error recovering \(fileName): \(errorMessage)")
            }
            // Log the error
            ELOG("iCloud Recovery Error: \(errorMessage) for file \(fileName)")
        }
    }
    
    // MARK: - ROM Scanning Handlers (Now Functional)
    @objc private func handleRomScanningStarted(_ notification: Notification) {
        VLOG("ViewModel: ROM Scan Started")
        // Extract total count if available in start notification? (Optional)
        let total = (notification.userInfo?["total"] as? NSNumber)?.intValue ?? 1 // Default to 1 for indeterminate
        Task { @MainActor in
            self.romScanningProgress = ProgressInfo(current: 0, total: total, detail: nil) // Provide nil for detail
            self.temporaryStatusMessage = "ROM scan started..."
        }
    }
    
    @objc private func handleRomScanningProgress(_ notification: Notification) {
        VLOG("ViewModel: ROM Scan Progress Received")
        if let progress = parseProgressInfo(from: notification) { // Use helper
            Task { @MainActor in
                self.romScanningProgress = progress // Assign ProgressInfo
                DLOG("ROM Scan Progress: \(progress.current)/\(progress.total)")
            }
        } else {
            WLOG("Could not parse ROM scanning progress userInfo")
        }
    }
    
    @objc private func handleRomScanningFinished(_ notification: Notification) {
        VLOG("ViewModel: ROM Scan Finished")
        Task { @MainActor in
            self.romScanningProgress = nil // Clear progress
            self.temporaryStatusMessage = "ROM scan finished."
            // Extract results if needed (e.g., count of new ROMs)
            let newROMs = (notification.userInfo?["newROMs"] as? Int) ?? 0
            self.triggerAlert(title: "Scan Complete", message: "Found \(newROMs) new ROMs.", type: .success)
        }
    }
    
    // MARK: - Other Progress Handlers (Placeholders)
    @objc private func handleArchiveExtractionProgress(_ notification: Notification) {
        VLOG("ViewModel: Archive Extraction Progress")
        guard let userInfo = notification.userInfo,
              let progressVal: Double = userInfo["progress"] as? Double else {
            WLOG("Could not parse archive extraction progress userInfo")
            return
        }
        Task { @MainActor in
            // Ensure progress is clamped between 0.0 and 1.0
            self.archiveExtractionProgress = max(0.0, min(1.0, progressVal))
            // Update temporary message with percentage?
            let percent = Int(progressVal * 100)
            if let filename = self.archiveExtractionFilename {
                self.temporaryStatusMessage = "Extracting \(filename) (\(percent)%)" // Use self.
            }
        }
    }
    
    @objc private func handleFileImportProgress(_ notification: Notification) {
        DLOG("Received file import progress")
        if let progress: ProgressInfo = parseProgressInfo(from: notification) {
            Task { @MainActor in self.fileImportProgress = progress } // Assign ProgressInfo
        } else {
            WLOG("Could not parse file import progress userInfo")
        }
    }
    
    @objc private func handleTempCleanupProgress(_ notification: Notification) {
        DLOG("Received temp cleanup progress")
        if let progress: ProgressInfo = parseProgressInfo(from: notification) {
            Task { @MainActor in self.temporaryFileCleanupProgress = progress } // Assign ProgressInfo
        } else {
            WLOG("Could not parse temp cleanup progress userInfo")
        }
    }
    
    @objc private func handleCacheMgmtProgress(_ notification: Notification) {
        DLOG("Received cache mgmt progress")
        if let progress: ProgressInfo = parseProgressInfo(from: notification) {
            Task { @MainActor in self.cacheManagementProgress = progress } // Assign ProgressInfo
        } else {
            WLOG("Could not parse cache mgmt progress userInfo")
        }
    }
    
    @objc private func handleDownloadProgress(_ notification: Notification) {
        DLOG("Received download progress")
        if let progress: ProgressInfo = parseProgressInfo(from: notification) {
            Task { @MainActor in self.downloadProgress = progress } // Assign ProgressInfo
        }
    }
    
    // MARK: - CloudKit Sync Handlers
    
    @objc private func handleCloudKitInitialSyncStarted(_ notification: Notification) {
        VLOG("CloudKit initial sync started")
        Task { @MainActor in
            self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Starting initial CloudKit sync...")
            self.temporaryStatusMessage = "Starting CloudKit sync..."
        }
    }
    
    @objc private func handleCloudKitInitialSyncCompleted(_ notification: Notification) {
        VLOG("CloudKit initial sync completed")
        Task { @MainActor in
            self.cloudKitSyncProgress = nil
            self.temporaryStatusMessage = "Initial CloudKit sync completed"
        }
    }
    
    @objc private func handleCloudKitInitialSyncProgress(_ notification: Notification) {
        DLOG("Received CloudKit initial sync progress")
        if let progress = parseProgressInfo(from: notification) {
            Task { @MainActor in
                self.cloudKitSyncProgress = progress
                if let detail = progress.detail {
                    DLOG("CloudKit initial sync: \(progress.current)/\(progress.total) - \(detail)")
                }
            }
        } else {
            WLOG("Could not parse CloudKit initial sync progress userInfo")
        }
    }
    
    @objc private func handleCloudKitZoneChangesStarted(_ notification: Notification) {
        VLOG("CloudKit zone changes started")
        Task { @MainActor in
            self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Checking for CloudKit zone changes...")
        }
    }
    
    @objc private func handleCloudKitZoneChangesCompleted(_ notification: Notification) {
        VLOG("CloudKit zone changes completed")
        Task { @MainActor in
            self.cloudKitSyncProgress = nil
        }
    }
    
    @objc private func handleCloudKitRecordTransferStarted(_ notification: Notification) {
        VLOG("CloudKit record transfer started")
        Task { @MainActor in
            self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Starting CloudKit record transfer...")
        }
    }
    
    @objc private func handleCloudKitRecordTransferCompleted(_ notification: Notification) {
        VLOG("CloudKit record transfer completed")
        Task { @MainActor in
            self.cloudKitSyncProgress = nil
            self.temporaryStatusMessage = "CloudKit sync completed"
        }
    }
    
    @objc private func handleCloudKitRecordTransferProgress(_ notification: Notification) {
        DLOG("Received CloudKit record transfer progress")
        if let progress = parseProgressInfo(from: notification) {
            Task { @MainActor in
                self.cloudKitSyncProgress = progress
                if let detail = progress.detail {
                    DLOG("CloudKit record transfer: \(progress.current)/\(progress.total) - \(detail)")
                }
            }
        } else {
            WLOG("Could not parse CloudKit record transfer progress userInfo")
        }
    }
    
    @objc private func handleCloudKitConflictsDetected(_ notification: Notification) {
        WLOG("CloudKit conflicts detected")
        Task { @MainActor in
            let count = (notification.userInfo?["count"] as? NSNumber)?.intValue ?? 0
            self.temporaryStatusMessage = "CloudKit conflicts detected (\(count))"
            self.triggerAlert(title: "CloudKit Conflicts", message: "\(count) conflicts detected during sync. These will be resolved automatically.", type: AlertMessage.AlertType.warning)
        }
    }
    
    @objc private func handleCloudKitConflictsResolved(_ notification: Notification) {
        VLOG("CloudKit conflicts resolved")
        Task { @MainActor in
            let count = (notification.userInfo?["count"] as? NSNumber)?.intValue ?? 0
            self.temporaryStatusMessage = "CloudKit conflicts resolved (\(count))"
        }
    }
    
    // MARK: - iCloud Sync General Handlers (Existing)
    @objc private func handleICloudSyncDisabled(_ notification: Notification) {
        VLOG("ViewModel: iCloud Sync Disabled")
        Task { @MainActor [weak self] in
            self?.isICloudSyncEnabled = false
            // Maybe post an alert or message?
            // self.triggerAlert(title: "iCloud Sync Disabled", message: "iCloud syncing has been turned off.", type: .warning)
        }
    }
    
    @objc private func handleICloudSyncCompleted(_ notification: Notification) {
        VLOG("ViewModel: iCloud Sync Completed")
        Task { @MainActor [weak self] in
            self?.isICloudSyncEnabled = true // Sync might complete even if disabled later, ensure state reflects reality
            // Optionally show a temporary success message?
            if self?.fileRecoveryState != .inProgress { // Avoid overlapping messages
                self?.temporaryStatusMessage = "iCloud sync completed."
            }
        }
    }
    
    @objc private func handleICloudFilePendingRecovery(_ notification: Notification) {
        VLOG("ViewModel: iCloud Files Pending Recovery Update")
        guard let userInfo = notification.userInfo,
              let countNum = userInfo["count"] as? NSNumber else
        {
            WLOG("Could not parse pending file recovery count. UserInfo: \(notification.userInfo ?? [:])")
            Task { @MainActor in self.pendingRecoveryFileCount = nil } // Clear if invalid
            return
        }
        let count = countNum.intValue
        Task { @MainActor in
            self.pendingRecoveryFileCount = count > 0 ? count : nil // Set to nil if count is 0
            DLOG("Pending iCloud recovery files: \(count)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Updates the view model's web server state properties from the PVWebServer shared instance.
    private func updateWebServerStatus() {
        let webServer = PVWebServer.shared
        self.isWebServerRunning = webServer.isWWWUploadServerRunning
        self.webServerIPAddress = webServer.ipAddress                  // Use self.
        self.webServerPort = webServer.bonjourSeverURL?.port           // Use self.
        self.webServerError = nil // Reset error on status change? How to get errors? - Use self.
        VLOG("ViewModel: Web server running status updated: \(self.isWebServerRunning)")
    }
    
    /// Helper to parse common file error info
    private func parseFileErrorInfo(from notification: Notification, defaultErrorType: String? = nil) -> FileErrorInfo? {
        guard let path: String = extract(from: notification, key: "path") else { return nil }
        
        let error: Error? = extract(from: notification, key: "error")
        let errorDescription: String? = error?.localizedDescription
        let errorString: String? = extract(from: notification, key: "error")
        let errorDesc: String = errorDescription ?? errorString ?? "Unknown Error"
        let filename: String = extract(from: notification, key: "filename") ?? URL(fileURLWithPath: path).lastPathComponent
        let timestamp: Date = extract(from: notification, key: "timestamp") ?? Date()
        let errorType: String? = extract(from: notification, key: "errorType") ?? defaultErrorType
        return FileErrorInfo(error: errorDesc, path: path, filename: filename, timestamp: timestamp, errorType: errorType)
    }
    
    // MARK: - Notification Handlers
    
    // --- Web Server Handlers ---
    @objc private func handleWebServerStatusChanged(_ notification: Notification) { // Add @objc
        DLOG("Received web server status change notification")
        Task { @MainActor in
            updateWebServerStatus()
        }
    }
    
    // --- Web Server Upload Progress Handler ---
    @objc private func handleWebServerUploadProgress(_ notification: Notification) { // Add @objc
        DLOG("Received web server upload progress notification")
        
        // Extract values using the keys from PVWebServer.m
        guard let userInfo = notification.userInfo,
              let progressVal: Double = userInfo["progress"] as? Double,
              let totalBytes: Int = userInfo["totalBytes"] as? Int,
              let transferredBytes: Int = userInfo["transferredBytes"] as? Int else {
            WLOG("Could not parse web server upload progress userInfo")
            return
        }
        
        // Extract additional info or provide defaults
        let currentFile = userInfo["currentFile"] as? String ?? "Unknown file"
        let queueLength = userInfo["queueLength"] as? Int ?? 0
        let bytesTransferred = transferredBytes // Use the same value if not separately provided
        
        Task { @MainActor in
            self.webServerUploadProgress = WebServerUploadInfo(
                progress: progressVal,
                totalBytes: totalBytes,
                transferredBytes: transferredBytes,
                currentFile: currentFile,
                queueLength: queueLength,
                bytesTransferred: bytesTransferred
            )
        }
    }
    
    // --- iCloud File Recovery Handlers --- (Add @objc)
    @objc private func handleFileRecoveryStarted(_ notification: Notification) {
        VLOG("ViewModel: iCloud File Recovery Started")
        Task { @MainActor in
            self.fileRecoverySessionId = extract(from: notification, key: "sessionId")
            self.fileRecoveryStartTime = extract(from: notification, key: "startTime") ?? Date()
            self.fileRecoveryBytesProcessed = 0
            self.fileRecoveryErrors = []
            self.fileRecoveryRetryQueueCount = 0
            self.fileRecoveryRetryAttempt = 0
        }
    }
    
    @objc private func handleFileRecoveryProgress(_ notification: Notification) {
        DLOG("Received file recovery progress")
        Task { @MainActor in
            // Update basic progress current/total if available
            if let progressInfo = parseProgressInfo(from: notification) {
                self.fileRecoveryProgressInfo = progressInfo
            }
            // Update bytes processed if available
            if let bytesProcessed: UInt64 = extract(from: notification, key: "bytesProcessed") {
                self.fileRecoveryBytesProcessed = bytesProcessed
            }
        }
    }
    
    @objc private func handleFileRecoveryCompleted(_ notification: Notification) {
        ILOG("File Recovery Completed")
        Task { @MainActor in
            let hadErrors = !self.fileRecoveryErrors.isEmpty
            self.fileRecoveryState = hadErrors ? .error : .complete
            self.fileRecoveryProgressInfo = nil
            self.fileRecoverySessionId = nil
            self.fileRecoveryStartTime = nil
            self.fileRecoveryBytesProcessed = 0
            self.fileRecoveryRetryQueueCount = 0
            self.fileRecoveryRetryAttempt = 0
        }
    }
    
    @objc private func handleFileRecoveryError(_ notification: Notification) {
        ILOG("File Recovery Error")
        guard let errorInfo = parseFileErrorInfo(from: notification, defaultErrorType: "recovery_error") else {
            WLOG("Could not parse file recovery error userInfo")
            return
        }
        Task { @MainActor in
            self.fileRecoveryErrors.append(errorInfo)
        }
    }
    
    // --- File Pending Recovery Handler --- (Add @objc)
    @objc private func handleFilePendingRecovery(_ notification: Notification) {
        DLOG("Received pending file recovery notification")
        guard let path: String = extract(from: notification, key: "path"),
              let filename: String = extract(from: notification, key: "filename") else {
            WLOG("Could not parse pending file recovery userInfo")
            return
        }
        let timestamp: Date = extract(from: notification, key: "timestamp") ?? Date()
        Task { @MainActor in
            self.pendingRecoveryFiles.append(PendingRecoveryInfo(filename: filename, path: path, timestamp: timestamp))
        }
    }
    
    // --- Archive Extraction Handlers --- (Add @objc)
    @objc private func handleArchiveExtractionStarted(_ notification: Notification) {
        VLOG("ViewModel: Archive Extraction Started")
        guard let filename: String = extract(from: notification, key: "filename") else {
            WLOG("Could not parse archive extraction started userInfo")
            return
        }
        Task { @MainActor in
            self.archiveExtractionInProgress = true
            self.archiveExtractionFilename = filename
            self.archiveExtractionStartTime = Date()
            self.archiveExtractionExtractedCount = 0
            self.archiveExtractionError = nil
        }
    }
    
    @objc private func handleArchiveExtractionCompleted(_ notification: Notification) {
        VLOG("ViewModel: Archive Extraction Completed")
        let count: Int = extract(from: notification, key: "count") ?? self.archiveExtractionExtractedCount // Keep old count if not provided
        Task { @MainActor in
            self.archiveExtractionInProgress = false
            self.archiveExtractionExtractedCount = count
            self.archiveExtractionError = nil
        }
    }
    
    @objc private func handleArchiveExtractionFailed(_ notification: Notification) {
        VLOG("ViewModel: Archive Extraction Failed")
        guard let errorInfo = parseFileErrorInfo(from: notification, defaultErrorType: "extraction_failed") else {
            WLOG("Could not parse archive extraction failed userInfo")
            return
        }
        Task { @MainActor in
            self.archiveExtractionInProgress = false
            self.archiveExtractionError = errorInfo
        }
    }
    
    // --- File Access Error Handler --- (Add @objc)
    @objc private func handleFileAccessError(_ notification: Notification) {
        VLOG("ViewModel: File Access Error")
        guard let errorInfo = parseFileErrorInfo(from: notification, defaultErrorType: "access_error") else {
            WLOG("Could not parse file access error userInfo")
            return
        }
        Task { @MainActor in
            self.fileAccessErrors.append(errorInfo)
            self.lastFileAccessErrorTime = errorInfo.timestamp
        }
    }
    
    // MARK: - Private Helpers
    
    /// Parses common progress info (current, total, message) from notification userInfo.
    private func parseProgressInfo(from notification: Notification) -> ProgressInfo? {
        guard let userInfo = notification.userInfo,
              let currentNum = userInfo["current"] as? NSNumber,
              let totalNum = userInfo["total"] as? NSNumber,
              let message = userInfo["message"] as? String else {
            return nil
        }
        let current = currentNum.intValue
        let total = totalNum.intValue
        return ProgressInfo(current: current, total: total, detail: message)
    }
    
    /// Generic helper to extract values from notification userInfo
    private func extract<T>(from notification: Notification, key: String) -> T? {
        return notification.userInfo?[key] as? T
    }
    
    // MARK: - Computed Property
    public var isWebServerActive: Bool {
        self.isWebServerRunning
    }
}

// MARK: - FileRecoveryState Extension (Example if needed)
extension FileRecoveryState {
    var isRecovering: Bool { self == .inProgress }
    var isFailed: Bool { self == .error }
    var isIdle: Bool { self == .idle }
}

// MARK: - Helper Structs for Parsing

public struct ProgressInfo: Identifiable, Equatable {
    public let id = UUID() // Make sure id is public for Identifiable
    let current: Int
    let total: Int
    var detail: String? // Changed to var
}

public struct WebServerUploadInfo: Identifiable, Equatable {
    public let id = UUID() // Make sure id is public for Identifiable
    let progress: Double
    let totalBytes: Int
    let transferredBytes: Int
    let currentFile: String
    let queueLength: Int
    let bytesTransferred: Int
}
