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
import Systems

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
}
