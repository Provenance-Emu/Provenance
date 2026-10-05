//
//  NetpacketTransportTests.swift
//  PVNetplayTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Testing
import Foundation
@testable import PVNetplay

// MARK: - Unit Tests

@Suite("NetpacketTransport Unit Tests")
struct NetpacketTransportTests {

    @Test("Host transport has client ID 0")
    func hostClientID() {
        let transport = NetpacketTransport(role: .host(port: 55435))
        #expect(transport.localClientID == NetpacketTransport.hostID)
    }

    @Test("Stop is idempotent")
    func stopIdempotent() {
        let transport = NetpacketTransport(role: .host(port: 55435))
        transport.stop()
        transport.stop()
    }

    @Test("Send with no peers does not crash")
    func sendNoPeers() {
        let transport = NetpacketTransport(role: .host(port: 55435))
        transport.send(data: Data([1]), to: NetpacketFlags.broadcastID, flags: 0)
        transport.send(data: Data([1]), to: 3, flags: NetpacketFlags.reliable.rawValue)
    }

    @Test("Frames round-trip through encode and decodeHeader")
    func frameRoundTrip() throws {
        let frame = NetpacketTransport.Frame(kind: .data, from: 2, to: 0xFFFF, payload: Data([9, 8, 7]))
        let encoded = NetpacketTransport.encode(frame)
        #expect(encoded.count == NetpacketTransport.headerSize + 3)
        let header = try #require(NetpacketTransport.decodeHeader(encoded.prefix(NetpacketTransport.headerSize)))
        #expect(header.kind == .data)
        #expect(header.from == 2)
        #expect(header.to == 0xFFFF)
        #expect(header.length == 3)
        #expect(encoded.suffix(3) == Data([9, 8, 7]))
    }

    @Test("A header announcing an oversized payload is rejected")
    func oversizedHeader() {
        let header = Data([0x7F, 0xFF, 0xFF, 0xFF, 4, 0, 0, 0, 0])
        #expect(NetpacketTransport.decodeHeader(header) == nil)
    }

    @Test("A header with an unknown kind is rejected")
    func unknownKind() {
        #expect(NetpacketTransport.decodeHeader(Data([0, 0, 0, 0, 99, 0, 0, 0, 0])) == nil)
    }

    @Test("Hello carries the protocol version, and a foreign payload isn't a hello")
    func helloPayload() {
        let payload = NetpacketTransport.helloPayload(protocolVersion: "gpSP 1.0")
        #expect(NetpacketTransport.protocolVersion(fromHello: payload) == "gpSP 1.0")
        #expect(NetpacketTransport.protocolVersion(fromHello: Data("RANP\0\u{2}x".utf8)) == nil)
    }
}

// MARK: - NetpacketFlags Tests

@Suite("NetpacketFlags Tests")
struct NetpacketFlagsTests {

    @Test("Raw values match libretro.h constants")
    func rawValues() {
        #expect(NetpacketFlags.unreliable.rawValue == 0)
        #expect(NetpacketFlags.reliable.rawValue == 1)
        #expect(NetpacketFlags.unsequenced.rawValue == 2)
        #expect(NetpacketFlags.flushHint.rawValue == 4)
    }

    @Test("Broadcast ID is 0xFFFF")
    func broadcastID() {
        #expect(NetpacketFlags.broadcastID == 0xFFFF)
    }

    @Test("OptionSet operations work")
    func optionSetCombination() {
        let combined: NetpacketFlags = [.reliable, .flushHint]
        #expect(combined.rawValue == 5)
        #expect(combined.contains(.reliable))
        #expect(combined.contains(.flushHint))
        #expect(!combined.contains(.unsequenced))
    }

    @Test("Reliable and unsequenced can combine")
    func reliableUnsequenced() {
        let flags: NetpacketFlags = [.reliable, .unsequenced]
        #expect(flags.rawValue == 3)
    }
}

