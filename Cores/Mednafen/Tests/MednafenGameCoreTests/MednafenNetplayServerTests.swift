//
//  MednafenNetplayServerTests.swift
//  PVMednafen
//
//  The embedded mednafen-server over loopback: start, a protocol-3 login,
//  password rejection, port conflicts, stop/restart, and the host-first rule.
//

import Foundation
import Testing
import MednafenGameCoreBridge
import mednafen_server

/// Raw TCP client speaking just enough of Mednafen's netplay protocol.
private final class LoopbackClient {
    let fd: Int32

    /// Connects to 127.0.0.1:port, or returns nil if the connection is refused.
    init?(port: UInt16, receiveTimeout: TimeInterval = 2) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: Int(receiveTimeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        inet_pton(AF_INET, "127.0.0.1", &address.sin_addr)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else {
            close(fd)
            return nil
        }
        self.fd = fd
    }

    deinit { close(fd) }

    func send(_ bytes: [UInt8]) -> Bool {
        bytes.withUnsafeBytes { Darwin.send(fd, $0.baseAddress, $0.count, 0) } == bytes.count
    }

    /// Reads until the server closes the connection. Returns false on timeout.
    func waitForClose() -> Bool {
        readUntilClose() != nil
    }

    /// Everything received until the server closes the connection; nil on timeout.
    func readUntilClose() -> [UInt8]? {
        var received: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = buffer.withUnsafeMutableBytes { recv(fd, $0.baseAddress, $0.count, 0) }
            if count == 0 { return received }
            if count < 0 { return nil }
            received += buffer[0..<count]
        }
    }

    /// A protocol-3 login packet as netplay.cpp's NetplayStart builds it:
    /// u32 LE length, login_data_t (97 bytes), nickname, emulator ID.
    static func loginPacket(nickname: String, password: [UInt8] = Array(repeating: 0, count: 16)) -> [UInt8] {
        let emulatorID = Array("mednafen 1.32.1".utf8)
        let nick = Array(nickname.utf8)

        var login = [UInt8](repeating: 0, count: 97)
        for i in 0..<16 { login[i] = UInt8(i + 1) }      // game ID (any 16 bytes)
        login.replaceSubrange(16..<32, with: password)    // MD5 of the server password, or zeros
        login[32] = 3                                     // protocol version
        login[33] = 2                                     // total controllers
        login.replaceSubrange(36..<40, with: le32(UInt32(emulatorID.count)))
        login[48] = 2; login[49] = 2                      // controller data sizes
        login[80] = 1; login[81] = 1                      // controller types
        login[96] = 1                                     // local players

        let payload = login + nick + emulatorID
        return le32(UInt32(payload.count)) + payload
    }

    private static func le32(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
    }
}

/// The server is a process-wide singleton, so these run one at a time.
@Suite(.serialized)
struct MednafenNetplayServerTests {

    /// A high port unlikely to be taken.
    private static func randomPort() -> UInt16 {
        UInt16.random(in: 40_000...59_999)
    }

