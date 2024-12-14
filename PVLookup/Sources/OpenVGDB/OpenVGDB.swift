//
//  Database_OpenVGDB.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/27/24.
//

import Foundation
import PVLogging
import SQLite
import PVSQLiteDatabase

@globalActor
public
actor OpenVGDBActor:GlobalActor
{
    public static
    let shared:OpenVGDBActor = .init()

    init()
    {
    }
}

public final class OpenVGDB {

    #warning("TODO: Convert to SQLSwift")
    /// Legacy connection
    private let vgdb: PVSQLiteDatabase

    /// SQLSwift connection
    lazy var sqldb: Connection = {
        let sqldb = try! Connection(openvgdbPath.path, readonly: true)
        return sqldb
    }()

    lazy var openvgdbPath: URL = {
        let bundle = Bundle.module
        guard let sqlFile = bundle.url(forResource: "openvgdb", withExtension: "sqlite") else {
            fatalError("Unable to locate `openvgdb.sqlite`")
        }
        return sqlFile
    }()

    public required init(database: PVSQLiteDatabase? = nil) {
        if let database = database {
            if database.url.lastPathComponent != "openvgdb.sqlite" {
                fatalError("Database must be named 'openvgdb.sqlite'")
            }

            vgdb = database
        } else {
            let url = Bundle.module.url(forResource: "openvgdb", withExtension: "sqlite")!
            do {
                let database = try PVSQLiteDatabase(withURL: url)
                self.vgdb = database
            } catch {
                fatalError("Failed to open database at \(url): \(error)")
            }
        }
    }
}

// MARK: - Artwork Queries
public extension OpenVGDB {
    typealias ArtworkMapping = (romMD5: [String:[String: AnyObject]], romFileNameToMD5: [String:String])

    func getArtworkMappings() throws -> ArtworkMapping {
        let results = try self.getAllReleases()
        var romMD5:[String:[String: AnyObject]] = [:]
        var romFileNameToMD5:[String:String] = [:]
        for res in results {
            if let md5 = res["romHashMD5"] as? String, !md5.isEmpty {
                let md5 : String = md5.uppercased()
                romMD5[md5] = res
                if let systemID = res["systemID"] as? Int {
                    if let filename = res["romFileName"] as? String, !filename.isEmpty {
                        let key : String = String(systemID) + ":" + filename
                        romFileNameToMD5[key]=md5
                        romFileNameToMD5[filename]=md5
                    }
                    let key : String = String(systemID) + ":" + md5
                    romFileNameToMD5[key]=md5
                }
                if let crc = res["romHashCRC"] as? String, !crc.isEmpty {
                    romFileNameToMD5[crc]=md5
                }
            }
        }
        return (romMD5, romFileNameToMD5)
    }

    package func getAllReleases() throws -> SQLQueryResponse {
        let queryString = """
            SELECT
                release.regionLocalizedID as 'regionID',
                release.releaseCoverBack as 'boxBackURL',
                release.releaseCoverFront as 'boxImageURL',
                release.releaseDate as 'releaseDate',
                release.releaseDescription as 'gameDescription',
                release.releaseDeveloper as 'developer',
                release.releaseGenre as 'genres',
                release.releaseID as 'releaseID',
                release.releasePublisher as 'publisher',
                release.releaseReferenceURL as 'referenceURL',
                release.releaseTitleName as 'gameTitle',
                rom.TEMPRomRegion as 'region',
                rom.romFileName as 'romFileName',
                rom.romHashCRC as 'romHashCRC',
                rom.romHashMD5 as 'romHashMD5',
                rom.romID as 'romID',
                rom.romLanguage as 'language',
                rom.romSerial as 'serial',
                rom.systemID as 'systemID',
                system.systemShortName as 'systemShortName'
            FROM ROMs rom, RELEASES release, SYSTEMS system, REGIONS region
            WHERE rom.romID = release.romID
            AND rom.systemID = system.systemID
            AND release.regionLocalizedID = region.regionID
            """
        let results = try vgdb.execute(query: queryString)
        return results
    }

