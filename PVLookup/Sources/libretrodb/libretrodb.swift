//
//  libretrodb.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/14/24.
//

import Foundation
import PVLogging
import SQLite
import PVSQLiteDatabase
import ROMMetadataProvider
import PVLookupTypes
import PVSystems

/* LibretroDB

Schema:

CREATE TABLE IF NOT EXISTS "developers" (
  id integer PRIMARY KEY,
  name text
);

CREATE TABLE IF NOT EXISTS "franchises" (
  id integer PRIMARY KEY,
  name text
);

CREATE TABLE IF NOT EXISTS "games" (
  id integer PRIMARY KEY,
  serial_id text,
  developer_id integer,
  publisher_id integer,
  rating_id integer,
  users integer,
  franchise_id integer,
  release_year integer,
  release_month integer,
  region_id integer,
  genre_id integer,
  display_name text,
  full_name text,
  platform_id integer
);

CREATE TABLE IF NOT EXISTS "genres" (
  id integer PRIMARY KEY,
  name text
);

CREATE TABLE IF NOT EXISTS "manufacturers" (
  id integer PRIMARY KEY,
  name text
);

CREATE TABLE IF NOT EXISTS "platforms" (
  id integer PRIMARY KEY,
  name text,
  manufacturer_id integer
);

CREATE TABLE IF NOT EXISTS "publishers" (
  id integer PRIMARY KEY,
  name text
);

CREATE TABLE IF NOT EXISTS "ratings" (
  id integer PRIMARY KEY,
  name text
);

CREATE TABLE IF NOT EXISTS "regions" (
  id integer PRIMARY KEY,
  name text
);

CREATE TABLE IF NOT EXISTS "roms" (
  id integer PRIMARY KEY,
  serial_id text,
  name text,
  md5 text
);

*/

@globalActor
public actor libretrodbActor: GlobalActor {
    public static let shared = libretrodbActor()
}

/// LibretroDB provides ROM metadata from a SQLite database converted from RetroArch's database
public final class libretrodb: ROMMetadataProvider, @unchecked Sendable {
    internal let db: PVSQLiteDatabase
    private let manager: LibretroDBManager

    private actor DatabaseConnection {
        private var connection: Connection?

        func execute(path: String, query: String) throws -> [LibretroDBROMMetadata] {
            if connection == nil {
                connection = try Connection(path, readonly: true)
            }
            guard let db = connection else {
                throw LibretroDBError.databaseError("Failed to create database connection")
            }

            let stmt = try db.prepare(query)
            var results: [LibretroDBROMMetadata] = []
            for row in stmt {
                var dict: [String: Any] = [:]
                for (index, name) in stmt.columnNames.enumerated() {
                    dict[name] = row[index]
                }

                // Convert to ROMMetadata
                if let metadata = convertToROMMetadata(dict) {
                    results.append(metadata)
                }
            }
            return results
        }

        private func convertToROMMetadata(_ dict: [String: Any]) -> LibretroDBROMMetadata? {
            guard let gameTitle = dict["game_title"] as? String else { return nil }

            return LibretroDBROMMetadata(
                gameTitle: gameTitle,
                fullName: dict["full_name"] as? String,
                releaseYear: dict["release_year"] as? Int,
                releaseMonth: dict["release_month"] as? Int,
                developer: dict["developer_name"] as? String,
                publisher: dict["publisher_name"] as? String,
                rating: dict["rating_name"] as? String,
                franchise: dict["franchise_name"] as? String,
                region: dict["region_name"] as? String,
                genre: dict["genre_name"] as? String,
                romName: dict["rom_name"] as? String,
                romMD5: dict["rom_md5"] as? String,
                platform: dict["platform_id"] as? String,
                manufacturer: dict["manufacturer_name"] as? String,
                genres: (dict["genres"] as? String)?.components(separatedBy: ","),
                romFileName: dict["rom_name"] as? String
            )
        }

        internal static func formatReleaseDate(year: Int?, month: Int?) -> String? {
            guard let year = year else { return nil }
            if let month = month {
                return String(format: "%04d-%02d", year, month)
            }
            return String(format: "%04d", year)
        }
    }

    private let dbConnection: DatabaseConnection

    public init() async throws {
        self.manager = LibretroDBManager.shared
        self.dbConnection = DatabaseConnection()

        do {
            try await manager.prepareDatabaseIfNeeded()
            self.db = try await PVSQLiteDatabase(withURL: manager.databasePath)
        } catch {
            throw LibretroDBError.databaseNotInitialized
        }
    }

