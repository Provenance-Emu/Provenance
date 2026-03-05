//
//  SwiftDataDatabaseDriverTests.swift
//  PVLibraryTests
//
//  Created by Agent on 2026-03-05.
//

#if canImport(SwiftData)
import SwiftData
import XCTest
@testable import PVLibrary

@available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, visionOS 1.0, *)
final class SwiftDataDatabaseDriverTests: XCTestCase {

    var driver: SwiftDataDatabaseDriver!

    override func setUpWithError() throws {
        try super.setUpWithError()
        driver = try SwiftDataDatabaseDriver(inMemory: true)
    }

    override func tearDownWithError() throws {
        if let driver {
            try driver.deleteAll()
            self.driver = nil
        }
        try super.tearDownWithError()
    }

    // MARK: - Container / setup

    func testContainerCreation() {
        XCTAssertNotNil(driver.modelContainer)
        XCTAssertNotNil(driver.modelContext)
    }

    // MARK: - Game CRUD

    func testInsertAndFetchGame() throws {
        let game = Game_Data(title: "Test Game", md5Hash: "abc123")
        try driver.insert(game: game)

        let fetched = driver.game(identifier: game.md5Hash)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Test Game")
        XCTAssertEqual(fetched?.md5Hash, "abc123")
    }

    func testFetchGameByIdentifier() throws {
        let game = Game_Data(title: "Metroid", md5Hash: "deadbeef")
        try driver.insert(game: game)

        let fetched = driver.game(identifier: game.md5Hash)
        XCTAssertEqual(fetched?.md5Hash, game.md5Hash)
    }

    func testFetchGameMissing() {
        let result = driver.game(identifier: "nonexistent-md5hash")
        XCTAssertNil(result)
    }

    func testDeleteGame() throws {
        let game = Game_Data(title: "Deletable", md5Hash: "del01")
        try driver.insert(game: game)
        XCTAssertNotNil(driver.game(identifier: game.md5Hash))

        try driver.delete(game: game)
        XCTAssertNil(driver.game(identifier: game.md5Hash))
    }

    func testAllGames() throws {
        let g1 = Game_Data(title: "Alpha", md5Hash: "m1")
        let g2 = Game_Data(title: "Beta",  md5Hash: "m2")
        try driver.insert(game: g1)
        try driver.insert(game: g2)

        let all = try driver.allGames()
        XCTAssertEqual(all.count, 2)
    }

    func testUpdateGame() throws {
        let game = Game_Data(title: "Original", md5Hash: "upd01")
        try driver.insert(game: game)

        game.title = "Updated"
        try driver.save()

        let fetched = driver.game(identifier: game.md5Hash)
        XCTAssertEqual(fetched?.title, "Updated")
    }

