//
//  GameSystemMoverTests.swift
//  PVUIBaseTests
//

import Foundation
import Testing
import PVLibrary
import PVRealm
import RealmSwift
@testable import PVUIBase

@MainActor
@Suite("GameSystemMover.resolveLiveObjects")
struct GameSystemMoverTests {

    private func makeRealm() throws -> Realm {
        try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
    }

    private func seed(in realm: Realm) throws -> (game: PVGame, system: PVSystem) {
        let game = PVGame()
        game.md5Hash = UUID().uuidString
        game.title = "Test Game"
        let system = PVSystem()
        system.identifier = "com.provenance.test.\(UUID().uuidString)"
        system.name = "Test System"
        try realm.write { realm.add([game]); realm.add(system) }
        return (game, system)
    }

    @Test("Frozen game and system (the tvOS media UI) resolve to live objects in the write realm")
    func frozenInputsResolveToLiveObjects() throws {
        let realm = try makeRealm()
        let (game, system) = try seed(in: realm)
        let frozenGame = game.freeze()
        let frozenSystem = system.freeze()
        #expect(frozenGame.isFrozen && frozenSystem.isFrozen)

        let resolved = GameSystemMover.resolveLiveObjects(
            gameMD5: frozenGame.md5Hash, systemIdentifier: frozenSystem.identifier, in: realm)

        #expect(resolved?.game.isFrozen == false)
        #expect(resolved?.system.isFrozen == false)
        #expect(resolved?.game.md5Hash == game.md5Hash)
        #expect(resolved?.system.identifier == system.identifier)
    }

    @Test("Live objects resolve to themselves")
    func liveInputsResolve() throws {
        let realm = try makeRealm()
        let (game, system) = try seed(in: realm)

        let resolved = GameSystemMover.resolveLiveObjects(
            gameMD5: game.md5Hash, systemIdentifier: system.identifier, in: realm)

        #expect(resolved?.game == game)
        #expect(resolved?.system == system)
    }

    @Test("A resolved game can be repointed inside a write transaction")
    func resolvedGameIsWritable() throws {
        let realm = try makeRealm()
        let (game, system) = try seed(in: realm)
        let frozenGame = game.freeze()

        try realm.write {
            let resolved = GameSystemMover.resolveLiveObjects(
                gameMD5: frozenGame.md5Hash, systemIdentifier: system.identifier, in: realm)
            resolved?.game.systemIdentifier = system.identifier
            resolved?.game.system = resolved?.system
        }

        #expect(game.systemIdentifier == system.identifier)
        #expect(game.system?.identifier == system.identifier)
    }

    @Test("A missing game resolves to nil")
    func missingGameIsNil() throws {
        let realm = try makeRealm()
        let (_, system) = try seed(in: realm)

        #expect(GameSystemMover.resolveLiveObjects(
            gameMD5: "no-such-md5", systemIdentifier: system.identifier, in: realm) == nil)
    }

    @Test("A missing system resolves to nil")
    func missingSystemIsNil() throws {
        let realm = try makeRealm()
        let (game, _) = try seed(in: realm)

        #expect(GameSystemMover.resolveLiveObjects(
            gameMD5: game.md5Hash, systemIdentifier: "com.provenance.no-such-system", in: realm) == nil)
    }
}
