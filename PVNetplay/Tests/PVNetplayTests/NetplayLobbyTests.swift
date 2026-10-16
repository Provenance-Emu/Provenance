//
//  NetplayLobbyTests.swift
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

private func room(hash: String = "", serial: String = "", system: String = "") -> NetplayRoom {
    NetplayRoom(
        hostName: "Joe",
        gameName: "Melee",
        gameHash: hash,
        coreIdentifier: "com.provenance.dolphin",
        maxPlayers: 4,
        currentPlayers: 1,
        isLAN: true,
        hostAddress: "192.168.1.20",
        port: 55435,
        gameSerial: serial,
        systemIdentifier: system
    )
}

@Suite("NetplayGameMatcher")
struct NetplayGameMatcherTests {
    private let library = ["ABC123": "Melee (ISO)"]
    private let bySerial = ["GALE01|com.provenance.gamecube": "Melee (RVZ)"]

    private func match(_ room: NetplayRoom) -> NetplayGameMatch<String> {
        NetplayGameMatcher.match(
            room,
            gameByMD5: { library[$0] },
            gameBySerial: { bySerial["\($0)|\($1)"] }
        )
    }

    @Test("The MD5 matches case-insensitively")
    func md5() {
        guard case .sameFile(let game) = match(room(hash: "abc123")) else {
            Issue.record("expected a file match")
            return
        }
        #expect(game == "Melee (ISO)")
    }

    @Test("Another dump of the same disc matches by serial and system")
    func serial() {
        let result = match(room(hash: "FFFF", serial: "GALE01", system: "com.provenance.gamecube"))
        guard case .sameSerial(let game) = result else {
            Issue.record("expected a serial match")
            return
        }
        #expect(game == "Melee (RVZ)")
    }

    @Test("A serial without its system is not enough")
    func serialNeedsSystem() {
        #expect(match(room(serial: "GALE01")).game == nil)
        guard case .unknown = match(room(serial: "GALE01")) else {
            Issue.record("expected unknown")
            return
        }
    }

    @Test("A known game the library lacks is not in the library")
    func notInLibrary() {
        guard case .notInLibrary = match(room(hash: "0000", serial: "GZLE01", system: "com.provenance.gamecube")) else {
            Issue.record("expected notInLibrary")
            return
        }
    }

    @Test("A room with neither hash nor serial can't be matched")
    func unknown() {
        guard case .unknown = match(room()) else {
            Issue.record("expected unknown")
            return
        }
    }
}

@Suite("NetplayLaunchIntent")
struct NetplayLaunchIntentTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("An intent applies to its own game, in any case, until it expires")
    func applies() {
        let intent = NetplayLaunchIntent(action: .host, gameMD5: "ABC", createdAt: start)
        #expect(intent.applies(toGameMD5: "abc", at: start.addingTimeInterval(1)))
        #expect(!intent.applies(toGameMD5: "DEF", at: start))
        #expect(!intent.applies(toGameMD5: "ABC", at: start.addingTimeInterval(NetplayLaunchIntent.lifetime + 1)))
    }

    @Test("The manager hands an intent out once")
    func takenOnce() async {
        let manager = PVNetplayManager(advertiser: nil)
        await manager.setLaunchIntent(NetplayLaunchIntent(action: .join(room(hash: "ABC")), gameMD5: "ABC"))
        let first = await manager.takeLaunchIntent(forGameMD5: "abc")
        let second = await manager.takeLaunchIntent(forGameMD5: "abc")
        #expect(first?.gameMD5 == "ABC")
        #expect(second == nil)
    }

    @Test("Launching another game discards the intent")
    func otherGameDiscards() async {
        let manager = PVNetplayManager(advertiser: nil)
        await manager.setLaunchIntent(NetplayLaunchIntent(action: .host, gameMD5: "ABC"))
        #expect(await manager.takeLaunchIntent(forGameMD5: "DEF") == nil)
        #expect(await manager.takeLaunchIntent(forGameMD5: "ABC") == nil)
    }
}

private final class LateBridge: PVNetplayCapable, @unchecked Sendable {
    private let lock = NSLock()
    private var _ready = false
    var ready: Bool {
        get { lock.withLock { _ready } }
        set { lock.withLock { _ready = newValue } }
    }

    var supportsNetplay: Bool { ready }
    var netplayEngineName: String { "Late" }
    func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {}
    func stopNetplay() async {}
    var netplayState: NetplayState { .idle }
    #if canImport(Combine)
    var netplayStatePublisher: AnyPublisher<NetplayState, Never> { Empty().eraseToAnyPublisher() }
    #endif
}

@Suite("PVNetplayManager readiness")
struct NetplayReadinessTests {

    @Test("Waiting returns once a late core supports netplay")
    func becomesReady() async {
        let manager = PVNetplayManager(advertiser: nil)
        let bridge = LateBridge()
        await manager.setActiveBridge(bridge)
        let flip = Task {
            try? await Task.sleep(for: .milliseconds(50))
            bridge.ready = true
        }
        let ready = await manager.waitUntilNetplayReady(timeout: .seconds(2), pollInterval: .milliseconds(10))
        #expect(ready)
        _ = await flip.value
    }

    @Test("Waiting gives up after the timeout")
    func timesOut() async {
        let manager = PVNetplayManager(advertiser: nil)
        let bridge = LateBridge()
        await manager.setActiveBridge(bridge)
        let ready = await manager.waitUntilNetplayReady(timeout: .milliseconds(50), pollInterval: .milliseconds(10))
        #expect(!ready)
        withExtendedLifetime(bridge) {}
    }

    @Test("Waiting with no core returns false")
    func noBridge() async {
        let manager = PVNetplayManager(advertiser: nil)
        #expect(await !manager.waitUntilNetplayReady(timeout: .milliseconds(20), pollInterval: .milliseconds(10)))
    }
}
