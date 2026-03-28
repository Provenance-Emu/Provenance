//
//  GameActivityAttributes.swift
//  PVLiveActivities
//
//  Defines the ActivityKit attributes for the Provenance in-game Live Activity.
//
//  Static attributes (GameActivityAttributes) describe the game being played and
//  do not change for the lifetime of the activity.  Mutable state
//  (GameActivityAttributes.ContentState) is updated whenever the game is paused,
//  resumed, an autosave completes, or a RetroAchievements progress event fires.
//
//  Platform guard: ActivityKit is iOS-only.  All types are wrapped in
//  `#if os(iOS)` so the module compiles cleanly on tvOS, macOS, and visionOS
//  without conditional imports at call sites.
//

#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

/// ActivityKit attributes for a Provenance gameplay session.
///
/// Register the activity with:
/// ```swift
/// let activity = try Activity.request(
///     attributes: GameActivityAttributes(...),
///     content: .init(state: initialState, staleDate: nil)
/// )
/// ```
///
/// The corresponding `ActivityConfiguration` in `ProvenanceWidgets` renders
/// the compact Dynamic Island pill, the expanded Dynamic Island panel, and
/// the lock-screen widget using these types.
///
/// iOS 17+ deployment target guarantees ActivityKit (16.2+) availability —
/// no `@available` guard is required.
public struct GameActivityAttributes: ActivityAttributes, Sendable {

    // MARK: - ContentState (mutable, updated during gameplay)

    /// The mutable portion of the Live Activity, updated via `Activity.update()`.
    public struct ContentState: Codable, Hashable, Sendable {
        /// Whether the emulator is currently paused.
        public var isPaused: Bool
        /// Total emulation time in seconds since the activity started.
        public var elapsedSeconds: Int
        /// Unlocked RetroAchievements points for this game session (nil if RA is not enabled).
        public var achievementPoints: Int?
        /// Maximum RA points available for this game (nil if RA is not enabled).
        public var achievementTotal: Int?
        /// Date of the last successful autosave (nil until the first save completes).
        public var lastSaveDate: Date?

        public init(
            isPaused: Bool = false,
            elapsedSeconds: Int = 0,
            achievementPoints: Int? = nil,
            achievementTotal: Int? = nil,
            lastSaveDate: Date? = nil
        ) {
            self.isPaused = isPaused
            self.elapsedSeconds = elapsedSeconds
            self.achievementPoints = achievementPoints
            self.achievementTotal = achievementTotal
            self.lastSaveDate = lastSaveDate
        }

        // MARK: Derived helpers (not stored)

        /// Returns `true` when RetroAchievements data is available to display.
        public var hasAchievements: Bool { achievementPoints != nil }

        /// Achievement progress fraction in [0, 1], or `nil` when not applicable.
        public var achievementFraction: Double? {
            guard let points = achievementPoints, let total = achievementTotal, total > 0 else { return nil }
            return Double(points) / Double(total)
        }

        /// Human-readable elapsed time string (e.g. "1h 23m" or "45m").
        public var elapsedTimeString: String {
            let hours = elapsedSeconds / 3600
            let minutes = (elapsedSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }
    }

    // MARK: - Static attributes (set at activity start, immutable)

    /// Display title of the game (e.g. "Super Mario World").
    public let gameTitle: String

    /// Short system name (e.g. "SNES", "GBA", "PSX").
    public let systemName: String

    /// MD5 hash used as the game identifier (matches `PVGame.md5Hash`).
    public let gameMD5: String

    /// Relative path inside the App Group container where box art is cached.
    /// Resolves to a local file URL the widget can render directly.
    /// `nil` when no artwork is available.
    public let artworkPath: String?

    public init(
        gameTitle: String,
        systemName: String,
        gameMD5: String,
        artworkPath: String? = nil
    ) {
        self.gameTitle = gameTitle
        self.systemName = systemName
        self.gameMD5 = gameMD5
        self.artworkPath = artworkPath
    }
}
#endif