    func system(forRomMD5 md5: String, or filename: String? = nil) throws -> Int? {
        var query = "SELECT DISTINCT systemID FROM ROMs WHERE romHashMD5 = '\(md5)'"
        if let filename = filename {
            query += " OR romFileName LIKE '\(filename)'"
        }

        let results = try vgdb.execute(query: query)
        guard let match = results.first else { return nil }

        return (match["systemID"] as? NSNumber)?.intValue
    }
}

// MARK: - Database Queries
public extension OpenVGDB {
    public enum OpenVGDBError: Error {
        case invalidSystemID(Int)
        case invalidQuery(String)
    }

    /// Valid system IDs from the database
    static let validSystemIDs = Set(1...47)  // Based on the provided database dump

    private func isValidSystemID(_ systemID: Int) -> Bool {
        return Self.validSystemIDs.contains(systemID)
    }

    private func escapeSQLString(_ string: String) -> String {
        // Escape special characters in SQL strings
        return string.replacingOccurrences(of: "'", with: "''")
    }

    private func escapeLikePattern(_ pattern: String) -> String {
        // Escape special characters in LIKE patterns
        var escaped = pattern
        escaped = escaped.replacingOccurrences(of: "%", with: "\\%")
        escaped = escaped.replacingOccurrences(of: "_", with: "\\_")
        escaped = escaped.replacingOccurrences(of: "'", with: "''")
        return escaped
    }

    func searchDatabase(usingKey key: String, value: String, systemID: Int? = nil) throws -> [ROMMetadata]? {
        let properties = getStandardProperties()
        let escapedValue = escapeSQLString(value)
        let query: String

        if let systemID = systemID, isValidSystemID(systemID) {
            query = """
                SELECT DISTINCT \(properties)
                FROM ROMs rom
                LEFT JOIN RELEASES release USING (romID)
                WHERE \(key) = '\(escapedValue)'
                AND systemID = \(systemID)
                """
        } else {
            query = """
                SELECT DISTINCT \(properties)
                FROM ROMs rom
                LEFT JOIN RELEASES release USING (romID)
                WHERE \(key) = '\(escapedValue)'
                """
        }

        return try executeQuery(query)
    }

    func searchDatabase(usingFilename filename: String, systemID: Int? = nil) throws -> [ROMMetadata]? {
        let properties = getStandardProperties()
        let escapedPattern = escapeLikePattern(filename)
        let query: String

        if let systemID = systemID, isValidSystemID(systemID) {
            query = """
                SELECT DISTINCT \(properties)
                FROM ROMs rom
                LEFT JOIN RELEASES release USING (romID)
                WHERE (romFileName LIKE '%\(escapedPattern)%' ESCAPE '\\'
                   OR releaseTitleName LIKE '%\(escapedPattern)%' ESCAPE '\\')
                AND systemID = \(systemID)
                ORDER BY
                    CASE
                        WHEN romFileName LIKE '\(escapedPattern)%' ESCAPE '\\' THEN 1
                        WHEN releaseTitleName LIKE '\(escapedPattern)%' ESCAPE '\\' THEN 2
                        ELSE 3
                    END
                """
        } else {
            query = """
                SELECT DISTINCT \(properties)
                FROM ROMs rom
                LEFT JOIN RELEASES release USING (romID)
                WHERE (romFileName LIKE '%\(escapedPattern)%' ESCAPE '\\'
                   OR releaseTitleName LIKE '%\(escapedPattern)%' ESCAPE '\\')
                ORDER BY
                    CASE
                        WHEN romFileName LIKE '\(escapedPattern)%' ESCAPE '\\' THEN 1
                        WHEN releaseTitleName LIKE '\(escapedPattern)%' ESCAPE '\\' THEN 2
                        ELSE 3
                    END
                """
        }

        return try executeQuery(query)
    }

