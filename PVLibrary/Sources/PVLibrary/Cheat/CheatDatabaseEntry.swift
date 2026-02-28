// CheatDatabaseEntry.swift
// PVLibrary
//
// Model for cheat code entries returned from the local cheatbase.sqlite database.

import Foundation

/// A cheat code entry retrieved from the local cheatbase database.
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

    public init(
        id: Int,
        cheatName: String,
        cheatCode: String,
        cheatDescription: String?,
        deviceName: String,
        deviceFormat: String?,
        category: String,
        romTitle: String
    ) {
        self.id = id
        self.cheatName = cheatName
        self.cheatCode = cheatCode
        self.cheatDescription = cheatDescription
        self.deviceName = deviceName
        self.deviceFormat = deviceFormat
        self.category = category
        self.romTitle = romTitle
    }
}
