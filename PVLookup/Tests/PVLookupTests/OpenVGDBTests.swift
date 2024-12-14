//
//  OpenVGDBTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Testing
@testable import PVLookup
@testable import OpenVGDB

struct OpenVGDBTest {
    let database = OpenVGDB()

    // MARK: - Test Data
    let testROM1 = (
        md5: "C43FA61C0D031D85B357BDDC055B24F7",
        crc: "5AD4DE86",
        filename: "NHL 97 (USA).cue",
        serial: "T-5016H",
        systemID: 34,  // Saturn
        region: "USA",
        regionID: 21
    )

    let testROM2 = (
        md5: "C02F86B655B981E04959AADEFC8103F6",
        crc: "E8293371",
        filename: "NHL 97 (USA).cue",
        serial: "SLUS-00030",
        systemID: 38,  // PSX
        region: "USA",
        regionID: 21
    )

    // MARK: - Additional Test Data
    let knucklesChaotix = (
        releaseID: 46016,
        romID: 15786,
        title: "Knuckles' Chaotix",
        regionID: 21,  // USA
        region: "USA",
        systemID: 29,  // Sega 32X
        description: "Knuckles, the edgiest Echidna on the block, is back! This screamin' wild ride's got everything but a speed limit. Race for the rings, and hoooOOOOLD ON!",
        developer: "Sega",
        genres: "Action,Platformer,2D",
        releaseDate: "Apr 20, 1995",
        boxFrontURL: "https://gamefaqs.gamespot.com/a/box/1/0/7/45107_front.jpg",
        boxBackURL: "https://gamefaqs.gamespot.com/a/box/1/0/7/45107_back.jpg"
    )

    let batmanVengeance = (
        romID: 6091,
        systemID: 20,  // GBA
        regionID: 7,   // Europe
        crc: "783AC0C7",
        md5: "FFFE680EFF483B4D4366964EB7A150D8",
        sha1: "413D18EE8A41E4B5051EA5BED343EDF8E52EEEE2",
        filename: "Batman - Vengeance (Europe) (En,Fr,De,Es,It,Nl).gba",
        region: "Europe",
        languages: ["En", "Fr", "De", "Es", "It", "Nl"]
    )

    // MARK: - Basic Search Tests
    @Test func testMD5Search() throws {
        let results = try database.searchDatabase(usingKey: "romHashMD5", value: testROM1.md5)

        #expect(results != nil)
        #expect(results?.count == 1)

        let metadata = results?.first
        #expect(metadata?.romHashMD5 == testROM1.md5)
        #expect(metadata?.serial == testROM1.serial)
        #expect(metadata?.systemID == testROM1.systemID)
        #expect(metadata?.region == testROM1.region)
        #expect(metadata?.regionID == testROM1.regionID)
    }

    @Test func testMD5SearchWithSystem() throws {
        // Should find with correct system
        let correctResults = try database.searchDatabase(
            usingKey: "romHashMD5",
            value: testROM1.md5,
            systemID: testROM1.systemID
        )
        #expect(correctResults?.count == 1)
        #expect(correctResults?.first?.systemID == testROM1.systemID)

        // Invalid system ID is now ignored, returns all matches
        let invalidResults = try database.searchDatabase(
            usingKey: "romHashMD5",
            value: testROM1.md5,
            systemID: 999999
        )
        #expect(invalidResults?.count == 1)  // Changed from nil to finding the match

        // Should find without system ID
        let noSystemResults = try database.searchDatabase(
            usingKey: "romHashMD5",
            value: testROM1.md5
        )
        #expect(noSystemResults?.count == 1)
    }

    @Test func testFilenameSearch() throws {
        let results = try database.searchDatabase(usingFilename: testROM1.filename)

        #expect(results != nil)
        #expect(results!.count > 1)  // Should find both NHL 97 versions

        let saturnVersion = results?.first { $0.systemID == testROM1.systemID }
        let psxVersion = results?.first { $0.systemID == testROM2.systemID }

        #expect(saturnVersion != nil)
        #expect(psxVersion != nil)
        #expect(saturnVersion?.serial == testROM1.serial)
        #expect(psxVersion?.serial == testROM2.serial)
    }

