//
//  LibretroArtworkTests.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/14/24.
//

import Testing
import Foundation
@testable import PVLookup
@testable import libretrodb
@testable import ROMMetadataProvider
import PVSystems
import PVLookupTypes

struct LibretroArtworkTests {
    let db: libretrodb

    // Test data for Pitfall
    struct TestGame {
        let title: String
        let systemID: SystemIdentifier
        let expectedArtwork: [String]
    }

    // Test data for known PSP game
    struct FromRussiaWithLoveTestGame {
        let title: String
        let systemID: SystemIdentifier
        let expectedArtwork: [String]
    }

    let testData = FromRussiaWithLoveTestGame(
        title: "007 - From Russia with Love",
        systemID: .PSP,
        expectedArtwork: ["boxart", "screenshot"]
    )

    init() async throws {
        print("Starting LibretroDB test initialization...")
        self.db = try await libretrodb()
        print("LibretroDB initialization complete")
    }


    @Test("Debug artwork search query")
    func debugArtworkSearch() throws {
        // Direct SQL query to verify we can get the data needed for artwork URLs
        let query = """
            SELECT DISTINCT
                games.display_name,
                games.full_name,
                platforms.name as platform_name,
                roms.name as rom_name,
                platforms.id as platform_id,
                manufacturers.name as manufacturer_name
            FROM games
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            LEFT JOIN roms ON games.serial_id = roms.serial_id
            WHERE games.display_name LIKE '%Pitfall%'
            AND platforms.id = \(testData.systemID.libretroDatabaseID ?? -1)
            """

        print("\nExecuting debug query:")
        print(query)

        let results = try db.db.execute(query: query)
        print("\nFound \(results.count) results:")
        results.forEach { result in
            print("- Game: \(result["display_name"] as? String ?? "nil")")
            print("  Platform: \(result["platform_name"] as? String ?? "nil")")
            print("  Manufacturer: \(result["manufacturer_name"] as? String ?? "nil")")
            print("  ROM: \(result["rom_name"] as? String ?? "nil")")

            // Show what the artwork URLs would look like
            if let romName = result["rom_name"] as? String,
               let platformName = result["platform_name"] as? String {
                let systemFolder = "\(result["manufacturer_name"] as? String ?? "") - \(platformName)"
                print("\nPotential artwork URLs:")
                print("- Boxart: https://thumbnails.libretro.com/\(systemFolder)/Named_Boxarts/\(romName).png")
                print("- Screenshot: https://thumbnails.libretro.com/\(systemFolder)/Named_Snaps/\(romName).png")
                print("- Titlescreen: https://thumbnails.libretro.com/\(systemFolder)/Named_Titles/\(romName).png")
            }
        }
    }

    @Test("Verifies artwork URLs use HTTPS")
    func testArtworkURLsUseHTTPS() async throws {
        print("\nTesting HTTPS URL validation:")

        let artwork = try await db.searchArtwork(
            byGameName: testData.title,
            systemID: testData.systemID,
            artworkTypes: nil
        )

        artwork?.forEach { art in
            print("Checking URL: \(art.url)")
            #expect(art.url.scheme == "https", "URL should use HTTPS: \(art.url)")
            #expect(art.url.absoluteString.starts(with: "https://"), "URL should start with https://")
        }
    }

    @Test("Validates artwork URL format")
    func testArtworkURLFormat() async throws {
        print("\nValidating artwork URL format:")

        let artwork = try await db.searchArtwork(
            byGameName: testData.title,
            systemID: testData.systemID,
            artworkTypes: nil
        )

        artwork?.forEach { art in
            let url = art.url
            print("Checking URL: \(url)")

            // Verify URL components
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            #expect(components != nil, "Should be a valid URL")
            #expect(components?.scheme == "https", "Should use HTTPS")
            #expect(components?.host != nil, "Should have a host")
            #expect(components?.path.isEmpty == false, "Should have a path")

            // Verify no HTTP URLs
            #expect(!url.absoluteString.contains("http://"), "Should not use HTTP")
        }
    }

