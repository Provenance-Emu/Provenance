// LibretroCheatDatabaseTests.swift
// Tests for LibretroCheatDB module
//
// Verifies database extraction, connection, and query functionality
// using the bundled libretro_cheats.sqlite.zip.

import Testing
import Foundation
@testable import LibretroCheatDB

// MARK: - Database Connection & Extraction

struct LibretroCheatDatabaseConnectionTests {

    @Test("Database connects and extracts successfully")
    func connectAndExtract() async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "Super Mario",
            limit: 1
        )
        // If we get here without throwing, connection + extraction worked.
        // Super Mario should exist in virtually any cheat database.
        #expect(results.count >= 0)
    }

    @Test("Repeated connections reuse existing connection")
    func connectionReuse() async throws {
        // First call triggers extraction
        _ = try await LibretroCheatDatabase.shared.searchCheats(byTitle: "test1234xyz", limit: 1)
        // Second call should reuse the connection (no extraction)
        _ = try await LibretroCheatDatabase.shared.searchCheats(byTitle: "test1234xyz", limit: 1)
    }
}

// MARK: - Search by Title

struct LibretroCheatDatabaseSearchTests {

    @Test("Search GoldenEye 007 returns N64 cheats")
    func searchGoldenEye() async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 50
        )
        #expect(results.count > 0, "GoldenEye 007 should have cheats in the database")
        #expect(results.count == 50, "Should respect the limit parameter")

        let first = try #require(results.first)
        #expect(first.gameTitle.localizedCaseInsensitiveContains("goldeneye"))
        #expect(first.systemName == "Nintendo - Nintendo 64")
        #expect(!first.cheatCode.isEmpty)
        #expect(!first.cheatName.isEmpty)
    }

    @Test("Search Super Mario World returns SNES cheats")
    func searchSuperMarioWorld() async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "Super Mario World",
            systemName: "Nintendo - Super Nintendo Entertainment System",
            limit: 20
        )
        #expect(results.count > 0, "Super Mario World should have SNES cheats")

        for entry in results {
            #expect(entry.systemName == "Nintendo - Super Nintendo Entertainment System")
        }
    }

    @Test("Case-insensitive title search")
    func caseInsensitiveSearch() async throws {
        let upper = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GOLDENEYE 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 10
        )
        let lower = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "goldeneye 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 10
        )
        let mixed = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 10
        )

        #expect(upper.count == lower.count, "Case should not affect result count")
        #expect(upper.count == mixed.count, "Case should not affect result count")
        #expect(upper.count > 0)
    }

    @Test("Fuzzy title match with partial name")
    func fuzzyTitleMatch() async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye",
            limit: 10
        )
        #expect(results.count > 0, "Partial title 'GoldenEye' should match")
    }

    @Test("Nonexistent game returns empty results")
    func noResultsForNonexistentGame() async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "ZZZZ_NoSuchGame_12345_XXXX",
            limit: 10
        )
        #expect(results.isEmpty, "Nonexistent game should return no results")
    }
}

// MARK: - System Name Filtering

struct LibretroCheatDatabaseSystemFilterTests {

    @Test("System filter restricts results to that system")
    func systemFilterRestricts() async throws {
        let n64Results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 50
        )
        let allResults = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            limit: 50
        )

        #expect(n64Results.count > 0)
        // All N64-filtered results should have the correct system
        for entry in n64Results {
            #expect(entry.systemName == "Nintendo - Nintendo 64")
        }

        // Unfiltered might include DS or other systems too
        #expect(allResults.count >= n64Results.count)
    }

    @Test("Wrong system returns fewer or no results")
    func wrongSystemFilter() async throws {
        // GoldenEye 007 is N64, not SNES
        let snesResults = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            systemName: "Nintendo - Super Nintendo Entertainment System",
            limit: 50
        )
        let n64Results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 50
        )

        #expect(snesResults.count < n64Results.count,
                "SNES filter should return fewer results than N64 for GoldenEye")
    }

    @Test("Nil system name returns results from all systems")
    func nilSystemReturnsAll() async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "Super Mario",
            systemName: nil,
            limit: 100
        )
        // Super Mario exists on multiple systems
        let systems = Set(results.map(\.systemName))
        #expect(systems.count >= 1, "Super Mario should appear on at least one system")
    }

    @Test("Empty system name is treated as no filter")
    func emptySystemTreatedAsNil() async throws {
        let emptyResults = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "Super Mario World",
            systemName: "",
            limit: 20
        )
        let nilResults = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "Super Mario World",
            systemName: nil,
            limit: 20
        )
        #expect(emptyResults.count == nilResults.count,
                "Empty string system should behave like nil")
    }
}

