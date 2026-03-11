//
//  BootstrapOrchestrator.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// Orchestrates app startup by resolving a dependency graph of ``BootstrapTask``
/// values and running independent tasks concurrently.
///
/// Usage:
/// ```swift
/// let orchestrator = BootstrapOrchestrator()
///     .with(LoggingBootstrapTask())
///     .with(FirebaseBootstrapTask())
/// await orchestrator.run()
/// ```
///
/// - Note: If any task throws, the error is logged but the orchestrator
///   continues with remaining tasks so the app always launches.
///   A failed task's provisions are **not** marked as satisfied, so any
///   tasks that depend on them will be skipped with a dependency error.
public final class BootstrapOrchestrator: Sendable {
    private let tasks: [any BootstrapTask]

    /// Maximum seconds a single task may run before it is considered stalled
    /// and skipped. Defaults to 30 seconds.
    public let taskTimeout: TimeInterval

    public init(tasks: [any BootstrapTask] = [], taskTimeout: TimeInterval = 30) {
        self.tasks = tasks
        self.taskTimeout = taskTimeout
    }

    /// Register tasks at call site for a fluent API.
    public func with(_ task: any BootstrapTask) -> BootstrapOrchestrator {
        BootstrapOrchestrator(tasks: tasks + [task], taskTimeout: taskTimeout)
    }

    /// Run all registered tasks in dependency order, executing independent
    /// tasks concurrently where possible.
    ///
    /// Uses a wave-based topological schedule: each "wave" collects tasks whose
    /// dependencies are already satisfied, runs them all concurrently, then
    /// marks their provisions as satisfied before processing the next wave.
    ///
    /// Each task is guarded by ``taskTimeout`` seconds. A stalled task is
    /// cancelled and logged as failed; its provisions are not marked satisfied
    /// so dependents are skipped rather than waiting forever.
    @MainActor
    public func run() async {
        var satisfied = Set<String>()
        var pending = tasks

        ILOG("BootstrapOrchestrator: Starting — \(tasks.count) task(s) registered (timeout: \(taskTimeout)s each)")

        while !pending.isEmpty {
            // Collect tasks whose dependencies are all satisfied.
            let ready = pending.filter { task in
                task.dependencies.allSatisfy { satisfied.contains($0) }
            }

            guard !ready.isEmpty else {
                // Unsatisfied cycle or missing provision — skip remaining tasks.
                let names = pending.map(\.name).joined(separator: ", ")
                ELOG("BootstrapOrchestrator: Dependency cycle or missing provision — skipping: \(names)")
                break
            }

            pending.removeAll { task in ready.contains(where: { $0.name == task.name }) }

            let timeout = taskTimeout
            // Execute the ready wave concurrently, each task guarded by a timeout.
            await withTaskGroup(of: (String, [String]).self) { group in
                for task in ready {
                    group.addTask {
                        ILOG("BootstrapOrchestrator: Starting '\(task.name)'")
                        do {
                            try await withBootstrapTaskTimeout(seconds: timeout) {
                                try await task.execute()
                            }
                            ILOG("BootstrapOrchestrator: Completed '\(task.name)'")
                            // Only return provisions on success so that dependents are
                            // not unblocked when a prerequisite task failed.
                            return (task.name, task.provisions)
                        } catch is BootstrapTaskTimeoutError {
                            ELOG("BootstrapOrchestrator: '\(task.name)' timed out after \(timeout)s — skipping")
                            return (task.name, [])
                        } catch {
                            ELOG("BootstrapOrchestrator: '\(task.name)' failed — \(error.localizedDescription)")
                            return (task.name, [])
                        }
                    }
                }

                for await (_, provisions) in group {
                    provisions.forEach { satisfied.insert($0) }
                }
            }
        }

        ILOG("BootstrapOrchestrator: All tasks completed")
    }
}

// MARK: - Per-task timeout helpers

private struct BootstrapTaskTimeoutError: Error {
    let seconds: TimeInterval
}

/// Runs `operation` and throws ``BootstrapTaskTimeoutError`` if it does not
/// complete within `seconds`. The stalled operation task is cancelled.
private func withBootstrapTaskTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw BootstrapTaskTimeoutError(seconds: seconds)
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
