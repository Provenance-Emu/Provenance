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
}
