//
//  NetplayState.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// The lifecycle state of netplay for the running core.
public enum NetplayState: Sendable, Equatable {
    /// Not in a netplay session.
    case idle
    /// Hosting a room and waiting for players to join.
    case hosting(room: NetplayRoom)
    /// Attempting to connect to a remote room.
    case connecting(to: NetplayRoom)
    /// Connected and actively playing.
    case connected(session: NetplaySession)
    /// Disconnected from a previous session.
    case disconnected(reason: DisconnectReason)

    public var isActive: Bool {
        switch self {
        case .hosting, .connecting, .connected: return true
        case .idle, .disconnected: return false
        }
    }

    public var session: NetplaySession? {
        if case .connected(let s) = self { return s }
        return nil
    }

    public static func == (lhs: NetplayState, rhs: NetplayState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.hosting(let a), .hosting(let b)): return a.id == b.id
        case (.connecting(let a), .connecting(let b)): return a.id == b.id
        case (.connected(let a), .connected(let b)): return a.id == b.id
        case (.disconnected(let a), .disconnected(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - DisconnectReason

/// Why a netplay session ended.
public enum DisconnectReason: String, Sendable, Equatable {
    case userRequested = "user_requested"
    case peerDisconnected = "peer_disconnected"
    case networkError = "network_error"
    case romMismatch = "rom_mismatch"
    case desync = "desync"
    case timeout = "timeout"
    case hostClosed = "host_closed"
}
