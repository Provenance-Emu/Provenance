@testable import PVLookup
import PVLookupTypes
import PVSystems
import Foundation

final class MockArtworkService: ArtworkLookupService {
    private actor Storage {
        var mockResults: [ArtworkMetadata]?
        var mockURLs: [URL]?
        var mockMappings: ArtworkMapping

        init(
            mockResults: [ArtworkMetadata]? = nil,
            mockURLs: [URL]? = nil,
            mockMappings: ArtworkMapping = ArtworkMappings(romMD5: [:], romFileNameToMD5: [:])
        ) {
            self.mockResults = mockResults
            self.mockURLs = mockURLs
            self.mockMappings = mockMappings
        }
    }

    private let storage: Storage

    init(
        mockResults: [ArtworkMetadata]? = nil,
        mockURLs: [URL]? = nil,
        mockMappings: ArtworkMapping = ArtworkMappings(romMD5: [:], romFileNameToMD5: [:])
    ) {
        self.storage = Storage(
            mockResults: mockResults,
            mockURLs: mockURLs,
            mockMappings: mockMappings
        )
    }

    func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        await storage.mockResults
    }

    func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        await storage.mockResults
    }

    func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        await storage.mockURLs
    }

    func getArtworkMappings() async throws -> ArtworkMapping {
        await storage.mockMappings
    }
}
