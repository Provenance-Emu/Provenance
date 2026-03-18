//
//  NetplaySettings.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// User-configurable settings for a netplay session.
public struct NetplaySettings: Sendable {
    /// Frame delay before each input is sent. 0 = rollback only, >0 = delay frames.
    public var frameDelay: Int
    /// Maximum number of spectators allowed in the room (0–11 for RetroArch).
    public var maxSpectators: Int
    /// Whether spectators are allowed.
    public var allowSpectators: Bool
    /// Relay server hostname. nil = direct P2P; "ra.me" = RetroArch relay.
    public var relayServer: String?
    /// Optional room password (nil = open room).
    public var password: String?
    /// The room display name (e.g. "JoeMatt's Room").
    public var roomName: String
    /// Maximum number of players (1–8).
    public var maxPlayers: Int
    /// This device's player index (0-based; 0 = Player 1).
    public var playerIndex: Int
    /// Preferred local network port. 0 = OS-assigned.
    public var port: UInt16
    /// The device owner's display nickname shown to peers.
    public var nickname: String

    public init(
        frameDelay: Int = 0,
        maxSpectators: Int = 4,
        allowSpectators: Bool = true,
        relayServer: String? = nil,
        password: String? = nil,
        roomName: String = "",
        maxPlayers: Int = 2,
        playerIndex: Int = 0,
        port: UInt16 = 55435,
        nickname: String = ""
    ) {
        self.frameDelay = frameDelay
        self.maxSpectators = maxSpectators
        self.allowSpectators = allowSpectators
        self.relayServer = relayServer
        self.password = password
        self.roomName = roomName
        self.maxPlayers = maxPlayers
        self.playerIndex = playerIndex
        self.port = port
        self.nickname = nickname
    }

    /// Default settings suitable for most LAN sessions.
    public static let defaultLAN = NetplaySettings(
        frameDelay: 0,
        maxSpectators: 4,
        allowSpectators: true,
        relayServer: nil,
        maxPlayers: 2,
        port: 55435
    )

    /// Default settings for WAN play via RetroArch relay.
    public static let defaultWAN = NetplaySettings(
        frameDelay: 2,
        maxSpectators: 2,
        allowSpectators: true,
        relayServer: "ra.me",
        maxPlayers: 2,
        port: 55435
    )
}
