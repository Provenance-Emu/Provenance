// CheatDatabaseEntry.swift
// PVLibrary
//
// Model for cheat code entries returned from the bundled cheat database or an online source.

import Foundation

/// A cheat code entry retrieved from the bundled cheat database or an online source.
public struct CheatDatabaseEntry: Sendable, Identifiable {
    /// Unique cheat ID from the database
    public let id: Int
    /// Human-readable name for the cheat (e.g. "Infinite Lives")
    public let cheatName: String
    /// The actual cheat code string
    public let cheatCode: String
    /// Optional description of what the cheat does
    public let cheatDescription: String?
    /// The cheat device name (e.g. "GameShark", "Game Genie", "Action Replay")
    public let deviceName: String
    /// Device format description, if available
    public let deviceFormat: String?
    /// Cheat category (e.g. "Infinite", "Unlock", "Misc")
    public let category: String
    /// The ROM title this cheat is associated with
    public let romTitle: String
    /// The system name this cheat is for (e.g. "Nintendo - Super Nintendo Entertainment System").
    /// Only populated for entries from the libretro cheat database.
    public let systemName: String?
    /// Whether this entry was fetched from an online source rather than the bundled database.
    /// Online results should be shown with an indicator in the UI so users know they came from the internet.
    public let isOnlineResult: Bool

    public init(
        id: Int,
        cheatName: String,
        cheatCode: String,
        cheatDescription: String?,
        deviceName: String,
        deviceFormat: String?,
        category: String,
        romTitle: String,
        systemName: String? = nil,
        isOnlineResult: Bool = false
    ) {
        self.id = id
        self.cheatName = cheatName
        self.cheatCode = cheatCode
        self.cheatDescription = cheatDescription
        self.deviceName = deviceName
        self.deviceFormat = deviceFormat
        self.category = category
        self.romTitle = romTitle
        self.systemName = systemName
        self.isOnlineResult = isOnlineResult
    }
}
