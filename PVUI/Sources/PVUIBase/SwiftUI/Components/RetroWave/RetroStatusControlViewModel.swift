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
import PVPrimitives // For Notification names and data models

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
                try await CloudSyncManager.shared.startSync()
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
        // Setup CloudKit subscriptions if needed
        DLOG("Setting up CloudKit subscriptions")
        
        // Subscribe directly to the @Published syncStatus property's projected value ($syncStatus)
        CloudSyncManager.shared.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                
                Task { @MainActor in
                    switch status {
                    case .initializing:
                        self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Initializing iCloud sync...")
                        self.temporaryStatusMessage = "Initializing iCloud sync"
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
                for await progress in await CloudKitInitialSyncer.shared.syncProgressPublisher.values {
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
                    let started = try server.startServers()
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
        #if !os(tvOS)
        Task {
            await iCloudDriveSync.checkForStuckFilesInICloudDrive()
        }
        #endif
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
        
        // Request for progress updates
        nc.addObserver(self, selector: #selector(handleRequestProgressUpdates), name: Notification.Name("RequestProgressUpdates"), object: nil)
        
        // --- Web Server Status --- (Using PVWebServer's notification)
        nc.addObserver(self, selector: #selector(handleWebServerStatusChanged(_:)), name: .webServerStatusChanged, object: nil)
        
        // --- Web Server Upload Progress ---
        nc.addObserver(self, selector: #selector(handleWebServerUploadProgress), name: Notification.Name("PVWebServerUploadProgressNotification"), object: nil)
        
        
        // --- Archive Extraction --- (PVSupport standard notifications)
        nc.addObserver(self, selector: #selector(handleArchiveExtractionStarted(_:)), name: .archiveExtractionStarted, object: nil)
        nc.addObserver(self, selector: #selector(handleArchiveExtractionProgress(_:)), name: .archiveExtractionProgress, object: nil)
        nc.addObserver(self, selector: #selector(handleArchiveExtractionCompleted(_:)), name: .archiveExtractionCompleted, object: nil)
        nc.addObserver(self, selector: #selector(handleArchiveExtractionFailed(_:)), name: .archiveExtractionFailed, object: nil)
        
        #if !os(tvOS)
        // --- File Pending Recovery --- (iCloudSync)
        nc.addObserver(self, selector: #selector(handleFilePendingRecovery(_:)), name: iCloudDriveSync.iCloudFilePendingRecovery, object: nil)

        // --- iCloud File Recovery Notifications ---
        nc.addObserver(self, selector: #selector(handleFileRecoveryStarted(_:)), name: iCloudDriveSync.iCloudFileRecoveryStarted, object: nil)
        nc.addObserver(self, selector: #selector(handleFileRecoveryProgress(_:)), name: iCloudDriveSync.iCloudFileRecoveryProgress, object: nil)
        nc.addObserver(self, selector: #selector(handleFileRecoveryCompleted(_:)), name: iCloudDriveSync.iCloudFileRecoveryCompleted, object: nil)
        nc.addObserver(self, selector: #selector(handleFileRecoveryError(_:)), name: iCloudDriveSync.iCloudFileRecoveryError, object: nil)
        #endif
    }
    
    /// Updates the view model's web server state properties from the PVWebServer shared instance.
    private func updateWebServerStatus() {
        let webServer = PVWebServer.shared
        self.isWebServerRunning = webServer.isWWWUploadServerRunning
        self.webServerIPAddress = webServer.ipAddress
        self.webServerPort = webServer.bonjourSeverURL?.port
        self.webServerError = nil // Reset error on status change
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
    
    /// Extract a value from a notification's userInfo
    private func extract<T>(from notification: Notification, key: String) -> T? {
        return notification.userInfo?[key] as? T
    }
    
    /// Helper to parse progress info from a notification
    private func parseProgressInfo(from notification: Notification) -> ProgressInfo? {
        guard let userInfo = notification.userInfo else { return nil }
        
        // Try to extract current and total values
        guard let currentNum = userInfo["current"] as? NSNumber,
              let totalNum = userInfo["total"] as? NSNumber else {
            return nil
        }
        
        let current = currentNum.intValue
        let total = totalNum.intValue
        let detail = userInfo["detail"] as? String
        let id = userInfo["id"] as? String ?? UUID().uuidString
        
        return ProgressInfo(id: id, current: current, total: total, detail: detail)
    }
    
    /// Triggers an alert with the specified title, message, and type
    private func triggerAlert(title: String, message: String, type: AlertMessage.AlertType) {
        Task { @MainActor in
            self.currentAlert = AlertMessage(title: title, message: message, type: type)
        }
    }
    
    // MARK: - Notification Handlers
    
    /// Handle requests for progress updates
    @objc private func handleRequestProgressUpdates() {
        DLOG("RetroStatusControlViewModel received request for progress updates")
        
        // Re-post all active progress information
        Task { @MainActor in
            // Check each progress type and post if active
            if let progress = fileImportProgress {
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "fileImport", current: progress.current, total: progress.total, detail: progress.detail))
            }
            
            if let progress = fileRecoveryProgressInfo {
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "fileRecovery", current: progress.current, total: progress.total, detail: progress.detail))
            }
            
            if let progress = romScanningProgress {
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "romScanning", current: progress.current, total: progress.total, detail: progress.detail))
            }
            
            if let progress = temporaryFileCleanupProgress {
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "tempCleanup", current: progress.current, total: progress.total, detail: progress.detail))
            }
            
            if let progress = cacheManagementProgress {
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "cacheMgmt", current: progress.current, total: progress.total, detail: progress.detail))
            }
            
            if let progress = downloadProgress {
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "download", current: progress.current, total: progress.total, detail: progress.detail))
            }
            
            if let progress = cloudKitSyncProgress {
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "cloudKitSync", current: progress.current, total: progress.total, detail: progress.detail))
            }
        }
    }
    
    // --- Web Server Handlers ---
    @objc private func handleWebServerStatusChanged(_ notification: Notification) {
        DLOG("Received web server status change notification")
        Task { @MainActor in
            updateWebServerStatus()
        }
    }
    
    // --- Web Server Upload Progress Handler ---
    @objc private func handleWebServerUploadProgress(_ notification: Notification) { // Add @objc
        DLOG("Received web server upload progress notification")
        
        // Extract progress information from the notification
        guard let userInfo = notification.userInfo,
              let filename = userInfo["filename"] as? String,
              let progressNumber = userInfo["progress"] as? NSNumber else {
            WLOG("Could not parse web server upload progress userInfo")
            return
        }
        
        let progress = progressNumber.doubleValue
        
        // Extract additional info or provide defaults
        let totalBytes = userInfo["totalBytes"] as? Int ?? 0
        let transferredBytes = userInfo["transferredBytes"] as? Int ?? 0
        let currentFile = userInfo["currentFile"] as? String ?? filename
        let queueLength = userInfo["queueLength"] as? Int ?? 0
        let bytesTransferred = userInfo["bytesTransferred"] as? Int ?? transferredBytes
        
        Task { @MainActor in
            // Update the web server upload progress with all required parameters
            self.webServerUploadProgress = WebServerUploadInfo(
                filename: filename,
                progress: progress,
                totalBytes: totalBytes,
                transferredBytes: transferredBytes,
                currentFile: currentFile,
                queueLength: queueLength,
                bytesTransferred: bytesTransferred
            )
            
            // Update temporary status message
            let percent = Int(progress * 100)
            self.temporaryStatusMessage = "Uploading \(filename) (\(percent)%)"
            
            // Post notification for the StatusControlButton
            NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "webServerUpload", current: percent, total: 100, detail: "Uploading \(filename)"))
        }
    }
    
    @objc private func handleFileRecoveryCompleted(_ notification: Notification) {
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
            
            // Delay dismissal of the status message
            delayStatusDismissal(statusId: "fileRecovery", message: "File recovery completed", delay: 5.0)
        }
    }
    
    // MARK: - Archive Extraction Handlers
    
    @objc private func handleArchiveExtractionStarted(_ notification: Notification) {
        VLOG("ViewModel: Archive Extraction Started")
        guard let userInfo = notification.userInfo,
              let filename = userInfo["filename"] as? String else {
            WLOG("Could not parse archive extraction started userInfo")
            return
        }
        
        Task { @MainActor in
            self.archiveExtractionInProgress = true
            self.archiveExtractionProgress = 0.0
            self.archiveExtractionFilename = filename
            self.archiveExtractionStartTime = Date()
            self.archiveExtractionExtractedCount = 0
            self.archiveExtractionError = nil
            self.temporaryStatusMessage = "Extracting \(filename)..."
        }
    }
    
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
                self.temporaryStatusMessage = "Extracting \(filename) (\(percent)%)"
                // Post notification for the StatusControlButton
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "archiveExtraction", current: Int(progressVal * 100), total: 100, detail: "Extracting \(filename) (\(percent)%)"))
            }
        }
    }
    
    @objc private func handleArchiveExtractionCompleted(_ notification: Notification) {
        VLOG("ViewModel: Archive Extraction Completed")
        guard let userInfo = notification.userInfo,
              let filename = userInfo["filename"] as? String,
              let extractedCountNum = userInfo["extractedCount"] as? NSNumber else {
            WLOG("Could not parse archive extraction completed userInfo")
            return
        }
        
        let extractedCount = extractedCountNum.intValue
        
        Task { @MainActor in
            self.archiveExtractionInProgress = false
            self.archiveExtractionProgress = 1.0
            self.archiveExtractionExtractedCount = extractedCount
            self.temporaryStatusMessage = "Extracted \(extractedCount) files from \(filename)"
            
            // Post notification for the StatusControlButton
            NotificationCenter.default.post(name: Notification.Name("ProgressRemoved"), object: "archiveExtraction")
        }
    }
    
    @objc private func handleArchiveExtractionFailed(_ notification: Notification) {
        VLOG("ViewModel: Archive Extraction Failed")
        let fileError = parseFileErrorInfo(from: notification, defaultErrorType: "archiveExtraction")
        
        Task { @MainActor in
            self.archiveExtractionInProgress = false
            self.archiveExtractionError = fileError
            self.temporaryStatusMessage = "Failed to extract \(fileError?.filename ?? "archive"): \(fileError?.error ?? "Unknown error")"
            
            // Post notification for the StatusControlButton
            NotificationCenter.default.post(name: Notification.Name("ProgressRemoved"), object: "archiveExtraction")
        }
    }
    
    // MARK: - File Access Error Handler
    
    @objc private func handleFileAccessError(_ notification: Notification) {
        WLOG("ViewModel: File Access Error")
        let fileError = parseFileErrorInfo(from: notification, defaultErrorType: "fileAccess")
        
        Task { @MainActor in
            if let error = fileError {
                // Add to the list of errors
                self.fileAccessErrors.append(error)
                self.lastFileAccessErrorTime = Date()
                
                // Limit the number of errors stored
                if self.fileAccessErrors.count > 10 {
                    self.fileAccessErrors.removeFirst()
                }
                
                // Show a temporary message
                self.temporaryStatusMessage = "File access error: \(error.filename)"
                
                // Trigger an alert
                self.triggerAlert(title: "File Access Error", message: "\(error.filename): \(error.error)", type: .error)
            }
        }
    }
    
    // MARK: - ROM Scanning Handlers
    
    @objc private func handleRomScanningStarted(_ notification: Notification) {
        VLOG("ViewModel: ROM Scan Started")
        // Extract total count if available in start notification? (Optional)
        let total = (notification.userInfo?["total"] as? NSNumber)?.intValue ?? 1 // Default to 1 for indeterminate
        Task { @MainActor in
            self.romScanningProgress = ProgressInfo(current: 0, total: total, detail: nil) // Provide nil for detail
            self.temporaryStatusMessage = "ROM scan started..."
            
            // Post notification for the StatusControlButton
            NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "romScanning", current: 0, total: total, detail: nil))
        }
    }
    
    @objc private func handleRomScanningProgress(_ notification: Notification) {
        VLOG("ViewModel: ROM Scan Progress Received")
        if let progress = parseProgressInfo(from: notification) { // Use helper
            Task { @MainActor in
                self.romScanningProgress = progress // Assign ProgressInfo
                DLOG("ROM Scan Progress: \(progress.current)/\(progress.total)")
                
                // Post notification for the StatusControlButton
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "romScanning", current: progress.current, total: progress.total, detail: progress.detail))
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
            
            // Post notification for the StatusControlButton
            NotificationCenter.default.post(name: Notification.Name("ProgressRemoved"), object: "romScanning")
        }
    }
    
    // MARK: - Other Progress Handlers
    
    @objc private func handleTempCleanupProgress(_ notification: Notification) {
        DLOG("Received temp cleanup progress")
        if let progress: ProgressInfo = parseProgressInfo(from: notification) {
            Task { @MainActor in
                self.temporaryFileCleanupProgress = progress
                
                // Update temporary status message with cleanup details
                if let detail = progress.detail {
                    self.temporaryStatusMessage = "Cleaning up: \(detail) (\(progress.current)/\(progress.total))"
                    DLOG("Temp cleanup progress: \(progress.current)/\(progress.total) - \(detail)")
                } else {
                    self.temporaryStatusMessage = "Cleaning up temporary files (\(progress.current)/\(progress.total))"
                }
                
                // Post notification for the StatusControlButton
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "tempCleanup", current: progress.current, total: progress.total, detail: progress.detail))
            }
        } else {
            WLOG("Could not parse temp cleanup progress userInfo")
        }
    }
    
    @objc private func handleCacheMgmtProgress(_ notification: Notification) {
        DLOG("Received cache mgmt progress")
        if let progress: ProgressInfo = parseProgressInfo(from: notification) {
            Task { @MainActor in
                self.cacheManagementProgress = progress
                
                // Update temporary status message with cache management details
                if let detail = progress.detail {
                    self.temporaryStatusMessage = "Managing cache: \(detail) (\(progress.current)/\(progress.total))"
                    DLOG("Cache management progress: \(progress.current)/\(progress.total) - \(detail)")
                } else {
                    self.temporaryStatusMessage = "Managing cache (\(progress.current)/\(progress.total))"
                }
                
                // Post notification for the StatusControlButton
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "cacheMgmt", current: progress.current, total: progress.total, detail: progress.detail))
            }
        } else {
            WLOG("Could not parse cache mgmt progress userInfo")
        }
    }
    
    @objc private func handleDownloadProgress(_ notification: Notification) {
        DLOG("Received download progress")
        if let progress: ProgressInfo = parseProgressInfo(from: notification) {
            Task { @MainActor in
                self.downloadProgress = progress
                
                // Update temporary status message with download details
                if let detail = progress.detail {
                    self.temporaryStatusMessage = "Downloading: \(detail) (\(progress.current)/\(progress.total))"
                    DLOG("Download progress: \(progress.current)/\(progress.total) - \(detail)")
                } else {
                    self.temporaryStatusMessage = "Downloading files (\(progress.current)/\(progress.total))"
                }
                
                // Post notification for the StatusControlButton
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "download", current: progress.current, total: progress.total, detail: progress.detail))
            }
        } else {
            WLOG("Could not parse download progress userInfo")
        }
    }
    
    // MARK: - CloudKit Sync Handlers
    
    @objc private func handleCloudKitInitialSyncStarted(_ notification: Notification) {
        VLOG("CloudKit initial sync started")
        Task { @MainActor in
            self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Starting initial CloudKit sync...")
            self.temporaryStatusMessage = "Starting CloudKit sync..."
            
            // Post notification for the StatusControlButton
            NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "cloudKitSync", current: 0, total: 1, detail: "Starting initial CloudKit sync..."))
        }
    }
    
    // Timer for delayed status dismissal
    private var statusDismissalTimer: Timer?
    
    /// Delay dismissal of a status message
    private func delayStatusDismissal(statusId: String, message: String, delay: TimeInterval = 3.0) {
        // Cancel any existing timer
        statusDismissalTimer?.invalidate()
        
        // Set the temporary status message
        self.temporaryStatusMessage = message
        
        // Create a new timer to dismiss the status after the delay
        statusDismissalTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Only clear if the message hasn't changed
                if self.temporaryStatusMessage == message {
                    self.temporaryStatusMessage = nil
                }
                
                // Post notification for the StatusControlButton
                NotificationCenter.default.post(name: Notification.Name("ProgressRemoved"), object: statusId)
            }
        }
    }
    
    @objc private func handleCloudKitInitialSyncCompleted(_ notification: Notification) {
        VLOG("CloudKit initial sync completed")
        Task { @MainActor in
            self.cloudKitSyncProgress = nil
            
            // Delay dismissal of the status message
            delayStatusDismissal(statusId: "cloudKitSync", message: "Initial CloudKit sync completed")
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
                
                // Post notification for the StatusControlButton
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "cloudKitSync", current: progress.current, total: progress.total, detail: progress.detail))
            }
        } else {
            WLOG("Could not parse CloudKit initial sync progress userInfo")
        }
    }
    
    @objc private func handleCloudKitZoneChangesStarted(_ notification: Notification) {
        VLOG("CloudKit zone changes started")
        Task { @MainActor in
            self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Checking for CloudKit zone changes...")
            
            // Post notification for the StatusControlButton
            NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "cloudKitSync", current: 0, total: 1, detail: "Checking for CloudKit zone changes..."))
        }
    }
    
    @objc private func handleCloudKitZoneChangesCompleted(_ notification: Notification) {
        VLOG("CloudKit zone changes completed")
        Task { @MainActor in
            self.cloudKitSyncProgress = nil
            
            // Delay dismissal of the status message
            delayStatusDismissal(statusId: "cloudKitSync", message: "CloudKit zone changes completed")
        }
    }
    
    @objc private func handleCloudKitRecordTransferStarted(_ notification: Notification) {
        VLOG("CloudKit record transfer started")
        Task { @MainActor in
            self.cloudKitSyncProgress = ProgressInfo(current: 0, total: 1, detail: "Starting CloudKit record transfer...")
            
            // Post notification for the StatusControlButton
            NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "cloudKitSync", current: 0, total: 1, detail: "Starting CloudKit record transfer..."))
        }
    }
    
    @objc private func handleCloudKitRecordTransferCompleted(_ notification: Notification) {
        Task { @MainActor in
            self.cloudKitSyncProgress = nil
            
            // Delay dismissal of the status message
            delayStatusDismissal(statusId: "cloudKitSync", message: "CloudKit sync completed", delay: 2.0) // Add a 2-second delay
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
                
                // Post notification for the StatusControlButton
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "cloudKitSync", current: progress.current, total: progress.total, detail: progress.detail))
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
            
            // Post notification for the StatusControlButton
            NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "fileRecovery", current: 0, total: 0, detail: "File Recovery Started"))
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
            
            // Post notification for the StatusControlButton
            if let progressInfo = self.fileRecoveryProgressInfo {
                NotificationCenter.default.post(name: Notification.Name("ProgressUpdate"), object: ProgressInfo(id: "fileRecovery", current: progressInfo.current, total: progressInfo.total, detail: progressInfo.detail))
            }
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
}
