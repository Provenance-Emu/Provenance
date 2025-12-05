//
//  RealmActor.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import RealmSwift
import PVRealm

/// Convenience helpers for running Realm work safely on the main thread
public enum RealmContext {
    /// Runs the provided closure on the main thread with the shared Realm instance.
    /// Returns frozen objects that can be safely used on any thread.
    /// For async callers, use `await RealmContext.withRealm { ... }`
    @discardableResult
    public static func withRealm<T: Sendable>(
        _ operation: @escaping (Realm) throws -> T
    ) async throws -> T {
        try await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            return try operation(realm)
        }
    }

    /// Synchronous version for code already on @MainActor
    @discardableResult
    @MainActor
    public static func withRealmSync<T: Sendable>(
        _ operation: (Realm) throws -> T
    ) throws -> T {
        let realm = RomDatabase.sharedInstance.realm
        return try operation(realm)
    }
}

/// Legacy global actor - kept for compatibility but prefer using RealmContext.withRealm
@globalActor
public actor RealmActor: GlobalActor {
    public static let shared = RealmActor()

    fileprivate func perform<T: Sendable>(
        _ work: @escaping (Realm) throws -> T
    ) async throws -> T {
        try await RealmContext.withRealm(work)
    }
}
