//
//  OpenVGDBTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/15/24.
//

import Testing
@testable import PVLookupTypes
@testable import PVLookup
@testable import OpenVGDB
@testable import ShiraGame
@testable import libretrodb
import PVSystems

struct PVLookupTests {
    let lookup: PVLookup
    let openVGDB: OpenVGDB
    let libreTroDB: libretrodb

    // Test data for Pitfall with metadata from all databases
    let pitfall = (
        // ShiraGame data
        shiraGame: (
            md5: "f73d2d0eff548e8fc66996f27acf2b4b",
            crc: "03cf3b2f",
            fileName: "Pitfall! (CCE) (PAL-M) [!].a26",
            gameId: 7807,
            platformId: "ATARI_2600",
            entryName: "Pitfall! (CCE) (PAL-M) [!]",
            title: "Pitfall!",
            releaseTitle: "Pitfall!",
            region: "ZZ",
            systemID: SystemIdentifier.Atari2600
        ),
        // OpenVGDB data
        openVGDB: (
            romID: 81222,
            systemID: 3,
            regionID: 21,
            fileName: "Pitfall (1983) (CCE) (C-813).a26",
            title: "Pitfall",
            region: "USA",
            systemName: "Atari 2600",
            systemShortName: "2600"
        )
    )

    init() async throws {
        self.lookup = .shared
        self.openVGDB = OpenVGDB()
        self.libreTroDB = libretrodb()
    }

    @Test
    func searchPitfallByMD5() async throws {
        let result = try await lookup.searchROM(byMD5: pitfall.shiraGame.md5)

        #expect(result != nil)

        // Verify base data (case-insensitive)
        #expect(result?.romHashMD5?.uppercased() == pitfall.shiraGame.md5.uppercased())
        #expect(result?.romHashCRC?.uppercased() == pitfall.shiraGame.crc.uppercased())
        #expect(result?.systemID == pitfall.shiraGame.systemID)

        // Verify merged data (OpenVGDB takes priority)
        #expect(result?.gameTitle == pitfall.openVGDB.title)  // Title from OpenVGDB
        #expect(result?.region == pitfall.openVGDB.region)  // Region from OpenVGDB
        #expect(result?.regionID == pitfall.openVGDB.regionID)  // RegionID from OpenVGDB
        #expect(result?.systemID == .Atari2600)  // System ID should be consistent
    }

    @Test
    func searchPitfallByFilenameInOpenVGDB() async throws {
        // Test OpenVGDB directly
        let openVGDBResults = try openVGDB.searchDatabase(
            usingFilename: pitfall.openVGDB.fileName,
            systemID: pitfall.openVGDB.systemID
        )

        #expect(openVGDBResults != nil)
        let vgdbVersion = openVGDBResults?.first {
            $0.romHashMD5?.uppercased() == pitfall.shiraGame.md5.uppercased()
        }
        #expect(vgdbVersion != nil)
        #expect(vgdbVersion?.systemID == .Atari2600)
        #expect(vgdbVersion?.gameTitle == pitfall.openVGDB.title)
        #expect(vgdbVersion?.region == pitfall.openVGDB.region)
    }

    @Test
    func searchPitfallByFilenameInLibretroDB() async throws {
        // Test LibretroDB directly
        let libretroDB = libretrodb()
        let results = try libretroDB.searchMetadata(
            usingFilename: "Pitfall - The Mayan Adventure",
            systemID: SystemIdentifier.SNES.libretroDatabaseID  // 37 for SNES
        )

        #expect(results != nil)
        let snesVersion = results?.first { result in
            result.romHashMD5?.uppercased() == "02CAE4C360567CD228E4DC951BE6CB85"  // USA SNES version
        }
        #expect(snesVersion != nil)
        #expect(snesVersion?.systemID == .SNES)
        #expect(snesVersion?.gameTitle == "Pitfall - The Mayan Adventure")
    }

    @Test
    func searchPitfallByFilenameInShiraGame() async throws {
        // Test ShiraGame directly
        let shiraGame = try await ShiraGame()
        let results = try await shiraGame.searchDatabase(
            usingFilename: pitfall.shiraGame.fileName,
            systemID: nil
        )

        #expect(results != nil)
        let shiraVersion = results?.first {
            $0.romHashMD5 == pitfall.shiraGame.md5
        }
        #expect(shiraVersion != nil)
        #expect(shiraVersion?.systemID == .Atari2600)
        #expect(shiraVersion?.gameTitle == pitfall.shiraGame.entryName)
    }

    @Test
    func searchPitfallByFilenameInPVLookup() async throws {
        // Test combined results through PVLookup
        let results = try await lookup.searchDatabase(
            usingFilename: "Pitfall",
            systemID: SystemIdentifier.Atari2600.openVGDBID
        )

        #expect(results != nil)
        #expect(results?.allSatisfy { $0.systemID == .Atari2600 } == true)

        // Find our specific version
        let version = results?.first {
            $0.romHashMD5?.uppercased() == pitfall.shiraGame.md5.uppercased()
        }
        #expect(version != nil)

        // Verify merged metadata
        if let metadata = version {
            #expect(metadata.systemID == .Atari2600)
            #expect(metadata.romHashCRC?.uppercased() == pitfall.shiraGame.crc.uppercased())
            // OpenVGDB data should take priority in merged results
            #expect(metadata.region == pitfall.openVGDB.region)
            #expect(metadata.regionID == pitfall.openVGDB.regionID)
        }
    }

