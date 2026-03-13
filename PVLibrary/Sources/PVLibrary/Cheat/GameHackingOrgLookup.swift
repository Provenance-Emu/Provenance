// GameHackingOrgLookup.swift
// PVLibrary
//
// Actor-based service that fetches cheat codes from GameHacking.org via
// HTML scraping.  GameHacking.org has no public API, so the implementation
// parses the site's HTML output.  Results are cached aggressively to reduce
// network traffic and respect the site.
//
// Strategy:
//   1. Search by title (+ optional system filter): GET /search/?q=<title>&system=<slug>
//   2. Parse HTML search results to find the best-matching game link.
//   3. Fetch the game page: GET /game/<id>
//   4. Parse HTML to extract cheat code name/code pairs.
//
// IMPORTANT: This is an HTML scraper.  If GameHacking.org changes its site
// structure, the parsing logic in `parseSearchResults` or `parseCheatPage`
// will need updating.  Failures are caught and logged; the lookup returns
// an empty array rather than throwing, so the UI degrades gracefully.
//
// Caching: 24-hour disk + in-memory cache, same pattern as CheatOnlineLookup.

import Foundation
import PVLogging

// MARK: - GameHackingOrgLookup

/// Actor-based service for scraping cheat codes from GameHacking.org.
///
/// Call `GameHackingOrgLookup.shared.searchCheats(title:systemSlug:)` to
/// retrieve cheat codes for a game.  The `systemSlug` is the GameHacking.org
/// system identifier (e.g. `"gc"`, `"wii"`, `"gba"`) and is optional —
/// omitting it performs a title-only search across all systems.
///
/// Use `SystemIdentifier.gameHackingOrgSlug` to map a Provenance system to
/// the correct slug.
///
/// This lookup always returns an empty array rather than throwing when
/// parsing fails, so it is safe to add as a best-effort fallback source.
public actor GameHackingOrgLookup {

    public static let shared = GameHackingOrgLookup()

    // MARK: - Constants

    private static let baseURL = "https://gamehacking.org"
    private static let searchURL = "https://gamehacking.org/search/"
    private static let cacheTTL: TimeInterval = 24 * 3600
    private static let idOffset = 4_000_000
    private static let maxMemoryCacheEntries = 50
    /// Minimum seconds between requests to be polite to the server.
    private static let minRequestInterval: TimeInterval = 1.0

    // MARK: - State

    private var memoryCache: [String: (fetchedAt: Date, entries: [CheatDatabaseEntry])] = [:]
    private var lastRequestDate: Date?

    private init() {}

    // MARK: - Public API

    /// Search GameHacking.org for cheat codes.
    ///
    /// - Parameters:
    ///   - title: The game title to search for.
    ///   - systemSlug: Optional GameHacking.org system slug (e.g. `"gc"`, `"n64"`, `"gba"`).
    /// - Returns: Array of `CheatDatabaseEntry` values with `isOnlineResult == true`
    ///   and `deviceName == "GameHacking.org"`.  Returns empty on parse failure.
    public func searchCheats(title: String, systemSlug: String?) async -> [CheatDatabaseEntry] {
        let key = makeCacheKey(title: title, slug: systemSlug)

        // 1. Memory cache
        if let hit = memoryCache[key], Date().timeIntervalSince(hit.fetchedAt) < Self.cacheTTL {
            DLOG("GameHackingOrgLookup: memory cache hit for '\(title)'")
            return hit.entries
        }

        // 2. Disk cache
        if let diskHit = loadDiskCache(forKey: key) {
            DLOG("GameHackingOrgLookup: disk cache hit for '\(title)'")
            evictMemoryCacheIfNeeded()
            memoryCache[key] = (fetchedAt: diskHit.fetchedAt, entries: diskHit.entries)
            return diskHit.entries
        }

        // 3. Network fetch — never throws outward; always returns empty on failure.
        DLOG("GameHackingOrgLookup: fetching online for title='\(title)' slug=\(systemSlug ?? "nil")")
        let results = await fetchWithFallback(title: title, systemSlug: systemSlug)

        evictMemoryCacheIfNeeded()
        memoryCache[key] = (Date(), results)
        saveDiskCache(results, forKey: key)

        DLOG("GameHackingOrgLookup: \(results.count) codes for '\(title)'")
        return results
    }

    // MARK: - Fetch Logic

    /// Try fetching with system filter first; fall back to no-system search on failure.
    private func fetchWithFallback(title: String, systemSlug: String?) async -> [CheatDatabaseEntry] {
        // Strategy 1: search with system filter (if we have a slug)
        if let slug = systemSlug {
            if let results = await fetchSearchResults(title: title, systemSlug: slug),
               !results.isEmpty {
                return results
            }
        }
        // Strategy 2: search without system filter
        if let results = await fetchSearchResults(title: title, systemSlug: nil),
           !results.isEmpty {
            return results
        }
        return []
    }

    /// Perform a title search and return parsed cheat entries for the best match.
    private func fetchSearchResults(title: String, systemSlug: String?) async -> [CheatDatabaseEntry]? {
        guard let searchPageHTML = await fetchHTML(
            searchURLFor(title: title, systemSlug: systemSlug)
        ) else { return nil }

        // Find the best-matching game link in the search results HTML.
        guard let gamePagePath = bestGameLink(in: searchPageHTML, for: title) else {
            DLOG("GameHackingOrgLookup: no game link found in search results for '\(title)'")
            return nil
        }

        let gamePageURL = Self.baseURL + gamePagePath
        guard let gamePageHTML = await fetchHTML(gamePageURL) else { return nil }

        return parseCheatPage(gamePageHTML, title: title)
    }

    // MARK: - URL Construction

    private func searchURLFor(title: String, systemSlug: String?) -> String {
        guard var components = URLComponents(string: Self.searchURL) else {
            return Self.searchURL
        }
        var items = [URLQueryItem(name: "q", value: title)]
        if let slug = systemSlug {
            items.append(URLQueryItem(name: "system", value: slug))
        }
        components.queryItems = items
        return components.url?.absoluteString ?? Self.searchURL
    }

    // MARK: - HTML Fetching

    private func fetchHTML(_ urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        await throttle()
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (compatible; Provenance-Emu/1.0)", forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                DLOG("GameHackingOrgLookup: non-200 response from \(urlString)")
                return nil
            }
            return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        } catch {
            WLOG("GameHackingOrgLookup: fetch error for \(urlString): \(error)")
            return nil
        }
    }

    // MARK: - Search Result HTML Parser

    /// Extract game page paths from search results HTML.
    ///
    /// GameHacking.org search results contain links like:
    ///   `<a href="/game/12345">Game Title</a>`
    /// or similar patterns.  We use multiple regex strategies and pick
    /// the best title match.
    func bestGameLink(in html: String, for title: String) -> String? {
        // extractGameLinks tries multiple URL patterns (/game/ and /system/ style links).
        // Return the highest-scoring title match, or nil if no links were found.
        let gameLinks = extractGameLinks(from: html)
        return bestMatch(for: title, among: gameLinks)?.path
    }

    private struct GameLink {
        let path: String
        let title: String
    }

    private func extractGameLinks(from html: String) -> [GameLink] {
        var results: [GameLink] = []

        // Pattern: href="/game/<digits>" or href="/system/<slug>/<id>" style links
        // with text content as the title.
        let patterns = [
            // <a href="/game/12345">Game Title</a>
            #"href="(/game/[^"]+)"[^>]*>([^<]{3,80})</a>"#,
            // <a href="/system/\w+/\d+">Game Title</a>
            #"href="(/system/[^"]+)"[^>]*>([^<]{3,80})</a>"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let ns = html as NSString
            let range = NSRange(location: 0, length: ns.length)
            let matches = regex.matches(in: html, range: range)
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let path = ns.substring(with: match.range(at: 1))
                let title = ns.substring(with: match.range(at: 2))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .htmlDecoded
                results.append(GameLink(path: path, title: title))
            }
            if !results.isEmpty { break }
        }

        return results
    }

    // MARK: - Cheat Page HTML Parser

    /// Parse a GameHacking.org game page HTML to extract cheat entries.
    ///
    /// Multiple parsing strategies are tried in order:
    ///   1. Table rows with code/name columns (most common layout)
    ///   2. Definition list / dt+dd pairs
    ///   3. Plain code blocks
    func parseCheatPage(_ html: String, title: String) -> [CheatDatabaseEntry] {
        var entries: [CheatDatabaseEntry] = []

        // Strategy 1: table with code + name columns
        entries = parseTableCheats(html, romTitle: title)
        if !entries.isEmpty { return entries }

        // Strategy 2: definition list
        entries = parseDefinitionListCheats(html, romTitle: title)
        if !entries.isEmpty { return entries }

        // Strategy 3: inline code patterns
        entries = parseInlineCheats(html, romTitle: title)
        return entries
    }

    /// Parse cheat codes from HTML table rows.
    ///
    /// Expects a table with <tr> rows containing at minimum one cell with the
    /// cheat code (hex pattern) and one with the cheat name.
    func parseTableCheats(_ html: String, romTitle: String) -> [CheatDatabaseEntry] {
        var entries: [CheatDatabaseEntry] = []
        var index = 0

        // Extract all <tr> blocks
        let trPattern = #"<tr[^>]*>(.*?)</tr>"#
        guard let trRegex = try? NSRegularExpression(pattern: trPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let ns = html as NSString
        let trMatches = trRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))

        // Strip HTML tags helper
        func stripTags(_ s: String) -> String {
            s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
             .htmlDecoded
             .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Compile these regexes once before iterating rows to avoid repeated compilation overhead.
        let codePattern = try? NSRegularExpression(
            pattern: #"[0-9A-Fa-f]{4,16}[\s\+\-\:]*[0-9A-Fa-f]{0,16}"#
        )
        let tdPattern = #"<t[dh][^>]*>(.*?)</t[dh]>"#
        guard let tdRegex = try? NSRegularExpression(pattern: tdPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }

        for match in trMatches {
            let rowHTML = ns.substring(with: match.range(at: 1))

            // Extract <td> cells from the row
            let rowNS = rowHTML as NSString
            let tdMatches = tdRegex.matches(in: rowHTML, range: NSRange(location: 0, length: rowNS.length))
            let cells = tdMatches.map { stripTags(rowNS.substring(with: $0.range(at: 1))) }

            guard cells.count >= 2 else { continue }

            // Find which cell contains a code and which contains a name
            var codeCell: String?
            var nameCell: String?

            for cell in cells {
                if let pattern = codePattern,
                   pattern.firstMatch(in: cell, range: NSRange(cell.startIndex..., in: cell)) != nil,
                   cell.count >= 4,
                   codeCell == nil {
                    // Looks like a code
                    codeCell = cell
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: " ", with: "")
                } else if nameCell == nil, !cell.isEmpty, cell.count < 200 {
                    nameCell = cell
                }
            }

            guard let code = codeCell, let name = nameCell,
                  !code.isEmpty, !name.isEmpty,
                  name.lowercased() != "name", name.lowercased() != "code" // skip header rows
            else { continue }

            entries.append(CheatDatabaseEntry(
                id: Self.idOffset + index,
                cheatName: name,
                cheatCode: code,
                cheatDescription: nil,
                deviceName: "GameHacking.org",
                deviceFormat: nil,
                category: "General",
                romTitle: romTitle,
                systemName: nil,
                isOnlineResult: true
            ))
            index += 1
        }

        return entries
    }

    /// Parse cheat codes from definition list (dt/dd) HTML patterns.
    func parseDefinitionListCheats(_ html: String, romTitle: String) -> [CheatDatabaseEntry] {
        var entries: [CheatDatabaseEntry] = []
        var index = 0

        let dtddPattern = #"<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>"#
        guard let regex = try? NSRegularExpression(pattern: dtddPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))

        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let dt = stripHTML(ns.substring(with: match.range(at: 1)))
            let dd = stripHTML(ns.substring(with: match.range(at: 2)))
            guard !dt.isEmpty, !dd.isEmpty else { continue }

            // Determine which is name vs code by checking for hex content
            let (name, code) = looksLikeCode(dd) ? (dt, dd) : (dd, dt)
            guard looksLikeCode(code) else { continue }

            entries.append(CheatDatabaseEntry(
                id: Self.idOffset + index,
                cheatName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                cheatCode: code.trimmingCharacters(in: .whitespacesAndNewlines)
                               .replacingOccurrences(of: " ", with: ""),
                cheatDescription: nil,
                deviceName: "GameHacking.org",
                deviceFormat: nil,
                category: "General",
                romTitle: romTitle,
                systemName: nil,
                isOnlineResult: true
            ))
            index += 1
        }

        return entries
    }

    /// Last-resort: scan for inline code+name patterns anywhere in the HTML body.
    func parseInlineCheats(_ html: String, romTitle: String) -> [CheatDatabaseEntry] {
        var entries: [CheatDatabaseEntry] = []
        var index = 0

        // Look for patterns like: <span class="code">XXXXXXXX XXXXXXXX</span>...<span class="name">Name</span>
        let pattern = #"class="code"[^>]*>([0-9A-Fa-f\s]+)</[^>]+>.*?class="[^"]*name[^"]*"[^>]*>([^<]{2,80})<"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))

        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let code = ns.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")
            let name = ns.substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .htmlDecoded
            guard !code.isEmpty, !name.isEmpty else { continue }

            entries.append(CheatDatabaseEntry(
                id: Self.idOffset + index,
                cheatName: name,
                cheatCode: code,
                cheatDescription: nil,
                deviceName: "GameHacking.org",
                deviceFormat: nil,
                category: "General",
                romTitle: romTitle,
                systemName: nil,
                isOnlineResult: true
            ))
            index += 1
        }

        return entries
    }

    // MARK: - HTML Helpers

    private func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
         .htmlDecoded
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func looksLikeCode(_ s: String) -> Bool {
        let hex = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count >= 4 else { return false }
        let hexPattern = try? NSRegularExpression(pattern: #"^[0-9A-Fa-f\s\+]{4,}$"#)
        return hexPattern?.firstMatch(in: hex, range: NSRange(hex.startIndex..., in: hex)) != nil
    }

    // MARK: - Title Matching

    private func bestMatch(for title: String, among links: [GameLink]) -> GameLink? {
        let normTitle = normalise(title)
        var bestLink: GameLink?
        var bestScore = 0.4 // lower threshold than libretro since GameHacking.org titles vary more

        for link in links {
            let score = diceSimilarity(normTitle, normalise(link.title))
            if score > bestScore {
                bestScore = score
                bestLink = link
            }
        }
        return bestLink
    }

    private func normalise(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "(usa)", with: "")
            .replacingOccurrences(of: "(europe)", with: "")
            .replacingOccurrences(of: "(japan)", with: "")
            .replacingOccurrences(of: "(world)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func diceSimilarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }
        let aGrams = bigrams(a)
        let bGrams = bigrams(b)
        guard !aGrams.isEmpty, !bGrams.isEmpty else { return 0 }
        var intersection = 0
        for (gram, aCount) in aGrams {
            if let bCount = bGrams[gram] { intersection += min(aCount, bCount) }
        }
        return 2.0 * Double(intersection) / Double(aGrams.values.reduce(0, +) + bGrams.values.reduce(0, +))
    }

    private func bigrams(_ s: String) -> [String: Int] {
        let chars = Array(s)
        guard chars.count >= 2 else { return [:] }
        var freq: [String: Int] = [:]
        for i in 0..<(chars.count - 1) {
            let gram = String([chars[i], chars[i + 1]])
            freq[gram, default: 0] += 1
        }
        return freq
    }

    // MARK: - Rate Limiting

    private func throttle() async {
        guard let last = lastRequestDate else {
            lastRequestDate = Date()
            return
        }
        let elapsed = Date().timeIntervalSince(last)
        if elapsed < Self.minRequestInterval {
            let wait = Self.minRequestInterval - elapsed
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
        lastRequestDate = Date()
    }

    // MARK: - Memory Cache Eviction

    private func evictMemoryCacheIfNeeded() {
        if memoryCache.count >= Self.maxMemoryCacheEntries {
            let oldest = memoryCache.min { $0.value.fetchedAt < $1.value.fetchedAt }?.key
            if let oldest { memoryCache.removeValue(forKey: oldest) }
        }
    }

    // MARK: - Cache Key

    private func makeCacheKey(title: String, slug: String?) -> String {
        "ghorg__\(title.lowercased())__\(slug ?? "any")"
    }

    // MARK: - Disk Cache

    private var cacheDirectoryURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("GameHackingOrgLookup", isDirectory: true)
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
                    id: $0.id, cheatName: $0.cheatName, cheatCode: $0.cheatCode,
                    cheatDescription: $0.cheatDescription, deviceName: $0.deviceName,
                    deviceFormat: $0.deviceFormat, category: $0.category,
                    romTitle: $0.romTitle, systemName: $0.systemName
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

// MARK: - String HTML Decoding

private extension String {
    /// Decode common HTML entities.
    var htmlDecoded: String {
        self
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
