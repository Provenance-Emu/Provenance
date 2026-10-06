//
//  PVmGBALinkTests.swift
//  PVCoremGBA
//
//  Loopback tests for the link cable transport: a host and a client session
//  in one process, talking over 127.0.0.1 / ::1.
//

import Foundation
import PVmGBALink
import XCTest

/// Hands a value from a background thread back to the test.
private final class Box<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) { stored = value }

    var value: Value {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}

final class PVmGBALinkTests: XCTestCase {
    private var sessions: [OpaquePointer] = []

    override func tearDown() {
        sessions.forEach { PVGBALinkSessionDestroy($0) }
        sessions = []
        super.tearDown()
    }

    private func makeSession() -> OpaquePointer {
        guard let session = PVGBALinkSessionCreate() else {
            preconditionFailure("PVGBALinkSessionCreate failed")
        }
        sessions.append(session)
        return session
    }

    private struct Pair {
        let host: OpaquePointer
        let client: OpaquePointer
        let connectResult: PVGBALinkResult
    }

    /// Listens on a free port, accepts on a background thread and connects.
    /// Fails the test unless both sides finish the handshake.
    private func connectPair(address: String = "127.0.0.1",
                             hostPassword: String? = nil,
                             clientPassword: String? = nil) -> Pair {
        let host = makeSession()
        let client = makeSession()
        var port: UInt16 = 0
        XCTAssertEqual(PVGBALinkSessionListen(host, 0, hostPassword, &port), PVGBALinkOK)
        XCTAssertNotEqual(port, 0, "port 0 must report the port actually bound")

        let acceptResult = Box(PVGBALinkErrorState)
        let accepted = expectation(description: "accept returned")
        Thread.detachNewThread {
            acceptResult.value = PVGBALinkSessionAccept(host, 5000)
            accepted.fulfill()
        }
        let connectResult = PVGBALinkSessionConnect(client, address, port, clientPassword, 5000)
        if connectResult == PVGBALinkOK {
            wait(for: [accepted], timeout: 6)
            XCTAssertEqual(acceptResult.value, PVGBALinkOK)
        }
        return Pair(host: host, client: client, connectResult: connectResult)
    }

    private func receive(_ session: OpaquePointer, timeoutMs: Int32 = 2000) -> PVGBALinkMessage? {
        var message = PVGBALinkMessage()
        return PVGBALinkSessionReceive(session, &message, timeoutMs) == 1 ? message : nil
    }

    private func message(_ type: PVGBALinkMessageType, player: UInt8, time: UInt64,
                         finish: UInt64 = 0, mode: Int8 = -1,
                         data: (UInt32, UInt32, UInt32, UInt32) = (0, 0, 0, 0)) -> PVGBALinkMessage {
        PVGBALinkMessage(type: UInt8(type.rawValue), player: player, mode: mode, reserved: 0,
                         time: time, finish: finish, data: data)
    }

    // MARK: - Wire format

