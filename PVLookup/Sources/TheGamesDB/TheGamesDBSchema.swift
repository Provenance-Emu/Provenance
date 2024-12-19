import Foundation
import PVSQLiteDatabase
import PVLookupTypes
import PVSystems

/// Schema for TheGamesDB SQLite database
public struct TheGamesDBSchema {
    internal let db: PVSQLiteDatabase

    public init(url: URL) async throws {
        self.db = try PVSQLiteDatabase(withURL: url)
    }

    public init(database: PVSQLiteDatabase) async throws {
        self.db = database
    }

    /// Clean game name for searching
    private func cleanGameName(_ name: String) -> String {
        // Remove common ROM notation patterns and normalize
        let cleaned = name
            .replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)  // Remove (USA), etc.
            .replacingOccurrences(of: "\\s*\\[[^\\]]*\\]", with: "", options: .regularExpression) // Remove [!], etc.
            .replacingOccurrences(of: "\\s*v[0-9.]+", with: "", options: .regularExpression)     // Remove version numbers
            .replacingOccurrences(of: "'", with: "''")  // Escape single quotes for SQL
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    /// Search for games by name
    func searchGames(name: String, platformId: Int? = nil) throws -> SQLQueryResponse {
        let cleanName = cleanGameName(name)
        let platformFilter = platformId.map { "AND g.platform = \($0)" } ?? ""

        let query = """
            SELECT DISTINCT
                g.id,
                g.game_title,
                g.platform,
                g.release_date,
                g.overview,
                g.rating,
                g.youtube,
                g.players,
                g.coop,
                s.name as system_name,
                s.alias as system_alias
            FROM games g
            LEFT JOIN systems s ON g.platform = s.id
            WHERE g.game_title LIKE '%\(cleanName)%' \(platformFilter)
            """
        return try db.execute(query: query)
    }

    /// Get images for a game
    func getImages(gameId: Int, types: [String]? = nil) throws -> SQLQueryResponse {
        var conditions: [String] = []

        print("\nTheGamesDB getImages:")
        print("- Game ID: \(gameId)")
        print("- Requested types: \(String(describing: types))")

        if let types = types {
            let typeConditions = types.map { type -> String in
                switch type {
                case "boxart-front":
                    let condition = "(type = 'boxart' AND side = 'front')"
                    print("- Adding boxart front condition: \(condition)")
                    return condition
                case "boxart-back":
                    let condition = "(type = 'boxart' AND side = 'back')"
                    print("- Adding boxart back condition: \(condition)")
                    return condition
                default:
                    let condition = "type = '\(type)'"
                    print("- Adding type condition: \(condition)")
                    return condition
                }
            }
            if !typeConditions.isEmpty {
                let combined = "AND (\(typeConditions.joined(separator: " OR ")))"
                print("- Combined conditions: \(combined)")
                conditions.append(combined)
            }
        }

        let query = """
            SELECT
                id,
                game_id,
                type,
                side,
                filename,
                resolution
            FROM game_artwork
            WHERE game_id = \(gameId)
            \(conditions.joined(separator: " "))
            """
        print("- Final query: \(query)")

        let results = try db.execute(query: query)
        print("- Found \(results.count) results")
        results.forEach { result in
            print("  - Type: \(result["type"] as? String ?? "nil")")
            print("    Side: \(result["side"] as? String ?? "nil")")
        }

        return results
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
            SELECT DISTINCT
                g.id,
                g.game_title,
                g.platform,
                g.release_date,
                g.overview,
                g.rating,
                g.youtube,
                g.players,
                g.coop,
                s.name as system_name,
                s.alias as system_alias
            FROM games g
            LEFT JOIN systems s ON g.platform = s.id
            WHERE g.id = \(id)
            LIMIT 1
            """
        return try db.execute(query: query).first
    }

    /// Search games with fuzzy matching
    func searchGamesFuzzy(name: String, platformId: Int? = nil) throws -> SQLQueryResponse {
        let cleanName = cleanGameName(name)
        let platformFilter = platformId.map { "AND g.platform = \($0)" } ?? ""

        let query = """
            SELECT DISTINCT
                g.id,
                g.game_title,
                g.platform,
                g.release_date,
                g.overview,
                g.rating,
                g.youtube,
                g.players,
                g.coop,
                s.name as system_name,
                s.alias as system_alias
            FROM games g
            LEFT JOIN systems s ON g.platform = s.id
            WHERE g.game_title LIKE '%\(cleanName)%' \(platformFilter)
            ORDER BY
                CASE
                    WHEN g.game_title = '\(cleanName)' THEN 0
                    WHEN g.game_title LIKE '\(cleanName)%' THEN 1
                    WHEN g.game_title LIKE '% \(cleanName) %' THEN 2
                    ELSE 3
                END,
                g.game_title
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
            FROM game_artwork
            WHERE game_id = \(gameId)
            """
        return try db.execute(query: query)
    }
}
