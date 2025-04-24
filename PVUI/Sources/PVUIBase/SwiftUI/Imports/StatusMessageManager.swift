//
//  StatusMessageManager.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import PVLibrary
import PVPrimitives
// Import the StatusMessageViewModel
import PVUIBase

/// A message to be displayed in the status view
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
        
        // Subscribe to notifications for file recovery started
        NotificationCenter.default.publisher(for: iCloudSync.iCloudFileRecoveryStarted)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.addMessage(StatusMessage(
                        message: "Starting file recovery from iCloud Drive...",
                        type: .info,
                        duration: 3.0
                    ))
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to notifications for file recovery completed
        NotificationCenter.default.publisher(for: iCloudSync.iCloudFileRecoveryCompleted)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.addMessage(StatusMessage(
                        message: "File recovery from iCloud Drive completed",
                        type: .success,
                        duration: 5.0
                    ))
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to disk space warnings
        NotificationCenter.default.publisher(for: .diskSpaceWarning)
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    if let userInfo = notification.userInfo,
                       let availableSpace = userInfo["availableSpace"] as? Int64 {
                        let spaceInGB = Double(availableSpace) / 1_073_741_824.0 // Convert to GB
                        self?.addMessage(StatusMessage(
                            message: "Low disk space warning: \(String(format: "%.1f", spaceInGB))GB available",
                            type: .warning,
                            duration: 10.0
                        ))
                    } else {
                        self?.addMessage(StatusMessage(
                            message: "Low disk space warning",
                            type: .warning,
                            duration: 10.0
                        ))
                    }
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to CloudKit notifications
        NotificationCenter.default.publisher(for: .cloudKitRecordTransferStarted)
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    if let userInfo = notification.userInfo,
                       let recordType = userInfo["recordType"] as? String,
                       let isUpload = userInfo["isUpload"] as? Bool {
                        let direction = isUpload ? "uploading to" : "downloading from"
                        self?.addMessage(StatusMessage(
                            message: "\(recordType) \(direction) iCloud...",
                            type: .info,
                            duration: 3.0
                        ))
                    }
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .cloudKitRecordTransferCompleted)
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    if let userInfo = notification.userInfo,
                       let recordType = userInfo["recordType"] as? String,
                       let count = userInfo["count"] as? Int,
                       let isUpload = userInfo["isUpload"] as? Bool {
                        let direction = isUpload ? "uploaded to" : "downloaded from"
                        self?.addMessage(StatusMessage(
                            message: "\(count) \(recordType) records \(direction) iCloud",
                            type: .success,
                            duration: 5.0
                        ))
                    }
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to temporary file cleanup notifications
        NotificationCenter.default.publisher(for: .temporaryFileCleanupStarted)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.addMessage(StatusMessage(
                        message: "Starting temporary file cleanup...",
                        type: .info,
                        duration: 3.0
                    ))
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .temporaryFileCleanupCompleted)
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    if let userInfo = notification.userInfo,
                       let bytesFreed = userInfo["bytesFreed"] as? Int64 {
                        let mbFreed = Double(bytesFreed) / 1_048_576.0 // Convert to MB
                        self?.addMessage(StatusMessage(
                            message: "Temporary file cleanup completed: \(String(format: "%.1f", mbFreed))MB freed",
                            type: .success,
                            duration: 5.0
                        ))
                    } else {
                        self?.addMessage(StatusMessage(
                            message: "Temporary file cleanup completed",
                            type: .success,
                            duration: 5.0
                        ))
                    }
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to ROM scanning notifications
        NotificationCenter.default.publisher(for: .romScanningStarted)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.addMessage(StatusMessage(
                        message: "Starting ROM scanning...",
                        type: .info,
                        duration: 3.0
                    ))
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .romScanningCompleted)
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    if let userInfo = notification.userInfo,
                       let count = userInfo["count"] as? Int {
                        self?.addMessage(StatusMessage(
                            message: "ROM scanning completed: \(count) ROMs processed",
                            type: .success,
                            duration: 5.0
                        ))
                    } else {
                        self?.addMessage(StatusMessage(
                            message: "ROM scanning completed",
                            type: .success,
                            duration: 5.0
                        ))
                    }
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to controller notifications
        NotificationCenter.default.publisher(for: .controllerConnected)
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    if let userInfo = notification.userInfo,
                       let controllerName = userInfo["name"] as? String {
                        self?.addMessage(StatusMessage(
                            message: "Controller connected: \(controllerName)",
                            type: .success,
                            duration: 3.0
                        ))
                    } else {
                        self?.addMessage(StatusMessage(
                            message: "Controller connected",
                            type: .success,
                            duration: 3.0
                        ))
                    }
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .controllerDisconnected)
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    if let userInfo = notification.userInfo,
                       let controllerName = userInfo["name"] as? String {
                        self?.addMessage(StatusMessage(
                            message: "Controller disconnected: \(controllerName)",
                            type: .warning,
                            duration: 3.0
                        ))
                    } else {
                        self?.addMessage(StatusMessage(
                            message: "Controller disconnected",
                            type: .warning,
                            duration: 3.0
                        ))
                    }
                }
            }
            .store(in: &cancellables)
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
