//
//  Service_TheGamesDB.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/30/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLookupTypes
import PVSystems
import PVLogging
import PVSQLiteDatabase
import CryptoKit
import ROMMetadataProvider

public final class TheGamesDB: ArtworkLookupService, ROMMetadataProvider, @unchecked Sendable {
    private let schema: TheGamesDBSchema
    private let manager: TheGamesDBManager

    public init() async throws {
        self.manager = TheGamesDBManager.shared
        do {
            try await manager.prepareDatabaseIfNeeded()
            self.schema = try await TheGamesDBSchema(url: manager.databasePath)
        } catch {
            throw TheGamesDBError.databaseNotInitialized
        }
    }

    /// Initialize with a specific database for testing
    internal init(database: PVSQLiteDatabase) async throws {
        self.manager = TheGamesDBManager.shared
        do {
            // Verify database is valid by trying a simple query
            let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='games'"
            let result = try database.execute(query: query)
            guard !result.isEmpty else {
                throw TheGamesDBError.databaseNotInitialized
            }

            self.schema = try await TheGamesDBSchema(database: database)
        } catch {
            ELOG("Failed to initialize TheGamesDB: \(error)")
            throw TheGamesDBError.databaseNotInitialized
        }
    }

    public func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        let platformId = systemID?.theGamesDBID

        do {
            let games = try schema.searchGames(name: name, platformId: platformId)
            var artworks: [ArtworkMetadata] = []

            for game in games {
                guard let gameId = game["id"] as? Int,
                      let gameTitle = game["game_title"] as? String,
                      let platformId = game["platform"] as? Int else {
                    continue
                }

                let images = try schema.getImages(
                    gameId: gameId,
                    types: artworkTypes?.theGamesDBTypes
                )

                for image in images {
                    if let metadata = try createArtworkMetadata(
                        from: image,
                        gameTitle: gameTitle,
                        platformId: platformId
                    ) {
                        artworks.append(metadata)
                    }
                }
            }

            return artworks.isEmpty ? nil : artworks
        } catch let error as TheGamesDBError {
            throw error
        } catch {
            throw TheGamesDBError.queryError(error)
        }
    }

    private func createArtworkMetadata(
        from image: SQLQueryDict,
        gameTitle: String,
        platformId: Int
    ) throws -> ArtworkMetadata? {
        do {
            guard let filename = image["filename"] as? String,
                  let type = image["type"] as? String,
                  let artworkType = ArtworkType(fromTheGamesDB: type, side: image["side"] as? String) else {
                throw TheGamesDBError.invalidImageData
            }

            guard let systemID = SystemIdentifier(theGamesDBID: platformId) else {
                throw TheGamesDBError.invalidPlatformID
            }

            let urlString = "https://cdn.thegamesdb.net/images/original/\(filename)"
            guard let url = URL(string: urlString) else {
                throw TheGamesDBError.invalidURL
            }

            return ArtworkMetadata(
                url: url,
                type: artworkType,
                resolution: image["resolution"] as? String,
                description: gameTitle,
                source: "TheGamesDB",
                systemID: systemID
            )
        } catch let error as TheGamesDBError {
            throw error
        } catch {
            throw TheGamesDBError.queryError(error)
        }
    }

    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        guard let id = Int(gameID) else {
            throw TheGamesDBError.invalidGameID
        }

        guard let game = try schema.getGame(id: id),
              let gameTitle = game["game_title"] as? String,
              let platformId = game["platform"] as? Int else {
            throw TheGamesDBError.gameNotFound
        }

        var artworks: [ArtworkMetadata] = []

        let images = try schema.getImages(
            gameId: id,
            types: artworkTypes?.theGamesDBTypes
        )

        for image in images {
            if let metadata = try createArtworkMetadata(
                from: image,
                gameTitle: gameTitle,
                platformId: platformId
            ) {
                artworks.append(metadata)
            }
        }

        return artworks.isEmpty ? nil : artworks
    }

    public func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        // Early return for invalid data
        guard !rom.gameTitle.isEmpty, rom.systemID != .Unknown else {
            return nil
        }

        var urls: [URL] = []

        let games = try schema.searchGames(
            name: rom.gameTitle,
            platformId: rom.systemID.theGamesDBID
        )

        for game in games {
            guard let gameId = game["id"] as? Int else { continue }
            let images = try schema.getImages(gameId: gameId)

            for image in images {
                if let filename = image["filename"] as? String,
                   let url = URL(string: "https://cdn.thegamesdb.net/images/original/\(filename)") {
                    urls.append(url)
                }
            }
        }

        // Only try fuzzy match if we have a valid system ID
        if urls.isEmpty && rom.systemID != .Unknown {
            let cleanName = rom.gameTitle.replacingOccurrences(
                of: "\\s*\\([^)]*\\)|\\s*\\[[^\\]]*\\]",
                with: "",
                options: [.regularExpression]
            )

            let fuzzyGames = try schema.searchGamesFuzzy(
                name: cleanName,
                platformId: rom.systemID.theGamesDBID
            )

            for game in fuzzyGames {
                guard let gameId = game["id"] as? Int else { continue }
                let images = try schema.getImages(gameId: gameId)

                for image in images {
                    if let filename = image["filename"] as? String,
                       let url = URL(string: "https://cdn.thegamesdb.net/images/original/\(filename)") {
                        urls.append(url)
                    }
                }
            }
        }

        return urls.isEmpty ? nil : urls
    }

    public func getArtworkMappings() async throws -> ArtworkMapping {
        var romMD5: [String: [String: String]] = [:]
        var romFileNameToMD5: [String: String] = [:]

        // Get all games with artwork
        let query = """
            SELECT DISTINCT
                g.id,
                g.game_title,
                g.platform,
                ga.filename,
                s.name as system_name
            FROM games g
            JOIN game_artwork ga ON g.id = ga.game_id
            LEFT JOIN systems s ON g.platform = s.id
            """

        let results = try schema.db.execute(query: query)
        for result in results {
            if let gameTitle = result["game_title"] as? String,
               let filename = result["filename"] as? String,
               let platformId = (result["platform"] as? NSNumber)?.stringValue {

                // Store metadata using filename as key
                let metadata: [String: String] = [
                    "gameTitle": gameTitle,
                    "filename": filename,
                    "platformId": platformId,
                    "systemName": result["system_name"] as? String ?? ""
                ]

                // Use filename as the key since it should be unique in TheGamesDB
                romFileNameToMD5[filename] = filename
                romMD5[filename] = metadata
            }
        }

        return ArtworkMappings(
            romMD5: romMD5,
            romFileNameToMD5: romFileNameToMD5
        )
    }

    // Other ArtworkLookupService methods...

    /// Search for games by name and platform ID
    /// - Parameters:
    ///   - name: Game name to search for
    ///   - platformId: Optional platform ID to filter results
    /// - Returns: Array of ROM metadata
    public func searchGames(name: String, platformId: Int?) throws -> [ROMMetadata] {
        do {
            let results = try schema.searchGames(name: name, platformId: platformId)

            return results.compactMap { game -> ROMMetadata? in
                guard let gameTitle = game["game_title"] as? String,
                      let platformId = game["platform"] as? Int,
                      let systemID = SystemIdentifier(theGamesDBID: platformId) else {
                    return nil
                }


                return ROMMetadata(
                    gameTitle: gameTitle,
                    region: game["region"] as? String,
                    gameDescription:  game["overview"] as? String,
                    developer: game["developer"] as? String,
                    publisher:  game["publisher"] as? String,
                    systemID: systemID,
                    source: "TheGamesDB"
                )
            }
        } catch {
            throw TheGamesDBError.queryError(error)
        }
    }

    // Add required ROMMetadataProvider methods
    public func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        return nil  // TheGamesDB doesn't support MD5 lookup
    }

    public func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        return try searchGames(name: filename, platformId: systemID?.theGamesDBID)
    }

    public func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier? {
        return nil  // TheGamesDB doesn't support system identification by MD5
    }

    private func constructArtworkSearchQuery(name: String, systemID: SystemIdentifier?) -> String {
        let sanitizedName = sanitizeForSQLLike(name)
        let platformFilter = if let id = systemID?.theGamesDBID {
            "AND games.platform_id = \(id)"
        } else {
            ""
        }

        return """
        WITH matched_games AS (
            SELECT DISTINCT games.id, games.serial_id,
                   CASE
                       WHEN games.display_name = '\(sanitizedName)' THEN 0
                       WHEN games.display_name LIKE '\(sanitizedName) %' THEN 1
                       WHEN games.display_name LIKE '% \(sanitizedName) %' THEN 2
                       WHEN games.display_name LIKE '%\(sanitizedName)%' THEN 3
                       ELSE 4
                   END as match_quality
            FROM games
            WHERE games.display_name LIKE '%\(sanitizedName)%'
            \(platformFilter)
            ORDER BY match_quality, games.display_name
            LIMIT 10
        )
        SELECT DISTINCT
            games.display_name as game_title,
            roms.name as rom_name,
            platforms.id as platform_id,
            manufacturers.name as manufacturer_name,
            games.developer_id,  -- Just get the ID
            games.publisher_id   -- Just get the ID
        FROM matched_games
        JOIN games ON matched_games.id = games.id
        LEFT JOIN platforms ON games.platform_id = platforms.id
        LEFT JOIN manufacturers ON platforms.manufacturer_id = manufacturers.id
        LEFT JOIN roms ON games.serial_id = roms.serial_id
        ORDER BY matched_games.match_quality, games.display_name
        """
    }
}

