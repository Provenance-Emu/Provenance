//
//  SwiftDataCRUDTests.swift
//  PVLibraryTests
//
//  Created by Agent on 2026-03-05.
//
//  Unit tests for SwiftData CRUD operations.
//  Covers Task 9 of issue #2556: Realm → SwiftData migration validation.
//

#if canImport(SwiftData)
import XCTest
import SwiftData
import PVPrimitives
@testable import PVLibrary

// MARK: - Container helpers

private func makeInMemoryContainer() throws -> ModelContainer {
    try PVSwiftDataSchema.makePVModelContainer(inMemory: true)
}

// MARK: - Game CRUD tests

final class SwiftDataGameCRUDTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testCreateGame() throws {
        let game = Game_Data(title: "Super Mario Bros",
                             id: "game-1",
                             md5Hash: "abc123def456")
        context.insert(game)
        try context.save()

        let descriptor = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.id == "game-1" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Super Mario Bros")
        XCTAssertEqual(results.first?.md5Hash, "abc123def456")
    }

    func testReadAllGames() throws {
        for i in 0..<5 {
            let game = Game_Data(title: "Game \(i)",
                                 id: "game-read-\(i)",
                                 md5Hash: "hash\(i)")
            context.insert(game)
        }
        try context.save()

        let descriptor = FetchDescriptor<Game_Data>()
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.count, 5)
    }

    func testUpdateGame() throws {
        let game = Game_Data(title: "Original Title",
                             id: "game-update-1",
                             md5Hash: "hashUpd")
        context.insert(game)
        try context.save()

        game.title = "Updated Title"
        game.isFavorite = true
        try context.save()

        let descriptor = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.id == "game-update-1" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.first?.title, "Updated Title")
        XCTAssertEqual(results.first?.isFavorite, true)
    }

    func testDeleteGame() throws {
        let game = Game_Data(title: "To Delete",
                             id: "game-delete-1",
                             md5Hash: "hashDel")
        context.insert(game)
        try context.save()

        context.delete(game)
        try context.save()

        let descriptor = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.id == "game-delete-1" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertTrue(results.isEmpty)
    }

    func testGameMD5Uniqueness() throws {
        let game1 = Game_Data(title: "Game A", id: "g-uniq-1", md5Hash: "same-md5")
        let game2 = Game_Data(title: "Game B", id: "g-uniq-2", md5Hash: "same-md5")
        context.insert(game1)
        context.insert(game2)
        // SwiftData enforces @Attribute(.unique) at the store level; inserting a duplicate
        // should upsert or throw — either way only one record with that md5 should remain.
        var saveError: Error?
        do {
            try context.save()
        } catch {
            saveError = error
        }

        // Regardless of whether the save merged or threw, at most one record with this md5
        // should exist in the store.
        let descriptor = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.md5Hash == "same-md5" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertLessThanOrEqual(results.count, 1,
            "Expected at most one Game_Data with md5Hash \"same-md5\" after enforcing uniqueness.")

        if let nsError = saveError as NSError? {
            // If a failure occurred, ensure it's a persistence/validation-style error.
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain,
                "Expected a Cocoa persistence error for unique-constraint violation.")
        }
    }
}

// MARK: - System CRUD tests

final class SwiftDataSystemCRUDTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testCreateSystem() throws {
        let system = System_Data(name: "Nintendo Entertainment System",
                                 shortName: "NES",
                                 manufacturer: "Nintendo",
                                 identifier: "com.provenance.nes")
        context.insert(system)
        try context.save()

        let descriptor = FetchDescriptor<System_Data>(
            predicate: #Predicate { $0.identifier == "com.provenance.nes" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Nintendo Entertainment System")
        XCTAssertEqual(results.first?.shortName, "NES")
    }

