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

    // MARK: - MD5 Search Tests
    @Test
    func searchByMD5CaseInsensitive() async throws {
        let md5Lower = "3ca38a30f1ec411073fc369c9ee41e2e"
        let md5Upper = "3CA38A30F1EC411073FC369C9EE41E2E"

        let resultsLower = try db.searchDatabase(usingKey: "romHashMD5", value: md5Lower, systemID: nil)
        let resultsUpper = try db.searchDatabase(usingKey: "romHashMD5", value: md5Upper, systemID: nil)

        #expect(resultsLower?.count == resultsUpper?.count)
        #expect(resultsLower?.first?.gameTitle == resultsUpper?.first?.gameTitle)
        #expect(resultsLower?.first?.gameTitle == "Advanced Dungeons & Dragons - Pool of Radiance")
    }

    @Test
    func searchByFilename() async throws {
        let filename = "Pool of Radiance"
        let results = try await db.searchDatabase(usingFilename: filename, systemID: nil)

        #expect(results != nil)
        #expect(!results!.isEmpty)
        #expect(results?.first?.gameTitle.contains("Pool of Radiance") == true)
    }

    @Test
    func searchByFilenameWithSystem() async throws {
        let filename = "Turrican"
        let results = try await db.searchDatabase(usingFilename: filename, systemID: SystemIdentifier.PCE.openVGDBID)

        #expect(results != nil)
        #expect(!results!.isEmpty)
        #expect(results?.first?.gameTitle == "Turrican")
        #expect(results?.first?.systemID == SystemIdentifier.PCE.openVGDBID)
    }

    @Test
    func systemIdentifier() async throws {
        let md5 = "3CA38A30F1EC411073FC369C9EE41E2E"  // Pool of Radiance
        let identifier = try await db.systemIdentifier(forRomMD5: md5, or: nil)
        #expect(identifier == .NES)
    }

    @Test
    func systemIdentifierByFilename() async throws {
        let identifier = try await db.systemIdentifier(forRomMD5: "invalid", or: "Pool of Radiance")
        #expect(identifier == .NES)
    }

    @Test
    func metadataFields() async throws {
        let md5 = "3CA38A30F1EC411073FC369C9EE41E2E"  // Pool of Radiance
        let metadata = try await db.searchROM(byMD5: md5)

        #expect(metadata != nil)
        #expect(metadata?.gameTitle == "Advanced Dungeons & Dragons - Pool of Radiance")
        #expect(metadata?.romHashMD5 == md5)
        #expect(metadata?.systemID == SystemIdentifier.NES.openVGDBID)
    }

    @Test
    func invalidMD5() async throws {
        let results = try db.searchDatabase(usingKey: "romHashMD5", value: "invalid", systemID: nil)
        #expect(results?.isEmpty != false)
    }

    @Test
    func invalidSystemID() async throws {
        let results = try await db.searchDatabase(usingFilename: "Pool of Radiance", systemID: 999)
        #expect(results?.isEmpty != false)
    }
}
