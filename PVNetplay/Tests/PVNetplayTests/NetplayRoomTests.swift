//
//  NetplayRoomTests.swift
//  PVNetplayTests
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Testing
import Foundation
@testable import PVNetplay

@Suite("NetplayRoom Tests")
struct NetplayRoomTests {

    @Test("Room hasOpenSlots is false when full")
    func roomSlots() {
        let full = NetplayRoom(
            hostName: "TestHost",
            gameName: "Chrono Trigger",
            gameHash: "abc123",
            coreIdentifier: "com.provenance.snes9x",
            maxPlayers: 2,
            currentPlayers: 2,
            isLAN: true,
            hostAddress: "192.168.1.10",
            port: 55435
        )
        #expect(full.isFull)
        #expect(!full.hasOpenSlots)
    }

    @Test("Room hasOpenSlots is true when not full")
    func roomOpenSlots() {
        let open = NetplayRoom(
            hostName: "TestHost",
            gameName: "Super Mario World",
            gameHash: "def456",
            coreIdentifier: "com.provenance.snes9x",
            maxPlayers: 2,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: "192.168.1.11",
            port: 55435
        )
        #expect(open.hasOpenSlots)
        #expect(!open.isFull)
    }

    @Test("pingDisplay shows question mark when nil")
    func pingDisplay() {
        let room = NetplayRoom(
            hostName: "Host",
            gameName: "Game",
            gameHash: "",
            coreIdentifier: "",
            maxPlayers: 2,
            currentPlayers: 1,
            pingMS: nil,
            isLAN: true,
            hostAddress: "10.0.0.1",
            port: 55435
        )
        #expect(room.pingDisplay == "?")
    }

    @Test("pingDisplay shows ms value")
    func pingDisplayValue() {
        let room = NetplayRoom(
            hostName: "Host",
            gameName: "Game",
            gameHash: "",
            coreIdentifier: "",
            maxPlayers: 2,
            currentPlayers: 1,
            pingMS: 42,
            isLAN: true,
            hostAddress: "10.0.0.1",
            port: 55435
        )
        #expect(room.pingDisplay == "42ms")
    }
}

@Suite("NetplayState Tests")
struct NetplayStateTests {

    @Test("idle state is not active")
    func idleNotActive() {
        let state = NetplayState.idle
        #expect(!state.isActive)
    }

    @Test("disconnected state is not active")
    func disconnectedNotActive() {
        let state = NetplayState.disconnected(reason: .userRequested)
        #expect(!state.isActive)
    }

    @Test("hosting state is active")
    func hostingIsActive() {
        let room = makeRoom()
        let state = NetplayState.hosting(room: room)
        #expect(state.isActive)
    }

    @Test("connected state session is not nil")
    func connectedHasSession() {
        let room = makeRoom()
        let session = NetplaySession(
            room: room,
            role: .host(port: 55435),
            peers: [],
            frameDelay: 0,
            isRollbackEnabled: true
        )
        let state = NetplayState.connected(session: session)
        #expect(state.session != nil)
        #expect(state.isActive)
    }

    private func makeRoom() -> NetplayRoom {
        NetplayRoom(
            hostName: "TestHost",
            gameName: "Test Game",
            gameHash: "abc",
            coreIdentifier: "com.provenance.test",
            maxPlayers: 2,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: "127.0.0.1",
            port: 55435
        )
    }
}

@Suite("NetplayRole Tests")
struct NetplayRoleTests {

    @Test("host role isHost is true")
    func hostRole() {
        let role = NetplayRole.host(port: 55435)
        #expect(role.isHost)
        #expect(!role.isClient)
        #expect(!role.isSpectator)
    }

    @Test("client role isClient is true")
    func clientRole() {
        let role = NetplayRole.client(host: "10.0.0.1", port: 55435)
        #expect(role.isClient)
        #expect(!role.isHost)
        #expect(!role.isSpectator)
    }

    @Test("spectator role isSpectator is true")
    func spectatorRole() {
        let role = NetplayRole.spectator(host: "10.0.0.1", port: 55435)
        #expect(role.isSpectator)
        #expect(!role.isHost)
        #expect(!role.isClient)
    }
}

@Suite("NetplaySettings Tests")
struct NetplaySettingsTests {

    @Test("defaultLAN has expected port")
    func defaultLANPort() {
        #expect(NetplaySettings.defaultLAN.port == 55435)
    }

    @Test("defaultWAN has relay server")
    func defaultWANRelay() {
        #expect(NetplaySettings.defaultWAN.relayServer != nil)
    }

    @Test("custom settings round-trip")
    func customSettings() {
        let s = NetplaySettings(frameDelay: 3, maxPlayers: 4, port: 12345, nickname: "TestPlayer")
        #expect(s.frameDelay == 3)
        #expect(s.maxPlayers == 4)
        #expect(s.port == 12345)
        #expect(s.nickname == "TestPlayer")
    }
}

@Suite("NetplayRoom WAN Tests")
struct NetplayRoomWANTests {

