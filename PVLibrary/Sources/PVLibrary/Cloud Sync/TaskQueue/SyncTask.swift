//
//  SyncTask.swift
//  PVLibrary
//
//  A single unit of sync work with priority, dependencies, and lifecycle state.
//

import Foundation

/// The kind of sync work to perform, with associated context.
public enum SyncTaskKind: Sendable, Hashable {
    /// Sync ROM metadata from CloudKit (fast, no file downloads)
    case metadataSync

    /// Re-download artwork from a known HTTP URL
    case artworkDownload(url: URL, gameID: String)

    /// Sync a save state screenshot
    case saveStateScreenshot(stateID: String)

    /// Sync a BIOS file
    case biosDownload(filename: String, systemID: String)

    /// Download a ROM file from CloudKit
    case romDownload(md5: String, expectedSize: Int64?)

    /// Run a database artwork lookup (OpenVGDB, LibretroDB, TheGamesDB)
    case dbArtworkLookup(gameID: String, title: String, systemID: String?)

    /// Upload a file to CloudKit
    case upload(relativePath: String, directory: String)

    /// A custom task with a description
    case custom(description: String)
}

/// Lifecycle state of a sync task.
public enum SyncTaskState: Sendable, Hashable {
    /// Waiting for dependencies to complete
    case pending
    /// All dependencies met, eligible for execution
    case ready
    /// Currently executing
    case running
    /// Paused (can resume)
    case paused
    /// Completed successfully
    case completed
    /// Failed with an error description
    case failed(String)
    /// Cancelled before or during execution
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        default: return false
        }
    }
}

/// A single unit of sync work.
public struct SyncTask: Identifiable, Sendable {
    public let id: UUID
    public let kind: SyncTaskKind
    public var priority: SyncTaskPriority
    public let createdAt: Date
    /// IDs of tasks that must complete before this task can run.
    public var dependencies: Set<UUID>
    public var state: SyncTaskState
    public var retryCount: Int
    /// Arbitrary context for matching (e.g., gameID for priority boosting)
    public var metadata: [String: String]

    /// The closure that performs the actual work.
    /// Stored as an unchecked sendable wrapper since closures can't be Sendable.
    let work: @Sendable () async throws -> Void

    public init(
        id: UUID = UUID(),
        kind: SyncTaskKind,
        priority: SyncTaskPriority,
        dependencies: Set<UUID> = [],
        metadata: [String: String] = [:],
        work: @escaping @Sendable () async throws -> Void
    ) {
        self.id = id
        self.kind = kind
        self.priority = priority
        self.createdAt = Date()
        self.dependencies = dependencies
        self.state = dependencies.isEmpty ? .ready : .pending
        self.retryCount = 0
        self.metadata = metadata
        self.work = work
    }
}

// MARK: - Hashable/Equatable by ID

extension SyncTask: Hashable {
    public static func == (lhs: SyncTask, rhs: SyncTask) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Events emitted by a SyncTaskQueue for observation.
public enum SyncTaskEvent: Sendable {
    case enqueued(taskID: UUID, kind: SyncTaskKind, priority: SyncTaskPriority)
    case started(taskID: UUID)
    case completed(taskID: UUID)
    case failed(taskID: UUID, error: String)
    case cancelled(taskID: UUID)
    case reprioritized(taskID: UUID, oldPriority: SyncTaskPriority, newPriority: SyncTaskPriority)
    case paused(taskID: UUID)
    case resumed(taskID: UUID)
}
