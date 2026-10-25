import Foundation

/// Synchronizes the last queued-only cancellation against the worker's claim.
final class ImportQueueClaim: @unchecked Sendable {
    private enum State { case pending, processing, cancelled, finished }
    private let lock = NSLock()
    private var state: State = .pending

    func claim() -> Bool {
        lock.withLock {
            guard case .pending = state else { return false }
            state = .processing
            return true
        }
    }

    func cancelPending() -> Bool {
        lock.withLock {
            guard case .pending = state else { return false }
            state = .cancelled
            return true
        }
    }

    func finish() {
        lock.withLock {
            if case .processing = state { state = .finished }
        }
    }

    func resetForRetry() {
        lock.withLock {
            switch state {
            case .finished, .cancelled: state = .pending
            case .pending, .processing: break
            }
        }
    }
}
