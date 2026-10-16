//
//  NetplayLANAdvertisementTests.swift
//  PVNetplayTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Testing
import Foundation
#if canImport(Combine)
import Combine
#endif
@testable import PVNetplay

private func makeRoom(
    port: UInt16 = 55435,
    traversalCode: String? = nil,
    gameName: String = "",
    gameHash: String = "",
    players: Int = 1
) -> NetplayRoom {
    NetplayRoom(
        hostName: "Joe",
        gameName: gameName,
        gameHash: gameHash,
        coreIdentifier: "com.provenance.dolphin",
        maxPlayers: 4,
        currentPlayers: players,
        isLAN: traversalCode == nil,
        hostAddress: traversalCode ?? "0.0.0.0",
        port: port,
        traversalCode: traversalCode
    )
}

@Suite("NetplayRoomTXTRecord")
struct NetplayRoomTXTRecordTests {

    @Test("A room survives a TXT round trip")
    func roundTrip() {
        let room = NetplayRoom(
            hostName: "Joe's Room",
            gameName: "Super Smash Bros. Melee",
            gameHash: "ABCDEF0123456789",
            coreIdentifier: "com.provenance.dolphin",
            maxPlayers: 4,
            currentPlayers: 2,
            isLAN: true,
            hostAddress: "0.0.0.0",
            port: 2626,
            isPasswordProtected: true,
            allowsSpectators: false,
            spectatorCount: 0,
            gameSerial: "GALE01",
            systemIdentifier: "com.provenance.gamecube"
        )
        let txt = NetplayRoomTXTRecord.txtRecord(for: room)
        let decoded = NetplayRoomTXTRecord.room(
            fromTXT: txt, serviceName: "ignored", hostAddress: "192.168.1.20", port: 2626
        )
        #expect(decoded.id == room.id)
        #expect(decoded.hostName == "Joe's Room")
        #expect(decoded.gameName == "Super Smash Bros. Melee")
        #expect(decoded.gameHash == "ABCDEF0123456789")
        #expect(decoded.gameSerial == "GALE01")
        #expect(decoded.systemIdentifier == "com.provenance.gamecube")
        #expect(decoded.coreIdentifier == "com.provenance.dolphin")
        #expect(decoded.maxPlayers == 4)
        #expect(decoded.currentPlayers == 2)
        #expect(decoded.isPasswordProtected)
        #expect(!decoded.allowsSpectators)
        #expect(decoded.hostAddress == "192.168.1.20")
        #expect(decoded.port == 2626)
        #expect(decoded.discoverySource == .bonjour)
    }

    @Test("Thin-wrapper TXT records without newer keys still decode")
    func legacyRecord() {
        let txt = ["nickname": "Host", "content": "Pokemon", "core": "gpsp", "maxPlayers": "2"]
        let room = NetplayRoomTXTRecord.room(fromTXT: txt, serviceName: "Host — Pokemon", hostAddress: "h.local.", port: 0)
        #expect(room.gameName == "Pokemon")
        #expect(room.gameHash.isEmpty)
        #expect(room.port == NetplayRoomTXTRecord.defaultPort)
        #expect(room.currentPlayers == 1)
        #expect(room.allowsSpectators)
        // No session id: the id comes from the service name, the same every time.
        #expect(room.id == NetplayRoomTXTRecord.stableID(forServiceName: "Host — Pokemon"))
    }

    @Test("Every TXT entry fits DNS-SD's 255-byte limit")
    func entryLimit() {
        let room = makeRoom(gameName: String(repeating: "é", count: 300))
        for (key, value) in NetplayRoomTXTRecord.txtRecord(for: room) {
            #expect(key.utf8.count + 1 + value.utf8.count <= 255)
        }
    }

    @Test("The instance name fits 63 bytes without splitting characters")
    func instanceName() {
        let room = makeRoom(gameName: String(repeating: "ポ", count: 40))
        let name = NetplayRoomTXTRecord.instanceName(for: room)
        #expect(name.utf8.count <= 63)
        #expect(name.hasPrefix("Joe — "))
    }

    @Test("The TXT record omits unknown hash, serial and system")
    func omitsEmptyKeys() {
        let txt = NetplayRoomTXTRecord.txtRecord(for: makeRoom())
        #expect(txt["hash"] == nil)
        #expect(txt["serial"] == nil)
        #expect(txt["system"] == nil)
    }

    #if canImport(Darwin)
    @Test("The TXT record encodes through NetService")
    func netServiceEncoding() {
        let room = makeRoom(gameName: "Mario Kart: Double Dash!!", gameHash: "1234")
        let txt = NetplayRoomTXTRecord.txtRecord(for: room).mapValues { Data($0.utf8) }
        let decoded = NetService.dictionary(fromTXTRecord: NetService.data(fromTXTRecord: txt))
            .compactMapValues { String(data: $0, encoding: .utf8) }
        #expect(decoded["game"] == "Mario Kart: Double Dash!!")
        #expect(decoded["hash"] == "1234")
    }
    #endif
}