    @libretrodbActor
    private func executeQuery(_ query: String) async throws -> [ROMMetadata] {
        let path = await manager.databasePath.path
        let libretroDB = try await dbConnection.execute(path: path, query: query)
        // Convert LibretroDBROMMetadata to ROMMetadata
        return libretroDB.map { convertToROMMetadata($0) }
    }

    /// Standard query to get ROM metadata by MD5
    private var standardMetadataQuery: String {
        """
        SELECT games.serial_id,
            games.platform_id,
            games.release_year,
            games.release_month,
            games.display_name,
            games.users,
            developers.name as developer_name,
            publishers.name as publisher_name,
            ratings.name as rating_name,
            franchises.name as franchise_name,
            regions.name as region_name,
            genres.name as genre_name,
            roms.name as rom_name,
            roms.md5 as rom_md5,
            platforms.name as platform_name,
            manufacturers.name as manufacturer_name
        FROM games
            LEFT JOIN developers ON games.developer_id = developers.id
            LEFT JOIN franchises ON games.franchise_id = franchises.id
            LEFT JOIN publishers ON games.publisher_id = publishers.id
            LEFT JOIN ratings ON games.rating_id = ratings.id
            LEFT JOIN genres ON games.genre_id = genres.id
            LEFT JOIN platforms ON games.platform_id = platforms.id
                LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            LEFT JOIN regions ON games.region_id = regions.id
            INNER JOIN roms ON games.serial_id = roms.serial_id
        """
    }

    /// Constants for artwork URL construction
    internal enum ArtworkConstants {
        static let baseURL = "http://thumbnails.libretro.com"
        static let boxartPath = "Named_Boxarts"
        static let titlesPath = "Named_Titles"
        static let snapshotPath = "Named_Snaps"
    }

    /// Constructs the artwork URL for a given metadata
    private func constructArtworkURL(platform: String, manufacturer: String?, displayName: String) -> String? {
        let platformPath: String
        if let manufacturer = manufacturer {
            platformPath = "\(manufacturer) - \(platform)"
        } else {
            platformPath = platform
        }

        // URL encode the components
        guard let encodedPlatform = platformPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedName = displayName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        return "\(ArtworkConstants.baseURL)/\(encodedPlatform)/\(ArtworkConstants.boxartPath)/\(encodedName).png"
    }

    /// Convert database result to ROMMetadata
    private func convertToROMMetadata(_ metadata: LibretroDBROMMetadata) -> ROMMetadata {
        let systemID = metadata.platform.flatMap { SystemIdentifier.fromLibretroDatabaseID(Int($0) ?? 0) } ?? .Unknown

        return ROMMetadata(
            gameTitle: metadata.gameTitle,
            boxImageURL: nil,
            region: metadata.region,
            gameDescription: nil,
            boxBackURL: nil,
            developer: metadata.developer,
            publisher: metadata.publisher,
            serial: nil,
            releaseDate: DatabaseConnection.formatReleaseDate(year: metadata.releaseYear, month: metadata.releaseMonth),
            genres: metadata.genres?.joined(separator: ","),
            referenceURL: nil,
            releaseID: nil,
            language: nil,
            regionID: nil,
            systemID: systemID,
            systemShortName: nil,
            romFileName: metadata.romFileName,
            romHashCRC: nil,
            romHashMD5: metadata.romMD5,
            romID: nil,
            source: "LibretroDB"
        )
    }

    // MARK: - ROMMetadataProvider Implementation

    public func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        if let results = try await searchByMD5(md5),
           let firstResult = results.first {
            return firstResult
        }
        return nil
    }

    public func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        DLOG("\nLibretroDB search details:")
        DLOG("- Input systemID: \(String(describing: systemID))")

        return try searchMetadata(usingFilename: filename, systemID: systemID)
    }
}

// MARK: - Query Methods
public extension libretrodb {
    /// Search by MD5 or other key
    internal func searchDatabase(usingKey key: String, value: String, systemID: SystemIdentifier?) throws -> [LibretroDBROMMetadata]? {
        if key == "romHashMD5" || key == "md5" {
            let results: [LibretroDBROMMetadata]? = try searchByMD5Internal(value.uppercased(), systemID: systemID)
            return results
        }
        // Handle other keys if needed
        return nil
    }

