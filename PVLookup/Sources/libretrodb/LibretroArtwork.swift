import Foundation
import PVSystems
import PVLookupTypes

/// Handles artwork URL construction and validation for libretro thumbnails
public struct LibretroArtwork {
    /// Base URL for libretro thumbnails
    private static let baseURL = "https://thumbnails.libretro.com"

    /// Cache for URL validation results
    private static let urlCache = URLCache(
        memoryCapacity: 10 * 1024 * 1024,  // 10MB memory cache
        diskCapacity: 50 * 1024 * 1024,    // 50MB disk cache
        directory: nil
    )

    /// Cache duration for URL validation results
    private static let cacheDuration: TimeInterval = 3600 // 1 hour

    private let db: libretrodb

    public init(db: libretrodb = .init()) {
        self.db = db
    }

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
            if let url = Self.constructURL(systemName: systemName, gameName: gameName, folder: "Named_Boxarts") {
                urls.append(url)
            }
        }

        if types.contains(.titleScreen) {
            if let url = Self.constructURL(systemName: systemName, gameName: gameName, folder: "Named_Titles") {
                urls.append(url)
            }
        }

        if types.contains(.screenshot) {
            if let url = Self.constructURL(systemName: systemName, gameName: gameName, folder: "Named_Snaps") {
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

    /// Validates if a URL exists with caching
    public static func validateURL(_ url: URL) async -> Bool {
        // Check cache first
        let cacheRequest = URLRequest(url: url)
        if let cachedResponse = urlCache.cachedResponse(for: cacheRequest),
           cachedResponse.response is HTTPURLResponse {
            return true
        }

        // If not in cache, perform HEAD request
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Cache successful responses
                let cachedResponse = CachedURLResponse(
                    response: response,
                    data: Data(),
                    userInfo: nil,
                    storagePolicy: .allowed
                )
                urlCache.storeCachedResponse(cachedResponse, for: request)
                return true
            }
        } catch {
            return false
        }
        return false
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
        let types = artworkTypes ?? .defaults
        let systemName = systemID?.libretroDatabaseName ?? ""

        // Get a limited set of matching games
        let results = try db.searchMetadata(
            usingFilename: name,
            systemID: systemID
        )
        guard let games = results else { return nil }

        // Limit results after the fact if needed
        let limitedGames = Array(games.prefix(10))

        // Batch URL construction and validation
        let allURLs = limitedGames.flatMap { game -> [(URL, ArtworkType, ROMMetadata)] in
            let gameName = game.romFileName?.deletingPathExtension() ?? ""
            let systemFolder = game.systemID.libretroDatabaseName
                .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""

            // Create array of types to iterate
            let typeArray: [ArtworkType] = [.boxFront, .titleScreen, .screenshot]
            let selectedTypes = typeArray.filter { types.contains($0) }

            return selectedTypes.compactMap { type -> (URL, ArtworkType, ROMMetadata)? in
                let folder = type.libretroDatabaseFolder
                guard
                      let url = Self.constructURL(systemName: systemFolder, gameName: gameName, folder: folder) else {
                    return nil
                }
                return (url, type, game)
            }
        }

        // Validate URLs in parallel
        let validResults = await withTaskGroup(of: (URL, ArtworkType, ROMMetadata, Bool).self) { group in
            for (url, type, metadata) in allURLs {
                group.addTask {
                    let isValid = await LibretroArtwork.validateURL(url)
                    return (url, type, metadata, isValid)
                }
            }

            var results: [(URL, ArtworkType, ROMMetadata)] = []
            for await (url, type, metadata, isValid) in group where isValid {
                results.append((url, type, metadata))
            }
            return results
        }

        // Convert to ArtworkMetadata
        return validResults.map { url, type, metadata in
            ArtworkMetadata(
                url: url,
                type: type,
                resolution: nil,
                description: metadata.gameTitle,
                source: "LibretroThumbnails",
                systemID: metadata.systemID
            )
        }
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
