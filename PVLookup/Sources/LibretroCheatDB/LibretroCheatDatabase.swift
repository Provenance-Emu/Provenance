// LibretroCheatDatabase.swift
// LibretroCheatDB
//
// Actor-based service for querying the libretro_cheats.sqlite database.
// Provides cheat code lookup by game title with optional system filtering.

import Foundation
import PVLogging
import PVSQLiteDatabase
import SQLite

/// Actor-based service for querying the bundled libretro cheat database.
/// Supports lookup by game title with optional system name filtering.
public actor LibretroCheatDatabase {

    public static let shared = LibretroCheatDatabase()

    private let databaseManager: SQLiteDatabaseManager
    private var connection: SQLite.Connection?

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
        return conn
    }

    // MARK: - Public Search API

    /// Search for cheat codes by game title, optionally filtered by system.
    ///
    /// - Parameters:
    ///   - title: The game title to search for (case-insensitive fuzzy match).
    ///   - systemName: Optional libretro system directory name (e.g. "Nintendo - Super Nintendo Entertainment System").
    ///                 When provided, results are filtered to only that system.
    ///   - limit: Maximum number of results to return.
    /// - Returns: Array of matching cheat entries.
    public func searchCheats(
        byTitle title: String,
        systemName: String? = nil,
        limit: Int = 300
    ) async throws -> [LibretroCheatEntry] {
        let conn = try await connect()

        let escapedTitle = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        let pattern = "%" + escapedTitle + "%"

        let stmt: Statement
        if let systemName = systemName, !systemName.isEmpty {
            let query = Self.queryByTitleAndSystem + " LIMIT \(limit)"
            stmt = try conn.prepare(query, pattern, systemName)
        } else {
            let query = Self.queryByTitle + " LIMIT \(limit)"
            stmt = try conn.prepare(query, pattern)
        }

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

            results.append(LibretroCheatEntry(
                id: Int(cheatID),
                cheatName: cheatName,
                cheatCode: cheatCode,
                deviceName: deviceName,
                gameTitle: gameTitle,
                systemName: sysName
            ))
        }

        if skippedRows > 0 {
            ELOG("LibretroCheatDatabase: Skipped \(skippedRows) rows due to type mismatch")
        }
        DLOG("LibretroCheatDatabase: \(results.count) results for title='\(title)' system=\(systemName ?? "any")")
        return results
    }

    // MARK: - Private Queries

    private static let selectClause = """
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

    private static let queryByTitle = selectClause + """

        WHERE g.game_title LIKE ? ESCAPE '\\' COLLATE NOCASE
        ORDER BY g.game_title, c.cheat_name
        """

    private static let queryByTitleAndSystem = selectClause + """

        WHERE g.game_title LIKE ? ESCAPE '\\' COLLATE NOCASE
          AND s.system_name = ?
        ORDER BY g.game_title, c.cheat_name
        """
}
