//
//  PVNetpacketCapable.swift
//  PVNetplay
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Sub-protocol of `PVNetplayCapable` for cores that support the libretro
//  netpacket interface (RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE, env 78).
//
//  Cores adopting this protocol indicate that they manage their own multiplayer
//  protocol and only need the frontend to provide a raw packet transport layer.
//

import Foundation

/// Adopted by cores whose multiplayer is driven by the libretro netpacket API.
///
/// Unlike RetroArch-style netplay (which handles deterministic lockstep,
/// rollback, and input relay at the frontend level), netpacket cores manage
/// their own multiplayer protocol — the frontend only provides the transport.
public protocol PVNetpacketCapable: PVNetplayCapable {
    /// Whether the loaded core registered a `retro_netpacket_callback` via env 78.
    var hasNetpacketInterface: Bool { get }

    /// The `protocol_version` string from the core's `retro_netpacket_callback`,
    /// or `nil` if the core did not supply one (falls back to library version).
    var netpacketProtocolVersion: String? { get }
}
