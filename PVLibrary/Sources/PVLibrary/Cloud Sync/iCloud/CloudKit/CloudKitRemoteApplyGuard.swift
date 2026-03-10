//
//  CloudKitRemoteApplyGuard.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 1/8/26.
//

import Foundation
import os

/// Thread-safe guard used to prevent local change observers from re-enqueueing uploads
/// while CloudKit-originated changes are being applied to Realm.
///
/// Uses `OSAllocatedUnfairLock<Int>` (iOS 16+) to wrap the nesting depth counter
/// directly, eliminating separate state and providing deadlock-free `withLock` semantics.
public enum CloudKitRemoteApplyGuard {
    /// Nesting depth counter, protected by its own lock.
    /// Positive depth means remote changes are actively being applied.
    private static let _depth = OSAllocatedUnfairLock<Int>(initialState: 0)

    /// Returns `true` while CloudKit-originated changes are being applied.
    public static var isApplyingRemoteChanges: Bool {
        _depth.withLock { $0 > 0 }
    }

    /// Executes `work` within a remote-apply guard scope.
    ///
    /// Increments the depth counter before calling `work` and decrements it
    /// (clamped to zero) in a `defer` block, so the guard is always released
    /// even if `work` throws.
    ///
    /// - Parameter work: The closure to execute while the guard is active.
    /// - Returns: The value returned by `work`.
    @discardableResult
    public static func withApplyingRemoteChanges<T>(_ work: () throws -> T) rethrows -> T {
        _depth.withLock { $0 += 1 }
        defer { _depth.withLock { $0 = max(0, $0 - 1) } }
        return try work()
    }
}