// MARK: - Error Tests

@Suite("NetpacketTransportError Tests")
struct NetpacketTransportErrorTests {

    @Test("All error descriptions are non-empty")
    func descriptions() {
        let cases: [NetpacketTransportError] = [
            .cancelled,
            .handshakeFailed,
            .connectionFailed("timeout")
        ]
        for error in cases {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test("connectionFailed includes the reason")
    func connectionFailedReason() {
        let error = NetpacketTransportError.connectionFailed("port in use")
        #expect(error.errorDescription?.contains("port in use") == true)
    }

    @Test("Conforms to LocalizedError")
    func localizedError() {
        let error: any LocalizedError = NetpacketTransportError.handshakeFailed
        #expect(error.errorDescription != nil)
    }

    @Test("Conforms to Sendable")
    func sendable() {
        let error: any Sendable = NetpacketTransportError.cancelled
        _ = error
    }
}

// MARK: - DiscoverySource Tests

@Suite("DiscoverySource Netpacket Tests")
struct DiscoverySourceTests {

    @Test("Netpacket case exists with correct raw value")
    func netpacketCase() {
        let source = DiscoverySource.netpacket
        #expect(source.rawValue == "netpacket")
    }

    @Test("Netpacket case is distinct from other cases")
    func distinctFromOthers() {
        #expect(DiscoverySource.netpacket != .bonjour)
        #expect(DiscoverySource.netpacket != .multipeer)
        #expect(DiscoverySource.netpacket != .manual)
    }

    @Test("Netpacket case round-trips through Codable")
    func codableRoundTrip() throws {
        let original = DiscoverySource.netpacket
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DiscoverySource.self, from: encoded)
        #expect(decoded == original)
    }
}

// MARK: - Protocol Hierarchy Tests

@Suite("PVNetpacketCapable Protocol Tests")
struct NetpacketCapableTests {

    @Test("PVNetpacketCapable extends PVNetplayCapable")
    func protocolHierarchy() {
        func acceptNetpacket(_ capable: any PVNetpacketCapable) {
            let _: any PVNetplayCapable = capable
        }
    }
}

// MARK: - NetplayRoom Netpacket Tests

@Suite("NetplayRoom Netpacket Integration Tests")
struct NetplayRoomNetpacketTests {

    @Test("NetplayRoom can be created with netpacket discovery source")
    func roomWithNetpacketSource() {
        let room = NetplayRoom(
            hostName: "Test Host",
            gameName: "Test Game",
            gameHash: "abc123",
            coreIdentifier: "com.provenance.test",
            maxPlayers: 4,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: "192.168.1.100",
            port: 55435,
            discoverySource: .netpacket
        )
        #expect(room.discoverySource == .netpacket)
        #expect(room.hasOpenSlots)
        #expect(!room.isFull)
        #expect(room.playerCountDisplay == "1/4 players")
    }
}

// MARK: - Loopback

/// Collects callback values from the transport's queue.
private final class Inbox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Value] = []

    func append(_ value: Value) {
        lock.lock(); values.append(value); lock.unlock()
    }

    var all: [Value] {
        lock.lock(); defer { lock.unlock() }
        return values
    }

    /// Waits until `count` values arrived, or `timeout` passed.
    @discardableResult
    func wait(for count: Int, timeout: TimeInterval = 5) async -> [Value] {
        let deadline = Date().addingTimeInterval(timeout)
        while all.count < count && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return all
    }
}

private struct Packet: Equatable, Sendable {
    let data: Data
    let from: UInt16
}

private func startHost(protocolVersion: String = "core 1", maxClients: Int = 15) async throws -> (NetpacketTransport, UInt16) {
    let host = NetpacketTransport(role: .host(port: 0), protocolVersion: protocolVersion, maxClients: maxClients)
    try await host.start()
    let port = try #require(host.listeningPort)
    return (host, port)
}

