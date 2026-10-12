//
//  DuckDuckGoHTMLParser.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Parses DuckDuckGo HTML search results for RomHacking.net entry links.
public enum DuckDuckGoHTMLParser: Sendable {

    public static func parseSearchResults(_ html: String) -> [OnlinePatchSearchResult] {
        var results: [OnlinePatchSearchResult] = []
        var seen = Set<String>()

        // DDG wraps destinations in /l/?uddg=<urlencoded>
        let linkPattern = #"class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(
            pattern: linkPattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let ns = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
        for match in matches {
            guard match.numberOfRanges >= 3,
                  let hrefRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else { continue }

            let href = String(html[hrefRange]).htmlUnescaped
            guard let destination = resolveDestinationURL(from: href),
                  isRomHackingEntry(destination) else { continue }

            let id = destination.absoluteString
            guard seen.insert(id).inserted else { continue }

            let rawTitle = String(html[titleRange]).strippingHTMLTags.htmlUnescaped
            let title = cleanTitle(rawTitle)
            let category = OnlinePatchCategory.infer(fromPath: destination.path)
            let snippet = nearbySnippet(in: html, around: match.range)

            results.append(
                OnlinePatchSearchResult(
                    id: id,
                    title: title,
                    category: category,
                    snippet: snippet,
                    pageURL: destination
                )
            )
        }
        return results
    }

    public static func resolveDestinationURL(from href: String) -> URL? {
        var candidate = href
        if candidate.hasPrefix("//") {
            candidate = "https:" + candidate
        }
        guard let url = URL(string: candidate) else { return nil }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let uddg = components.queryItems?.first(where: { $0.name == "uddg" })?.value,
           let decoded = URL(string: uddg) {
            return decoded
        }
        return url
    }

    public static func isRomHackingEntry(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), host.contains("romhacking.net") else { return false }
        let path = url.path.lowercased()
        let prefixes = ["/translations/", "/hacks/", "/improvements/", "/bugfixes/", "/patches/"]
        guard let match = prefixes.first(where: { path.contains($0) }) else { return false }
        // Require a numeric id after the category segment.
        guard let range = path.range(of: match) else { return false }
        let rest = path[range.upperBound...]
        let idPart = rest.split(separator: "/").first.map(String.init) ?? ""
        return !idPart.isEmpty && idPart.allSatisfy(\.isNumber)
    }

    public static func cleanTitle(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Romhacking.net - Translations - ",
            "Romhacking.net - Hacks - ",
            "Romhacking.net - Improvements - ",
            "Romhacking.net - Bug Fixes - ",
            "Romhacking.net - Patches - ",
            "Romhacking.net - "
        ]
        for prefix in prefixes where title.hasPrefix(prefix) {
            title = String(title.dropFirst(prefix.count))
        }
        if title.hasSuffix(" - Romhacking.net") {
            title = String(title.dropLast(" - Romhacking.net".count))
        }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nearbySnippet(in html: String, around range: NSRange) -> String? {
        let ns = html as NSString
        let start = max(0, range.location)
        // The snippet anchor follows the title anchor within the same result block;
        // stop at the next result's title so we never borrow a neighbour's snippet.
        var end = min(ns.length, range.location + range.length + 4000)
        let nextTitle = ns.range(
            of: "class=\"result__a\"",
            options: [.caseInsensitive],
            range: NSRange(location: min(ns.length, range.location + range.length), length: end - min(ns.length, range.location + range.length))
        )
        if nextTitle.location != NSNotFound {
            end = nextTitle.location
        }
        let window = ns.substring(with: NSRange(location: start, length: end - start))
        // Capture through the closing anchor — DDG bolds query terms with <b>, so
        // stopping at the first closing tag would truncate the snippet.
        guard let regex = try? NSRegularExpression(
            pattern: #"class="result__snippet"[^>]*>(.*?)</a>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ),
        let match = regex.firstMatch(in: window, options: [], range: NSRange(location: 0, length: (window as NSString).length)),
        match.numberOfRanges >= 2,
        let r = Range(match.range(at: 1), in: window) else {
            return nil
        }
        let cleaned = String(window[r]).strippingHTMLTags.htmlUnescaped
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}

extension String {
    /// Cheap HTML entity decode — avoids NSAttributedString (AppKit/UIKit-only on some hosts).
    var htmlUnescaped: String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    var strippingHTMLTags: String {
        replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    }
}
