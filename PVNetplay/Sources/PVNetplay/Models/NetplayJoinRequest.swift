//
//  NetplayJoinRequest.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/27/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Parsed representation of a `provenance://netplay/join` deep link.
public struct NetplayJoinRequest: Equatable, Sendable {
    public let host: String
    public let port: UInt16
    public let relay: String?
    public let gameName: String?

    public init(host: String, port: UInt16, relay: String? = nil, gameName: String? = nil) {
        self.host = host
        self.port = port
        self.relay = relay
        self.gameName = gameName
    }
}

// MARK: - URL parsing

public extension NetplayJoinRequest {
    /// The default RetroArch netplay port used when no port is specified.
    static let defaultPort: UInt16 = 55435

    /// Parses a `provenance://netplay/join` deep link URL into a `NetplayJoinRequest`.
    ///
    /// Returns `nil` when the URL is missing the required `host` parameter or the
    /// scheme/host/path do not match the expected deep-link format.
    static func from(url: URL) -> NetplayJoinRequest? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "provenance",
              components.host == "netplay",
              components.path == "/join",
              let items = components.queryItems else { return nil }

        func value(for name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }

        guard let host = value(for: "host"), !host.isEmpty else { return nil }

        let portValue: UInt16
        if let portStr = value(for: "port"), let parsed = UInt16(portStr), parsed >= 1 {
            portValue = parsed
        } else {
            portValue = defaultPort
        }

        return NetplayJoinRequest(
            host: host,
            port: portValue,
            relay: value(for: "relay"),
            gameName: value(for: "game")
        )
    }

    /// Parses a `NetplayJoinRequest` from a `Notification.userInfo` dictionary.
    ///
    /// The notification is posted by `PVAppDelegate` after it validates a deep link URL.
    /// The port is stored as `UInt16` by the current dispatcher, but the parser also
    /// accepts `Int` and `String` for forward-compatibility with future senders.
    ///
    /// Returns `nil` when the required `host` key is absent or empty.
    static func from(notificationUserInfo info: [AnyHashable: Any]) -> NetplayJoinRequest? {
        guard let host = info["host"] as? String, !host.isEmpty else { return nil }

        let portValue: UInt16
        if let portUInt16 = info["port"] as? UInt16, portUInt16 >= 1 {
            // AppDelegate posts port as UInt16 directly
            portValue = portUInt16
        } else if let portStr = info["port"] as? String, let parsed = UInt16(portStr), parsed >= 1 {
            portValue = parsed
        } else if let portInt = info["port"] as? Int, portInt >= 1, portInt <= 65535 {
            portValue = UInt16(portInt)
        } else {
            portValue = defaultPort
        }

        let relay = info["relay"] as? String
        let gameName = info["game"] as? String
        return NetplayJoinRequest(host: host, port: portValue, relay: relay, gameName: gameName)
    }
}
