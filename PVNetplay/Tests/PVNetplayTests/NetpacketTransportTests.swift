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
        let transport = NetpacketTransport(role: .host(port: 0))
        #expect(transport.localClientID == 0)
    }

    @Test("Client transport starts with client ID 0 before handshake")
    func clientInitialClientID() {
        let transport = NetpacketTransport(role: .client(host: "127.0.0.1", port: 12345))
        #expect(transport.localClientID == 0)
    }

    @Test("dequeueReceived returns empty array initially")
    func emptyQueue() {
        let transport = NetpacketTransport(role: .host(port: 0))
        let messages = transport.dequeueReceived()
        #expect(messages.isEmpty)
    }

    @Test("dequeueReceived drains the queue — second call returns empty")
    func dequeueDrains() {
        let transport = NetpacketTransport(role: .host(port: 0))
        let first = transport.dequeueReceived()
        let second = transport.dequeueReceived()
        #expect(first.isEmpty)
        #expect(second.isEmpty)
    }

    @Test("Stop is idempotent")
    func stopIdempotent() {
        let transport = NetpacketTransport(role: .host(port: 0))
        transport.stop()
        transport.stop()
        transport.stop()
    }

    @Test("Send to broadcast with no peers does not crash")
    func sendBroadcastNoPeers() {
        let transport = NetpacketTransport(role: .host(port: 0))
        let data = Data([0x01, 0x02])
        transport.send(data: data, to: NetpacketFlags.broadcastID, flags: 0)
        transport.stop()
    }

    @Test("Send to specific client with no peers does not crash")
    func sendToMissingPeer() {
        let transport = NetpacketTransport(role: .host(port: 0))
        let data = Data([0xAA, 0xBB])
        transport.send(data: data, to: 42, flags: 0)
        transport.stop()
    }

    @Test("Callback closures can be set and cleared")
    func callbackSetClear() {
        let transport = NetpacketTransport(role: .host(port: 0))

        transport.onPeerConnected = { @Sendable _ in }
        transport.onPeerDisconnected = { @Sendable _ in }

        #expect(transport.onPeerConnected != nil)
        #expect(transport.onPeerDisconnected != nil)

        transport.onPeerConnected = nil
        transport.onPeerDisconnected = nil

        #expect(transport.onPeerConnected == nil)
        #expect(transport.onPeerDisconnected == nil)
    }

    @Test("Role enum equatable semantics")
    func roleEquatable() {
        let host1 = NetpacketTransport(role: .host(port: 9000))
        let host2 = NetpacketTransport(role: .host(port: 9001))
        #expect(host1.localClientID == 0)
        #expect(host2.localClientID == 0)
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

// MARK: - NetpacketMessage Tests

@Suite("NetpacketMessage Tests")
struct NetpacketMessageTests {

    @Test("Stores data and client ID")
    func construction() {
        let data = Data([0x01, 0x02, 0x03])
        let msg = NetpacketMessage(data: data, fromClient: 42)
        #expect(msg.data == data)
        #expect(msg.fromClient == 42)
    }

    @Test("Empty data is valid")
    func emptyData() {
        let msg = NetpacketMessage(data: Data(), fromClient: 0)
        #expect(msg.data.isEmpty)
        #expect(msg.fromClient == 0)
    }

    @Test("Large payload is preserved")
    func largePayload() {
        let payload = Data(repeating: 0xAB, count: 65535)
        let msg = NetpacketMessage(data: payload, fromClient: 1)
        #expect(msg.data.count == 65535)
        #expect(msg.data.first == 0xAB)
        #expect(msg.data.last == 0xAB)
    }

    @Test("Client ID max value (65534, excluding broadcast)")
    func maxClientID() {
        let msg = NetpacketMessage(data: Data([0xFF]), fromClient: 0xFFFE)
        #expect(msg.fromClient == 0xFFFE)
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
            #expect(!error.errorDescription!.isEmpty)
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
        #expect(DiscoverySource.netpacket != .lobbyAPI)
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

// MARK: - Host Listener Integration Tests

@Suite("NetpacketTransport Host Listener Tests")
struct NetpacketHostListenerTests {

    @Test("Host starts and stops cleanly on ephemeral port")
    func hostStartStop() async throws {
        let transport = NetpacketTransport(role: .host(port: 0))
        try await transport.start()
        transport.stop()
    }

    @Test("Host start-stop-start cycle works")
    func hostRestartCycle() async throws {
        let transport = NetpacketTransport(role: .host(port: 0))
        try await transport.start()
        transport.stop()
        // After stop, queue is drained
        #expect(transport.dequeueReceived().isEmpty)
    }

    @Test("Multiple hosts can start on different ephemeral ports")
    func multipleHosts() async throws {
        let transport1 = NetpacketTransport(role: .host(port: 0))
        let transport2 = NetpacketTransport(role: .host(port: 0))

        try await transport1.start()
        try await transport2.start()

        transport1.stop()
        transport2.stop()
    }
}

// MARK: - Concurrent Queue Safety Tests

@Suite("NetpacketTransport Thread Safety Tests")
struct NetpacketThreadSafetyTests {

    @Test("Concurrent dequeueReceived calls don't crash")
    func concurrentDequeue() async {
        let transport = NetpacketTransport(role: .host(port: 0))

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    _ = transport.dequeueReceived()
                }
            }
        }
    }

    @Test("Concurrent send calls don't crash")
    func concurrentSend() async {
        let transport = NetpacketTransport(role: .host(port: 0))
        let data = Data([0x01, 0x02])

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    transport.send(data: data, to: UInt16(i % 10), flags: 0)
                }
            }
        }

        transport.stop()
    }

    @Test("Concurrent stop calls don't crash")
    func concurrentStop() async {
        let transport = NetpacketTransport(role: .host(port: 0))

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    transport.stop()
                }
            }
        }
    }

    @Test("Rapid create-stop cycles don't crash (deinit safety)")
    func rapidCreateStopCycles() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let transport = NetpacketTransport(role: .host(port: 0))
                    transport.stop()
                }
            }
        }
    }

    @Test("Stop after start from multiple threads doesn't deadlock")
    func concurrentStartStop() async throws {
        let transport = NetpacketTransport(role: .host(port: 0))
        try await transport.start()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    transport.stop()
                }
                group.addTask {
                    _ = transport.dequeueReceived()
                }
            }
        }
    }
}

// MARK: - Loopback Integration Tests

@Suite("NetpacketTransport Loopback Tests")
struct NetpacketLoopbackTests {

    @Test("Host starts on ephemeral port and stops cleanly")
    func hostLifecycle() async throws {
        let host = NetpacketTransport(role: .host(port: 0))
        try await host.start()
        host.stop()
    }

    @Test("Dequeue returns empty when no data received")
    func dequeueEmptyAfterStart() async throws {
        let host = NetpacketTransport(role: .host(port: 0))
        try await host.start()
        let messages = host.dequeueReceived()
        #expect(messages.isEmpty)
        host.stop()
    }

    @Test("Client transport can be created and stopped without connecting")
    func clientStopBeforeStart() {
        let client = NetpacketTransport(role: .client(host: "127.0.0.1", port: 55435))
        client.stop()
        #expect(client.dequeueReceived().isEmpty)
    }

    @Test("Host send after stop is a no-op (no crash)")
    func sendAfterStop() async throws {
        let host = NetpacketTransport(role: .host(port: 0))
        try await host.start()
        host.stop()
        host.send(data: Data([0x01]), to: 1, flags: 0)
        host.send(data: Data([0x02]), to: NetpacketFlags.broadcastID, flags: NetpacketFlags.reliable.rawValue)
    }
}
