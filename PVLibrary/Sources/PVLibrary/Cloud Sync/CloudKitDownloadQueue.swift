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
import PVPrimitives
import PVSettings
import Defaults
import RealmSwift
import PVRealm
import RxSwift

/// Manages CloudKit asset downloads with space checking, queuing, and progress tracking
public class CloudKitDownloadQueue: ObservableObject {

    // MARK: - Singleton
    public static let shared = CloudKitDownloadQueue()

    // MARK: - Properties
    private let progressTracker = SyncProgressTracker.shared
    private let maxConcurrentDownloads: Int
    private var activeDownloadTasks: [String: Task<Void, Error>] = [:]
    private var cancellables = Set<AnyCancellable>()

    /// Active reasons the service is paused (PausableService conformance)
    @MainActor public private(set) var activePauseReasons = Set<ServiceLifecycleReason>()

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

            progressTracker.$databaseSynced
                .removeDuplicates()
                .sink { [weak self] synced in
                    guard let self = self, synced else { return }
                    Task {
                        await self.startProcessingQueue()
                    }
                }
                .store(in: &self.cancellables)
        }

        ILOG("CloudKit Download Queue initialized with max concurrent downloads: \(maxConcurrentDownloads)")

        Task { @MainActor in
            BackgroundServiceRegistry.shared.register(self)
        }
    }

    // MARK: - Public Methods

    /// Queue a ROM download with space checking
    public func queueDownload(
        md5: String,
        title: String,
        fileSize: Int64,
        systemIdentifier: String,
        priority: SyncProgressTracker.DownloadPriority = .normal,
        onDemand: Bool = false
    ) async throws {
        try await enqueueDownload(
            kind: .rom(md5: md5),
            title: title,
            fileSize: fileSize,
            systemIdentifier: systemIdentifier,
            priority: priority,
            onDemand: onDemand
        )
    }

    /// Queue a save-state download
    public func queueSaveStateDownload(
        recordID: String,
        title: String,
        fileSize: Int64,
        systemIdentifier: String,
        priority: SyncProgressTracker.DownloadPriority = .normal
    ) async throws {
        try await enqueueDownload(
            kind: .saveState(recordID: recordID),
            title: title,
            fileSize: fileSize,
            systemIdentifier: systemIdentifier,
            priority: priority,
            onDemand: false
        )
    }

    private func enqueueDownload(
        kind: SyncProgressTracker.DownloadKind,
        title: String,
        fileSize: Int64,
        systemIdentifier: String,
        priority: SyncProgressTracker.DownloadPriority,
        onDemand: Bool
    ) async throws {
        ILOG("Queuing download: \(title) [\(kind.description)] - Size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")

        // Check space before queuing
        switch kind {
        case .rom(let md5):
        try await progressTracker.queueDownload(
            md5: md5,
            title: title,
            fileSize: fileSize,
            systemIdentifier: systemIdentifier,
            priority: priority
        )
        case .saveState(let recordID):
            try await progressTracker.queueSaveStateDownload(
                recordID: recordID,
                title: title,
                fileSize: fileSize,
                systemIdentifier: systemIdentifier,
                priority: priority
            )
        }

        // Start processing queue if not already running
        if !isProcessingQueue {
            await startProcessingQueue()
        }

        // For on-demand ROM downloads, return immediately but show progress
        if onDemand {
            ILOG("On-demand download queued with high priority: \(title)")
            if case .rom(let md5) = kind {
            await startOnDemandImmediately(md5: md5)
            }
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
            let targetKind = SyncProgressTracker.DownloadKind.rom(md5: md5)
            if let idx = await self.progressTracker.queuedDownloads.firstIndex(where: { $0.kind == targetKind }) {
                queued = self.progressTracker.queuedDownloads.remove(at: idx)
                // Reinsert at front as high priority
                let elevated = SyncProgressTracker.QueuedDownload(
                    kind: queued.kind,
                    title: queued.title,
                    fileSize: queued.fileSize,
                    priority: .high,
                    systemIdentifier: queued.systemIdentifier
                )

                self.progressTracker.queuedDownloads.insert(elevated, at: 0)
                queued = elevated
            } else {
                VLOG("On-demand item not found in queue (md5=\(md5)); it may already be active")
                // Pause lower-priority downloads if any are running
                await MainActor.run {
                    if self.progressTracker.activeDownloads.contains(where: { _ in true }) {
                        self.progressTracker.pauseDownloads()
                    }
                }
                return
            }
            // Ensure PVGame exists; otherwise defer until DB synced and PVGame created
            if case let .rom(currentMD5) = queued.kind, !self.pvGameExists(md5: currentMD5) {
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
        guard let _ = await progressTracker.startDownload(kind: queuedDownload.kind) else {
            ELOG("Failed to start download for \(queuedDownload.kind.description)")
            return
        }

        // Create download task
        let downloadTask: Task<Void, Error> = Task { [weak self] in
            do {
                try await self?.executeDownload(queuedDownload)
                await MainActor.run {
                    self?.progressTracker.completeDownload(kind: queuedDownload.kind)
                }
            } catch {
                let cloudError = error as? CloudSyncError ?? CloudSyncError.genericError(error.localizedDescription)
                await MainActor.run {
                    self?.progressTracker.failDownload(kind: queuedDownload.kind, error: cloudError)
                }
                ELOG("Download failed for \(queuedDownload.kind.description): \(error)")
                throw error // Re-throw to maintain Task<Void, Error> signature
            }

            // Remove from active tasks
            await MainActor.run {
                self?.activeDownloadTasks.removeValue(forKey: queuedDownload.identifier)
            }
        }

        activeDownloadTasks[queuedDownload.identifier] = downloadTask
    }

    /// Execute the actual download
    private func executeDownload(_ download: SyncProgressTracker.QueuedDownload) async throws {
        ILOG("Executing download: \(download.title) [\(download.kind.description)]")

        switch download.kind {
        case .rom(let md5):
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
                        self?.progressTracker.activeDownloads.contains { $0.kind == download.kind } ?? false
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
                        self?.progressTracker.updateDownloadProgress(kind: download.kind, bytesDownloaded: estimatedBytes)
                }

                // Update every 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }

        defer {
            progressTask.cancel()
        }

            try await romsSyncer.downloadGame(md5: md5)

            await MainActor.run {
                self.progressTracker.updateDownloadProgress(kind: download.kind, bytesDownloaded: download.fileSize)
            }

        case .saveState(let recordID):
            guard let saveStateSyncer = CloudSyncManager.shared.saveStatesSyncer as? CloudKitSaveStatesSyncer else {
                throw CloudSyncError.missingDependency
            }

            let frozenSaveState = try? await RealmContext.withRealm { realm -> PVSaveState? in
                let state = realm.objects(PVSaveState.self)
                    .filter("cloudRecordID == %@", recordID)
                    .first ?? realm.object(ofType: PVSaveState.self, forPrimaryKey: recordID)
                return state?.freeze()
            }

            guard let saveState = frozenSaveState else {
                throw CloudSyncError.genericError("Save state not found for recordID \(recordID)")
            }
            try await saveStateSyncer.downloadSaveState(for: saveState, isUserInitiated: true).toAsync()

        await MainActor.run {
                self.progressTracker.updateDownloadProgress(kind: download.kind, bytesDownloaded: download.fileSize)
            }
        }

        ILOG("Download completed successfully: \(download.title) [\(download.kind.description)]")
    }

    /// Cancel a specific download
    public func cancelDownload(md5: String) {
        let key = SyncProgressTracker.DownloadKind.rom(md5: md5).identifier
        if let task = activeDownloadTasks[key] {
            task.cancel()
            activeDownloadTasks.removeValue(forKey: key)
            Task { @MainActor in
                progressTracker.failDownload(kind: .rom(md5: md5), error: .downloadCancelled)
            }
            ILOG("Cancelled download: \(md5)")
        } else {
            // Remove from queue if not active
            Task { @MainActor in
                if let index = progressTracker.queuedDownloads.firstIndex(where: { $0.kind == .rom(md5: md5) }) {
                    progressTracker.queuedDownloads.remove(at: index)
                    ILOG("Removed from queue: \(md5)")
                }
            }
        }
    }

    /// Cancel a specific save-state download
    public func cancelSaveStateDownload(recordID: String) {
        let key = SyncProgressTracker.DownloadKind.saveState(recordID: recordID).identifier
        if let task = activeDownloadTasks[key] {
            task.cancel()
            activeDownloadTasks.removeValue(forKey: key)
            Task { @MainActor in
                progressTracker.failDownload(kind: .saveState(recordID: recordID), error: .downloadCancelled)
            }
            ILOG("Cancelled save-state download: \(recordID)")
        } else {
            Task { @MainActor in
                if let index = progressTracker.queuedDownloads.firstIndex(where: { $0.kind == .saveState(recordID: recordID) }) {
                    progressTracker.queuedDownloads.remove(at: index)
                    ILOG("Removed save-state from queue: \(recordID)")
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

    /// Legacy convenience — delegates to `pause(reason: .emulation)`
    public func pauseQueue() {
        Task { @MainActor in
            pause(reason: .emulation)
        }
    }

    /// Legacy convenience — delegates to `resume(reason: .emulation)`
    public func resumeQueue() {
        Task { @MainActor in
            resume(reason: .emulation)
        }
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
        if await progressTracker.activeDownloads.contains(where: { $0.kind == .rom(md5: md5) }) {
            return .downloading
        } else if await progressTracker.queuedDownloads.contains(where: { $0.kind == .rom(md5: md5) }) {
            return .queued
        } else if await progressTracker.failedDownloads.contains(where: { $0.kind == .rom(md5: md5) }) {
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
        return true
    }
}

// MARK: - PausableService

extension CloudKitDownloadQueue: PausableService {

    public var serviceName: String { "CloudKitDownloadQueue" }

    @MainActor
    public func pause(reason: ServiceLifecycleReason) {
        guard !activePauseReasons.contains(reason) else { return }
        let wasRunning = activePauseReasons.isEmpty
        activePauseReasons.insert(reason)

        guard wasRunning else { return }

        ILOG("CloudKitDownloadQueue: Pausing (reason: \(reason.rawValue))")
        progressTracker.pauseDownloads()
    }

    @MainActor
    public func resume(reason: ServiceLifecycleReason) {
        guard activePauseReasons.contains(reason) else { return }
        activePauseReasons.remove(reason)

        guard activePauseReasons.isEmpty else {
            ILOG("CloudKitDownloadQueue: Cleared reason \(reason.rawValue) but still paused for: \(activePauseReasons.map(\.rawValue))")
            return
        }

        ILOG("CloudKitDownloadQueue: Resuming (cleared: \(reason.rawValue))")
        progressTracker.resumeDownloads()
        Task {
            if !progressTracker.queuedDownloads.isEmpty && !isProcessingQueue {
                await startProcessingQueue()
            }
        }
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
