//
//  NetplaySession.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// An active netplay session (post-connect).
public struct NetplaySession: Identifiable, Sendable {
    public let id: UUID
    /// The room this session was created from
    public let room: NetplayRoom
    /// This device's role in the session
    public let role: NetplayRole
    /// Connected peers (excluding self)
    public let peers: [NetplayPeer]
    /// Time the session was established
    public let connectedAt: Date
    /// Current frame delay setting
    public let frameDelay: Int
    /// Whether rollback netplay is active
    public let isRollbackEnabled: Bool

    public init(
        id: UUID = UUID(),
        room: NetplayRoom,
        role: NetplayRole,
        peers: [NetplayPeer],
        connectedAt: Date = Date(),
        frameDelay: Int,
        isRollbackEnabled: Bool
    ) {
        self.id = id
        self.room = room
        self.role = role
        self.peers = peers
        self.connectedAt = connectedAt
        self.frameDelay = frameDelay
        self.isRollbackEnabled = isRollbackEnabled
    }

    /// Duration of the session
    public var duration: TimeInterval { Date().timeIntervalSince(connectedAt) }

    /// All players (including spectators)
    public var allParticipants: [NetplayPeer] { peers }
}

// MARK: - NetplayRole

/// The role of this device in a netplay session.
public enum NetplayRole: Sendable, Equatable {
    case host(port: UInt16)
    case client(host: String, port: UInt16)
    case spectator(host: String, port: UInt16)

    public var isHost: Bool {
        if case .host = self { return true }
        return false
    }

    public var isClient: Bool {
        if case .client = self { return true }
        return false
    }

    public var isSpectator: Bool {
        if case .spectator = self { return true }
        return false
    }
}

// MARK: - NetplayPeer

/// A connected remote peer in a netplay session.
public struct NetplayPeer: Identifiable, Sendable {
    public let id: UUID
    public let nickname: String
    public let playerIndex: Int
    public let pingMS: Int?
    public let isSpectator: Bool

    public init(
        id: UUID = UUID(),
        nickname: String,
        playerIndex: Int,
        pingMS: Int? = nil,
        isSpectator: Bool = false
    ) {
        self.id = id
        self.nickname = nickname
        self.playerIndex = playerIndex
        self.pingMS = pingMS
        self.isSpectator = isSpectator
    }

    public var pingDisplay: String {
        guard let ms = pingMS else { return "?" }
        return "\(ms)ms"
    }
}
