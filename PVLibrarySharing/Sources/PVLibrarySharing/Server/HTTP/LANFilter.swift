//
//  LANFilter.swift
//  PVLibrarySharing
//
//  Who may talk to a sharing listener (spec §3.6, "LAN-only guarantees").
//

import Foundation

/// An IPv4 or IPv6 address as raw bytes (4 or 16).
public struct IPAddressBytes: Sendable, Hashable {
    public var bytes: [UInt8]

    public init?(_ bytes: [UInt8]) {
        guard bytes.count == 4 || bytes.count == 16 else { return nil }
        self.bytes = bytes
    }

    public var isIPv4: Bool { bytes.count == 4 }

    /// `::ffff:a.b.c.d` becomes `a.b.c.d`; anything else is returned unchanged.
    public var unmapped: IPAddressBytes {
        guard bytes.count == 16, bytes[0..<10].allSatisfy({ $0 == 0 }), bytes[10] == 0xFF, bytes[11] == 0xFF else { return self }
        return IPAddressBytes(Array(bytes[12..<16])) ?? self
    }

    public var isLoopback: Bool {
        if isIPv4 { return bytes[0] == 127 }
        return bytes[0..<15].allSatisfy { $0 == 0 } && bytes[15] == 1
    }

    /// 169.254/16 or fe80::/10.
    public var isLinkLocal: Bool {
        if isIPv4 { return bytes[0] == 169 && bytes[1] == 254 }
        return bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80
    }

    /// Parses dotted IPv4 or textual IPv6 (a `%scope` suffix is dropped).
    public init?(string: String) {
        let host = string.split(separator: "%", maxSplits: 1).first.map(String.init) ?? string
        if let v4 = Self.parse(host, family: AF_INET, size: 4) {
            self = v4
        } else if let v6 = Self.parse(host, family: AF_INET6, size: 16) {
            self = v6
        } else {
            return nil
        }
    }

    private static func parse(_ host: String, family: Int32, size: Int) -> IPAddressBytes? {
        var buffer = [UInt8](repeating: 0, count: size)
        let result = host.withCString { inet_pton(family, $0, &buffer) }
        return result == 1 ? IPAddressBytes(buffer) : nil
    }
}

/// One local interface address and its netmask.
public struct LocalInterfaceAddress: Sendable, Hashable {
    public var name: String
    public var address: IPAddressBytes
    public var netmask: IPAddressBytes

    public init(name: String, address: IPAddressBytes, netmask: IPAddressBytes) {
        self.name = name
        self.address = address
        self.netmask = netmask
    }

    /// True when `other` is on this interface's prefix.
    public func contains(_ other: IPAddressBytes) -> Bool {
        let candidate = other.unmapped
        guard candidate.bytes.count == address.bytes.count, netmask.bytes.count == address.bytes.count else { return false }
        for index in address.bytes.indices where (address.bytes[index] & netmask.bytes[index]) != (candidate.bytes[index] & netmask.bytes[index]) {
            return false
        }
        return true
    }
}

/// Accepts a request only from loopback, a link-local address, or the on-link
/// prefix of one of this device's interfaces. The last rule admits global IPv6
/// on a home network while refusing anything routed in from outside it.
public enum LANFilter {
    /// Interface name prefixes that are never the LAN: cellular and VPN tunnels.
    static let excludedInterfacePrefixes = ["pdp_ip", "utun", "ipsec", "ppp"]

    public static func isAllowed(_ remote: IPAddressBytes, interfaces: [LocalInterfaceAddress]) -> Bool {
        let address = remote.unmapped
        if address.isLoopback || address.isLinkLocal { return true }
        return interfaces.contains { $0.contains(address) }
    }

    /// The device's up, non-loopback, non-cellular interface addresses.
    public static func currentInterfaces() -> [LocalInterfaceAddress] {
        var result: [LocalInterfaceAddress] = []
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let addr = entry.pointee.ifa_addr, let mask = entry.pointee.ifa_netmask else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            guard !excludedInterfacePrefixes.contains(where: name.hasPrefix) else { continue }
            if let address = bytes(of: addr), let netmask = bytes(of: mask), address.bytes.count == netmask.bytes.count {
                result.append(LocalInterfaceAddress(name: name, address: address, netmask: netmask))
            }
        }
        return result
    }

    /// Base URLs a peer can reach this device on (`u0..u3`): IPv4 addresses
    /// on Wi-Fi/Ethernet first, then the `<host>.local` name. The name is what
    /// works over router-less peer-to-peer Wi-Fi, which has no IPv4 address
    /// (iCube advertises the same kind of `.local` URL). At most `limit`.
    public static func baseURLs(
        port: UInt16,
        interfaces: [LocalInterfaceAddress] = currentInterfaces(),
        hostName: String? = ProcessInfo.processInfo.hostName,
        limit: Int = 4
    ) -> [URL] {
        let ipv4 = interfaces.filter { $0.address.isIPv4 && !$0.address.isLinkLocal }
        let ordered = ipv4.sorted { lhs, rhs in
            let left = lhs.name.hasPrefix("en") ? 0 : 1
            let right = rhs.name.hasPrefix("en") ? 0 : 1
            return (left, lhs.name) < (right, rhs.name)
        }
        var seen = Set<String>()
        var hosts = ordered.compactMap { interface -> String? in
            let text = interface.address.bytes.map(String.init).joined(separator: ".")
            return seen.insert(text).inserted ? text : nil
        }
        if let hostName, hostName.lowercased().hasSuffix(".local"), hostName.count > ".local".count {
            // Keep room for the name: it is the only candidate that works without a router.
            hosts = Array(hosts.prefix(max(limit - 1, 0))) + [hostName]
        }
        return hosts.prefix(limit).compactMap { URL(string: "http://\($0):\(port)") }
    }

    private static func bytes(of sockaddrPointer: UnsafeMutablePointer<sockaddr>) -> IPAddressBytes? {
        switch Int32(sockaddrPointer.pointee.sa_family) {
        case AF_INET:
            return sockaddrPointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer in
                withUnsafeBytes(of: pointer.pointee.sin_addr) { IPAddressBytes(Array($0)) }
            }
        case AF_INET6:
            return sockaddrPointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
                withUnsafeBytes(of: pointer.pointee.sin6_addr) { IPAddressBytes(Array($0)) }
            }
        default:
            return nil
        }
    }
}
