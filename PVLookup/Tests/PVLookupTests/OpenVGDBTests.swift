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
    let db = OpenVGDB()

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
            systemID: nhlSaturn.openVGDBID
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
        let results = try db.searchDatabase(
            usingFilename: nhlSaturn.filename,
            systemID: nhlSaturn.openVGDBID  // Use openVGDBID for API call
        )
        #expect(results?.count == 1)
        #expect(results?.first?.systemID == nhlSaturn.systemID)  // Compare SystemIdentifier directly
    }

    // MARK: - System ID Tests

    @Test
    func systemLookupByMD5() async throws {
        let rawSystemID = try db.system(forRomMD5: nhlSaturn.md5)
        let systemIdentifier = SystemIdentifier.fromOpenVGDBID(rawSystemID ?? 0)
        #expect(systemIdentifier == nhlSaturn.systemID)
    }

    @Test
    func systemLookupByFilename() async throws {
        let rawSystemID = try db.system(forRomMD5: "invalid", or: nhlSaturn.filename)
        let systemIdentifier = SystemIdentifier.fromOpenVGDBID(rawSystemID ?? 0)
        #expect(systemIdentifier == nhlSaturn.systemID)
    }

    // MARK: - Artwork URL Tests

    let artworkTestData = (
        // ROM with MD5 match
        md5Match: (
            md5: "F73D2D0EFF548E8FC66996F27ACF2B4B",
            romID: 81222,
            systemID: SystemIdentifier.Atari2600,
            fileName: "Pitfall (1983) (CCE) (C-813).a26",
            expectedURLs: [
                "releaseCoverFront": "https://example.com/pitfall_front.jpg",
                "releaseCoverBack": "https://example.com/pitfall_back.jpg"
            ]
        ),

        // ROM with filename match
        filenameMatch: (
            fileName: "Super Mario World (USA).sfc",
            systemID: SystemIdentifier.SNES,
            expectedURLs: [
                "releaseCoverFront": "https://example.com/mario_front.jpg",
                "releaseCoverCart": "https://example.com/mario_cart.jpg"
            ]
        ),

        // ROM with serial match
        serialMatch: (
            serial: "SNSP-MW-USA",
            systemID: SystemIdentifier.SNES,
            expectedURLs: [
                "releaseCoverFront": "https://example.com/mario_serial_front.jpg"
            ]
        )
    )

    @Test
    func testArtworkURLsByMD5() throws {
        // Create ROM metadata with MD5
        let metadata = ROMMetadata(
            gameTitle: "Pitfall",
            systemID: artworkTestData.md5Match.systemID,
            romFileName: artworkTestData.md5Match.fileName,
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
}
