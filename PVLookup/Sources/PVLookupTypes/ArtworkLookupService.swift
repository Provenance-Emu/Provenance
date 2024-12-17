import Foundation
import PVSystems

/// Represents different types of artwork
public enum ArtworkType: String, Codable, Sendable {
    case boxFront = "front"
    case boxBack = "back"
    case manual = "manual"
    case screenshot = "screenshot"
    case titleScreen = "titlescreen"
    case fanArt = "fanart"
    case banner = "banner"
    case clearLogo = "clearlogo"
    case other = "other"
}

/// Represents a single piece of artwork with its metadata
public struct ArtworkMetadata: Codable, Sendable {
    /// The URL to the artwork image
    public let url: URL

    /// The type of artwork
    public let type: ArtworkType

    /// Optional resolution of the artwork (e.g., "1920x1080")
    public let resolution: String?

    /// Optional description or caption
    public let description: String?

    /// Source database or service that provided this artwork
    public let source: String

    public init(
        url: URL,
        type: ArtworkType,
        resolution: String? = nil,
        description: String? = nil,
        source: String
    ) {
        self.url = url
        self.type = type
        self.resolution = resolution
        self.description = description
        self.source = source
    }
}

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
        artworkTypes: [ArtworkType]?
    ) async throws -> [ArtworkMetadata]?

    /// Get artwork for a specific game ID
    /// - Parameters:
    ///   - gameID: ID of the game in the service's database
    ///   - artworkTypes: Optional array of artwork types to filter results
    /// - Returns: Array of artwork metadata, or nil if none found
    func getArtwork(
        forGameID gameID: String,
        artworkTypes: [ArtworkType]?
    ) async throws -> [ArtworkMetadata]?
    
    /// Get possible URLs for a ROM
    func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]?
}
