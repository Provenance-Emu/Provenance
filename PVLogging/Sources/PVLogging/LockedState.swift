//
//  LockedState.swift
//  PVLogging
//

import Foundation

/// A lock that owns the values it guards: they can only be reached through `withLock`,
/// so no read or write can skip the lock and no early exit can leave it held.
///
/// It is an `NSLock` underneath, because PVLogging also builds on Linux, where
/// `OSAllocatedUnfairLock` does not exist.
final class LockedState<State>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State

    init(_ state: State) {
        self.state = state
    }

    func withLock<Result>(_ body: (inout State) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&state)
    }
}
