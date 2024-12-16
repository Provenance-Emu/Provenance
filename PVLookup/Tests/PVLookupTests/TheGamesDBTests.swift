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
}

// MARK: - Mock Client
private actor MockTheGamesDBClient {
    func searchGames(name: String, platformID: String?) async throws -> GamesResponse {
        // Return mock data for Super Mario World
        return GamesResponse(
            code: 200,
            status: "Success",
            data: .init(games: [
                Game(
                    id: 1,
                    game_title: "Super Mario World",
                    platform: 6  // SNES
                )
            ])
        )
    }

    func getGameImages(gameID: String, types: [String]?) async throws -> ImagesResponse {
        // Filter images based on requested types
        var images: [String: [GameImage]] = [:]

        // Base set of available images
        let allImages = [
            "boxart": [
                GameImage(
                    id: 1,
                    type: "boxart",
                    side: "front",
                    filename: "boxart/front/1-1.jpg",
                    resolution: "1024x1024"
                ),
                GameImage(
                    id: 2,
                    type: "boxart",
                    side: "back",
                    filename: "boxart/back/1-1.jpg",
                    resolution: "1024x1024"
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
            ]
        ]

        // If types are specified, only return those types
        if let types = types {
            for type in types {
                if let typeImages = allImages[type] {
                    // For boxart, check if we need to filter by side
                    if type == "boxart" {
                        // Only include front boxart
                        images[type] = typeImages.filter { $0.side == "front" }
                    } else {
                        images[type] = typeImages
                    }
                }
            }
        } else {
            // If no types specified, return all images
            images = allImages
        }

        return ImagesResponse(
            code: 200,
            status: "Success",
            data: .init(
                base_url: .init(
                    original: "https://cdn.thegamesdb.net/images/original/",
                    small: nil,
                    thumb: nil
                ),
                images: images
            )
        )
    }
}

// MARK: - TheGamesDBClient Protocol
extension MockTheGamesDBClient: TheGamesDBClient {}