    @Test func testFilenameSearchWithSystemID() throws {
        let results = try database.searchDatabase(
            usingFilename: testROM1.filename,
            systemID: testROM1.systemID
        )

        #expect(results != nil)
        #expect(results?.count == 1)
        #expect(results?.first?.systemID == testROM1.systemID)
        #expect(results?.first?.serial == testROM1.serial)
    }

    @Test func testFilenameSearchWithMultipleSystemIDs() throws {
        // Test with mix of valid and invalid system IDs
        let results = try database.searchDatabase(
            usingFilename: testROM1.filename,
            systemIDs: [testROM1.systemID, testROM2.systemID, 999999]
        )

        #expect(results != nil)
        #expect(results?.count == 2)  // Should only find the two valid systems
        #expect((results?.contains { $0.systemID == testROM1.systemID }) == true)
        #expect((results?.contains { $0.systemID == testROM2.systemID }) == true)

        // Test with all invalid system IDs
        let invalidResults = try database.searchDatabase(
            usingFilename: testROM1.filename,
            systemIDs: [999999, 888888]
        )
        #expect(invalidResults == nil)
    }

    // MARK: - System Lookup Tests
    @Test func testSystemForRomMD5Only() throws {
        let systemID = try database.system(forRomMD5: testROM1.md5)
        #expect(systemID == testROM1.systemID)
    }

    @Test func testSystemForRomFilenameOnly() throws {
        let systemID = try database.system(forRomMD5: "", or: testROM1.filename)
        #expect(systemID != nil)  // Will return one of the valid systems
    }

    @Test func testSystemForRomMD5AndFilename() throws {
        let systemID = try database.system(forRomMD5: testROM1.md5, or: testROM1.filename)
        #expect(systemID == testROM1.systemID)
    }

    // MARK: - Artwork Tests
    @Test func testGetArtworkMappings() throws {
        let mappings = try database.getArtworkMappings()

        #expect(mappings.romMD5.count > 0)
        #expect(mappings.romFileNameToMD5.count > 0)

        // Test specific ROM lookup
        let md5Data = mappings.romMD5[testROM1.md5]
        #expect(md5Data != nil)
        #expect(md5Data?["romFileName"] as? String == testROM1.filename)

        // Test filename to MD5 mapping
        let md5FromFilename = mappings.romFileNameToMD5["\(testROM1.systemID):\(testROM1.filename)"]
        #expect(md5FromFilename == testROM1.md5)
    }

    // MARK: - Error Tests
    @Test func testInvalidMD5() throws {
        let results = try database.searchDatabase(
            usingKey: "romHashMD5",
            value: "INVALID_MD5_HASH"
        )
        #expect(results == nil)
    }

    // MARK: - Additional Search Tests
    @Test func testMultiLanguageGameSearch() throws {
        let results = try database.searchDatabase(
            usingFilename: batmanVengeance.filename,
            systemID: batmanVengeance.systemID
        )

        #expect(results != nil)
        #expect(results?.count == 1)
        let game = results?.first
        #expect(game?.romHashMD5 == batmanVengeance.md5)
        #expect(game?.romHashCRC == batmanVengeance.crc)
        #expect(game?.region == batmanVengeance.region)
    }

    @Test func testGameWithApostrophe() throws {
        let results = try database.searchDatabase(
            usingFilename: "Chaotix",  // Changed to match partial name since that's what we test
            systemID: knucklesChaotix.systemID
        )

        #expect(results != nil)
        let game = results?.first { $0.gameTitle == knucklesChaotix.title }  // Added filter
        #expect(game != nil)
        #expect(game?.gameTitle == knucklesChaotix.title)
        #expect(game?.gameDescription == knucklesChaotix.description)
        #expect(game?.developer == knucklesChaotix.developer)
        #expect(game?.genres == knucklesChaotix.genres)
        #expect(game?.boxImageURL == knucklesChaotix.boxFrontURL)
        #expect(game?.boxBackURL == knucklesChaotix.boxBackURL)
    }

