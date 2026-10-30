import Foundation
import Testing
@testable import PVNetplay

struct NetplayEligibilityTests {
    private let link = NetplayCoreSupport(coreIdentifier: "link", modes: [.linkCable], maxPlayers: 2)
    private let shared = NetplayCoreSupport(coreIdentifier: "shared", modes: [.sharedConsole], maxPlayers: 4, supportsSpectators: true)

    @Test func singlePlayerAndUnknownAreNeverRecommended() {
        let single = NetplayMultiplayerMetadata(modes: [], singlePlayerOnly: true, source: .userConfirmed, reference: "manual")
        #expect(NetplayEligibility.evaluate(localFileAvailable: true, metadata: single, cores: [shared]).options.isEmpty)
        #expect(NetplayEligibility.evaluate(localFileAvailable: true, metadata: nil, cores: [shared]) == .unverified)
        let unknown = NetplayRankedGame(id: "x", title: "A", system: "S", favorite: true, lastPlayed: .now,
                                       hasJoinableRoom: true, eligibility: .unverified)
        for list in [NetplayGameList.suggested, .allSupported, .recent, .favorites] {
            #expect(NetplayRankedGame.select([unknown], list: list).isEmpty)
        }
        #expect(NetplayRankedGame.select([unknown], list: .unverified).count == 1)
    }

    @Test func exactModeMustIntersectAndPlayerCountIsClamped() {
        let metadata = NetplayMultiplayerMetadata(modes: [.init(.linkCable, maxPlayers: 4)], source: .userConfirmed, reference: "manual")
        #expect(NetplayEligibility.evaluate(localFileAvailable: true, metadata: metadata, cores: [shared]).options.isEmpty)
        let result = NetplayEligibility.evaluate(localFileAvailable: true, metadata: metadata, cores: [link])
        #expect(result.options.first?.maxPlayers == 2)
        #expect(result.options.first?.core.supportsSpectators == false)
        #expect(NetplayEligibility.evaluate(localFileAvailable: false, metadata: metadata, cores: [link]).options.isEmpty)
    }

    @Test func deterministicOrderingAndUnplayedGames() {
        let metadata = NetplayMultiplayerMetadata(modes: [.init(.sharedConsole, maxPlayers: 4)], source: .userConfirmed, reference: "manual")
        let ready = NetplayEligibility.evaluate(localFileAvailable: true, metadata: metadata, cores: [shared])
        let games = [
            NetplayRankedGame(id: "a", title: "Alpha", system: "S", favorite: false, lastPlayed: .now, hasJoinableRoom: false, eligibility: ready),
            NetplayRankedGame(id: "b", title: "Beta", system: "S", favorite: true, lastPlayed: nil, hasJoinableRoom: false, eligibility: ready),
            NetplayRankedGame(id: "c", title: "Charlie", system: "S", favorite: false, lastPlayed: nil, hasJoinableRoom: true, eligibility: ready)
        ]
        #expect(NetplayRankedGame.select(games, list: .suggested).map(\.id) == ["c", "b", "a"])
        #expect(NetplayRankedGame.select(games, list: .allSupported).map(\.id) == ["a", "b", "c"])
        #expect(NetplayRankedGame.select(games, list: .recent).map(\.id) == ["a"])
        #expect(NetplayRankedGame.select(games, list: .favorites).map(\.id) == ["b"])
    }

    @Test @MainActor func metadataPersistenceIsScopedToROMAndSystem() throws {
        let suite = "NetplayMetadataTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let metadata = NetplayMultiplayerMetadata(modes: [.init(.linkCable, maxPlayers: 2)], source: .userConfirmed, reference: "manual")
        try NetplayMetadataStore(defaults: defaults).save(metadata, md5: "abc", system: "gba")
        let store = NetplayMetadataStore(defaults: defaults)
        #expect(store.metadata(md5: "ABC", system: "gba", serial: nil) == metadata)
        #expect(store.metadata(md5: "def", system: "gba", serial: nil) == nil)
        #expect(store.metadata(md5: "ABC", system: "gb", serial: nil) == nil)
    }

    @Test @MainActor func catalogRequiresExactSystemAndSerialAndDoesNotTrustPatches() {
        let store = NetplayMetadataStore()
        let melee = store.metadata(md5: "", system: "com.provenance.gamecube", serial: "GALE01")
        #expect(melee?.modes.contains(.init(.sharedConsole, maxPlayers: 4)) == true)
        #expect(melee?.source == .gameTDB)
        #expect(store.metadata(md5: "", system: "com.provenance.wii", serial: "GALE01") == nil)
        #expect(store.metadata(md5: "", system: "com.provenance.gamecube", serial: "GALE") == nil)
        #expect(store.metadata(md5: "", system: "com.provenance.gamecube", serial: "GALE01", isPatched: true) == nil)
        let localOnePlayer = store.metadata(md5: "", system: "com.provenance.gamecube", serial: "GMSE01")
        #expect(localOnePlayer?.modes.isEmpty == true)
        #expect(localOnePlayer?.singlePlayerOnly == false)
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
        let core = NetplayCoreSupport(coreIdentifier: "shared", modes: [.sharedConsole, .alternating], maxPlayers: 4, coreVersion: "1.2")
        let metadata = NetplayMultiplayerMetadata(modes: [.init(.sharedConsole, maxPlayers: 4)], source: .userConfirmed, reference: "manual")
        let eligible = NetplayEligibility.evaluate(localFileAvailable: true, metadata: metadata, cores: [core])
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
        let multiple = NetplayMultiplayerMetadata(modes: [.init(.sharedConsole, maxPlayers: 4), .init(.alternating, maxPlayers: 4)],
                                                 source: .userConfirmed, reference: "manual")
        let ambiguous = NetplayEligibility.evaluate(localFileAvailable: true, metadata: multiple, cores: [core])
        #expect(ambiguous.joinOption(for: room(mode: nil), gameMD5: "ROM", systemIdentifier: "system") == nil)
    }
}
