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
    func searchPitfallByFilename() async throws {
        // Test with ShiraGame filename
        let shiraResults = try await lookup.searchDatabase(usingFilename: pitfall.shiraGame.fileName, systemID: nil)
        let shiraVersion = shiraResults?.first { $0.romHashMD5 == pitfall.shiraGame.md5 }
        #expect(shiraVersion != nil)
        #expect(shiraVersion?.systemID == .Atari2600)

        // Test with OpenVGDB filename
        let vgdbResults = try await lookup.searchDatabase(usingFilename: pitfall.openVGDB.fileName, systemID: nil)
        let vgdbVersion = vgdbResults?.first { $0.romHashMD5?.uppercased() == pitfall.shiraGame.md5.uppercased() }
        #expect(vgdbVersion != nil)
        #expect(vgdbVersion?.systemID == .Atari2600)
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
}
