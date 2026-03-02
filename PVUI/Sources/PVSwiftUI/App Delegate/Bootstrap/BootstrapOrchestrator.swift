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
/// orchestrator.register(LoggingBootstrapTask())
/// orchestrator.register(FirebaseBootstrapTask())
/// try await orchestrator.run()
/// ```
///
/// - Note: If any task throws, the error is logged but the orchestrator
///   continues with remaining tasks so the app always launches.
public final class BootstrapOrchestrator: Sendable {
    private let tasks: [any BootstrapTask]

    public init(tasks: [any BootstrapTask] = []) {
        self.tasks = tasks
    }

    /// Register tasks at call site for a fluent API.
    public func with(_ task: any BootstrapTask) -> BootstrapOrchestrator {
        BootstrapOrchestrator(tasks: tasks + [task])
    }

    /// Run all registered tasks in dependency order, executing independent
    /// tasks concurrently where possible.
    ///
    /// Uses a wave-based topological schedule: each "wave" collects tasks whose
    /// dependencies are already satisfied, runs them all concurrently, then
    /// marks their provisions as satisfied before processing the next wave.
    @MainActor
    public func run() async {
        var satisfied = Set<String>()
        var pending = tasks

        ILOG("BootstrapOrchestrator: Starting — \(tasks.count) task(s) registered")

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

            // Execute the ready wave concurrently.
            await withTaskGroup(of: (String, [String]).self) { group in
                for task in ready {
                    group.addTask {
                        ILOG("BootstrapOrchestrator: Starting '\(task.name)'")
                        do {
                            try await task.execute()
                            ILOG("BootstrapOrchestrator: Completed '\(task.name)'")
                        } catch {
                            ELOG("BootstrapOrchestrator: '\(task.name)' failed — \(error.localizedDescription)")
                        }
                        return (task.name, task.provisions)
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