private func client(_ port: UInt16, protocolVersion: String = "core 1") -> NetpacketTransport {
    NetpacketTransport(role: .client(host: "127.0.0.1", port: port), protocolVersion: protocolVersion)
}

@Suite("NetpacketTransport Loopback Tests", .serialized)
struct NetpacketLoopbackTests {

    @Test("Host reports the port it bound when asked for any port")
    func listeningPort() async throws {
        let (host, port) = try await startHost()
        defer { host.stop() }
        #expect(port != 0)
    }

    @Test("A client gets an ID from the host and the host sees it connect")
    func handshake() async throws {
        let (host, port) = try await startHost()
        defer { host.stop() }
        let connected = Inbox<UInt16>()
        host.onPeerConnected = { connected.append($0) }

        let joiner = client(port)
        defer { joiner.stop() }
        try await joiner.start()

        #expect(joiner.localClientID == 1)
        #expect(await connected.wait(for: 1) == [1])
        #expect(host.connectedPeerIDs == [1])
    }

    @Test("Packets arrive intact both ways, back-to-back and up to 64 KB")
    func dataBothWays() async throws {
        let (host, port) = try await startHost()
        defer { host.stop() }
        let atHost = Inbox<Packet>()
        host.onPacket = { atHost.append(Packet(data: $0, from: $1)) }

        let joiner = client(port)
        defer { joiner.stop() }
        let atClient = Inbox<Packet>()
        joiner.onPacket = { atClient.append(Packet(data: $0, from: $1)) }
        try await joiner.start()

        let large = Data((0..<NetpacketTransport.maxPayloadSize).map { UInt8(truncatingIfNeeded: $0 &* 31) })
        let payloads = [Data([1]), Data([2, 2]), large, Data([3, 3, 3])]
        for (index, payload) in payloads.enumerated() {
            let flags = index.isMultiple(of: 2) ? NetpacketFlags.reliable.rawValue : NetpacketFlags.unreliable.rawValue
            joiner.send(data: payload, to: NetpacketTransport.hostID, flags: flags)
            host.send(data: payload, to: 1, flags: flags)
        }

        #expect(await atHost.wait(for: 4) == payloads.map { Packet(data: $0, from: 1) })
        #expect(await atClient.wait(for: 4) == payloads.map { Packet(data: $0, from: 0) })
    }

    @Test("A client hears it was welcomed before the host's first packet")
    func welcomedBeforeFirstPacket() async throws {
        let (host, port) = try await startHost()
        defer { host.stop() }
        // The host's core sends as soon as it sees the client.
        host.onPeerConnected = { [weak host] clientID in
            host?.send(data: Data([0x42]), to: clientID, flags: NetpacketFlags.reliable.rawValue)
        }
        let joiner = client(port)
        defer { joiner.stop() }
        let events = Inbox<String>()
        joiner.onWelcomed = { events.append("welcomed \($0)") }
        joiner.onPacket = { data, from in events.append("packet \(from) \([UInt8](data))") }

        try await joiner.start()

        #expect(await events.wait(for: 2) == ["welcomed 1", "packet 0 [66]"])
    }

    @Test("A packet over 64 KB is dropped")
    func oversizedPacket() async throws {
        let (host, port) = try await startHost()
        defer { host.stop() }
        let atHost = Inbox<Packet>()
        host.onPacket = { atHost.append(Packet(data: $0, from: $1)) }
        let joiner = client(port)
        defer { joiner.stop() }
        try await joiner.start()

        joiner.send(data: Data(count: NetpacketTransport.maxPayloadSize + 1), to: 0, flags: 0)
        joiner.send(data: Data([7]), to: 0, flags: 0)

        #expect(await atHost.wait(for: 1) == [Packet(data: Data([7]), from: 1)])
    }

