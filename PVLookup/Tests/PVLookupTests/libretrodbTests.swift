//
//  libretrodbTests.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/14/24.
//

import Testing
import Foundation
@testable import PVLookup
@testable import libretrodb
@testable import ROMMetadataProvider
import Systems
import PVLookupTypes

// MARK: - Platform Constants
private extension LibretroDBTests {
    enum PlatformID {
        static let neogeoCD = 1
        static let pcEngine = 108  // PC Engine - TurboGrafx 16
        static let nes = 28        // Nintendo Entertainment System
        static let snes = 37       // Super Nintendo Entertainment System
        static let genesis = 15    // Mega Drive - Genesis
        static let gameboy = 75    // Game Boy
        static let gba = 115       // Game Boy Advance
    }
}

// MARK: - Region Constants
private extension LibretroDBTests {
    enum RegionID {
        static let japan = 1
        static let europe = 4
        static let usa = 5
        static let uk = 26
        static let asia = 10
        static let australia = 9
    }

    // Helper to get region name from ID
    static let regionNames: [Int: String] = [
        1: "Japan",
        4: "Europe",
        5: "USA",
        26: "United Kingdom",
        10: "Asia",
        9: "Australia"
    ]
}

struct LibretroDBTests {
    let db: libretrodb = .init()

    // MARK: - Test Data
    let dragonQuest3 = (
        id: 23207,
        md5: "7C7C7DB73B0608A184CC5E1D73D7695B",
        romName: "Dragon Quest III - Soshite Densetsu e... (Japan).sfc",
        displayName: "Dragon Quest III - Soshite Densetsu e...",
        fullName: "Dragon Quest III - Soshite Densetsu e... (Japan)",
        platformID: 37,
        systemID: SystemIdentifier.SNES,
        manufacturer: "Nintendo",
        developer: "Heart Beat",
        genre: "RPG",
        year: 1996,
        month: 12,
        region: "Japan"
    )

    let pMan = (
        id: 22411,
        md5: "146C7CD073165C271B6EB09E032F91E9",
        romName: "P-Man (Japan).sfc",
        displayName: "P-Man",
        fullName: "P-Man (Japan)",
        platformID: 37,
        systemID: SystemIdentifier.SNES,
        manufacturer: "Nintendo",
        developer: "Titus Software",
        genre: "Platform",
        year: 1996,
        month: 1,
        region: "Japan"
    )

    // MARK: - MD5 Search Tests
    @Test
    func searchByMD5CaseInsensitive() async throws {
        let md5Lower = dragonQuest3.md5.lowercased()
        let md5Upper = dragonQuest3.md5.uppercased()

        let resultsLower = try db.searchDatabase(usingKey: "romHashMD5", value: md5Lower, systemID: nil)
        let resultsUpper = try db.searchDatabase(usingKey: "romHashMD5", value: md5Upper, systemID: nil)

        #expect(resultsLower?.count == resultsUpper?.count)
        #expect(resultsLower?.first?.gameTitle == resultsUpper?.first?.gameTitle)
        #expect(resultsLower?.first?.gameTitle == dragonQuest3.displayName)
    }

    @Test
    func searchByFilename() async throws {
        let filename = "Dragon Quest III"
        let results = try await db.searchDatabase(usingFilename: filename, systemID: nil)

        #expect(results != nil)
        #expect(!results!.isEmpty)
        #expect(results?.contains { $0.gameTitle == dragonQuest3.displayName } == true)
        #expect(results?.contains { $0.systemID == dragonQuest3.systemID } == true)
    }

    @Test
    func searchByFilenameWithSystem() async throws {
        let results = try await db.searchDatabase(
            usingFilename: "Dragon Quest III",
            systemID: dragonQuest3.platformID
        )

        #expect(results != nil)
        #expect(!results!.isEmpty)
        #expect(results?.first?.gameTitle == dragonQuest3.displayName)
        #expect(results?.first?.systemID == dragonQuest3.systemID)
    }

    @Test
    func systemIdentifier() async throws {
        let identifier = try await db.systemIdentifier(forRomMD5: dragonQuest3.md5, or: nil)
        #expect(identifier == dragonQuest3.systemID)
    }

    @Test
    func systemIdentifierByFilename() async throws {
        let identifier = try await db.systemIdentifier(
            forRomMD5: "invalid",
            or: dragonQuest3.displayName,
            platformID: dragonQuest3.platformID
        )
        #expect(identifier == dragonQuest3.systemID)
    }

    @Test
    func metadataFields() async throws {
        let metadata = try await db.searchROM(byMD5: dragonQuest3.md5)

        #expect(metadata != nil)
        #expect(metadata?.gameTitle == dragonQuest3.displayName)
        #expect(metadata?.systemID == dragonQuest3.systemID)
        #expect(metadata?.region == dragonQuest3.region)
        #expect(metadata?.genres == dragonQuest3.genre)
        #expect(metadata?.developer == dragonQuest3.developer)
    }

    @Test
    func invalidMD5() async throws {
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: "invalid", systemID: nil)
        #expect(results?.isEmpty != false)
    }

    @Test
    func invalidSystemID() async throws {
        let results = try await db.searchDatabase(usingFilename: dragonQuest3.displayName, systemID: 999)
        #expect(results?.isEmpty != false)
    }

    @Test
    func searchSpecialCharacters() async throws {
        let results = try await db.searchDatabase(usingFilename: "P-Man", systemID: pMan.platformID)

        #expect(results != nil)
        #expect(results?.count == 1)
        let firstResult = results?.first
        #expect(firstResult != nil)
        #expect(firstResult?.gameTitle == pMan.displayName)
        #expect(firstResult?.systemID == pMan.systemID)
        #expect(firstResult?.region == pMan.region)

        // Test partial match with hyphen
        let partialResults = try await db.searchDatabase(usingFilename: "P-", systemID: pMan.platformID)
        #expect(partialResults?.contains { $0.gameTitle.contains("P-Man") } == true)
    }
}
