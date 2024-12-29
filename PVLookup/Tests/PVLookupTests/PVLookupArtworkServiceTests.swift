import Testing
import Foundation
@testable import PVLookup
@testable import PVLookupTypes
@testable import OpenVGDB
@testable import libretrodb
@testable import TheGamesDB
import PVSystems

struct PVLookupArtworkServiceTests {
    let lookup: PVLookup

    init() async {
        self.lookup = .shared
    }

    @Test("Combines artwork results from multiple services")
    func testSearchArtworkCombinesResults() async throws {
        // Test with a game that should have artwork in multiple services
        let results = try await lookup.searchArtwork(
            byGameName: "Super Mario World",
            systemID: .SNES,
            artworkTypes: nil
        )

        #expect(results != nil)
        #expect(!results!.isEmpty)

        // Verify we got results from different sources
        let sources = Set(results?.map(\.source) ?? [])
        print("Found artwork sources: \(sources)")
        #expect(sources.count > 1)  // Should have results from multiple sources

        // Verify artwork types are sorted correctly
        let types = results?.map(\.type)
        #expect(types?.first == .boxFront)  // Box front should be first
    }

    @Test("Gets artwork URLs from all available sources")
    func testGetArtworkURLsFromAllSources() async throws {
        // Create test ROM metadata
        let rom = ROMMetadata(
            gameTitle: "Super Mario World",
            systemID: .SNES,
            romFileName: "Super Mario World (USA).sfc",
            romHashMD5: "CDD3C8C37322978CA8669B34BC89C804"  // Known MD5
        )

        let urls = try await lookup.getArtworkURLs(forRom: rom)

        #expect(urls != nil)
        #expect(!urls!.isEmpty)

        // Print URLs for debugging
        print("\nFound artwork URLs:")
        urls?.forEach { print($0) }

        // Verify URLs from different sources
        let openVGDBUrls = urls?.filter { $0.absoluteString.contains("gamefaqs") }
        let libretroDBArtworkUrls = urls?.filter { $0.absoluteString.contains("libretro") }
        let theGamesDBUrls = urls?.filter { $0.absoluteString.contains("thegamesdb") }

        print("\nURLs by source:")
        print("OpenVGDB: \(openVGDBUrls?.count ?? 0)")
        print("LibretroDB: \(libretroDBArtworkUrls?.count ?? 0)")
        print("TheGamesDB: \(theGamesDBUrls?.count ?? 0)")

        // Should have results from at least two sources
        let sourcesWithResults = [
            openVGDBUrls?.isEmpty == false,
            libretroDBArtworkUrls?.isEmpty == false,
            theGamesDBUrls?.isEmpty == false
        ].filter { $0 }.count

        #expect(sourcesWithResults >= 2)
    }

    @Test("Sorts artwork types in correct order")
    func testArtworkTypeSorting() async throws {
        let results = try await lookup.searchArtwork(
            byGameName: "Final Fantasy VI",
            systemID: .SNES,
            artworkTypes: [.boxFront, .boxBack, .screenshot]
        )

        #expect(results != nil)
        let types = results?.map(\.type)

        // Verify order matches priority
        #expect(types?.first == .boxFront)
        #expect(types?.contains(where: { $0 == .boxBack }) == true)
        #expect(types?.contains(where: { $0 == .screenshot }) == true)

        // Print order for debugging
        print("\nArtwork type order:")
        types?.forEach { print($0.rawValue) }
    }
}
