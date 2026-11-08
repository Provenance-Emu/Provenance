//
//  PVWebServerPortFallbackTests.swift
//  PVWebServer
//
//  iFly and iCube want port 80 on the same device, and whoever binds first owns
//  it. Provenance must fall back to the next free port and report the one it
//  holds, never the one it wanted.
//

import Darwin
import XCTest
@testable import PVWebServer

final class PVWebServerPortFallbackTests: XCTestCase {

    // MARK: - Candidate order

    func testDeviceCandidatesStartAtTheLowPairAndNeverOverlap() {
        XCTAssertEqual(PVWebServerPorts.deviceUploadCandidates, [80, 8080, 8000, 8888, 9000])
        XCTAssertEqual(PVWebServerPorts.deviceWebDAVCandidates.first, 81)
        XCTAssertTrue(Set(PVWebServerPorts.deviceUploadCandidates).isDisjoint(with: PVWebServerPorts.deviceWebDAVCandidates))
        XCTAssertTrue(Set(PVWebServerPorts.desktopUploadCandidates).isDisjoint(with: PVWebServerPorts.desktopWebDAVCandidates))
        XCTAssertTrue(PVWebServerPorts.desktopUploadCandidates.allSatisfy { $0 >= 1024 })
        XCTAssertTrue(PVWebServerPorts.desktopWebDAVCandidates.allSatisfy { $0 >= 1024 })
    }

    func testBindOrderDropsDuplicatesInvalidAndExcludedPorts() {
        XCTAssertEqual(PVWebServerPorts.bindOrder([80, 8080, 80, 0, 70_000, 8000], excluding: [8080]), [80, 8000])
    }

    func testFirstBoundSkipsTakenPorts() async {
        var tried: [Int] = []
        let port = await PVWebServerPorts.firstBound([80, 8080, 8000], excluding: [8080]) { candidate in
            tried.append(candidate)
            if candidate == 80 { throw POSIXError(.EADDRINUSE) }
            return true
        }
        XCTAssertEqual(port, 8000)
        XCTAssertEqual(tried, [80, 8000])
    }

    func testFirstBoundIsNilWhenEveryPortIsTaken() async {
        let port = await PVWebServerPorts.firstBound([80, 8080]) { _ in false }
        XCTAssertNil(port)
    }

    // MARK: - Real listeners

    /// The old bind check connected to 127.0.0.1:port, which succeeds against ANY
    /// listener. With another app on the preferred port, Provenance claimed it.
    func testBusyPreferredPortsFallBackAndReportTheBoundPorts() async throws {
        let base = Self.testPortBase()
        let httpHog = try XCTUnwrap(PortHog(port: base))
        let davHog = try XCTUnwrap(PortHog(port: base + 2))
        defer { httpHog.close(); davHog.close() }

        let server = Self.makeServer(httpPorts: [base, base + 1], webDAVPorts: [base + 2, base + 3])
        let started = try await server.startServers()
        defer { Task { await server.stopServers() } }

        XCTAssertTrue(started)
        XCTAssertEqual(server.boundHTTPPort, base + 1, "HTTP must not claim a port another listener holds")
        XCTAssertEqual(server.boundWebDAVPort, base + 3)
        if let url = server.serverURL {
            XCTAssertEqual(url.port, base + 1)
        }
        if let url = server.webDAVURL {
            XCTAssertEqual(url.port, base + 3)
        }
        await server.stopServers()
        XCTAssertNil(server.boundHTTPPort)
        XCTAssertNil(server.boundWebDAVPort)
        XCTAssertNil(server.serverURL)
    }

    func testWebDAVSkipsThePortHTTPTook() async throws {
        let base = Self.testPortBase()
        let server = Self.makeServer(httpPorts: [base], webDAVPorts: [base, base + 1])
        let started = try await server.startServers()
        XCTAssertTrue(started)
        XCTAssertEqual(server.boundHTTPPort, base)
        XCTAssertEqual(server.boundWebDAVPort, base + 1)
        await server.stopServers()
    }

    func testEveryCandidateTakenFailsCleanly() async throws {
        let base = Self.testPortBase()
        let hog = try XCTUnwrap(PortHog(port: base))
        defer { hog.close() }
        let server = Self.makeServer(httpPorts: [base], webDAVPorts: [base + 1])
        let started = try await server.startServers()
        XCTAssertFalse(started)
        XCTAssertFalse(server.isWWWServerRunning)
        XCTAssertFalse(server.isWebDAVServerRunning)
        XCTAssertNil(server.serverURL)
    }

    /// iOS defuncts a suspended app's listener. The server must stop claiming the
    /// port (another app may take it) and tell its owner, once.
    func testUnexpectedListenerStopTakesTheServerDownAndNotifiesOnce() async throws {
        let base = Self.testPortBase()
        let server = Self.makeServer(httpPorts: [base], webDAVPorts: [base + 1])
        let stops = Counter()
        server.setUnexpectedStopHandler { stops.increment() }
        let started = try await server.startServers()
        XCTAssertTrue(started)

        let generation = server.listenerState.generation
        await server.listenerEnded(.http, port: base, generation: generation)
        XCTAssertNil(server.boundHTTPPort)
        XCTAssertNil(server.boundWebDAVPort, "both listeners go down together")
        XCTAssertNil(server.serverURL)
        // The WebDAV task ending afterwards is part of the same teardown, not news.
        await server.listenerEnded(.webDAV, port: base + 1, generation: generation)
        XCTAssertEqual(stops.value, 1)

        // The ports come free again for the restart (NIO closes the old channels asynchronously).
        let replacement = Self.makeServer(httpPorts: [base], webDAVPorts: [base + 1])
        var restarted = false
        for _ in 0..<10 where !restarted {
            restarted = try await replacement.startServers()
            if !restarted { try await Task.sleep(nanoseconds: 200_000_000) }
        }
        XCTAssertTrue(restarted)
        await replacement.stopServers()
    }

    func testExplicitStopIsNotReportedAsUnexpected() async throws {
        let base = Self.testPortBase()
        let server = Self.makeServer(httpPorts: [base], webDAVPorts: [base + 1])
        let stops = Counter()
        server.setUnexpectedStopHandler { stops.increment() }
        _ = try await server.startServers()
        await server.stopServers()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(stops.value, 0)
    }

    // MARK: - Helpers

    private static func makeServer(httpPorts: [Int], webDAVPorts: [Int]) -> PVModernWebServer {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        return PVModernWebServer(browseRoot: root, httpPorts: httpPorts, webDAVPorts: webDAVPorts)
    }

    /// Four consecutive high ports, different per test so a slow teardown can't collide.
    private static func testPortBase() -> Int {
        42_000 + Int.random(in: 0..<2_000) * 4
    }
}

/// Holds a port the way another app's listener would: bound on 0.0.0.0 and listening.
private final class PortHog {
    private var fd: Int32

    init?(port: Int) {
        fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr.s_addr = INADDR_ANY
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(fd, 4) == 0 else {
            Darwin.close(fd)
            return nil
        }
    }

    func close() {
        guard fd >= 0 else { return }
        Darwin.close(fd)
        fd = -1
    }

    deinit { close() }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}
