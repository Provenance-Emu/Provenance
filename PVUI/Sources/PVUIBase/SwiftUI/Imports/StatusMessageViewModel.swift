//
//  StatusMessageViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import PVLibrary
import SwiftUI
import PVPrimitives
import PVWebServer

/// Web server type enum
public enum WebServerType {
    case webUploader
    case webDAV
}

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
    
    // Web server status and upload progress
    @Published public var webServerStatus: (isRunning: Bool, type: WebServerType, url: URL?)? = nil
    @Published public var webServerUploadProgress: (currentFile: String, bytesTransferred: Int64, totalBytes: Int64, progress: Double, queueLength: Int)? = nil

    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupObservers()
    }

    /// Sets up observers for various system notifications
    private func setupObservers() {
        setupFileRecoveryObservers()
        setupROMScanningEnhancedObservers()
        setupTempFileCleanupObservers()
        setupCacheManagementObservers()
        setupDownloadObservers()
        setupCloudKitSyncObservers()
        setupWebServerObservers()
        setupImportQueueObservers()
        setupFileSystemObservers()
        setupNetworkObservers()
        setupControllerObservers()
        setupROMScanningObservers()
        setupCloudKitObservers()
    }

    // MARK: - File Recovery Observers

    #if !os(tvOS)
    private func setupFileRecoveryObservers() {
        // Subscribe to notifications for file recovery progress
        NotificationCenter.default.publisher(for: iCloudDriveSync.iCloudFileRecoveryProgress)
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
    #else
    private func setupFileRecoveryObservers() { }
    #endif

    // MARK: - ROM Scanning Observers

    private func setupROMScanningObservers() {
        // Subscribe to notifications for ROM scanning progress
        NotificationCenter.default.publisher(for: .romScanningProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int {
                    self?.romScanningProgress = (current, total)

                    // If progress is complete, clear it after a delay
                    if current >= total {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                            if self?.romScanningProgress?.current == current {
                                self?.romScanningProgress = nil
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Temporary File Cleanup Observers

    private func setupTempFileCleanupObservers() {
        // Subscribe to notifications for temporary file cleanup progress
        NotificationCenter.default.publisher(for: .temporaryFileCleanupProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int {
                    self?.temporaryFileCleanupProgress = (current, total)

                    // If progress is complete, clear it after a delay
                    if current >= total {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                            if self?.temporaryFileCleanupProgress?.current == current {
                                self?.temporaryFileCleanupProgress = nil
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Cache Management Observers

    private func setupCacheManagementObservers() {
        // Subscribe to notifications for cache management progress
        NotificationCenter.default.publisher(for: .cacheManagementProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int {
                    self?.cacheManagementProgress = (current, total)

                    // If progress is complete, clear it after a delay
                    if current >= total {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                            if self?.cacheManagementProgress?.current == current {
                                self?.cacheManagementProgress = nil
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Download Observers

    private func setupDownloadObservers() {
        // Subscribe to notifications for download progress
        NotificationCenter.default.publisher(for: .downloadProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["bytesDownloaded"] as? Int,
                   let total = userInfo["totalBytes"] as? Int {
                    self?.downloadProgress = (current, total)

                    // If progress is complete, clear it after a delay
                    if current >= total {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                            if self?.downloadProgress?.current == current {
                                self?.downloadProgress = nil
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - CloudKit Sync Observers

    private func setupCloudKitSyncObservers() {
        // Subscribe to notifications for CloudKit sync progress
        NotificationCenter.default.publisher(for: .cloudKitRecordTransferProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int {
                    self?.cloudKitSyncProgress = (current, total)

                    // If progress is complete, clear it after a delay
                    if current >= total {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                            if self?.cloudKitSyncProgress?.current == current {
                                self?.cloudKitSyncProgress = nil
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Also listen for initial sync progress
        NotificationCenter.default.publisher(for: .cloudKitInitialSyncProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int {
                    self?.cloudKitSyncProgress = (current, total)

                    // If progress is complete, clear it after a delay
                    if current >= total {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                            if self?.cloudKitSyncProgress?.current == current {
                                self?.cloudKitSyncProgress = nil
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
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        // Temporary file cleanup
        NotificationCenter.default.publisher(for: .temporaryFileCleanupStarted)
            .sink { [weak self] _ in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .temporaryFileCleanupProgress)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .temporaryFileCleanupCompleted)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        // Cache management
        NotificationCenter.default.publisher(for: .cacheManagementStarted)
            .sink { [weak self] _ in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cacheManagementProgress)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cacheManagementCompleted)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)
    }

    // MARK: - Network Observers

    private func setupNetworkObservers() {
        // Network connectivity changed
        NotificationCenter.default.publisher(for: .networkConnectivityChanged)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)
    }

    // MARK: - Web Server Observers

    private func setupWebServerObservers() {
        // Web server status changed
        NotificationCenter.default.publisher(for: .webServerStatusChanged)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let isRunning = userInfo["isRunning"] as? Bool,
                   let rawType = userInfo["type"] as? String,
                   let url = userInfo["url"] as? URL? {
                    let type: WebServerType = (rawType.lowercased() == "webdav") ? .webDAV : .webUploader
                    self?.webServerStatus = (isRunning: isRunning, type: type, url: url)
                    // Removed message forwarding to StatusMessageManager
                }
            }
            .store(in: &cancellables)

        // Download queue
        NotificationCenter.default.publisher(for: .downloadQueueChanged)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        // Download progress
        NotificationCenter.default.publisher(for: .downloadProgress)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        // Web server upload progress
        NotificationCenter.default.publisher(for: .webServerUploadProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let currentFile = userInfo["currentFile"] as? String,
                   let bytesTransferred = userInfo["bytesTransferred"] as? Int64,
                   let totalBytes = userInfo["totalBytes"] as? Int64,
                   let progress = userInfo["progress"] as? Double,
                   let queueLength = userInfo["queueLength"] as? Int {
                    self?.webServerUploadProgress = (currentFile, bytesTransferred, totalBytes, progress, queueLength)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Controller Observers

    private func setupControllerObservers() {
        // Controller connected
        NotificationCenter.default.publisher(for: .controllerConnected)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        // Controller disconnected
        NotificationCenter.default.publisher(for: .controllerDisconnected)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)
        
        // .controllerMappingStarted, .controllerMappingCompleted - Messages handled by StatusMessageManager if those notifications exist and are observed by it.
        // Removed listeners for these notifications if they only forwarded messages.
    }

    // MARK: - ROM Scanning Enhanced Observers

    private func setupROMScanningEnhancedObservers() {
        // ROM scanning started
        NotificationCenter.default.publisher(for: .romScanningStarted)
            .sink { [weak self] _ in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        // ROM scanning progress with enhanced details
        NotificationCenter.default.publisher(for: .romScanningProgress)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let current = userInfo["current"] as? Int,
                   let total = userInfo["total"] as? Int,
                   let currentROM = userInfo["currentROM"] as? String {
                    self?.romScanningProgress = (current, total)

                    // Removed message forwarding to StatusMessageManager
                }
            }
            .store(in: &cancellables)

        // ROM scanning completed
        NotificationCenter.default.publisher(for: .romScanningCompleted)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)
    }

    // MARK: - CloudKit Observers

    private func setupCloudKitObservers() {
        // Initial sync
        NotificationCenter.default.publisher(for: .cloudKitInitialSyncStarted)
            .sink { [weak self] _ in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitInitialSyncProgress)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitInitialSyncCompleted)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        // Zone changes
        NotificationCenter.default.publisher(for: .cloudKitZoneChangesStarted)
            .sink { [weak self] _ in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitZoneChangesCompleted)
            .sink { [weak self] _ in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        // Record transfer
        NotificationCenter.default.publisher(for: .cloudKitRecordTransferStarted)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitRecordTransferProgress)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitRecordTransferCompleted)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        // Conflicts
        NotificationCenter.default.publisher(for: .cloudKitConflictsDetected)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitConflictsResolved)
            .sink { [weak self] notification in
                // Removed message forwarding to StatusMessageManager
            }
            .store(in: &cancellables)
    }

    /// Clear the file recovery progress
    public func clearFileRecoveryProgress() {
        fileRecoveryProgress = nil
    }
    
    /// Clear the web server upload progress
    public func clearWebServerUploadProgress() {
        webServerUploadProgress = nil
    }

    /// Set the import active state
    public func setImportActive(_ active: Bool) {
        isImportActive = active
    }
}
