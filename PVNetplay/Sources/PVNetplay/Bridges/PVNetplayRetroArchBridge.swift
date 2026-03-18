//
//  PVNetplayRetroArchBridge.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(Combine)
import Combine
#endif

/// Swift-side protocol that the ObjC `PVRetroArchNetplayBridge` conforms to.
///
/// This allows `PVNetplayManager` to call RetroArch netplay commands without
/// depending directly on the `PVRetroArchCore` module, keeping the dependency
/// graph clean (PVNetplay → protocol; PVRetroArchCore → implements protocol).
public protocol RetroArchNetplayBridging: AnyObject, Sendable {
    /// Start hosting a RetroArch netplay session.
    func startHosting(settings: NetplaySettings) throws

    /// Connect to a remote RetroArch netplay host.
    func connect(to room: NetplayRoom, settings: NetplaySettings) throws

    /// Stop the current RetroArch netplay session.
    func stop()

    /// Query current RetroArch netplay status.
    /// Returns nil if no session is active.
    func currentStatus() -> RetroArchNetplayStatus?
}

// MARK: - RetroArchNetplayStatus

/// Snapshot of RetroArch's current netplay state, polled from config vars.
public struct RetroArchNetplayStatus: Sendable {
    public let isConnected: Bool
    public let isHost: Bool
    public let peerNickname: String?
    public let pingMS: Int?
    public let frameDelay: Int
    public let rollbackCount: Int

    public init(
        isConnected: Bool,
        isHost: Bool,
        peerNickname: String? = nil,
        pingMS: Int? = nil,
        frameDelay: Int = 0,
        rollbackCount: Int = 0
    ) {
        self.isConnected = isConnected
        self.isHost = isHost
        self.peerNickname = peerNickname
        self.pingMS = pingMS
        self.frameDelay = frameDelay
        self.rollbackCount = rollbackCount
    }
}
