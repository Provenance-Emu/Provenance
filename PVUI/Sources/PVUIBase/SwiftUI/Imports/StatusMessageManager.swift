//
//  StatusMessageManager.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import PVLibrary
import PVPrimitives

/// A message to be displayed in the status view
extension StatusMessageManager {
    public struct StatusMessage: Identifiable, Equatable {
        public let id = UUID()
        public let message: String
        public let type: MessageType
        public let timestamp = Date()
        public let duration: TimeInterval
        
        public enum MessageType {
            case info
            case success
            case warning
            case error
            case progress
            
            var color: Color {
                switch self {
                case .info: return .blue
                case .success: return .green
                case .warning: return .orange
                case .error: return .red
                case .progress: return .purple
                }
            }
        }
        
        public init(message: String, type: MessageType = .info, duration: TimeInterval = 5.0) {
            self.message = message
            self.type = type
            self.duration = duration
        }
        
        public static func == (lhs: StatusMessage, rhs: StatusMessage) -> Bool {
            lhs.id == rhs.id
        }
    }
}

/// Manages status messages for the app
public class StatusMessageManager: ObservableObject {
    public static let shared = StatusMessageManager()

    @Published public private(set) var messages: [StatusMessage] = []
    @Published public private(set) var fileRecoveryProgress: (current: Int, total: Int)? = nil
    @Published public private(set) var isImportActive: Bool = false

    // Additional progress tracking (forwarded from ViewModel)
    @Published public private(set) var romScanningProgress: (current: Int, total: Int)? = nil
    @Published public private(set) var temporaryFileCleanupProgress: (current: Int, total: Int)? = nil
    @Published public private(set) var cacheManagementProgress: (current: Int, total: Int)? = nil
    @Published public private(set) var downloadProgress: (current: Int, total: Int)? = nil
    @Published public private(set) var cloudKitSyncProgress: (current: Int, total: Int)? = nil

    private var cancellables = Set<AnyCancellable>()
    private var messageTimers: [UUID: Timer] = [:]

    /// ViewModel to handle actor isolation
    @MainActor
    public let viewModel = StatusMessageViewModel()

    private init() {
        setupNotificationObservers()

        Task { @MainActor [weak self] in
            // Set up bindings to the ViewModel
            self?.viewModel.$fileRecoveryProgress
                .receive(on: RunLoop.main)
                .assign(to: &$fileRecoveryProgress)

            self?.viewModel.$isImportActive
                .receive(on: RunLoop.main)
                .assign(to: &$isImportActive)

            // Bind additional progress tracking from ViewModel
            self?.viewModel.$romScanningProgress
                .receive(on: RunLoop.main)
                .assign(to: &$romScanningProgress)

            self?.viewModel.$temporaryFileCleanupProgress
                .receive(on: RunLoop.main)
                .assign(to: &$temporaryFileCleanupProgress)

            self?.viewModel.$cacheManagementProgress
                .receive(on: RunLoop.main)
                .assign(to: &$cacheManagementProgress)

            self?.viewModel.$downloadProgress
                .receive(on: RunLoop.main)
                .assign(to: &$downloadProgress)

            self?.viewModel.$cloudKitSyncProgress
                .receive(on: RunLoop.main)
                .assign(to: &$cloudKitSyncProgress)
        }
    }

    private func setupNotificationObservers() {
        // Clear existing observers to prevent duplicates if called multiple times
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // MARK: - File System Operations
        NotificationCenter.default.publisher(for: .diskSpaceWarning)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let message = notification.userInfo?["message"] as? String ?? "Disk space is running low."
                self?.addMessage(StatusMessage(message: message, type: .warning, duration: 10.0))
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .temporaryFileCleanupStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.addMessage(StatusMessage(message: "Starting temporary file cleanup...", type: .info)) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .temporaryFileCleanupCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.addMessage(StatusMessage(message: "Temporary file cleanup completed.", type: .success)) }
            .store(in: &cancellables)

