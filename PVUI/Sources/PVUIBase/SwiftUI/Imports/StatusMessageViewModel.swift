//
//  StatusMessageViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import PVLibrary
import SwiftUI

/// ViewModel to handle actor isolation for StatusMessageManager
@MainActor
public class StatusMessageViewModel: ObservableObject {
    @Published public var fileRecoveryProgress: (current: Int, total: Int)? = nil
    @Published public var isImportActive: Bool = false
    
    // Additional progress tracking
    @Published public var romScanningProgress: (current: Int, total: Int)? = nil
    @Published public var temporaryFileCleanupProgress: (current: Int, total: Int)? = nil
    @Published public var cacheManagementProgress: (current: Int, total: Int)? = nil
    @Published public var downloadProgress: (current: Int, total: Int)? = nil
    @Published public var cloudKitSyncProgress: (current: Int, total: Int)? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupObservers()
    }
    
    /// Sets up observers for various system notifications
    private func setupObservers() {
        setupFileRecoveryObservers()
        setupImportQueueObservers()
        setupFileSystemObservers()
        setupNetworkObservers()
        setupControllerObservers()
        setupROMScanningObservers()
        setupCloudKitObservers()
    }
    
    // MARK: - File Recovery Observers
    
    private func setupFileRecoveryObservers() {
        // Subscribe to notifications for file recovery progress
        NotificationCenter.default.publisher(for: iCloudSync.iCloudFileRecoveryProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int {
                    self?.fileRecoveryProgress = (current, total)
                    
                    // If progress is complete, clear it after a delay
                    if current >= total {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                            if self?.fileRecoveryProgress?.current == current {
                                self?.fileRecoveryProgress = nil
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Import Queue Observers
    
    private func setupImportQueueObservers() {
        // Define a notification name for import queue changes
        let importQueueChangedNotification = Notification.Name("ImportQueueChanged")
        
        // Subscribe to import queue changes
        NotificationCenter.default.publisher(for: importQueueChangedNotification)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let count = userInfo["count"] as? Int {
                    self?.isImportActive = count > 0
                }
            }
            .store(in: &cancellables)
        
        // Also track changes through the GameImporter if available
        Task {
            if let gameImporter = await MainActor.run { AppState.shared.gameImporter } as? GameImporter {
                gameImporter.importQueuePublisher
                    .receive(on: RunLoop.main)
                    .sink { [weak self] queue in
                        self?.isImportActive = !queue.isEmpty
                    }
                    .store(in: &cancellables)
            }
        }
    }
    
    // MARK: - File System Observers
    
    private func setupFileSystemObservers() {
        // Disk space warning
        NotificationCenter.default.publisher(for: .diskSpaceWarning)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let userInfo = notification.userInfo,
                   let availableMB = userInfo["availableMB"] as? Double {
                    let message = "Low disk space warning: \(Int(availableMB)) MB available"
                    StatusMessageManager.shared.addWarning(message, duration: 10.0)
                }
            }
            .store(in: &cancellables)
        
        // Temporary file cleanup
        NotificationCenter.default.publisher(for: .temporaryFileCleanupStarted)
            .sink { [weak self] _ in
                StatusMessageManager.shared.addInfo("Starting temporary file cleanup", duration: 3.0)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .temporaryFileCleanupProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int,
                   let bytesFreed = userInfo["bytesFreed"] as? Int64 {
                    self?.temporaryFileCleanupProgress = (current, total)
                    
                    // Convert bytes to MB for display
                    let mbFreed = Double(bytesFreed) / 1_048_576.0 // 1024^2
                    let message = "Cleaning up temporary files: \(current)/\(total) (\(String(format: "%.1f", mbFreed)) MB freed)"
                    StatusMessageManager.shared.addInfo(message, duration: 2.0)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .temporaryFileCleanupCompleted)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let bytesFreed = userInfo["bytesFreed"] as? Int64,
                   let fileCount = userInfo["fileCount"] as? Int {
                    // Convert bytes to MB for display
                    let mbFreed = Double(bytesFreed) / 1_048_576.0 // 1024^2
                    let message = "Temporary file cleanup complete: \(fileCount) files removed, \(String(format: "%.1f", mbFreed)) MB freed"
                    StatusMessageManager.shared.addSuccess(message, duration: 5.0)
                    self?.temporaryFileCleanupProgress = nil
                }
            }
            .store(in: &cancellables)
        
        // Cache management
        NotificationCenter.default.publisher(for: .cacheManagementStarted)
            .sink { [weak self] _ in
                StatusMessageManager.shared.addInfo("Starting cache optimization", duration: 3.0)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cacheManagementProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int {
                    self?.cacheManagementProgress = (current, total)
                    
                    let message = "Optimizing cache: \(current)/\(total)"
                    StatusMessageManager.shared.addInfo(message, duration: 2.0)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cacheManagementCompleted)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let bytesFreed = userInfo["bytesFreed"] as? Int64 {
                    // Convert bytes to MB for display
                    let mbFreed = Double(bytesFreed) / 1_048_576.0 // 1024^2
                    let message = "Cache optimization complete: \(String(format: "%.1f", mbFreed)) MB optimized"
                    StatusMessageManager.shared.addSuccess(message, duration: 5.0)
                    self?.cacheManagementProgress = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Network Observers
    
    private func setupNetworkObservers() {
        // Network connectivity
        NotificationCenter.default.publisher(for: .networkConnectivityChanged)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let isConnected = userInfo["isConnected"] as? Bool {
                    let message = isConnected ? "Network connection established" : "Network connection lost"
                    let type: StatusMessage.MessageType = isConnected ? .success : .warning
                    StatusMessageManager.shared.addMessage(StatusMessage(message: message, type: type, duration: 3.0))
                }
            }
            .store(in: &cancellables)
        
        // Download queue
        NotificationCenter.default.publisher(for: .downloadQueueChanged)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let queueCount = userInfo["queueCount"] as? Int {
                    if queueCount > 0 {
                        StatusMessageManager.shared.addInfo("\(queueCount) downloads in queue", duration: 3.0)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Download progress
        NotificationCenter.default.publisher(for: .downloadProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int,
                   let fileName = userInfo["fileName"] as? String {
                    self?.downloadProgress = (current, total)
                    
                    let message = "Downloading \(fileName): \(current)/\(total) bytes"
                    StatusMessageManager.shared.addInfo(message, duration: 2.0)
                }
            }
            .store(in: &cancellables)
        
        // Web server status
        NotificationCenter.default.publisher(for: .webServerStatusChanged)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let isRunning = userInfo["isRunning"] as? Bool,
                   let port = userInfo["port"] as? Int {
                    let message = isRunning ? 
                        "Web server started on port \(port)" : 
                        "Web server stopped"
                    let type: StatusMessage.MessageType = isRunning ? .success : .info
                    StatusMessageManager.shared.addMessage(StatusMessage(message: message, type: type, duration: 5.0))
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Controller Observers
    
    private func setupControllerObservers() {
        // Controller connected
        NotificationCenter.default.publisher(for: .controllerConnected)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let controllerName = userInfo["controllerName"] as? String {
                    let message = "Controller connected: \(controllerName)"
                    StatusMessageManager.shared.addSuccess(message, duration: 3.0)
                }
            }
            .store(in: &cancellables)
        
        // Controller disconnected
        NotificationCenter.default.publisher(for: .controllerDisconnected)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let controllerName = userInfo["controllerName"] as? String {
                    let message = "Controller disconnected: \(controllerName)"
                    StatusMessageManager.shared.addInfo(message, duration: 3.0)
                }
            }
            .store(in: &cancellables)
        
        // Controller mapping
        NotificationCenter.default.publisher(for: .controllerMappingStarted)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let controllerName = userInfo["controllerName"] as? String {
                    let message = "Mapping controller: \(controllerName)"
                    StatusMessageManager.shared.addInfo(message, duration: 3.0)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .controllerMappingCompleted)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let controllerName = userInfo["controllerName"] as? String,
                   let success = userInfo["success"] as? Bool {
                    let message = success ? 
                        "Controller mapped successfully: \(controllerName)" : 
                        "Controller mapping failed: \(controllerName)"
                    let type: StatusMessage.MessageType = success ? .success : .error
                    StatusMessageManager.shared.addMessage(StatusMessage(message: message, type: type, duration: 5.0))
                }
            }
            .store(in: &cancellables)
        
        // MFi controller config
        NotificationCenter.default.publisher(for: .mfiControllerConfigChanged)
            .sink { [weak self] _ in
                StatusMessageManager.shared.addInfo("MFi controller configuration updated", duration: 3.0)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - ROM Scanning Observers
    
    private func setupROMScanningObservers() {
        // ROM scanning started
        NotificationCenter.default.publisher(for: .romScanningStarted)
            .sink { [weak self] _ in
                StatusMessageManager.shared.addInfo("Starting ROM scanning", duration: 3.0)
            }
            .store(in: &cancellables)
        
        // ROM scanning progress
        NotificationCenter.default.publisher(for: .romScanningProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int,
                   let currentROM = userInfo["currentROM"] as? String {
                    self?.romScanningProgress = (current, total)
                    
                    let message = "Scanning ROM \(current)/\(total): \(currentROM)"
                    StatusMessageManager.shared.addInfo(message, duration: 2.0)
                }
            }
            .store(in: &cancellables)
        
        // ROM scanning completed
        NotificationCenter.default.publisher(for: .romScanningCompleted)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let totalScanned = userInfo["totalScanned"] as? Int,
                   let newROMs = userInfo["newROMs"] as? Int {
                    let message = "ROM scanning complete: \(totalScanned) ROMs scanned, \(newROMs) new ROMs found"
                    StatusMessageManager.shared.addSuccess(message, duration: 5.0)
                    self?.romScanningProgress = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - CloudKit Observers
    
    private func setupCloudKitObservers() {
        // Initial sync
        NotificationCenter.default.publisher(for: .cloudKitInitialSyncStarted)
            .sink { [weak self] _ in
                StatusMessageManager.shared.addInfo("Starting initial CloudKit sync", duration: 3.0)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cloudKitInitialSyncProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int,
                   let dataType = userInfo["dataType"] as? String {
                    self?.cloudKitSyncProgress = (current, total)
                    
                    let message = "Syncing \(dataType): \(current)/\(total)"
                    StatusMessageManager.shared.addInfo(message, duration: 2.0)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cloudKitInitialSyncCompleted)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let totalSynced = userInfo["totalSynced"] as? Int {
                    let message = "Initial CloudKit sync complete: \(totalSynced) items synced"
                    StatusMessageManager.shared.addSuccess(message, duration: 5.0)
                    self?.cloudKitSyncProgress = nil
                }
            }
            .store(in: &cancellables)
        
        // Zone changes
        NotificationCenter.default.publisher(for: .cloudKitZoneChangesStarted)
            .sink { [weak self] _ in
                StatusMessageManager.shared.addInfo("Updating CloudKit zones", duration: 3.0)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cloudKitZoneChangesCompleted)
            .sink { [weak self] _ in
                StatusMessageManager.shared.addSuccess("CloudKit zones updated", duration: 3.0)
            }
            .store(in: &cancellables)
        
        // Record transfer
        NotificationCenter.default.publisher(for: .cloudKitRecordTransferStarted)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let isUpload = userInfo["isUpload"] as? Bool,
                   let recordType = userInfo["recordType"] as? String {
                    let direction = isUpload ? "Uploading" : "Downloading"
                    let message = "\(direction) \(recordType) records to CloudKit"
                    StatusMessageManager.shared.addInfo(message, duration: 3.0)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cloudKitRecordTransferProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int,
                   let isUpload = userInfo["isUpload"] as? Bool,
                   let recordType = userInfo["recordType"] as? String {
                    self?.cloudKitSyncProgress = (current, total)
                    
                    let direction = isUpload ? "Uploading" : "Downloading"
                    let message = "\(direction) \(recordType) records: \(current)/\(total)"
                    StatusMessageManager.shared.addInfo(message, duration: 2.0)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cloudKitRecordTransferCompleted)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let count = userInfo["count"] as? Int,
                   let isUpload = userInfo["isUpload"] as? Bool,
                   let recordType = userInfo["recordType"] as? String {
                    let direction = isUpload ? "Uploaded" : "Downloaded"
                    let message = "\(direction) \(count) \(recordType) records"
                    StatusMessageManager.shared.addSuccess(message, duration: 5.0)
                    self?.cloudKitSyncProgress = nil
                }
            }
            .store(in: &cancellables)
        
        // Conflicts
        NotificationCenter.default.publisher(for: .cloudKitConflictsDetected)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let count = userInfo["count"] as? Int,
                   let recordType = userInfo["recordType"] as? String {
                    let message = "Detected \(count) conflicts in \(recordType) records"
                    StatusMessageManager.shared.addWarning(message, duration: 5.0)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cloudKitConflictsResolved)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let count = userInfo["count"] as? Int,
                   let recordType = userInfo["recordType"] as? String {
                    let message = "Resolved \(count) conflicts in \(recordType) records"
                    StatusMessageManager.shared.addSuccess(message, duration: 5.0)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Clear the file recovery progress
    public func clearFileRecoveryProgress() {
        fileRecoveryProgress = nil
    }
    
    /// Set the import active state
    public func setImportActive(_ active: Bool) {
        isImportActive = active
    }
}
