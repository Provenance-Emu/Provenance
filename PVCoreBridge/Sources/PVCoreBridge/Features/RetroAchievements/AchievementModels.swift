//
//  AchievementModels.swift
//  PVCoreBridge
//
//  Data models shared between cores and the OSD/UI layer
//  for RetroAchievements events.
//

import Foundation

// MARK: - Memory Region

/// Describes a contiguous block of emulator memory exposed to the achievement runtime.
public struct AchievementMemoryRegion: Sendable {
    /// Category of memory, matching rcheevos `RC_MEMORY_TYPE_*` constants.
    public enum Kind: UInt8, Sendable {
        case systemRAM   = 0
        case savedRAM    = 1
        case videoRAM    = 2
        case unusedRAM   = 3
        case hardwareController = 4
        case readonly    = 5
        case unknown     = 255
    }

    /// Pointer to the base of the memory region (valid for the lifetime of the emulation session).
    public let base: UnsafeMutableRawPointer
    /// Size in bytes.
    public let size: Int
    /// Category of this region.
    public let kind: Kind

    public init(base: UnsafeMutableRawPointer, size: Int, kind: Kind) {
        self.base = base
        self.size = size
        self.kind = kind
    }
}

// MARK: - Notification models

/// Payload delivered when an achievement is unlocked.
public struct AchievementUnlockNotification: Sendable {
    public let id: UInt32
    public let title: String
    public let description: String
    public let points: UInt32
    /// URL for the achievement badge image (48×48 PNG on retroachievements.org).
    public let badgeURL: URL?
    /// True when unlocked in hardcore mode.
    public let isHardcore: Bool

    public init(id: UInt32, title: String, description: String, points: UInt32,
                badgeURL: URL?, isHardcore: Bool) {
        self.id = id
        self.title = title
        self.description = description
        self.points = points
        self.badgeURL = badgeURL
        self.isHardcore = isHardcore
    }
}

/// Payload delivered when measurable achievement progress changes.
public struct AchievementProgressNotification: Sendable {
    public let achievementID: UInt32
    public let title: String
    /// Human-readable progress string, e.g. "3/10".
    public let progressText: String

    public init(achievementID: UInt32, title: String, progressText: String) {
        self.achievementID = achievementID
        self.title = title
        self.progressText = progressText
    }
}

/// Payload for a challenge-indicator show/hide pair.
public struct AchievementChallengeNotification: Sendable {
    public let achievementID: UInt32
    public let badgeURL: URL?

    public init(achievementID: UInt32, badgeURL: URL?) {
        self.achievementID = achievementID
        self.badgeURL = badgeURL
    }
}

/// Payload for leaderboard events.
public struct AchievementLeaderboardNotification: Sendable {
    public let leaderboardID: UInt32
    public let title: String
    public let description: String
    /// Formatted score string, e.g. "01:23.45" or "9999".
    public let scoreText: String

    public init(leaderboardID: UInt32, title: String, description: String, scoreText: String) {
        self.leaderboardID = leaderboardID
        self.title = title
        self.description = description
        self.scoreText = scoreText
    }
}