@Suite("Host address selection")
struct HostAddressTests {

    private func sockaddrIn(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> Data {
        Data([16, 2, 0x0A, 0x42, a, b, c, d, 0, 0, 0, 0, 0, 0, 0, 0])
    }

    private func sockaddrIn6() -> Data {
        var bytes = [UInt8](repeating: 0, count: 28)
        bytes[0] = 28
        bytes[1] = 30
        bytes[8] = 0xfe
        bytes[9] = 0x80
        return Data(bytes)
    }

    @Test("An IPv4 address wins over the host name and IPv6")
    func prefersIPv4() {
        let address = NetplayRoomTXTRecord.preferredHostAddress(
            addresses: [sockaddrIn6(), sockaddrIn(192, 168, 1, 20)],
            hostName: "iPad.local."
        )
        #expect(address == "192.168.1.20")
    }

    @Test("Link-local and unspecified IPv4 fall back to the host name")
    func skipsUnusableIPv4() {
        let address = NetplayRoomTXTRecord.preferredHostAddress(
            addresses: [sockaddrIn(169, 254, 3, 4), sockaddrIn(0, 0, 0, 0)],
            hostName: "iPad.local."
        )
        #expect(address == "iPad.local.")
    }

    @Test("A slice of a larger buffer is read from its own start")
    func dataSlice() {
        let buffer = Data([0xFF, 0xFF]) + sockaddrIn(10, 0, 0, 7)
        let slice = buffer[2...]
        #expect(NetplayRoomTXTRecord.ipv4String(fromSockaddr: slice) == "10.0.0.7")
    }

    @Test("No address and no host name means the room can't be joined")
    func nothingUsable() {
        #expect(NetplayRoomTXTRecord.preferredHostAddress(addresses: [], hostName: nil) == nil)
        #expect(NetplayRoomTXTRecord.preferredHostAddress(addresses: [], hostName: "") == nil)
    }
}

@Suite("PVNetplayManager LAN advertisement")
struct ManagerAdvertisementTests {

    @Test("A direct session is published with the library's game details")
    func publishesHostedGame() throws {
        var settings = NetplaySettings.defaultLAN
        settings.roomName = "Joe's Room"
        let game = NetplayHostedGame(
            name: "Melee", md5: "MD5", serial: "GALE01",
            systemIdentifier: "com.provenance.gamecube", coreIdentifier: "ignored"
        )
        let room = try #require(PVNetplayManager.lanAdvertisement(for: makeRoom(port: 2626), settings: settings, game: game))
        #expect(room.hostName == "Joe's Room")
        #expect(room.gameName == "Melee")
        #expect(room.gameHash == "MD5")
        #expect(room.gameSerial == "GALE01")
        #expect(room.systemIdentifier == "com.provenance.gamecube")
        // The core's identifier wins over the caller's.
        #expect(room.coreIdentifier == "com.provenance.dolphin")
        #expect(room.port == 2626)
    }

    @Test("Traversal and relay sessions are not published on the LAN")
    func skipsRelaySessions() {
        var relayed = NetplaySettings.defaultLAN
        relayed.relayServer = "stun.dolphin-emu.org"
        #expect(PVNetplayManager.lanAdvertisement(for: makeRoom(), settings: relayed, game: nil) == nil)
        #expect(PVNetplayManager.lanAdvertisement(for: makeRoom(traversalCode: "abcd1234"), settings: .defaultLAN, game: nil) == nil)
    }

    @Test("A session with no known port is not published")
    func skipsUnknownPort() {
        var settings = NetplaySettings.defaultLAN
        settings.port = 0
        #expect(PVNetplayManager.lanAdvertisement(for: makeRoom(port: 0), settings: settings, game: nil) == nil)
    }

    @Test("A LAN room is joined directly whatever relay is stored")
    func joinRelay() {
        var lan = makeRoom()
        lan = NetplayRoom(
            id: lan.id, hostName: lan.hostName, gameName: "", gameHash: "", coreIdentifier: "",
            maxPlayers: 2, currentPlayers: 1, isLAN: true, hostAddress: "192.168.1.20", port: 2626,
            discoverySource: .bonjour
        )
        #expect(PVNetplayManager.relayServer(forJoining: lan, stored: "stun.example") == nil)
        #expect(PVNetplayManager.relayServer(forJoining: makeRoom(traversalCode: "code"), stored: nil) == "code")
        let manual = NetplayRoom(
            hostName: "", gameName: "", gameHash: "", coreIdentifier: "", maxPlayers: 2, currentPlayers: 1,
            isLAN: true, hostAddress: "10.0.0.2", port: 1, discoverySource: .manual
        )
        #expect(PVNetplayManager.relayServer(forJoining: manual, stored: "relay") == "relay")
    }
}

// MARK: - Lifecycle with a mock core

private final class RecordingAdvertiser: NetplayRoomAdvertising, @unchecked Sendable {
    private let lock = NSLock()
    private var _advertised: [NetplayRoom] = []
    private var _withdrawals = 0