    @Test("The host relays a client's broadcast and direct packets to other clients")
    func relay() async throws {
        let (host, port) = try await startHost()
        defer { host.stop() }
        let atHost = Inbox<Packet>()
        host.onPacket = { atHost.append(Packet(data: $0, from: $1)) }

        let first = client(port)
        let second = client(port)
        defer { first.stop(); second.stop() }
        let atFirst = Inbox<Packet>()
        let atSecond = Inbox<Packet>()
        first.onPacket = { atFirst.append(Packet(data: $0, from: $1)) }
        second.onPacket = { atSecond.append(Packet(data: $0, from: $1)) }
        try await first.start()
        try await second.start()
        #expect(first.localClientID == 1)
        #expect(second.localClientID == 2)

        first.send(data: Data([0xB]), to: NetpacketFlags.broadcastID, flags: 0)
        first.send(data: Data([0xD]), to: 2, flags: 0)

        #expect(await atHost.wait(for: 1) == [Packet(data: Data([0xB]), from: 1)])
        #expect(await atSecond.wait(for: 2) == [Packet(data: Data([0xB]), from: 1), Packet(data: Data([0xD]), from: 1)])
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(atFirst.all.isEmpty)
    }

    @Test("A client with a different core version is refused")
    func versionMismatch() async throws {
        let (host, port) = try await startHost(protocolVersion: "core 1")
        defer { host.stop() }
        let joiner = client(port, protocolVersion: "core 2")
        defer { joiner.stop() }
        await #expect(throws: NetpacketTransportError.self) { try await joiner.start() }
        #expect(host.connectedPeerIDs.isEmpty)
    }

    @Test("A full room refuses another client")
    func roomFull() async throws {
        let (host, port) = try await startHost(maxClients: 1)
        defer { host.stop() }
        let first = client(port)
        let second = client(port)
        defer { first.stop(); second.stop() }
        try await first.start()
        do {
            try await second.start()
            Issue.record("second client was admitted")
        } catch let error as NetpacketTransportError {
            guard case .rejected = error else {
                Issue.record("expected a rejection, got \(error)")
                return
            }
        }
    }

    @Test("The host sees a client leave")
    func clientLeaves() async throws {
        let (host, port) = try await startHost()
        defer { host.stop() }
        let disconnected = Inbox<UInt16>()
        host.onPeerDisconnected = { disconnected.append($0) }
        let joiner = client(port)
        try await joiner.start()

        joiner.stop()

        #expect(await disconnected.wait(for: 1) == [1])
        #expect(host.connectedPeerIDs.isEmpty)
    }

    @Test("A client learns the host closed the session")
    func hostCloses() async throws {
        let (host, port) = try await startHost()
        let joiner = client(port)
        defer { joiner.stop() }
        let ended = Inbox<NetpacketTransportError>()
        joiner.onSessionEnded = { ended.append($0) }
        try await joiner.start()

        host.stop()

        #expect(await ended.wait(for: 1).count == 1)
    }

    @Test("No callback fires after stop")
    func stopClearsCallbacks() async throws {
        let (host, port) = try await startHost()
        let disconnected = Inbox<UInt16>()
        host.onPeerDisconnected = { disconnected.append($0) }
        let joiner = client(port)
        defer { joiner.stop() }
        try await joiner.start()

        host.stop()
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(disconnected.all.isEmpty)
    }

    @Test("Joining a port nobody listens on fails instead of hanging")
    func nobodyListening() async throws {
        let (host, port) = try await startHost()
        host.stop()
        let joiner = client(port)
        defer { joiner.stop() }
        await #expect(throws: NetpacketTransportError.self) { try await joiner.start() }
    }

    @Test("Concurrent sends and stops don't crash")
    func concurrentSendStop() async throws {
        let (host, _) = try await startHost()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<50 {
                group.addTask {
                    host.send(data: Data([UInt8(index)]), to: NetpacketFlags.broadcastID, flags: 0)
                    if index.isMultiple(of: 10) { host.stop() }
                }
            }
        }
    }
}
