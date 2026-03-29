//
//  LiveActivityManager.swift
//  PVLiveActivities
//
//  Central manager for the Provenance in-game Live Activity.
//
//  Usage from the host app:
//  ```swift
//  // Game starts
//  await LiveActivityManager.shared.startActivity(
//      gameTitle: game.title,
//      systemName: game.systemShortName ?? game.systemIdentifier,
//      gameMD5: game.md5Hash,
//      artworkPath: <relative path inside App Group container>
//  )
//
//  // Game paused
//  await LiveActivityManager.shared.setPaused(true)
//
//  // Achievement progress update
//  await LiveActivityManager.shared.updateAchievements(points: 120, total: 500)
//
//  // Autosave completed
//  await LiveActivityManager.shared.recordAutosave()
//
//  // Game stops
//  await LiveActivityManager.shared.endActivity()
//  ```
//
//  All public methods are no-ops on devices where ActivityKit is unavailable
//  (iOS < 16.2) or when the user has disabled Live Activities for the app.
//

#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

/// Manages the lifecycle of the Provenance in-game Live Activity.
///
/// The manager is a `Sendable` actor-like class using `@MainActor` isolation so
/// its state is always mutated on the main thread, which is where the emulator
/// view controller lifecycle callbacks fire.
// iOS 17+ deployment target guarantees ActivityKit (16.2+) availability.
@MainActor
public final class LiveActivityManager {

    // MARK: - Singleton

    public static let shared = LiveActivityManager()

    // MARK: - Private state

    /// The ID of the currently active `Activity<GameActivityAttributes>`, or `nil`.
    private var activityID: String?

    /// Snapshot of the most-recently pushed ContentState, used for incremental updates.
    private var currentState: GameActivityAttributes.ContentState = .init()

    /// Wall-clock time when the current activity was started (used for elapsed time).
    private var startDate: Date?

    private init() {}

    // MARK: - Public API

    /// Start a new Live Activity for the given game.
    ///
    /// If a Live Activity is already running (e.g. previous session was not cleaned up),
    /// it is ended first.
    ///
    /// - Parameters:
    ///   - gameTitle: Display title of the game.
    ///   - systemName: Short system name (e.g. "SNES").
    ///   - gameMD5: Unique MD5 hash identifying the game.
    ///   - artworkPath: Relative path inside the App Group container for box art. Pass `nil` when unavailable.
    public func startActivity(
        gameTitle: String,
        systemName: String,
        gameMD5: String,
        artworkPath: String?
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Tear down any lingering activity from a previous session.
        await endActivity()

        let attributes = GameActivityAttributes(
            gameTitle: gameTitle,
            systemName: systemName,
            gameMD5: gameMD5,
            artworkPath: artworkPath
        )
        let initialState = GameActivityAttributes.ContentState()

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
            activityID = activity.id
            currentState = initialState
            startDate = Date()
        } catch {
            // Live Activities are a non-critical UI enhancement.
            // Log the error but do not propagate — a missing Live Activity
            // must never affect emulation stability.
#if DEBUG
            print("[PVLiveActivities] Failed to start activity: \(error)")
#endif
        }
    }

    /// Set the paused state and push an immediate update.
    public func setPaused(_ paused: Bool) async {
        currentState.isPaused = paused
        currentState.elapsedSeconds = elapsedSeconds()
        await pushUpdate()
    }

    /// Record that an autosave completed and push an update.
    public func recordAutosave() async {
        currentState.lastSaveDate = Date()
        currentState.elapsedSeconds = elapsedSeconds()
        await pushUpdate()
    }

    /// Update RetroAchievements progress and push an update.
    ///
    /// - Parameters:
    ///   - points: Unlocked achievement points for this game.
    ///   - total: Maximum available points for this game.
    public func updateAchievements(points: Int, total: Int) async {
        currentState.achievementPoints = points
        currentState.achievementTotal = total
        currentState.elapsedSeconds = elapsedSeconds()
        await pushUpdate()
    }

    /// End the current Live Activity, removing it from the Dynamic Island and lock screen.
    ///
    /// Safe to call multiple times — subsequent calls are no-ops if no activity is running.
    public func endActivity() async {
        guard let id = activityID else { return }
        if let activity = Activity<GameActivityAttributes>.activities.first(where: { $0.id == id }) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activityID = nil
        currentState = .init()
        startDate = nil
    }

    // MARK: - Private helpers

    private func pushUpdate() async {
        guard let id = activityID,
              let activity = Activity<GameActivityAttributes>.activities.first(where: { $0.id == id }) else {
            return
        }
        await activity.update(ActivityContent(state: currentState, staleDate: nil))
    }

    private func elapsedSeconds() -> Int {
        guard let start = startDate else { return 0 }
        return max(0, Int(Date().timeIntervalSince(start)))
    }
}
#endif

// MARK: - No-op stubs for non-iOS/non-ActivityKit platforms

#if !(os(iOS) && canImport(ActivityKit))
/// Stub so call sites compile on tvOS, macOS, visionOS, and macCatalyst when
/// ActivityKit is unavailable. All methods are no-ops.
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()
    private init() {}
    public func startActivity(gameTitle: String, systemName: String, gameMD5: String, artworkPath: String?) async {}
    public func setPaused(_ paused: Bool) async {}
    public func recordAutosave() async {}
    public func updateAchievements(points: Int, total: Int) async {}
    public func endActivity() async {}
}
#endif
