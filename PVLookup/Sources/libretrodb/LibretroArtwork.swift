import Foundation
import PVSystems
import PVLookupTypes
import PVSQLiteDatabase

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

    private let libreTroDB: libretrodb

    public init(libreTroDB: libretrodb) {
        self.libreTroDB = libreTroDB
    }

    /// Search for artwork by game name
    /// - Parameters:
    ///   - name: Name of the game
    ///   - systemID: Optional system ID to filter by
    ///   - types: Types of artwork to search for
    /// - Returns: Array of artwork metadata
    func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        types: Set<ArtworkType>
    ) async throws -> [ArtworkMetadata] {
        // Use libretrodb's search function
        let metadata = try await libreTroDB.searchGamesForArtwork(name: name, systemID: systemID)
        return convertToArtwork(metadata, types: types)
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
            if let url = Self.constructURL(systemName: systemName, gameName: gameName, folder: libretrodb.ArtworkConstants.boxartPath) {
                urls.append(url)
            }
        }

        if types.contains(.titleScreen) {
            if let url = Self.constructURL(systemName: systemName, gameName: gameName, folder: libretrodb.ArtworkConstants.titlesPath) {
                urls.append(url)
            }
        }

        if types.contains(.screenshot) {
            if let url = Self.constructURL(systemName: systemName, gameName: gameName, folder: libretrodb.ArtworkConstants.snapshotPath) {
                urls.append(url)
            }
        }

        return urls
    }

    /// Helper to construct a single URL
    internal static func constructURL(systemName: String, gameName: String, folder: String) -> URL? {
        // First decode any existing encoding
        let decodedSystem = systemName.removingPercentEncoding ?? systemName
        let decodedGame = gameName.removingPercentEncoding ?? gameName

        // Create URL components
        var components = URLComponents()
        components.scheme = "https"  // Keep HTTPS for iOS ATS requirements
        components.host = "thumbnails.libretro.com"

        // Build path without encoding first
        let path = "/\(decodedSystem)/\(folder)/\(decodedGame).png"

        // Then encode the entire path at once
        components.percentEncodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path

        print("Constructing URL:")
        print("- System: \(decodedSystem)")
        print("- Game: \(decodedGame)")
        print("- Folder: \(folder)")
        print("- Result: \(components.url?.absoluteString ?? "nil")")

        return components.url
    }

    /// Validates if a URL exists with caching
    public static func validateURL(_ url: URL) async -> Bool {
        guard url.scheme == "https",  // Keep HTTPS check
              url.host == "thumbnails.libretro.com",
              url.pathExtension.lowercased() == "png" else {
            return false
        }

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

    private static func cleanGameName(_ name: String) -> String {
        // Remove file extensions and parenthetical info
        var cleaned = name
            .replacingOccurrences(of: " (USA)", with: "")
            .replacingOccurrences(of: " (Europe)", with: "")
            .replacingOccurrences(of: " (Japan)", with: "")
            .replacingOccurrences(of: " (En,Fr,Es)", with: "")
            .replacingOccurrences(of: " (Rev 1)", with: "")
            .replacingOccurrences(of: " (Track 1)", with: "")
            .replacingOccurrences(of: " (Demo)", with: "")
            .replacingOccurrences(of: " (Kiosk)", with: "")
            .replacingOccurrences(of: " (Virtual Console)", with: "")
            .replacingOccurrences(of: " (Wii Virtual Console)", with: "")
            .replacingOccurrences(of: ".v64", with: "")
            .replacingOccurrences(of: ".z64", with: "")
            .replacingOccurrences(of: ".gbc", with: "")
            .replacingOccurrences(of: ".gba", with: "")
            .replacingOccurrences(of: ".iso", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Remove any remaining parenthetical content
        while let range = cleaned.range(of: #"\([^)]+\)"#, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func convertToArtwork(_ metadata: [ROMMetadata], types: Set<ArtworkType>) -> [ArtworkMetadata] {
        var artworks: [ArtworkMetadata] = []

        for game in metadata {
            let systemID = game.systemID
            let systemName = systemID.libretroDatabaseName
            let gameName = game.romFileName ?? game.gameTitle

            let urls = Self.constructURLs(
                systemName: systemName,
                gameName: gameName,
                types: ArtworkType(types)
            )

            for url in urls {
                // Create ArtworkMetadata for each URL
                let type = determineArtworkType(from: url)
                let artwork = ArtworkMetadata(
                    url: url,
                    type: type,
                    resolution: nil,
                    description: game.gameTitle,
                    source: "LibretroDB",
                    systemID: systemID
                )
                artworks.append(artwork)
            }
        }

        return artworks
    }

    private func determineArtworkType(from url: URL) -> ArtworkType {
        let path = url.path.lowercased()
        if path.contains("/named_boxarts/") {
            return .boxFront
        } else if path.contains("/named_titles/") {
            return .titleScreen
        } else if path.contains("/named_snaps/") {
            return .screenshot
        }
        return .other
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

        // Get all matching games in one query
        let metadata = try await libreTroDB.searchGamesForArtwork(name: name, systemID: systemID)
        guard !metadata.isEmpty else { return nil }

        // Use a set to automatically handle deduplication
        var artworkSet = Set<ArtworkMetadata>()

        for game in metadata {
            let gameName = game.romFileName ?? game.gameTitle
            let systemID = game.systemID

            let systemName = systemID.libretroDatabaseName

            // Check each supported type
            for type in [ArtworkType.retroDBSupported] where types.contains(type) {
                if let url = Self.constructURL(systemName: systemName, gameName: gameName, folder: type.libretroDatabaseFolder) {
                    let artwork = ArtworkMetadata(
                        url: url,
                        type: type,
                        resolution: nil,
                        description: game.gameTitle,
                        source: "LibretroThumbnails",
                        systemID: game.systemID
                    )
                    artworkSet.insert(artwork)
                }
            }
        }

        // Convert set back to array
        let artworks = Array(artworkSet)
        return artworks.isEmpty ? nil : artworks
    }

    public func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        return Self.getArtworkURLs(forRom: rom)
    }

    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        // LibretroDB doesn't support direct game ID lookup for artwork
        return nil
    }

    /// Get artwork mappings for ROMs
    public func getArtworkMappings() async throws -> ArtworkMapping {
        // Query the database for all ROM mappings
        let query = """
            SELECT DISTINCT
                roms.md5,
                roms.name as rom_name,
                games.display_name as game_title,
                games.platform_id,
                platforms.name as platform_name,
                manufacturers.name as manufacturer_name
            FROM roms
            JOIN games ON roms.serial_id = games.serial_id
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            WHERE roms.md5 IS NOT NULL
        """

        let results = try libreTroDB.db.execute(query: query)
        var romMD5: [String: [String: String]] = [:]
        var romFileNameToMD5: [String: String] = [:]

        for result in results {
            if let md5 = result["md5"] as? String,
               let romName = result["rom_name"] as? String,
               let gameTitle = result["game_title"] as? String,
               let platformId = (result["platform_id"] as? NSNumber)?.stringValue {

                // Store metadata for this MD5
                var metadata: [String: String] = [
                    "gameTitle": gameTitle,
                    "romName": romName,
                    "platformId": platformId
                ]

                // Add optional fields if present
                if let platformName = result["platform_name"] as? String {
                    metadata["platformName"] = platformName
                }
                if let manufacturerName = result["manufacturer_name"] as? String {
                    metadata["manufacturerName"] = manufacturerName
                }

                // Store in mappings
                romMD5[md5] = metadata
                romFileNameToMD5[romName] = md5

                // Store with platform prefix for better matching
                let platformKey = "\(platformId):\(romName)"
                romFileNameToMD5[platformKey] = md5
            }
        }

        return ArtworkMappings(
            romMD5: romMD5,
            romFileNameToMD5: romFileNameToMD5
        )
    }
}

// MARK: - ArtworkType Extensions
private extension ArtworkType {
    var libretroDatabaseFolder: String {
        switch self {
        case .boxFront: return libretrodb.ArtworkConstants.boxartPath
        case .titleScreen: return libretrodb.ArtworkConstants.titlesPath
        case .screenshot: return libretrodb.ArtworkConstants.snapshotPath
        default: return ""
        }
    }

    static func fromLibretroPath(_ path: String) -> ArtworkType {
        if path.contains(libretrodb.ArtworkConstants.boxartPath) {
            return .boxFront
        } else if path.contains(libretrodb.ArtworkConstants.titlesPath) {
            return .titleScreen
        } else if path.contains(libretrodb.ArtworkConstants.snapshotPath) {
            return .screenshot
        } else {
            return .other
        }
    }
}

internal extension String {
    func deletingPathExtension() -> String {
        (self as NSString).deletingPathExtension
    }
}