        // MARK: - Network Operations
        NotificationCenter.default.publisher(for: .networkConnectivityChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo, let isConnected = userInfo["isConnected"] as? Bool {
                    let msg = isConnected ? "Network connection restored." : "Network connection lost."
                    let type: StatusMessage.MessageType = isConnected ? .success : .warning
                    self?.addMessage(StatusMessage(message: msg, type: type, duration: 5.0))
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .webServerStatusChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo, 
                   let isRunning = userInfo["isRunning"] as? Bool, 
                   let type = userInfo["type"] as? String, 
                   let urlString = userInfo["url"] as? String {
                    let status = isRunning ? "started" : "stopped"
                    let message = "Web server (\(type)) \(status) at \(urlString)"
                    self?.addMessage(StatusMessage(message: message, type: isRunning ? .success : .info, duration: 7.0))
                } else if let userInfo = notification.userInfo, let isRunning = userInfo["isRunning"] as? Bool, let type = userInfo["type"] as? String {
                     let status = isRunning ? "started" : "stopped"
                     let message = "Web server (\(type)) \(status)."
                     self?.addMessage(StatusMessage(message: message, type: isRunning ? .success : .info, duration: 7.0))
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .webServerUploadProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let currentFile = userInfo["currentFile"] as? String,
                   let bytesTransferred = userInfo["bytesTransferred"] as? Int64,
                   let totalBytes = userInfo["totalBytes"] as? Int64,
                   let progress = userInfo["progress"] as? Double,
                   let queueLength = userInfo["queueLength"] as? Int {
                    let fileName = URL(fileURLWithPath: currentFile).lastPathComponent
                    let progressPercent = Int(progress * 100)
                    let mbTransferred = String(format: "%.1f", Double(bytesTransferred) / (1024 * 1024))
                    let mbTotal = String(format: "%.1f", Double(totalBytes) / (1024 * 1024))
                    
                    var message = "Uploading \(fileName): \(progressPercent)% ([\(mbTransferred)/\(mbTotal) MB])"
                    if queueLength > 0 {
                        message += " - \(queueLength) in queue"
                    }
                    self?.addMessage(StatusMessage(message: message, type: .progress, duration: 3.0))
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .webServerUploadCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let fileName = userInfo["fileName"] as? String {
                    let displayName = URL(fileURLWithPath: fileName).lastPathComponent
                    var message = "Upload complete: \(displayName)"
                    if let fileSize = userInfo["fileSize"] as? Int64 {
                        let mbSize = String(format: "%.1f", Double(fileSize) / (1024 * 1024))
                        message += " (\(mbSize) MB)"
                    }
                    self?.addMessage(StatusMessage(message: message, type: .success, duration: 7.0))
                }
            }
            .store(in: &cancellables)

        // MARK: - Game Importer Notifications
        NotificationCenter.default.publisher(for: .GameImporterDidStart)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleGameImporterDidStart()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .PVGameImported) // Changed from .gameImportFileImported
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleGameImportFileImported(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .GameImporterFileDidFail)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleGameImporterFileDidFail(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .GameImporterDidFinish)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleGameImporterDidFinish()
            }
            .store(in: &cancellables)

        // MARK: - Controller Management
        NotificationCenter.default.publisher(for: .controllerConnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let name = notification.userInfo?["name"] as? String ?? "Controller"
                self?.addMessage(StatusMessage(message: "\(name) connected.", type: .success, duration: 4.0))
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .controllerDisconnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let name = notification.userInfo?["name"] as? String ?? "Controller"
                self?.addMessage(StatusMessage(message: "\(name) disconnected.", type: .warning, duration: 4.0))
            }
            .store(in: &cancellables)

        // MARK: - ROM Scanning
        NotificationCenter.default.publisher(for: .romScanningStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.addMessage(StatusMessage(message: "Starting ROM scan...", type: .info)) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .romScanningCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let count = notification.userInfo?["count"] as? Int
                let message = count != nil ? "ROM scan completed. Found \(count!) new items." : "ROM scan completed."
                self?.addMessage(StatusMessage(message: message, type: .success))
            }
            .store(in: &cancellables)

        // MARK: - CloudKit Sync Operations (Ensure these are robust and cover existing logic if any)
        NotificationCenter.default.publisher(for: .cloudKitInitialSyncStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.addMessage(StatusMessage(message: "Starting initial CloudKit sync...", type: .info, duration: 5.0)) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitInitialSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let success = notification.userInfo?["success"] as? Bool ?? true // Assume success if not specified
                let message = success ? "Initial CloudKit sync completed successfully." : "Initial CloudKit sync finished with issues."
                self?.addMessage(StatusMessage(message: message, type: success ? .success : .warning, duration: 7.0))
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitRecordTransferProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let recordType = userInfo["recordType"] as? String,
                   let isUpload = userInfo["isUpload"] as? Bool,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int {
                    let direction = isUpload ? "Uploading" : "Downloading"
                    let message = "\(direction) \(recordType) to/from iCloud... (\(current)/\(total))"
                    // This message might be too frequent. Consider if a dedicated progress bar is better handled by StatusMessageViewModel directly.
                    // For now, keeping it simple. A more sophisticated approach might use the message ID to update, not just add.
                    self?.addMessage(StatusMessage(message: message, type: .info, duration: 3.0))
                } else if let userInfo = notification.userInfo, // Simpler version if no progress numbers
                          let recordType = userInfo["recordType"] as? String,
                          let isUpload = userInfo["isUpload"] as? Bool {
                    let direction = isUpload ? "Uploading" : "Downloading"
                    self?.addMessage(StatusMessage(message: "\(direction) \(recordType) to/from iCloud...", type: .info, duration: 3.0))
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitRecordTransferCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let recordType = userInfo["recordType"] as? String,
                   let count = userInfo["count"] as? Int,
                   let isUpload = userInfo["isUpload"] as? Bool {
                    let direction = isUpload ? "Uploaded" : "Downloaded"
                    let plural = count == 1 ? "" : "s"
                    self?.addMessage(StatusMessage(message: "\(direction) \(count) \(recordType)\(plural) \(isUpload ? "to" : "from") iCloud.", type: .success, duration: 5.0))
                } else if let userInfo = notification.userInfo, // Simpler version
                          let recordType = userInfo["recordType"] as? String,
                          let isUpload = userInfo["isUpload"] as? Bool {
                    let direction = isUpload ? "Uploaded" : "Downloaded"
                    self?.addMessage(StatusMessage(message: "\(direction) \(recordType)\(isUpload ? " to" : " from") iCloud.", type: .success, duration: 5.0))
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitConflictsDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let count = notification.userInfo?["count"] as? Int ?? 0
                let recordType = notification.userInfo?["recordType"] as? String ?? "items"
                if count > 0 {
                    self?.addMessage(StatusMessage(message: "\(count) CloudKit sync conflict\(count == 1 ? "" : "s") detected for \(recordType). Please resolve.", type: .warning, duration: 10.0))
                }
            }
            .store(in: &cancellables)

        // TODO: Add observers for cache management, other downloads, MFi controller changes etc. as needed.
        // Example for one more:
        NotificationCenter.default.publisher(for: .romScanningProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo, let current = userInfo["current"] as? Int, let total = userInfo["total"] as? Int, total > 0 {
                    let percent = Int((Double(current) / Double(total)) * 100)
                    // This message might be too frequent. Consider if a dedicated progress bar is better handled by StatusMessageViewModel directly.
                    // For now, adding a textual update.
                    self?.addMessage(StatusMessage(message: "ROM Scan: \(percent)% (\(current)/\(total))", type: .info, duration: 2.0))
                }
            }
            .store(in: &cancellables)

        ILOG("StatusMessageManager: All notification observers set up.")
    }

    // MARK: - Private Notification Handlers

    private func handleGameImporterDidStart() {
        let message = "Import process started."
        addMessage(StatusMessage(message: message, type: .info, duration: 3.0))
        ILOG("Game importer did start message added: \(message)")
    }

    private func handleGameImportFileImported(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let fileName = userInfo[PVNotificationUserInfoKeys.fileNameKey] as? String else {
            WLOG("Game import file imported notification received without valid filename.")
            return
        }
        
        let displayName = URL(fileURLWithPath: fileName).lastPathComponent
        let successMessage = "Successfully imported \(displayName)."
        addMessage(StatusMessage(message: successMessage, type: .success, duration: 5.0))
        ILOG("Game import success message added: \(successMessage)")
    }

    private func handleGameImporterFileDidFail(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let fileName = userInfo[PVNotificationUserInfoKeys.fileNameKey] as? String else {
            WLOG("GameImporterFileDidFail notification received without filename.")
            // Optionally, add a generic failure message if filename is missing
            // addMessage(StatusMessage(message: "An import operation failed.", type: .error, duration: 5.0))
            return
        }

        let errorDescription = userInfo[PVNotificationUserInfoKeys.errorKey] as? String ?? "Unknown error"
        let displayName = URL(fileURLWithPath: fileName).lastPathComponent
        let errorMessage = "Failed to import \(displayName): \(errorDescription)"
        addMessage(StatusMessage(message: errorMessage, type: .error, duration: 7.0)) // Longer duration for errors
        ELOG("Game import failure message added: \(errorMessage)")
    }

    private func handleGameImporterDidFinish() {
        let message = "Import process finished."
        addMessage(StatusMessage(message: message, type: .success, duration: 5.0))
        ILOG("Game importer did finish message added: \(message)")
    }

    /// Add a new status message
    /// - Parameter message: The message to add
    public func addMessage(_ message: StatusMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Add the message
            self.messages.append(message)

            // Set a timer to remove the message after its duration
            let timer = Timer.scheduledTimer(withTimeInterval: message.duration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.removeMessage(withID: message.id)
                }
            }

            self.messageTimers[message.id] = timer
        }
    }