    /// Search by filename
    internal func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier?) throws -> [LibretroDBROMMetadata]? {
        var query = standardMetadataQuery
        let pattern = createSQLLikePattern(filename)

        query += " WHERE roms.name LIKE '\(pattern)' COLLATE NOCASE"

        if let systemID = systemID?.libretroDatabaseID {
            query += " AND platform_id = \(systemID)"
        }

        let results = try db.execute(query: query)
        return results.compactMap { dict in
            try? convertDictToMetadata(dict)
        }
    }

    /// Search by filename across multiple systems
    func searchDatabase(usingFilename filename: String, systemIDs: [SystemIdentifier]) throws -> [ROMMetadata]? {
        // Use the platform_ids directly since we're in libretrodb
        let platformIDs = systemIDs.map {
            $0.libretroDatabaseID
        }

        var query = standardMetadataQuery
        let escapedFilename = filename.replacingOccurrences(of: "'", with: "''")

        query += " WHERE roms.name LIKE '%\(escapedFilename)%' COLLATE NOCASE"

        if !platformIDs.isEmpty {
            let platformIDList = platformIDs.map(String.init).joined(separator: ",")
            query += " AND platform_id IN (\(platformIDList))"
        }

        let results = try db.execute(query: query)
        return results.compactMap { dict in
            guard let metadata = try? convertDictToMetadata(dict) else {
                return nil
            }
            return convertToROMMetadata(metadata)
        }
    }

    /// Get system ID for a ROM
    func systemIdentifier(forRomMD5 md5: String, or filename: String?, platformID: SystemIdentifier? = nil) async throws -> SystemIdentifier? {
        let platformID = platformID?.libretroDatabaseID

        // MD5 search with proper sanitization
        let sanitizedMD5 = sanitizeForSQLLike(md5.uppercased())
        let query = """
            SELECT platform_id
            FROM roms r
            JOIN games g ON r.serial_id = g.serial_id
            WHERE r.md5 = '\(sanitizedMD5)'
        """

        if let result = try db.execute(query: query).first,
           let platformId = result["platform_id"] as? Int {
            return SystemIdentifier.fromLibretroDatabaseID(platformId)
        }

        // Try filename with proper sanitization
        if let filename = filename {
            let pattern = createSQLLikePattern(filename)
            var query = """
                SELECT platform_id
                FROM roms r
                JOIN games g ON r.serial_id = g.serial_id
                WHERE r.name LIKE '\(pattern)' ESCAPE '\\'
            """

            if let platformID = platformID {
                query += " AND g.platform_id = \(platformID)"
            }

            query += " LIMIT 1"

            DLOG("LibretroDB filename search query: \(query)")

            if let result = try db.execute(query: query).first,
               let platformId = result["platform_id"] as? Int {
                return SystemIdentifier.fromLibretroDatabaseID(platformId)
            }
        }

        return nil
    }

    // MARK: - Private Helpers
    private func convertDictToMetadata(_ dict: [String: Any]) throws -> LibretroDBROMMetadata {
        guard let gameTitle = dict["game_title"] as? String else {
            throw LibretroDBError.invalidMetadata
        }

        // Convert platform_id to string safely
        let platformString: String?
        if let platformId = dict["platform_id"] as? Int {
            platformString = String(platformId)
        } else {
            platformString = nil
        }

        return LibretroDBROMMetadata(
            gameTitle: gameTitle,
            fullName: dict["full_name"] as? String,
            releaseYear: dict["release_year"] as? Int,
            releaseMonth: dict["release_month"] as? Int,
            developer: dict["developer_name"] as? String,
            publisher: dict["publisher_name"] as? String,
            rating: dict["rating_name"] as? String,
            franchise: dict["franchise_name"] as? String,
            region: dict["region_name"] as? String,
            genre: dict["genre_name"] as? String,
            romName: dict["rom_name"] as? String,
            romMD5: dict["rom_md5"] as? String,
            platform: platformString,
            manufacturer: dict["manufacturer_name"] as? String,
            genres: (dict["genres"] as? String)?.components(separatedBy: ","),
            romFileName: dict["rom_name"] as? String
        )
    }

    /// Query to get all ROM metadata for artwork mapping
    private var artworkMappingQuery: String {
        """
        SELECT DISTINCT
            roms.md5,
            roms.name as rom_name,
            games.display_name,
            platforms.name as platform_name,
            manufacturers.name as manufacturer_name,
            games.platform_id
        FROM roms
        INNER JOIN games ON games.serial_id = roms.serial_id
        LEFT JOIN platforms ON games.platform_id = platforms.id
        LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
        WHERE roms.md5 IS NOT NULL
        """
    }

    /// Constants for artwork cache
    internal enum ArtworkCacheConstants {
        static let cacheFileName = "libretrodb_artwork_cache.json"

        static var cacheURL: URL {
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            return cacheDir.appendingPathComponent(cacheFileName)
        }
    }

    /// Cache structure for artwork mappings
    internal struct ArtworkCache: Codable {
        let romMD5: [String: [String: String]]
        let romFileNameToMD5: [String: String]
        let timestamp: Date

        var asArtworkMapping: ArtworkMapping {
            return ArtworkMappings(romMD5: romMD5, romFileNameToMD5: romFileNameToMD5)
        }
    }

    /// Get artwork mappings for all ROMs in the database
    func getArtworkMappings() throws -> ArtworkMapping {
        // Try to load from cache first
        if let cached = try? loadArtworkCache(), !isCacheStale(cached) {
            return cached.asArtworkMapping
        }

        // Generate new mappings
        let mappings = try generateArtworkMappings()

        // Save to cache
        try? saveArtworkCache(mappings)

        return mappings
    }

    /// Generate fresh artwork mappings from the database
    private func generateArtworkMappings() throws -> ArtworkMapping {
        let results: [[String: Any]] = try db.execute(query: artworkMappingQuery)
        var romMD5: [String: [String: String]] = [:]
        var romFileNameToMD5: [String: String] = [:]

        for result in results {
            guard let md5 = result["md5"] as? String,
                  let displayName = result["display_name"] as? String,
                  let platform = result["platform_name"] as? String else {
                continue
            }

            let manufacturer = result["manufacturer_name"] as? String

            // Construct artwork URL
            if let artworkURL = constructArtworkURL(
                platform: platform,
                manufacturer: manufacturer,
                displayName: displayName
            ) {
                // Create metadata dictionary
                var metadata: [String: String] = [
                    "gameTitle": displayName,
                    "boxImageURL": artworkURL
                ]

                // Add optional fields if available
                if let platformID = result["platform_id"] as? Int {
                    metadata["systemID"] = String(platformID)
                }
                if let romName = result["rom_name"] as? String {
                    metadata["romFileName"] = romName
                    // Map filename to MD5
                    romFileNameToMD5[romName] = md5
                }

                // Store in romMD5 mapping
                romMD5[md5] = metadata

                // If we have a platform ID, create a platform-specific mapping
                if let platformID = result["platform_id"] as? Int {
                    let key = "\(platformID):\(displayName)"
                    romFileNameToMD5[key] = md5
                }
            }
        }

        return ArtworkMappings(romMD5: romMD5, romFileNameToMD5: romFileNameToMD5)
    }

    /// Save artwork mappings to cache file
    private func saveArtworkCache(_ mappings: ArtworkMapping) throws {
        let cache = ArtworkCache(
            romMD5: mappings.romMD5,
            romFileNameToMD5: mappings.romFileNameToMD5,
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(cache)
        try data.write(to: ArtworkCacheConstants.cacheURL)
    }

    /// Load artwork mappings from cache file
    private func loadArtworkCache() throws -> ArtworkCache? {
        let data = try Data(contentsOf: ArtworkCacheConstants.cacheURL)
        let decoder = JSONDecoder()
        return try decoder.decode(ArtworkCache.self, from: data)
    }

    /// Check if cache is stale (older than 24 hours)
    private func isCacheStale(_ cache: ArtworkCache) -> Bool {
        let staleInterval: TimeInterval = 24 * 60 * 60 // 24 hours
        return Date().timeIntervalSince(cache.timestamp) > staleInterval
    }

    /// Gets artwork URLs for a ROM by searching the libretro database and constructing thumbnail URLs
    /// - Parameter rom: ROM metadata to search with
    /// - Returns: Array of valid artwork URLs from libretro thumbnails
    func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        let libretroDatabaseName = rom.systemID.libretroDatabaseName
        guard !libretroDatabaseName.isEmpty else {
            return nil
        }

        var libretroDatabaseUrls: [URL] = []

        // Try MD5 search first if available
        if let md5 = rom.romHashMD5?.uppercased() {
            let results: [LibretroDBROMMetadata]? = try searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)
            if let results = results {
                // Try with full_name first
                if let firstResult = results.first,
                   let fullName = firstResult.fullName {
                    let urls = await LibretroArtwork.getValidURLs(
                        systemName: libretroDatabaseName,
                        gameName: fullName
                    )
                    libretroDatabaseUrls.append(contentsOf: urls)
                }

                // If no results with full_name, try with display_name (gameTitle)
                if libretroDatabaseUrls.isEmpty, let firstResult = results.first {
                    let urls = await LibretroArtwork.getValidURLs(
                        systemName: libretroDatabaseName,
                        gameName: firstResult.gameTitle
                    )
                    libretroDatabaseUrls.append(contentsOf: urls)
                }
            }
        }

        // If MD5 search found no results and we have a filename, try filename search
        if libretroDatabaseUrls.isEmpty, let filename = rom.romFileName {
            let results: [LibretroDBROMMetadata]? = try searchDatabase(usingFilename: filename, systemID: nil)
            if let results = results {
                // Try with full_name first
                if let firstResult = results.first,
                   let fullName = firstResult.fullName {
                    let urls = await LibretroArtwork.getValidURLs(
                        systemName: libretroDatabaseName,
                        gameName: fullName
                    )
                    libretroDatabaseUrls.append(contentsOf: urls)
                }

                // If no results with full_name, try with display_name (gameTitle)
                if libretroDatabaseUrls.isEmpty, let firstResult = results.first {
                    let urls = await LibretroArtwork.getValidURLs(
                        systemName: libretroDatabaseName,
                        gameName: firstResult.gameTitle
                    )
                    libretroDatabaseUrls.append(contentsOf: urls)
                }
            }
        }

        return libretroDatabaseUrls.isEmpty ? nil : libretroDatabaseUrls
    }

    /// Search by MD5 or other key
    func searchMetadata(usingKey key: String, value: String, systemID: SystemIdentifier?) throws -> [ROMMetadata]? {
        DLOG("\nLibretroDB metadata search:")
        DLOG("- Key: \(key)")
        DLOG("- Value: \(value)")
        DLOG("- SystemID: \(String(describing: systemID))")

        // Map the external key names to database column names
        let dbColumn = switch key {
            case "romHashMD5": "roms.md5"
            default: key
        }

        let query = """
            SELECT DISTINCT
                games.display_name as game_title,
                games.full_name,
                games.release_year,
                games.release_month,
                developers.name as developer_name,
                publishers.name as publisher_name,
                ratings.name as rating_name,
                franchises.name as franchise_name,
                regions.name as region_name,
                genres.name as genre_name,
                roms.name as rom_name,
                roms.md5 as rom_md5,
                platforms.id as platform_id,
                manufacturers.name as manufacturer_name,
                GROUP_CONCAT(genres.name) as genres
            FROM games
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN roms ON games.serial_id = roms.serial_id
            LEFT JOIN developers ON games.developer_id = developers.id
            LEFT JOIN publishers ON games.publisher_id = publishers.id
            LEFT JOIN ratings ON games.rating_id = ratings.id
            LEFT JOIN franchises ON games.franchise_id = franchises.id
            LEFT JOIN regions ON games.region_id = regions.id
            LEFT JOIN genres ON games.genre_id = genres.id
            LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            WHERE \(dbColumn) = '\(value.uppercased())'
            \(systemID != nil ? "AND games.platform_id = \(systemID!.libretroDatabaseID)" : "")
            GROUP BY games.id
            """

        DLOG("- Generated query: \(query)")
        let results = try db.execute(query: query)
        DLOG("- Raw results: \(results)")

        let metadata = results.compactMap { dict in
            try? convertDictToMetadata(dict)
        }
        DLOG("- Converted metadata: \(metadata)")

        return metadata.isEmpty ? nil : metadata.map(convertToROMMetadata)
    }

    /// Search by filename
    func searchMetadata(usingFilename filename: String, systemID: SystemIdentifier?) throws -> [ROMMetadata]? {
        let systemID = systemID?.libretroDatabaseID

        DLOG("\nLibretroDB search details:")
        DLOG("- Input filename: \(filename)")
        DLOG("- Input systemID: \(String(describing: systemID))")

        let query = """
            SELECT DISTINCT
                games.display_name as game_title,
                games.full_name,
                games.release_year,
                games.release_month,
                developers.name as developer_name,
                publishers.name as publisher_name,
                ratings.name as rating_name,
                franchises.name as franchise_name,
                regions.name as region_name,
                genres.name as genre_name,
                roms.name as rom_name,
                roms.md5 as rom_md5,
                platforms.id as platform_id,
                manufacturers.name as manufacturer_name,
                GROUP_CONCAT(genres.name) as genres
            FROM games
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN roms ON games.serial_id = roms.serial_id
            LEFT JOIN developers ON games.developer_id = developers.id
            LEFT JOIN publishers ON games.publisher_id = publishers.id
            LEFT JOIN ratings ON games.rating_id = ratings.id
            LEFT JOIN franchises ON games.franchise_id = franchises.id
            LEFT JOIN regions ON games.region_id = regions.id
            LEFT JOIN genres ON games.genre_id = genres.id
            LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            WHERE roms.name LIKE '%\(filename)%'
            \(systemID != nil ? "AND games.platform_id = \(systemID!)" : "")
            GROUP BY games.id
            """
        DLOG("- Generated SQL query: \(query)")

        let results = try db.execute(query: query)
        let metadata = results.compactMap { dict in
            try? convertDictToMetadata(dict)
        }

        DLOG("- Found \(metadata.count) results:")
        metadata.forEach { result in
            DLOG("  • Title: \(result.gameTitle)")
            DLOG("    System: \(result.platform ?? "nil")")
            DLOG("    MD5: \(result.romMD5 ?? "nil")")
            DLOG("    Filename: \(result.romFileName ?? "nil")")
        }

        return metadata.isEmpty ? nil : metadata.map(convertToROMMetadata)
    }

    /// Search directly by MD5 hash with optional system filter
    func searchByMD5(_ md5: String, systemID: SystemIdentifier? = nil) async throws -> [ROMMetadata]? {
        guard let results = try searchByMD5Internal(md5, systemID: systemID) else {
            return nil
        }
        // Explicitly convert each LibretroDBROMMetadata to ROMMetadata
        let romMetadata: [ROMMetadata] = results.map { libretroMetadata in
            convertToROMMetadata(libretroMetadata)
        }
        return romMetadata
    }

    /// Internal implementation of MD5 search that returns LibretroDBROMMetadata
    private func searchByMD5Internal(_ md5: String, systemID: SystemIdentifier? = nil) throws -> [LibretroDBROMMetadata]? {
        DLOG("\nLibretroDB MD5 search:")
        DLOG("- MD5: \(md5)")
        DLOG("- SystemID: \(String(describing: systemID))")

        let query = """
            SELECT DISTINCT
                games.display_name as game_title,
                games.full_name,
                games.release_year,
                games.release_month,
                developers.name as developer_name,
                publishers.name as publisher_name,
                ratings.name as rating_name,
                franchises.name as franchise_name,
                regions.name as region_name,
                genres.name as genre_name,
                roms.name as rom_name,
                roms.md5 as rom_md5,
                platforms.id as platform_id,
                manufacturers.name as manufacturer_name,
                GROUP_CONCAT(genres.name) as genres
            FROM games
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN roms ON games.serial_id = roms.serial_id
            LEFT JOIN developers ON games.developer_id = developers.id
            LEFT JOIN publishers ON games.publisher_id = publishers.id
            LEFT JOIN ratings ON games.rating_id = ratings.id
            LEFT JOIN franchises ON games.franchise_id = franchises.id
            LEFT JOIN regions ON games.region_id = regions.id
            LEFT JOIN genres ON games.genre_id = genres.id
            LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            WHERE roms.md5 = '\(md5.uppercased())'
            \(systemID != nil ? "AND games.platform_id = \(systemID!.libretroDatabaseID)" : "")
            GROUP BY games.id
            """

        DLOG("- Generated query: \(query)")
        let results = try db.execute(query: query)
        DLOG("- Raw results: \(results)")

        let metadata: [LibretroDBROMMetadata] = results.compactMap { dict in
            try? convertDictToMetadata(dict)
        }
        DLOG("- Converted metadata: \(metadata)")

        return metadata.isEmpty ? nil : metadata
    }
}

