import Testing
import Foundation
@testable import TheGamesDB
@testable import PVLookupTypes

struct TheGamesDBTests {
    let service: TheGamesDBService

    init() {
        // Create a mock client for testing
        let mockClient = MockTheGamesDBClient()
        self.service = TheGamesDBService(client: mockClient)
    }

    @Test
    func testSearchArtworkByName() async throws {
        let artwork = try await service.searchArtwork(
            byGameName: "Super Mario World",
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
            #expect(art.url.absoluteString.starts(with: "https://"))
            #expect(art.source == "TheGamesDB")
        }
    }

    @Test
    func testGetArtworkByGameID() async throws {
        let artwork = try await service.getArtwork(
            forGameID: "1",  // Super Mario World
            artworkTypes: nil  // Get all types
        )

        print("\nArtwork results for game ID 1:")
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

    @Test("Handles empty response correctly")
    func testEmptyResponse() async throws {
        let artwork = try await service.searchArtwork(
            byGameName: "NonexistentGame12345",
            systemID: .Unknown,
            artworkTypes: nil
        )

        #expect(artwork == nil)
    }

    @Test("Filters artwork types correctly")
    func testArtworkTypeFiltering() async throws {
        // Test with only boxart
        let boxartOnly = try await service.searchArtwork(
            byGameName: "Super Mario World",
            systemID: .SNES,
            artworkTypes: [.boxFront]
        )

        #expect(boxartOnly?.allSatisfy { $0.type == .boxFront } == true)

        // Test with multiple types
        let multipleTypes = try await service.searchArtwork(
            byGameName: "Super Mario World",
            systemID: .SNES,
            artworkTypes: [.boxFront, .screenshot]
        )

        let types = Set(multipleTypes?.map(\.type) ?? [])
        #expect(types.isSubset(of: [.boxFront, .screenshot]))
    }

    @Test("Sorts artwork correctly")
    func testArtworkSorting() async throws {
        let artwork = try await service.searchArtwork(
            byGameName: "Super Mario World",
            systemID: .SNES,
            artworkTypes: [.boxFront, .boxBack, .screenshot]
        )

        #expect(artwork != nil, "No artwork found")
        guard let sortedArtwork = artwork else { return }

        // Print current order for debugging
        print("\nArtwork order:")
        sortedArtwork.enumerated().forEach { index, art in
            print("[\(index)] \(art.type.rawValue)")
        }

        // First item should be boxFront
        #expect(sortedArtwork.first?.type == .boxFront, "First item should be boxFront")

        // All boxart (front and back) should come before other types
        let boxArtTypes: Set<ArtworkType> = [.boxFront, .boxBack]
        let otherTypes: Set<ArtworkType> = [.screenshot, .titleScreen, .clearLogo, .banner, .fanArt, .manual, .other]

        // Get indices for each type
        let boxArtIndices = sortedArtwork.enumerated()
            .filter { boxArtTypes.contains($0.element.type) }
            .map(\.offset)
        let otherIndices = sortedArtwork.enumerated()
            .filter { otherTypes.contains($0.element.type) }
            .map(\.offset)

        if !boxArtIndices.isEmpty && !otherIndices.isEmpty {
            let lastBoxArtIndex = boxArtIndices.max()!
            let firstOtherIndex = otherIndices.min()!
            #expect(lastBoxArtIndex < firstOtherIndex,
                   "Box art (max index: \(lastBoxArtIndex)) should come before other types (min index: \(firstOtherIndex))")
        }
    }
}

// MARK: - Mock Client
private actor MockTheGamesDBClient: TheGamesDBClient {
    func searchGames(name: String, platformID: Int?) async throws -> GamesResponse {
        // Return mock game data
        return GamesResponse(
            code: 200,
            status: "Success",
            data: GamesResponse.GamesData(
                games: [
                    Game(
                        id: 1,
                        game_title: "Super Mario World",
                        platform: platformID ?? 6  // SNES platform ID
                    ),
                    Game(
                        id: 2,
                        game_title: "Super Mario World 2: Yoshi's Island",
                        platform: platformID ?? 6
                    )
                ]
            )
        )
    }

    func getGameImages(gameID: String?, types: [String]?) async throws -> ImagesResponse {
        // Return mock image data with dictionary structure
        return ImagesResponse(
            code: 200,
            status: "Success",
            data: ImagesResponse.ImagesData(
                base_url: ImagesResponse.ImagesData.BaseURL(
                    original: "https://cdn.thegamesdb.net/images/original/",
                    small: "https://cdn.thegamesdb.net/images/small/",
                    thumb: "https://cdn.thegamesdb.net/images/thumb/",
                    cropped_center_thumb: "https://cdn.thegamesdb.net/images/cropped_center_thumb/",
                    medium: "https://cdn.thegamesdb.net/images/medium/",
                    large: "https://cdn.thegamesdb.net/images/large/"
                ),
                count: 4,
                images: .dictionary([
                    "boxart": [
                        GameImage(
                            id: 1,
                            type: "boxart",
                            side: "front",
                            filename: "boxart/1-1.jpg",
                            resolution: "2048x2048"
                        ),
                        GameImage(
                            id: 2,
                            type: "boxart",
                            side: "back",
                            filename: "boxart/1-2.jpg",
                            resolution: "2048x2048"
                        )
                    ],
                    "screenshot": [
                        GameImage(
                            id: 3,
                            type: "screenshot",
                            side: nil,
                            filename: "screenshot/1-1.jpg",
                            resolution: "1920x1080"
                        )
                    ],
                    "titlescreen": [
                        GameImage(
                            id: 4,
                            type: "titlescreen",
                            side: nil,
                            filename: "titlescreen/1-1.jpg",
                            resolution: "1920x1080"
                        )
                    ]
                ])
            )
        )
    }
}
