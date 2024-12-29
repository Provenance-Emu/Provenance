//
//  OpenVGDBTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Testing
@testable import PVLookupTypes
@testable import PVLookup
@testable import OpenVGDB
import PVSystems

struct OpenVGDBTests {
    let db: OpenVGDB

    init() async throws {
        self.db = try await OpenVGDB()
    }

    @Test("Database initialization works")
    func testDatabaseInitialization() async throws {
        let db = try await OpenVGDB()
        #expect(db != nil)
    }

    // MARK: - Test Data
    let nhlSaturn = (
        md5: "C43FA61C0D031D85B357BDDC055B24F7",
        crc: "5AD4DE86",
        filename: "NHL 97 (USA).cue",
        serial: "T-5016H",
        openVGDBID: 34,
        systemID: SystemIdentifier.Saturn,
        region: "USA",
        regionID: 21
    )

    let nhlPSX = (
        md5: "C02F86B655B981E04959AADEFC8103F6",
        crc: "E8293371",
        filename: "NHL 97 (USA).cue",
        serial: "SLUS-00030",
        openVGDBID: 38,
        systemID: SystemIdentifier.PSX,
        region: "USA",
        regionID: 21
    )

    // MARK: - MD5 Search Tests

    @Test
    func searchByMD5() async throws {
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: nhlSaturn.md5)

        #expect(results != nil)
        #expect(results?.count == 1)