    @Test("lobbyAPI source is not LAN")
    func lobbyAPISourceIsWAN() {
        let room = NetplayRoom(
            hostName: "OnlinePal",
            gameName: "Sonic",
            gameHash: "deadbeef",
            coreIdentifier: "com.provenance.genesis",
            maxPlayers: 2,
            currentPlayers: 1,
            isLAN: false,
            hostAddress: "1.2.3.4",
            port: 55435,
            discoverySource: .lobbyAPI
        )
        #expect(!room.isLAN)
        #expect(room.discoverySource == .lobbyAPI)
    }

    @Test("lobbyAPI source roundtrips via Codable")
    func lobbyAPISourceCodable() throws {
        let source = DiscoverySource.lobbyAPI
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(DiscoverySource.self, from: data)
        #expect(decoded == .lobbyAPI)
    }
}

@Suite("NetplayError Tests")
struct NetplayErrorTests {

    @Test("unsupported error has description")
    func unsupportedDescription() {
        let err = NetplayError.unsupported
        #expect(err.errorDescription != nil)
    }

    @Test("connectionFailed error embeds reason")
    func connectionFailedReason() {
        let err = NetplayError.connectionFailed("timeout")
        #expect(err.errorDescription?.contains("timeout") == true)
    }

    @Test("invalidSettings error embeds reason")
    func invalidSettingsReason() {
        let err = NetplayError.invalidSettings("bad port")
        #expect(err.errorDescription?.contains("bad port") == true)
    }
}

// MARK: - RetroArch Lobby address selection tests

#if canImport(Combine)
@Suite("RetroArchLobby Address Selection Tests")
struct RetroArchLobbyAddressTests {

    @Test("MITM address is preferred when present")
    func mitmAddressPreferred() throws {
        let json = """
        [{"fields":{"username":"HostA","game_name":"Sonic","game_crc":"DEADBEEF",
          "core_name":"genesis_plus_gx","ip":"203.0.113.1","port":55435,
          "mitm_ip":"relay.example.com","mitm_port":55436,
          "has_password":false,"has_spectate_password":false,"connectable":true}}]
        """.data(using: .utf8)!
        let entries = try JSONDecoder().decode([LobbyEntry].self, from: json)
        let room = try #require(NetplayRoom(lobbyEntry: entries[0]))
        #expect(room.hostAddress == "relay.example.com")
        #expect(room.port == 55436)
    }

    @Test("Direct IP used when MITM fields are absent")
    func directIPFallback() throws {
        let json = """
        [{"fields":{"username":"HostB","game_name":"Mario","game_crc":"CAFEBABE",
          "core_name":"snes9x","ip":"198.51.100.5","port":12345,
          "has_password":false,"has_spectate_password":false,"connectable":true}}]
        """.data(using: .utf8)!
        let entries = try JSONDecoder().decode([LobbyEntry].self, from: json)
        let room = try #require(NetplayRoom(lobbyEntry: entries[0]))
        #expect(room.hostAddress == "198.51.100.5")
        #expect(room.port == 12345)
    }

    @Test("Entry with empty MITM IP falls back to direct IP")
    func emptyMITMFallsBackToDirect() throws {
        let json = """
        [{"fields":{"username":"HostC","game_name":"Zelda","game_crc":"BEEFDEAD",
          "core_name":"mgba","ip":"192.0.2.9","port":55435,
          "mitm_ip":"","mitm_port":0,
          "has_password":false,"has_spectate_password":false,"connectable":true}}]
        """.data(using: .utf8)!
        let entries = try JSONDecoder().decode([LobbyEntry].self, from: json)
        let room = try #require(NetplayRoom(lobbyEntry: entries[0]))
        #expect(room.hostAddress == "192.0.2.9")
    }

    @Test("Entry missing both IP and MITM returns nil")
    func missingAllAddressesReturnsNil() throws {
        let json = """
        [{"fields":{"username":"HostD","game_name":"Pong","game_crc":"00000000",
          "core_name":"atari800","has_password":false,"has_spectate_password":false}}]
        """.data(using: .utf8)!
        let entries = try JSONDecoder().decode([LobbyEntry].self, from: json)
        #expect(NetplayRoom(lobbyEntry: entries[0]) == nil)
    }

    @Test("Unknown gameName and username use fallback strings")
    func fallbackDisplayStrings() throws {
        let json = """
        [{"fields":{"ip":"10.0.0.1","port":55435,
          "has_password":false,"has_spectate_password":false,"connectable":true}}]
        """.data(using: .utf8)!
        let entries = try JSONDecoder().decode([LobbyEntry].self, from: json)
        let room = try #require(NetplayRoom(lobbyEntry: entries[0]))
        #expect(room.gameName == "Unknown Game")
        #expect(room.hostName == "Unknown Host")
    }

