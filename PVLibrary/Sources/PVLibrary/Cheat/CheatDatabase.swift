// CheatDatabase.swift
// PVLibrary
//
// Provides lookup of cheat codes from the bundled cheatbase.sqlite database.
// The database schema contains ROMS, RELEASES, CHEATS, CHEAT_DEVICES,
// CHEAT_CATEGORIES, SYSTEMS, and REGIONS tables.

import Foundation
import SQLite
import PVLogging
import PVPrimitives
import LibretroCheatDB

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

    // MARK: - Unified Search (both databases)

    /// Search both the existing DS cheatbase AND the libretro cheat database.
    ///
    /// - Parameters:
    ///   - md5: The MD5 hash of the ROM (for exact match in DS cheatbase).
    ///   - title: The game title for fuzzy search across both databases.
    ///   - systemIdentifier: The libretro system directory name (e.g. "Nintendo - Super Nintendo Entertainment System").
    ///   - limit: Maximum number of results to return.
    /// - Returns: Combined, deduplicated array of cheat entries from both databases.
    public func searchAllCheats(
        byMD5 md5: String? = nil,
        title: String? = nil,
        systemIdentifier: String? = nil,
        limit: Int = 300
    ) async throws -> [CheatDatabaseEntry] {
        var results: [CheatDatabaseEntry] = []
        var seenCodes = Set<String>()
        var lastError: Error?

        // 1. Try MD5 exact match on existing cheatbase.sqlite (DS data — high precision)
        if let md5 = md5, !md5.isEmpty {
            do {
                let md5Results = try searchCheats(byMD5: md5)
                for entry in md5Results {
                    let key = entry.cheatCode.lowercased()
                    if seenCodes.insert(key).inserted {
                        results.append(entry)
                    }
                }
                DLOG("CheatDatabase: \(md5Results.count) results from cheatbase by MD5")
            } catch {
                ELOG("CheatDatabase: MD5 search error: \(error)")
                lastError = error
            }
        }

        // 2. Query LibretroCheatDatabase by title + system
        if let title = title, !title.isEmpty {
            // Strip parenthetical/bracketed region and release tags (e.g. "(USA)", "[!]")
            // so "Bomberman (USA)" matches the DB entry "Bomberman".
            let lookupTitle = title.strippingROMTags()
            DLOG("CheatDatabase: Querying libretro DB for title='\(lookupTitle)' (original='\(title)') system=\(systemIdentifier ?? "any")")
            do {
                let libretroResults = try await LibretroCheatDatabase.shared.searchCheats(
                    byTitle: lookupTitle,
                    systemName: systemIdentifier,
                    limit: limit
                )
                DLOG("CheatDatabase: \(libretroResults.count) results from libretro DB")

                for entry in libretroResults {
                    let key = entry.cheatCode.lowercased()
                    if seenCodes.insert(key).inserted {
                        results.append(CheatDatabaseEntry(
                            id: entry.id + 1_000_000, // Offset to avoid ID collision
                            cheatName: entry.cheatName,
                            cheatCode: entry.cheatCode,
                            cheatDescription: nil,
                            deviceName: entry.deviceName,
                            deviceFormat: nil,
                            category: "General",
                            romTitle: entry.gameTitle,
                            systemName: entry.systemName
                        ))
                    }
                }
            } catch {
                ELOG("CheatDatabase: LibretroCheatDatabase error: \(error)")
                lastError = error
            }
        }

        // 3. If libretro returned nothing, also try title on old DS cheatbase
        if results.isEmpty, let title = title, !title.isEmpty {
            let lookupTitle = title.strippingROMTags()
            do {
                let titleResults = try searchCheats(byTitle: lookupTitle, limit: limit)
                for entry in titleResults {
                    let key = entry.cheatCode.lowercased()
                    if seenCodes.insert(key).inserted {
                        results.append(entry)
                    }
                }
                DLOG("CheatDatabase: \(titleResults.count) results from cheatbase by title '\(lookupTitle)'")
            } catch {
                ELOG("CheatDatabase: Title search error: \(error)")
                lastError = error
            }
        }

        DLOG("CheatDatabase: searchAllCheats total=\(results.count) for md5=\(md5 ?? "nil") title=\(title ?? "nil") system=\(systemIdentifier ?? "nil")")

        // If all searches failed and we have no results, propagate the last error
        // so the UI can display it instead of just showing "No results"
        if results.isEmpty, let error = lastError {
            throw error
        }

        return results
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

    // MARK: - Online Search

    /// Fetch cheat codes from online sources (libretro cheat database on GitHub).
    ///
    /// This is a thin wrapper around `CheatOnlineLookup` that can be called directly
    /// from the UI layer after local searches return no results.
    ///
    /// - Parameters:
    ///   - title: The game title.
    ///   - systemIdentifier: The libretro system directory name.
    /// - Returns: Array of `CheatDatabaseEntry` values with `isOnlineResult == true`.
    public func searchCheatsOnline(
        title: String,
        systemIdentifier: String? = nil
    ) async throws -> [CheatDatabaseEntry] {
        try await CheatOnlineLookup.shared.searchCheats(
            title: title,
            systemIdentifier: systemIdentifier
        )
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