        let metadata = results?.first
        #expect(metadata?.romHashMD5 == nhlSaturn.md5)
        #expect(metadata?.serial == nhlSaturn.serial)
        #expect(metadata?.systemID == nhlSaturn.systemID)
        #expect(metadata?.region == nhlSaturn.region)
        #expect(metadata?.regionID == nhlSaturn.regionID)
    }

    @Test
    func searchByMD5WithSystem() async throws {
        let results = try db.searchDatabase(
            usingKey: "romHashMD5",
            value: nhlSaturn.md5,
            systemID: nhlSaturn.systemID
        )
        #expect(results?.count == 1)
        #expect(results?.first?.systemID == nhlSaturn.systemID)
    }

    // MARK: - Filename Search Tests

    @Test
    func searchByFilename() async throws {
        let results = try db.searchDatabase(usingFilename: nhlSaturn.filename)

        #expect(results != nil)
        #expect(results!.count > 1)  // Should find both NHL 97 versions

        let saturnVersion = results?.first {
            $0.systemID == nhlSaturn.systemID  // SystemIdentifier is not optional
        }
        let psxVersion = results?.first {
            $0.systemID == nhlPSX.systemID  // SystemIdentifier is not optional
        }

        #expect(saturnVersion != nil)
        #expect(psxVersion != nil)
        #expect(saturnVersion?.serial == nhlSaturn.serial)
        #expect(psxVersion?.serial == nhlPSX.serial)
    }

    @Test
    func searchByFilenameWithSystem() async throws {
        let results = try await db.searchDatabase(
            usingFilename: nhlSaturn.filename,
            systemID: nhlSaturn.systemID  // Use openVGDBID for API call
        )
        #expect(results?.count == 1)
        #expect(results?.first?.systemID == nhlSaturn.systemID)  // Compare SystemIdentifier directly
    }

    // MARK: - System ID Tests

    @Test
    func systemLookupByMD5() async throws {
        let systemIdentifier = try db.system(forRomMD5: nhlSaturn.md5)
        #expect(systemIdentifier == nhlSaturn.systemID)
    }

    @Test
    func systemLookupByFilename() async throws {
        let systemIdentifier = try await db.systemIdentifier(forRomMD5: "invalid", or: nhlSaturn.filename)
        #expect(systemIdentifier == nhlSaturn.systemID)
    }

    // MARK: - Artwork URL Tests

    let artworkTestData = (
        // ROM with MD5 match (PSX game)
        md5Match: (
            md5: "877BA8B62470C85149A9BA32B012D069",
            crc: "7D7F6E2E",
            romID: 63271,
            systemID: SystemIdentifier.PSX,
            fileName: "...Iru! (Japan).cue",
            serial: "SLPS-00965",
            title: "...Iru!",
            region: "Japan",
            regionID: 13,
            expectedURLs: [
                "releaseCoverFront": "https://gamefaqs.gamespot.com/a/box/3/5/1/307351_front.jpg",
                "releaseCoverBack": "https://gamefaqs.gamespot.com/a/box/3/5/1/307351_back.jpg"
            ]
        ),

        // ROM with filename match (Saturn game)
        filenameMatch: (
            fileName: "2do Arukotoha Sand-R (Japan).cue",
            systemID: SystemIdentifier.Saturn,
            romID: 54588,
            serial: "T-6802G,T-6804G",
            title: "2do Arukotoha Sand-R",
            region: "Japan",
            regionID: 13,
            expectedURLs: [
                "releaseCoverFront": "https://gamefaqs.gamespot.com/a/box/6/3/8/308638_front.jpg",
                "releaseCoverBack": "https://gamefaqs.gamespot.com/a/box/6/3/8/308638_back.jpg"
            ]
        ),

        // ROM with serial match (GameCube game)
        serialMatch: (
            serial: "GW7D69",
            systemID: SystemIdentifier.GameCube,
            romID: 84282,
            fileName: "007 - Agent im Kreuzfeuer (Germany).iso",
            title: "007: Agent im Kreuzfeuer",
            region: "Germany",
            regionID: 10,
            expectedURLs: [
                "releaseCoverFront": "https://art.gametdb.com/wii/cover/DE/GW7D69.png"
            ]
        )
    )

    @Test
    func testArtworkURLsByMD5() throws {
        // Create ROM metadata with MD5
        let metadata = ROMMetadata(
            gameTitle: artworkTestData.md5Match.title,
            region: artworkTestData.md5Match.region,
            serial: artworkTestData.md5Match.serial,
            regionID: artworkTestData.md5Match.regionID,
            systemID: artworkTestData.md5Match.systemID,
            romFileName: artworkTestData.md5Match.fileName,
            romHashCRC: artworkTestData.md5Match.crc,
            romHashMD5: artworkTestData.md5Match.md5,
            romID: artworkTestData.md5Match.romID
        )

        let urls = try db.getArtworkURLs(forRom: metadata)

        #expect(urls != nil)
        #expect(urls?.count == artworkTestData.md5Match.expectedURLs.count)

        // Verify expected URLs are present
        for (_, expectedURL) in artworkTestData.md5Match.expectedURLs {
            #expect(urls?.contains(where: { $0.absoluteString == expectedURL }) == true)
        }
    }

    @Test
    func testArtworkURLsByFilename() throws {
        // Create ROM metadata with filename
        let metadata = ROMMetadata(
            gameTitle: "Super Mario World",
            systemID: artworkTestData.filenameMatch.systemID,
            romFileName: artworkTestData.filenameMatch.fileName
        )

        let urls = try db.getArtworkURLs(forRom: metadata)

        #expect(urls != nil)
        #expect(urls?.count == artworkTestData.filenameMatch.expectedURLs.count)

        // Verify expected URLs are present
        for (_, expectedURL) in artworkTestData.filenameMatch.expectedURLs {
            #expect(urls?.contains(where: { $0.absoluteString == expectedURL }) == true)
        }
    }

    @Test
    func testArtworkURLsBySerial() throws {
        // Create ROM metadata with serial
        let metadata = ROMMetadata(
            gameTitle: "Super Mario World",
            serial: artworkTestData.serialMatch.serial,
            systemID: artworkTestData.serialMatch.systemID
        )

        let urls = try db.getArtworkURLs(forRom: metadata)

        #expect(urls != nil)
        #expect(urls?.count == artworkTestData.serialMatch.expectedURLs.count)

        // Verify expected URLs are present
        for (_, expectedURL) in artworkTestData.serialMatch.expectedURLs {
            #expect(urls?.contains(where: { $0.absoluteString == expectedURL }) == true)
        }
    }

    @Test
    func testArtworkURLsWithUnknownSystem() throws {
        // Create ROM metadata with Unknown system
        let metadata = ROMMetadata(
            gameTitle: "Some Game",
            systemID: .Unknown,
            romFileName: artworkTestData.filenameMatch.fileName
        )

        let urls = try db.getArtworkURLs(forRom: metadata)

        // Should still find results since system filter is omitted
        #expect(urls != nil)
    }

    @Test
    func testArtworkURLsWithNoMatches() throws {
        // Create ROM metadata with non-existent data
        let metadata = ROMMetadata(
            gameTitle: "Non Existent Game",
            systemID: .SNES,
            romFileName: "nonexistent.sfc",
            romHashMD5: "0000000000000000000000000000000"
        )

        let urls = try db.getArtworkURLs(forRom: metadata)
        #expect(urls == nil)
    }

    @Test
    func testArtworkURLsByPartialFilename() throws {
        // Create ROM metadata with partial filename
        let metadata = ROMMetadata(
            gameTitle: artworkTestData.serialMatch.title,
            region: artworkTestData.serialMatch.region,
            systemID: artworkTestData.serialMatch.systemID,
            romFileName: "007"  // Just the partial filename
        )

        let urls = try db.getArtworkURLs(forRom: metadata)

        #expect(urls != nil)
        #expect((urls?.count ?? 0) >= artworkTestData.serialMatch.expectedURLs.count)

        // Verify expected URLs are present - should find the full game's artwork
        for (_, expectedURL) in artworkTestData.serialMatch.expectedURLs {
            #expect(urls?.contains(where: { $0.absoluteString == expectedURL }) == true)
        }

        // Also test with a different partial match
        let metadata2 = ROMMetadata(
            gameTitle: artworkTestData.filenameMatch.title,
            region: artworkTestData.filenameMatch.region,
            systemID: artworkTestData.filenameMatch.systemID,
            romFileName: "Arukotoha"  // Partial match from middle of filename
        )

        let urls2 = try db.getArtworkURLs(forRom: metadata2)

        #expect(urls2 != nil)
        #expect(urls2?.count == artworkTestData.filenameMatch.expectedURLs.count)

        // Should find the Saturn game's artwork
        for (_, expectedURL) in artworkTestData.filenameMatch.expectedURLs {
            #expect(urls2?.contains(where: { $0.absoluteString == expectedURL }) == true)
        }
    }
}
