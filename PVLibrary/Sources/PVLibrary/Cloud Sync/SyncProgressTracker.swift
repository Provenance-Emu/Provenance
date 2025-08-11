//
//  SyncProgressTracker.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import PVLogging

/// A singleton class to track CloudKit sync progress across the app
public final class SyncProgressTracker: ObservableObject, Sendable {
    /// Shared instance for app-wide access
    public static let shared = SyncProgressTracker()

    // MARK: - Properties

    /// Current operation being performed
    @Published public var currentOperation: String = ""

    /// Progress of the current operation (0.0 to 1.0)
    @Published public var progress: Double = 0

    /// Whether a sync operation is currently active
    @Published public var isActive: Bool = false

    // MARK: - New: Download Queue Management

    /// Current download queue status
    @Published public var downloadQueueStatus: DownloadQueueStatus = .idle

    /// Download queue items
    @Published public var queuedDownloads: [QueuedDownload] = []

    /// Currently downloading items
    @Published public var activeDownloads: [ActiveDownload] = []

    /// Failed downloads that can be retried
    @Published public var failedDownloads: [FailedDownload] = []

    /// Total bytes to download
    @Published public var totalBytesToDownload: Int64 = 0

    /// Total bytes downloaded
    @Published public var totalBytesDownloaded: Int64 = 0

    /// Available disk space
    @Published public var availableDiskSpace: Int64 = 0

    /// Space required for pending downloads
    @Published public var spaceRequiredForQueue: Int64 = 0

    /// Set true once Realm DB has been populated from metadata sync (PVGame/PVSystem/etc.)
    @Published public var databaseSynced: Bool = false

    /// Downloads that were requested before databaseSynced and/or before PVGame existed
    @Published public private(set) var deferredDownloads: [QueuedDownload] = []

    // MARK: - Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Subject for throttling progress updates
    private var progressSubject = PassthroughSubject<Double, Never>()

    /// Task that can be cancelled when an operation is stopped
    private var currentTask: Task<Void, Error>?

    // MARK: - Download Queue Data Structures

    /// Status of the download queue
    public enum DownloadQueueStatus: Equatable {
        case idle
        case downloading
        case paused
        case error(Error)

