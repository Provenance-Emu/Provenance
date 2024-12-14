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
public final class libretrodb {

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

        return ROMMetadata(
            gameTitle: metadata.gameTitle,
            boxImageURL: artworkURL,  // Now using the constructed URL
            region: metadata.region,
            gameDescription: nil,
            boxBackURL: nil,  // Could potentially construct a back box URL if needed
            developer: metadata.developer,
            publisher: metadata.publisher,
            serial: nil,
            releaseDate: metadata.releaseYear.map { "\($0)" },
            genres: metadata.genre,
            referenceURL: nil,
            releaseID: nil,
            language: nil,
            regionID: nil,
            systemID: 0,
            systemShortName: metadata.platform,
            romFileName: metadata.romName,
            romHashCRC: nil,
            romHashMD5: metadata.romMD5,
            romID: nil
        )
    }
}

// MARK: - Query Methods
public extension libretrodb {
    /// Search by MD5 or other key
    func searchDatabase(usingKey key: String, value: String, systemID: Int?) throws -> [ROMMetadata]? {
        var query = standardMetadataQuery

        switch key {
        case "romHashMD5":
            query += " WHERE roms.md5 = '\(value)' COLLATE NOCASE"
        case "romHashCRC":
            return nil // Not supported in libretrodb
        default:
            return nil
        }

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
        var query = standardMetadataQuery
        let escapedFilename = filename.replacingOccurrences(of: "'", with: "''")

        query += " WHERE roms.name LIKE '%\(escapedFilename)%' COLLATE NOCASE"

        if !systemIDs.isEmpty {
            let systemIDList = systemIDs.map(String.init).joined(separator: ",")
            query += " AND platform_id IN (\(systemIDList))"
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
    func system(forRomMD5 md5: String, or filename: String?) throws -> Int? {
        var query = "SELECT DISTINCT platform_id FROM games"
        query += " INNER JOIN roms ON games.serial_id = roms.serial_id"
        query += " WHERE roms.md5 = '\(md5)' COLLATE NOCASE"

        if let filename = filename {
            let escapedFilename = filename.replacingOccurrences(of: "'", with: "''")
            query += " OR roms.name LIKE '%\(escapedFilename)%' COLLATE NOCASE"
        }

        let results = try db.execute(query: query)
        guard let match = results.first,
              let platformID = match["platform_id"] as? Int else {
            return nil
        }

        return platformID
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
}