    /// Polls `condition` until it holds or `timeout` passes.
    private static func eventually(timeout: TimeInterval = 3, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    @Test func loginIsAcceptedAndStopClosesEverything() async throws {
        let port = Self.randomPort()
        try MednafenGameCoreBridge.startNetplayServer(onPort: port, password: nil, maxClients: 4)
        #expect(MednafenGameCoreBridge.netplayServerRunning)

        let client = try #require(LoopbackClient(port: port))
        #expect(client.send(LoopbackClient.loginPacket(nickname: "Tester")))
        #expect(await Self.eventually { MednafenGameCoreBridge.netplayServerPlayerCount == 1 })

        let stopStart = Date()
        MednafenGameCoreBridge.stopNetplayServer()
        #expect(Date().timeIntervalSince(stopStart) < 1)
        #expect(!MednafenGameCoreBridge.netplayServerRunning)
        #expect(MednafenGameCoreBridge.netplayServerPlayerCount == 0)

        // The player's connection was closed, and nothing listens any more.
        #expect(client.waitForClose())
        #expect(LoopbackClient(port: port) == nil)
    }

    @Test func wrongPasswordIsRejected() async throws {
        let port = Self.randomPort()
        try MednafenGameCoreBridge.startNetplayServer(onPort: port, password: "secret", maxClients: 4)
        defer { MednafenGameCoreBridge.stopNetplayServer() }

        let client = try #require(LoopbackClient(port: port))
        #expect(client.send(LoopbackClient.loginPacket(nickname: "Intruder")))
        #expect(client.waitForClose())
        #expect(MednafenGameCoreBridge.netplayServerPlayerCount == 0)
    }

    @Test func busyPortFailsAndSecondServerIsRefused() throws {
        let port = Self.randomPort()
        try MednafenGameCoreBridge.startNetplayServer(onPort: port, password: nil, maxClients: 4)
        defer { MednafenGameCoreBridge.stopNetplayServer() }

        // One server per process.
        #expect(throws: (any Error).self) {
            try MednafenGameCoreBridge.startNetplayServer(onPort: Self.randomPort(), password: nil, maxClients: 4)
        }
        MednafenGameCoreBridge.stopNetplayServer()

        // A port another socket is listening on can't be bound.
        let blocker = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(blocker) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = INADDR_ANY
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(blocker, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        try #require(bound == 0 && listen(blocker, 1) == 0)

        #expect(throws: (any Error).self) {
            try MednafenGameCoreBridge.startNetplayServer(onPort: port, password: nil, maxClients: 4)
        }
        #expect(!MednafenGameCoreBridge.netplayServerRunning)
    }

    @Test func restartsOnTheSamePort() async throws {
        let port = Self.randomPort()
        try MednafenGameCoreBridge.startNetplayServer(onPort: port, password: nil, maxClients: 4)
        // A logged-in player, so the port has a live (then TIME_WAIT) connection.
        let first = try #require(LoopbackClient(port: port))
        #expect(first.send(LoopbackClient.loginPacket(nickname: "First")))
        #expect(await Self.eventually { MednafenGameCoreBridge.netplayServerPlayerCount == 1 })
        MednafenGameCoreBridge.stopNetplayServer()
        #expect(first.waitForClose())

        try MednafenGameCoreBridge.startNetplayServer(onPort: port, password: nil, maxClients: 4)
        defer { MednafenGameCoreBridge.stopNetplayServer() }
        #expect(LoopbackClient(port: port) != nil)
    }

    /// A remote player can't log in before the host (a loopback client) is in
    /// the game; once the host is in, they can. Remote players are simulated
    /// over loopback with the server's test hook.
    @Test func remotePlayerWaitsForTheHost() async throws {
        let port = Self.randomPort()
        try MednafenGameCoreBridge.startNetplayServer(onPort: port, password: nil, maxClients: 4)
        defer { MednafenGameCoreBridge.stopNetplayServer() }

        // Too early: refused with an explanation.
        mednafen_server_testing_treat_next_connection_as_remote()
        let early = try #require(LoopbackClient(port: port))
        #expect(early.send(LoopbackClient.loginPacket(nickname: "Early")))
        let refusal = try #require(early.readUntilClose())
        let printable = String(bytes: refusal.filter { (0x20..<0x7F).contains($0) }, encoding: .ascii) ?? ""
        #expect(printable.contains("The host hasn't resumed the game yet"))
        #expect(MednafenGameCoreBridge.netplayServerPlayerCount == 0)

        // The host joins over loopback, then the remote player gets in.
        let host = try #require(LoopbackClient(port: port))
        #expect(host.send(LoopbackClient.loginPacket(nickname: "Host")))
        #expect(await Self.eventually { MednafenGameCoreBridge.netplayServerPlayerCount == 1 })

        mednafen_server_testing_treat_next_connection_as_remote()
        let remote = try #require(LoopbackClient(port: port))
        #expect(remote.send(LoopbackClient.loginPacket(nickname: "Remote")))
        #expect(await Self.eventually { MednafenGameCoreBridge.netplayServerPlayerCount == 2 })
    }
}