// Helper to convert ArtworkType to TheGamesDB types
private extension ArtworkType {
    var theGamesDBTypes: [String] {
        var types: [String] = []

        if self.contains(.boxFront) {
            types.append("boxart-front")
        }
        if self.contains(.boxBack) {
            types.append("boxart-back")
        }
        if self.contains(.screenshot) {
            types.append("screenshot")
        }
        if self.contains(.titleScreen) {
            types.append("titlescreen")
        }
        if self.contains(.fanArt) {
            types.append("fanart")
        }
        if self.contains(.banner) {
            types.append("banner")
        }
        if self.contains(.clearLogo) {
            types.append("clearlogo")
        }
        if self.contains(.other) {
            // When .other is requested, get all types that aren't explicitly handled
            types.append("fanart")  // These will be converted to .other in init
            types.append("banner")
            types.append("clearlogo")
            types.append("manual")
            types.append("poster")
            types.append("flyer")
        }

        return types
    }

    init?(fromTheGamesDB type: String, side: String?) {
        DLOG("\nConverting TheGamesDB type:")
        DLOG("- Type: \(type)")
        DLOG("- Side: \(String(describing: side))")

        let result: ArtworkType
        switch (type.lowercased(), side?.lowercased()) {
        case ("boxart", "back"):
            result = .boxBack
        case ("boxart", "front"):
            result = .boxFront
        case ("screenshot", _):
            result = .screenshot
        case ("titlescreen", _):
            result = .titleScreen
        case ("fanart", _), ("banner", _), ("clearlogo", _),
             ("manual", _), ("poster", _), ("flyer", _):
            result = .other  // Convert these types to .other
        default:
            result = .other  // Any unknown type becomes .other
        }

        DLOG("- Converted to: \(result)")
        self = result
    }
}

private extension String {
    /// Generate MD5 hash of the string
    var md5: String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
