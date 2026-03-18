//
//  GameEntityTests.swift
//  PVAppIntentsTests
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVAppIntents

#if canImport(AppIntents)
final class GameEntityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameEntityStore.shared.update(all: [], recents: [])
        SystemEntityStore.shared.update(all: [])
        SaveStateEntityStore.shared.update(all: [], recents: [])
    }

    override func tearDown() {
        GameEntityStore.shared.update(all: [], recents: [])
        SystemEntityStore.shared.update(all: [])
        SaveStateEntityStore.shared.update(all: [], recents: [])
        super.tearDown()
    }

    // MARK: - EntityStore Tests

    func testGameEntityStoreStoresAndRetrievesEntities() {
        let store = GameEntityStore.shared
        let entity = GameEntity(
            id: "abc123",
            title: "Super Mario World",
            systemName: "Super Nintendo",
            systemIdentifier: "com.provenance.snes",
            isFavorite: true,
            lastPlayedDate: Date(),
            artworkURL: nil
        )
        store.update(all: [entity], recents: [entity])

        let retrieved = store.entity(for: "abc123")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "Super Mario World")
        XCTAssertEqual(retrieved?.systemName, "Super Nintendo")
        XCTAssertTrue(retrieved?.isFavorite == true)
    }

    func testGameEntityStoreReturnsNilForUnknownID() {
        let store = GameEntityStore.shared
        let result = store.entity(for: "does-not-exist-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testGameEntityStoreRecentEntitiesRespectLimit() {
        let store = GameEntityStore.shared
        let entities = (0..<10).map { i in
            GameEntity(
                id: "game-\(i)",
                title: "Game \(i)",
                systemName: "NES",
                systemIdentifier: "com.provenance.nes",
                isFavorite: false
            )
        }
        store.update(all: entities, recents: entities)
        let recents = store.recentEntities(limit: 3)
        XCTAssertEqual(recents.count, 3)
    }

    // MARK: - GameEntity Tests

    func testDeepLinkURLContainsMD5() {
        let entity = GameEntity(
            id: "deadbeef",
            title: "Test Game",
            systemName: "Game Boy",
            systemIdentifier: "com.provenance.gb",
            isFavorite: false
        )
        let url = entity.deepLinkURL
        XCTAssertTrue(url.absoluteString.contains("deadbeef"))
        XCTAssertTrue(url.scheme == "provenance")
    }

    // MARK: - SystemEntityStore Tests

    func testSystemEntityStoreStoresAndSorts() {
        let store = SystemEntityStore.shared
        let systems = [
            SystemEntity(id: "com.provenance.nes", name: "Nintendo Entertainment System", manufacturer: "Nintendo", gameCount: 5),
            SystemEntity(id: "com.provenance.snes", name: "Super Nintendo", manufacturer: "Nintendo", gameCount: 12)
        ]
        store.update(all: systems)

        let all = store.allEntities()
        // Should be sorted by name: NES before SNES alphabetically
        XCTAssertEqual(all.first?.id, "com.provenance.nes")
    }

    // MARK: - SaveStateEntity Tests

    func testSaveStateDeepLinkURL() {
        let entity = SaveStateEntity(
            id: "state-uuid-001",
            gameTitle: "Sonic the Hedgehog",
            gameMD5: "abc123",
            slot: 1,
            date: Date()
        )
        let url = entity.deepLinkURL
        XCTAssertTrue(url.absoluteString.contains("abc123"))
        XCTAssertTrue(url.absoluteString.contains("state-uuid-001"))
        XCTAssertTrue(url.absoluteString.contains("saveStateId"))
    }

    // MARK: - GameEntity favourite count

    func testFavoriteCountInGameEntityStore() {
        let store = GameEntityStore.shared
        let entities = [
            GameEntity(id: "fav1", title: "Fave Game", systemName: "SNES", systemIdentifier: "com.provenance.snes", isFavorite: true),
            GameEntity(id: "fav2", title: "Not Fave", systemName: "SNES", systemIdentifier: "com.provenance.snes", isFavorite: false),
            GameEntity(id: "fav3", title: "Also Fave", systemName: "NES", systemIdentifier: "com.provenance.nes", isFavorite: true)
        ]
        store.update(all: entities, recents: [])
        let favoriteCount = store.allEntities().filter { $0.isFavorite }.count
        XCTAssertEqual(favoriteCount, 2)
    }

    // MARK: - AppIntentError

    func testAppIntentErrorDescription() {
        let error = AppIntentError.noGamesFound(in: "Super Nintendo")
        XCTAssertEqual(error.errorDescription, "No games found in Super Nintendo.")
    }
}
#endif
