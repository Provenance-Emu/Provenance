//
//  CloudKitRemoteApplyGuard.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 1/8/26.
//

import Foundation

/// Thread-safe guard used to prevent local change observers from re-enqueueing uploads
/// while CloudKit-originated changes are being applied to Realm.
public enum CloudKitRemoteApplyGuard {
    private static let lock = NSLock()
    private static var depth: Int = 0

    public static var isApplyingRemoteChanges: Bool {
        lock.withLock { depth > 0 }
    }

    @discardableResult
    public static func withApplyingRemoteChanges<T>(_ work: () throws -> T) rethrows -> T {
        lock.withLock { depth += 1 }
        defer { lock.withLock { depth = max(0, depth - 1) } }
        return try work()
    }
}