        public static func == (lhs: DownloadQueueStatus, rhs: DownloadQueueStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.downloading, .downloading), (.paused, .paused):
                return true
            case (.error, .error):
                return true // Consider all errors equal for comparison purposes
            default:
                return false
            }
        }
    }

    /// A queued download waiting to start
    public struct QueuedDownload: Identifiable, Equatable {
        public let id = UUID()
        public let md5: String
        public let title: String
        public let fileSize: Int64
        public let priority: DownloadPriority
        public let systemIdentifier: String

        public static func == (lhs: QueuedDownload, rhs: QueuedDownload) -> Bool {
            lhs.md5 == rhs.md5
        }
    }

    /// An actively downloading item
    public struct ActiveDownload: Identifiable, Equatable {
        public let id = UUID()
        public let md5: String
        public let title: String
        public let fileSize: Int64
        public let systemIdentifier: String
        public var bytesDownloaded: Int64 = 0
        public var progress: Double {
            guard fileSize > 0 else { return 0 }
            return Double(bytesDownloaded) / Double(fileSize)
        }
        public let startTime: Date = Date()

        public static func == (lhs: ActiveDownload, rhs: ActiveDownload) -> Bool {
            lhs.md5 == rhs.md5
        }
    }

    /// A failed download that can be retried
    public struct FailedDownload: Identifiable, Equatable {
        public let id = UUID()
        public let md5: String
        public let title: String
        public let fileSize: Int64
        public let systemIdentifier: String
        public let error: CloudSyncError
        public let failureTime: Date = Date()
        public var retryCount: Int = 0

        public static func == (lhs: FailedDownload, rhs: FailedDownload) -> Bool {
            lhs.md5 == rhs.md5
        }
    }

    /// Download priority levels
    public enum DownloadPriority: Int, CaseIterable {
        case high = 0      // User requested (on-demand)
        case normal = 1    // Background sync
        case low = 2       // Bulk sync

        public var description: String {
            switch self {
            case .high: return "High"
            case .normal: return "Normal"
            case .low: return "Low"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        setupProgressThrottling()
    }

    // MARK: - Public Methods

    /// Start tracking a new sync operation
    /// - Parameter operation: Description of the operation being performed
    public func startTracking(operation: String) {
        DLOG("Starting CloudKit operation: \(operation)")
        currentOperation = operation
        isActive = true
        progress = 0
    }

    /// Update the progress of the current operation
    /// - Parameter newProgress: Progress value between 0.0 and 1.0
    public func updateProgress(_ newProgress: Double) {
        progressSubject.send(min(max(newProgress, 0.0), 1.0))
    }

    /// Mark the current operation as complete
    public func completeOperation() {
        DLOG("Completed CloudKit operation: \(currentOperation)")
        progress = 1.0

        // Small delay before hiding to allow UI to show completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isActive = false
            self?.currentOperation = ""
            self?.progress = 0
        }
    }

    /// Stop tracking the current operation
    public func stopTracking() {
        DLOG("Stopping CloudKit operation: \(currentOperation)")
        isActive = false
        currentOperation = ""
        progress = 0
        currentTask?.cancel()
        currentTask = nil
    }

    /// Cancel the current operation
    public func cancel() {
        DLOG("Cancelling CloudKit operation: \(currentOperation)")
        currentTask?.cancel()
        stopTracking()
    }

    /// Track an operation with automatic start/stop management
    /// - Parameters:
    ///   - operation: Description of the operation being performed
    ///   - block: The operation to execute
    /// - Returns: The result of the operation
    public func trackOperation<T>(operation: String, block: (SyncProgressTracker) async throws -> T) async throws -> T {
        startTracking(operation: operation)
        defer { stopTracking() }

        do {
            let result = try await block(self)
            completeOperation()
            return result
        } catch {
            stopTracking()
            throw error
        }
    }

    // MARK: - New: Download Queue Management Methods

    /// Add a download to the queue
    public func queueDownload(md5: String, title: String, fileSize: Int64, systemIdentifier: String, priority: DownloadPriority = .normal) throws {
        // Check if already queued, active, or failed
        guard !queuedDownloads.contains(where: { $0.md5 == md5 }),
              !activeDownloads.contains(where: { $0.md5 == md5 }),
              !failedDownloads.contains(where: { $0.md5 == md5 }) else {
            VLOG("Download for \(md5) already in queue/active/failed")
            return
        }

        // Check space requirements
        try checkSpaceForDownload(fileSize: fileSize)

        let download = QueuedDownload(
            md5: md5,
            title: title,
            fileSize: fileSize,
            priority: priority,
            systemIdentifier: systemIdentifier
        )

        // Insert based on priority
        if let insertIndex = queuedDownloads.firstIndex(where: { $0.priority.rawValue > priority.rawValue }) {
            queuedDownloads.insert(download, at: insertIndex)
        } else {
            queuedDownloads.append(download)
        }

        updateSpaceRequirements()
        ILOG("Queued download: \(title) (\(md5)) - \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
    }

    /// Move a download from queue to active
    public func startDownload(md5: String) -> QueuedDownload? {
        guard let index = queuedDownloads.firstIndex(where: { $0.md5 == md5 }) else {
            WLOG("Cannot start download - \(md5) not found in queue")
            return nil
        }

        let queuedDownload = queuedDownloads.remove(at: index)
        let activeDownload = ActiveDownload(
            md5: queuedDownload.md5,
            title: queuedDownload.title,
            fileSize: queuedDownload.fileSize,
            systemIdentifier: queuedDownload.systemIdentifier
        )

        activeDownloads.append(activeDownload)
        downloadQueueStatus = .downloading
        updateSpaceRequirements()

        ILOG("Started download: \(queuedDownload.title) (\(md5))")
        return queuedDownload
    }

    /// Update progress for an active download
    public func updateDownloadProgress(md5: String, bytesDownloaded: Int64) {
        guard let index = activeDownloads.firstIndex(where: { $0.md5 == md5 }) else {
            return
        }

        let oldBytesDownloaded = activeDownloads[index].bytesDownloaded
        activeDownloads[index].bytesDownloaded = bytesDownloaded

        // Update total progress
        let bytesIncrease = bytesDownloaded - oldBytesDownloaded
        totalBytesDownloaded += bytesIncrease

        // Update overall progress
        if totalBytesToDownload > 0 {
            let overallProgress = Double(totalBytesDownloaded) / Double(totalBytesToDownload)
            updateProgress(overallProgress)
        }
    }

    /// Complete a download (success)
    public func completeDownload(md5: String) {
        guard let index = activeDownloads.firstIndex(where: { $0.md5 == md5 }) else {
            WLOG("Cannot complete download - \(md5) not found in active downloads")
            return
        }

        let completedDownload = activeDownloads.remove(at: index)
        updateSpaceRequirements()
        updateDiskSpaceInternal()

        // Check if queue is now empty
        if activeDownloads.isEmpty && queuedDownloads.isEmpty {
            downloadQueueStatus = .idle
            ILOG("All downloads completed")
        }

        ILOG("Completed download: \(completedDownload.title) (\(md5))")
    }

    /// Fail a download
    public func failDownload(md5: String, error: CloudSyncError) {
        guard let index = activeDownloads.firstIndex(where: { $0.md5 == md5 }) else {
            WLOG("Cannot fail download - \(md5) not found in active downloads")
            return
        }

        let activeDownload = activeDownloads.remove(at: index)
        let failedDownload = FailedDownload(
            md5: activeDownload.md5,
            title: activeDownload.title,
            fileSize: activeDownload.fileSize,
            systemIdentifier: activeDownload.systemIdentifier,
            error: error
        )

        failedDownloads.append(failedDownload)
        updateSpaceRequirements()

        // Check if this was the last active download
        if activeDownloads.isEmpty {
            downloadQueueStatus = queuedDownloads.isEmpty ? .idle : .error(error)
        }

        ELOG("Failed download: \(activeDownload.title) (\(md5)) - \(error)")
    }

    /// Retry a failed download
    public func retryFailedDownload(md5: String) {
        guard let index = failedDownloads.firstIndex(where: { $0.md5 == md5 }) else {
            WLOG("Cannot retry download - \(md5) not found in failed downloads")
            return
        }

        var failedDownload = failedDownloads.remove(at: index)
        failedDownload.retryCount += 1

        // Add back to queue with high priority for retry
        let queuedDownload = QueuedDownload(
            md5: failedDownload.md5,
            title: failedDownload.title,
            fileSize: failedDownload.fileSize,
            priority: .high,
            systemIdentifier: failedDownload.systemIdentifier
        )

        queuedDownloads.insert(queuedDownload, at: 0) // High priority goes first
        updateSpaceRequirements()

        ILOG("Retrying download: \(failedDownload.title) (\(md5)) - Attempt \(failedDownload.retryCount)")
    }

    /// Cancel all downloads
    public func cancelAllDownloads() {
        queuedDownloads.removeAll()
        activeDownloads.removeAll()
        downloadQueueStatus = .idle
        updateSpaceRequirements()
        ILOG("Cancelled all downloads")
    }

    /// Pause the download queue
    public func pauseDownloads() {
        downloadQueueStatus = .paused
        ILOG("Paused download queue")
    }

    /// Resume the download queue
    public func resumeDownloads() {
        downloadQueueStatus = queuedDownloads.isEmpty && activeDownloads.isEmpty ? .idle : .downloading
        ILOG("Resumed download queue")
    }

    // MARK: - Space Management

    /// Check if there's enough space for a download
    private func checkSpaceForDownload(fileSize: Int64) throws {
        updateDiskSpaceInternal()

        let spaceBuffer: Int64 = 500_000_000 // 500MB buffer
        let requiredSpace = fileSize + spaceBuffer

        #if os(tvOS)
        // More aggressive space checking on tvOS due to limited storage
        let tvOSBuffer: Int64 = 1_000_000_000 // 1GB buffer for tvOS
        let requiredSpaceTvOS = max(fileSize + tvOSBuffer, 1_000_000_000)

        if availableDiskSpace < requiredSpaceTvOS {
            throw CloudSyncError.insufficientSpace(required: requiredSpaceTvOS, available: availableDiskSpace)
        }
        #else
        if availableDiskSpace < requiredSpace {
            throw CloudSyncError.insufficientSpace(required: requiredSpace, available: availableDiskSpace)
        }
        #endif
    }

    /// Update available disk space
    private func updateDiskSpaceInternal() {
        do {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let resourceValues = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            availableDiskSpace = Int64(resourceValues.volumeAvailableCapacity ?? 0)
        } catch {
            ELOG("Failed to get available disk space: \(error)")
            availableDiskSpace = 0
        }
    }

    /// Update available disk space (public method)
    public func updateDiskSpace() {
        updateDiskSpaceInternal()
    }

    /// Update space requirements for queued downloads
    private func updateSpaceRequirements() {
        spaceRequiredForQueue = queuedDownloads.reduce(0) { $0 + $1.fileSize }
        totalBytesToDownload = queuedDownloads.reduce(0) { $0 + $1.fileSize } +
                              activeDownloads.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - Private Methods

    /// Setup throttling for progress updates to avoid UI jank
    private func setupProgressThrottling() {
        progressSubject
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] newProgress in
                self?.progress = newProgress
            }
            .store(in: &cancellables)
    }

    // MARK: - Deferred handling
    public func deferDownload(_ item: QueuedDownload) {
        if !deferredDownloads.contains(where: { $0.md5 == item.md5 }) {
            deferredDownloads.append(item)
        }
    }

    public func takeDeferred() -> [QueuedDownload] {
        let items = deferredDownloads
        deferredDownloads.removeAll()
        return items
    }
}
