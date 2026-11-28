import Foundation
import Testing
@testable import PVNetplay

struct NetplayEligibilityTests {
    private let link = NetplayCoreSupport(coreIdentifier: "link", modes: [.linkCable], maxPlayers: 2)
    private let shared = NetplayCoreSupport(coreIdentifier: "shared", modes: [.sharedConsole, .alternating], maxPlayers: 4,
                                            supportsSpectators: true, coreVersion: "1.2")

    @Test func everyGameWithANetplayCoreIsOffered() {
        let result = NetplayEligibility.evaluate(localFileAvailable: true, cores: [link, shared])
        #expect(result.options.map(\.core.coreIdentifier) == ["link", "shared"])
        #expect(result.options.map(\.mode) == [.linkCable, .sharedConsole])
        #expect(result.options.map(\.maxPlayers) == [2, 4])
    }

    @Test func aGameNeedsALocalFileAndACoreWithSeats() {
        #expect(NetplayEligibility.evaluate(localFileAvailable: false, cores: [link]).options.isEmpty)
        #expect(NetplayEligibility.evaluate(localFileAvailable: true, cores: []).options.isEmpty)
        let solo = NetplayCoreSupport(coreIdentifier: "solo", modes: [.sharedConsole], maxPlayers: 1)
        let modeless = NetplayCoreSupport(coreIdentifier: "modeless", modes: [], maxPlayers: 4)
        #expect(NetplayEligibility.evaluate(localFileAvailable: true, cores: [solo, modeless]).options.isEmpty)
    }

    @Test func listsNeverDropAPlayableGameAndOrderIsDeterministic() {
        let ready = NetplayEligibility.evaluate(localFileAvailable: true, cores: [shared])
        let games = [
            NetplayRankedGame(id: "a", title: "Alpha", system: "S", favorite: false, lastPlayed: .now, hasJoinableRoom: false, eligibility: ready),
            NetplayRankedGame(id: "b", title: "Beta", system: "S", favorite: true, lastPlayed: nil, hasJoinableRoom: false, eligibility: ready),
            NetplayRankedGame(id: "c", title: "Charlie", system: "S", favorite: false, lastPlayed: nil, hasJoinableRoom: true, eligibility: ready),
            NetplayRankedGame(id: "d", title: "Delta", system: "S", favorite: true, lastPlayed: .now, hasJoinableRoom: false,
                              eligibility: .unavailable("No core"))
        ]
        #expect(NetplayRankedGame.select(games, list: .all).map(\.id) == ["c", "a", "b"])
        #expect(NetplayRankedGame.select(games, list: .recent).map(\.id) == ["a"])
        #expect(NetplayRankedGame.select(games, list: .favorites).map(\.id) == ["b"])
    }

    @Test @MainActor func hintsDefaultToUnknownAndNeverChangeWhatIsOffered() {
        struct Source: NetplayGameHintSource {
            func hint(for game: NetplayGameIdentity) -> NetplayGameHint { game.md5 == "BAD" ? .reportedBroken : .works }
        }
        let game = NetplayGameIdentity(md5: "BAD", systemIdentifier: "system", coreIdentifier: "shared")
        #expect(NetplayGameHints.hint(for: game) == .unknown)
        #expect(NetplayGameHint.unknown.label == nil)
        NetplayGameHints.source = Source()
        defer { NetplayGameHints.source = nil }
        #expect(NetplayGameHints.hint(for: game) == .reportedBroken)
        #expect(NetplayGameHints.hint(for: NetplayGameIdentity(md5: "GOOD", systemIdentifier: "system", coreIdentifier: "shared")) == .works)
        // A hint is advice: eligibility has no input for it.
        #expect(!NetplayEligibility.evaluate(localFileAvailable: true, cores: [shared]).options.isEmpty)
    }

    @Test func discoveryPreservesModeAndCoreVersion() {
        let room = NetplayRoom(hostName: "Host", gameName: "Game", gameHash: "ABC", coreIdentifier: "core", maxPlayers: 2,
                              currentPlayers: 1, isLAN: true, hostAddress: "127.0.0.1", port: 55435,
                              coreVersion: "1.2", playMode: .linkCable)
        let decoded = NetplayRoomTXTRecord.room(fromTXT: NetplayRoomTXTRecord.txtRecord(for: room), serviceName: "test",
                                               hostAddress: "127.0.0.1", port: 55435)
        #expect(decoded.coreVersion == "1.2")
        #expect(decoded.playMode == .linkCable)
    }

    @Test func roomChecksExactROMCoreVersionModeAndSlots() {
        let eligible = NetplayEligibility.evaluate(localFileAvailable: true, cores: [shared])
        func room(hash: String = "ROM", core: String = "shared", version: String = "1.2", mode: NetplayPlayMode? = .sharedConsole,
                  current: Int = 1, max: Int = 4) -> NetplayRoom {
            NetplayRoom(hostName: "Host", gameName: "Game", gameHash: hash, coreIdentifier: core, maxPlayers: max, currentPlayers: current,
                        isLAN: true, hostAddress: "127.0.0.1", port: 55435, systemIdentifier: "system", coreVersion: version, playMode: mode)
        }
        func check(_ room: NetplayRoom) -> NetplayGameOption? { eligible.joinOption(for: room, gameMD5: "ROM", systemIdentifier: "system") }
        #expect(check(room()) != nil)
        #expect(check(room(hash: "OTHER")) == nil)
        #expect(check(room(core: "uninstalled")) == nil)
        #expect(check(room(version: "2.0")) == nil)
        #expect(check(room(mode: .linkCable)) == nil)
        #expect(check(room(current: 4)) == nil)
        #expect(check(room(max: 8)) == nil)
        #expect(check(room(version: "", mode: nil)) != nil)
        // A room from a build that advertised the core's other mode still joins.
        #expect(check(room(mode: .alternating)) != nil)
    }
}
