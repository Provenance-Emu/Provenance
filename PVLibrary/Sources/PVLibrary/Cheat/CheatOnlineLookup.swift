// CheatOnlineLookup.swift
// PVLibrary
//
// Actor-based service that fetches cheat codes from the libretro cheat database
// on GitHub when the bundled local databases have no results for a game.
//
// Sources queried:
//   - libretro/libretro-database (GitHub raw + directory listing API)
//     https://github.com/libretro/libretro-database/tree/master/cht
//
// Caching: results are cached to disk for 24 hours and kept in memory for
// the process lifetime to minimise network traffic and respect GitHub API
// rate limits (60 unauthenticated requests/hour).

import Foundation
import PVLogging

// MARK: - CheatOnlineLookup

/// Actor-based service for querying online cheat code databases.
///
/// Call `CheatOnlineLookup.shared.searchCheats(title:systemIdentifier:)` to fetch
/// cheat codes from the libretro database on GitHub.  Results are cached
/// aggressively to avoid hammering the API.
public actor CheatOnlineLookup {

    public static let shared = CheatOnlineLookup()

    // MARK: - Constants

    /// Base URL for raw file content in the libretro database.
    private static let rawBase = "https://raw.githubusercontent.com/libretro/libretro-database/master/cht"
    /// GitHub API base for directory listings.
    private static let apiBase = "https://api.github.com/repos/libretro/libretro-database/contents/cht"
    /// How long (seconds) cached results are considered fresh.
    private static let cacheTTL: TimeInterval = 24 * 3600
    /// Minimum gap between GitHub API directory-listing requests.
    private static let minAPIRequestInterval: TimeInterval = 2.0
    /// ID offset so online entries don't collide with local DB entries.
    private static let idOffset = 2_000_000

    // MARK: - State

    /// In-memory LRU-style cache keyed by `makeCacheKey`.
    private var memoryCache: [String: (fetchedAt: Date, entries: [CheatDatabaseEntry])] = [:]
    /// Timestamp of the last GitHub API directory-listing request (for rate limiting).
    private var lastAPIRequestDate: Date?

    private init() {}

    // MARK: - Public API

    /// Fetch cheat codes for a game from online sources.
    ///
    /// - Parameters:
    ///   - title: The game title used for fuzzy filename matching.
    ///   - systemIdentifier: Libretro system folder name
    ///     (e.g. `"Nintendo - Super Nintendo Entertainment System"`).
    /// - Returns: Array of `CheatDatabaseEntry` values with `isOnlineResult == true`.
    ///   Returns an empty array when no results are found; does **not** throw on a cache hit.
    public func searchCheats(
        title: String,
        systemIdentifier: String? = nil
    ) async throws -> [CheatDatabaseEntry] {
        let key = makeCacheKey(title: title, system: systemIdentifier)

        // 1. Memory cache
        if let hit = memoryCache[key], Date().timeIntervalSince(hit.fetchedAt) < Self.cacheTTL {
            DLOG("CheatOnlineLookup: memory cache hit for '\(title)'")
            return hit.entries
        }

        // 2. Disk cache
        if let diskHit = loadDiskCache(forKey: key) {
            DLOG("CheatOnlineLookup: disk cache hit for '\(title)'")
            memoryCache[key] = (Date(), diskHit)
            return diskHit
        }

        // 3. Fetch from network
        DLOG("CheatOnlineLookup: fetching online for title='\(title)' system=\(systemIdentifier ?? "nil")")
        let results = try await fetchOnline(title: title, systemIdentifier: systemIdentifier)

        // Cache even empty results so we don't hammer the API for unknown games
        memoryCache[key] = (Date(), results)
        saveDiskCache(results, forKey: key)

        DLOG("CheatOnlineLookup: \(results.count) results for '\(title)'")
        return results
    }

    // MARK: - Fetch Logic

    private func fetchOnline(title: String, systemIdentifier: String?) async throws -> [CheatDatabaseEntry] {
        guard let system = systemIdentifier, !system.isEmpty else {
            // Without a system identifier we can't construct a useful path
            return []
        }

        // Strategy 1: Try direct raw URL using sanitised title (no API quota consumed)
        let sanitised = sanitiseFilename(title)
        if let entries = try? await fetchRawCht(system: system, filename: sanitised),
           !entries.isEmpty {
            DLOG("CheatOnlineLookup: direct raw URL hit for '\(title)'")
            return entries
        }

        // Strategy 2: Use GitHub directory-listing API to fuzzy-match a filename
        if let entries = try? await fetchViaDirectoryListing(title: title, system: system),
           !entries.isEmpty {
            return entries
        }

        return []
    }

    /// Fetch a `.cht` file directly using a known/guessed raw URL.
    private func fetchRawCht(system: String, filename: String) async throws -> [CheatDatabaseEntry]? {
        guard let encoded = "\(system)/\(filename).cht"
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(Self.rawBase)/\(encoded)")
        else { return nil }

        let data = try await httpGet(url: url)
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return nil }

        let parsed = parseCht(text, romTitle: filename, systemName: system)
        return parsed.isEmpty ? nil : parsed
    }

    /// List a system's cheat directory via the GitHub API, then fetch the best-matching file.
    private func fetchViaDirectoryListing(title: String, system: String) async throws -> [CheatDatabaseEntry]? {
        await throttleAPIRequest()

        guard let encoded = system.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(Self.apiBase)/\(encoded)?per_page=100")
        else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Provenance-Emu/Provenance", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { return nil }
        guard http.statusCode == 200 else {
            WLOG("CheatOnlineLookup: GitHub API returned \(http.statusCode) for system '\(system)'")
            return nil
        }

        let files = try JSONDecoder().decode([GitHubFileEntry].self, from: data)
        let chtFiles = files.filter { $0.name.hasSuffix(".cht") }

        guard let best = bestMatch(for: title, among: chtFiles) else {
            DLOG("CheatOnlineLookup: no filename match for '\(title)' in \(system)")
            return nil
        }

        DLOG("CheatOnlineLookup: matched '\(best.name)' for title '\(title)'")
        return try? await fetchRawCht(system: system, filename: String(best.name.dropLast(4)))
    }

    // MARK: - Rate Limiting

    private func throttleAPIRequest() async {
        guard let last = lastAPIRequestDate else {
            lastAPIRequestDate = Date()
            return
        }
        let elapsed = Date().timeIntervalSince(last)
        if elapsed < Self.minAPIRequestInterval {
            let wait = Self.minAPIRequestInterval - elapsed
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
        lastAPIRequestDate = Date()
    }

    // MARK: - HTTP

    private func httpGet(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Provenance-Emu/Provenance", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // MARK: - .cht Parser

    /// Parse the libretro `.cht` file format into `CheatDatabaseEntry` values.
    ///
    /// Format:
    /// ```
    /// cheats = N
    /// cheat0_desc = "Description"
    /// cheat0_code = "CODE+MORE"
    /// cheat0_enable = false
    /// ```
    private func parseCht(_ text: String, romTitle: String, systemName: String?) -> [CheatDatabaseEntry] {
        var descs: [Int: String] = [:]
        var codes: [Int: String] = [:]

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                  let eqIdx = trimmed.firstIndex(of: "=") else { continue }

            let key = trimmed[..<eqIdx].trimmingCharacters(in: .whitespaces)
            let raw = trimmed[trimmed.index(after: eqIdx)...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

            if key.hasSuffix("_desc"), let n = cheatIndex(from: key, suffix: "_desc") {
                descs[n] = raw
            } else if key.hasSuffix("_code"), let n = cheatIndex(from: key, suffix: "_code") {
                codes[n] = raw
            }
        }

        return descs.keys.sorted().compactMap { n -> CheatDatabaseEntry? in
            guard let code = codes[n], !code.isEmpty else { return nil }
            let desc = descs[n] ?? "Cheat \(n)"
            return CheatDatabaseEntry(
                id: Self.idOffset + n,
                cheatName: desc,
                cheatCode: code,
                cheatDescription: nil,
                deviceName: "Libretro",
                deviceFormat: nil,
                category: "General",
                romTitle: romTitle,
                systemName: systemName,
                isOnlineResult: true
            )
        }
    }

    /// Extract the numeric index from keys like `cheat0_desc` → `0`, `cheat12_code` → `12`.
    private func cheatIndex(from key: String, suffix: String) -> Int? {
        guard key.hasSuffix(suffix) else { return nil }
        let stem = String(key.dropLast(suffix.count)) // e.g. "cheat0"
        // Find the last run of digits
        let digits = stem.reversed().prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        return Int(String(digits.reversed()))
    }

    // MARK: - Filename Sanitisation

    /// Convert a game title to a plausible libretro `.cht` filename stem.
    ///
    /// libretro cheat filenames closely mirror the ROM filename:
    /// `Super Mario World (USA)` → `Super Mario World (USA)`
    private func sanitiseFilename(_ title: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: " ()!'-.,"))
        return title
            .components(separatedBy: allowed.inverted)
            .joined(separator: "_")
    }

    // MARK: - Fuzzy Title Matching

    /// Return the file from `files` whose stem best matches `title` (Dice coefficient ≥ 0.6).
    private func bestMatch(for title: String, among files: [GitHubFileEntry]) -> GitHubFileEntry? {
        let normTitle = normalise(title)
        var bestFile: GitHubFileEntry?
        var bestScore = 0.6 // minimum threshold

        for file in files {
            let stem = String(file.name.dropLast(4)) // drop ".cht"
            let score = diceSimilarity(normTitle, normalise(stem))
            if score > bestScore {
                bestScore = score
                bestFile = file
            }
        }
        return bestFile
    }

    /// Normalise a string for comparison: lowercase and strip common region tags.
    private func normalise(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "(usa)", with: "")
            .replacingOccurrences(of: "(europe)", with: "")
            .replacingOccurrences(of: "(japan)", with: "")
            .replacingOccurrences(of: "(world)", with: "")
            .replacingOccurrences(of: "(en)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sørensen–Dice similarity coefficient over character bigrams.
    private func diceSimilarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }
        let aGrams = bigrams(a)
        let bGrams = bigrams(b)
        guard !aGrams.isEmpty || !bGrams.isEmpty else { return 0 }
        let intersection = aGrams.intersection(bGrams).count
        return 2.0 * Double(intersection) / Double(aGrams.count + bGrams.count)
    }

    private func bigrams(_ s: String) -> Set<String> {
        let chars = Array(s)
        guard chars.count >= 2 else { return [] }
        return Set((0..<chars.count - 1).map { String([chars[$0], chars[$0 + 1]]) })
    }

    // MARK: - Cache Key

    private func makeCacheKey(title: String, system: String?) -> String {
        "\(title.lowercased())__\(system?.lowercased() ?? "any")"
    }

    // MARK: - Disk Cache

    private var cacheDirectoryURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CheatOnlineLookup", isDirectory: true)
    }

    private func diskCacheFileURL(forKey key: String) -> URL? {
        var safe = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        if safe.count > 200 { safe = String(safe.prefix(200)) }
        return cacheDirectoryURL?.appendingPathComponent("\(safe).json")
    }

    private func loadDiskCache(forKey key: String) -> [CheatDatabaseEntry]? {
        guard let fileURL = diskCacheFileURL(forKey: key),
              let data = try? Data(contentsOf: fileURL),
              let cache = try? JSONDecoder().decode(DiskCache.self, from: data),
              Date().timeIntervalSince(cache.fetchedAt) < Self.cacheTTL
        else { return nil }

        return cache.entries.map {
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

// MARK: - GitHub API Model

private struct GitHubFileEntry: Decodable {
    let name: String
}
