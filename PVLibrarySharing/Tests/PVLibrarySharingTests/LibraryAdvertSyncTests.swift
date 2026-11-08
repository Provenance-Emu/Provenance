//
//  LibraryAdvertSyncTests.swift
//  PVLibrarySharingTests
//
//  A library advert must follow the port its listener actually holds. iFly and
//  iCube serve on the same device, and iOS defuncts a suspended app's sockets,
//  so an advert naming a lost port sends peers to another app.
//

import Foundation
import XCTest
@testable import PVLibrarySharing

final class LibraryAdvertSyncTests: XCTestCase {
    func testListenerMovedPortRepublishes() {
        XCTAssertEqual(LibraryAdvertSync.action(wanted: true, listenerPort: 8487, advertisedPort: 8484, contentChanged: false), .republish)
        XCTAssertEqual(LibraryAdvertSync.action(wanted: true, listenerPort: 8487, advertisedPort: 8484, contentChanged: true), .republish)
    }

    func testListenerDownWithdraws() {
        XCTAssertEqual(LibraryAdvertSync.action(wanted: true, listenerPort: nil, advertisedPort: 8484, contentChanged: false), .withdraw)
        XCTAssertEqual(LibraryAdvertSync.action(wanted: true, listenerPort: 0, advertisedPort: 8484, contentChanged: false), .withdraw)
    }

    func testNothingToShareWithdraws() {
        XCTAssertEqual(LibraryAdvertSync.action(wanted: false, listenerPort: 8484, advertisedPort: 8484, contentChanged: false), .withdraw)
    }

    func testListenerBackPublishes() {
        XCTAssertEqual(LibraryAdvertSync.action(wanted: true, listenerPort: 8484, advertisedPort: nil, contentChanged: false), .republish)
    }

    func testUnchangedKeeps() {
        XCTAssertEqual(LibraryAdvertSync.action(wanted: true, listenerPort: 8484, advertisedPort: 8484, contentChanged: false), .keep)
        XCTAssertEqual(LibraryAdvertSync.action(wanted: true, listenerPort: nil, advertisedPort: nil, contentChanged: true), .keep)
        XCTAssertEqual(LibraryAdvertSync.action(wanted: false, listenerPort: 8484, advertisedPort: nil, contentChanged: true), .keep)
    }

    func testNewSystemsOrURLsOnTheSamePortRepublish() {
        XCTAssertEqual(LibraryAdvertSync.action(wanted: true, listenerPort: 8484, advertisedPort: 8484, contentChanged: true), .republish)
    }
}

#if canImport(Network)
/// The host over real listeners, with adverts recorded instead of published.
final class LibrarySharingHostAdvertTests: XCTestCase {
    func testAdvertsNameTheBoundPorts() async throws {
        let fixture = try ServerFixture()
        defer { fixture.cleanUp() }
        let publisher = RecordingPublisher()
        let host = fixture.host(publisher: publisher)
        try await host.start()
        defer { Task { await host.stop() } }

        let ports = await host.ports
        let advertised = await host.advertisedPorts
        // The fixture shares Dreamcast and GameCube, so all three dialects are published.
        XCTAssertEqual(advertised, ports)
        XCTAssertEqual(Set(ports.values).count, ServedDialect.allCases.count, "one port per dialect")
        await host.stop()
        XCTAssertTrue(publisher.live.isEmpty, "stop withdraws every advert")
    }

    /// iOS defuncted the socket (tvOS keeps the host across backgrounding, so this is
    /// its only recovery): the old advert goes, a new listener comes up, and the new
    /// advert names the new listener's port.
    func testDeadListenerIsWithdrawnReboundAndRepublished() async throws {
        let fixture = try ServerFixture()
        defer { fixture.cleanUp() }
        let publisher = RecordingPublisher()
        let host = fixture.host(publisher: publisher)
        try await host.start()

        let before = await host.ports
        let oldPort = try XCTUnwrap(before[.iFly])
        await host.simulateListenerFailure(.iFly)

        var after = await host.advertisedPorts
        for _ in 0..<200 where after[.iFly] == nil || after[.iFly] == oldPort {
            try await Task.sleep(nanoseconds: 10_000_000)
            after = await host.advertisedPorts
        }
        let newPort = try XCTUnwrap(after[.iFly])
        let listenerPort = await host.ports[.iFly]
        XCTAssertNotEqual(newPort, oldPort)
        XCTAssertEqual(newPort, listenerPort, "the advert names the port the new listener holds")
        XCTAssertEqual(publisher.withdrawn(type: ServedDialect.iFly.serviceType), [oldPort])
        XCTAssertEqual(publisher.live[ServedDialect.iFly.serviceType], newPort)
        // The other dialects were untouched.
        XCTAssertEqual(after[.iCube], before[.iCube])
        XCTAssertEqual(after[.pvLibrary], before[.pvLibrary])
        await host.stop()
    }

    func testRefreshRacingTheDeathReportEndsConsistent() async throws {
        // A foreground refresh racing the death report still ends with every advert on a live port.
        let fixture = try ServerFixture()
        defer { fixture.cleanUp() }
        let publisher = RecordingPublisher()
        let host = fixture.host(publisher: publisher)
        try await host.start()
        await host.simulateListenerFailure(.pvLibrary)
        await host.refreshAdvertisements()
        let ports = await host.ports
        let advertised = await host.advertisedPorts
        XCTAssertNotNil(ports[.pvLibrary])
        XCTAssertEqual(advertised, ports)
        await host.stop()
    }
}

extension ServerFixture {
    func host(publisher: RecordingPublisher) -> LibrarySharingHost {
        LibrarySharingHost(
            identity: hostIdentity, device: device, library: library, trust: trust,
            approver: owner, hashes: FileHashCache(), publisher: publisher
        )
    }
}

/// Records adverts instead of publishing them on the LAN.
final class RecordingPublisher: LibraryAdvertPublishing, @unchecked Sendable {
    private let lock = NSLock()
    private var published: [String: UInt16] = [:]
    private var withdrawals: [String: [UInt16]] = [:]

    /// Live adverts: service type → port.
    var live: [String: UInt16] { lock.withLock { published } }

    func withdrawn(type: String) -> [UInt16] { lock.withLock { withdrawals[type] ?? [] } }

    func makeAdvertiser(type: String, name: String, port: UInt16) -> any LibraryAdvertising {
        RecordedAdvert(type: type, port: port, publisher: self)
    }

    fileprivate func record(type: String, port: UInt16, live isLive: Bool) {
        lock.withLock {
            if isLive {
                published[type] = port
            } else {
                if published[type] == port { published[type] = nil }
                withdrawals[type, default: []].append(port)
            }
        }
    }
}

private final class RecordedAdvert: LibraryAdvertising, @unchecked Sendable {
    let type: String
    let port: UInt16
    weak var publisher: RecordingPublisher?

    init(type: String, port: UInt16, publisher: RecordingPublisher) {
        self.type = type
        self.port = port
        self.publisher = publisher
    }

    func publish(txt: [String: String]) async { publisher?.record(type: type, port: port, live: true) }
    func withdraw() async { publisher?.record(type: type, port: port, live: false) }
}
#endif