    func testWireEncodingRoundTrips() {
        let original = message(PVGBALinkMessageTransferStart, player: 3, time: 0x1_2345_6789_ABCD,
                               finish: 0xFFFF_FFFF_0000_0001, mode: -1,
                               data: (0xFFFF, 0x1234, 0xDEAD_BEEF, 0))
        var bytes = [UInt8](repeating: 0, count: Int(PVGBALINK_WIRE_SIZE))
        PVGBALinkEncode([original], &bytes)
        var decoded = PVGBALinkMessage()
        PVGBALinkDecode(bytes, &decoded)

        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.player, 3)
        XCTAssertEqual(decoded.mode, -1)
        XCTAssertEqual(decoded.time, original.time)
        XCTAssertEqual(decoded.finish, original.finish)
        XCTAssertEqual(decoded.data.0, 0xFFFF)
        XCTAssertEqual(decoded.data.2, 0xDEAD_BEEF)
        // Little-endian on the wire regardless of host byte order.
        XCTAssertEqual(Array(bytes[4..<6]), [0xCD, 0xAB])
    }

    // MARK: - Handshake

    func testHandshakeAssignsPlayers() {
        let pair = connectPair()
        XCTAssertEqual(pair.connectResult, PVGBALinkOK)
        XCTAssertEqual(PVGBALinkSessionPlayerId(pair.host), 0)
        XCTAssertEqual(PVGBALinkSessionPlayerId(pair.client), 1)
        XCTAssertEqual(PVGBALinkSessionPlayerCount(pair.host), 2)
        XCTAssertEqual(PVGBALinkSessionPlayerCount(pair.client), 2)
    }

    func testIPv6ClientReachesDualStackHost() {
        let pair = connectPair(address: "::1")
        XCTAssertEqual(pair.connectResult, PVGBALinkOK)
    }

    func testMatchingPasswordIsAccepted() {
        let pair = connectPair(hostPassword: "pikachu", clientPassword: "pikachu")
        XCTAssertEqual(pair.connectResult, PVGBALinkOK)
    }

    func testWrongPasswordIsRejectedAndHostKeepsListening() {
        let host = makeSession()
        let client = makeSession()
        var port: UInt16 = 0
        XCTAssertEqual(PVGBALinkSessionListen(host, 0, "pikachu", &port), PVGBALinkOK)

        let acceptResult = Box(PVGBALinkOK)
        let accepted = expectation(description: "accept returned")
        Thread.detachNewThread {
            acceptResult.value = PVGBALinkSessionAccept(host, -1)
            accepted.fulfill()
        }
        XCTAssertEqual(PVGBALinkSessionConnect(client, "127.0.0.1", port, "eevee", 5000),
                       PVGBALinkErrorWrongPassword)

        // The host is still waiting for a real partner; stopping cancels it.
        PVGBALinkSessionStop(host)
        wait(for: [accepted], timeout: 2)
        XCTAssertEqual(acceptResult.value, PVGBALinkErrorCancelled)
    }

    // MARK: - Cancellation

    func testStopInterruptsBlockedAccept() {
        let host = makeSession()
        var port: UInt16 = 0
        XCTAssertEqual(PVGBALinkSessionListen(host, 0, nil, &port), PVGBALinkOK)

        let acceptResult = Box(PVGBALinkOK)
        let accepted = expectation(description: "accept returned")
        Thread.detachNewThread {
            acceptResult.value = PVGBALinkSessionAccept(host, -1)
            accepted.fulfill()
        }
        Thread.sleep(forTimeInterval: 0.2)
        let stopped = Date()
        PVGBALinkSessionStop(host)
        wait(for: [accepted], timeout: 2)
        XCTAssertEqual(acceptResult.value, PVGBALinkErrorCancelled)
        XCTAssertLessThan(Date().timeIntervalSince(stopped), 1)
    }

    // MARK: - Messaging

    func testMessagesArriveInOrderBothWays() {
        let pair = connectPair()
        XCTAssertEqual(PVGBALinkSessionStart(pair.host, nil, nil), PVGBALinkOK)
        XCTAssertEqual(PVGBALinkSessionStart(pair.client, nil, nil), PVGBALinkOK)

        // Host: clock advances (each taken before the next is sent, so they
        // can't coalesce), then a transfer.
        for time: UInt64 in [4096, 8192, 12288] {
            XCTAssertEqual(PVGBALinkSessionSend(pair.host, [message(PVGBALinkMessageAdvance, player: 0, time: time)]),
                           PVGBALinkOK)
            let advance = receive(pair.client)
            XCTAssertEqual(advance?.type, UInt8(PVGBALinkMessageAdvance.rawValue))
            XCTAssertEqual(advance?.time, time)
        }
        let start = message(PVGBALinkMessageTransferStart, player: 0, time: 12300, finish: 28541,
                            mode: 2, data: (0x7FFF, 0, 0, 0))
        XCTAssertEqual(PVGBALinkSessionSend(pair.host, [start]), PVGBALinkOK)
        let received = receive(pair.client)
        XCTAssertEqual(received?.type, UInt8(PVGBALinkMessageTransferStart.rawValue))
        XCTAssertEqual(received?.finish, 28541)
        XCTAssertEqual(received?.mode, 2)
        XCTAssertEqual(received?.data.0, 0x7FFF)

        // Client: the acknowledgement goes the other way.
        let ack = message(PVGBALinkMessageTransferAck, player: 1, time: 12300, data: (0x1234, 0, 0, 0))
        XCTAssertEqual(PVGBALinkSessionSend(pair.client, [ack]), PVGBALinkOK)
        let receivedAck = receive(pair.host)
        XCTAssertEqual(receivedAck?.player, 1)
        XCTAssertEqual(receivedAck?.data.0, 0x1234)

        // Nothing else queued: a zero-timeout receive returns at once.
        var none = PVGBALinkMessage()
        XCTAssertEqual(PVGBALinkSessionReceive(pair.host, &none, 0), 0)
    }

    func testPeerStopClosesTheOtherSide() {
        let pair = connectPair()
        let closedReason = Box(PVGBALinkCloseNone)
        let closed = expectation(description: "closed callback")
        let context = Unmanaged.passRetained(CallbackContext { reason in
            closedReason.value = reason
            closed.fulfill()
        })
        defer { context.release() }

        XCTAssertEqual(PVGBALinkSessionStart(pair.host, { context, reason in
            guard let context else { return }
            Unmanaged<CallbackContext>.fromOpaque(context).takeUnretainedValue().handler(reason)
        }, context.toOpaque()), PVGBALinkOK)
        XCTAssertEqual(PVGBALinkSessionStart(pair.client, nil, nil), PVGBALinkOK)

        PVGBALinkSessionStop(pair.client)

        wait(for: [closed], timeout: 3)
        XCTAssertEqual(closedReason.value, PVGBALinkClosePeerLeft)
        var message = PVGBALinkMessage()
        XCTAssertEqual(PVGBALinkSessionReceive(pair.host, &message, 100), -1)
        XCTAssertTrue(PVGBALinkSessionIsClosed(pair.host))
        XCTAssertEqual(PVGBALinkSessionSend(pair.host, [message]), PVGBALinkErrorClosed)
        // A local stop is not reported through the callback.
        XCTAssertEqual(PVGBALinkSessionCloseReason(pair.client), PVGBALinkCloseLocal)
    }

    func testQueuedMessagesSurviveTheClose() {
        let pair = connectPair()
        XCTAssertEqual(PVGBALinkSessionStart(pair.host, nil, nil), PVGBALinkOK)
        XCTAssertEqual(PVGBALinkSessionStart(pair.client, nil, nil), PVGBALinkOK)

        XCTAssertEqual(PVGBALinkSessionSend(pair.client, [message(PVGBALinkMessageSync, player: 1, time: 77)]),
                       PVGBALinkOK)
        PVGBALinkSessionStop(pair.client)

        // The sync was sent before the goodbye, so it is delivered first.
        XCTAssertEqual(receive(pair.host)?.time, 77)
        var message = PVGBALinkMessage()
        XCTAssertEqual(PVGBALinkSessionReceive(pair.host, &message, 2000), -1)
    }

    // MARK: - Raw peer

    /// A started host session with a hand-driven client that finished the
    /// handshake.
    private func rawPair() -> (host: OpaquePointer, peer: RawPeer)? {
        let host = makeSession()
        var port: UInt16 = 0
        XCTAssertEqual(PVGBALinkSessionListen(host, 0, nil, &port), PVGBALinkOK)
        let acceptResult = Box(PVGBALinkErrorState)
        let accepted = expectation(description: "accept returned")
        Thread.detachNewThread {
            acceptResult.value = PVGBALinkSessionAccept(host, 5000)
            accepted.fulfill()
        }
        guard let peer = RawPeer(port: port) else {
            XCTFail("raw connect failed")
            return nil
        }
        peer.write(Wire.hello())
        let welcome = peer.read(count: Wire.size).map(Wire.decode)
        XCTAssertEqual(welcome?.type, Wire.welcome)
        wait(for: [accepted], timeout: 6)
        XCTAssertEqual(acceptResult.value, PVGBALinkOK)
        XCTAssertEqual(PVGBALinkSessionStart(host, nil, nil), PVGBALinkOK)
        return (host, peer)
    }

    private func waitUntilClosed(_ session: OpaquePointer, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !PVGBALinkSessionIsClosed(session) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        return PVGBALinkSessionIsClosed(session)
    }

    func testMessagesSplitAcrossReadsAreReassembled() throws {
        let (host, peer) = try XCTUnwrap(rawPair())
        let messages = [
            message(PVGBALinkMessageTransferAck, player: 1, time: 100, data: (0xB001, 0, 0, 0)),
            message(PVGBALinkMessageMode, player: 1, time: 200, mode: 2),
            message(PVGBALinkMessageTransferAck, player: 1, time: 300, data: (0xB002, 0, 0, 0))
        ]
        let stream = messages.flatMap(Wire.bytes)
        // Cut mid-message, and across message boundaries.
        for range in [0..<10, 10..<60, 60..<stream.count] {
            peer.write(Array(stream[range]))
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertEqual(receive(host)?.data.0, 0xB001)
        XCTAssertEqual(receive(host)?.mode, 2)
        XCTAssertEqual(receive(host)?.data.0, 0xB002)
    }

    func testConsecutiveClockMessagesCoalesce() throws {
        let (host, peer) = try XCTUnwrap(rawPair())
        var stream: [UInt8] = []
        for time: UInt64 in 1...5 {
            stream += Wire.bytes(message(PVGBALinkMessageSync, player: 1, time: time))
        }
        stream += Wire.bytes(message(PVGBALinkMessageMode, player: 1, time: 5, mode: 2))
        for time: UInt64 in 6...7 {
            stream += Wire.bytes(message(PVGBALinkMessageSync, player: 1, time: time))
        }
        peer.write(stream)
        Thread.sleep(forTimeInterval: 0.3)

        // Five syncs became the newest; the mode change kept its place.
        XCTAssertEqual(receive(host)?.time, 5)
        XCTAssertEqual(receive(host)?.type, UInt8(PVGBALinkMessageMode.rawValue))
        XCTAssertEqual(receive(host)?.time, 7)
        var none = PVGBALinkMessage()
        XCTAssertEqual(PVGBALinkSessionReceive(host, &none, 0), 0)
    }

    func testFloodingTheInboxClosesTheSession() throws {
        let (host, peer) = try XCTUnwrap(rawPair())
        // Mode changes don't coalesce, and nobody takes them.
        let flood = (0..<4200).flatMap { index in
            Wire.bytes(message(PVGBALinkMessageMode, player: 1, time: UInt64(index), mode: 2))
        }
        peer.write(flood)
        XCTAssertTrue(waitUntilClosed(host, timeout: 3))
        XCTAssertEqual(PVGBALinkSessionCloseReason(host), PVGBALinkCloseProtocolError)
    }

    func testSilentPeerTimesOut() throws {
        // The raw peer stays connected but never sends a heartbeat.
        let (host, peer) = try XCTUnwrap(rawPair())
        withExtendedLifetime(peer) {
            XCTAssertTrue(waitUntilClosed(host, timeout: 8))
        }
        XCTAssertEqual(PVGBALinkSessionCloseReason(host), PVGBALinkCloseTimeout)
    }

    func testVersionMismatchIsRejected() throws {
        let host = makeSession()
        var port: UInt16 = 0
        XCTAssertEqual(PVGBALinkSessionListen(host, 0, nil, &port), PVGBALinkOK)
        let accepted = expectation(description: "accept returned")
        Thread.detachNewThread {
            _ = PVGBALinkSessionAccept(host, -1)
            accepted.fulfill()
        }
        let peer = try XCTUnwrap(RawPeer(port: port))
        peer.write(Wire.hello(version: PVGBALINK_PROTOCOL_VERSION + 1))
        let reply = peer.read(count: Wire.size).map(Wire.decode)
        XCTAssertEqual(reply?.type, Wire.reject)
        XCTAssertEqual(reply?.data.0, Wire.rejectVersion)

        PVGBALinkSessionStop(host)
        wait(for: [accepted], timeout: 2)
    }
}

