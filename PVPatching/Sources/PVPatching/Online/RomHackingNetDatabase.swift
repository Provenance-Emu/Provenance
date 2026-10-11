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
    private let userAgent = "Provenance/1.0 (iOS; Online Patch Search; +https://provenance-emu.com)"

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

        let data = try await fetchData(from: url, cacheKey: cacheKey)
        guard let html = String(data: data, encoding: .utf8) else {
            throw OnlinePatchDatabaseError.parseFailed("Search response was not UTF-8 text")
        }
        let results = DuckDuckGoHTMLParser.parseSearchResults(html)
        ILOG("RomHackingNetDatabase: search '\(trimmed)' → \(results.count) hit(s)")
        return results
    }

    public func fetchPatchInfo(id: String) async throws -> OnlinePatchInfo {
        guard let pageURL = URL(string: id), DuckDuckGoHTMLParser.isRomHackingEntry(pageURL) else {
            throw OnlinePatchDatabaseError.unsupportedURL
        }

        let cacheKey = "detail:" + pageURL.absoluteString
        if let cached = await rateLimiter.cachedData(for: cacheKey),
           let html = String(data: cached, encoding: .utf8),
           !isCloudflareChallenge(html) {
            return try RomHackingNetHTMLParser.parseDetail(html: html, pageURL: pageURL)
        }

        do {
            let data = try await fetchData(from: pageURL, cacheKey: cacheKey)
            guard let html = String(data: data, encoding: .utf8) else {
                throw OnlinePatchDatabaseError.parseFailed("Detail response was not UTF-8 text")
            }
            if isCloudflareChallenge(html) {
                throw OnlinePatchDatabaseError.blockedByUpstream
            }
            return try RomHackingNetHTMLParser.parseDetail(html: html, pageURL: pageURL)
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
        do {
            data = try await fetchData(from: downloadURL, cacheKey: nil)
        } catch {
            throw OnlinePatchDatabaseError.downloadFailed(error.localizedDescription)
        }

        if let text = String(data: data.prefix(256), encoding: .utf8), isCloudflareChallenge(text) {
            throw OnlinePatchDatabaseError.blockedByUpstream
        }

        // Reject HTML error pages masquerading as downloads.
        let lowerNameHint = downloadURL.lastPathComponent.lowercased()
        let looksLikePatch = ["ips", "bps", "ups", "xdelta", "ppf", "zip", "7z", "rar"]
            .contains(where: { lowerNameHint.hasSuffix(".\($0)") })
        if !looksLikePatch, let head = String(data: data.prefix(64), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           head.hasPrefix("<!doctype") || head.hasPrefix("<html") {
            throw OnlinePatchDatabaseError.blockedByUpstream
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = suggestedFilename(for: info, downloadURL: downloadURL)
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

    private func fetchData(from url: URL, cacheKey: String?) async throws -> Data {
        if let cacheKey, let cached = await rateLimiter.cachedData(for: cacheKey) {
            return cached
        }
        await rateLimiter.waitIfNeeded()

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/octet-stream,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                if http.statusCode == 403 || http.statusCode == 503 {
                    throw OnlinePatchDatabaseError.blockedByUpstream
                }
                throw OnlinePatchDatabaseError.network("HTTP \(http.statusCode)")
            }
            if let cacheKey {
                await rateLimiter.store(data, for: cacheKey)
            }
            return data
        } catch let error as OnlinePatchDatabaseError {
            throw error
        } catch {
            throw OnlinePatchDatabaseError.network(error.localizedDescription)
        }
    }

    private nonisolated func isCloudflareChallenge(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("cf-mitigated")
            || lower.contains("cdn-cgi/challenge")
            || lower.contains("just a moment...")
            || (lower.contains("cloudflare") && lower.contains("enable javascript"))
    }

    private nonisolated func suggestedFilename(for info: OnlinePatchInfo, downloadURL: URL) -> String {
        let last = downloadURL.lastPathComponent
        if last.contains("."), last.lowercased() != "download" {
            return last
        }
        let stem = info.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = stem.isEmpty ? "patch-\(info.id.hashValue)" : stem
        return "\(safe).bps"
    }
}
