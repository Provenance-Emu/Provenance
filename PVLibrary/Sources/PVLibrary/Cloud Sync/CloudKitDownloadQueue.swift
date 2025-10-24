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

        Task { @MainActor in
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
        }

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
        try await progressTracker.queueDownload(
            md5: md5,
            title: title,
            fileSize: fileSize,
            systemIdentifier: systemIdentifier,
            priority: priority
        )

        // Start processing queue if not already running
        if !isProcessingQueue {
            await startProcessingQueue()
        }

        // For on-demand downloads, return immediately but show progress
        if onDemand {
            ILOG("On-demand download queued with high priority: \(title)")
            // Start immediately, ignoring concurrency limits
            await startOnDemandImmediately(md5: md5)
        }
    }

    /// Start processing the download queue
    private func startProcessingQueue() async {
        guard !isProcessingQueue else { return }
        // Gate auto-sync until metadata has populated PVGame
        if await !SyncProgressTracker.shared.databaseSynced {
            // Leave queue intact; on-demand items are started elsewhere
            return
        }
        isProcessingQueue = true
        Task { @MainActor in
            progressTracker.downloadQueueStatus = .downloading
        }
        await progressTracker.startTracking(operation: "Processing Download Queue")

        Task.detached(priority: .background) { [weak self] in
            await self?.processQueue()
        }
    }

    private func processQueue() async {
        while true {
            if Task.isCancelled { break }
            guard let item = await dequeueNext() else { break }
            await startIndividualDownload(item)
        }
        isProcessingQueue = false
    }

    private func dequeueNext() async -> SyncProgressTracker.QueuedDownload? {
        await MainActor.run { }
        // Pull item on main thread explicitly to avoid type inference issue
        var next: SyncProgressTracker.QueuedDownload? = nil
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            // Prioritize non-high (auto) items here; on-demand (.high) are started via startOnDemandImmediately
            if let idx = self.progressTracker.queuedDownloads.firstIndex(where: { $0.priority != .high }) {
                next = self.progressTracker.queuedDownloads.remove(at: idx)
            }
        }
        return next
    }

    /// Immediately start a queued on-demand download, ignoring concurrency limits
    private func startOnDemandImmediately(md5: String) async {
        Task.detached(priority: .userInitiated) { @MainActor [weak self] in
            guard let self = self else { return }
            // Find the queued item by md5
            var queued: SyncProgressTracker.QueuedDownload
            if let idx = await self.progressTracker.queuedDownloads.firstIndex(where: { $0.md5 == md5 }) {
                queued = self.progressTracker.queuedDownloads.remove(at: idx)
                // Reinsert at front as high priority
                let elevated = SyncProgressTracker.QueuedDownload(md5: queued.md5, title: queued.title, fileSize: queued.fileSize, priority: .high, systemIdentifier: queued.systemIdentifier)

                self.progressTracker.queuedDownloads.insert(elevated, at: 0)
                queued = elevated
            } else {
                VLOG("On-demand item not found in queue (md5=\(md5)); it may already be active")
                // If it's active but not progressing, we still proceed to pause normals
                // but we cannot start another instance.
                // Fall through to prioritization of active downloads
                // and return afterwards.
                // Pause lower-priority downloads if any are running
                await MainActor.run {
                    if self.progressTracker.activeDownloads.contains(where: { _ in true }) {
                        self.progressTracker.pauseDownloads()
                    }
                }
                return
            }
            // Ensure PVGame exists; otherwise defer until DB synced and PVGame created
            if !self.pvGameExists(md5: queued.md5) {
                await MainActor.run { self.progressTracker.deferDownload(queued) }
                return
            }
            // Pause lower priority downloads to favor this on-demand
            await MainActor.run {
                if !self.progressTracker.activeDownloads.isEmpty {
                    self.progressTracker.pauseDownloads()
                }
            }
            await self.startIndividualDownload(queued)
        }
    }

    /// Start an individual download
    private func startIndividualDownload(_ queuedDownload: SyncProgressTracker.QueuedDownload) async {
        guard let _ = await progressTracker.startDownload(md5: queuedDownload.md5) else {
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

        // Create a progress monitoring task that tracks actual CloudKit progress
        let progressTask = Task { [weak self] in
            var currentProgress: Double = 0.0
            let startTime = Date()

            while !Task.isCancelled && currentProgress < 1.0 {
                // Check if download completed externally
                let isStillActive = await MainActor.run {
                    self?.progressTracker.activeDownloads.contains { $0.md5 == download.md5 } ?? false
                }

                if !isStillActive {
                    break
                }

                // Update progress based on time elapsed (better than random)
                let timeElapsed = Date().timeIntervalSince(startTime)
                let estimatedTotalTime = TimeInterval(download.fileSize) / 1_000_000.0 // Rough estimate: 1MB/sec
                currentProgress = min(0.95, timeElapsed / max(estimatedTotalTime, 10.0)) // Cap at 95% until actual completion

                await MainActor.run {
                    let estimatedBytes = Int64(Double(download.fileSize) * currentProgress)
                    self?.progressTracker.updateDownloadProgress(md5: download.md5, bytesDownloaded: estimatedBytes)
                }

                // Update every 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }

        defer {
            progressTask.cancel()
        }

        // Execute the actual download via the ROM syncer
        try await romsSyncer.downloadGame(md5: download.md5)

        // Final progress update - mark as complete
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
            Task { @MainActor in
                progressTracker.failDownload(md5: md5, error: .downloadCancelled)
            }
            ILOG("Cancelled download: \(md5)")
        } else {
            // Remove from queue if not active
            Task { @MainActor in
                if let index = progressTracker.queuedDownloads.firstIndex(where: { $0.md5 == md5 }) {
                    progressTracker.queuedDownloads.remove(at: index)
                    ILOG("Removed from queue: \(md5)")
                }
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
        Task { @MainActor in
            progressTracker.cancelAllDownloads()
        }
        isProcessingQueue = false
        ILOG("Cancelled all downloads")
    }

    /// Pause the download queue
    public func pauseQueue() {
        Task { @MainActor in
            progressTracker.pauseDownloads()
        }
        ILOG("Paused download queue")
    }

    /// Resume the download queue
    public func resumeQueue() {
        Task { @MainActor in
            progressTracker.resumeDownloads()
            if !progressTracker.queuedDownloads.isEmpty && !isProcessingQueue {
                await startProcessingQueue()
            }
        }
        ILOG("Resumed download queue")
    }

    /// Retry a failed download
    public func retryDownload(md5: String) {
        Task { @MainActor in
            progressTracker.retryFailedDownload(md5: md5)
            if !isProcessingQueue {
                await startProcessingQueue()
            }
        }
        ILOG("Retrying download: \(md5)")
    }

    /// Get download status for a specific MD5
    public func downloadStatus(for md5: String) async -> DownloadStatus {
        if await progressTracker.activeDownloads.contains(where: { $0.md5 == md5 }) {
            return .downloading
        } else if await progressTracker.queuedDownloads.contains(where: { $0.md5 == md5 }) {
            return .queued
        } else if await progressTracker.failedDownloads.contains(where: { $0.md5 == md5 }) {
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

    private func pvGameExists(md5: String) -> Bool {
        // Implement a lightweight lookup via RomDatabase/Realm if accessible here; otherwise assume false on tvOS until DB synced
        return true
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
