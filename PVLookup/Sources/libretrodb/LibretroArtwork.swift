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
        let games = try db.searchGames(name: name, systemID: systemID, limit: 10)
        guard !games.isEmpty else { return nil }

        // Track unique URLs across all tasks
        var seenURLs = Set<URL>()

        // Batch URL validation
        let urlTasks = games.flatMap { game -> [(URL, ArtworkType, LibretroDBROMMetadata)] in
            let gameName = game.romFileName?.deletingPathExtension() ?? ""
            guard let systemID = game.systemID else {
                return []
            }

            let systemName = systemID.libretroDatabaseName
            var tasks: [(URL, ArtworkType, LibretroDBROMMetadata)] = []

            // Check each supported type and deduplicate URLs
            let supportedTypes: [ArtworkType] = [ArtworkType.retroDBSupported]
            for type in supportedTypes where types.contains(type) {
                if let url = Self.constructURL(systemName: systemName, gameName: gameName, folder: type.libretroDatabaseFolder),
                   !seenURLs.contains(url) {
                    seenURLs.insert(url)
                    tasks.append((url, type, game))
                }
            }

            return tasks
        }

        // Validate URLs in parallel
        let validResults = await withTaskGroup(of: (URL, ArtworkType, LibretroDBROMMetadata, Bool).self) { group in
            for (url, type, metadata) in urlTasks {
                group.addTask {
                    let isValid = await Self.validateURL(url)
                    return (url, type, metadata, isValid)
                }
            }

            var results: [(URL, ArtworkType, LibretroDBROMMetadata)] = []
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

        // Use exact filename without extension
        if let filename = rom.romFileName?.deletingPathExtension() {
            let urls = await LibretroArtwork.getValidURLs(systemName: systemName, gameName: filename)
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
