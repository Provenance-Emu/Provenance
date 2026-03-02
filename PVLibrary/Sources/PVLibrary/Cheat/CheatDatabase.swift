// CheatDatabase.swift
// PVLibrary
//
// Provides lookup of cheat codes from the bundled cheatbase.sqlite database.
// The database schema contains ROMS, RELEASES, CHEATS, CHEAT_DEVICES,
// CHEAT_CATEGORIES, SYSTEMS, and REGIONS tables.

import Foundation
import SQLite
import PVLogging

/// Actor-based service for querying the bundled cheatbase.sqlite database.
/// Supports lookup by ROM MD5 hash and by game title.
public actor CheatDatabase {

    public static let shared = CheatDatabase()

    private var connection: SQLite.Connection?

    /// Lazily resolved bundle URL, computed once at load time.
    private static let databaseURL: URL? = Bundle.module.url(forResource: "cheatbase", withExtension: "sqlite")

    private init() {}

    // MARK: - Setup

    /// Ensures the database connection is open, connecting lazily on first use.
    private func connect() throws -> SQLite.Connection {
        if let existing = connection {
            return existing
        }
        guard let dbURL = Self.databaseURL else {
            ELOG("CheatDatabase: cheatbase.sqlite not found in bundle")
            throw CheatDatabaseError.databaseNotFound
        }
        let conn = try SQLite.Connection(dbURL.path, readonly: true)
        connection = conn
        DLOG("CheatDatabase: Connected to cheatbase.sqlite at \(dbURL.path)")
        return conn
    }

    // MARK: - Public Search API

    /// Search for cheat codes by exact ROM MD5 hash.
    /// Uses a parameterized query to prevent SQL injection.
    /// - Parameter md5: The MD5 hash of the ROM file (uppercase expected; normalized internally).
    /// - Returns: Array of matching cheat entries, empty if none found.
    public func searchCheats(byMD5 md5: String) throws -> [CheatDatabaseEntry] {
        let conn = try connect()
        return try executeQuery(Self.queryByMD5, on: conn, binding: md5.uppercased())
    }

    /// Search for cheat codes by game title (case-insensitive fuzzy match).
    /// Uses a parameterized query to prevent SQL injection.
    /// - Parameters:
    ///   - title: The game title to search for.
    ///   - limit: Maximum number of results to return (default: 200).
    /// - Returns: Array of matching cheat entries.
    public func searchCheats(byTitle title: String, limit: Int = 200) throws -> [CheatDatabaseEntry] {
        let conn = try connect()
        let pattern = "%" + title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_") + "%"
        let query = Self.queryByTitleBase + " LIMIT \(limit)"
        return try executeQuery(query, on: conn, binding: pattern)
    }

    // MARK: - Private Queries

    private static let selectClause = """
        SELECT
            c.cheatID,
            c.cheatName,
            c.cheatCode,
            c.cheatDescription,
            cd.cheatDeviceName,
            cd.cheatDeviceFormat,
            cc.cheatCategory,
            rel.releaseTitleName
        FROM CHEATS c
        JOIN ROMS r           ON c.romID          = r.romID
        JOIN RELEASES rel     ON r.romID           = rel.romID
        JOIN CHEAT_DEVICES cd ON c.cheatDeviceID   = cd.cheatDeviceID
        JOIN CHEAT_CATEGORIES cc ON c.cheatCategoryID = cc.cheatCategoryID
        """

    private static let queryByMD5 = selectClause + """

        WHERE UPPER(r.romHashMD5) = ?
        ORDER BY rel.releaseTitleName, cc.cheatCategory, c.cheatName
        """

    /// Base query for title search — caller appends " LIMIT N".
    private static let queryByTitleBase = selectClause + """

        WHERE rel.releaseTitleName LIKE ? ESCAPE '\\' COLLATE NOCASE
        ORDER BY rel.releaseTitleName, cc.cheatCategory, c.cheatName
        """

    // MARK: - Private Helpers

    /// Executes a parameterized query with a single bound string value.
    private func executeQuery(_ query: String, on conn: SQLite.Connection, binding: String) throws -> [CheatDatabaseEntry] {
        // conn.prepare(_:_:) binds the parameter safely, preventing SQL injection.
        let stmt = try conn.prepare(query, binding)
        var results: [CheatDatabaseEntry] = []
        for row in stmt {
            guard
                let cheatID    = row[0] as? Int64,
                let cheatName  = row[1] as? String,
                let cheatCode  = row[2] as? String,
                // row[3] is optional cheatDescription
                let deviceName = row[4] as? String,
                // row[5] is optional cheatDeviceFormat
                let category   = row[6] as? String,
                let romTitle   = row[7] as? String
            else { continue }

            results.append(CheatDatabaseEntry(
                id: Int(cheatID),
                cheatName: cheatName,
                cheatCode: cheatCode,
                cheatDescription: row[3] as? String,
                deviceName: deviceName,
                deviceFormat: row[5] as? String,
                category: category,
                romTitle: romTitle
            ))
        }
        return results
    }
}

// MARK: - Error

public enum CheatDatabaseError: Error, LocalizedError {
    case databaseNotFound

    public var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "The cheat code database could not be found in the app bundle."
        }
    }
}
