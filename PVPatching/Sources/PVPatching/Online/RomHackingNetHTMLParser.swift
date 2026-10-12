//
//  RomHackingNetHTMLParser.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Best-effort parser for RomHacking.net entry pages.
public enum RomHackingNetHTMLParser: Sendable {

    public static func parseDetail(html: String, pageURL: URL) throws -> OnlinePatchInfo {
        guard DuckDuckGoHTMLParser.isRomHackingEntry(pageURL)
                || html.localizedCaseInsensitiveContains("romhacking") else {
            throw OnlinePatchDatabaseError.unsupportedURL
        }

        let id = pageURL.absoluteString
        let category = OnlinePatchCategory.infer(fromPath: pageURL.path)
        let title = extractTitle(from: html) ?? DuckDuckGoHTMLParser.cleanTitle(pageURL.lastPathComponent)
        let author = tableValue(in: html, labels: ["Author", "Authors", "Hack Author"])
        let version = tableValue(in: html, labels: ["Patch Version", "Version"])
        let platform = tableValue(in: html, labels: ["Platform", "System"])
        let language = tableValue(in: html, labels: ["Language"])
        let released = tableValue(in: html, labels: ["Released", "Release Date", "Date"])
        let description = extractDescription(from: html)
        let downloadURL = extractDownloadURL(from: html, base: pageURL)

        return OnlinePatchInfo(
            id: id,
            title: title,
            author: author,
            version: version,
            category: category,
            platformName: platform,
            language: language,
            patchDescription: description,
            pageURL: pageURL,
            downloadURL: downloadURL,
            releaseDateDescription: released
        )
    }

    public static func entryID(from url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        // /translations/6228/...
        if parts[1].allSatisfy(\.isNumber) {
            return parts[1]
        }
        return nil
    }

    // MARK: - Private

    private static func extractTitle(from html: String) -> String? {
        if let value = firstCapture(in: html, pattern: #"<h2[^>]*>(.*?)</h2>"#) {
            return value.strippingHTMLTags.htmlUnescaped.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value = firstCapture(in: html, pattern: #"<title[^>]*>(.*?)</title>"#) {
            return DuckDuckGoHTMLParser.cleanTitle(value.strippingHTMLTags.htmlUnescaped)
        }
        return nil
    }

    private static func tableValue(in html: String, labels: [String]) -> String? {
        for label in labels {
            let pattern = #"<t[dh][^>]*>\s*"#
                + NSRegularExpression.escapedPattern(for: label)
                + #"\s*</t[dh]>\s*<t[dh][^>]*>(.*?)</t[dh]>"#
            if let value = firstCapture(in: html, pattern: pattern) {
                let cleaned = value.strippingHTMLTags.htmlUnescaped
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    private static func extractDescription(from html: String) -> String? {
        let patterns = [
            #"class="entryDescription"[^>]*>(.*?)</div>"#,
            #"id="entryDescription"[^>]*>(.*?)</div>"#,
            #"<meta\s+name="description"\s+content="([^"]+)""#
        ]
        for pattern in patterns {
            if let value = firstCapture(in: html, pattern: pattern) {
                let cleaned = value.strippingHTMLTags.htmlUnescaped
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    private static func extractDownloadURL(from html: String, base: URL) -> URL? {
        let patterns = [
            #"href="(/download/\d+[^"]*)""#,
            #"href="(https?://www\.romhacking\.net/download/\d+[^"]*)""#
        ]
        for pattern in patterns {
            if let href = firstCapture(in: html, pattern: pattern)?.htmlUnescaped,
               let absolute = URL(string: href, relativeTo: base)?.absoluteURL {
                return absolute
            }
        }
        if let entryID = entryID(from: base) {
            return URL(string: "https://www.romhacking.net/download/\(entryID)")
        }
        return nil
    }

    private static func firstCapture(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ),
        let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
        match.numberOfRanges >= 2,
        let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range])
    }
}
