//
//  NetplayJoinInfo.swift
//  PVNetplay
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// How to reach a host, sent to the other player over a side channel that
/// can't carry the game traffic itself. Game Center pairs two players but
/// never reveals either one's IP address, so the host sends its own.
public struct NetplayJoinInfo: Codable, Equatable, Sendable {
    /// Bumped when the format changes incompatibly.
    public static let currentVersion = 1

    public var version: Int
    /// The port the host listens on.
    public var port: UInt16
    /// The host's addresses, most likely to work first.
    public var addresses: [String]

    public init(port: UInt16, addresses: [String]) {
        self.version = Self.currentVersion
        self.port = port
        self.addresses = addresses
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a join message, or nil if it isn't one this build understands.
    public static func decode(_ data: Data) -> NetplayJoinInfo? {
        guard let info = try? JSONDecoder().decode(NetplayJoinInfo.self, from: data),
              info.version == currentVersion else {
            return nil
        }
        return info
    }
}

/// The device's own network addresses.
public enum NetplayLocalAddresses {

    /// Addresses another device could connect to: IPv4 on active,
    /// non-loopback interfaces first, then global IPv6. Link-local addresses
    /// (169.254/16, fe80::/10) are left out — they need an interface scope
    /// the other device doesn't know.
    public static func current() -> [String] {
        #if canImport(Darwin)
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ipv4: [String] = []
        var ipv6: [String] = []
        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(interface.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0,
                  let address = interface.pointee.ifa_addr else { continue }
            let family = Int32(address.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let text = String(cString: host)
            if family == AF_INET {
                if !text.hasPrefix("169.254.") { ipv4.append(text) }
            } else if !text.lowercased().hasPrefix("fe80") {
                ipv6.append(text)
            }
        }
        return orderedUnique(ipv4 + ipv6)
        #else
        return []
        #endif
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
