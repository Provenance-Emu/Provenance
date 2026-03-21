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
            let (data, response) = try await URLSession.shared.data(from: lobbyURL)
            guard !Task.isCancelled else { return }

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                lastError = "Lobby API returned HTTP \(code)"
                return
            }

            let entries = try JSONDecoder().decode([LobbyEntry].self, from: data)
            rooms = entries.compactMap { NetplayRoom(lobbyEntry: $0) }
        } catch is CancellationError {
            // Normal cancellation — no error to report.
        } catch {
            lastError = error.localizedDescription
        }
    }
}

// MARK: - Lobby API Decodable models

/// Top-level entry in the RetroArch lobby JSON array.
private struct LobbyEntry: Decodable {
    let fields: LobbyFields
}

private struct LobbyFields: Decodable {
    let username: String?
    let gameName: String?
    let gameCrc: String?
    let coreName: String?
    let ip: String?
    let mitm_ip: String?
    let mitm_port: Int?
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
        case mitm_ip
        case mitm_port
        case port
        case hasPassword    = "has_password"
        case hasSpectatePassword = "has_spectate_password"
        case connectable
        case country
        case id
    }
}

// MARK: - NetplayRoom initialiser from lobby entry

private extension NetplayRoom {
    /// Build a `NetplayRoom` from a lobby API entry.
    /// Returns `nil` if essential fields are missing.
    init?(lobbyEntry entry: LobbyEntry) {
        let fields = entry.fields
        // Prefer MITM relay address when available (NAT traversal), fall back to direct IP.
        let address: String
        let roomPort: UInt16
        if let mitm = fields.mitm_ip, !mitm.isEmpty, let mPort = fields.mitm_port, mPort > 0 {
            address = mitm
            roomPort = UInt16(clamping: mPort)
        } else if let ip = fields.ip, !ip.isEmpty {
            address = ip
            roomPort = UInt16(clamping: fields.port ?? 55435)
        } else {
            return nil
        }

        let gameText = fields.gameName?.isEmpty == false ? fields.gameName! : "Unknown Game"
        let hostText = fields.username?.isEmpty == false ? fields.username! : "Unknown Host"
        let coreText = fields.coreName ?? ""
        let roomID: UUID
        if let idStr = fields.id, let parsed = UUID(uuidString: idStr) {
            roomID = parsed
        } else {
            roomID = UUID()
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
            allowsSpectators: fields.hasSpectatePassword == false,
            spectatorCount: 0,
            discoverySource: .lobbyAPI,
            lastSeen: Date()
        )
    }
}
#endif
