//
//  ShiraGameTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Testing
@testable import ShiraGame
@testable import PVLookupTypes

final class ShiraGameTests {
    let db: ShiraGame

    override func setUp() {
        db = try! ShiraGame()
    }

    func testSearchByMD5() async throws {
        let md5 = "SOME_KNOWN_MD5"  // Replace with actual MD5
        let result = try await db.searchROM(byMD5: md5)

        #expect(result != nil)
        #expect(result?.romHashMD5 == md5)
    }

    func testSearchByFilename() async throws {
        let results = try await db.searchDatabase(usingFilename: "Mario", systemID: nil)

        #expect(results != nil)
        #expect(!results!.isEmpty)
    }

    func testSystemIDMapping() async throws {
        // Test NES game
        let nesGame = try await db.searchDatabase(usingFilename: "Super Mario Bros", systemID: SystemIdentifier.NES.openVGDBID)?.first
        #expect(nesGame?.systemID == SystemIdentifier.NES.openVGDBID)

        // Test system lookup
        let systemID = try await db.system(forRomMD5: "SOME_MD5", or: "Super Mario Bros")
        #expect(systemID == SystemIdentifier.NES.openVGDBID)
    }

    func testBIOSDetection() async throws {
        // Test a known BIOS file
        let biosResult = try await db.searchDatabase(usingFilename: "bios", systemID: nil)?.first
        #expect(biosResult?.isBIOS == true)

        // Test a regular game
        let gameResult = try await db.searchDatabase(usingFilename: "Super Mario", systemID: nil)?.first
        #expect(gameResult?.isBIOS == false)
    }
}