    func testUpdateSystem() throws {
        let system = System_Data(name: "Old Name",
                                 shortName: "ON",
                                 manufacturer: "Mfr",
                                 identifier: "com.provenance.test-sys")
        context.insert(system)
        try context.save()

        system.name = "New Name"
        system.requiresBIOS = true
        try context.save()

        let descriptor = FetchDescriptor<System_Data>(
            predicate: #Predicate { $0.identifier == "com.provenance.test-sys" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.first?.name, "New Name")
        XCTAssertEqual(results.first?.requiresBIOS, true)
    }

    func testDeleteSystem() throws {
        let system = System_Data(name: "Delete Me",
                                 shortName: "DM",
                                 manufacturer: "Test",
                                 identifier: "com.provenance.del-sys")
        context.insert(system)
        try context.save()

        context.delete(system)
        try context.save()

        let descriptor = FetchDescriptor<System_Data>(
            predicate: #Predicate { $0.identifier == "com.provenance.del-sys" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertTrue(results.isEmpty)
    }
}

// MARK: - SaveState CRUD tests

final class SwiftDataSaveStateCRUDTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testCreateSaveState() throws {
        let saveState = SaveState_Data(id: "ss-1",
                                      date: Date(),
                                      isAutosave: false,
                                      createdWithCoreVersion: "1.0")
        context.insert(saveState)
        try context.save()

        let descriptor = FetchDescriptor<SaveState_Data>(
            predicate: #Predicate { $0.id == "ss-1" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        let saveState = try XCTUnwrap(results.first)
        XCTAssertFalse(saveState.isAutosave)
    }

    func testAutosaveFlagRoundtrip() throws {
        let saveState = SaveState_Data(id: "ss-auto",
                                      isAutosave: true,
                                      createdWithCoreVersion: "2.0")
        context.insert(saveState)
        try context.save()

        let descriptor = FetchDescriptor<SaveState_Data>(
            predicate: #Predicate { $0.id == "ss-auto" }
        )
        let results = try context.fetch(descriptor)
        let saveState = try XCTUnwrap(results.first)
        XCTAssertTrue(saveState.isAutosave)
    }

    func testDeleteSaveState() throws {
        let saveState = SaveState_Data(id: "ss-del")
        context.insert(saveState)
        try context.save()

        context.delete(saveState)
        try context.save()

        let descriptor = FetchDescriptor<SaveState_Data>(
            predicate: #Predicate { $0.id == "ss-del" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertTrue(results.isEmpty)
    }
}

// MARK: - Core CRUD tests

final class SwiftDataCoreCRUDTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testCreateCore() throws {
        let core = Core_Data(identifier: "com.provenance.nestopia",
                             principleClass: "PVNestopia",
                             projectName: "Nestopia",
                             projectURL: "https://nestopia.sourceforge.net",
                             projectVersion: "1.51.1")
        context.insert(core)
        try context.save()

        let descriptor = FetchDescriptor<Core_Data>(
            predicate: #Predicate { $0.identifier == "com.provenance.nestopia" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.projectName, "Nestopia")
    }

    func testCoreDisabledFlag() throws {
        let core = Core_Data(identifier: "com.provenance.disabled",
                             principleClass: "PVDisabled",
                             disabled: false)
        context.insert(core)
        try context.save()

        core.disabled = true
        try context.save()

        let descriptor = FetchDescriptor<Core_Data>(
            predicate: #Predicate { $0.identifier == "com.provenance.disabled" }
        )
        let results = try context.fetch(descriptor)
        let core = try XCTUnwrap(results.first)
        XCTAssertTrue(core.disabled)
    }
}

// MARK: - BIOS CRUD tests

final class SwiftDataBIOSCRUDTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testCreateBIOS() throws {
        let bios = BIOS_Data(expectedFilename: "scph1001.bin",
                             expectedMD5: "924E392ED05558FFDB115408C263DCCF",
                             expectedSize: 524288,
                             optional: false,
                             descriptionText: "PlayStation BIOS",
                             regions: .usa,
                             version: "1.0")
        context.insert(bios)
        try context.save()

        let descriptor = FetchDescriptor<BIOS_Data>(
            predicate: #Predicate { $0.expectedFilename == "scph1001.bin" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.expectedSize, 524288)
    }
}

// MARK: - Relationship integrity tests

final class SwiftDataRelationshipTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testSystemGamesRelationship() throws {
        let system = System_Data(name: "SNES",
                                 shortName: "SNES",
                                 manufacturer: "Nintendo",
                                 identifier: "com.provenance.snes")
        let game1 = Game_Data(title: "Zelda: A Link to the Past",
                              id: "snes-g1",
                              md5Hash: "zelda-md5")
        let game2 = Game_Data(title: "Super Metroid",
                              id: "snes-g2",
                              md5Hash: "metroid-md5")

        context.insert(system)
        context.insert(game1)
        context.insert(game2)

        system.games.append(game1)
        system.games.append(game2)
        game1.system = system
        game2.system = system

        try context.save()

        let sysDescriptor = FetchDescriptor<System_Data>(
            predicate: #Predicate { $0.identifier == "com.provenance.snes" }
        )
        let fetched = try context.fetch(sysDescriptor)
        XCTAssertEqual(fetched.first?.games.count, 2)
    }

    func testCascadeDeleteGameDeletesSaveStates() throws {
        let game = Game_Data(title: "Cascade Test Game",
                             id: "cascade-g1",
                             md5Hash: "cascade-md5")
        let ss1 = SaveState_Data(id: "cascade-ss1")
        let ss2 = SaveState_Data(id: "cascade-ss2")

        context.insert(game)
        context.insert(ss1)
        context.insert(ss2)

        game.saveStates.append(ss1)
        game.saveStates.append(ss2)
        ss1.game = game
        ss2.game = game

        try context.save()

        // Delete the game; cascade rule should delete save states too
        context.delete(game)
        try context.save()

        let ssDescriptor = FetchDescriptor<SaveState_Data>(
            predicate: #Predicate { $0.id == "cascade-ss1" || $0.id == "cascade-ss2" }
        )
        let remainingSaveStates = try context.fetch(ssDescriptor)
        XCTAssertTrue(remainingSaveStates.isEmpty,
                      "Save states should be cascade-deleted when their game is deleted")
    }

    func testSystemCoresManyToMany() throws {
        let system = System_Data(name: "Game Boy",
                                 shortName: "GB",
                                 manufacturer: "Nintendo",
                                 identifier: "com.provenance.gb")
        let core1 = Core_Data(identifier: "com.provenance.gambatte",
                              principleClass: "PVGambatte")
        let core2 = Core_Data(identifier: "com.provenance.mgba-gb",
                              principleClass: "PVmGBA")

        context.insert(system)
        context.insert(core1)
        context.insert(core2)

        system.cores.append(core1)
        system.cores.append(core2)
        core1.supportedSystems.append(system)
        core2.supportedSystems.append(system)

        try context.save()

        let sysDescriptor = FetchDescriptor<System_Data>(
            predicate: #Predicate { $0.identifier == "com.provenance.gb" }
        )
        let fetched = try context.fetch(sysDescriptor)
        XCTAssertEqual(fetched.first?.cores.count, 2)
    }

    func testGameSaveStateBacklink() throws {
        let game = Game_Data(title: "Backlink Test",
                             id: "backlink-g1",
                             md5Hash: "backlink-md5")
        let ss = SaveState_Data(id: "backlink-ss1")

        context.insert(game)
        context.insert(ss)

        ss.game = game
        game.saveStates.append(ss)
        try context.save()

        let ssDescriptor = FetchDescriptor<SaveState_Data>(
            predicate: #Predicate { $0.id == "backlink-ss1" }
        )
        let fetchedSS = try context.fetch(ssDescriptor)
        XCTAssertEqual(fetchedSS.first?.game?.id, "backlink-g1")
    }
}

// MARK: - Migration simulation tests

final class SwiftDataMigrationSimulationTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    /// Simulates importing a batch of games (as would happen during Realm → SwiftData migration)
    /// and verifies record counts and relationship integrity.
    func testBatchImportPreservesRecordCounts() throws {
        let systemCount = 3
        let gamesPerSystem = 5

        var systems: [System_Data] = []
        for s in 0..<systemCount {
            let system = System_Data(name: "System \(s)",
                                     shortName: "SYS\(s)",
                                     manufacturer: "Mfr\(s)",
                                     identifier: "com.provenance.test-sys-\(s)")
            context.insert(system)
            systems.append(system)
        }

        for (si, system) in systems.enumerated() {
            for g in 0..<gamesPerSystem {
                let game = Game_Data(title: "Game \(g) on \(system.shortName)",
                                     id: "batch-g-\(si)-\(g)",
                                     md5Hash: "batch-hash-\(si)-\(g)")
                context.insert(game)
                game.system = system
                system.games.append(game)
            }
        }
        try context.save()

        let sysDescriptor = FetchDescriptor<System_Data>()
        let gameDescriptor = FetchDescriptor<Game_Data>()
        let fetchedSystems = try context.fetch(sysDescriptor)
        let fetchedGames = try context.fetch(gameDescriptor)

        XCTAssertEqual(fetchedSystems.count, systemCount)
        XCTAssertEqual(fetchedGames.count, systemCount * gamesPerSystem)

        for system in fetchedSystems {
            XCTAssertEqual(system.games.count, gamesPerSystem,
                           "\(system.name) should have exactly \(gamesPerSystem) games")
        }
    }

    /// Verifies that a game saved with an empty md5Hash retains it as-is
    /// (i.e., no automatic population), while a game saved with a non-empty
    /// md5Hash round-trips correctly. This checks actual persistence fidelity
    /// rather than asserting on values we explicitly set.
    func testMD5HashPersistenceFidelity() throws {
        let gameWithHash = Game_Data(title: "Has Hash", id: "md5-fidelity-1", md5Hash: "abc123")
        let gameNoHash = Game_Data(title: "No Hash", id: "md5-fidelity-2", md5Hash: "")
        context.insert(gameWithHash)
        context.insert(gameNoHash)
        try context.save()

        let descriptorWithHash = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.id == "md5-fidelity-1" }
        )
        let descriptorNoHash = FetchDescriptor<Game_Data>(
            predicate: #Predicate { $0.id == "md5-fidelity-2" }
        )
        let withHashResult = try XCTUnwrap(try context.fetch(descriptorWithHash).first)
        let noHashResult = try XCTUnwrap(try context.fetch(descriptorNoHash).first)

