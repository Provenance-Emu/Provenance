//
//  CloudKitUploadQueueActor.swift
//  PVLibrary
//
//  Created by Cascade on 7/30/25.
//

import Foundation
import CloudKit
import Combine
import PVLogging
import PVSupport
import RealmSwift
import PVRealm

/// Actor-based upload queue for CloudKit ROM uploads to prevent blocking sync operations
@globalActor
public actor CloudKitUploadQueueActor {
    public static let shared = CloudKitUploadQueueActor()

    // MARK: - Types

    /// Upload task representing a CloudKit upload operation
    public struct UploadTask {
        let id: UUID
        let kind: UploadKind
        let title: String
        let priority: Priority
        let createdAt: Date

        public enum Priority: Int, Comparable {
            case low = 0
            case normal = 1
            case high = 2

            public static func < (lhs: Priority, rhs: Priority) -> Bool {
                return lhs.rawValue < rhs.rawValue
            }
        }
    }

    public enum UploadKind {
        case rom(md5: String, filePath: URL)
        case saveState(id: String)

        var identifier: String {
            switch self {
            case .rom(let md5, _):
                return "rom:\(md5)"
            case .saveState(let id):
                return "savestate:\(id)"
            }
        }
    }

    /// Upload status for tracking
    public enum UploadStatus {
        case queued
        case uploading
        case completed
        case failed(Error)
    }

    // MARK: - Properties

    private var uploadQueue: [UploadTask] = []
    private var activeUploads: [UUID: Task<Void, Never>] = [:]
    private var uploadStatuses: [UUID: UploadStatus] = [:]
    private let maxConcurrentUploads: Int = 2
    private var isProcessing = false

    /// When true, dequeue is suspended during an emulator UI session (same signal as `CloudSyncManager` `.emulation` pause). In-flight uploads may finish.
    private var emulatorSessionUploadsPaused = false

    // Progress tracking
    private let progressSubject = CurrentValueSubject<UploadProgress, Never>(UploadProgress())
    public nonisolated var progressPublisher: AnyPublisher<UploadProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    public struct UploadProgress {
        let queuedCount: Int
        let uploadingCount: Int
        let completedCount: Int
        let failedCount: Int
        let totalBytesUploaded: Int64

        init(queuedCount: Int = 0, uploadingCount: Int = 0, completedCount: Int = 0, failedCount: Int = 0, totalBytesUploaded: Int64 = 0) {
            self.queuedCount = queuedCount
            self.uploadingCount = uploadingCount
            self.completedCount = completedCount
            self.failedCount = failedCount
            self.totalBytesUploaded = totalBytesUploaded
        }
    }

    private init() {}

    // MARK: - Emulator session (BackgroundServiceRegistry / CloudSyncManager)

    /// Called from `CloudSyncManager.pause` / `resume` for `.emulation` so queued uploads align with other CloudKit I/O during gameplay.
    public func setEmulatorSessionUploadsPaused(_ paused: Bool) {
        let syncLog = CloudSyncManager.syncLog
        emulatorSessionUploadsPaused = paused
        if paused {
            syncLog.event(.upload, item: "queue/emulator-pause", status: .pending, detail: "deferring new uploads, in-flight may complete")
        } else {
            syncLog.event(.upload, item: "queue/emulator-resume", status: .inProgress, detail: "resuming upload processing")
            startProcessingIfNeeded()
        }
    }

    // MARK: - Public Interface

    /// Add a ROM upload task to the queue
    /// - Parameters:
    ///   - md5: ROM MD5 hash
    ///   - gameTitle: Game title for logging
    ///   - filePath: Path to ROM file
    ///   - priority: Upload priority
    /// - Returns: Task ID for tracking
    public func enqueueUpload(md5: String, gameTitle: String, filePath: URL, priority: UploadTask.Priority = .normal) -> UUID {
        let task = UploadTask(
            id: UUID(),
            kind: .rom(md5: md5, filePath: filePath),
            title: gameTitle,
            priority: priority,
            createdAt: Date()
        )

        uploadQueue.append(task)
        uploadStatuses[task.id] = .queued

        // Sort queue by priority (high to low) and creation time (oldest first)
        uploadQueue.sort { task1, task2 in
            if task1.priority != task2.priority {
                return task1.priority > task2.priority
            }
            return task1.createdAt < task2.createdAt
        }

        let syncLog = CloudSyncManager.syncLog
        syncLog.event(.upload, item: "rom/\(md5)", status: .pending, detail: "\(gameTitle) pri=\(priority) queue=\(uploadQueue.count)")

        updateProgress()
        startProcessingIfNeeded()

        return task.id
    }

    /// Queue a save-state upload with elevated priority.
    public func enqueueSaveStateUpload(saveStateID: String, gameTitle: String, priority: UploadTask.Priority = .high) -> UUID {
        let task = UploadTask(
            id: UUID(),
            kind: .saveState(id: saveStateID),
            title: gameTitle,
            priority: priority,
            createdAt: Date()
        )

        uploadQueue.append(task)
        uploadStatuses[task.id] = .queued

        uploadQueue.sort { task1, task2 in
            if task1.priority != task2.priority {
                return task1.priority > task2.priority
            }
            return task1.createdAt < task2.createdAt
        }

        let syncLog = CloudSyncManager.syncLog
        syncLog.event(.upload, item: "save/\(saveStateID)", status: .pending, detail: "\(gameTitle) pri=\(priority)")
        updateProgress()
        startProcessingIfNeeded()
        return task.id
    }

    /// Get current upload status for a task
    /// - Parameter taskId: Task ID
    /// - Returns: Current upload status
    public func getUploadStatus(taskId: UUID) -> UploadStatus? {
        return uploadStatuses[taskId]
    }

    /// Cancel a queued upload task
    /// - Parameter taskId: Task ID to cancel
    /// - Returns: True if task was cancelled, false if not found or already processing
    public func cancelUpload(taskId: UUID) -> Bool {
        // Cancel active upload if running
        if let activeTask = activeUploads[taskId] {
            activeTask.cancel()
            activeUploads.removeValue(forKey: taskId)
            uploadStatuses[taskId] = .failed(CancellationError())
            CloudSyncManager.syncLog.event(.upload, item: "task/\(taskId)", status: .cancelled, detail: "active upload cancelled")
            updateProgress()
            return true
        }

        // Remove from queue if not yet started
        if let index = uploadQueue.firstIndex(where: { $0.id == taskId }) {
            let task = uploadQueue.remove(at: index)
            uploadStatuses.removeValue(forKey: taskId)
            CloudSyncManager.syncLog.event(.upload, item: "task/\(task.title)", status: .cancelled, detail: "queued upload removed")
            updateProgress()
            return true
        }

        return false
    }

    /// Clear all queued uploads (does not cancel active uploads)
    public func clearQueue() {
        let queuedCount = uploadQueue.count
        uploadQueue.removeAll()

        // Remove statuses for queued items only
        uploadStatuses = uploadStatuses.filter { key, status in
            if case .queued = status {
                return false
            }
            return true
        }

        CloudSyncManager.syncLog.event(.delete, item: "queue/clear", status: .ok, detail: "\(queuedCount) tasks removed")
        updateProgress()
    }

    /// Get current queue statistics
    public func getQueueStats() -> (queued: Int, uploading: Int, completed: Int, failed: Int) {
        let queued = uploadQueue.count
        let uploading = activeUploads.count
        let completed = uploadStatuses.values.filter {
            if case .completed = $0 { return true }
            return false
        }.count
        let failed = uploadStatuses.values.filter {
            if case .failed = $0 { return true }
            return false
        }.count

        return (queued: queued, uploading: uploading, completed: completed, failed: failed)
    }

    // MARK: - Private Implementation

    private func startProcessingIfNeeded() {
        guard !emulatorSessionUploadsPaused else { return }
        guard !isProcessing else { return }
        guard !uploadQueue.isEmpty else { return }
        guard activeUploads.count < maxConcurrentUploads else { return }

        isProcessing = true

        Task {
            await processQueue()
            isProcessing = false
        }
    }

    private func processQueue() async {
        while !uploadQueue.isEmpty && activeUploads.count < maxConcurrentUploads {
            guard !emulatorSessionUploadsPaused else { break }
            let task = uploadQueue.removeFirst()

            uploadStatuses[task.id] = .uploading
            updateProgress()

            let syncLog = CloudSyncManager.syncLog
            switch task.kind {
            case .rom(let md5, _):
                syncLog.event(.upload, item: "rom/\(md5)", status: .inProgress, detail: task.title)
            case .saveState(let id):
                syncLog.event(.upload, item: "save/\(id)", status: .inProgress, detail: task.title)
            }

            let uploadTask = Task {
                await performUpload(task: task)
            }

            activeUploads[task.id] = uploadTask
        }

        // Continue processing when uploads complete
        if !uploadQueue.isEmpty && activeUploads.count < maxConcurrentUploads {
            startProcessingIfNeeded()
        }
    }

    private func performUpload(task: UploadTask) async {
        let syncLog = CloudSyncManager.syncLog
        do {
            switch task.kind {
            case .rom(let md5, let filePath):
                guard let romSyncer = CloudSyncManager.shared.romsSyncer as? CloudKitRomsSyncer else {
                    throw CloudSyncError.syncerNotAvailable
                }
                try await romSyncer.uploadGameFile(md5: md5, filePath: filePath)
                syncLog.event(.upload, item: "rom/\(md5)", status: .ok, detail: task.title)
            case .saveState(let saveStateID):
                guard let saveState = try? await RealmContext.withRealm({ realm in
                    realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateID)?.freeze()
                }) else {
                    throw CloudSyncError.gameNotFound("Save state \(saveStateID) not found locally")
                }
                try await CloudSyncManager.shared.uploadSaveState(for: saveState)
                syncLog.event(.upload, item: "save/\(saveStateID)", status: .ok, detail: task.title)
            }

            // Mark as completed
            uploadStatuses[task.id] = .completed
            activeUploads.removeValue(forKey: task.id)

        } catch {
            // Mark as failed
            uploadStatuses[task.id] = .failed(error)
            activeUploads.removeValue(forKey: task.id)

            let errorDetails = formatCloudKitUploadQueueError(error)
            let itemKey: String
            switch task.kind {
            case .rom(let md5, _): itemKey = "rom/\(md5)"
            case .saveState(let id): itemKey = "save/\(id)"
            }
            syncLog.event(.upload, item: itemKey, status: .failed, detail: "\(task.title) - \(errorDetails)")
        }

        updateProgress()

        // Continue processing queue
        startProcessingIfNeeded()
    }

    private func updateProgress() {
        let stats = getQueueStats()
        let totalBytes: Int64 = 0 // TODO: Track actual bytes uploaded if needed

        let progress = UploadProgress(
            queuedCount: stats.queued,
            uploadingCount: stats.uploading,
            completedCount: stats.completed,
            failedCount: stats.failed,
            totalBytesUploaded: totalBytes
        )

        progressSubject.send(progress)
    }
}

