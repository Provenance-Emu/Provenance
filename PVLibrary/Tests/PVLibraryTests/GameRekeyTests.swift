//
//  GameRekeyTests.swift
//  PVLibraryTests
//
//  "Replace the Original" overwrites a ROM, so the game's MD5 (its Realm primary key) changes.
//  GameRekey moves the row and everything that points at it; these run on an in-memory Realm.
//

import XCTest
import RealmSwift
import PVRealm
@testable import PVLibrary

final class GameRekeyTests: XCTestCase {

    private let oldMD5 = "0123456789ABCDEF0123456789ABCDEF"
    private let newMD5 = "FEDCBA9876543210FEDCBA9876543210"
    private let systemID = "com.provenance.gba"

    private var realm: Realm!

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
    }

    override func tearDown() {
        realm = nil
        super.tearDown()
    }

    /// A base game with one of everything that links to it.
    @discardableResult
    private func addGame() throws -> PVGame {
        let system = PVSystem()
        system.identifier = systemID
        let game = PVGame()
        game.md5Hash = oldMD5
        game.title = "Pocket Monsters"
        game.systemIdentifier = systemID
        game.system = system
        game.crc = "11111111"
        game.playCount = 7
        game.isFavorite = true
        game.cloudRecordID = "rom_\(oldMD5)"
        game.hasCloudAssets = true
        game.file = PVFile(withPartialPath: "com.provenance.gba/Pocket Monsters.gba", relativeRoot: .documents, size: 1024, md5: oldMD5)

        let state = PVSaveState()
        state.game = game
        let cheat = PVCheats()
        cheat.game = game
        let recent = PVRecentGame(withGame: game)

        let patch = PVPatch()
        patch.id = "Patches/other.bps"
        patch.game = game
        patch.baseGameMD5 = oldMD5

        let variant = PVGame()
        variant.md5Hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        variant.isPatchVariant = true
        variant.baseGameMD5 = oldMD5
        patch.variantGame = variant
        patch.variantGameMD5 = variant.md5Hash

        // A second patch and variant: the re-key edits the very field its queries match on.
        let second = PVPatch()
        second.id = "Patches/second.ips"
        second.game = game
        second.baseGameMD5 = oldMD5.lowercased()
        let secondVariant = PVGame()
        secondVariant.md5Hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        secondVariant.isPatchVariant = true
        secondVariant.baseGameMD5 = oldMD5
        second.variantGame = secondVariant
        second.variantGameMD5 = secondVariant.md5Hash

        let library = PVLibrary()
        library.games.append(game)

        let profile = PVControllerProfile(name: "Pad", controllerVendorName: "Pad", gameID: oldMD5)
        let secondProfile = PVControllerProfile(name: "Keyboard", controllerVendorName: "Keyboard", gameID: oldMD5)

        try realm.write {
            realm.add([game, state, cheat, recent, patch, variant, second, secondVariant, library, profile, secondProfile] as [Object])
        }
        return game
    }

    private func rekey(to md5: String? = nil) throws -> PVGame {
        var result: PVGame!
        try realm.write {
            result = try GameRekey.rekey(gameWithMD5: oldMD5, to: md5 ?? newMD5, crc: "22222222", fileSize: 2048, in: realm)
        }
        return result
    }

    func testTheGameMovesToTheNewKeyWithItsFields() throws {
        let id = try addGame().id

        let game = try rekey()

        XCTAssertNil(realm.object(ofType: PVGame.self, forPrimaryKey: oldMD5))
        XCTAssertEqual(realm.object(ofType: PVGame.self, forPrimaryKey: newMD5), game)
        XCTAssertEqual(realm.objects(PVGame.self).filter("isPatchVariant == false").count, 1)
        XCTAssertEqual(game.id, id, "skins and artwork look games up by id")
        XCTAssertEqual(game.title, "Pocket Monsters")
        XCTAssertEqual(game.playCount, 7)
        XCTAssertTrue(game.isFavorite)
        XCTAssertEqual(game.system?.identifier, systemID)
        XCTAssertEqual(game.file?.partialPath, "com.provenance.gba/Pocket Monsters.gba")
        XCTAssertEqual(game.crc, "22222222")
        XCTAssertEqual(game.fileSize, 2048)
    }

    func testSavesCheatsHistoryAndPatchesFollowTheGame() throws {
        try addGame()

        let game = try rekey()

        XCTAssertEqual(game.saveStates.count, 1)
        XCTAssertEqual(game.cheats.count, 1)
        XCTAssertEqual(game.recentPlays.count, 1)
        XCTAssertEqual(game.patches.count, 2)
        XCTAssertEqual(game.libraries.count, 1)
        XCTAssertEqual(game.libraries.first?.games.count, 1)
        XCTAssertEqual(game.system?.games.count, 1)
        for patch in game.patches {
            XCTAssertEqual(patch.baseGameMD5, newMD5)
            XCTAssertEqual(patch.variantGame?.baseGameMD5, newMD5, "the patch's variant still names its base game")
        }
        XCTAssertEqual(Array(realm.objects(PVControllerProfile.self).map(\.gameID)), [newMD5, newMD5])
    }

    func testTheCloudCopyIsNotClaimedForTheNewContent() throws {
        try addGame()

        let game = try rekey()

        XCTAssertNil(game.cloudRecordID)
        XCTAssertFalse(game.hasCloudAssets)
        XCTAssertTrue(game.requiresSync)
    }

    func testTheNewKeyIsUppercase() throws {
        try addGame()

        let game = try rekey(to: newMD5.lowercased())

        XCTAssertEqual(game.md5Hash, newMD5)
    }

    func testAnUnchangedMD5KeepsTheRowAndRefreshesTheFileFacts() throws {
        let original = try addGame()

        let game = try rekey(to: oldMD5)

        XCTAssertEqual(game, original)
        XCTAssertEqual(game.crc, "22222222")
        XCTAssertNil(game.file?.md5Cache, "the cached MD5 described the old bytes")
    }

    func testAGameAlreadyUnderTheNewKeyIsNeverOverwritten() throws {
        try addGame()
        let other = PVGame()
        other.md5Hash = newMD5
        other.title = "Pocket Monsters (Translated)"
        try realm.write { realm.add(other) }

        XCTAssertThrowsError(try rekey()) { error in
            XCTAssertEqual(error as? GameRekey.Failure, .targetExists(title: "Pocket Monsters (Translated)"))
        }
        XCTAssertEqual(realm.object(ofType: PVGame.self, forPrimaryKey: oldMD5)?.saveStates.count, 1)
        XCTAssertEqual(realm.object(ofType: PVGame.self, forPrimaryKey: oldMD5)?.crc, "11111111")
    }

    func testAMissingGameThrows() throws {
        XCTAssertThrowsError(try rekey()) { error in
            XCTAssertEqual(error as? GameRekey.Failure, .gameNotFound)
        }
    }
}