    @Test
    func searchPitfallWithSystem() async throws {
        let results = try await lookup.searchDatabase(
            usingFilename: "Pitfall",
            systemID: SystemIdentifier.Atari2600.openVGDBID
        )

        #expect(results != nil)
        #expect(results?.allSatisfy { $0.systemID == .Atari2600 } == true)

        // Find our specific version in results
        let cceVersion = results?.first {
            $0.romHashMD5?.uppercased() == pitfall.shiraGame.md5.uppercased()
        }
        #expect(cceVersion != nil)

        // Verify merged metadata
        if let metadata = cceVersion {
            #expect(metadata.systemID == .Atari2600)
            #expect(metadata.romHashCRC?.uppercased() == pitfall.shiraGame.crc.uppercased())
            #expect(metadata.region == pitfall.openVGDB.region)
        }
    }

    @Test
    func searchPitfallByMD5InEachDatabase() async throws {
        // Test OpenVGDB
        let openVGDBResult = try await lookup.searchDatabase(
            usingKey: "romHashMD5",
            value: pitfall.shiraGame.md5,
            systemID: nil
        )?.first
        print("Test: OpenVGDB result: \(String(describing: openVGDBResult))")

        // Test ShiraGame directly
        let shiraGame = try await ShiraGame()
        let shiraGameResult = try await shiraGame.searchROM(byMD5: pitfall.shiraGame.md5)
        print("Test: ShiraGame result: \(String(describing: shiraGameResult))")

        // Test LibretroDB directly
        let libretroDB = libretrodb()
        let libretroDatabaseResult = try libretroDB.searchDatabase(
            usingKey: "romHashMD5",
            value: pitfall.shiraGame.md5,
            systemID: nil
        )?.first
        print("Test: LibretroDB result: \(String(describing: libretroDatabaseResult))")

        // At least one database should find it
        #expect(openVGDBResult != nil || shiraGameResult != nil || libretroDatabaseResult != nil)
    }

    @Test
    func testGetArtworkURLs() async throws {
        // Create test ROM metadata
        let rom = ROMMetadata(
            gameTitle: "Sonic CD",
            systemID: .SegaCD,
            romFileName: "Sonic CD (USA).cue",
            romHashMD5: "c7658288"  // Example MD5
        )

        let urls = try await lookup.getArtworkURLs(forRom: rom)

        #expect(urls != nil)
        #expect(!urls!.isEmpty)

        // Verify we got URLs from both databases
        let openVGDBUrls = urls?.filter { $0.absoluteString.contains("gamefaqs.gamespot.com") }
        let libretroDatabaseUrls = urls?.filter { $0.absoluteString.contains("thumbnails.libretro.com") }

        // We should have at least one URL from either database
        #expect(openVGDBUrls?.isEmpty == false || libretroDatabaseUrls?.isEmpty == false)

        // If we have libretro URLs, verify the system name is correct
        if let libretroDatabaseUrl = libretroDatabaseUrls?.first {
            #expect(libretroDatabaseUrl.absoluteString.contains("Sega%20-%20Mega-CD%20-%20Sega%20CD"))
        }
    }

    @Test
    func testGetArtworkURLsWithUnknownSystem() async throws {
        // Test with Unknown system
        let rom = ROMMetadata(
            gameTitle: "Unknown Game",
            systemID: .Unknown,
            romFileName: "game.bin"
        )

        let urls = try await lookup.getArtworkURLs(forRom: rom)
        #expect(urls == nil)  // Should return nil for Unknown system
    }

    @Test
    func testGetArtworkURLsWithMultipleMatches() async throws {
        // Create test ROM metadata for a game we know has artwork
        let rom = ROMMetadata(
            gameTitle: "Pitfall - The Mayan Adventure",
            systemID: .SNES,
            romFileName: "Pitfall - The Mayan Adventure (USA).sfc",
            romHashMD5: "02CAE4C360567CD228E4DC951BE6CB85"  // USA SNES version from our query
        )

        let urls = try await lookup.getArtworkURLs(forRom: rom) ?? []

        #expect(!urls.isEmpty)

        // Verify we got URLs from both databases
        let openVGDBUrls = urls.filter { $0.absoluteString.contains("gamefaqs.gamespot.com") }
        let libretroDatabaseUrls = urls.filter { $0.absoluteString.contains("thumbnails.libretro.com") }

        // Log URLs for debugging
        print("OpenVGDB URLs: \(openVGDBUrls)")
        print("LibretroDB URLs: \(libretroDatabaseUrls)")

        // We should have at least one URL from either database
        #expect(openVGDBUrls.count > 0 || libretroDatabaseUrls.count > 0)

        // Verify URLs are deduplicated
        let uniqueUrls = Set(urls.map { $0.absoluteString })
        #expect(uniqueUrls.count == urls.count)  // No duplicates
    }

    @Test
    func testGetArtworkURLsWithNoMatches() async throws {
        // Test with valid system but non-existent game
        let rom = ROMMetadata(
            gameTitle: "Non Existent Game",
            systemID: .SNES,
            romFileName: "fake.sfc",
            romHashMD5: "0000000000000000000000000000000"
        )

        let urls = try await lookup.getArtworkURLs(forRom: rom)
        #expect(urls == nil)  // Should return nil for no matches
    }
}