    /// Remove a message by its ID
    /// - Parameter id: The ID of the message to remove
    public func removeMessage(withID id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Remove the message
            self.messages.removeAll { $0.id == id }

            // Invalidate and remove the timer
            self.messageTimers[id]?.invalidate()
            self.messageTimers.removeValue(forKey: id)
        }
    }

    /// Clear all messages
    public func clearAllMessages() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Invalidate all timers
            for timer in self.messageTimers.values {
                timer.invalidate()
            }

            // Clear messages and timers
            self.messages.removeAll()
            self.messageTimers.removeAll()
        }
    }

    /// Update the file recovery progress
    /// - Parameters:
    ///   - current: Current number of files processed
    ///   - total: Total number of files to process
    public func updateFileRecoveryProgress(current: Int, total: Int) {
        Task { @MainActor in
            viewModel.fileRecoveryProgress = (current, total)
        }
    }

    /// Clear the file recovery progress
    public func clearFileRecoveryProgress() {
        Task { @MainActor in
            viewModel.clearFileRecoveryProgress()
        }
    }

    /// Set the import active state
    /// - Parameter active: Whether imports are active
    public func setImportActive(_ active: Bool) {
        Task { @MainActor in
            viewModel.setImportActive(active)
        }
    }
}

// Extension to add convenience methods for different message types
public extension StatusMessageManager {
    /// Add an info message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addInfo(_ message: String, duration: TimeInterval = 5.0) {
        addMessage(StatusMessage(message: message, type: .info, duration: duration))
    }

    /// Add a success message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addSuccess(_ message: String, duration: TimeInterval = 5.0) {
        addMessage(StatusMessage(message: message, type: .success, duration: duration))
    }

    /// Add a warning message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addWarning(_ message: String, duration: TimeInterval = 5.0) {
        addMessage(StatusMessage(message: message, type: .warning, duration: duration))
    }

    /// Add an error message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addError(_ message: String, duration: TimeInterval = 8.0) {
        addMessage(StatusMessage(message: message, type: .error, duration: duration))
    }

    /// Add a progress message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addProgress(_ message: String, duration: TimeInterval = 3.0) {
        addMessage(StatusMessage(message: message, type: .progress, duration: duration))
    }
}
