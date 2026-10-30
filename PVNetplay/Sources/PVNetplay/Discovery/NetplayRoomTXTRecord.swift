//
//  NetplayRoomTXTRecord.swift
//  PVNetplay
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// The Bonjour TXT record a host publishes for its room, and how a browser
/// reads it back. Hosts and browsers share these keys, so they live here.
public enum NetplayRoomTXTRecord {

    /// TXT keys. Changing one breaks discovery between app versions.
    public enum Key {
        public static let sessionID = "sessionId"
        public static let nickname = "nickname"
        public static let game = "game"
        /// Older hosts wrote the game name here.
        public static let content = "content"
        public static let hash = "hash"
        public static let serial = "serial"
        public static let system = "system"
        public static let core = "core"
        public static let coreVersion = "coreVersion"
        public static let playMode = "playMode"
        public static let maxPlayers = "maxPlayers"
        public static let players = "players"
        public static let spectators = "spectators"
        public static let password = "password"
        public static let allowSpectators = "allowSpectators"
    }

    /// Port a browser assumes when a service reports none.
    public static let defaultPort: UInt16 = 55435
    /// DNS-SD limit for one TXT entry ("key=value"), in bytes.
    static let maxEntryBytes = 255
    /// DNS-SD limit for a service instance name, in bytes.
    static let maxInstanceNameBytes = 63

    // MARK: - Encode

    /// The TXT record for `room`. Values are cut so each entry fits DNS-SD's
    /// 255-byte limit.
    public static func txtRecord(for room: NetplayRoom) -> [String: String] {
        var txt: [String: String] = [
            Key.sessionID: room.id.uuidString,
            Key.nickname: room.hostName,
            Key.game: room.gameName,
            Key.core: room.coreIdentifier,
            Key.maxPlayers: String(room.maxPlayers),
            Key.players: String(room.currentPlayers),
            Key.spectators: String(room.spectatorCount),
            Key.password: room.isPasswordProtected ? "1" : "0",
            Key.allowSpectators: room.allowsSpectators ? "1" : "0"
        ]
        if !room.gameHash.isEmpty { txt[Key.hash] = room.gameHash }
        if !room.gameSerial.isEmpty { txt[Key.serial] = room.gameSerial }
        if !room.systemIdentifier.isEmpty { txt[Key.system] = room.systemIdentifier }
        if !room.coreVersion.isEmpty { txt[Key.coreVersion] = room.coreVersion }
        if let mode = room.playMode { txt[Key.playMode] = mode.rawValue }
        return txt.reduce(into: [:]) { result, entry in
            let budget = maxEntryBytes - entry.key.utf8.count - 1
            result[entry.key] = truncated(entry.value, toBytes: budget)
        }
    }

    /// The Bonjour instance name for `room`: "<host> — <game>", cut to 63 bytes.
    public static func instanceName(for room: NetplayRoom) -> String {
        let name = room.gameName.isEmpty ? room.hostName : "\(room.hostName) — \(room.gameName)"
        return truncated(name, toBytes: maxInstanceNameBytes)
    }

    // MARK: - Decode

    /// The room a resolved service describes.
    ///
    /// - Parameters:
    ///   - txt: The TXT record, decoded to strings.
    ///   - serviceName: The Bonjour instance name; it names the room when the
    ///     TXT record has no nickname, and seeds a stable id when it has no session id.
    ///   - hostAddress: Where to connect (see `preferredHostAddress`).
    ///   - port: The service's port; 0 or less means unknown.
    public static func room(
        fromTXT txt: [String: String],
        serviceName: String,
        hostAddress: String,
        port: Int,
        lastSeen: Date = Date()
    ) -> NetplayRoom {
        let id = txt[Key.sessionID].flatMap(UUID.init(uuidString:)) ?? stableID(forServiceName: serviceName)
        return NetplayRoom(
            id: id,
            hostName: txt[Key.nickname] ?? serviceName,
            gameName: txt[Key.game] ?? txt[Key.content] ?? "Unknown Game",
            gameHash: txt[Key.hash] ?? "",
            coreIdentifier: txt[Key.core] ?? "",
            maxPlayers: txt[Key.maxPlayers].flatMap { Int($0) } ?? 2,
            currentPlayers: txt[Key.players].flatMap { Int($0) } ?? 1,
            isLAN: true,
            hostAddress: hostAddress,
            port: port > 0 ? UInt16(clamping: port) : defaultPort,
            isPasswordProtected: txt[Key.password] == "1",
            allowsSpectators: txt[Key.allowSpectators] != "0",
            spectatorCount: txt[Key.spectators].flatMap { Int($0) } ?? 0,
            discoverySource: .bonjour,
            lastSeen: lastSeen,
            gameSerial: txt[Key.serial] ?? "",
            systemIdentifier: txt[Key.system] ?? "",
            coreVersion: txt[Key.coreVersion] ?? "",
            playMode: txt[Key.playMode].flatMap(NetplayPlayMode.init(rawValue:))
        )
    }

    /// A deterministic UUID for a service name, for hosts that publish no session id.
    ///
    /// XOR-folds the UTF-8 bytes into 16 bytes, which is stable across launches
    /// (unlike `Hasher`), and tags the result as a version 4 / variant 1 UUID.
    public static func stableID(forServiceName name: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, byte) in name.utf8.enumerated() {
            bytes[i % 16] ^= byte
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x40
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// Where a joiner should connect: the first IPv4 address the service
    /// resolved to, else its host name.
    ///
    /// Several cores take only an IPv4 literal (PPSSPP ad hoc) or resolve
    /// names over IPv4 only (Dolphin's ENet), so a literal is the safe choice.
    /// - Parameter addresses: `sockaddr` blobs, as `NetService.addresses` gives them.
    public static func preferredHostAddress(addresses: [Data], hostName: String?) -> String? {
        for address in addresses {
            if let ipv4 = ipv4String(fromSockaddr: address) { return ipv4 }
        }
        guard let hostName, !hostName.isEmpty else { return nil }
        return hostName
    }

    /// The dotted IPv4 address in a `sockaddr_in` blob, or nil for anything else.
    static func ipv4String(fromSockaddr data: Data) -> String? {
        // sockaddr_in: sin_len (1), sin_family (1), sin_port (2), sin_addr (4), padding (8).
        let familyOffset = 1
        let addressOffset = 4
        let ipv4Length = 4
        let afInet: UInt8 = 2
        guard data.count >= addressOffset + ipv4Length,
              data[data.startIndex + familyOffset] == afInet else { return nil }
        let start = data.startIndex + addressOffset
        let octets = data[start..<(start + ipv4Length)]
        // 0.0.0.0 and link-local 169.254/16 are no use to a peer.
        guard octets.contains(where: { $0 != 0 }),
              !(octets[start] == 169 && octets[start + 1] == 254) else { return nil }
        return octets.map(String.init).joined(separator: ".")
    }

    // MARK: - Helpers

    /// `string` cut to at most `limit` UTF-8 bytes, never splitting a character.
    static func truncated(_ string: String, toBytes limit: Int) -> String {
        guard string.utf8.count > limit else { return string }
        var result = ""
        var used = 0
        for character in string {
            let size = String(character).utf8.count
            guard used + size <= limit else { break }
            result.append(character)
            used += size
        }
        return result
    }
}
