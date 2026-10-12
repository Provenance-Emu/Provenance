//
//  RomHackingNetDatabase.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// RomHacking.net catalog client.
///
/// RomHacking.net itself is often behind Cloudflare bot challenges, so search
/// discovery uses DuckDuckGo HTML (`site:romhacking.net`). Detail/download
/// requests still try RHDN directly and surface ``OnlinePatchDatabaseError/blockedByUpstream``
/// when a challenge page is returned — the UI can then open Safari.
public actor RomHackingNetDatabase: PatchDatabase {
    public static let shared = RomHackingNetDatabase()

    public nonisolated let displayName = "RomHacking.net"

    private let session: URLSession
    private let rateLimiter: PatchDatabaseRateLimiter
    private let userAgent = "Provenance/1.0 (Online Patch Search; +https://provenance-emu.com)"

    /// Extensions we accept from a Content-Disposition / URL filename.
    private static let downloadExtensions: Set<String> = PatchFormat.implementedFileExtensions
        .union(["zip", "7z", "rar"])

    public init(
        session: URLSession = .shared,
        rateLimiter: PatchDatabaseRateLimiter = PatchDatabaseRateLimiter()
    ) {
        self.session = session
        self.rateLimiter = rateLimiter
    }

    // MARK: - PatchDatabase

    public func search(
        query: String,
        filter: OnlinePatchSearchFilter
    ) async throws -> [OnlinePatchSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OnlinePatchDatabaseError.invalidQuery }

        var terms = [trimmed, "site:romhacking.net"]
        if let category = filter.category, let path = category.romHackingPathComponent {
            terms.append("inurl:\(path)")
        }
        if let platform = filter.platformQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !platform.isEmpty {
            terms.append(platform)
        }
        if let author = filter.author?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty {
            terms.append(author)
        }

        let ddgQuery = terms.joined(separator: " ")
        let cacheKey = "search:" + ddgQuery.lowercased()
        if let cached = await rateLimiter.cachedData(for: cacheKey),
           let html = String(data: cached, encoding: .utf8) {
            return DuckDuckGoHTMLParser.parseSearchResults(html)
        }

        guard var components = URLComponents(string: "https://html.duckduckgo.com/html/") else {
            throw OnlinePatchDatabaseError.network("Invalid search URL")
        }
        components.queryItems = [URLQueryItem(name: "q", value: ddgQuery)]
        guard let url = components.url else {
            throw OnlinePatchDatabaseError.network("Invalid search URL")
        }

        let (data, _) = try await fetchData(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw OnlinePatchDatabaseError.parseFailed("Search response was not UTF-8 text")
        }
        if Self.isSearchChallenge(html) {
            throw OnlinePatchDatabaseError.searchBlocked
        }
        let results = DuckDuckGoHTMLParser.parseSearchResults(html)
        await rateLimiter.store(data, for: cacheKey)
        ILOG("RomHackingNetDatabase: search '\(trimmed)' → \(results.count) hit(s)")
        return results
    }

    public func fetchPatchInfo(id: String) async throws -> OnlinePatchInfo {
        guard let pageURL = URL(string: id), DuckDuckGoHTMLParser.isRomHackingEntry(pageURL) else {
            throw OnlinePatchDatabaseError.unsupportedURL
        }

        let cacheKey = "detail:" + pageURL.absoluteString
        if let cached = await rateLimiter.cachedData(for: cacheKey),
           let html = String(data: cached, encoding: .utf8) {
            return try RomHackingNetHTMLParser.parseDetail(html: html, pageURL: pageURL)
        }

        do {
            let (data, _) = try await fetchData(from: pageURL)
            guard let html = String(data: data, encoding: .utf8) else {
                throw OnlinePatchDatabaseError.parseFailed("Detail response was not UTF-8 text")
            }
            if Self.isCloudflareChallenge(html) {
                // Never cache a challenge page — the next retry must hit the network.
                throw OnlinePatchDatabaseError.blockedByUpstream
            }
            let info = try RomHackingNetHTMLParser.parseDetail(html: html, pageURL: pageURL)
            await rateLimiter.store(data, for: cacheKey)
            return info
        } catch let error as OnlinePatchDatabaseError {
            throw error
        } catch {
            // Fall back to sparse info from the URL itself so the UI can still open Safari.
            WLOG("RomHackingNetDatabase: detail fetch failed — \(error.localizedDescription)")
            throw OnlinePatchDatabaseError.blockedByUpstream
        }
    }

    public func downloadPatch(
        id: String,
        to directory: URL,
        progress: (@Sendable (OnlinePatchDownloadProgress) -> Void)?
    ) async throws -> URL {
        let info = try await fetchPatchInfo(id: id)
        guard let downloadURL = info.downloadURL else {
            throw OnlinePatchDatabaseError.downloadFailed("No download link available — open the page in Safari")
        }

        progress?(OnlinePatchDownloadProgress(fractionCompleted: 0.05, status: "Downloading…"))
        let data: Data
        let response: HTTPURLResponse?
        do {
            (data, response) = try await fetchData(from: downloadURL)
        } catch {
            throw OnlinePatchDatabaseError.downloadFailed(error.localizedDescription)
        }

        if let text = String(data: data.prefix(512), encoding: .utf8), Self.isCloudflareChallenge(text) {
            throw OnlinePatchDatabaseError.blockedByUpstream
        }

        // Reject HTML error pages masquerading as downloads.
        if let head = String(data: data.prefix(64), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           head.hasPrefix("<!doctype") || head.hasPrefix("<html") {
            throw OnlinePatchDatabaseError.blockedByUpstream
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = Self.suggestedFilename(
            for: info,
            downloadURL: downloadURL,
            contentDisposition: response?.value(forHTTPHeaderField: "Content-Disposition"),
            data: data
        )
        var destination = directory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            let stem = destination.deletingPathExtension().lastPathComponent
            let ext = destination.pathExtension
            destination = directory.appendingPathComponent("\(stem)-\(UUID().uuidString.prefix(8)).\(ext)")
        }
        try data.write(to: destination, options: .atomic)
        progress?(OnlinePatchDownloadProgress(fractionCompleted: 1.0, status: "Done"))
        ILOG("RomHackingNetDatabase: downloaded \(destination.lastPathComponent) (\(data.count) bytes)")
        return destination
    }

    /// Direct Safari URL for a query (used when in-app fetch is blocked).
    public nonisolated func safariSearchURL(query: String, filter: OnlinePatchSearchFilter = .empty) -> URL? {
        var terms = [query.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let category = filter.category, let path = category.romHackingPathComponent {
            terms.append(path)
        }
        if let platform = filter.platformQuery, !platform.isEmpty {
            terms.append(platform)
        }
        let joined = terms.filter { !$0.isEmpty }.joined(separator: " ")
        var components = URLComponents(string: "https://www.romhacking.net/")
        // RHDN advanced search query param; still useful as a landing page.
        components?.queryItems = [
            URLQueryItem(name: "page", value: "search"),
            URLQueryItem(name: "advsearch", value: "y"),
            URLQueryItem(name: "search", value: joined),
            URLQueryItem(name: "stype", value: "entry")
        ]
        return components?.url
    }

    // MARK: - Internals

    /// Rate-limited GET. Callers validate the body and decide whether to cache it;
    /// nothing is stored here so challenge/anomaly pages never poison the cache.
    private func fetchData(from url: URL) async throws -> (Data, HTTPURLResponse?) {
        await rateLimiter.waitIfNeeded()

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/octet-stream,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            if let http, !(200...299).contains(http.statusCode) {
                if http.statusCode == 403 || http.statusCode == 429 || http.statusCode == 503 {
                    throw OnlinePatchDatabaseError.blockedByUpstream
                }
                throw OnlinePatchDatabaseError.network("HTTP \(http.statusCode)")
            }
            return (data, http)
        } catch let error as OnlinePatchDatabaseError {
            throw error
        } catch {
            throw OnlinePatchDatabaseError.network(error.localizedDescription)
        }
    }

    static func isCloudflareChallenge(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("cf-mitigated")
            || lower.contains("cdn-cgi/challenge")
            || lower.contains("just a moment...")
            || (lower.contains("cloudflare") && lower.contains("enable javascript"))
    }

    /// DuckDuckGo's HTML endpoint answers suspected bots with an "anomaly" page (HTTP 200,
    /// no result markup). Treat that as a block rather than an empty result set.
    static func isSearchChallenge(_ html: String) -> Bool {
        let lower = html.lowercased()
        guard !lower.contains("result__a") else { return false }
        return lower.contains("anomaly")
            || lower.contains("unusual traffic")
            || lower.contains("captcha")
            || lower.contains("challenge-form")
            || lower.contains("bot detection")
    }

    /// Pick a filename whose extension reflects the actual payload.
    ///
    /// RHDN serves `/download/{id}` with no extension and usually as a ZIP, so the order is:
    /// Content-Disposition filename → URL filename → magic bytes → `.zip` for PK archives
    /// → `.bps` as a last resort.
    static func suggestedFilename(
        for info: OnlinePatchInfo,
        downloadURL: URL,
        contentDisposition: String?,
        data: Data
    ) -> String {
        if let header = contentDisposition,
           let name = filename(fromContentDisposition: header),
           downloadExtensions.contains((name as NSString).pathExtension.lowercased()) {
            return sanitized(name)
        }
        let last = downloadURL.lastPathComponent
        if downloadExtensions.contains((last as NSString).pathExtension.lowercased()) {
            return sanitized(last)
        }

        let stem = sanitized(info.title)
        let fallbackStem: String = {
            if !stem.isEmpty { return stem }
            if let entryID = RomHackingNetHTMLParser.entryID(from: downloadURL)
                ?? RomHackingNetHTMLParser.entryID(from: info.pageURL) {
                return "rhdn-\(entryID)"
            }
            return "patch"
        }()

        if let format = PatchFormat.detect(fromMagic: data), let ext = format.fileExtensions.first {
            return "\(fallbackStem).\(ext)"
        }
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) || data.starts(with: [0x50, 0x4B, 0x05, 0x06]) {
            return "\(fallbackStem).zip"
        }
        if data.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) {
            return "\(fallbackStem).7z"
        }
        if data.starts(with: [0x52, 0x61, 0x72, 0x21]) {
            return "\(fallbackStem).rar"
        }
        return "\(fallbackStem).bps"
    }

    /// `attachment; filename="x.zip"` or RFC 5987 `filename*=UTF-8''x.zip`.
    static func filename(fromContentDisposition header: String) -> String? {
        for part in header.split(separator: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if lower.hasPrefix("filename*=") {
                var value = String(trimmed.dropFirst("filename*=".count))
                if let quote = value.range(of: "''") {
                    value = String(value[quote.upperBound...])
                }
                let unquoted = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if let decoded = unquoted.removingPercentEncoding, !decoded.isEmpty { return decoded }
            } else if lower.hasPrefix("filename=") {
                let value = String(trimmed.dropFirst("filename=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    private static func sanitized(_ name: String) -> String {
        let last = (name as NSString).lastPathComponent // drop any directory component
        return last
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
