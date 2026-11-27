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

    /// Runs synchronous `work` while the process holds an expiring-activity assertion.
    ///
    /// Overlapping calls share one assertion, so many concurrent Realm jobs park one
    /// thread between them, not one each. The work always runs, with or without the
    /// grant; use `runSyncRequiringGrant` for work that can be put off.
    public static func runSync<T>(_ reason: String, _ work: () throws -> T) rethrows -> T {
        shared.begin(reason)
        defer { shared.end() }
        return try work()
    }

    /// Like `runSync`, but throws `BackgroundActivityError.notGranted` without running
    /// `work` when iOS refuses the assertion or has already revoked it: the process
    /// is about to be suspended, and a Realm commit caught by that is a 0xDEAD10CC kill.
    public static func runSyncRequiringGrant<T>(_ reason: String, _ work: () throws -> T) throws -> T {
        guard shared.begin(reason, waitForGrant: true) else {
            throw BackgroundActivityError.notGranted
        }
        defer { shared.end() }
        return try work()
    }

    private static let shared = SharedAssertion()
}

public enum BackgroundActivityError: Error, Equatable {
    /// iOS would not keep the process awake for the work, so it was not started.
    case notGranted
}

/// One expiring activity held for as long as any `runSync` caller is working.
///
/// When iOS revokes the activity the assertion is **not** released at once: the
/// process is suspended as soon as the activity's block returns, and a commit still
/// running then is killed. It is released when the last caller finishes.
final class SharedAssertion: @unchecked Sendable {
    typealias Requester = @Sendable (_ reason: String, _ block: @escaping @Sendable (_ expired: Bool) -> Void) -> Void

    /// How long a caller waits for iOS to answer the request. The answer normally
    /// arrives within a millisecond; an unanswered request is treated as granted.
    static let defaultGrantTimeout: TimeInterval = 1

    private let request: Requester
    private let grantTimeout: TimeInterval
    private let lock = NSLock()
    private var users = 0
    private var assertion: Assertion?

    init(
        grantTimeout: TimeInterval = SharedAssertion.defaultGrantTimeout,
        request: @escaping Requester = { reason, block in
            ProcessInfo.processInfo.performExpiringActivity(withReason: reason, using: block)
        }
    ) {
        self.grantTimeout = grantTimeout
        self.request = request
    }

    /// Joins the shared activity, requesting it for the first caller.
    /// - Returns: `false`, having left again, when `waitForGrant` is set and iOS
    ///   refused or revoked the activity. Otherwise `true`: pair it with `end()`.
    @discardableResult
    func begin(_ reason: String, waitForGrant: Bool = false) -> Bool {
        lock.lock()
        users += 1
        let assertion: Assertion
        if let current = self.assertion {
            assertion = current
        } else {
            assertion = Assertion()
            self.assertion = assertion
            request(reason) { expired in
                if expired {
                    assertion.revoke()
                } else {
                    assertion.hold()
                }
            }
        }
        lock.unlock()

        guard waitForGrant, assertion.waitForAnswer(timeout: grantTimeout) == .revoked else { return true }
        end()
        return false
    }

    func end() {
        lock.lock()
        defer { lock.unlock() }
        users -= 1
        guard users == 0 else { return }
        assertion?.release()
        assertion = nil
    }
}

private final class Assertion: @unchecked Sendable {
    enum Answer { case pending, granted, revoked }

    private let released = DispatchSemaphore(value: 0)
    private let condition = NSCondition()
    private var answer = Answer.pending

    /// Called from the activity's block: parks its thread, which is what keeps the
    /// process awake, until `release()`.
    func hold() {
        setAnswer(.granted)
        released.wait()
    }

    /// iOS refused the activity or is taking it back. Does not release it.
    func revoke() { setAnswer(.revoked) }

    /// Safe to call more than once: a surplus signal is never waited on.
    func release() { released.signal() }

    /// The current answer, waiting up to `timeout` while there is none.
    func waitForAnswer(timeout: TimeInterval) -> Answer {
        let deadline = Date(timeIntervalSinceNow: timeout)
        condition.lock()
        defer { condition.unlock() }
        while answer == .pending {
            guard condition.wait(until: deadline) else { break }
        }
        return answer
    }

    private func setAnswer(_ new: Answer) {
        condition.lock()
        // A revocation is final; a late "granted" must not undo it.
        if answer != .revoked { answer = new }
        condition.broadcast()
        condition.unlock()
    }
}
