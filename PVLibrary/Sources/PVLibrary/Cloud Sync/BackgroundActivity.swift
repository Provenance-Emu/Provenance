//
//  BackgroundActivity.swift
//  PVLibrary
//
//  The Realm file lives in the shared App Group container. iOS kills an app
//  that is suspended while it holds a lock on a file there (RunningBoard
//  0xDEAD10CC), and a Realm commit holds one. Sync work that writes Realm and
//  can outlive the foreground runs inside `BackgroundActivity.run`, which keeps
//  the process from being suspended until the work returns or iOS revokes the
//  grant.
//
//  Uses `ProcessInfo.performExpiringActivity` rather than
//  `UIApplication.beginBackgroundTask` because PVLibrary is linked into app
//  extensions, where `UIApplication.shared` is unavailable.
//

import Foundation

public enum BackgroundActivity {
    /// Runs `work` while holding an expiring-activity assertion.
    ///
    /// - Parameters:
    ///   - reason: Shown in system diagnostics.
    ///   - onExpiration: Called when iOS is about to suspend the process.
    ///     Cancel the work here so it stops before starting another write.
    ///   - work: The work to protect.
    public static func run<T>(
        _ reason: String,
        onExpiration: @escaping @Sendable () -> Void = {},
        _ work: () async -> T
    ) async -> T {
        let assertion = Assertion()
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
            if expired {
                onExpiration()
                assertion.release()
            } else {
                // The activity lasts as long as this block runs.
                assertion.hold()
            }
        }
        defer { assertion.release() }
        return await work()
    }
}

private final class Assertion: @unchecked Sendable {
    private let released = DispatchSemaphore(value: 0)

    func hold() { released.wait() }

    /// Safe to call more than once: a surplus signal is never waited on.
    func release() { released.signal() }
}
