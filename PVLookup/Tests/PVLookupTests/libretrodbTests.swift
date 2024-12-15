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
        serial: "SHVC-AQ3J-JPN",
        md5: "534856432D4151334A2D4A504E",
        title: "Dragon Quest III - Soshite Densetsu e...",
        fullTitle: "Dragon Quest III - Soshite Densetsu e... (Japan)",
        openVGDBID: 37,  // SNES
        systemID: SystemIdentifier.SNES,
        manufacturer: "Nintendo",
        genre: "RPG",  // genre_id: 10
        year: 1996,
        month: 12,
        region: "Japan"
    )

    let dragonQuest6 = (
        id: 23205,
        serial: "SHVC-AQ6J-JPN",
        md5: "534856432D4151364A2D4A504E",
        title: "Dragon Quest VI - Maboroshi no Daichi",
        fullTitle: "Dragon Quest VI - Maboroshi no Daichi (Japan)",
        openVGDBID: 37,  // SNES
        systemID: SystemIdentifier.SNES,
        manufacturer: "Nintendo",
        genre: "RPG",  // genre_id: 10
        year: 1995,
        month: 12,
        region: "Japan"
    )

    let pMan = (
        id: 22411,
        serial: "534856432D4150554A2D4A504E",
        title: "P-Man",
        fullTitle: "P-Man (Japan)",
        openVGDBID: 37,  // SNES
        systemID: SystemIdentifier.SNES,
        manufacturer: "Nintendo",
        genre: "Action",  // genre_id: 7
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
        #expect(resultsLower?.first?.gameTitle == dragonQuest3.fullTitle)
    }

    @Test
    func searchByFilename() async throws {
        let filename = "Dragon Quest"
        let results = try await db.searchDatabase(usingFilename: filename, systemID: nil)

        #expect(results != nil)
        #expect(!results!.isEmpty)
        #expect(results?.count == 128)  // Should find both DQ3 and DQ6
        #expect(results?.contains { $0.gameTitle == dragonQuest3.fullTitle } == true)
        #expect(results?.contains { $0.gameTitle == dragonQuest6.fullTitle } == true)
    }

    @Test
    func searchByFilenameWithSystem() async throws {
        let results = try await db.searchDatabase(
            usingFilename: "Dragon Quest III",
            systemID: dragonQuest3.openVGDBID
        )

        #expect(results != nil)
        #expect(!results!.isEmpty)
        #expect(results?.first?.gameTitle == dragonQuest3.fullTitle)
        #expect(results?.first?.systemID == dragonQuest3.systemID)
    }

    @Test
    func systemIdentifier() async throws {
        let identifier = try await db.systemIdentifier(forRomMD5: dragonQuest3.md5, or: nil)
        #expect(identifier == dragonQuest3.systemID)
    }

    @Test
    func systemIdentifierByFilename() async throws {
        let identifier = try await db.systemIdentifier(forRomMD5: "invalid", or: dragonQuest3.title)
        #expect(identifier == dragonQuest3.systemID)
    }

    @Test
    func metadataFields() async throws {
        let metadata = try await db.searchROM(byMD5: dragonQuest3.md5)

        #expect(metadata != nil)
        #expect(metadata?.gameTitle == dragonQuest3.fullTitle)
        #expect(metadata?.systemID == dragonQuest3.systemID)
        #expect(metadata?.region == dragonQuest3.region)
        #expect(metadata?.genres == dragonQuest3.genre)
        #expect(metadata?.developer == dragonQuest3.manufacturer)
    }

    @Test
    func invalidMD5() async throws {
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: "invalid", systemID: nil)
        #expect(results?.isEmpty != false)
    }

    @Test
    func invalidSystemID() async throws {
        let results = try await db.searchDatabase(usingFilename: dragonQuest3.title, systemID: 999)
        #expect(results?.isEmpty != false)
    }

    @Test
    func searchSpecialCharacters() async throws {
        // Test hyphen in title
        let results = try await db.searchDatabase(usingFilename: "P-Man", systemID: pMan.openVGDBID)

        #expect(results != nil)
        #expect(results?.count == 1)
        let firstResult = results?.first
        #expect(firstResult != nil)
        #expect(firstResult?.gameTitle == "P-Man")  // Match exact title from database
        #expect(firstResult?.systemID == pMan.systemID)
        #expect(firstResult?.region == pMan.region)

        // Test partial match with hyphen
        let partialResults = try await db.searchDatabase(usingFilename: "P-", systemID: pMan.openVGDBID)
        #expect(partialResults?.contains { $0.gameTitle.contains("P-Man") } == true)
    }
}