/// A bare TCP socket speaking the wire format by hand, to test what the
/// session does with input the PVmGBALink API never sends.
private final class RawPeer {
    private let fd: Int32

    init?(port: UInt16) {
        fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let fd = self.fd
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        // On failure deinit closes the socket.
        guard connected == 0 else { return nil }
        var one: Int32 = 1
        setsockopt(fd, Int32(IPPROTO_TCP), TCP_NODELAY, &one, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
    }

    deinit { close(fd) }

    @discardableResult
    func write(_ bytes: [UInt8]) -> Bool {
        bytes.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return true }
            var sent = 0
            while sent < buffer.count {
                let n = Darwin.send(fd, base + sent, buffer.count - sent, 0)
                guard n > 0 else { return false }
                sent += n
            }
            return true
        }
    }

    func read(count: Int, timeoutMs: Int32 = 2000) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: count)
        var have = 0
        while have < count {
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            guard poll(&descriptor, 1, timeoutMs) > 0 else { return nil }
            let n = bytes.withUnsafeMutableBytes { buffer -> Int in
                guard let base = buffer.baseAddress else { return -1 }
                return Darwin.recv(fd, base + have, count - have, 0)
            }
            guard n > 0 else { return nil }
            have += n
        }
        return bytes
    }
}

/// Session-internal message types and values (PVmGBALink.c).
private enum Wire {
    static let hello: UInt8 = 1
    static let welcome: UInt8 = 2
    static let reject: UInt8 = 3
    static let magic: UInt32 = 0x4C47_5650
    static let rejectVersion: UInt32 = 1
    static var size: Int { Int(PVGBALINK_WIRE_SIZE) }

    static func bytes(_ message: PVGBALinkMessage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: size)
        PVGBALinkEncode([message], &bytes)
        return bytes
    }

    static func decode(_ bytes: [UInt8]) -> PVGBALinkMessage {
        var message = PVGBALinkMessage()
        PVGBALinkDecode(bytes, &message)
        return message
    }

    static func hello(version: UInt32 = PVGBALINK_PROTOCOL_VERSION) -> [UInt8] {
        bytes(PVGBALinkMessage(type: Wire.hello, player: 0, mode: -1, reserved: 0, time: 0, finish: 0,
                               data: (magic, version, 0, 0)))
    }
}

private final class CallbackContext {
    let handler: (PVGBALinkCloseReason) -> Void
    init(_ handler: @escaping (PVGBALinkCloseReason) -> Void) { self.handler = handler }
}