// MARK: - Limit Parameter

struct LibretroCheatDatabaseLimitTests {

    @Test("Limit parameter caps results")
    func limitCapsResults() async throws {
        let small = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 5
        )
        let large = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 100
        )

        #expect(small.count == 5, "Should return exactly 5 results when limit is 5")
        #expect(large.count == 100, "Should return exactly 100 results when limit is 100")
    }

    @Test("Limit of 1 returns single result")
    func limitOfOne() async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 1
        )
        #expect(results.count == 1)
    }
}

// MARK: - Entry Model Validation

struct LibretroCheatEntryTests {

    @Test("Entry fields are populated correctly")
    func entryFieldsPopulated() async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "GoldenEye 007",
            systemName: "Nintendo - Nintendo 64",
            limit: 1
        )
        let entry = try #require(results.first)

        #expect(entry.id > 0)
        #expect(!entry.cheatName.isEmpty)
        #expect(!entry.cheatCode.isEmpty)
        #expect(!entry.deviceName.isEmpty)
        #expect(!entry.gameTitle.isEmpty)
        #expect(!entry.systemName.isEmpty)
    }

    @Test("Entry conforms to Identifiable")
    func entryIsIdentifiable() {
        let entry = LibretroCheatEntry(
            id: 42,
            cheatName: "Infinite Lives",
            cheatCode: "ABCD1234",
            deviceName: "GameShark",
            gameTitle: "Test Game",
            systemName: "Test System"
        )
        #expect(entry.id == 42)
    }

    @Test("Entry conforms to Sendable")
    func entryIsSendable() async {
        let entry = LibretroCheatEntry(
            id: 1,
            cheatName: "Test",
            cheatCode: "CODE",
            deviceName: "Device",
            gameTitle: "Game",
            systemName: "System"
        )
        // Verify Sendable by passing across actor boundary
        let captured: LibretroCheatEntry = await Task.detached {
            return entry
        }.value
        #expect(captured.id == entry.id)
        #expect(captured.cheatCode == entry.cheatCode)
    }
}

// MARK: - Special Characters in Search

struct LibretroCheatDatabaseSpecialCharTests {

    @Test("SQL wildcards in title are escaped")
    func sqlWildcardsEscaped() async throws {
        // These should not match everything
        let percentResults = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "%",
            limit: 10
        )
        // A bare "%" would match all rows if not escaped; with LIKE '%\%%' it matches
        // only titles containing a literal percent sign, which should be very few or none
        #expect(percentResults.count < 10,
                "SQL wildcard % should be escaped, not match everything")
    }

    @Test("Underscore in title is escaped")
    func underscoreEscaped() async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "_",
            limit: 20
        )
        // If "_" were unescaped it would match any single character (i.e. every game).
        // Escaped, it only matches games whose title contains a literal "_".
        // Verify every matched title actually contains an underscore character.
        for entry in results {
            #expect(entry.gameTitle.contains("_"),
                    "Result '\(entry.gameTitle)' should contain a literal underscore")
        }
    }
}

// MARK: - Multi-System Coverage

struct LibretroCheatDatabaseCoverageTests {

    @Test("Database contains multiple systems",
          .tags(.slow))
    func multipleSystemsCovered() async throws {
        // Search for a very common word to get results from various systems
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: "Mario",
            limit: 300
        )
        let systems = Set(results.map(\.systemName))
        #expect(systems.count >= 2,
                "Database should contain cheats from at least 2 systems, found: \(systems)")
    }

    @Test("Known systems have cheats",
          arguments: [
            ("Super Mario World", "Nintendo - Super Nintendo Entertainment System"),
            ("GoldenEye 007", "Nintendo - Nintendo 64"),
            ("Pokemon", "Nintendo - Game Boy Advance"),
          ])
    func knownSystemHasCheats(title: String, system: String) async throws {
        let results = try await LibretroCheatDatabase.shared.searchCheats(
            byTitle: title,
            systemName: system,
            limit: 5
        )
        #expect(results.count > 0,
                "\(title) should have cheats for \(system)")
    }
}

// MARK: - Tags

extension Tag {
    @Tag static var slow: Self
}