    var advertised: [NetplayRoom] { lock.withLock { _advertised } }
    var withdrawals: Int { lock.withLock { _withdrawals } }

    @MainActor func advertise(_ room: NetplayRoom) { lock.withLock { _advertised.append(room) } }
    @MainActor func withdraw() { lock.withLock { _withdrawals += 1 } }
}

private final class HostingBridge: PVNetplayCapable, @unchecked Sendable {
    let advertisesOwnRoom: Bool
    private(set) var hosting = false

    init(advertisesOwnRoom: Bool) { self.advertisesOwnRoom = advertisesOwnRoom }

    var supportsNetplay: Bool { true }
    var netplayEngineName: String { "Mock" }
    var netplayAdvertisesOwnRoom: Bool { advertisesOwnRoom }
    func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws { hosting = true }
    func stopNetplay() async { hosting = false }
    var netplayState: NetplayState { hosting ? .hosting(room: makeRoom(port: 2626)) : .idle }
    #if canImport(Combine)
    var netplayStatePublisher: AnyPublisher<NetplayState, Never> { Empty().eraseToAnyPublisher() }
    #endif
}

@Suite("PVNetplayManager advertisement lifecycle")
struct ManagerAdvertisementLifecycleTests {

    @Test("Hosting publishes the room and disconnecting withdraws it")
    func hostAndDisconnect() async throws {
        let advertiser = RecordingAdvertiser()
        let manager = PVNetplayManager(advertiser: advertiser)
        let bridge = HostingBridge(advertisesOwnRoom: false)
        await manager.setActiveBridge(bridge)

        try await manager.host(settings: .defaultLAN, game: NetplayHostedGame(name: "Melee", md5: "MD5"))
        #expect(advertiser.advertised.count == 1)
        #expect(advertiser.advertised.first?.gameHash == "MD5")
        #expect(advertiser.advertised.first?.port == 2626)

        await manager.disconnect()
        #expect(advertiser.withdrawals == 1)
    }

    @Test("A core that advertises its own room is not published twice")
    func selfAdvertisingCore() async throws {
        let advertiser = RecordingAdvertiser()
        let manager = PVNetplayManager(advertiser: advertiser)
        // The manager holds its bridge weakly.
        let bridge = HostingBridge(advertisesOwnRoom: true)
        await manager.setActiveBridge(bridge)

        try await manager.host(settings: .defaultLAN)
        await manager.disconnect()
        #expect(advertiser.advertised.isEmpty)
        #expect(advertiser.withdrawals == 0)
        withExtendedLifetime(bridge) {}
    }

    @Test("A session the network ends withdraws the room")
    func networkEnded() async throws {
        let advertiser = RecordingAdvertiser()
        let manager = PVNetplayManager(advertiser: advertiser)
        let bridge = HostingBridge(advertisesOwnRoom: false)
        await manager.setActiveBridge(bridge)

        try await manager.host(settings: .defaultLAN)
        await manager.bridgeStateChanged(.hosting(room: makeRoom(port: 2626, players: 2)))
        #expect(advertiser.advertised.last?.currentPlayers == 2)

        await manager.bridgeStateChanged(.disconnected(reason: .networkError))
        #expect(advertiser.withdrawals == 1)
        withExtendedLifetime(bridge) {}
    }

    @Test("An unchanged room is not republished on every core tick")
    func unchangedRoomNotRepublished() async throws {
        let advertiser = RecordingAdvertiser()
        let manager = PVNetplayManager(advertiser: advertiser)
        let bridge = HostingBridge(advertisesOwnRoom: false)
        await manager.setActiveBridge(bridge)

        try await manager.host(settings: .defaultLAN)
        let hosted = makeRoom(port: 2626, players: 1)
        await manager.bridgeStateChanged(.hosting(room: hosted))
        await manager.bridgeStateChanged(.hosting(room: hosted))
        #expect(advertiser.advertised.count == 2) // host() + the first tick (new session id)
        await manager.bridgeStateChanged(.hosting(room: NetplayRoom(
            id: hosted.id, hostName: hosted.hostName, gameName: "", gameHash: "",
            coreIdentifier: hosted.coreIdentifier, maxPlayers: 4, currentPlayers: 2,
            isLAN: true, hostAddress: "0.0.0.0", port: 2626
        )))
        #expect(advertiser.advertised.count == 3)
        #expect(advertiser.advertised.last?.currentPlayers == 2)
        withExtendedLifetime(bridge) {}
    }
}
