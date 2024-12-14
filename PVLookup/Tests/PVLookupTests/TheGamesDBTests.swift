//
//  TheGamesDBTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//
#if false
import Testing
import PVLogging
@testable import PVLookup
@testable import TheGamesDB

struct Test {

    @Test func testGamesDB() async throws {
        let gamesDB = TheGamesDBService()
        print(gamesDB)
    }

    @Test func testGetGameByID() async throws {
        let gamesDB = TheGamesDBService()
        let game = try await gamesDB.getGame(id: "1018")
        #expect(game != nil)
        #expect(game!.game_title == "1943: The Battle of Midway")
        #expect(game!.rating == "E")
        print(game!)
        #expect(game!.id == 1018)
    }
}
#endif
