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

    init(startSucceeds: Bool = true) { self.startSucceeds = startSucceeds }

    func startServers() async throws -> Bool {
        startCount += 1
        await Task.yield()
        running = startSucceeds
        return running
    }

    func stopServers() async {
        stopCount += 1
        running = false
    }
}