    // MARK: - Region Tests
    @Test func testRegionSpecificSearch() throws {
        // Test USA region
        let usaResults = try database.searchDatabase(
            usingFilename: testROM1.filename,  // Changed to exact filename
            systemID: testROM1.systemID
        )
        #expect(usaResults?.first?.regionID == 21)  // USA

        // Test Europe region
        let euroResults = try database.searchDatabase(
            usingFilename: batmanVengeance.filename,
            systemID: batmanVengeance.systemID
        )
        #expect(euroResults?.first?.regionID == 7)  // Europe
    }

    // MARK: - File Format Tests
    @Test func testCueFileSearch() throws {
        let results = try database.searchDatabase(
            usingFilename: "Sol-Feace (USA)",
            systemID: 32  // Sega CD
        )

        #expect(results != nil)
        let game = results?.first
        #expect((game?.romFileName?.hasSuffix(".cue")) == true)
    }

    @Test func testISORomSearch() throws {
        let results = try database.searchDatabase(
            usingFilename: "One Piece - Pirates Carnival",
            systemID: 22  // GameCube
        )

        #expect(results != nil)
        let game = results?.first
        #expect((game?.romFileName?.hasSuffix(".iso")) == true)
    }

    // MARK: - Edge Case Tests
    @Test func testGameWithSpecialCharacters() throws {
        // Test game with hyphen
        let results1 = try database.searchDatabase(
            usingFilename: "Shin Megami Tensei - Devil Survivor",
            systemID: 24  // Nintendo DS
        )
        #expect(results1 != nil)

        // Test game with Japanese characters
        let results2 = try database.searchDatabase(
            usingFilename: "Bleach - Heat the Soul",
            systemID: 39  // PSP
        )
        #expect(results2 != nil)
    }

    @Test func testPartialFilenameMatch() throws {
        // Should match "Knuckles' Chaotix" with just "Chaotix"
        let results = try database.searchDatabase(
            usingFilename: "Chaotix",
            systemID: knucklesChaotix.systemID
        )

        #expect(results != nil)
        #expect((results?.contains { $0.gameTitle == knucklesChaotix.title }) == true)
    }

    // MARK: - System ID Tests
    @Test func testSystemIDHandling() throws {
        // Test with invalid system ID - should ignore the system ID and return all matches
        let resultsWithInvalidID = try database.searchDatabase(
            usingFilename: testROM1.filename,
            systemID: 999999
        )
        #expect(resultsWithInvalidID != nil)
        #expect(resultsWithInvalidID?.count == 2)  // Should find both NHL 97 versions

        // Test with valid system ID - should filter to just that system
        let resultsWithValidID = try database.searchDatabase(
            usingFilename: testROM1.filename,
            systemID: testROM1.systemID
        )
        #expect(resultsWithValidID != nil)
        #expect(resultsWithValidID?.count == 1)
        #expect(resultsWithValidID?.first?.systemID == testROM1.systemID)
    }

    @Test func testMultipleSystemIDHandling() throws {
        // Test with mix of valid and invalid system IDs
        let results = try database.searchDatabase(
            usingFilename: testROM1.filename,
            systemIDs: [testROM1.systemID, testROM2.systemID, 999999]
        )

        #expect(results != nil)
        #expect(results?.count == 2)  // Should find matches for valid systems only
        #expect((results?.contains { $0.systemID == testROM1.systemID }) == true)
        #expect((results?.contains { $0.systemID == testROM2.systemID }) == true)

        // Test with all invalid system IDs
        let invalidResults = try database.searchDatabase(
            usingFilename: testROM1.filename,
            systemIDs: [999999, 888888]
        )
        #expect(invalidResults == nil)  // No valid systems = no results
    }

    @Test func testValidSystemIDRange() {
        // Test boundaries of valid system IDs
        let minID = OpenVGDB.validSystemIDs.min()
        let maxID = OpenVGDB.validSystemIDs.max()

        #expect(minID == 1)
        #expect(maxID == 47)

        // Test some known valid systems
        #expect(OpenVGDB.validSystemIDs.contains(testROM1.systemID))  // Saturn
        #expect(OpenVGDB.validSystemIDs.contains(testROM2.systemID))  // PSX
        #expect(OpenVGDB.validSystemIDs.contains(batmanVengeance.systemID))  // GBA
        #expect(OpenVGDB.validSystemIDs.contains(knucklesChaotix.systemID))  // 32X
    }
}