    @Test("Verifies system ID mapping")
    func testSystemIDMapping() throws {
        let atari2600ID = SystemIdentifier.Atari2600.libretroDatabaseID
        print("\nSystem ID mapping:")
        print("- Atari 2600 -> LibretroDB ID: \(atari2600ID ?? -1)")
        #expect(atari2600ID != nil, "Should have valid LibretroDB ID for Atari 2600")
    }

    @Test("Verifies Atari 2600 system ID mapping")
    func testAtari2600Mapping() throws {
        let atari2600 = SystemIdentifier.Atari2600
        print("\nAtari 2600 mapping:")
        print("- SystemIdentifier: \(atari2600)")
        print("- Raw value: \(atari2600.rawValue)")
        print("- LibretroDB ID: \(atari2600.libretroDatabaseID ?? -1)")

        #expect(atari2600.libretroDatabaseID != nil, "Should have valid LibretroDB ID")
        let id = atari2600.libretroDatabaseID
            // Query platform table directly
            let query = "SELECT * FROM platforms WHERE id = \(id)"
            let results = try db.db.execute(query: query)
            print("- Platform query results: \(results)")
            #expect(!results.isEmpty, "Should find platform in database")

    }

    @Test("Debug database contents")
    func testDatabaseContents() throws {
        // Check platforms table
        let platformsQuery = """
            SELECT * FROM platforms
            """
        let platforms = try db.db.execute(query: platformsQuery)
        print("\nPlatforms in database:")
        platforms.forEach { platform in
            if let id = platform["id"],
               let name = platform["name"],
               let manufacturerId = platform["manufacturer_id"] {
                print("- ID: \(id)")
                print("  Name: \(name)")
                print("  Manufacturer ID: \(manufacturerId)")
            }
        }

        // Search for Pitfall without system filter
        let gameQuery = """
            SELECT DISTINCT
                games.display_name,
                games.platform_id,
                platforms.name as platform_name,
                roms.name as rom_name
            FROM games
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN roms ON games.serial_id = roms.serial_id
            WHERE games.display_name LIKE '%Pitfall%'
            """

        let games = try db.db.execute(query: gameQuery)
        print("\nPitfall games in database:")
        games.forEach { game in
            if let title = game["display_name"],
               let platformId = game["platform_id"],
               let platformName = game["platform_name"],
               let romName = game["rom_name"] {
                print("- Title: \(title)")
                print("  Platform ID: \(platformId)")
                print("  Platform Name: \(platformName)")
                print("  ROM Name: \(romName)")
            }
        }
    }

    @Test("Debug specific game search")
    func testDebugSpecificGame() throws {
        let query = """
            SELECT DISTINCT
                games.display_name,
                games.platform_id,
                platforms.name as platform_name,
                roms.name as rom_name,
                manufacturers.name as manufacturer_name
            FROM games
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            LEFT JOIN roms ON games.serial_id = roms.serial_id
            WHERE games.display_name = '\(testData.title)'
            """

        let results = try db.db.execute(query: query)
        print("\nSearching for exact game: \(testData.title)")
        print("Expected platform ID: \(testData.systemID.libretroDatabaseID ?? -1)")

        if results.isEmpty {
            print("No results found!")
        } else {
            results.forEach { result in
                if let title = result["display_name"] as? String,
                   let platformId = result["platform_id"] as? Int,
                   let platformName = result["platform_name"] as? String,
                   let manufacturer = result["manufacturer_name"] as? String,
                   let romName = result["rom_name"] as? String {
                    print("\nFound match:")
                    print("- Title: \(title)")
                    print("  Platform ID: \(platformId)")
                    print("  Platform: \(manufacturer) - \(platformName)")
                    print("  ROM: \(romName)")

                    // Show potential artwork URL
                    let systemFolder = "\(manufacturer) - \(platformName)"
                    print("\nPotential artwork URL:")
                    print("https://thumbnails.libretro.com/\(systemFolder)/Named_Boxarts/\(romName).png")
                }
            }
        }
    }