// MARK: - Upload error formatting

/// Formats upload failures for logging (file scope keeps `CloudKitUploadQueueActor` under SwiftLint type body limits).
private func formatCloudKitUploadQueueError(_ error: Error) -> String {
    if let cloudSyncError = error as? CloudSyncError {
        switch cloudSyncError {
        case .noUbiquityURL:
            return "No iCloud Drive URL available"
        case .notImplemented:
            return "Feature not implemented"
        case .invalidData:
            return "Invalid game data"
        case .missingDependency:
            return "Missing required dependency"
        case .cloudKitContainerUnavailable:
            return "CloudKit is not available (check iCloud / CloudKit entitlements and provisioning)"
        case .alreadyExists:
            return "Record already exists"
        case .cloudKitError(let underlyingError):
            if let ckError = underlyingError as? CKError {
                return "CloudKit error: \(ckError.localizedDescription) (code: \(ckError.code.rawValue)"
            }
            return "CloudKit error: \(underlyingError.localizedDescription)"
        case .fileSystemError(let underlyingError):
            return "File system error: \(underlyingError.localizedDescription)"
        case .zipError(let underlyingError):
            return "Zip error: \(underlyingError.localizedDescription)"
        case .realmError(let underlyingError):
            return "Realm error: \(underlyingError.localizedDescription)"
        case .unknown:
            return "Unknown error"
        case .recordNotFound:
            return "Record not found"
        case .genericError(let message):
            return "Generic error: \(message)"
        case .gameNotFound(let message):
            return "Game not found: \(message)"
        case .noAccount:
            return "No iCloud account configured"
        case .accountRestricted:
            return "iCloud account is restricted"
        case .accountStatusUnknown:
            return "Could not determine iCloud account status"
        case .accountTemporarilyUnavailable:
            return "iCloud account temporarily unavailable"
        case .insufficientSpace(let required, let available):
            let need = ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
            let have = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
            return "Insufficient space: need \(need), have \(have)"
        case .downloadCancelled:
            return "Download cancelled"
        case .downloadQueueFull:
            return "Download queue is full"
        case .assetTooLarge(let size, let maxSize):
            let sz = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let maxSz = ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)
            return "Asset too large: \(sz) > \(maxSz)"
        case .networkUnavailable:
            return "Network unavailable"
        case .pausedForEmulation:
            return "Paused for emulator session"
        }
    }

    let nsError = error as NSError
    var details = "\(error.localizedDescription)"
    if !nsError.domain.isEmpty && nsError.domain != "NSCocoaErrorDomain" {
        details += " (domain: \(nsError.domain), code: \(nsError.code))"
    }
    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
        details += " - Underlying: \(underlyingError.localizedDescription)"
    }
    return details
}

// MARK: - CloudSyncError Extension

extension CloudSyncError {
    static let syncerNotAvailable = CloudSyncError.genericError("ROM syncer not available")
}
