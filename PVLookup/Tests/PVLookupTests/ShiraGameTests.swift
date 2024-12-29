//
//  ShiraGameTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Testing
import PVSystems
import Foundation
@testable import ShiraGame
@testable import PVLookupTypes

struct ShiraGameTests {
    let db: ShiraGame

    // Test data based on actual database contents
    let sampleGames = (
        genesis: (
            md5: "cac9928a84e1001817b223f0cecaa3f2",
            crc: "931a0bdc",
            fileName: "3-D Genesis (USA) (Proto).a26",
            entryName: "3-D Genesis (USA) (Proto)",
            title: "3-D Genesis",
            platformId: "ATARI_2600",
            region: "US",
            isUnlicensed: false,
            gameId: 1
        ),
        ticTacToeUS: (
            md5: "0db4f4150fecf77e4ce72ca4d04c052f",
            crc: "58805709",
            fileName: "3-D Tic-Tac-Toe (USA).a26",
            entryName: "3-D Tic-Tac-Toe (USA)",
            title: "3-D Tic-Tac-Toe",
            platformId: "ATARI_2600",
            region: "US",
            isUnlicensed: false,
            gameId: 4
        ),
        ticTacToeEU: (
            md5: "e3600be9eb98146adafdc12d91323d0f",
            crc: "7322ebc6",
            fileName: "3-D Tic-Tac-Toe (Europe).a26",
            entryName: "3-D Tic-Tac-Toe (Europe)",
            title: "3-D Tic-Tac-Toe",
            platformId: "ATARI_2600",
            region: "EU",
            isUnlicensed: false,
            gameId: 5
        )
    )

    init() async throws {
        print("Starting ShiraGame test initialization...")
        self.db = try await ShiraGame()
        print("ShiraGame initialization complete")
    }

    // MARK: - MD5 Search Tests
    @Test
    func searchByMD5() async throws {
        let result = try await db.searchROM(byMD5: sampleGames.genesis.md5)
        #expect(result != nil)
        #expect(result?.gameTitle == sampleGames.genesis.entryName)
        #expect(result?.region == sampleGames.genesis.region)
        #expect(result?.romHashMD5 == sampleGames.genesis.md5)
        #expect(result?.romHashCRC == sampleGames.genesis.crc)
        #expect(result?.systemID == .Atari2600)
    }

    // MARK: - Filename Search Tests
    @Test
    func searchByFilename() async throws {
        // Test exact match
        let exactResults = try await db.searchDatabase(usingFilename: sampleGames.ticTacToeUS.fileName, systemID: nil)
        #expect(exactResults?.count == 1)
        #expect(exactResults?.first?.gameTitle == sampleGames.ticTacToeUS.entryName)
        #expect(exactResults?.first?.systemID == .Atari2600)
    }

    @Test
    func searchByFilenameWithSystem() async throws {
        // Test 1: Using systemID filter during search
        let filteredResults = try await db.searchDatabase(
            usingFilename: "3-D Tic-Tac-Toe",
            systemID: SystemIdentifier.Atari2600
        )

        // Print debug info
        print("Test: Got \(filteredResults?.count ?? 0) filtered results")
        filteredResults?.forEach { result in
            print("Test: Result - \(result.gameTitle) for \(result.systemID)")
        }

        // Filter to just the main US/EU releases
        let mainReleases = filteredResults?.filter {
            $0.region == "US" || $0.region == "EU"
        }
        #expect(mainReleases?.count == 2)  // Should find both US and EU versions
        #expect(mainReleases?.allSatisfy { $0.systemID == .Atari2600 } == true)

        let filteredRegions = Set(mainReleases?.compactMap { $0.region } ?? [])
        #expect(filteredRegions.contains("US"))
        #expect(filteredRegions.contains("EU"))
    }

    @Test
    func searchBrainGames() async throws {
        // Test specifically for Atari 2600 Brain Games
        let brainResults = try await db.searchDatabase(usingFilename: "Brain Games (USA).a26", systemID: nil)
        #expect(brainResults?.count == 1)  // Should find just the US Atari version
        #expect(brainResults?.first?.systemID == .Atari2600)
        #expect(brainResults?.first?.region == "US")

        // Test for all Atari 2600 versions
        let allResults = try await db.searchDatabase(usingFilename: "Brain Games", systemID: nil)
        let atari2600Results = allResults?.filter { $0.systemID == .Atari2600 }
        #expect(atari2600Results?.count ?? 0 > 0)  // Should have at least one result
        #expect(atari2600Results?.allSatisfy { $0.systemID == .Atari2600 } == true)

        // Verify we have both main regions
        let mainRegions = Set(atari2600Results?.compactMap { $0.region }.filter { $0 == "US" || $0 == "EU" } ?? [])
        #expect(mainRegions.contains("US"))
        #expect(mainRegions.contains("EU"))
    }

    // MARK: - Region Tests
    @Test
    func regionDetection() async throws {
        let results = try await db.searchDatabase(usingFilename: "3-D Tic-Tac-Toe", systemID: nil)
        let regions = Set(results?.compactMap { $0.region } ?? [])
        #expect(regions.contains("US"))
        #expect(regions.contains("EU"))
    }

    @Test
    func searchByPlatform() async throws {
        // Test that platform filtering works correctly
        let results = try await db.searchDatabase(usingFilename: "3-D", systemID: nil)
        let atariGames = results?.filter { $0.systemID == .Atari2600 }
        #expect(atariGames?.count ?? 0 > 0)
        #expect(atariGames?.allSatisfy { $0.systemID == .Atari2600 } == true)
    }
}
