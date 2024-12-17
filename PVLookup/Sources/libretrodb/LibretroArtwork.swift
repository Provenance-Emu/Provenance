import Foundation
import PVSystems
import PVLookupTypes

/// Handles artwork URL construction and validation for libretro thumbnails
public struct LibretroArtwork {
    /// Base URL for libretro thumbnails
    private static let baseURL = "https://thumbnails.libretro.com"

    /// Types of artwork available
    public enum ArtworkType: String {
        case boxart = "Named_Boxarts"
        case snapshot = "Named_Snaps"
        case titleScreen = "Named_Titles"
    }

    /// Constructs artwork URLs for a given system and game name
    /// - Parameters:
    ///   - systemName: Full system name (e.g. "Nintendo - Game Boy Advance")
    ///   - gameName: Game name including region if available
    ///   - types: Array of artwork types to generate URLs for
    /// - Returns: Array of constructed URLs
    public static func constructURLs(systemName: String, gameName: String, types: [ArtworkType] = [.boxart]) -> [URL] {
        return types.compactMap { type in
            let urlString = "\(baseURL)/\(systemName)/\(type.rawValue)/\(gameName).png"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            return URL(string: urlString ?? "")
        }
    }

    /// Validates if a URL exists by performing a HEAD request
    /// - Parameter url: URL to validate
    /// - Returns: True if URL returns 200 status code
    public static func validateURL(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Gets valid artwork URLs for a given system and game name
    /// - Parameters:
    ///   - systemName: Full system name
    ///   - gameName: Game name including region if available
    /// - Returns: Array of valid artwork URLs
    public static func getValidURLs(systemName: String, gameName: String) async -> [URL] {
        let urls = constructURLs(systemName: systemName, gameName: gameName)

        var validURLs: [URL] = []
        for url in urls {
            if await validateURL(url) {
                validURLs.append(url)
            }
        }

        return validURLs
    }

    /// Constructs artwork URLs for a given ROM metadata
    /// - Parameter metadata: ROM metadata to use for URL construction
    /// - Returns: Array of possible artwork URLs
    public static func getArtworkURLs(forRom metadata: ROMMetadata) -> [URL] {
        let systemFolder = metadata.systemID.libretroDatabaseName
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Get filename without extension
        let filename = (metadata.romFileName as NSString?)?
            .deletingPathExtension
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Construct URLs for each artwork type
        let boxartURL = URL(string: "\(baseURL)/\(systemFolder)/Named_Boxarts/\(filename).png")
        let titleURL = URL(string: "\(baseURL)/\(systemFolder)/Named_Titles/\(filename).png")
        let snapsURL = URL(string: "\(baseURL)/\(systemFolder)/Named_Snaps/\(filename).png")

        return [boxartURL, titleURL, snapsURL].compactMap { $0 }
    }
}

// MARK: - ArtworkLookupOfflineService Conformance
extension LibretroArtwork: ArtworkLookupOfflineService {
    /// Search for artwork by game name and system
    public func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: [PVLookupTypes.ArtworkType]?
    ) async throws -> [ArtworkMetadata]? {
        // Construct URLs for all requested artwork types (or default types if none specified)
        let types = artworkTypes ?? [.boxFront, .titleScreen, .screenshot]
        let systemName = systemID?.libretroDatabaseName ?? ""

        // Convert protocol ArtworkType to LibretroArtwork.ArtworkType
        let libretroTypes = types.compactMap { type -> LibretroArtwork.ArtworkType? in
            switch type {
            case .boxFront: return .boxart
            case .titleScreen: return .titleScreen
            case .screenshot: return .snapshot
            default: return nil
            }
        }

        // Construct and validate URLs
        let urls = LibretroArtwork.constructURLs(systemName: systemName, gameName: name, types: libretroTypes)
        var validArtwork: [ArtworkMetadata] = []

        for url in urls {
            if await LibretroArtwork.validateURL(url) {
                // Determine artwork type from URL path
                let type: PVLookupTypes.ArtworkType = if url.path.contains("Named_Boxarts") {
                    .boxFront
                } else if url.path.contains("Named_Titles") {
                    .titleScreen
                } else if url.path.contains("Named_Snaps") {
                    .screenshot
                } else {
                    .other
                }

                validArtwork.append(ArtworkMetadata(
                    url: url,
                    type: type,
                    resolution: nil,
                    description: nil,
                    source: "LibretroThumbnails"
                ))
            }
        }

        return validArtwork.isEmpty ? nil : validArtwork
    }

    /// Get artwork for a specific game ID
    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: [PVLookupTypes.ArtworkType]?
    ) async throws -> [ArtworkMetadata]? {
        // For libretro, this is the same as searchArtwork since we don't use IDs
        return try await searchArtwork(
            byGameName: gameID,
            systemID: nil,
            artworkTypes: artworkTypes
        )
    }

    /// Get artwork mappings for ROMs
    public func getArtworkMappings() async throws -> ArtworkMapping {
        // LibretroArtwork doesn't maintain a mapping database
        return ArtworkMappings(romMD5: [:], romFileNameToMD5: [:])
    }

    /// Get artwork URLs for a ROM
    public func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        // Get system name from ROM metadata
        let systemName = rom.systemID.libretroDatabaseName

        // Try with game title first
        let title = rom.gameTitle
        if !title.isEmpty {
            let urls = await LibretroArtwork.getValidURLs(systemName: systemName, gameName: title)
            if !urls.isEmpty {
                return urls
            }
        }

        // Fall back to filename if title search yields no results
        if let filename = rom.romFileName, !filename.isEmpty {
            let cleanName = filename.deletingPathExtension()
            let urls = await LibretroArtwork.getValidURLs(systemName: systemName, gameName: cleanName)
            if !urls.isEmpty {
                return urls
            }
        }

        return nil
    }
}

private extension String {
    func deletingPathExtension() -> String {
        (self as NSString).deletingPathExtension
    }
}
