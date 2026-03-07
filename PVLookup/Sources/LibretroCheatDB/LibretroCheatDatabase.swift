// LibretroCheatDatabase.swift
// LibretroCheatDB
//
// Actor-based service for querying the libretro_cheats.sqlite database.
// Provides cheat code lookup by game title or MD5 hash with optional system filtering.

import Foundation
import PVLogging
import PVSQLiteDatabase
import SQLite

/// Actor-based service for querying the bundled libretro cheat database.
/// Supports lookup by game title (fuzzy) or ROM MD5 hash (exact match) with
/// optional system name filtering.
public actor LibretroCheatDatabase {

    public static let shared = LibretroCheatDatabase()

    private let databaseManager: SQLiteDatabaseManager
    private var connection: SQLite.Connection?
    /// Cached at connect time — false when the DB was generated without `--dat-dir` (no md5 column).
    private var hasMD5Column: Bool = false

    private init() {
        let bundle = Bundle.module
        DLOG("LibretroCheatDatabase: Bundle.module = \(bundle.bundlePath)")
        let zipURL = bundle.url(forResource: "libretro_cheats.sqlite", withExtension: "zip")
        DLOG("LibretroCheatDatabase: zip resource URL = \(zipURL?.path ?? "NOT FOUND")")
        if zipURL == nil {
            // List all resources in the bundle for debugging
            if let resourcePath = bundle.resourcePath {
                let contents = (try? FileManager.default.contentsOfDirectory(atPath: resourcePath)) ?? []
                ELOG("LibretroCheatDatabase: Bundle contents (\(contents.count) items): \(contents)")
            }
        }
        self.databaseManager = SQLiteDatabaseManager(
            bundle: bundle,
            databaseName: "libretro_cheats.sqlite",
            compressedName: "libretro_cheats.sqlite"
        )
    }

    // MARK: - Setup

    /// Pre-warm: ensures the database is extracted and the connection is open.
    /// Call this at app startup (fire-and-forget) to avoid first-use lag.
    public func warmUp() async {
        _ = try? await connect()
    }

    /// Ensures the database is extracted and connection is open.
    private func connect() async throws -> SQLite.Connection {
        if let existing = connection {
            return existing
        }

        DLOG("LibretroCheatDatabase: Preparing database...")
        do {
            try await databaseManager.prepareDatabaseIfNeeded()
        } catch {
            ELOG("LibretroCheatDatabase: Failed to prepare database: \(error)")
            throw error
        }

        let dbPath = databaseManager.databasePath.path
        let fileExists = FileManager.default.fileExists(atPath: dbPath)
        DLOG("LibretroCheatDatabase: Database path=\(dbPath) exists=\(fileExists)")

        guard fileExists else {
            ELOG("LibretroCheatDatabase: Database file missing after extraction at \(dbPath)")
            throw SQLiteDatabaseError.extractionFailed
        }

        let conn = try SQLite.Connection(dbPath, readonly: true)
        connection = conn

        // Quick sanity check: verify the database has tables
        let tableCount = try conn.scalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table'") as? Int64 ?? 0
        DLOG("LibretroCheatDatabase: Connected (\(tableCount) tables) at \(dbPath)")

        // Check whether the games table has any populated MD5 values.
        // The md5 column always exists in the schema, but values are only
        // populated when the DB is generated with --dat-dir. Use a data-presence
        // check (not column-existence) so the warning fires correctly and
        // unnecessary MD5 queries are skipped when no hash data is available.
        let md5DataCount = (try? conn.scalar(
            "SELECT EXISTS(SELECT 1 FROM games WHERE md5 IS NOT NULL)"
        ) as? Int64) ?? 0
        hasMD5Column = md5DataCount > 0
        if !hasMD5Column {
            WLOG("LibretroCheatDatabase: No MD5 data in games table — DB was generated without --dat-dir; MD5 lookup disabled, falling back to title-only search")
        }

        return conn
    }

    // MARK: - Public Search API

    /// Search for cheat codes by ROM MD5 hash (exact match).
    ///
    /// MD5 hashes are stored when the database is generated with the `--dat-dir`
    /// option pointing to the libretro-database root. When an MD5 match is found,
    /// only that game's cheats are returned. When no MD5 match is found, returns
    /// an empty array (use `searchCheats(byTitle:)` for fuzzy fallback).
    ///
    /// - Parameters:
    ///   - md5: The lowercase MD5 hex string of the ROM file (32 hex characters).
    ///   - systemName: Optional libretro system directory name for additional filtering.
    ///   - limit: Maximum number of results to return.
    /// - Returns: Array of matching cheat entries, empty if MD5 not found.
    public func searchCheats(
        byMD5 md5: String,
        systemName: String? = nil,
        limit: Int = 300
    ) async throws -> [LibretroCheatEntry] {
        let conn = try await connect()

        guard hasMD5Column else {
            WLOG("LibretroCheatDatabase: searchCheats(byMD5:) called but md5 column is absent — returning empty")
            return []
        }

        let normalizedMD5 = md5.lowercased()

        let stmt: Statement
        if let systemName = systemName, !systemName.isEmpty {
            let query = queryByMD5AndSystem + " LIMIT \(limit)"
            stmt = try conn.prepare(query, normalizedMD5, systemName)
        } else {
            let query = queryByMD5 + " LIMIT \(limit)"
            stmt = try conn.prepare(query, normalizedMD5)
        }

        let results = try collectResults(from: stmt)
        DLOG("LibretroCheatDatabase: \(results.count) results for md5='\(normalizedMD5)' system=\(systemName ?? "any")")
        return results
    }

    /// Search for cheat codes by game title, optionally filtered by system.
    ///
    /// When an MD5 hash is provided, performs an exact MD5 match first and
    /// returns those results if any are found. Falls back to fuzzy title search
    /// if MD5 is nil or produces no results.
    ///
    /// - Parameters:
    ///   - title: The game title to search for (case-insensitive fuzzy match).
    ///   - md5: Optional ROM MD5 hash for exact-match lookup (tried first when non-nil).
    ///   - systemName: Optional libretro system directory name (e.g. "Nintendo - Super Nintendo Entertainment System").
    ///                 When provided, results are filtered to only that system.
    ///   - limit: Maximum number of results to return.
    /// - Returns: Array of matching cheat entries.
    public func searchCheats(
        byTitle title: String,
        md5: String? = nil,
        systemName: String? = nil,
        limit: Int = 300
    ) async throws -> [LibretroCheatEntry] {
        // MD5-first: if md5 is provided, attempt exact match lookup
        if let md5 = md5, !md5.isEmpty {
            let md5Results = try await searchCheats(byMD5: md5, systemName: systemName, limit: limit)
            if !md5Results.isEmpty {
                DLOG("LibretroCheatDatabase: MD5 hit for '\(title)' — returning \(md5Results.count) results")
                return md5Results
            }
            DLOG("LibretroCheatDatabase: MD5 miss for '\(title)', falling back to title search")
        }

        let conn = try await connect()

        let escapedTitle = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        let pattern = "%" + escapedTitle + "%"

        let stmt: Statement
        if let systemName = systemName, !systemName.isEmpty {
            let query = queryByTitleAndSystem + " LIMIT \(limit)"
            // Bind pattern twice: once for game_title, once for file_title
            stmt = try conn.prepare(query, pattern, pattern, systemName)
        } else {
            let query = queryByTitle + " LIMIT \(limit)"
            // Bind pattern twice: once for game_title, once for file_title
            stmt = try conn.prepare(query, pattern, pattern)
        }

        let results = try collectResults(from: stmt)
        DLOG("LibretroCheatDatabase: \(results.count) results for title='\(title)' system=\(systemName ?? "any")")
        return results
    }

    // MARK: - Private Helpers

    private func collectResults(from stmt: Statement) throws -> [LibretroCheatEntry] {
        var results: [LibretroCheatEntry] = []
        var skippedRows = 0

        for row in stmt {
            guard
                let cheatID = row[0] as? Int64,
                let cheatName = row[1] as? String,
                let cheatCode = row[2] as? String,
                let deviceName = row[3] as? String,
                let gameTitle = row[4] as? String,
                let sysName = row[5] as? String
            else {
                skippedRows += 1
                if skippedRows <= 3 {
                    DLOG("LibretroCheatDatabase: Skipped row - types: \(row.map { type(of: $0) })")
                }
                continue
            }

            let md5 = hasMD5Column ? row[6] as? String : nil

            results.append(LibretroCheatEntry(
                id: Int(cheatID),
                cheatName: cheatName,
                cheatCode: cheatCode,
                deviceName: deviceName,
                gameTitle: gameTitle,
                systemName: sysName,
                md5: md5
            ))
        }

        if skippedRows > 0 {
            ELOG("LibretroCheatDatabase: Skipped \(skippedRows) rows due to type mismatch")
        }
        return results
    }

    // MARK: - Private Queries

    /// SELECT clause adapts based on whether the md5 column exists in the games table.
    private var selectClause: String {
        if hasMD5Column {
            return """
                SELECT
                    c.cheat_id,
                    c.cheat_name,
                    c.cheat_code,
                    c.device_name,
                    g.game_title,
                    s.system_name,
                    g.md5
                FROM cheats c
                JOIN games g ON c.game_id = g.game_id
                JOIN systems s ON g.system_id = s.system_id
                """
        } else {
            return """
                SELECT
                    c.cheat_id,
                    c.cheat_name,
                    c.cheat_code,
                    c.device_name,
                    g.game_title,
                    s.system_name
                FROM cheats c
                JOIN games g ON c.game_id = g.game_id
                JOIN systems s ON g.system_id = s.system_id
                """
        }
    }

    private var queryByTitle: String {
        selectClause + """

            WHERE (g.game_title LIKE ? ESCAPE '\\' COLLATE NOCASE
               OR  g.file_title LIKE ? ESCAPE '\\' COLLATE NOCASE)
            ORDER BY g.game_title, c.cheat_name
            """
    }

    private var queryByTitleAndSystem: String {
        selectClause + """

            WHERE (g.game_title LIKE ? ESCAPE '\\' COLLATE NOCASE
               OR  g.file_title LIKE ? ESCAPE '\\' COLLATE NOCASE)
              AND s.system_name = ?
            ORDER BY g.game_title, c.cheat_name
            """
    }

    private var queryByMD5: String {
        selectClause + """

            WHERE g.md5 = ?
            ORDER BY g.game_title, c.cheat_name
            """
    }

    private var queryByMD5AndSystem: String {
        selectClause + """

            WHERE g.md5 = ?
              AND s.system_name = ?
            ORDER BY g.game_title, c.cheat_name
            """
    }
}
