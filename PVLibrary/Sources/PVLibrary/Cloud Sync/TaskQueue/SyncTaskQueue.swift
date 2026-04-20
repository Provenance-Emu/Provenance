//
//  SyncTaskQueue.swift
//  PVLibrary
//
//  A priority-sorted, concurrency-limited queue for sync operations.
//  Each queue handles one category of work (artwork, ROM downloads, etc.)
//  with independent concurrency limits.
//

import Foundation
import PVLogging

/// A single priority-sorted task queue with configurable concurrency.
/// Tasks are dequeued highest-priority-first, with dependency resolution.
public actor SyncTaskQueue {

    // MARK: - Configuration

    public let name: String
    public let maxConcurrentTasks: Int
    public let defaultPriority: SyncTaskPriority
    public let maxRetries: Int

    // MARK: - State

    /// All non-terminal tasks, indexed by ID for O(1) lookup
    private var tasks: [UUID: SyncTask] = [:]

    /// IDs of tasks currently executing
    private var runningTaskIDs: Set<UUID> = []

    /// Running Swift Tasks for cancellation support
    private var runningSwiftTasks: [UUID: Task<Void, Never>] = [:]

    /// Whether the queue is paused (no new tasks will be dequeued)
    private var isPaused = false

    /// Continuation for the event stream
    private var eventContinuation: AsyncStream<SyncTaskEvent>.Continuation?

    /// The event stream for external observation
    public let events: AsyncStream<SyncTaskEvent>

    // MARK: - Stats

    public var pendingCount: Int { tasks.values.count { $0.state == .pending || $0.state == .ready } }
    public var runningCount: Int { runningTaskIDs.count }
    public var totalCount: Int { tasks.count }

    // MARK: - Init

    public init(
        name: String,
        maxConcurrentTasks: Int = 4,
        defaultPriority: SyncTaskPriority = .artworkRedownload,
        maxRetries: Int = 2
    ) {
        self.name = name
        self.maxConcurrentTasks = maxConcurrentTasks
        self.defaultPriority = defaultPriority
        self.maxRetries = maxRetries

        var continuation: AsyncStream<SyncTaskEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
    }

    deinit {
        eventContinuation?.finish()
    }

    // MARK: - Public API

    /// Add a task to the queue. Immediately attempts to dequeue if slots are available.
    @discardableResult
    public func enqueue(_ task: SyncTask) -> UUID {
        var task = task
        if task.dependencies.isEmpty && task.state == .pending {
            task.state = .ready
        }
        tasks[task.id] = task
        eventContinuation?.yield(.enqueued(taskID: task.id, kind: task.kind, priority: task.priority))
        DLOG("SyncTaskQueue[\(name)]: Enqueued \(task.kind) at priority \(task.priority) (total: \(tasks.count))")
        scheduleNext()
        return task.id
    }

    /// Convenience: create and enqueue a task in one call.
    @discardableResult
    public func submit(
        kind: SyncTaskKind,
        priority: SyncTaskPriority? = nil,
        dependencies: Set<UUID> = [],
        metadata: [String: String] = [:],
        work: @escaping @Sendable () async throws -> Void
    ) -> UUID {
        let task = SyncTask(
            kind: kind,
            priority: priority ?? defaultPriority,
            dependencies: dependencies,
            metadata: metadata,
            work: work
        )
        return enqueue(task)
    }

    /// Cancel a specific task. If running, the Swift Task is cancelled cooperatively.
    public func cancel(taskID: UUID) {
        guard var task = tasks[taskID], !task.state.isTerminal else { return }

        if runningTaskIDs.contains(taskID) {
            runningSwiftTasks[taskID]?.cancel()
            runningSwiftTasks.removeValue(forKey: taskID)
            runningTaskIDs.remove(taskID)
        }

        task.state = .cancelled
        tasks[taskID] = task
        eventContinuation?.yield(.cancelled(taskID: taskID))
        DLOG("SyncTaskQueue[\(name)]: Cancelled task \(taskID)")
        // Cancellation is terminal — release dependents so they can proceed.
        dependencyCompleted(taskID: taskID)
        scheduleNext()
    }

    /// Cancel all non-terminal tasks.
    public func cancelAll() {
        for id in tasks.keys {
            cancel(taskID: id)
        }
    }

    /// Change the priority of a pending/ready task.
    public func reprioritize(taskID: UUID, newPriority: SyncTaskPriority) {
        guard var task = tasks[taskID], !task.state.isTerminal else { return }
        let old = task.priority
        task.priority = newPriority
        tasks[taskID] = task
        eventContinuation?.yield(.reprioritized(taskID: taskID, oldPriority: old, newPriority: newPriority))
    }

    /// Pause the queue — no new tasks will start. In-flight tasks continue.
    public func pause() {
        isPaused = true
        DLOG("SyncTaskQueue[\(name)]: Paused")
    }

    /// Resume the queue and immediately try to fill available slots.
    public func resume() {
        isPaused = false
        DLOG("SyncTaskQueue[\(name)]: Resumed")
        scheduleNext()
    }

    /// Notify the queue that a dependency task has completed (may be from another queue).
    public func dependencyCompleted(taskID: UUID) {
        var changed = false
        for (id, var task) in tasks where task.state == .pending {
            if task.dependencies.remove(taskID) != nil {
                if task.dependencies.isEmpty {
                    task.state = .ready
                    tasks[id] = task
                    changed = true
                } else {
                    tasks[id] = task
                }
            }
        }
        if changed {
            scheduleNext()
        }
    }

    /// Remove all terminal tasks from memory.
    public func pruneCompleted() {
        tasks = tasks.filter { !$0.value.state.isTerminal }
    }

    /// Auto-prune when terminal tasks exceed this threshold.
    private let autoPruneThreshold = 100

    /// Remove terminal tasks if the dictionary has grown too large.
    private func autoPruneIfNeeded() {
        let terminalCount = tasks.values.count { $0.state.isTerminal }
        if terminalCount > autoPruneThreshold {
            pruneCompleted()
        }
    }

    /// Boost priority for all tasks matching a gameID.
    /// Returns the number of tasks boosted.
    @discardableResult
    public func boostPriority(forGameID gameID: String) -> Int {
        var count = 0
        for (id, var task) in tasks where !task.state.isTerminal {
            if task.metadata["gameID"] == gameID, !task.priority.isBoosted {
                let old = task.priority
                task.priority = task.priority.boosted()
                tasks[id] = task
                eventContinuation?.yield(.reprioritized(taskID: id, oldPriority: old, newPriority: task.priority))
                count += 1
            }
        }
        return count
    }

    /// Remove the on-demand boost for all tasks matching a gameID.
    @discardableResult
    public func resetBoost(forGameID gameID: String) -> Int {
        var count = 0
        for (id, var task) in tasks where !task.state.isTerminal {
            if task.metadata["gameID"] == gameID, task.priority.isBoosted {
                let old = task.priority
                task.priority = task.priority.unboosted()
                tasks[id] = task
                eventContinuation?.yield(.reprioritized(taskID: id, oldPriority: old, newPriority: task.priority))
                count += 1
            }
        }
        return count
    }

    // MARK: - Scheduling

    /// Try to fill available execution slots with the highest-priority ready tasks.
    private func scheduleNext() {
        guard !isPaused else { return }

        while runningTaskIDs.count < maxConcurrentTasks {
            guard let nextID = pickNextReady() else { break }
            execute(taskID: nextID)
        }
    }

    /// Find the highest-priority .ready task.
    private func pickNextReady() -> UUID? {
        tasks.values
            .filter { $0.state == .ready }
            .max(by: { $0.priority < $1.priority })?.id
    }

    /// Start executing a task.
    private func execute(taskID: UUID) {
        guard var task = tasks[taskID] else { return }
        task.state = .running
        tasks[taskID] = task
        runningTaskIDs.insert(taskID)
        eventContinuation?.yield(.started(taskID: taskID))

        let work = task.work
        let swiftTask = Task { [weak self] in
            do {
                try await work()
                await self?.taskDidComplete(taskID: taskID)
            } catch is CancellationError {
                await self?.taskDidCancel(taskID: taskID)
            } catch {
                await self?.taskDidFail(taskID: taskID, error: error)
            }
        }
        runningSwiftTasks[taskID] = swiftTask
    }

    // MARK: - Completion handlers

    private func taskDidComplete(taskID: UUID) {
        guard var task = tasks[taskID] else { return }
        task.state = .completed
        tasks[taskID] = task
        runningTaskIDs.remove(taskID)
        runningSwiftTasks.removeValue(forKey: taskID)
        eventContinuation?.yield(.completed(taskID: taskID))
        DLOG("SyncTaskQueue[\(name)]: Completed \(task.kind)")
        // Resolve intra-queue dependencies so pending tasks that depended
        // on this one can transition to .ready.
        dependencyCompleted(taskID: taskID)
        autoPruneIfNeeded()
        scheduleNext()
    }

    private func taskDidFail(taskID: UUID, error: Error) {
        guard var task = tasks[taskID] else { return }
        runningTaskIDs.remove(taskID)
        runningSwiftTasks.removeValue(forKey: taskID)

        if task.retryCount < maxRetries {
            task.retryCount += 1
            task.state = .ready
            tasks[taskID] = task
            DLOG("SyncTaskQueue[\(name)]: Retrying \(task.kind) (attempt \(task.retryCount)/\(maxRetries))")
            scheduleNext()
        } else {
            task.state = .failed(error.localizedDescription)
            tasks[taskID] = task
            eventContinuation?.yield(.failed(taskID: taskID, error: error.localizedDescription))
            ELOG("SyncTaskQueue[\(name)]: Failed \(task.kind) after \(maxRetries) retries: \(error)")
            // A terminal failure must unblock dependents — otherwise a single
            // failed prerequisite (e.g. ROM metadata fetch) permanently strands
            // every downstream task (skins, save states, artwork triage).
            dependencyCompleted(taskID: taskID)
            scheduleNext()
        }
    }

    private func taskDidCancel(taskID: UUID) {
        guard var task = tasks[taskID] else { return }
        task.state = .cancelled
        tasks[taskID] = task
        runningTaskIDs.remove(taskID)
        runningSwiftTasks.removeValue(forKey: taskID)
        eventContinuation?.yield(.cancelled(taskID: taskID))
        // Cancellation is terminal — release dependents so they can proceed.
        dependencyCompleted(taskID: taskID)
        scheduleNext()
    }
}