extension libretrodb {
    /// Search for artwork by game name and system
    public func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        let types = artworkTypes ?? .defaults

        // Get all matching games in one query
        let metadata = try await searchGamesForArtwork(name: name, systemID: systemID)

        guard !metadata.isEmpty else {
            DLOG("Query returned no results")
            return nil
        }

        // Batch URL validation
        let urlTasks = metadata.flatMap { game -> [(URL, ArtworkType, ROMMetadata)] in
            let gameName = game.romFileName ?? game.gameTitle
            let systemID = game.systemID

            #if DEBUG
            DLOG("\nConstructing URLs for game:")
            DLOG("- Game Title: \(game.gameTitle)")
            DLOG("- ROM Name: \(game.romFileName ?? "nil")")
            DLOG("- System ID: \(systemID)")
            DLOG("- System Name: \(systemID.libretroDatabaseName)")
            #endif

            guard let systemFolder = systemID.libretroDatabaseName
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return []
            }

            var tasks: [(URL, ArtworkType, ROMMetadata)] = []

            // For each supported type, try to construct a URL
            if types.contains(.boxFront) {
                if let url = LibretroArtwork.constructURL(systemName: systemFolder, gameName: gameName, type: .boxFront) {
                    #if DEBUG
                    DLOG("- Boxart URL: \(url)")
                    #endif
                    tasks.append((url, .boxFront, game))
                }
            }
            if types.contains(.screenshot) {
                if let url = LibretroArtwork.constructURL(systemName: systemFolder, gameName: gameName, type: .screenshot) {
                    #if DEBUG
                    DLOG("- Screenshot URL: \(url)")
                    #endif
                    tasks.append((url, .screenshot, game))
                }
            }
            if types.contains(.titleScreen) {
                if let url = LibretroArtwork.constructURL(systemName: systemFolder, gameName: gameName, type: .titleScreen) {
                    #if DEBUG
                    DLOG("- Titlescreen URL: \(url)")
                    #endif
                    tasks.append((url, .titleScreen, game))
                }
            }

