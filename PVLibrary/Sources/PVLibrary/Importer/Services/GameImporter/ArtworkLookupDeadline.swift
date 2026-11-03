import Foundation

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

    private final class Race: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<String?, Never>?
        private var tasks: [Task<Void, Never>] = []
        private var finished = false
        private var result: String?

        func install(_ continuation: CheckedContinuation<String?, Never>) {
            lock.lock()
            let alreadyFinished = finished
            let value = result
            if !alreadyFinished { self.continuation = continuation }
            lock.unlock()
            if alreadyFinished { continuation.resume(returning: value) }
        }

        func add(_ task: Task<Void, Never>) {
            lock.lock()
            let alreadyFinished = finished
            if !alreadyFinished { tasks.append(task) }
            lock.unlock()
            if alreadyFinished { task.cancel() }
        }

        func finish(_ value: String?) {
            lock.lock()
            guard !finished else {
                lock.unlock()
                return
            }
            finished = true
            result = value
            let waiter = continuation
            continuation = nil
            let workers = tasks
            tasks.removeAll()
            lock.unlock()
            waiter?.resume(returning: value)
            for task in workers { task.cancel() }
        }
    }
}
