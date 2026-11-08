import Foundation
import XCTest
@testable import PVWebServer

final class PVWebServerManagerLifecycleTests: XCTestCase {
    func testReopeningControlsKeepsRunningServer() async throws {
        let server = LifecycleServer()
        let manager = PVWebServerManager(serverFactory: { server })
        let first = try await manager.start()
        let reopened = try await manager.start()
        let running = await manager.isRunning
        XCTAssertTrue(first)
        XCTAssertTrue(reopened)
        XCTAssertTrue(running)
        XCTAssertEqual(server.startCount, 1, "Reopening controls must retain existing upload connections")
        XCTAssertEqual(server.stopCount, 0)
        await manager.stop()
        let stopped = await manager.isRunning
        XCTAssertFalse(stopped)
        XCTAssertEqual(server.stopCount, 1)
    }

    func testConcurrentOpenRequestsStartOnlyOnce() async throws {
        let server = LifecycleServer()
        let manager = PVWebServerManager(serverFactory: { server })
        async let first = manager.start()
        async let second = manager.start()
        let results = try await (first, second)
        XCTAssertTrue(results.0 && results.1)
        XCTAssertEqual(server.startCount, 1)
        await manager.stop()
    }

    func testReopeningRestartsAnUnexpectedlyStoppedListener() async throws {
        let server = LifecycleServer()
        let manager = PVWebServerManager(serverFactory: { server })
        _ = try await manager.start()
        await server.stopServers()
        let restarted = try await manager.start()
        XCTAssertTrue(restarted)
        XCTAssertTrue(server.isWWWServerRunning)
        XCTAssertEqual(server.startCount, 2)
        await manager.stop()
    }

    func testUnexpectedListenerStopRestartsAndReportsTheNewPort() async throws {
        let server = LifecycleServer()
        let manager = PVWebServerManager(serverFactory: { server })
        _ = try await manager.start()
        let firstPort = await manager.httpPort
        XCTAssertEqual(firstPort, 80)

        // iOS killed the listener while suspended; another app now holds 80.
        server.nextHTTPPort = 8080
        server.dieUnexpectedly()
        for _ in 0..<100 where server.startCount < 2 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        _ = try await manager.start()  // drains the queued restart
        XCTAssertEqual(server.startCount, 2)
        let port = await manager.httpPort
        XCTAssertEqual(port, 8080, "the manager reports the port bound after the restart")
        await manager.stop()
    }

    func testExplicitStopBeforeTheRestartRunsWins() async throws {
        let server = LifecycleServer()
        let manager = PVWebServerManager(serverFactory: { server })
        _ = try await manager.start()
        await manager.stop()
        server.dieUnexpectedly()  // a stale report from the stopped server
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(server.startCount, 1)
        let running = await manager.isRunning
        XCTAssertFalse(running)
        let port = await manager.httpPort
        XCTAssertNil(port)
    }

    func testFailedStartCleansUpAndAllowsRetry() async throws {
        let server = LifecycleServer(startSucceeds: false)
        let manager = PVWebServerManager(serverFactory: { server })
        let started = try await manager.start()
        let running = await manager.isRunning
        XCTAssertFalse(started)
        XCTAssertFalse(running)
        XCTAssertEqual(server.stopCount, 1)
        server.startSucceeds = true
        let retried = try await manager.start()
        XCTAssertTrue(retried)
        await manager.stop()
    }
}

/// Mutable fixture is driven only by the manager's serialized lifecycle operations.
/// Tests read counters after awaiting every operation; it never binds a listener.
private final class LifecycleServer: PVWebServerProtocol, @unchecked Sendable {
    var startSucceeds: Bool
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var running = false
    var isWWWServerRunning: Bool { running }
    var isWebDAVServerRunning: Bool { running }
    var serverURL: URL? { nil }
    var webDAVURL: URL? { nil }
    var nextHTTPPort = 80
    private var httpPort: Int?
    var boundHTTPPort: Int? { running ? httpPort : nil }
    var boundWebDAVPort: Int? { running ? 81 : nil }
    private var unexpectedStop: (@Sendable () -> Void)?

    init(startSucceeds: Bool = true) { self.startSucceeds = startSucceeds }

    func startServers() async throws -> Bool {
        startCount += 1
        await Task.yield()
        running = startSucceeds
        httpPort = running ? nextHTTPPort : nil
        return running
    }

    func stopServers() async {
        stopCount += 1
        running = false
    }

    func setUnexpectedStopHandler(_ handler: @escaping @Sendable () -> Void) {
        unexpectedStop = handler
    }

    /// What `PVModernWebServer` does when a confirmed listener's task ends on its own.
    func dieUnexpectedly() {
        running = false
        let handler = unexpectedStop
        unexpectedStop = nil
        handler?()
    }
}