    @Test("Verifies known PSP artwork URL")
    func testKnownPSPArtwork() async throws {
        print("\nSearching for PSP game artwork:")
        print("- Game: \(testData.title)")
        print("- System: \(testData.systemID)")

        let artwork = try await db.searchArtwork(
            byGameName: testData.title,
            systemID: testData.systemID,
            artworkTypes: nil
        )

        #expect(artwork != nil, "Should find artwork")
        if let artwork = artwork {
            #expect(!artwork.isEmpty, "Should have at least one artwork result")

            // Verify the known boxart URL
            let knownURL = "https://thumbnails.libretro.com/Sony%20-%20PlayStation%20Portable/Named_Boxarts/007%20-%20From%20Russia%20with%20Love%20(Asia)%20(En).png"
            let hasKnownURL = artwork.contains { $0.url.absoluteString == knownURL }
            #expect(hasKnownURL, "Should find known boxart URL")

            print("\nFound artwork results:")
            artwork.forEach { art in
                print("- Type: \(art.type)")
                print("  URL: \(art.url)")
                print("  Source: \(art.source)")
            }
        }
    }

    @Test("Verifies known Jaguar artwork URL")
    func testKnownJaguarArtwork() async throws {
        // Use a game we know exists in the database
        let jaguarGame = TestGame(
            title: "Alien vs Predator",  // Matches database entry exactly
            systemID: .AtariJaguar,
            expectedArtwork: ["screenshot"]
        )

        print("\nSearching for Jaguar game artwork:")
        print("- Game: \(jaguarGame.title)")
        print("- System: \(jaguarGame.systemID)")

        let artwork = try await db.searchArtwork(
            byGameName: jaguarGame.title,
            systemID: jaguarGame.systemID,
            artworkTypes: [.screenshot]
        )

        #expect(artwork != nil, "Should find artwork")
        if let artwork = artwork {
            #expect(!artwork.isEmpty, "Should have at least one artwork result")

            // Verify the known screenshot URL
            let knownURL = "https://thumbnails.libretro.com/Atari%20-%20Jaguar/Named_Snaps/Alien%20vs%20Predator%20(World).png"
            let hasKnownURL = artwork.contains { $0.url.absoluteString == knownURL }
            #expect(hasKnownURL, "Should find known screenshot URL")

            print("\nFound artwork results:")
            artwork.forEach { art in
                print("- Type: \(art.type)")
                print("  URL: \(art.url)")
                print("  Source: \(art.source)")
            }
        }
    }

    @Test("Verifies known Jaguar artwork URL construction")
    func testKnownJaguarArtworkURL() throws {
        // Test direct URL construction without database lookup
        let systemName = "Atari - Jaguar"
        let gameName = "Aircars (USA)"  // Match the actual filename on the server

        let url = LibretroArtwork.constructURL(
            systemName: systemName,
            gameName: gameName,
            type: .screenshot
        )

        print("\nConstructed URL:")
        print("- System Name: \(systemName)")
        print("- Game Name: \(gameName)")
        print("- Type: screenshot")
        print("- URL: \(url?.absoluteString ?? "nil")")

        let expectedURL = "https://thumbnails.libretro.com/Atari%20-%20Jaguar/Named_Snaps/Aircars%20(USA).png"
        #expect(url?.absoluteString == expectedURL, "Should construct correct URL")
    }

    @Test("Verifies Jaguar database search")
    func testJaguarDatabaseSearch() async throws {
        // Search for a game we know exists in the database
        let jaguarGame = TestGame(
            title: "Alien vs Predator",  // This exists in the database
            systemID: .AtariJaguar,
            expectedArtwork: ["screenshot"]
        )

        print("\nSearching for known Jaguar game:")
        print("- Game: \(jaguarGame.title)")
        print("- System: \(jaguarGame.systemID)")

        let artwork = try await db.searchArtwork(
            byGameName: jaguarGame.title,
            systemID: jaguarGame.systemID,
            artworkTypes: [.screenshot]
        )

        #expect(artwork != nil, "Should find artwork")
        if let artwork = artwork {
            #expect(!artwork.isEmpty, "Should have at least one artwork result")
            print("\nFound artwork results:")
            artwork.forEach { art in
                print("- Type: \(art.type)")
                print("  URL: \(art.url)")
                print("  Source: \(art.source)")
            }
        }
    }
}
