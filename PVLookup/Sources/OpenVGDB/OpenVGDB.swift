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
import ROMMetadataProvider
import PVLookupTypes
import PVSystems

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

public final class OpenVGDB: ArtworkLookupOfflineService, ROMMetadataProvider, @unchecked Sendable {
    private let db: PVSQLiteDatabase
    private let manager: OpenVGDBManager

    public init() async throws {
        self.manager = OpenVGDBManager.shared
        do {
            try await manager.prepareDatabaseIfNeeded()
            self.db = try await PVSQLiteDatabase(withURL: manager.databasePath)
        } catch {
            throw OpenVGDBError.databaseNotInitialized
        }
    }

    // ... rest of implementation ...
}

// MARK: - Artwork Queries
public extension OpenVGDB {
    enum OpenVGDBError: Error {
        case invalidSystemID(Int)
        case invalidQuery(String)
        case databaseNotInitialized
    }

    /// Valid system IDs from the database
    static let validSystemIDs = Set(1...47)  // Based on the provided database dump

    func getArtworkMappings() throws -> ArtworkMapping {
        let results = try self.getAllReleases()
        var romMD5: [String: [String: String]] = [:]
        var romFileNameToMD5: [String: String] = [:]

        for res in results {
            if let md5 = res["romHashMD5"] as? String, !md5.isEmpty {
                let md5 = md5.uppercased()
                var metadata: [String: String] = [:]
                for (key, value) in res {
                    metadata[key] = String(describing: value)
                }
                romMD5[md5] = metadata

                if let systemID = res["systemID"] as? Int {
                    if let filename = res["romFileName"] as? String, !filename.isEmpty {
                        let key = String(systemID) + ":" + filename
                        romFileNameToMD5[key] = md5
                        romFileNameToMD5[filename] = md5
                    }
                    let key = String(systemID) + ":" + md5
                    romFileNameToMD5[key] = md5
                }
                if let crc = res["romHashCRC"] as? String, !crc.isEmpty {
                    romFileNameToMD5[crc] = md5
                }
            }
        }
        return ArtworkMappings(romMD5: romMD5, romFileNameToMD5: romFileNameToMD5)
    }

    /// Get possible artwork URLs for a ROM
    /// - Parameter rom: The ROM metadata
    /// - Returns: Array of possible artwork URLs, or nil if none found
    func getArtworkURLs(forRom rom: ROMMetadata) throws -> [URL]? {
        var urls: [URL] = []

        // 1. Try MD5 search first (exact match, no system filter needed)
        if let md5 = rom.romHashMD5 {
            let md5Query = """
                SELECT DISTINCT
                    release.releaseCoverFront,
                    release.releaseCoverBack,
                    release.releaseCoverCart,
                    release.releaseCoverDisc
                FROM ROMs rom
                JOIN RELEASES release ON rom.romID = release.romID
                WHERE rom.romHashMD5 = '\(md5.uppercased())' COLLATE NOCASE
            """

            if let results = try? db.execute(query: md5Query) {
                urls.append(contentsOf: extractURLs(from: results))
                if !urls.isEmpty { return urls }
            }
        }

        // Prepare system ID filter if available and not unknown
        let systemFilter: String
        if case .Unknown = rom.systemID {
            systemFilter = ""
        } else {
            systemFilter = " AND rom.systemID = \(rom.systemID.openVGDBID)"
        }

        // 2. Try ROM name search
        if let romName = rom.romFileName?.replacingOccurrences(of: "'", with: "''") {
            let nameQuery = """
                SELECT DISTINCT
                    release.releaseCoverFront,
                    release.releaseCoverBack,
                    release.releaseCoverCart,
                    release.releaseCoverDisc
                FROM ROMs rom
                JOIN RELEASES release ON rom.romID = release.romID
                WHERE rom.romFileName LIKE '%\(romName)%' COLLATE NOCASE
                \(systemFilter)
            """

            if let results = try? db.execute(query: nameQuery) {
                urls.append(contentsOf: extractURLs(from: results))
                if !urls.isEmpty { return urls }
            }
        }

        // 3. Try exact matches by ID or serial if available
        if let romID = rom.romID {
            let idQuery = """
                SELECT DISTINCT
                    release.releaseCoverFront,
                    release.releaseCoverBack,
                    release.releaseCoverCart,
                    release.releaseCoverDisc
                FROM ROMs rom
                JOIN RELEASES release ON rom.romID = release.romID
                WHERE rom.romID = \(romID)
            """

            if let results = try? db.execute(query: idQuery) {
                urls.append(contentsOf: extractURLs(from: results))
                if !urls.isEmpty { return urls }
            }
        }

        if let serial = rom.serial?.replacingOccurrences(of: "'", with: "''") {
            let serialQuery = """
                SELECT DISTINCT
                    release.releaseCoverFront,
                    release.releaseCoverBack,
                    release.releaseCoverCart,
                    release.releaseCoverDisc
                FROM ROMs rom
                JOIN RELEASES release ON rom.romID = release.romID
                WHERE rom.romSerial = '\(serial)'
            """

            if let results = try? db.execute(query: serialQuery) {
                urls.append(contentsOf: extractURLs(from: results))
            }
        }

        return urls.isEmpty ? nil : urls
    }

