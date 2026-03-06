// LibretroCheatEntry.swift
// LibretroCheatDB
//
// Model for cheat code entries returned from the libretro_cheats.sqlite database.

import Foundation

/// A cheat code entry from the libretro cheat database.
public struct LibretroCheatEntry: Sendable, Identifiable {
    /// Unique cheat ID from the database
    public let id: Int
    /// Human-readable name for the cheat (e.g. "Infinite Lives")
    public let cheatName: String
    /// The actual cheat code string
    public let cheatCode: String
    /// The cheat device name (e.g. "Action Replay", "Game Genie", "RetroArch")
    public let deviceName: String
    /// The game title this cheat is associated with
    public let gameTitle: String
    /// The system name (e.g. "Nintendo - Super Nintendo Entertainment System")
    public let systemName: String
    /// MD5 hash of the ROM file, if available from the libretro DAT database
    public let md5: String?

    public init(
        id: Int,
        cheatName: String,
        cheatCode: String,
        deviceName: String,
        gameTitle: String,
        systemName: String,
        md5: String? = nil
    ) {
        self.id = id
        self.cheatName = cheatName
        self.cheatCode = cheatCode
        self.deviceName = deviceName
        self.gameTitle = gameTitle
        self.systemName = systemName
        self.md5 = md5
    }
}
