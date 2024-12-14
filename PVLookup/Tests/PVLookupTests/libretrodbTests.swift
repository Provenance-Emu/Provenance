//
//  libretrodbTests.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/14/24.
//

import Testing
@testable import PVLookup
@testable import libretrodb
import ROMMetadataProvider

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

final class LibretroDBTests {
    let db = libretrodb()

    // MARK: - MD5 Search Tests
    func testSearchByMD5_PoolOfRadiance() async throws {
        let md5 = "3CA38A30F1EC411073FC369C9EE41E2E"  // Pool of Radiance
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)

        #expect(results != nil)
        #expect(results?.count == 1)

        let metadata = results?.first
        #expect(metadata?.gameTitle == "Advanced Dungeons & Dragons - Pool of Radiance")
        #expect(metadata?.romHashMD5 == md5)
        #expect(metadata?.region == "Japan")
        #expect(metadata?.systemID == PlatformID.nes)
    }

    func testSearchByMD5_Turrican() async throws {
        let md5 = "52D40C4E0A8435308C22C69A54E4BAAE"  // Turrican
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)

        #expect(results != nil)
        #expect(results?.count == 1)

        let metadata = results?.first
        #expect(metadata?.gameTitle == "Turrican")
        #expect(metadata?.romHashMD5 == md5)
        #expect(metadata?.region == "USA")
        #expect(metadata?.systemShortName?.contains("PCE") == true)
    }

    func testSearchByMD5_BardsTale() async throws {
        let md5 = "987F635B6DE871BBE335CCAD06186DAF"  // Bard's Tale II
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)

        #expect(results != nil)
        #expect(results?.count == 1)

        let metadata = results?.first
        #expect(metadata?.gameTitle == "The Bard's Tale II - The Destiny Knight")
        #expect(metadata?.romHashMD5 == md5)
        #expect(metadata?.region == "Japan")
        #expect(metadata?.systemShortName?.contains("NES") == true)
    }

    func testSearchByMD5CaseInsensitive() async throws {
        let md5Lower = "3ca38a30f1ec411073fc369c9ee41e2e"
        let md5Upper = "3CA38A30F1EC411073FC369C9EE41E2E"

        let resultsLower = try db.searchDatabase(usingKey: "romHashMD5", value: md5Lower, systemID: nil)
        let resultsUpper = try db.searchDatabase(usingKey: "romHashMD5", value: md5Upper, systemID: nil)

        #expect(resultsLower?.count == resultsUpper?.count)
        #expect(resultsLower?.first?.gameTitle == resultsUpper?.first?.gameTitle)
        #expect(resultsLower?.first?.gameTitle == "Advanced Dungeons & Dragons - Pool of Radiance")
    }

    // MARK: - Filename Search Tests
    func testSearchByFilename() async throws {
        let filename = "Pool of Radiance"
        let results = try db.searchDatabase(usingFilename: filename, systemID: nil)

        #expect(results != nil)
        #expect(results?.count ?? 0 > 0)
        #expect(results?.first?.gameTitle.contains("Pool of Radiance") == true)
    }

    func testSearchByFilenameWithSystem() async throws {
        let filename = "Turrican"
        let systemID = PlatformID.pcEngine  // PC Engine
        let results = try db.searchDatabase(usingFilename: filename, systemID: systemID)

        #expect(results != nil)
        #expect(results?.count ?? 0 > 0)
        #expect(results?.first?.systemID == systemID)
        #expect(results?.first?.gameTitle == "Turrican")
    }

    // MARK: - System ID Tests
    func testGetSystemID_NES() async throws {
        let md5 = "3CA38A30F1EC411073FC369C9EE41E2E"  // Pool of Radiance (NES)
        let systemID = try db.system(forRomMD5: md5, or: nil)

        #expect(systemID != nil)
        #expect(systemID == 3)  // NES system ID
    }

    func testGetSystemID_PCE() async throws {
        let md5 = "52D40C4E0A8435308C22C69A54E4BAAE"  // Turrican (PCE)
        let systemID = try db.system(forRomMD5: md5, or: nil)

        #expect(systemID != nil)
        #expect(systemID == 1)  // PCE system ID
    }

    // MARK: - Metadata Conversion Tests
    func testMetadataConversion_CompleteFields() async throws {
        let md5 = "3CA38A30F1EC411073FC369C9EE41E2E"  // Pool of Radiance
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)
        let metadata = results?.first

        #expect(metadata != nil)
        // Test required fields
        #expect(metadata!.gameTitle == "Advanced Dungeons & Dragons - Pool of Radiance")
        #expect(metadata!.systemID == 3)  // NES
        #expect(metadata!.region == "Japan")

        // Test optional fields
        #expect(metadata!.romHashMD5 == md5)
        #expect(metadata!.romFileName?.contains("Pool of Radiance") == true)

        // Test fields that should be nil
        #expect(metadata!.boxImageURL == nil)
        #expect(metadata!.boxBackURL == nil)
        #expect(metadata!.romHashCRC == nil)
    }

    // MARK: - Error Cases
    func testInvalidMD5() async throws {
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: "invalid", systemID: nil)
        #expect(results == nil || results?.isEmpty == true)
    }

    func testInvalidSystemID() async throws {
        let results = try db.searchDatabase(usingFilename: "World Heroes Perfect", systemID: 999)
        #expect(results == nil || results?.isEmpty == true)
    }

    func testUnsupportedSearchKey() async throws {
        let results = try db.searchDatabase(usingKey: "unsupported", value: "test", systemID: nil)
        #expect(results == nil)
    }

    // MARK: - Platform-Specific Tests
    func testSearchAcrossPlatforms() async throws {
        let filename = "Turrican"  // Game released on multiple platforms
        let systemIDs = [PlatformID.pcEngine, PlatformID.nes, PlatformID.genesis]
        let results = try db.searchDatabase(usingFilename: filename, systemIDs: systemIDs)

        #expect(results != nil)
        #expect(results?.count ?? 0 > 1)  // Should find multiple versions

        // Verify we got results from different platforms
        let platforms = Set(results?.compactMap { $0.systemID } ?? [])
        #expect(platforms.count > 1)
    }

    func testPlatformSpecificSearch() async throws {
        // Test NES games
        let nesResults = try db.searchDatabase(usingFilename: "Mario", systemID: PlatformID.nes)
        #expect(nesResults?.allSatisfy { $0.systemID == PlatformID.nes } == true)

        // Test SNES games
        let snesResults = try db.searchDatabase(usingFilename: "Mario", systemID: PlatformID.snes)
        #expect(snesResults?.allSatisfy { $0.systemID == PlatformID.snes } == true)

        // Verify different results by comparing system IDs
        let nesSystemIDs = Set(nesResults?.map { $0.systemID } ?? [])
        let snesSystemIDs = Set(snesResults?.map { $0.systemID } ?? [])
        #expect(nesSystemIDs != snesSystemIDs)

        // Also verify titles are different
        let nesTitles = Set(nesResults?.map { $0.gameTitle } ?? [])
        let snesTitles = Set(snesResults?.map { $0.gameTitle } ?? [])
        #expect(nesTitles != snesTitles)
    }

    func testPlatformMapping() async throws {
        let md5 = "3CA38A30F1EC411073FC369C9EE41E2E"  // Pool of Radiance (NES)
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)
        let metadata = results?.first

        #expect(metadata != nil)
        #expect(metadata?.systemID == PlatformID.nes)
        #expect(metadata?.systemShortName == "Nintendo Entertainment System")
    }

    func testSystemIDLookup() async throws {
        // Test multiple platform IDs
        let platformTests = [
            (PlatformID.nes, "Nintendo Entertainment System"),
            (PlatformID.snes, "Super Nintendo Entertainment System"),
            (PlatformID.genesis, "Mega Drive - Genesis"),
            (PlatformID.pcEngine, "PC Engine - TurboGrafx 16"),
            (PlatformID.gameboy, "Game Boy"),
            (PlatformID.gba, "Game Boy Advance")
        ]

        for (platformID, expectedName) in platformTests {
            let results = try db.searchDatabase(usingFilename: "", systemID: platformID)
            let metadata = results?.first
            #expect(metadata?.systemID == platformID)
            #expect(metadata?.systemShortName == expectedName)
        }
    }

    // MARK: - Region-Specific Tests
    func testRegionSpecificSearch() async throws {
        // Test Japanese version
        let japaneseResults = try db.searchDatabase(usingFilename: "Final Fantasy", systemID: PlatformID.nes)
        let japaneseGames = japaneseResults?.filter { $0.regionID == RegionID.japan }
        #expect(japaneseGames?.isEmpty == false)

        // Test USA version
        let usaResults = try db.searchDatabase(usingFilename: "Final Fantasy", systemID: PlatformID.nes)
        let usaGames = usaResults?.filter { $0.regionID == RegionID.usa }
        #expect(usaGames?.isEmpty == false)

        // Verify different results
        #expect(japaneseGames != usaGames)
    }

    func testMultiRegionGame() async throws {
        let filename = "Super Mario"
        let results = try db.searchDatabase(usingFilename: filename, systemID: PlatformID.nes)

        // Should find versions from multiple regions
        let regions = Set(results?.compactMap { $0.regionID } ?? [])
        #expect(regions.count > 1)

        // Verify region names are correct
        for result in results ?? [] {
            if let regionID = result.regionID {
                let expectedName = LibretroDBTests.regionNames[regionID]
                #expect(result.region == expectedName)
            }
        }
    }

    func testRegionPriority() async throws {
        // Test that USA versions are prioritized when multiple regions exist
        let results = try db.searchDatabase(usingFilename: "Mario", systemID: PlatformID.nes)

        if let firstResult = results?.first {
            // First result should be USA version if available
            #expect(firstResult.regionID == RegionID.usa || firstResult.region == "USA")
        }
    }

    func testRegionSpecificMetadata() async throws {
        // Test Japanese game metadata
        let japaneseResults = try db.searchDatabase(usingFilename: "Dragon Quest", systemID: PlatformID.nes)
        let japaneseGame = japaneseResults?.first { $0.regionID == RegionID.japan }
        #expect(japaneseGame?.region == "Japan")

        // Test USA game metadata
        let usaResults = try db.searchDatabase(usingFilename: "Dragon Warrior", systemID: PlatformID.nes)
        let usaGame = usaResults?.first { $0.regionID == RegionID.usa }
        #expect(usaGame?.region == "USA")

        // Verify they're the same game with different regional titles
        #expect(japaneseGame?.systemID == usaGame?.systemID)
        #expect(japaneseGame?.developer == usaGame?.developer)
    }

    func testRegionIDMapping() async throws {
        // Test mapping for each major region
        let regionTests = [
            (RegionID.japan, "Japan"),
            (RegionID.usa, "USA"),
            (RegionID.europe, "Europe"),
            (RegionID.uk, "United Kingdom"),
            (RegionID.australia, "Australia"),
            (RegionID.asia, "Asia")
        ]

        for (regionID, expectedName) in regionTests {
            let results = try db.searchDatabase(usingFilename: "Mario", systemID: PlatformID.nes)
            let regionGame = results?.first { $0.regionID == regionID }
            if let game = regionGame {
                #expect(game.region == expectedName)
            }
        }
    }

    // MARK: - Artwork Tests
    func testArtworkURLConstruction() async throws {
        let md5 = "3CA38A30F1EC411073FC369C9EE41E2E"  // Pool of Radiance
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)
        let metadata = results?.first

        #expect(metadata?.boxImageURL != nil)
        #expect(metadata?.boxImageURL?.contains("thumbnails.libretro.com") == true)
        #expect(metadata?.boxImageURL?.contains("Named_Boxarts") == true)
        #expect(metadata?.boxImageURL?.hasSuffix(".png") == true)
    }

    func testAdvanceWarsArtworkURL() async throws {
        let results = try db.searchDatabase(usingFilename: "Advance Wars", systemID: PlatformID.gba)
        let metadata = results?.first

        let expectedURL = "http://thumbnails.libretro.com/Nintendo%20-%20Game%20Boy%20Advance/Named_Boxarts/Advance%20Wars%20%28USA%29.png"
        #expect(metadata?.boxImageURL == expectedURL)
    }
}
