import Testing
import PVLogging
import PVSystems
@testable import PVLookup
@testable import TheGamesDB
@testable import PVLookupTypes

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

    @Test("Database initialization works")
    func testDatabaseInitialization() async throws {
        // Verify database exists and is readable
        let artwork = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: nil
        )
        #expect(artwork != nil)
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
            artworkTypes: nil
        )

        #expect(artwork != nil)
        #expect(!artwork!.isEmpty)

        // Verify we have different types of artwork
        let artworkTypes = Set(artwork?.map(\.type) ?? [])
        print("\nFound artwork types: \(artworkTypes)")
        #expect(!artworkTypes.isEmpty)
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

    @Test("Handles database errors gracefully")
    func testDatabaseErrors() async throws {
        // Try to initialize with invalid path
        do {
            _ = try await TheGamesDB()
            #expect(false, "Should have thrown an error")
        } catch let error as TheGamesDBError {
            #expect(error == .databaseNotInitialized)
        }
    }

    @Test("Handles fuzzy name matching with special characters")
    func testFuzzyNameMatchingSpecialChars() async throws {
        // Test with parentheses
        let withParens = try await db.searchArtwork(
            byGameName: "Super Mario World (USA)",
            systemID: .SNES,
            artworkTypes: nil
        )
        #expect(withParens != nil)
        #expect(!withParens!.isEmpty)

        // Test with brackets
        let withBrackets = try await db.searchArtwork(
            byGameName: "Super Mario World [!]",
            systemID: .SNES,
            artworkTypes: nil
        )
        #expect(withBrackets != nil)
        #expect(!withBrackets!.isEmpty)

        // Test with version numbers
        let withVersion = try await db.searchArtwork(
            byGameName: "Super Mario World v1.1",
            systemID: .SNES,
            artworkTypes: nil
        )
        #expect(withVersion != nil)
        #expect(!withVersion!.isEmpty)
    }

    @Test("Handles fuzzy name matching with partial names")
    func testFuzzyNameMatchingPartial() async throws {
        // Test with partial title
        let partialStart = try await db.searchArtwork(
            byGameName: "Super Mario",
            systemID: .SNES,
            artworkTypes: nil
        )
        #expect(partialStart != nil)
        #expect(!partialStart!.isEmpty)

        // Test with middle word
        let partialMiddle = try await db.searchArtwork(
            byGameName: "Mario",
            systemID: .SNES,
            artworkTypes: nil
        )
        #expect(partialMiddle != nil)
        #expect(!partialMiddle!.isEmpty)

        // Test with end word
        let partialEnd = try await db.searchArtwork(
            byGameName: "World",
            systemID: .SNES,
            artworkTypes: nil
        )
        #expect(partialEnd != nil)
        #expect(!partialEnd!.isEmpty)
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

        // Test boxart back
        let boxartBack = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: [.boxBack]
        )
        #expect(boxartBack?.allSatisfy { $0.type == .boxBack } == true)

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
        // Test with unknown type
        let unknownType = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: [.other]
        )
        // Should still return results but marked as .other type
        #expect(unknownType?.contains { $0.type == .other } == true)

        // Test with no type filter
        let noFilter = try await db.searchArtwork(
            byGameName: testData.superMarioWorld.title,
            systemID: .SNES,
            artworkTypes: nil
        )
        // Should return all available types
        #expect(noFilter?.isEmpty == false)
        let allTypes = Set(noFilter?.map(\.type) ?? [])
        #expect(allTypes.count > 1)
    }
}
