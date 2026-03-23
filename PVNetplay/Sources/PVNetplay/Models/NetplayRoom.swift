//
//  NetplayRoom.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Represents a discoverable netplay room hosted by a peer.
public struct NetplayRoom: Identifiable, Sendable, Hashable {
    /// Unique session identifier
    public let id: UUID
    /// Display name of the host
    public let hostName: String
    /// Name of the game being played
    public let gameName: String
    /// MD5 hash of the ROM for identity verification (never transferred)
    public let gameHash: String
    /// Core identifier (e.g., "com.provenance.snes9x")
    public let coreIdentifier: String
    /// Maximum number of connected players
    public let maxPlayers: Int
    /// Current number of connected players
    public let currentPlayers: Int
    /// Round-trip latency in milliseconds (nil if unknown)
    public let pingMS: Int?
    /// Whether this room was discovered on the local network
    public let isLAN: Bool
    /// Host IP address or hostname
    public let hostAddress: String
    /// Netplay port (RetroArch default: 55435)
    public let port: UInt16
    /// Dolphin relay traversal code (non-nil when the host used STUN/traversal relay).
    ///
    /// When this is non-nil, `hostAddress` is set to the same traversal code value
    /// so that existing consumers that only read `hostAddress` can still connect via
    /// the relay.  Consumers that want to distinguish relay sessions from direct-IP
    /// sessions should check `traversalCode != nil` (or equivalently `isLAN == false`).
    public let traversalCode: String?
    /// Whether the room is password-protected
    public let isPasswordProtected: Bool
    /// Whether the room accepts spectators
    public let allowsSpectators: Bool
    /// Current number of spectators
    public let spectatorCount: Int
    /// Source of discovery (Bonjour, MultipeerConnectivity, manual)
    public let discoverySource: DiscoverySource
    /// Time at which this room was last seen
    public let lastSeen: Date

    public init(
        id: UUID = UUID(),
        hostName: String,
        gameName: String,
        gameHash: String,
        coreIdentifier: String,
        maxPlayers: Int,
        currentPlayers: Int,
        pingMS: Int? = nil,
        isLAN: Bool,
        hostAddress: String,
        port: UInt16,
        traversalCode: String? = nil,
        isPasswordProtected: Bool = false,
        allowsSpectators: Bool = true,
        spectatorCount: Int = 0,
        discoverySource: DiscoverySource = .bonjour,
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.hostName = hostName
        self.gameName = gameName
        self.gameHash = gameHash
        self.coreIdentifier = coreIdentifier
        self.maxPlayers = maxPlayers
        self.currentPlayers = currentPlayers
        self.pingMS = pingMS
        self.isLAN = isLAN
        self.hostAddress = hostAddress
        self.port = port
        self.traversalCode = traversalCode
        self.isPasswordProtected = isPasswordProtected
        self.allowsSpectators = allowsSpectators
        self.spectatorCount = spectatorCount
        self.discoverySource = discoverySource
        self.lastSeen = lastSeen
    }

    /// Whether the room still has open player slots
    public var hasOpenSlots: Bool { currentPlayers < maxPlayers }

    /// Whether the room is full (spectating only)
    public var isFull: Bool { currentPlayers >= maxPlayers }

    /// Human-readable player count string
    public var playerCountDisplay: String {
        "\(currentPlayers)/\(maxPlayers) players"
    }

    /// Human-readable ping string
    public var pingDisplay: String {
        guard let ms = pingMS else { return "?" }
        return "\(ms)ms"
    }
}

// MARK: - DiscoverySource

/// How a netplay room was discovered.
public enum DiscoverySource: String, Sendable, Codable {
    /// Discovered via RetroArch Bonjour/NSNetService advertisement
    case bonjour = "bonjour"
    /// Discovered via MultipeerConnectivity (Bluetooth / P2P Wi-Fi)
    case multipeer = "multipeer"
    /// Entered manually by the user (IP + port)
    case manual = "manual"
    /// Fetched from the RetroArch public lobby REST API
    case lobbyAPI = "lobbyAPI"
}
