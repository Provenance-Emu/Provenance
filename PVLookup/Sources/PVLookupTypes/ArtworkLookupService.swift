import Foundation
import PVSystems

/// Protocol for services that can look up artwork for games
public protocol ArtworkLookupService: Sendable {
    /// Search for artwork by game name and system
    /// - Parameters:
    ///   - name: Name of the game
    ///   - systemID: Optional system identifier to filter results
    ///   - artworkTypes: Optional array of artwork types to filter results
    /// - Returns: Array of artwork metadata, or nil if none found
    func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]?

    /// Get artwork for a specific game ID
    /// - Parameters:
    ///   - gameID: ID of the game in the service's database
    ///   - artworkTypes: Optional array of artwork types to filter results
    /// - Returns: Array of artwork metadata, or nil if none found
    func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]?

    /// Get possible URLs for a ROM
    func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]?
}