        XCTAssertEqual(withHashResult.md5Hash, "abc123",
            "md5Hash should persist exactly as stored.")
        XCTAssertTrue(noHashResult.md5Hash.isEmpty,
            "md5Hash stored as empty should remain empty — no auto-population expected.")
    }
}

// MARK: - Performance tests

final class SwiftDataPerformanceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testInsert1000GamesPerformance() throws {
        // Each measure iteration uses a fresh in-memory container so that
        // data from prior iterations does not accumulate and skew results.
        measure {
            do {
                let freshContainer = try makeInMemoryContainer()
                let localContext = ModelContext(freshContainer)
                for i in 0..<1000 {
                    let game = Game_Data(title: "Perf Game \(i)",
                                         id: "perf-\(i)",
                                         md5Hash: "perf-hash-\(i)")
                    localContext.insert(game)
                }
                try localContext.save()
            } catch {
                XCTFail("Performance test failed with error: \(error)")
            }
        }
    }

    func testFetch1000GamesPerformance() throws {
        for i in 0..<1000 {
            let game = Game_Data(title: "Fetch Perf Game \(i)",
                                 id: "fetch-perf-\(i)",
                                 md5Hash: "fp-hash-\(i)")
            context.insert(game)
        }
        try context.save()

        measure {
            do {
                let descriptor = FetchDescriptor<Game_Data>()
                _ = try context.fetch(descriptor)
            } catch {
                XCTFail("Fetch performance test failed with error: \(error)")
            }
        }
    }
}

#endif // canImport(SwiftData)
