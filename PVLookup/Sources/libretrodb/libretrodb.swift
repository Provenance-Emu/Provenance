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
import Systems

@globalActor
public actor libretrodbActor: GlobalActor {
    public static let shared = libretrodbActor()
}

/// Internal representation of ROM metadata from the libretrodb database
internal struct LibretroDBROMMetadata: Codable {
    let gameTitle: String
    let releaseYear: Int?
    let releaseMonth: Int?
    let developer: String?
    let publisher: String?
    let rating: String?
    let franchise: String?
    let region: String?
    let genre: String?
    let romName: String?
    let romMD5: String?
    let platform: String?
    let manufacturer: String?
}

/// LibretroDB provides ROM metadata from a SQLite database converted from RetroArch's database
public final class libretrodb: ROMMetadataProvider, @unchecked Sendable {

    /// Legacy connection
    private let db: PVSQLiteDatabase

    /// SQLite.swift connection for more modern queries
    lazy var sqldb: Connection = {
        let sqldb = try! Connection(dbPath.path, readonly: true)
        return sqldb
    }()

    /// Path to the database file
    lazy var dbPath: URL = {
        let bundle = Bundle.module
        guard let sqlFile = bundle.url(forResource: "libretrodb", withExtension: "sqlite") else {
            fatalError("Unable to locate `libretrodb.sqlite`")
        }
        return sqlFile
    }()

