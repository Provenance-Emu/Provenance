//
//  ShiraGameTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Testing
import Systems
@testable import ShiraGame
@testable import PVLookupTypes
#if false
struct ShiraGameTests {
    let db: ShiraGame = .init()

    // MARK: - MD5 Search Tests
    @Test
    func searchByMD5() async throws {
        // Test German Boxing
        let germanBoxingMD5 = "7f07cd2e89dda5a3a90d3ab064bfd1f6"
        let germanResult = try await db.searchROM(byMD5: germanBoxingMD5)
        #expect(germanResult != nil)
        #expect(germanResult?.gameTitle == "Boxen (Germany) (En)")
        #expect(germanResult?.region == "DE")
        #expect(germanResult?.romHashMD5 == germanBoxingMD5)
        #expect(germanResult?.romHashCRC == "7931c845")
        #expect(germanResult?.systemID == .Atari2600)

        // Test US Boxing
        let usBoxingMD5 = "c3ef5c4653212088eda54dc91d787870"
        let usResult = try await db.searchROM(byMD5: usBoxingMD5)
        #expect(usResult?.gameTitle == "Boxing (USA)")
        #expect(usResult?.region == "US")
        #expect(usResult?.systemID == .Atari2600)

        // Test unlicensed Brazilian version
        let brBoxingMD5 = "a8b3ea6836b99bea77c8f603cf1ea187"
        let brResult = try await db.searchROM(byMD5: brBoxingMD5)
        #expect(brResult?.gameTitle == "Boxing (Brazil) (En) (Unl)")
        #expect(brResult?.region == "BR")
        #expect(brResult?.systemID == .Atari2600)
    }

    // MARK: - Filename Search Tests
    @Test
    func searchByFilename() async throws {
        // Test exact match
        let exactResults = try await db.searchDatabase(usingFilename: "Boxing (USA).a26", systemID: nil)
        #expect(exactResults?.count == 1)
        #expect(exactResults?.first?.gameTitle == "Boxing (USA)")
        #expect(exactResults?.first?.systemID == .Atari2600)
    }

    @Test
    func searchByFilenameWithSystem() async throws {
        let partialResults = try await db.searchDatabase(usingFilename: "Boxing", systemID: nil)
        #expect(partialResults?.count == 4)  // Should find all Boxing variants
        #expect(partialResults?.allSatisfy { $0.systemID == .Atari2600 } == true)  // All should be Atari 2600
    }

    @Test
    func searchBrainGames() async throws {
        let brainResults = try await db.searchDatabase(usingFilename: "Brain Games", systemID: nil)
        #expect(brainResults?.count == 2)  // US and Europe versions
        #expect(brainResults?.allSatisfy { $0.systemID == .Atari2600 } == true)
    }

    // MARK: - Region Tests
    @Test
    func regionDetection() async throws {
        let results = try await db.searchDatabase(usingFilename: "Boxing", systemID: nil)
        let regions = Set(results?.compactMap { $0.region } ?? [])
        #expect(regions.contains("US"))
        #expect(regions.contains("EU"))
        #expect(regions.contains("DE"))
        #expect(regions.contains("BR"))
    }

    // MARK: - Unlicensed Game Detection
    @Test
    func unlicensedGameDetection() async throws {
        // Brazilian Boxing is unlicensed
        let brBoxingMD5 = "a8b3ea6836b99bea77c8f603cf1ea187"
        let unlicensed = try await db.searchROM(byMD5: brBoxingMD5)
        #expect(((unlicensed?.gameTitle.contains("(Unl)")) != nil))

        // US Boxing is licensed
        let usBoxingMD5 = "c3ef5c4653212088eda54dc91d787870"
        let licensed = try await db.searchROM(byMD5: usBoxingMD5)
        #expect(!licensed!.gameTitle.contains("(Unl)"))
    }
}
#endif
