//
//  NetplayRoomTests.swift
//  PVNetplayTests
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Testing
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
