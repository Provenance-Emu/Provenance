//
//  SyncTaskQueueCoordinator.swift
//  PVLibrary
//
//  The "queue of queues" — owns all category-specific SyncTaskQueues and
//  provides cross-queue orchestration: global concurrency budget, phase gating,
//  priority boosting, and task dependency resolution across queues.
//

import Foundation
import PVLogging

/// Category tags for the predefined queues.
public enum SyncQueueCategory: String, CaseIterable, Sendable {
    case metadata
    case artwork
    case saveState
    case bios
    case romDownload
    case dbLookup
    case upload
}

/// Coordinates multiple SyncTaskQueues with global concurrency budgeting,
/// cross-queue dependency resolution, and priority boosting.
public actor SyncTaskQueueCoordinator {

    /// Shared singleton. Created lazily on first access.
    public static let shared = SyncTaskQueueCoordinator()

    // MARK: - Queues

    /// All managed queues, keyed by category
    private var queues: [SyncQueueCategory: SyncTaskQueue] = [:]

    /// Global concurrency limit across all queues combined.
    /// 0 means no global limit (each queue uses its own maxConcurrentTasks independently).
    public let globalMaxConcurrent: Int

    /// Whether all queues are paused
    private var isPaused = false

    /// Cross-queue dependency tracking: taskID → set of queue categories that have the dependency
    private var crossQueueDependencies: [UUID: Set<SyncQueueCategory>] = [:]

    /// Event listeners for cross-queue observation
    private var eventListenerTasks: [SyncQueueCategory: Task<Void, Never>] = [:]

    // MARK: - Init

    public init(globalMaxConcurrent: Int = 8) {
        self.globalMaxConcurrent = globalMaxConcurrent

        // Create the predefined queues with appropriate concurrency limits
        let queueConfigs: [(SyncQueueCategory, Int, SyncTaskPriority, Int)] = [
            (.metadata, 1, .metadataSync, 1),
            (.artwork, 6, .artworkRedownload, 2),
            (.saveState, 2, .saveStateScreenshot, 2),
            (.bios, 1, .biosSync, 1),
            (.romDownload, 2, .romDownload, 2),
            (.dbLookup, 1, .dbArtworkLookup, 0),
            (.upload, 3, .romDownload, 1)
        ]

        for (category, maxConcurrent, defaultPriority, maxRetries) in queueConfigs {
            queues[category] = SyncTaskQueue(
                name: category.rawValue,
                maxConcurrentTasks: maxConcurrent,
                defaultPriority: defaultPriority,
                maxRetries: maxRetries
            )
        }
    }

    // MARK: - Public API: Submit

    /// Submit a task to a specific queue.
    @discardableResult
    public func submit(
        to category: SyncQueueCategory,
        kind: SyncTaskKind,
        priority: SyncTaskPriority? = nil,
        dependencies: Set<UUID> = [],
        metadata: [String: String] = [:],
        work: @escaping @Sendable () async throws -> Void
    ) async -> UUID? {
        guard let queue = queues[category] else {
            ELOG("SyncTaskQueueCoordinator: No queue for category \(category)")
            return nil
        }

        let defaultPriority = await queue.defaultPriority
        let task = SyncTask(
            kind: kind,
            priority: priority ?? defaultPriority,
            dependencies: dependencies,
            metadata: metadata,
            work: work
        )

        // Track cross-queue dependencies
        for depID in dependencies {
            crossQueueDependencies[depID, default: []].insert(category)
        }

        return await queue.enqueue(task)
    }

    /// Submit a task that should run after another task completes (possibly in a different queue).
    @discardableResult
    public func submitChained(
        to category: SyncQueueCategory,
        after prerequisiteID: UUID,
        kind: SyncTaskKind,
        priority: SyncTaskPriority? = nil,
        metadata: [String: String] = [:],
        work: @escaping @Sendable () async throws -> Void
    ) async -> UUID? {
        await submit(
            to: category,
            kind: kind,
            priority: priority,
            dependencies: [prerequisiteID],
            metadata: metadata,
            work: work
        )
    }

    // MARK: - Public API: Queue Access

    /// Get a specific queue for direct manipulation.
    public func queue(for category: SyncQueueCategory) -> SyncTaskQueue? {
        queues[category]
    }

    // MARK: - Public API: Priority Boosting

    /// Boost priority for all tasks related to a game across all queues.
    /// Call when a game cell becomes visible in the UI.
    public func boostPriority(forGameID gameID: String) async {
        var totalBoosted = 0
        for (_, queue) in queues {
            totalBoosted += await queue.boostPriority(forGameID: gameID)
        }
        if totalBoosted > 0 {
            DLOG("SyncTaskQueueCoordinator: Boosted \(totalBoosted) tasks for game \(gameID)")
        }
    }

    /// Reset the boost for all tasks related to a game.
    /// Call when a game cell scrolls off-screen.
    public func resetBoost(forGameID gameID: String) async {
        for (_, queue) in queues {
            await queue.resetBoost(forGameID: gameID)
        }
    }

    // MARK: - Public API: Pause/Resume/Cancel

    /// Pause all queues. In-flight tasks continue but no new tasks start.
    public func pauseAll() async {
        isPaused = true
        for (_, queue) in queues {
            await queue.pause()
        }
        DLOG("SyncTaskQueueCoordinator: All queues paused")
    }

    /// Resume all queues.
    public func resumeAll() async {
        isPaused = false
        for (_, queue) in queues {
            await queue.resume()
        }
        DLOG("SyncTaskQueueCoordinator: All queues resumed")
    }

    /// Cancel all tasks in all queues.
    public func cancelAll() async {
        for (_, queue) in queues {
            await queue.cancelAll()
        }
        crossQueueDependencies.removeAll()
        DLOG("SyncTaskQueueCoordinator: All tasks cancelled")
    }

    /// Cancel all tasks in a specific queue.
    public func cancelQueue(_ category: SyncQueueCategory) async {
        await queues[category]?.cancelAll()
    }

    /// Pause a specific queue.
    public func pause(_ category: SyncQueueCategory) async {
        await queues[category]?.pause()
    }

    /// Resume a specific queue.
    public func resume(_ category: SyncQueueCategory) async {
        await queues[category]?.resume()
    }

    // MARK: - Cross-Queue Dependency Resolution

    /// Called when a task reaches a terminal state (completed, failed, or
    /// cancelled) to notify dependent tasks in other queues.
    ///
    /// Failure and cancellation are treated the same as completion for
    /// dependency resolution — a terminal prerequisite must never strand
    /// downstream work, regardless of outcome.
    public func taskFinalized(taskID: UUID) async {
        guard let dependentCategories = crossQueueDependencies.removeValue(forKey: taskID) else { return }

        for category in dependentCategories {
            await queues[category]?.dependencyCompleted(taskID: taskID)
        }
    }

    /// Back-compat alias — prefer ``taskFinalized(taskID:)``.
    public func taskCompleted(taskID: UUID) async {
        await taskFinalized(taskID: taskID)
    }

    // MARK: - Monitoring

    /// Start listening to events from all queues for cross-queue dependency resolution.
    /// Call once after initialization.
    public func startEventListeners() {
        for (category, queue) in queues {
            let events = queue.events
            eventListenerTasks[category] = Task { [weak self] in
                for await event in events {
                    guard let self else { break }
                    switch event {
                    case .completed(let taskID),
                         .cancelled(let taskID):
                        await self.taskFinalized(taskID: taskID)
                    case .failed(let taskID, _):
                        await self.taskFinalized(taskID: taskID)
                    case .enqueued, .started, .reprioritized, .paused, .resumed:
                        break
                    }
                }
            }
        }
    }

    /// Stop all event listeners.
    public func stopEventListeners() {
        for (_, task) in eventListenerTasks {
            task.cancel()
        }
        eventListenerTasks.removeAll()
    }

    // MARK: - Stats

    /// Get a snapshot of all queue stats.
    public func stats() async -> [(category: SyncQueueCategory, pending: Int, running: Int, total: Int)] {
        var result: [(category: SyncQueueCategory, pending: Int, running: Int, total: Int)] = []
        for category in SyncQueueCategory.allCases {
            guard let queue = queues[category] else { continue }
            let pending = await queue.pendingCount
            let running = await queue.runningCount
            let total = await queue.totalCount
            result.append((category: category, pending: pending, running: running, total: total))
        }
        return result
    }
}