    func searchDatabase(usingFilename filename: String, systemIDs: [Int]) throws -> [ROMMetadata]? {
        // Filter to only valid system IDs
        let validSystemIDs = systemIDs.filter(isValidSystemID)
        guard !validSystemIDs.isEmpty else {
            return nil
        }

        let properties = getStandardProperties()
        let systemIDsString = validSystemIDs.map { String($0) }.joined(separator: ",")

        let query = """
            SELECT DISTINCT \(properties)
            FROM ROMs rom
            LEFT JOIN RELEASES release USING (romID)
            WHERE romFileName LIKE '%\(filename)%'
            AND systemID IN (\(systemIDsString))
            ORDER BY case when romFileName LIKE '\(filename)%' then 1 else 0 end DESC
            """

        return try executeQuery(query)
    }
}

// MARK: - Private Helpers
private extension OpenVGDB {
    func getStandardProperties() -> String {
        return """
            releaseTitleName as 'gameTitle',
            releaseCoverFront as 'boxImageURL',
            TEMPRomRegion as 'region',
            releaseDescription as 'gameDescription',
            releaseCoverBack as 'boxBackURL',
            releaseDeveloper as 'developer',
            releasePublisher as 'publisher',
            romSerial as 'serial',
            releaseDate as 'releaseDate',
            releaseGenre as 'genres',
            releaseReferenceURL as 'referenceURL',
            releaseID as 'releaseID',
            romLanguage as 'language',
            regionLocalizedID as 'regionID',
            systemID as 'systemID',
            TEMPsystemShortName as 'systemShortName',
            romFileName,
            romHashCRC,
            romHashMD5,
            romID
            """
    }

    func convertToROMMetadata(_ dict: [String: NSObject]) -> ROMMetadata? {
        guard let systemID = (dict["systemID"] as? NSNumber)?.intValue else {
            return nil
        }

        return ROMMetadata(
            gameTitle: (dict["gameTitle"] as? String) ?? "",
            boxImageURL: dict["boxImageURL"] as? String,
            region: dict["region"] as? String,
            gameDescription: dict["gameDescription"] as? String,
            boxBackURL: dict["boxBackURL"] as? String,
            developer: dict["developer"] as? String,
            publisher: dict["publisher"] as? String,
            serial: dict["serial"] as? String,
            releaseDate: dict["releaseDate"] as? String,
            genres: dict["genres"] as? String,
            referenceURL: dict["referenceURL"] as? String,
            releaseID: (dict["releaseID"] as? NSNumber)?.stringValue,
            language: dict["language"] as? String,
            regionID: (dict["regionID"] as? NSNumber)?.intValue,
            systemID: systemID,
            systemShortName: dict["systemShortName"] as? String,
            romFileName: dict["romFileName"] as? String,
            romHashCRC: dict["romHashCRC"] as? String,
            romHashMD5: dict["romHashMD5"] as? String,
            romID: (dict["romID"] as? NSNumber)?.intValue
        )
    }

    func executeQuery(_ query: String) throws -> [ROMMetadata]? {
        let results = try vgdb.execute(query: query)
        guard let validResults = results as? [[String: NSObject]], !validResults.isEmpty else {
            return nil
        }
        return validResults.compactMap(convertToROMMetadata)
    }
}

/// Represents metadata for a ROM/game from the OpenVGDB database
public struct ROMMetadata: Codable {
    public let gameTitle: String
    public let boxImageURL: String?
    public let region: String?
    public let gameDescription: String?
    public let boxBackURL: String?
    public let developer: String?
    public let publisher: String?
    public let serial: String?
    public let releaseDate: String?
    public let genres: String?
    public let referenceURL: String?
    public let releaseID: String?
    public let language: String?
    public let regionID: Int?
    public let systemID: Int
    public let systemShortName: String?
    public let romFileName: String?
    public let romHashCRC: String?
    public let romHashMD5: String?
    public let romID: Int?
}

/// Result type for artwork mappings query
public struct ArtworkMappings {
    public let romMD5: [String: [String: AnyObject]]
    public let romFileNameToMD5: [String: String]
}