            return tasks
        }

        // Validate URLs in parallel
        let validResults = await withTaskGroup(of: (URL, ArtworkType, ROMMetadata, Bool).self) { group in
            for (url, type, metadata) in urlTasks {
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
        let artworks = validResults.map { url, type, metadata in
            ArtworkMetadata(
                url: url,
                type: type,
                resolution: nil,
                description: metadata.gameTitle,
                source: "LibretroDB",
                systemID: metadata.systemID
            )
        }

        return artworks.isEmpty ? nil : artworks
    }

    private func constructArtworkSearchQuery(name: String, systemID: SystemIdentifier?) -> String {
        let escapedName = name.replacingOccurrences(of: "'", with: "''")
        let platformFilter = systemID != nil ? "AND games.platform_id = \(systemID!.libretroDatabaseID)" : ""

        return """
            WITH matched_games AS (
                SELECT DISTINCT games.id, games.serial_id,
                       CASE
                           WHEN games.display_name = '\(escapedName)' THEN 0  -- Exact match
                           WHEN games.display_name LIKE '\(escapedName) %' THEN 1  -- Starts with name
                           WHEN games.display_name LIKE '% \(escapedName) %' THEN 2  -- Contains word
                           WHEN games.display_name LIKE '%\(escapedName)%' THEN 3  -- Contains substring
                           WHEN games.display_name LIKE '%\(escapedName)% (Aftermarket)%' THEN 4  -- Aftermarket version
                           WHEN games.display_name LIKE '%\(escapedName)% (Beta)%' THEN 5  -- Beta version
                           ELSE 6
                       END as match_quality
                FROM games
                WHERE games.display_name LIKE '%\(escapedName)%'
                \(platformFilter)
                ORDER BY match_quality, games.display_name
                LIMIT 10
            )
            SELECT DISTINCT
                games.display_name as game_title,
                games.full_name,
                roms.name as rom_name,
                platforms.id as platform_id,
                platforms.name as platform_name,
                manufacturers.name as manufacturer_name,
                developers.name as developer_name,
                publishers.name as publisher_name,
                regions.name as region_name,
                games.platform_id as raw_platform_id  -- Add this for debugging
            FROM matched_games
            JOIN games ON matched_games.id = games.id
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            LEFT JOIN roms ON games.serial_id = roms.serial_id
            LEFT JOIN developers ON games.developer_id = developers.id
            LEFT JOIN publishers ON games.publisher_id = publishers.id
            LEFT JOIN regions ON games.region_id = regions.id
            ORDER BY matched_games.match_quality, games.display_name
            """
    }

    /// Get artwork for a specific game ID
    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        // In LibretroDB, we can search by game name since we don't use IDs
        return try await searchArtwork(
            byGameName: gameID,
            systemID: nil,
            artworkTypes: artworkTypes
        )
    }

    /// Optimized batch search for games
    func searchGames(name: String, systemID: SystemIdentifier? = nil, limit: Int = 10) throws -> [LibretroDBROMMetadata] {
        // Single optimized query that gets all data at once, including ROM data
        let query = """
            WITH matched_games AS (
                SELECT DISTINCT games.id, games.serial_id
                FROM games
                WHERE games.display_name LIKE '%\(name)%'
                \(systemID != nil ? "AND games.platform_id = \(systemID!.libretroDatabaseID)" : "")
                LIMIT \(limit)
            ),
            game_roms AS (
                SELECT DISTINCT r.*
                FROM matched_games mg
                JOIN roms r ON r.serial_id = mg.serial_id
            )
            SELECT DISTINCT
                games.display_name as game_title,
                games.full_name,
                games.release_year,
                games.release_month,
                developers.name as developer_name,
                publishers.name as publisher_name,
                ratings.name as rating_name,
                franchises.name as franchise_name,
                regions.name as region_name,
                genres.name as genre_name,
                game_roms.name as rom_name,
                game_roms.md5 as rom_md5,
                platforms.id as platform_id,
                manufacturers.name as manufacturer_name,
                GROUP_CONCAT(genres.name) as genres
            FROM matched_games
            JOIN games ON matched_games.id = games.id
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN game_roms ON games.serial_id = game_roms.serial_id
            LEFT JOIN developers ON games.developer_id = developers.id
            LEFT JOIN publishers ON games.publisher_id = publishers.id
            LEFT JOIN ratings ON games.rating_id = ratings.id
            LEFT JOIN franchises ON games.franchise_id = franchises.id
            LEFT JOIN regions ON games.region_id = regions.id
            LEFT JOIN genres ON games.genre_id = genres.id
            LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            GROUP BY games.id, game_roms.id
        """

        let results = try db.execute(query: query)
        return try results.compactMap { dict in
            try convertDictToMetadata(dict)
        }
    }

    /// Search for games with artwork-specific data
    /// - Parameters:
    ///   - name: Game name to search for
    ///   - systemID: Optional system to filter by
    /// - Returns: Array of ROM metadata optimized for artwork lookup
    internal func searchGamesForArtwork(name: String, systemID: SystemIdentifier? = nil) async throws -> [ROMMetadata] {
        DLOG("\nLibretroDB artwork search:")
        DLOG("- Name: \(name)")
        DLOG("- SystemID: \(String(describing: systemID))")
        if let systemID = systemID {
            DLOG("- LibretroDB Platform ID: \(systemID.libretroDatabaseID)")
        }

        // Clean the name and escape SQL including parentheses
        let sanitizedName = sanitizeForSQLLike(name)
        let platformFilter = systemID?.libretroDatabaseID != nil ?
            "AND games.platform_id = \(systemID!.libretroDatabaseID)" : ""

        // Optimize the search query to find more relevant matches
        let query = """
            WITH matched_games AS (
                SELECT DISTINCT games.id, games.serial_id,
                       CASE
                           WHEN LOWER(games.display_name) = LOWER('\(sanitizedName)') THEN 0  -- Exact match
                           WHEN LOWER(games.display_name) LIKE LOWER('\(sanitizedName) %') THEN 1  -- Starts with name
                           WHEN LOWER(games.display_name) LIKE LOWER('% \(sanitizedName) %') THEN 2  -- Contains word
                           WHEN LOWER(games.display_name) LIKE LOWER('%\(sanitizedName)%') THEN 3  -- Contains substring
                           ELSE 4
                       END as match_quality
                FROM games
                WHERE LOWER(games.display_name) LIKE LOWER('%\(sanitizedName)%')
                \(platformFilter)
                ORDER BY match_quality, games.display_name
                LIMIT 10
            )
            SELECT DISTINCT
                games.display_name as game_title,
                games.full_name,
                roms.name as rom_name,
                platforms.id as platform_id,
                platforms.name as platform_name,
                manufacturers.name as manufacturer_name,
                developers.name as developer_name,
                publishers.name as publisher_name,
                regions.name as region_name,
                games.platform_id as raw_platform_id
            FROM matched_games
            JOIN games ON matched_games.id = games.id
            LEFT JOIN platforms ON games.platform_id = platforms.id
            LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
            LEFT JOIN roms ON games.serial_id = roms.serial_id
            LEFT JOIN developers ON games.developer_id = developers.id
            LEFT JOIN publishers ON games.publisher_id = publishers.id
            LEFT JOIN regions ON games.region_id = regions.id
            ORDER BY matched_games.match_quality, games.display_name
            """

        DLOG("- Generated query: \(query)")
        let rawResults = try db.execute(query: query)
        DLOG("- Raw results count: \(rawResults.count)")

        if rawResults.isEmpty {
            DLOG("- No results found!")
            // Debug platform mapping
            DLOG("- Platform mapping check:")
            DLOG("  • SystemID: \(systemID?.rawValue ?? "nil")")
            DLOG("  • LibretroDB ID: \(systemID?.libretroDatabaseID ?? -1)")
            return []
        } else {
            DLOG("- Found results:")
            rawResults.forEach { result in
                DLOG("  • Game: \(result["game_title"] as? String ?? "nil")")
                DLOG("    Platform ID: \(result["raw_platform_id"] as? Int ?? -1)")
                DLOG("    Platform Name: \(result["platform_name"] as? String ?? "nil")")
            }
        }

        // Convert raw results to ROMMetadata
        return rawResults.compactMap { result in
            guard let gameTitle = result["game_title"] as? String,
                  let platformId = result["platform_id"] as? Int,
                  let systemID = SystemIdentifier.fromLibretroDatabaseID(platformId) else {
                return nil
            }

            return ROMMetadata(
                gameTitle: gameTitle,
                region: result["region_name"] as? String,
                gameDescription: nil,
                developer: result["developer_name"] as? String,
                publisher: result["publisher_name"] as? String,
                systemID: systemID,
                romFileName: result["rom_name"] as? String,
                source: "LibretroDB"
            )
        }
    }
}