    // Helper to extract URLs from query results
    private func extractURLs(from results: [[String: Any]]) -> [URL] {
        var urls: [URL] = []

        for result in results {
            // Check each possible artwork field
            let fields = ["releaseCoverFront", "releaseCoverBack", "releaseCoverCart", "releaseCoverDisc"]

            for field in fields {
                if let urlString = result[field] as? String,
                   !urlString.isEmpty,
                   let url = URL(string: urlString) {
                    urls.append(url)
                }
            }
        }

        return urls
    }
}

// MARK: - Private Artwork Helpers
private extension OpenVGDB {
    func getAllReleases() throws -> SQLQueryResponse {
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
        return try db.execute(query: queryString)
    }
}

// MARK: - Database Queries
public extension OpenVGDB {
    func searchDatabase(usingKey key: String, value: String, systemID: SystemIdentifier? = nil) throws -> [ROMMetadata]? {
        let properties = getStandardProperties()
        let escapedValue = escapeSQLString(value)
        let query: String

        let systemID = systemID?.openVGDBID

        if let systemID = systemID {
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

    func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier? = nil) throws -> [ROMMetadata]? {
        let properties = getStandardProperties()
        let escapedPattern = escapeLikePattern(filename)
        let query: String

        let systemID = systemID?.openVGDBID

        if let systemID = systemID {
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

    func searchDatabase(usingFilename filename: String, systemIDs: [SystemIdentifier]) throws -> [ROMMetadata]? {

        let validSystemIDs = systemIDs.map(\.openVGDBID)

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

    func system(forRomMD5 md5: String, or filename: String? = nil) throws -> SystemIdentifier? {
        var query = "SELECT DISTINCT systemID FROM ROMs WHERE romHashMD5 = '\(md5)'"
        if let filename = filename {
            query += " OR romFileName LIKE '\(filename)'"
        }

        let results = try db.execute(query: query)
        guard let match = results.first else { return nil }

        guard let openVGDBSystemID = (match["systemID"] as? NSNumber)?.intValue else {
            return nil
        }
        return SystemIdentifier.fromOpenVGDBID(openVGDBSystemID)
    }
}

// MARK: - Private Helpers
private extension OpenVGDB {
    func escapeSQLString(_ input: String) -> String {
        input.replacingOccurrences(of: "'", with: "''")
             .replacingOccurrences(of: "(", with: "\\(")
             .replacingOccurrences(of: ")", with: "\\)")
             .replacingOccurrences(of: "[", with: "\\[")
             .replacingOccurrences(of: "]", with: "\\]")
             .replacingOccurrences(of: "!", with: "\\!")
    }

    func escapeLikePattern(_ pattern: String) -> String {
        var escaped = pattern
        escaped = escaped.replacingOccurrences(of: "%", with: "\\%")
        escaped = escaped.replacingOccurrences(of: "_", with: "\\_")
        escaped = escaped.replacingOccurrences(of: "'", with: "''")
        return escaped
    }

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

    func executeQuery(_ query: String) throws -> [ROMMetadata]? {
        let results = try db.execute(query: query)
        guard let validResults = results as? [[String: NSObject]], !validResults.isEmpty else {
            return nil
        }
        return validResults.compactMap(convertToROMMetadata)
    }

    func convertToROMMetadata(_ dict: [String: NSObject]) -> ROMMetadata? {
        // First convert to our internal type
        guard let internalMetadata = convertToOpenVGDBMetadata(dict) else {
            return nil
        }

        // Then convert to public ROMMetadata
        return ROMMetadata(
            gameTitle: internalMetadata.gameTitle,
            boxImageURL: internalMetadata.boxImageURL,
            region: internalMetadata.region,
            gameDescription: internalMetadata.gameDescription,
            boxBackURL: internalMetadata.boxBackURL,
            developer: internalMetadata.developer,
            publisher: internalMetadata.publisher,
            serial: internalMetadata.serial,
            releaseDate: internalMetadata.releaseDate,
            genres: internalMetadata.genres,
            referenceURL: internalMetadata.referenceURL,
            releaseID: internalMetadata.releaseID,
            language: internalMetadata.language,
            regionID: internalMetadata.regionID,
            systemID: internalMetadata.systemID,
            systemShortName: internalMetadata.systemShortName,
            romFileName: internalMetadata.romFileName,
            romHashCRC: internalMetadata.romHashCRC,
            romHashMD5: internalMetadata.romHashMD5,
            romID: internalMetadata.romID,
            source: "OpenVGDB"
        )
    }

    func convertToOpenVGDBMetadata(_ dict: [String: NSObject]) -> OpenVGDBROMMetadata? {
        guard let systemIDInt = (dict["systemID"] as? NSNumber)?.intValue,
              let systemID = SystemIdentifier.fromOpenVGDBID(systemIDInt) else {
            return nil
        }

        return OpenVGDBROMMetadata(
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

    private func convertToROMMetadata(_ dict: SQLQueryDict) -> ROMMetadata? {
        // Convert systemID to SystemIdentifier
        guard let systemIDInt = (dict["systemID"] as? NSNumber)?.intValue,
              let systemIdentifier = SystemIdentifier.fromOpenVGDBID(systemIDInt) else {
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
            systemID: systemIdentifier,
            systemShortName: dict["systemShortName"] as? String,
            romFileName: dict["romFileName"] as? String,
            romHashCRC: dict["romHashCRC"] as? String,
            romHashMD5: dict["romHashMD5"] as? String,
            romID: (dict["romID"] as? NSNumber)?.intValue,
            source: "OpenVGDB"
        )
    }
}

extension OpenVGDB {
    /// Search for artwork by game name and system
    public func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        let types = artworkTypes ?? .defaults

        // Use the existing search method
        let games = try await searchDatabase(usingFilename: name, systemID: systemID)
        guard let games = games else { return nil }

        // Use a set to automatically handle deduplication
        var artworkSet = Set<ArtworkMetadata>()

        for game in games {
            // Get artwork URLs for each game
            if let urls = try getArtworkURLs(forRom: game) {
                for url in urls {
                    // Determine artwork type from URL path
                    let type: ArtworkType = if url.path.contains("front") {
                        .boxFront
                    } else if url.path.contains("back") {
                        .boxBack
                    } else if url.path.contains("screenshot") {
                        .screenshot
                    } else {
                        .other
                    }

                    // Only include requested types
                    if types.contains(type) {
                        let artwork = ArtworkMetadata(
                            url: url,
                            type: type,
                            resolution: nil,
                            description: game.gameTitle,
                            source: "OpenVGDB",
                            systemID: game.systemID
                        )
                        artworkSet.insert(artwork)
                    }
                }
            }
        }

        // Convert set back to array
        let artworks = Array(artworkSet)
        return artworks.isEmpty ? nil : artworks
    }

    /// Get artwork for a specific game ID
    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        // In OpenVGDB, we can use the romID as gameID
        guard let romID = Int(gameID) else { return nil }

        // Search for ROM by ID
        let query = """
            SELECT DISTINCT
                release.releaseCoverFront,
                release.releaseCoverBack,
                release.releaseCoverCart,
                release.releaseCoverDisc,
                rom.*
            FROM ROMs rom
            JOIN RELEASES release ON rom.romID = release.romID
            WHERE rom.romID = \(romID)
        """

        let results = try db.execute(query: query)
        guard let result = results.first,
              let metadata = convertToROMMetadata(result) else { return nil }

        // Get artwork URLs
        guard let urls = try getArtworkURLs(forRom: metadata) else { return nil }

        // Convert URLs to ArtworkMetadata
        var artworks: [ArtworkMetadata] = []

        for url in urls {
            // Determine artwork type from URL path
            let type: ArtworkType = if url.path.contains("front") {
                .boxFront
            } else if url.path.contains("back") {
                .boxBack
            } else if url.path.contains("screenshot") {
                .screenshot
            } else {
                .other
            }

            // Only include requested types
            if artworkTypes?.contains(type) ?? true {
                artworks.append(ArtworkMetadata(
                    url: url,
                    type: type,
                    resolution: nil,
                    description: nil,
                    source: "OpenVGDB"
                ))
            }
        }

        return artworks.isEmpty ? nil : artworks
    }
}

// MARK: - ROMMetadataProvider Implementation
public extension OpenVGDB {
    func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        let query = """
            SELECT DISTINCT
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
            FROM ROMs rom
            LEFT JOIN RELEASES release USING (romID)
            WHERE romHashMD5 = '\(md5.uppercased())' COLLATE NOCASE
            LIMIT 1
        """

        let results = try db.execute(query: query)
        guard let result = results.first else { return nil }
        return convertToROMMetadata(result)
    }

    func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        let properties = getStandardProperties()
        let escapedPattern = escapeLikePattern(filename)
        let query: String

        let systemID = systemID?.openVGDBID

        if let systemID = systemID {
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

    func searchByMD5(_ md5: String, systemID: SystemIdentifier? = nil) async throws -> [ROMMetadata]? {
        let properties = getStandardProperties()
        let query: String

        if let systemID = systemID {
            query = """
                SELECT DISTINCT \(properties)
                FROM ROMs rom
                LEFT JOIN RELEASES release USING (romID)
                WHERE romHashMD5 = '\(md5.uppercased())' COLLATE NOCASE
                AND systemID = \(systemID.openVGDBID)
                """
        } else {
            query = """
                SELECT DISTINCT \(properties)
                FROM ROMs rom
                LEFT JOIN RELEASES release USING (romID)
                WHERE romHashMD5 = '\(md5.uppercased())' COLLATE NOCASE
                """
        }

        return try executeQuery(query)
    }

    func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier? {
        var query = "SELECT DISTINCT systemID FROM ROMs WHERE romHashMD5 = '\(md5.uppercased())' COLLATE NOCASE"
        if let filename = filename {
            let escapedFilename = escapeSQLString(filename)
            query += " OR romFileName LIKE '%\(escapedFilename)%'"
        }

        let results = try db.execute(query: query)
        guard let result = results.first,
              let systemID = (result["systemID"] as? NSNumber)?.intValue else {
            return nil
        }

        return SystemIdentifier.fromOpenVGDBID(systemID)
    }
}