    public init() {
        do {
            let url = Bundle.module.url(forResource: "libretrodb", withExtension: "sqlite")!
            self.db = try PVSQLiteDatabase(withURL: url)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }

    /// Standard query to get ROM metadata by MD5
    private var standardMetadataQuery: String {
        """
        SELECT games.serial_id,
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
    private enum ArtworkConstants {
        static let baseURL = "http://thumbnails.libretro.com"
        static let boxartPath = "Named_Boxarts"

        // Map manufacturer IDs to names
        static let manufacturers: [Int: String] = [
            1: "SNK",
            2: "Sega",
            3: "NEC",
            8: "Nintendo",
            5: "Sony",
            // ... add other manufacturers
        ]

        // Map platform IDs to names
        static let platforms: [Int: String] = [
            75: "Game Boy",
            115: "Game Boy Advance",
            28: "Nintendo Entertainment System",
            37: "Super Nintendo Entertainment System",
            15: "Mega Drive",
            108: "PC Engine",
            // ... add other platforms
        ]
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
        // Construct artwork URL if we have the necessary information
        let artworkURL: String?
        if let platform = metadata.platform {
            artworkURL = constructArtworkURL(
                platform: platform,
                manufacturer: metadata.manufacturer,
                displayName: metadata.gameTitle
            )
        } else {
            artworkURL = nil
        }

        // Convert platform ID to SystemIdentifier
        let systemIdentifier = metadata.platform.flatMap { platformName in
            SystemIdentifier.fromLibretroDatabaseID(Int(platformName) ?? 0)
        } ?? .Unknown

        return ROMMetadata(
            gameTitle: metadata.gameTitle,
            boxImageURL: artworkURL,
            region: metadata.region,
            gameDescription: nil,
            boxBackURL: nil,
            developer: metadata.developer,
            publisher: metadata.publisher,
            serial: nil,
            releaseDate: metadata.releaseYear.map { "\($0)" },
            genres: metadata.genre,
            referenceURL: nil,
            releaseID: nil,
            language: nil,
            regionID: nil,
            systemID: systemIdentifier,
            systemShortName: metadata.platform,
            romFileName: metadata.romName,
            romHashCRC: nil,
            romHashMD5: metadata.romMD5,
            romID: nil
        )
    }

    // MARK: - ROMMetadataProvider Implementation

    public func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        let results = try searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)
        return results?.first
    }

    public func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]? {
        var query = standardMetadataQuery
        let escapedFilename = filename.replacingOccurrences(of: "'", with: "''")

        query += " WHERE roms.name LIKE '%\(escapedFilename)%' COLLATE NOCASE"

        if let systemID = systemID {
            query += " AND platform_id = \(systemID)"
        }

        let results = try db.execute(query: query)
        return results.compactMap { dict in
            guard let metadata = try? convertDictToMetadata(dict) else {
                return nil
            }
            return convertToROMMetadata(metadata)
        }
    }

    @available(*, deprecated, message: "Use systemIdentifier(forRomMD5:or:) instead")
    public func system(forRomMD5 md5: String, or filename: String?) async throws -> Int? {
        if let identifier = try await systemIdentifier(forRomMD5: md5, or: filename) {
            return identifier.openVGDBID
        }
        return nil
    }
}

// MARK: - Query Methods
public extension libretrodb {
    /// Search by MD5 or other key
    func searchDatabase(usingKey key: String, value: String, systemID: Int?) throws -> [ROMMetadata]? {
        // Convert OpenVGDB system ID to libretrodb platform ID
        let platformID = systemID.flatMap { SystemIDMapping.convertToLibretroID($0) }

        var query = standardMetadataQuery

        switch key {
        case "romHashMD5":
            // Normalize MD5 to uppercase
            let normalizedMD5 = value.uppercased()
            query += " WHERE roms.md5 = '\(normalizedMD5)' COLLATE NOCASE"
        case "romHashCRC":
            return nil // Not supported in libretrodb
        default:
            return nil
        }

        if let platformID = platformID {
            query += " AND platform_id = \(platformID)"
        }

        let results = try db.execute(query: query)
        return results.compactMap { dict in
            guard let metadata = try? convertDictToMetadata(dict) else {
                return nil
            }
            return convertToROMMetadata(metadata)
        }
    }

    /// Search by filename
    func searchDatabase(usingFilename filename: String, systemID: Int?) throws -> [ROMMetadata]? {
        var query = standardMetadataQuery
        let escapedFilename = filename.replacingOccurrences(of: "'", with: "''")

        query += " WHERE roms.name LIKE '%\(escapedFilename)%' COLLATE NOCASE"

        if let systemID = systemID {
            query += " AND platform_id = \(systemID)"
        }

        let results = try db.execute(query: query)
        return results.compactMap { dict in
            guard let metadata = try? convertDictToMetadata(dict) else {
                return nil
            }
            return convertToROMMetadata(metadata)
        }
    }

    /// Search by filename across multiple systems
    func searchDatabase(usingFilename filename: String, systemIDs: [Int]) throws -> [ROMMetadata]? {
        // Convert OpenVGDB system IDs to libretrodb platform IDs
        let platformIDs = SystemIDMapping.convertToLibretroIDs(systemIDs)

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
    func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier? {
        // Use existing query but return SystemIdentifier directly
        let query = """
            SELECT platform_id FROM rom r
            JOIN game g ON r.game_id = g.game_id
            WHERE r.md5 = '\(md5.uppercased())'
        """

        if let result = try db.execute(query: query).first,
           let platformId = result["platform_id"] as? Int {
            return SystemIdentifier.fromLibretroDatabaseID(platformId)
        }

        // Try filename if MD5 fails
        if let filename = filename {
            let query = """
                SELECT platform_id FROM rom r
                JOIN game g ON r.game_id = g.game_id
                WHERE r.file_name LIKE '%\(filename)%'
            """
            if let result = try db.execute(query: query).first,
               let platformId = result["platform_id"] as? Int {
                return SystemIdentifier.fromLibretroDatabaseID(platformId)
            }
        }

        return nil
    }

    // MARK: - Private Helpers
    private func convertDictToMetadata(_ dict: [String: Any]) throws -> LibretroDBROMMetadata {
        return LibretroDBROMMetadata(
            gameTitle: (dict["display_name"] as? String) ?? "",
            releaseYear: (dict["release_year"] as? Int),
            releaseMonth: (dict["release_month"] as? Int),
            developer: dict["developer_name"] as? String,
            publisher: dict["publisher_name"] as? String,
            rating: dict["rating_name"] as? String,
            franchise: dict["franchise_name"] as? String,
            region: dict["region_name"] as? String,
            genre: dict["genre_name"] as? String,
            romName: dict["rom_name"] as? String,
            romMD5: dict["rom_md5"] as? String,
            platform: dict["platform_name"] as? String,
            manufacturer: dict["manufacturer_name"] as? String
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
        let results = try db.execute(query: artworkMappingQuery)
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
}
