// GeckoCodesLookup.swift
// PVLibrary
//
// Actor-based service that fetches Gecko cheat codes from the RiiConnect24 / GeckoCodes
// database (https://codes.rc24.xyz) for GameCube and Wii games.
//
// Sources queried:
//   - RiiConnect24 GeckoCodes mirror: https://codes.rc24.xyz/txt.php?txt=geckocodes&id=GAMEID
//
// The 6-character game ID (e.g. "RMCE01" for Mario Kart Wii USA) is read from
// the ROM header and stored in PVGame.romSerial by the game importer.
//
// Caching: results are cached to disk for 24 hours and kept in memory for
// the process lifetime to minimise network traffic.
//
// Gecko code format:
//   [GAMEID - Game Title]
//   $Cheat Name
//   XXXXXXXX YYYYYYYY
//   XXXXXXXX YYYYYYYY
//   $Another Cheat
//   XXXXXXXX YYYYYYYY

import Foundation
import PVLogging

// MARK: - GeckoCodesLookup

/// Actor-based service for querying the RiiConnect24 GeckoCodes database.
///
/// Call `GeckoCodesLookup.shared.searchCheats(gameID:)` to fetch Gecko cheat
/// codes for a GameCube or Wii game.  Results are cached for 24 hours.
///
/// The `gameID` should be the 6-character disc ID stored in `PVGame.romSerial`
/// (e.g. "RMCE01" for Mario Kart Wii USA, "GALE01" for Super Smash Bros. Melee).
public actor GeckoCodesLookup {

    public static let shared = GeckoCodesLookup()

    // MARK: - Constants

    /// Base URL for the RiiConnect24 GeckoCodes text endpoint.
    private static let endpointBase = "https://codes.rc24.xyz/txt.php"
    /// How long (seconds) cached results are considered fresh.
    private static let cacheTTL: TimeInterval = 24 * 3600
    /// ID offset so GeckoCodes entries don't collide with local DB or libretro entries.
    private static let idOffset = 3_000_000
    /// Maximum entries in the in-memory cache.
    private static let maxMemoryCacheEntries = 30

    // MARK: - State

    private var memoryCache: [String: (fetchedAt: Date, entries: [CheatDatabaseEntry])] = [:]

    private init() {}

    // MARK: - Public API

    /// Fetch Gecko cheat codes for a GameCube or Wii game.
    ///
    /// - Parameter gameID: The 6-character disc ID from the ROM header, e.g. `"RMCE01"`.
    /// - Returns: Array of `CheatDatabaseEntry` values with `isOnlineResult == true`
    ///   and `deviceName == "Gecko"`.  Returns an empty array if no codes are found.
    /// - Throws: Network errors. Returns empty array for 404 (game not in database).
    public func searchCheats(gameID: String) async throws -> [CheatDatabaseEntry] {
        let key = gameID.uppercased()

        // 1. Memory cache
        if let hit = memoryCache[key], Date().timeIntervalSince(hit.fetchedAt) < Self.cacheTTL {
            DLOG("GeckoCodesLookup: memory cache hit for '\(key)'")
            return hit.entries
        }

        // 2. Disk cache
        if let diskHit = loadDiskCache(forKey: key) {
            DLOG("GeckoCodesLookup: disk cache hit for '\(key)'")
            evictMemoryCacheIfNeeded()
            memoryCache[key] = (fetchedAt: diskHit.fetchedAt, entries: diskHit.entries)
            return diskHit.entries
        }

        // 3. Network fetch
        DLOG("GeckoCodesLookup: fetching online for gameID='\(key)'")
        let results = try await fetchGeckoCodes(gameID: key)

        evictMemoryCacheIfNeeded()
        memoryCache[key] = (Date(), results)
        saveDiskCache(results, forKey: key)

        DLOG("GeckoCodesLookup: \(results.count) codes for '\(key)'")
        return results
    }

    // MARK: - Fetch Logic

    private func fetchGeckoCodes(gameID: String) async throws -> [CheatDatabaseEntry] {
        // Build URL: https://codes.rc24.xyz/txt.php?txt=geckocodes&id=GAMEID
        guard var components = URLComponents(string: Self.endpointBase) else {
            WLOG("GeckoCodesLookup: failed to construct URLComponents from endpointBase '\(Self.endpointBase)'")
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "txt", value: "geckocodes"),
            URLQueryItem(name: "id", value: gameID.uppercased())
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Provenance-Emu/Provenance", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return [] }

        // 404 = game not in GeckoCodes database — not an error, just no results.
        if http.statusCode == 404 { return [] }
        guard (200..<300).contains(http.statusCode) else {
            WLOG("GeckoCodesLookup: HTTP \(http.statusCode) for gameID '\(gameID)'")
            throw URLError(.badServerResponse)
        }

        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return [] }

        // If the server returns an error message (not actual codes), return empty.
        if text.hasPrefix("Could not find") || text.hasPrefix("Error") || text.count < 20 {
            DLOG("GeckoCodesLookup: no codes found for '\(gameID)' — server responded: \(text.prefix(80))")
            return []
        }

        return parseGeckoCodes(text, gameID: gameID)
    }

    // MARK: - Gecko Code Parser

    /// Parse the GeckoCodes plain-text format into `CheatDatabaseEntry` values.
    ///
    /// Format:
    /// ```
    /// [GAMEID - Game Title]
    /// $Cheat Name
    /// XXXXXXXX YYYYYYYY
    /// XXXXXXXX YYYYYYYY
    /// $Another Cheat
    /// XXXXXXXX YYYYYYYY
    /// ```
    ///
    /// Lines beginning with `$` or `*` start a new cheat entry.
    /// Lines matching 8 hex + space + 8 hex are code bytes for the current cheat.
    /// Lines beginning with `[` are game-header lines (skipped).
    /// Lines beginning with `#` are comments (skipped).
    func parseGeckoCodes(_ text: String, gameID: String) -> [CheatDatabaseEntry] {
        var entries: [CheatDatabaseEntry] = []
        var currentName: String?
        var currentLines: [String] = []
        var index = 0

        /// Flush the current cheat into `entries`.
        func flush() {
            guard let name = currentName, !currentLines.isEmpty else { return }
            let code = currentLines.joined(separator: "+")
            entries.append(CheatDatabaseEntry(
                id: Self.idOffset + index,
                cheatName: name,
                cheatCode: code,
                cheatDescription: nil,
                deviceName: "Gecko",
                deviceFormat: "Gecko",
                category: "General",
                romTitle: gameID,
                systemName: nil,
                isOnlineResult: true
            ))
            index += 1
            currentLines = []
        }

        let codeLinePattern = try? NSRegularExpression(
            pattern: #"^[0-9A-Fa-f]{8}\s[0-9A-Fa-f]{8}$"#
        )

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("[") {
                // Game header — skip
                continue
            } else if line.hasPrefix("#") {
                // Comment — skip
                continue
            } else if line.hasPrefix("$") || line.hasPrefix("*") {
                // New cheat name
                flush()
                currentName = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                currentLines = []
            } else if let pattern = codeLinePattern,
                      pattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                // Code bytes line
                if currentName != nil {
                    currentLines.append(line.replacingOccurrences(of: " ", with: ""))
                }
            }
        }
        flush()

        return entries
    }

    // MARK: - Memory Cache Eviction

    private func evictMemoryCacheIfNeeded() {
        if memoryCache.count >= Self.maxMemoryCacheEntries {
            let oldest = memoryCache.min { $0.value.fetchedAt < $1.value.fetchedAt }?.key
            if let oldest { memoryCache.removeValue(forKey: oldest) }
        }
    }

    // MARK: - Cache Key

    private func makeCacheKey(_ gameID: String) -> String {
        "gecko__\(gameID.uppercased())"
    }

    // MARK: - Disk Cache

    private var cacheDirectoryURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("GeckoCodesLookup", isDirectory: true)
    }

    private func diskCacheFileURL(forKey key: String) -> URL? {
        let data = Data(key.utf8)
        var hash: UInt64 = 14695981039346656037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        let filename = String(format: "%016llx", hash)
        return cacheDirectoryURL?.appendingPathComponent("\(filename).json")
    }

    private func loadDiskCache(forKey key: String) -> (fetchedAt: Date, entries: [CheatDatabaseEntry])? {
        guard let fileURL = diskCacheFileURL(forKey: key),
              let data = try? Data(contentsOf: fileURL),
              let cache = try? JSONDecoder().decode(DiskCache.self, from: data),
              Date().timeIntervalSince(cache.fetchedAt) < Self.cacheTTL
        else { return nil }

        let entries = cache.entries.map {
            CheatDatabaseEntry(
                id: $0.id,
                cheatName: $0.cheatName,
                cheatCode: $0.cheatCode,
                cheatDescription: $0.cheatDescription,
                deviceName: $0.deviceName,
                deviceFormat: $0.deviceFormat,
                category: $0.category,
                romTitle: $0.romTitle,
                systemName: $0.systemName,
                isOnlineResult: true
            )
        }
        return (fetchedAt: cache.fetchedAt, entries: entries)
    }

    private func saveDiskCache(_ entries: [CheatDatabaseEntry], forKey key: String) {
        guard let dirURL = cacheDirectoryURL,
              let fileURL = diskCacheFileURL(forKey: key)
        else { return }
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let cache = DiskCache(
            fetchedAt: Date(),
            entries: entries.map {
                DiskCache.Entry(
                    id: $0.id,
                    cheatName: $0.cheatName,
                    cheatCode: $0.cheatCode,
                    cheatDescription: $0.cheatDescription,
                    deviceName: $0.deviceName,
                    deviceFormat: $0.deviceFormat,
                    category: $0.category,
                    romTitle: $0.romTitle,
                    systemName: $0.systemName
                )
            }
        )
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: fileURL)
        }
    }

    // MARK: - Cache Model

    private struct DiskCache: Codable {
        let fetchedAt: Date
        let entries: [Entry]

        struct Entry: Codable {
            let id: Int
            let cheatName: String
            let cheatCode: String
            let cheatDescription: String?
            let deviceName: String
            let deviceFormat: String?
            let category: String
            let romTitle: String
            let systemName: String?
        }
    }
}
