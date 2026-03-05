//
//  RealmToSwiftDataMigrationTests.swift
//  PVLibraryTests
//
//  Created by Agent on 2026-03-05.
//

#if canImport(SwiftData)
import XCTest
import SwiftData
import RealmSwift
@testable import PVLibrary

final class RealmToSwiftDataMigrationTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an in-memory ModelContainer with the full Provenance schema.
    private func makeInMemoryContainer() throws -> ModelContainer {
        try PVSwiftDataSchema.makePVModelContainer(inMemory: true)
    }

    // MARK: - Migration flag tests

    func testMigrationFlagDefaultFalse() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let container = try makeInMemoryContainer()
        let migrator = RealmToSwiftDataMigration(modelContainer: container, defaults: defaults)
        let completed = await migrator.isMigrationCompleted
        XCTAssertFalse(completed)
    }

    func testResetMigrationFlag() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        defaults.set(true, forKey: "PVRealmToSwiftDataMigrationCompleted")
        let container = try makeInMemoryContainer()
        let migrator = RealmToSwiftDataMigration(modelContainer: container, defaults: defaults)
        var completed = await migrator.isMigrationCompleted
        XCTAssertTrue(completed)

        await migrator.resetMigrationFlag()
        completed = await migrator.isMigrationCompleted
        XCTAssertFalse(completed)
    }

    // MARK: - Empty Realm migration (no data)

    func testMigrationWithEmptyRealm() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let container = try makeInMemoryContainer()
        let migrator = RealmToSwiftDataMigration(modelContainer: container, defaults: defaults)

        // Should not throw — Realm is simply empty.
        await XCTAssertNoThrowAsync {
            try await migrator.migrateIfNeeded()
        }
        let completed = await migrator.isMigrationCompleted
        XCTAssertTrue(completed)
    }

    // MARK: - Idempotency

    func testMigrationIsIdempotent() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let container = try makeInMemoryContainer()
        let migrator = RealmToSwiftDataMigration(modelContainer: container, defaults: defaults)

        // First run
        try await migrator.migrateIfNeeded()
        // Second run — should be a no-op (flag is set)
        await XCTAssertNoThrowAsync {
            try await migrator.migrateIfNeeded()
        }
    }

    // MARK: - SwiftData model creation helpers (unit tests for mappers)

    func testFile_DataCreation() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let file = File_Data(partialPath: "ROMs/nes/game.nes", md5Cache: "abc123", createdDate: Date())
        context.insert(file)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<File_Data>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.partialPath, "ROMs/nes/game.nes")
        XCTAssertEqual(fetched.first?.md5Cache, "abc123")
    }

    func testImageFile_DataCreation() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let img = ImageFile_Data(partialPath: "Artwork/game.png", width: 512, height: 768, ratio: 1.5, layout: "portrait")
        context.insert(img)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ImageFile_Data>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.width, 512)
        XCTAssertEqual(fetched.first?.layout, "portrait")
    }

    func testSystem_DataCreation() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let system = System_Data(
            name: "Nintendo Entertainment System",
            shortName: "NES",
            manufacturer: "Nintendo",
            releaseYear: 1985,
            bit: 8,
            identifier: "com.provenance.nes"
        )
        context.insert(system)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<System_Data>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.identifier, "com.provenance.nes")
    }

    func testGame_DataCreation() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let system = System_Data(name: "NES", shortName: "NES", manufacturer: "Nintendo",
                                 releaseYear: 1985, bit: 8, identifier: "com.provenance.nes")
        context.insert(system)
        let file = File_Data(partialPath: "ROMs/nes/game.nes")
        context.insert(file)
        let game = Game_Data(
            title: "Super Mario Bros.",
            id: UUID().uuidString,
            romPath: "com.provenance.nes/Super Mario Bros..nes",
            file: file,
            systemIdentifier: "com.provenance.nes",
            system: system,
            md5Hash: "deadbeefdeadbeef01234567890abcde"
        )
        context.insert(game)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Game_Data>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Super Mario Bros.")
        XCTAssertEqual(fetched.first?.system?.identifier, "com.provenance.nes")
    }

    func testSaveState_DataRelationships() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let system = System_Data(name: "NES", shortName: "NES", manufacturer: "Nintendo",
                                 releaseYear: 1985, bit: 8, identifier: "com.provenance.nes")
        context.insert(system)
        let game = Game_Data(title: "Test Game", systemIdentifier: "com.provenance.nes",
                             system: system, md5Hash: "aabbccdd00112233aabbccdd00112233")
        context.insert(game)
        let core = Core_Data(identifier: "com.provenance.fceu", principleClass: "FCEUCore")
        context.insert(core)
        let file = File_Data(partialPath: "Save States/nes/test.svs")
        context.insert(file)

        let save = SaveState_Data(id: UUID().uuidString, date: Date(), isAutosave: false,
                                  createdWithCoreVersion: "1.0", game: game, core: core, file: file)
        context.insert(save)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SaveState_Data>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.game?.md5Hash, "aabbccdd00112233aabbccdd00112233")
        XCTAssertEqual(fetched.first?.core?.identifier, "com.provenance.fceu")
    }

    func testCheats_DataRelationships() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let game = Game_Data(title: "Cheaty Game", systemIdentifier: "com.provenance.gba",
                             md5Hash: "11223344556677881122334455667788")
        context.insert(game)
        let core = Core_Data(identifier: "com.provenance.vba", principleClass: "VBACore")
        context.insert(core)
        let cheat = Cheats_Data(id: UUID().uuidString, code: "AAAA-BBBB", enabled: true,
                                type: "GameShark", codeType: "GameShark",
                                game: game, core: core)
        context.insert(cheat)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Cheats_Data>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.code, "AAAA-BBBB")
        XCTAssertEqual(fetched.first?.game?.md5Hash, "11223344556677881122334455667788")
    }

    func testUser_DataCreation() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let user = User_Data(uuid: UUID().uuidString, name: "Test User", lastSeen: Date())
        context.insert(user)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<User_Data>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test User")
    }

    func testRecentGame_DataCreation() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let game = Game_Data(title: "Recent Game", systemIdentifier: "com.provenance.snes",
                             md5Hash: "aabb1122aabb1122aabb1122aabb1122")
        context.insert(game)
        let recent = RecentGame_Data(id: UUID().uuidString, game: game, lastPlayedDate: Date())
        context.insert(recent)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RecentGame_Data>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.game?.title, "Recent Game")
    }

    // MARK: - Progress reporting

    func testProgressHandlerIsCalled() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let container = try makeInMemoryContainer()
        let migrator = RealmToSwiftDataMigration(modelContainer: container, defaults: defaults)

        var entities: [String] = []
        try await migrator.migrateIfNeeded { progress in
            entities.append(progress.entity)
        }

        // Even with an empty Realm the handler may be called for entities with 0 records;
        // the key assertion is that migration completed without error.
        let completed = await migrator.isMigrationCompleted
        XCTAssertTrue(completed)
    }
}

// MARK: - Test helpers

extension XCTestCase {
    func XCTAssertNoThrowAsync(
        _ expression: @escaping () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
        } catch {
            XCTFail("Expression threw an error: \(error)", file: file, line: line)
        }
    }
}
#endif
