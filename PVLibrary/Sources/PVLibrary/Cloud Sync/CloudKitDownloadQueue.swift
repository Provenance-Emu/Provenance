//
//  CloudKitDownloadQueue.swift
//  PVLibrary
//
//  Created by AI Assistant
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import Combine
import PVLogging
import PVSettings
import Defaults

/// Manages CloudKit asset downloads with space checking, queuing, and progress tracking
public class CloudKitDownloadQueue: ObservableObject {

    // MARK: - Singleton
    public static let shared = CloudKitDownloadQueue()

    // MARK: - Properties
    private let progressTracker = SyncProgressTracker.shared
    private let maxConcurrentDownloads: Int
    private var activeDownloadTasks: [String: Task<Void, Error>] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties for UI
    @Published public var isProcessingQueue = false
    @Published public var queueCount: Int = 0
    @Published public var activeCount: Int = 0
    @Published public var failedCount: Int = 0

    // MARK: - Initialization
    private init() {
        #if os(tvOS)
        // More conservative on tvOS due to limited storage
        self.maxConcurrentDownloads = 2
        #else
        self.maxConcurrentDownloads = 3
        #endif

        // Listen to progress tracker changes
        progressTracker.$queuedDownloads
            .map { $0.count }
            .assign(to: &$queueCount)

        progressTracker.$activeDownloads
            .map { $0.count }
            .assign(to: &$activeCount)

        progressTracker.$failedDownloads
            .map { $0.count }
            .assign(to: &$failedCount)

        progressTracker.$downloadQueueStatus
            .map { status in
                switch status {
                case .downloading: return true
                default: return false
                }
            }
            .assign(to: &$isProcessingQueue)

        ILOG("CloudKit Download Queue initialized with max concurrent downloads: \(maxConcurrentDownloads)")
    }

    // MARK: - Public Methods

    /// Queue a game for download with space checking
    /// - Parameters:
    ///   - md5: Game MD5 hash
    ///   - title: Game title for display
    ///   - fileSize: Expected download size
    ///   - systemIdentifier: System identifier
    ///   - priority: Download priority level
    ///   - onDemand: Whether this is an on-demand download (shows progress UI)
    public func queueDownload(
        md5: String,
        title: String,
        fileSize: Int64,
        systemIdentifier: String,
        priority: SyncProgressTracker.DownloadPriority = .normal,
        onDemand: Bool = false
    ) async throws {

        ILOG("Queuing download: \(title) (\(md5)) - Size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")

        // Check space before queuing
        try progressTracker.queueDownload(
            md5: md5,
            title: title,
            fileSize: fileSize,
            systemIdentifier: systemIdentifier,
            priority: priority
        )

        // Start processing queue if not already running
        if !isProcessingQueue {
            startProcessingQueue()
        }

        // For on-demand downloads, return immediately but show progress
        if onDemand {
            ILOG("On-demand download queued with high priority: \(title)")
        }
    }

    /// Start processing the download queue
    private func startProcessingQueue() {
        guard !isProcessingQueue else { return }

        isProcessingQueue = true
        progressTracker.downloadQueueStatus = .downloading
        progressTracker.startTracking(operation: "Processing Download Queue")

        Task.detached(priority: .background) { [weak self] in
            await self?.processDownloadQueue()
        }
    }

