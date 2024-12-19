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

public final class TheGamesDB: ArtworkLookupService, @unchecked Sendable {
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

            let platform = try schema.getPlatform(id: platformId)
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
        var urls: [URL] = []

        let games = try schema.searchGames(
            name: rom.gameTitle,
            platformId: rom.systemID.theGamesDBID
        )

        for game in games {
            guard let gameId = game["id"] as? Int else { continue }
            let images = try schema.getImages(gameId: gameId)

            for image in images {
                guard let filename = image["filename"] as? String else { continue }
                let urlString = "https://cdn.thegamesdb.net/images/original/\(filename)"
                if let url = URL(string: urlString) {
                    urls.append(url)
                }
            }
        }

        if urls.isEmpty {
            // Try fuzzy match
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
                    guard let filename = image["filename"] as? String else { continue }
                    let urlString = "https://cdn.thegamesdb.net/images/original/\(filename)"
                    if let url = URL(string: urlString) {
                        urls.append(url)
                    }
                }
            }
        }

        return urls.isEmpty ? nil : urls
    }

    // Other ArtworkLookupService methods...
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

        return types
    }
}
