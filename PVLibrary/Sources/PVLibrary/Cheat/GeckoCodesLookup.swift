// GeckoCodesLookup.swift
// PVLibrary
//
// Actor-based service that fetches Gecko cheat codes from the RiiConnect24 / GeckoCodes
// database (https://codes.rc24.xyz) for GameCube and Wii games.
//
// Sources queried:
//   - RiiConnect24 mirror uses the same URL shape as Dolphin:
//     `https://codes.rc24.xyz/txt.php?txt=GAMEID` (e.g. txt=GALE01).
//     The older `txt=geckocodes&id=` form returns 404 and must not be used.
//
// The 6-character game ID (e.g. "RMCE01" for Mario Kart Wii USA) is read from
// the ROM header and stored in PVGame.romSerial by the game importer.
//
// Caching: results are cached to disk for 24 hours and kept in memory for
// the process lifetime to minimise network traffic.
//
// Parsed text formats:
//   1) RiiConnect24 / Dolphin download layout (`Core/GeckoCodeConfig.cpp`): game ID line,
//      title line, blank line, then blocks separated by blank lines; each cheat starts with
//      `Name [Author]` followed by `XXXXXXXX YYYYYYYY` lines.
//   2) Legacy: `[GAMEID - Title]` header, `$Cheat Name` or `*Cheat Name`, then hex lines.

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

    /// Base URL for the RiiConnect24 GeckoCodes text endpoint (`?txt=<GAMEID>`).
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
        let key = makeCacheKey(gameID)

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
        /// Same query pattern as Dolphin `Gecko::DownloadCodes`: `txt.php?txt=<gametdb_or_game_id>`.
        guard var components = URLComponents(string: Self.endpointBase) else {
            WLOG("GeckoCodesLookup: failed to construct URLComponents from endpointBase '\(Self.endpointBase)'")
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "txt", value: gameID.uppercased())
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

    /// Parse RiiConnect24 / Dolphin plaintext Gecko lists and legacy `$` / `*` cheat files into `CheatDatabaseEntry` values.
    ///
    /// Dolphin download format (`GeckoCodeConfig.cpp`): after a 3-line header (game ID, title, blank),
    /// cheats are separated by blank lines; each cheat begins with `Name [Author]` then `XXXXXXXX YYYYYYYY` lines.
    ///
    /// Legacy format: optional `[GAMEID - Title]` line, then `$Name` or `*Name` and hex lines (no blank-line requirement between cheats).
    func parseGeckoCodes(_ text: String, gameID: String) -> [CheatDatabaseEntry] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { line in
                line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\r", with: "")
            }

        var index = 0
        var entries: [CheatDatabaseEntry] = []

        /// True when `line` is two whitespace-separated 8-hex values (Dolphin `DeserializeLine`).
        func isGeckoHexPair(_ line: String) -> Bool {
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2 else { return false }
            let a = parts[0]
            let b = parts[1]
            guard a.count == 8, b.count == 8 else { return false }
            let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            return a.unicodeScalars.allSatisfy { hex.contains($0) } && b.unicodeScalars.allSatisfy { hex.contains($0) }
        }

        func flushCheat(name: String?, hexLines: [String], into results: inout [CheatDatabaseEntry], idCounter: inout Int) {
            guard let name, !name.isEmpty, !hexLines.isEmpty else { return }
            let code = hexLines.joined(separator: "+")
            results.append(CheatDatabaseEntry(
                id: Self.idOffset + idCounter,
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
            idCounter += 1
        }

        /// Dolphin `DownloadCodes` state machine: blank line ends a cheat; `Name [Author]` starts one.
        /// Legacy `$` / `*` cheats may repeat without blank lines — finishing one `$` header starts the next.
        func parseDolphinStyle(from start: Int) {
            var i = start
            /// 0 = expect cheat title, 1 = expect hex code lines, 2 = note lines until blank (Dolphin download)
            var readState = 0
            var currentName: String?
            var currentCreator: String?
            var hexLines: [String] = []

            func displayName() -> String? {
                guard let n = currentName, !n.isEmpty else { return nil }
                if let c = currentCreator, !c.isEmpty { return "\(n) [\(c)]" }
                return n
            }

            func resetCheat() {
                currentName = nil
                currentCreator = nil
                hexLines = []
                readState = 0
            }

            func flushPending() {
                flushCheat(name: displayName(), hexLines: hexLines, into: &entries, idCounter: &index)
                resetCheat()
            }

            func applyTitleLine(_ line: String) {
                if line.hasPrefix("$") {
                    currentName = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    currentCreator = nil
                } else if line.hasPrefix("*") {
                    currentName = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    currentCreator = nil
                } else if let openBracket = line.firstIndex(of: "[") {
                    currentName = String(line[..<openBracket]).trimmingCharacters(in: .whitespaces)
                    let after = line[line.index(after: openBracket)...]
                    if let close = after.firstIndex(of: "]") {
                        currentCreator = String(after[..<close]).trimmingCharacters(in: .whitespaces)
                    } else {
                        currentCreator = nil
                    }
                } else {
                    currentName = line
                    currentCreator = nil
                }
                readState = 1
            }

            while i < lines.count {
                let line = lines[i]
                i += 1
                if line.isEmpty {
                    if !hexLines.isEmpty {
                        flushPending()
                    } else {
                        resetCheat()
                    }
                    continue
                }
                if line.hasPrefix("[") || line.hasPrefix("#") {
                    continue
                }
                switch readState {
                case 0:
                    if isGeckoHexPair(line) {
                        continue
                    }
                    applyTitleLine(line)
                case 1:
                    if line.hasPrefix("$") || line.hasPrefix("*") {
                        if !hexLines.isEmpty {
                            flushCheat(name: displayName(), hexLines: hexLines, into: &entries, idCounter: &index)
                            hexLines = []
                        }
                        currentName = nil
                        currentCreator = nil
                        readState = 0
                        i -= 1
                        continue
                    }
                    if isGeckoHexPair(line) {
                        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
                        hexLines.append(parts[0] + parts[1])
                    } else {
                        readState = 2
                    }
                case 2:
                    break
                default:
                    break
                }
            }
            if !hexLines.isEmpty {
                flushCheat(name: displayName(), hexLines: hexLines, into: &entries, idCounter: &index)
            }
        }

        var startLine = 0
        if let first = lines.first,
           first.count == 6,
           first.allSatisfy({ $0.isLetter || $0.isNumber }) {
            startLine = min(3, lines.count)
        }

        parseDolphinStyle(from: startLine)
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

    /// Bumped when fetch URL or parse format changes so stale disk entries (e.g. empty 404 caches) are ignored.
    private func makeCacheKey(_ gameID: String) -> String {
        "gecko_txt_v2__\(gameID.uppercased())"
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
