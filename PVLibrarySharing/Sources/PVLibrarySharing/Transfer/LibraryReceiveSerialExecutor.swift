import Foundation

/// One physical receive/import at a time. Cancelled work keeps its lease until
/// its delegate returns; queued cancellation never disturbs the current owner.
public actor LibraryReceiveSerialExecutor {
    public static let shared = LibraryReceiveSerialExecutor()
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }
    private var busy = false
    private var waiting: [Waiter] = []

    public init() {}

    public func withPermit<Value: Sendable>(
        _ body: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await acquire()
        defer { release() }
        try Task.checkCancellation()
        let result = try await body()
        try Task.checkCancellation()
        return result
    }

    private func acquire() async throws {
        try Task.checkCancellation()
        if !busy { busy = true; return }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                else { waiting.append(Waiter(id: id, continuation: continuation)) }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    private func cancel(_ id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        waiting.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    private func release() {
        if waiting.isEmpty { busy = false }
        else { waiting.removeFirst().continuation.resume() }
    }
}
