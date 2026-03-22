//
//  RetroArchLobbyService.swift
//  PVNetplay
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

@preconcurrency import Foundation
#if canImport(Combine)
import Combine

/// Fetches publicly listed WAN netplay rooms from the RetroArch lobby REST API.
///
/// Endpoint: `https://lobby.libretro.com/list/`
/// No authentication required — publicly available room listing.
@MainActor
public final class RetroArchLobbyService: ObservableObject {
    /// Currently fetched WAN rooms.
    @Published public private(set) var rooms: [NetplayRoom] = []
    /// Whether a fetch is in-flight.
    @Published public private(set) var isFetching: Bool = false
    /// Last fetch error, if any.
    @Published public private(set) var lastError: String?

    private let lobbyURL = URL(string: "https://lobby.libretro.com/list/")!
    private var fetchTask: Task<Void, Never>?
    /// Maximum seconds to wait for the lobby API before giving up.
    private let fetchTimeout: TimeInterval = 15

    public init() {}

    // MARK: - Public API

    /// Fetch the current list of public rooms from the lobby API.
    public func fetchRooms() {
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            await self?.performFetch()
        }
    }

    /// Cancel any in-flight fetch.
    public func cancelFetch() {
        fetchTask?.cancel()
        fetchTask = nil
        isFetching = false
    }

    // MARK: - Private

    private func performFetch() async {
        guard !Task.isCancelled else { return }
        isFetching = true
        lastError = nil
        defer { isFetching = false }

        do {
            let request = URLRequest(url: lobbyURL, timeoutInterval: fetchTimeout)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                lastError = "Lobby API returned HTTP \(code)"
                return
            }

            // Decode and map off the main actor to avoid blocking UI updates.
            let decoded = try await Task.detached(priority: .userInitiated) { () throws -> [NetplayRoom] in
                let entries = try JSONDecoder().decode([LobbyEntry].self, from: data)
                return entries.compactMap { NetplayRoom(lobbyEntry: $0) }
            }.value
            rooms = decoded
        } catch is CancellationError {
            // Normal cancellation — no error to report.
        } catch {
            lastError = error.localizedDescription
        }
    }
}

// MARK: - UUID deterministic helper

private extension UUID {
    /// Creates a UUID deterministically from a string using a 16-byte XOR fold of its UTF-8 bytes.
    /// The version (5) and RFC 4122 variant bits are stamped so the output looks structurally like
    /// a name-based UUID, keeping SwiftUI List identity stable across fetches.
    /// This is NOT SHA-1 and does NOT conform to RFC 4122 §4.3 (UUIDv5). It is a fast fold
    /// suitable only for stable list diffing — do not use for cryptographic purposes.
    init(deterministicString string: String) {
        var hash = [UInt8](repeating: 0, count: 16)
        let bytes = Array(string.utf8)
        for (index, byte) in bytes.enumerated() {
            hash[index % 16] ^= byte &+ UInt8(truncatingIfNeeded: index)
        }
        // Set version 5 and RFC 4122 variant bits (does not imply SHA-1 hashing).
        hash[6] = (hash[6] & 0x0F) | 0x50
        hash[8] = (hash[8] & 0x3F) | 0x80
        self = UUID(uuid: (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        ))
    }
}

// MARK: - Lobby API Decodable models

/// Top-level entry in the RetroArch lobby JSON array.
struct LobbyEntry: Decodable {
    let fields: LobbyFields
}

struct LobbyFields: Decodable {
    let username: String?
    let gameName: String?
    let gameCrc: String?
    let coreName: String?
    let ip: String?
    let mitmIP: String?
    let mitmPort: Int?
    let port: Int?
    let hasPassword: Bool?
    let hasSpectatePassword: Bool?
    let connectable: Bool?
    let country: String?
    let id: String?

    enum CodingKeys: String, CodingKey {
        case username
        case gameName       = "game_name"
        case gameCrc        = "game_crc"
        case coreName       = "core_name"
        case ip
        case mitmIP         = "mitm_ip"
        case mitmPort       = "mitm_port"
        case port
        case hasPassword    = "has_password"
        case hasSpectatePassword = "has_spectate_password"
        case connectable
        case country
        case id
    }
}

// MARK: - NetplayRoom initialiser from lobby entry

extension NetplayRoom {
    /// Build a `NetplayRoom` from a lobby API entry.
    /// Returns `nil` if essential fields are missing.
    /// Internal for testability; not part of the public API.
    init?(lobbyEntry entry: LobbyEntry) {
        let fields = entry.fields
        // Prefer MITM relay address when available (NAT traversal), fall back to direct IP.
        let address: String
        let roomPort: UInt16
        if let mitm = fields.mitmIP, !mitm.isEmpty, let mPort = fields.mitmPort, mPort > 0 {
            address = mitm
            roomPort = UInt16(clamping: mPort)
        } else if let ip = fields.ip, !ip.isEmpty {
            address = ip
            let rawPort = fields.port ?? 55435
            roomPort = UInt16(clamping: rawPort > 0 ? rawPort : 55435)
        } else {
            return nil
        }

        let rawGameName = fields.gameName ?? ""
        let gameText = rawGameName.isEmpty ? "Unknown Game" : rawGameName

        let rawUsername = fields.username ?? ""
        let hostText = rawUsername.isEmpty ? "Unknown Host" : rawUsername
        let coreText = fields.coreName ?? ""
        // Use the lobby-provided ID when it's a valid UUID; otherwise derive a deterministic
        // identifier from stable fields so SwiftUI List diffing stays stable across refreshes.
        let roomID: UUID
        if let idStr = fields.id, let parsed = UUID(uuidString: idStr) {
            roomID = parsed
        } else {
            let stableKey = "\(address):\(roomPort):\(fields.gameCrc ?? ""):\(rawUsername)"
            roomID = UUID(deterministicString: stableKey)
        }

        self.init(
            id: roomID,
            hostName: hostText,
            gameName: gameText,
            gameHash: fields.gameCrc ?? "",
            coreIdentifier: coreText,
            maxPlayers: 2,
            currentPlayers: 1,
            pingMS: nil,
            isLAN: false,
            hostAddress: address,
            port: roomPort,
            isPasswordProtected: fields.hasPassword ?? false,
            // nil means the field was absent — treat as "no spectate password" → spectators allowed.
            allowsSpectators: fields.hasSpectatePassword != true,
            spectatorCount: 0,
            discoverySource: .lobbyAPI,
            lastSeen: Date()
        )
    }
}
#endif
