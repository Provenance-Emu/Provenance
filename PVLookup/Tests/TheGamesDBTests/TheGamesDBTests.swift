//
//  TheGamesDBTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Testing
import PVLogging
import PVSystems
@testable import PVLookup
@testable import TheGamesDB
@testable import PVLookupTypes
import PVSQLiteDatabase
import Foundation

struct TheGamesDBTests {
    let db: TheGamesDB

    // Test data based on known database entries
    let testData = (
        superMarioWorld: (
            id: 1018,
            title: "Super Mario World",
            platformId: 6, // SNES
            boxartFront: "boxart/1018-1.jpg",
            boxartBack: "boxart/1018-2.jpg",
            screenshot: "screenshot/1018-1.jpg"
        ),
        finalFantasy: (
            id: 1020,
            title: "Final Fantasy VI",
            platformId: 6, // SNES
            boxartFront: "boxart/1020-1.jpg",
            screenshot: "screenshot/1020-1.jpg"
        )
    )

    init() async throws {
        print("Starting TheGamesDB test initialization...")
        self.db = try await TheGamesDB()
        print("TheGamesDB initialization complete")
    }

    @Test("Search artwork by name returns expected results")
    func testSearchArtworkByName() async throws {
        let artwork = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: [.boxFront, .screenshot]
        )

        print("\nArtwork search results:")
        artwork?.forEach { art in
            print("- Type: \(art.type.rawValue)")
            print("  URL: \(art.url)")
            print("  Resolution: \(art.resolution ?? "unknown")")
        }

        #expect(artwork != nil)
        #expect(!artwork!.isEmpty)

        // Verify we got some box art
        let boxArt = artwork?.filter { $0.type == .boxFront }
        #expect(!boxArt!.isEmpty)

        // Verify URLs are valid
        artwork?.forEach { art in
            #expect(art.url.absoluteString.starts(with: "https://cdn.thegamesdb.net/images/"))
            #expect(art.source == "TheGamesDB")
        }
    }

    @Test("Get artwork by game ID returns expected results")
    func testGetArtworkByGameID() async throws {
        let artwork = try await db.getArtwork(
            forGameID: String(testData.superMarioWorld.id),
            artworkTypes: nil  // Get all types
        )

        print("\nArtwork results for game ID \(testData.superMarioWorld.id):")
        artwork?.forEach { art in
            print("- Type: \(art.type.rawValue)")
            print("  URL: \(art.url)")
            print("  Resolution: \(art.resolution ?? "unknown")")
        }

        #expect(artwork != nil)
        #expect(!artwork!.isEmpty)

        // Verify we have different types of artwork
        let artworkTypes = Set(artwork?.map(\.type) ?? [])
        print("\nFound artwork types: \(artworkTypes)")
        #expect(artworkTypes.count > 1)
    }

    @Test("Handles invalid game ID correctly")
    func testInvalidGameID() async throws {
        do {
            let artwork = try await db.getArtwork(
                forGameID: "invalid",
                artworkTypes: nil
            )
            #expect(artwork == nil)
        } catch let error as TheGamesDBError {
            #expect(error == .invalidGameID)
        }
    }

    @Test("Filters artwork types correctly")
    func testArtworkTypeFiltering() async throws {
        // Test with only boxart
        let boxartOnly = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: [.boxFront]
        )

        #expect(boxartOnly?.allSatisfy { $0.type == .boxFront } == true)

        // Test with multiple types
        let multipleTypes = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: [.boxFront, .screenshot]
        )

        let types = Set(multipleTypes?.map(\.type) ?? [])
        #expect(types.isSubset(of: [.boxFront, .screenshot]))
    }

    @Test("Handles fuzzy name matching")
    func testFuzzyNameMatching() async throws {
        // Test with partial name
        let partialName = try await db.searchArtwork(
            byGameName: "Mario",
            systemID: .SNES,
            artworkTypes: nil
        )

        #expect(partialName != nil)
        #expect(!partialName!.isEmpty)

        // Test with name containing region
        let nameWithRegion = try await db.searchArtwork(
            byGameName: "Super Mario World (USA)",
            systemID: .SNES,
            artworkTypes: nil
        )

        #expect(nameWithRegion != nil)
        #expect(!nameWithRegion!.isEmpty)
    }

    @Test("Handles fuzzy name matching with special characters")
    func testFuzzyNameMatchingSpecialChars() async throws {
        print("\nTesting fuzzy name matching with special characters...")

        // Test base name first to verify database has the game
        print("\nTesting base name 'Super Mario World'...")
        let baseName = try await db.searchArtwork(
            byGameName: "Super Mario World",
            systemID: .SNES,
            artworkTypes: nil
        )
        #expect(baseName != nil && !baseName!.isEmpty, "Base name search should work")

        // Test with parentheses
        print("\nTesting name with parentheses...")
        let withParens = try await db.searchArtwork(
            byGameName: "Super Mario World (USA)",
            systemID: .SNES,
            artworkTypes: nil
        )
        print("Found \(withParens?.count ?? 0) results")
        #expect(withParens != nil, "Should handle parentheses")
        #expect(!withParens!.isEmpty, "Should find results with parentheses")

        // Test with brackets
        print("\nTesting name with brackets...")
        let withBrackets = try await db.searchArtwork(
            byGameName: "Super Mario World [!]",
            systemID: .SNES,
            artworkTypes: nil
        )
        print("Found \(withBrackets?.count ?? 0) results")
        #expect(withBrackets != nil, "Should handle brackets")
        #expect(!withBrackets!.isEmpty, "Should find results with brackets")

        // Test with version numbers
        print("\nTesting name with version number...")
        let withVersion = try await db.searchArtwork(
            byGameName: "Super Mario World v1.1",
            systemID: .SNES,
            artworkTypes: nil
        )
        print("Found \(withVersion?.count ?? 0) results")
        #expect(withVersion != nil, "Should handle version numbers")
        #expect(!withVersion!.isEmpty, "Should find results with version numbers")
    }

    @Test("Converts artwork types correctly")
    func testArtworkTypeConversion() async throws {
        // Test boxart front
        let boxartFront = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: [.boxFront]
        )
        #expect(boxartFront?.allSatisfy { $0.type == .boxFront } == true)

        // Test screenshots
        let screenshots = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: [.screenshot]
        )
        #expect(screenshots?.allSatisfy { $0.type == .screenshot } == true)

        // Test multiple types
        let multipleTypes = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: [.boxFront, .screenshot, .titleScreen]
        )
        let types = Set(multipleTypes?.map(\.type) ?? [])
        #expect(types.isSubset(of: [.boxFront, .screenshot, .titleScreen]))
    }

    @Test("Handles artwork type conversion edge cases")
    func testArtworkTypeConversionEdgeCases() async throws {
        // Test with no type filter (should get all types)
        let noFilter = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: nil
        )
        #expect(noFilter?.isEmpty == false, "Should return all available types")

        // Verify we get all expected types
        let allTypes = Set(noFilter?.map(\.type) ?? [])
        print("\nFound artwork types: \(allTypes)")
        #expect(allTypes.count > 1, "Should have multiple artwork types")

        // Test with unknown type
        let unknownType = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: [.other]
        )

        // Verify we get fanart as .other type
        print("\nTesting unknown type conversion:")
        unknownType?.forEach { art in
            print("- Type: \(art.type)")
        }
        #expect(unknownType?.contains { $0.type == .other } == true, "Should convert unknown types to .other")
    }
}