    func testFavoriteGames() throws {
        let fav  = Game_Data(title: "Fav",    md5Hash: "fav1", isFavorite: true)
        let notFav = Game_Data(title: "NotFav", md5Hash: "nfav1")
        try driver.insert(game: fav)
        try driver.insert(game: notFav)

        let favorites = try driver.favoriteGames()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.id, fav.id)
    }

    func testSearchGames() throws {
        let g1 = Game_Data(title: "Super Mario",  md5Hash: "sm1")
        let g2 = Game_Data(title: "Sonic the Hedgehog", md5Hash: "sh1")
        try driver.insert(game: g1)
        try driver.insert(game: g2)

        let results = try driver.searchGames(for: "mario")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Super Mario")
    }

    func testSearchGamesEmptyReturnsAll() throws {
        let g1 = Game_Data(title: "A", md5Hash: "a1")
        let g2 = Game_Data(title: "B", md5Hash: "b1")
        try driver.insert(game: g1)
        try driver.insert(game: g2)

        let results = try driver.searchGames(for: "")
        XCTAssertEqual(results.count, 2)
    }

    func testGamesForSystem() throws {
        let sysID = "com.provenance.nes"
        let g1 = Game_Data(title: "NES Game 1", md5Hash: "n1", systemIdentifier: sysID)
        let g2 = Game_Data(title: "NES Game 2", md5Hash: "n2", systemIdentifier: sysID)
        let g3 = Game_Data(title: "SNES Game",  md5Hash: "s1", systemIdentifier: "com.provenance.snes")
        try driver.insert(game: g1)
        try driver.insert(game: g2)
        try driver.insert(game: g3)

        let nesGames = try driver.games(forSystemIdentifier: sysID)
        XCTAssertEqual(nesGames.count, 2)
        XCTAssertTrue(nesGames.allSatisfy { $0.systemIdentifier == sysID })
    }

    // MARK: - System CRUD

    func testInsertAndFetchSystem() throws {
        let system = System_Data(name: "Nintendo Entertainment System",
                                 shortName: "NES",
                                 identifier: "com.provenance.nes")
        try driver.insert(system: system)

        let fetched = driver.system(identifier: "com.provenance.nes")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Nintendo Entertainment System")
        XCTAssertEqual(fetched?.shortName, "NES")
    }

    func testFetchSystemByIdentifier() throws {
        let system = System_Data(name: "SNES", shortName: "SNES",
                                  identifier: "com.provenance.snes")
        try driver.insert(system: system)

        let fetched = driver.system(identifier: "com.provenance.snes")
        XCTAssertEqual(fetched?.identifier, "com.provenance.snes")
    }

    func testFetchSystemMissing() {
        let result = driver.system(identifier: "com.provenance.nonexistent")
        XCTAssertNil(result)
    }

    func testDeleteSystem() throws {
        let system = System_Data(name: "Atari 2600", shortName: "2600",
                                  identifier: "com.provenance.2600")
        try driver.insert(system: system)
        XCTAssertNotNil(driver.system(identifier: "com.provenance.2600"))

        try driver.delete(system: system)
        XCTAssertNil(driver.system(identifier: "com.provenance.2600"))
    }

    func testAllSystems() throws {
        let s1 = System_Data(name: "NES",  shortName: "NES",  identifier: "com.provenance.nes")
        let s2 = System_Data(name: "SNES", shortName: "SNES", identifier: "com.provenance.snes")
        try driver.insert(system: s1)
        try driver.insert(system: s2)

        let all = try driver.allSystems()
        XCTAssertEqual(all.count, 2)
    }

    // MARK: - SaveState CRUD

    func testInsertAndFetchSaveState() throws {
        let saveState = SaveState_Data(isAutosave: true)
        try driver.insert(saveState: saveState)

        let all = try driver.allSaveStates()
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all.first?.isAutosave == true)
    }

    func testDeleteSaveState() throws {
        let saveState = SaveState_Data()
        try driver.insert(saveState: saveState)
        XCTAssertEqual(try driver.allSaveStates().count, 1)

        try driver.delete(saveState: saveState)
        XCTAssertEqual(try driver.allSaveStates().count, 0)
    }

    // MARK: - RecentGame CRUD

    func testInsertAndFetchRecentGame() throws {
        let recent = RecentGame_Data()
        try driver.insert(recentGame: recent)

        let all = try driver.allRecentGames()
        XCTAssertEqual(all.count, 1)
    }

    func testDeleteRecentGame() throws {
        let recent = RecentGame_Data()
        try driver.insert(recentGame: recent)
        XCTAssertEqual(try driver.allRecentGames().count, 1)

        try driver.delete(recentGame: recent)
        XCTAssertEqual(try driver.allRecentGames().count, 0)
    }

    // MARK: - DeleteAll

    func testDeleteAll() throws {
        let game = Game_Data(title: "G", md5Hash: "g1")
        let system = System_Data(name: "S", shortName: "S", identifier: "com.test.s")
        let save = SaveState_Data()
        try driver.insert(game: game)
        try driver.insert(system: system)
        try driver.insert(saveState: save)

        try driver.deleteAll()

        XCTAssertEqual(try driver.allGames().count, 0)
        XCTAssertEqual(try driver.allSystems().count, 0)
        XCTAssertEqual(try driver.allSaveStates().count, 0)
    }
}

// MARK: - SwiftDataDatabaseActor Tests

@available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, visionOS 1.0, *)
final class SwiftDataDatabaseActorTests: XCTestCase {

    var container: ModelContainer!
    var actor: SwiftDataDatabaseActor!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try PVSwiftDataSchema.makePVModelContainer(inMemory: true)
        actor = SwiftDataDatabaseActor(modelContainer: container)
    }

    override func tearDownWithError() throws {
        actor = nil
        container = nil
        try super.tearDownWithError()
    }

    func testActorInsertAndFetchGame() async throws {
        let game = Game_Data(title: "Async Game", md5Hash: "async1")
        try await actor.insert(game: game)

        let fetched = try await actor.game(identifier: game.md5Hash)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Async Game")
    }

    func testActorInsertAndFetchSystem() async throws {
        let system = System_Data(name: "Async System", shortName: "AS",
                                  identifier: "com.async.test")
        try await actor.insert(system: system)

        let fetched = try await actor.system(identifier: "com.async.test")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Async System")
    }

    func testActorDeleteAll() async throws {
        let game = Game_Data(title: "To Delete", md5Hash: "del1")
        try await actor.insert(game: game)

        try await actor.deleteAll()

        let all = try await actor.allGames()
        XCTAssertEqual(all.count, 0)
    }

    func testActorFetchMissingGame() async throws {
        let result = try await actor.game(identifier: "missing")
        XCTAssertNil(result)
    }

    func testActorDeleteGame() async throws {
        let game = Game_Data(title: "Will Delete", md5Hash: "wd1")
        try await actor.insert(game: game)
        XCTAssertNotNil(try await actor.game(identifier: game.md5Hash))

        try await actor.delete(game: game)
        XCTAssertNil(try await actor.game(identifier: game.md5Hash))
    }
}
#endif