    @Test("Missing has_spectate_password field allows spectators")
    func missingSpectatePasswordAllowsSpectators() throws {
        let json = """
        [{"fields":{"username":"HostE","game_name":"Tetris","game_crc":"12345678",
          "core_name":"gbcore","ip":"10.0.0.2","port":55435,
          "has_password":false,"connectable":true}}]
        """.data(using: .utf8)!
        let entries = try JSONDecoder().decode([LobbyEntry].self, from: json)
        let room = try #require(NetplayRoom(lobbyEntry: entries[0]))
        // nil has_spectate_password means no password required → spectators allowed
        #expect(room.allowsSpectators)
    }

    @Test("has_spectate_password true disallows spectators")
    func spectatePasswordTrueDisallowsSpectators() throws {
        let json = """
        [{"fields":{"username":"HostF","game_name":"Pong","game_crc":"AAAABBBB",
          "core_name":"atari","ip":"10.0.0.3","port":55435,
          "has_password":false,"has_spectate_password":true,"connectable":true}}]
        """.data(using: .utf8)!
        let entries = try JSONDecoder().decode([LobbyEntry].self, from: json)
        let room = try #require(NetplayRoom(lobbyEntry: entries[0]))
        #expect(!room.allowsSpectators)
    }

    @Test("Rooms with same stable fields produce same deterministic UUID")
    func deterministicUUIDStability() throws {
        let json = """
        [{"fields":{"username":"HostG","game_name":"BreakOut","game_crc":"CCCCDDDD",
          "core_name":"atari","ip":"10.0.0.4","port":55435,
          "has_password":false,"connectable":true}}]
        """.data(using: .utf8)!
        let entries = try JSONDecoder().decode([LobbyEntry].self, from: json)
        let room1 = try #require(NetplayRoom(lobbyEntry: entries[0]))
        let room2 = try #require(NetplayRoom(lobbyEntry: entries[0]))
        #expect(room1.id == room2.id)
    }
}
#endif

// MARK: - TraversalCode Tests

@Suite("NetplayRoom TraversalCode Tests")
struct NetplayRoomTraversalCodeTests {

    @Test("traversalCode is nil by default")
    func traversalCodeDefaultsToNil() {
        let room = NetplayRoom(
            hostName: "DirectHost",
            gameName: "F-Zero",
            gameHash: "aabbccdd",
            coreIdentifier: "com.provenance.dolphin",
            maxPlayers: 4,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: "192.168.1.5",
            port: 2626
        )
        #expect(room.traversalCode == nil)
    }

    @Test("traversalCode is preserved when non-nil")
    func traversalCodeRoundTrips() {
        let room = NetplayRoom(
            hostName: "RelayHost",
            gameName: "Mario Kart Wii",
            gameHash: "deadbeef",
            coreIdentifier: "com.provenance.dolphin",
            maxPlayers: 4,
            currentPlayers: 1,
            isLAN: false,
            hostAddress: "ABCD-EFGH",
            port: 2626,
            traversalCode: "ABCD-EFGH"
        )
        #expect(room.traversalCode == "ABCD-EFGH")
        // When traversalCode is set, hostAddress should carry the same value
        // so existing consumers can connect without needing to check traversalCode.
        #expect(room.hostAddress == room.traversalCode)
    }

    @Test("traversal room is not LAN")
    func traversalRoomIsNotLAN() {
        let room = NetplayRoom(
            hostName: "RelayHost",
            gameName: "Super Smash Bros.",
            gameHash: "cafebabe",
            coreIdentifier: "com.provenance.dolphin",
            maxPlayers: 4,
            currentPlayers: 2,
            isLAN: false,
            hostAddress: "WXYZ-1234",
            port: 2626,
            traversalCode: "WXYZ-1234"
        )
        #expect(!room.isLAN)
        #expect(room.traversalCode != nil)
    }
}

// MARK: - PVNetplayCapable mock conformance test
// Verifies the protocol requirements can be satisfied (compile-time check).

#if canImport(Combine)
import Combine

/// Minimal mock to verify the PVNetplayCapable protocol surface compiles.
/// @unchecked Sendable: mock is only used on a single test thread; no concurrent mutation.
private final class MockNetplayCapable: PVNetplayCapable, @unchecked Sendable {
    var supportsNetplay: Bool { true }
    var netplayEngineName: String { "MockEngine" }

    func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {}
    func stopNetplay() async {}

    var netplayState: NetplayState { .idle }
    var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        Just(.idle).eraseToAnyPublisher()
    }
}

@Suite("PVNetplayCapable Protocol Tests")
struct PVNetplayCapableTests {

    @Test("mock conformance: supportsNetplay is true")
    func mockSupports() {
        let mock = MockNetplayCapable()
        #expect(mock.supportsNetplay)
    }

    @Test("mock conformance: netplayState is idle")
    func mockState() {
        let mock = MockNetplayCapable()
        #expect(mock.netplayState == .idle)
    }

    @Test("mock conformance: engineName is non-empty")
    func mockEngineName() {
        let mock = MockNetplayCapable()
        #expect(!mock.netplayEngineName.isEmpty)
    }
}
#endif
