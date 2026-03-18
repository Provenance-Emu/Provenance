//
//  PlayTimeTracker.swift
//  PVUI
//
//  Replaces the KVO-based GameplayDurationTrackerUtil protocol.
//  Swift-6-friendly, Combine-driven, idempotent play time tracking.
//

import Foundation
import PVLibrary
import PVRealm
import PVLogging

/// Tracks emulation session play time and persists it to Realm.
///
/// All methods run on the `@MainActor`.
///
/// ### Why this replaces KVO / `GameplayDurationTrackerUtil`
/// The old protocol used raw KVO on `core.isRunning`.  When `setPauseEmulation(false)`
/// was called twice in quick succession both observers fired before the main-queue async
/// flush had a chance to clear `gameStartTime`, producing the dreaded
/// "Didn't expect to get a KVO update of isRunning to true while we still have an
/// unflushed gameStartTime variable" error.
///
/// This class is idempotent by design:
/// - `didResume()` is a no-op when already tracking (duplicate start → ignored).
/// - `didPause()` is a no-op when not tracking (duplicate stop → ignored).
///
/// The Combine observer in `PVEmulatorViewController` further guards with
/// `.removeDuplicates()` so back-to-back `true→true` KVO values deliver only once.
@MainActor
final class PlayTimeTracker {

    // MARK: - State

    private var sessionStart: Date?
    private let game: PVGame

    // MARK: - Init

    init(game: PVGame) {
        self.game = game
    }

    // MARK: - Lifecycle

    /// Mark emulation as running. **Idempotent** — safe to call multiple times.
    func didResume() {
        guard sessionStart == nil else { return }
        sessionStart = Date()
        DLOG("PlayTimeTracker: session started for '\(game.title)'")
    }

    /// Mark emulation as paused or stopped. Persists elapsed time. **Idempotent**.
    func didPause() {
        guard let start = sessionStart else { return }
        sessionStart = nil
        guard !game.isInvalidated else { return }
        let elapsed = Int(-start.timeIntervalSinceNow)
        guard elapsed > 0 else { return }
        persistElapsed(elapsed)
    }

    // MARK: - Named convenience wrappers (preserve existing call-site names)

    /// Alias for `didPause()` — flushes elapsed time to `timeSpentInGame`.
    func updatePlayedDuration() { didPause() }

    /// Writes `lastPlayed = now` to Realm.
    func updateLastPlayedTime() {
        guard !game.isInvalidated else { return }
        ILOG("PlayTimeTracker: updating lastPlayed for '\(game.title)'")
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                self.game.realm?.refresh()
                self.game.lastPlayed = Date()
            }
        } catch {
            ELOG("PlayTimeTracker: lastPlayed update failed: \(error)")
        }
    }

    /// Resets `timeSpentInGame` to zero.
    func resetPlayedDuration() {
        guard !game.isInvalidated else { return }
        ILOG("PlayTimeTracker: resetting play time for '\(game.title)'")
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                self.game.realm?.refresh()
                self.game.timeSpentInGame = 0
            }
        } catch {
            ELOG("PlayTimeTracker: reset failed: \(error)")
        }
    }

    // MARK: - Private

    private func persistElapsed(_ seconds: Int) {
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                self.game.realm?.refresh()
                self.game.timeSpentInGame += seconds
                ILOG("PlayTimeTracker: +\(seconds)s → total \(self.game.timeSpentInGame)s for '\(self.game.title)'")
            }
        } catch {
            ELOG("PlayTimeTracker: failed to flush elapsed time: \(error)")
        }
    }
}
