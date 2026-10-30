//
//  NetplayHostedGame.swift
//  PVNetplay
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// The game a host is running, as the library knows it.
///
/// Cores report little about their game (Dolphin's room has no name or hash),
/// so the UI passes this to `PVNetplayManager.host` and the manager publishes
/// it in the room's LAN advertisement. Joiners match it to their own library.
public struct NetplayHostedGame: Sendable, Hashable {
    /// Display title.
    public var name: String
    /// The library MD5 (`PVGame.md5Hash`).
    public var md5: String
    /// Serial / game ID, empty when unknown.
    public var serial: String
    /// System identifier (e.g. "com.provenance.gamecube").
    public var systemIdentifier: String
    /// Identifier of the core running it.
    public var isPatched: Bool = false
    public var coreVersion: String = ""
    public var option: NetplayGameOption?
    public var coreIdentifier: String

    public init(name: String, md5: String, serial: String = "", systemIdentifier: String = "", coreIdentifier: String = "") {
        self.name = name
        self.md5 = md5
        self.serial = serial
        self.systemIdentifier = systemIdentifier
        self.coreIdentifier = coreIdentifier
    }
}
