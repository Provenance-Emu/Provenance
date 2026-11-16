import Foundation
import os

/// Releases the importer at the deadline even when a provider ignores cancellation.
/// A task group cannot implement this contract: its scope waits for every child.
enum ArtworkLookupDeadline {
    static func value(
        timeoutNanoseconds: UInt64,
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) },
        operation: @escaping @Sendable () async -> String?
    ) async -> String? {
        let race = Race()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                race.install(continuation)
                race.add(Task {
                    guard !Task.isCancelled else { return }
                    race.finish(await operation())
                })
                race.add(Task.detached {
                    do {
                        try await sleep(timeoutNanoseconds)
                        race.finish(nil)
                    } catch {
                        // The lookup finished or its caller was cancelled.
                    }
                })
            }
        } onCancel: {
            race.finish(nil)
        }
    }

    private final class Race: Sendable {
        /// Lives inside the lock that guards it.
        private struct State: Sendable {
            var continuation: CheckedContinuation<String?, Never>?
            var tasks: [Task<Void, Never>] = []
            var finished = false
            var result: String?
        }

        private let state = OSAllocatedUnfairLock(initialState: State())

        func install(_ continuation: CheckedContinuation<String?, Never>) {
            let outcome = state.withLock { state -> (finished: Bool, value: String?) in
                if !state.finished { state.continuation = continuation }
                return (state.finished, state.result)
            }
            // Resumed after the lock is released.
            if outcome.finished { continuation.resume(returning: outcome.value) }
        }

        func add(_ task: Task<Void, Never>) {
            let alreadyFinished = state.withLock { state -> Bool in
                if !state.finished { state.tasks.append(task) }
                return state.finished
            }
            if alreadyFinished { task.cancel() }
        }

        func finish(_ value: String?) {
            let pending = state.withLock { state -> (waiter: CheckedContinuation<String?, Never>?, workers: [Task<Void, Never>])? in
                guard !state.finished else { return nil }
                state.finished = true
                state.result = value
                let pending = (state.continuation, state.tasks)
                state.continuation = nil
                state.tasks.removeAll()
                return pending
            }
            // The first finish wins; the waiter and workers are released outside the lock.
            guard let pending else { return }
            pending.waiter?.resume(returning: value)
            for task in pending.workers { task.cancel() }
        }
    }
}
