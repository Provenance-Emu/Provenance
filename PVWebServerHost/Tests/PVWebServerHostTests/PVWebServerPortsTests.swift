//
//  PVWebServerPortsTests.swift
//  PVWebServerHostTests
//
//  iFly and iCube run servers on the same device, and whoever binds first owns the port.
//  Provenance must fall back to the next free port and report the one it holds.
//

import XCTest
@testable import PVWebServerHost

final class PVWebServerPortsTests: XCTestCase {

    func testPortMap() {
        XCTAssertEqual(PVWebServerPorts.deviceCandidates, [80] + Array(8180...8189))
        XCTAssertEqual(PVWebServerPorts.desktopCandidates, [8080] + Array(8180...8189))
    }

    func testFallbacksNeverTakeAnotherAppsHomePort() {
        for list in [PVWebServerPorts.deviceCandidates, PVWebServerPorts.desktopCandidates] {
            let fallbacks = Set(list.dropFirst())
            XCTAssertTrue(fallbacks.isDisjoint(with: PVWebServerPorts.ecosystemHomePorts), "\(list)")
            XCTAssertTrue(fallbacks.allSatisfy(PVWebServerPorts.fallbackRange.contains), "\(list)")
        }
        // iFly falls back to 8092–8099 and iCube to 8190–8199: no overlap with ours.
        XCTAssertTrue(Set(PVWebServerPorts.fallbackRange).isDisjoint(with: Set(8092...8099).union(8190...8199)))
    }

    func testAServerFallsBackAndReportsThePortItHolds() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let ports = randomPorts()

        let first = PVHostedWebServer(browseRoot: root, ports: ports)
        let second = PVHostedWebServer(browseRoot: root, ports: ports)
        let firstStarted = try await first.startServers()
        let secondStarted = try await second.startServers()
        XCTAssertTrue(firstStarted)
        XCTAssertTrue(secondStarted)
        XCTAssertEqual(first.boundPort, ports[0])
        XCTAssertEqual(second.boundPort, ports[1])

        await first.stopServers()
        await second.stopServers()
        XCTAssertNil(first.boundPort)
    }

    func testStartReportsFailureWhenEveryPortIsTaken() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let port = randomPorts()[0]

        let first = PVHostedWebServer(browseRoot: root, ports: [port])
        let second = PVHostedWebServer(browseRoot: root, ports: [port])
        let firstStarted = try await first.startServers()
        let secondStarted = try await second.startServers()
        XCTAssertTrue(firstStarted)
        XCTAssertFalse(secondStarted)
        XCTAssertFalse(second.isRunning)
        await first.stopServers()
    }
}
