import Foundation
import PVSystems
import PVLookupTypes

/// Handles artwork URL construction and validation for libretro thumbnails
public struct LibretroArtwork {
    /// Base URL for libretro thumbnails
    private static let baseURL = "https://thumbnails.libretro.com"

    /// Constructs artwork URLs for a given system and game name
    /// - Parameters:
    ///   - systemName: Full system name (e.g. "Nintendo - Game Boy Advance")
    ///   - gameName: Game name including region if available
    ///   - types: Artwork types to generate URLs for
    /// - Returns: Array of constructed URLs
    internal static func constructURLs(systemName: String, gameName: String, types: ArtworkType) -> [URL] {
        var urls: [URL] = []

        // Check each possible type in the OptionSet
        if types.contains(.boxFront) {
            if let url = constructURL(systemName: systemName, gameName: gameName, folder: "Named_Boxarts") {
                urls.append(url)
            }
        }

        if types.contains(.titleScreen) {
            if let url = constructURL(systemName: systemName, gameName: gameName, folder: "Named_Titles") {
                urls.append(url)
            }
        }

        if types.contains(.screenshot) {
            if let url = constructURL(systemName: systemName, gameName: gameName, folder: "Named_Snaps") {
                urls.append(url)
            }
        }

        return urls
    }

    /// Helper to construct a single URL
    private static func constructURL(systemName: String, gameName: String, folder: String) -> URL? {
        let urlString = "\(baseURL)/\(systemName)/\(folder)/\(gameName).png"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        return URL(string: urlString ?? "")
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
    public static func getValidURLs(
        systemName: String,
        gameName: String,
        types: ArtworkType = [.boxFront]
    ) async -> [URL] {
        let urls = constructURLs(systemName: systemName, gameName: gameName, types: types)

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
        let filename = (metadata.romFileName as NSString?)?
            .deletingPathExtension
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Use constructURLs with all supported types
        return constructURLs(
            systemName: systemFolder,
            gameName: filename,
            types: [.boxFront, .titleScreen, .screenshot]
        )
    }
}

// MARK: - ArtworkLookupOfflineService Conformance
extension LibretroArtwork: ArtworkLookupOfflineService {
    /// Search for artwork by game name and system
    public func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        // Use default types if none specified
        let types = artworkTypes ?? .defaults
        let systemName = systemID?.libretroDatabaseName ?? ""

        // Construct and validate URLs
        let urls = LibretroArtwork.constructURLs(systemName: systemName, gameName: name, types: types)
        var validArtwork: [ArtworkMetadata] = []

        for url in urls {
            if await LibretroArtwork.validateURL(url) {
                // Determine artwork type from URL path
                let type = ArtworkType.fromLibretroPath(url.path)

                validArtwork.append(ArtworkMetadata(
                    url: url,
                    type: type,
                    resolution: nil,
                    description: nil,
                    source: "LibretroThumbnails",
                    systemID: systemID
                ))
            }
        }

        return validArtwork.isEmpty ? nil : validArtwork
    }

    /// Get artwork for a specific game ID
    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
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

// MARK: - ArtworkType Extensions
private extension ArtworkType {
    var libretroDatabaseFolder: String {
        switch self {
        case .boxFront: return "Named_Boxarts"
        case .titleScreen: return "Named_Titles"
        case .screenshot: return "Named_Snaps"
        default: return ""
        }
    }

    static func fromLibretroPath(_ path: String) -> ArtworkType {
        if path.contains("Named_Boxarts") {
            return .boxFront
        } else if path.contains("Named_Titles") {
            return .titleScreen
        } else if path.contains("Named_Snaps") {
            return .screenshot
        } else {
            return .other
        }
    }
}

private extension String {
    func deletingPathExtension() -> String {
        (self as NSString).deletingPathExtension
    }
}