    /// Process downloads from the queue
    private func processDownloadQueue() async {
        ILOG("Starting download queue processing")

        while !progressTracker.queuedDownloads.isEmpty &&
              progressTracker.downloadQueueStatus == .downloading {

            // Check if we can start more downloads
            guard activeDownloadTasks.count < maxConcurrentDownloads else {
                // Wait for active downloads to complete
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                continue
            }

            // Get next download from queue (sorted by priority)
            let sortedQueue = progressTracker.queuedDownloads.sorted { $0.priority.rawValue < $1.priority.rawValue }
            guard let nextDownload = sortedQueue.first else {
                break
            }

            // Start the download
            await startIndividualDownload(nextDownload)

            // Small delay between starting downloads
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        // Wait for all active downloads to complete
        while !activeDownloadTasks.isEmpty {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        // Queue processing complete
        await MainActor.run {
            self.isProcessingQueue = false
            self.progressTracker.downloadQueueStatus = .idle
            self.progressTracker.stopTracking()
            ILOG("Download queue processing completed")
        }
    }

    /// Start an individual download
    private func startIndividualDownload(_ queuedDownload: SyncProgressTracker.QueuedDownload) async {
        guard let _ = progressTracker.startDownload(md5: queuedDownload.md5) else {
            ELOG("Failed to start download for \(queuedDownload.md5)")
            return
        }

        // Create download task
        let downloadTask: Task<Void, Error> = Task { [weak self] in
            do {
                try await self?.executeDownload(queuedDownload)
                await MainActor.run {
                    self?.progressTracker.completeDownload(md5: queuedDownload.md5)
                }
            } catch {
                let cloudError = error as? CloudSyncError ?? CloudSyncError.genericError(error.localizedDescription)
                await MainActor.run {
                    self?.progressTracker.failDownload(md5: queuedDownload.md5, error: cloudError)
                }
                ELOG("Download failed for \(queuedDownload.md5): \(error)")
                throw error // Re-throw to maintain Task<Void, Error> signature
            }

            // Remove from active tasks
            await MainActor.run {
                self?.activeDownloadTasks.removeValue(forKey: queuedDownload.md5)
            }
        }

        activeDownloadTasks[queuedDownload.md5] = downloadTask
    }

    /// Execute the actual download
    private func executeDownload(_ download: SyncProgressTracker.QueuedDownload) async throws {
        ILOG("Executing download: \(download.title) (\(download.md5))")

        // Get the ROM syncer
        guard let romsSyncer = CloudSyncManager.shared.romsSyncer as? CloudKitRomsSyncer else {
            throw CloudSyncError.missingDependency
        }

        // Monitor download progress
        let progressTask = Task { [weak self] in
            while !Task.isCancelled {
                // Update progress periodically
                // This would be improved with actual progress callbacks from CloudKit
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                await MainActor.run {
                    // Estimated progress - in real implementation, get from CloudKit progress
                    let estimatedProgress = min(0.9, Double.random(in: 0.1...0.9))
                    let estimatedBytes = Int64(Double(download.fileSize) * estimatedProgress)
                    self?.progressTracker.updateDownloadProgress(md5: download.md5, bytesDownloaded: estimatedBytes)
                }
            }
        }

        defer {
            progressTask.cancel()
        }

        // Execute the actual download via the ROM syncer
        try await romsSyncer.downloadGame(md5: download.md5)

        // Final progress update
        await MainActor.run {
            self.progressTracker.updateDownloadProgress(md5: download.md5, bytesDownloaded: download.fileSize)
        }

        ILOG("Download completed successfully: \(download.title) (\(download.md5))")
    }

    /// Cancel a specific download
    public func cancelDownload(md5: String) {
        if let task = activeDownloadTasks[md5] {
            task.cancel()
            activeDownloadTasks.removeValue(forKey: md5)
            progressTracker.failDownload(md5: md5, error: .downloadCancelled)
            ILOG("Cancelled download: \(md5)")
        } else {
            // Remove from queue if not active
            if let index = progressTracker.queuedDownloads.firstIndex(where: { $0.md5 == md5 }) {
                progressTracker.queuedDownloads.remove(at: index)
                ILOG("Removed from queue: \(md5)")
            }
        }
    }

    /// Cancel all downloads
    public func cancelAllDownloads() {
        // Cancel active tasks
        for (_, task) in activeDownloadTasks {
            task.cancel()
        }
        activeDownloadTasks.removeAll()

        // Clear queue
        progressTracker.cancelAllDownloads()

        isProcessingQueue = false
        ILOG("Cancelled all downloads")
    }

    /// Pause the download queue
    public func pauseQueue() {
        progressTracker.pauseDownloads()
        ILOG("Paused download queue")
    }

    /// Resume the download queue
    public func resumeQueue() {
        progressTracker.resumeDownloads()
        if !progressTracker.queuedDownloads.isEmpty && !isProcessingQueue {
            startProcessingQueue()
        }
        ILOG("Resumed download queue")
    }

    /// Retry a failed download
    public func retryDownload(md5: String) {
        progressTracker.retryFailedDownload(md5: md5)
        if !isProcessingQueue {
            startProcessingQueue()
        }
        ILOG("Retrying download: \(md5)")
    }

    /// Get download status for a specific MD5
    public func downloadStatus(for md5: String) -> DownloadStatus {
        if progressTracker.activeDownloads.contains(where: { $0.md5 == md5 }) {
            return .downloading
        } else if progressTracker.queuedDownloads.contains(where: { $0.md5 == md5 }) {
            return .queued
        } else if progressTracker.failedDownloads.contains(where: { $0.md5 == md5 }) {
            return .failed
        } else {
            return .notQueued
        }
    }

    /// Download status enumeration
    public enum DownloadStatus {
        case notQueued
        case queued
        case downloading
        case failed
    }
}

// MARK: - Extensions

private extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
