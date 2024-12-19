import Foundation
import PVSQLiteDatabase
import PVLookupTypes
import PVSystems

/// Schema for TheGamesDB SQLite database
public struct TheGamesDBSchema {
    private let db: PVSQLiteDatabase

    public init(url: URL) async throws {
        self.db = try PVSQLiteDatabase(withURL: url)
    }

    public init(database: PVSQLiteDatabase) async throws {
        self.db = database
    }

    /// Search for games by name
    func searchGames(name: String, platformId: Int? = nil) throws -> SQLQueryResponse {
        let platformFilter = platformId.map { "AND platform = \($0)" } ?? ""
        let query = """
            SELECT DISTINCT
                games.id,
                games.game_title,
                games.platform,
                games.release_date,
                games.overview,
                games.developers,
                games.publishers,
                games.genres,
                games.rating
            FROM games
            WHERE game_title LIKE '%\(name)%' \(platformFilter)
            """
        return try db.execute(query: query)
    }

    /// Get images for a game
    func getImages(gameId: Int, types: [String]? = nil) throws -> SQLQueryResponse {
        let typeFilter = types.map { types in
            let typeList = types.map { "'\($0)'" }.joined(separator: ",")
            return "AND type IN (\(typeList))"
        } ?? ""

        let query = """
            SELECT
                id,
                game_id,
                type,
                side,
                filename,
                resolution
            FROM images
            WHERE game_id = \(gameId) \(typeFilter)
            """
        return try db.execute(query: query)
    }

    /// Get platform info
    func getPlatform(id: Int) throws -> SQLQueryDict? {
        let query = """
            SELECT
                id,
                name,
                manufacturer
            FROM platforms
            WHERE id = \(id)
            LIMIT 1
            """
        return try db.execute(query: query).first
    }

    /// Get a game by ID
    func getGame(id: Int) throws -> SQLQueryDict? {
        let query = """
            SELECT
                id,
                game_title,
                platform,
                release_date,
                overview,
                developers,
                publishers,
                genres,
                rating
            FROM games
            WHERE id = \(id)
            LIMIT 1
            """
        return try db.execute(query: query).first
    }

    /// Search games with fuzzy matching
    func searchGamesFuzzy(name: String, platformId: Int? = nil) throws -> SQLQueryResponse {
        // Remove special characters and normalize spaces
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "'", with: "''") // Escape single quotes

        let platformFilter = platformId.map { "AND platform = \($0)" } ?? ""

        let query = """
            SELECT DISTINCT
                games.id,
                games.game_title,
                games.platform,
                games.release_date,
                games.overview,
                games.developers,
                games.publishers,
                games.genres,
                games.rating
            FROM games
            WHERE game_title LIKE '%\(normalizedName)%' \(platformFilter)
            """
        return try db.execute(query: query)
    }

    /// Get all images for a game
    func getAllImages(gameId: Int) throws -> SQLQueryResponse {
        let query = """
            SELECT
                id,
                game_id,
                type,
                side,
                filename,
                resolution
            FROM images
            WHERE game_id = \(gameId)
            """
        return try db.execute(query: query)
    }
}
