//
//  NetplayLaunchIntent.swift
//  PVNetplay
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// What to do once a game launched from the netplay lobby has booted.
public struct NetplayLaunchIntent: Sendable, Equatable {
    public enum Action: Sendable, Equatable {
        /// Join this room.
        case join(NetplayRoom)
        /// Open the room setup to host.
        case host
    }

    /// Lifetime of an intent. Long enough for a slow disc boot or a cloud
    /// download, short enough that an abandoned launch can't fire later.
    public static let lifetime: TimeInterval = 120

    public let action: Action
    /// Library MD5 of the game the intent is for.
    public let gameMD5: String
    public let createdAt: Date
    public let option: NetplayGameOption?
    public let password: String?

    public init(action: Action, gameMD5: String, createdAt: Date = Date(), option: NetplayGameOption? = nil, password: String? = nil) {
        self.action = action
        self.gameMD5 = gameMD5
        self.createdAt = createdAt
        self.option = option
        self.password = password
    }

    /// Whether this intent applies to the game `md5` at `now`.
    public func applies(toGameMD5 md5: String, at now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(createdAt)
        return gameMD5.caseInsensitiveCompare(md5) == .orderedSame
            && age >= 0 && age <= Self.lifetime
    }
}
