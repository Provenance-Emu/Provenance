//
//  RomFileProviderVirtualPath.swift
//  PVPrimitives
//
//  Identifier strings and encoding for the ROM File Provider virtual hierarchy.
//

import CryptoKit
import Foundation

/// Root category folders under the file provider root (each maps to a stable `NSFileProviderItemIdentifier` raw value).
public enum RomFileProviderRootCategory: String, CaseIterable, Sendable {
    /// `cat:systems` — browse by console, canonical ROM items and imports.
    case systems = "cat:systems"
    /// `cat:publishers` — browse by publisher metadata.
    case publishers = "cat:publishers"
    /// `cat:years` — browse by release year (from `publishDate`).
    case years = "cat:years"
    /// `cat:regions` — browse by `regionName`.
    case regions = "cat:regions"
    /// `cat:ratings` — browse by user star rating.
    case ratings = "cat:ratings"

    /// Folder title shown in Files.app.
    public var folderDisplayName: String {
        switch self {
        case .systems: "Systems"
        case .publishers: "Publishers"
        case .years: "Years"
        case .regions: "Regions"
        case .ratings: "Ratings"
        }
    }

    /// Raw identifier passed to `NSFileProviderItemIdentifier`.
    public var rawIdentifier: String { rawValue }
}

/// Encode/decode path segments and build deterministic symlink identifiers for the ROM File Provider.
public enum RomFileProviderVirtualPath {

    public static let publisherFolderPrefix = "pub:"
    public static let publisherAllGamesPrefix = "puball:"
    public static let publisherSystemPrefix = "pubsys:"
    public static let symlinkPrefix = "sym:"

    /// Normalized key used for grouping (lowercased trimmed, or a sentinel for missing values).
    public static let unknownGroupingKey = "__unknown__"

    // MARK: - Base64url (no padding)

    /// Encodes arbitrary UTF-8 text for use inside a single path segment (no `/` or unescaped `:` in payload).
    public static func encodeSegment(_ string: String) -> String {
        let data = Data(string.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes a segment produced by ``encodeSegment(_:)``.
    public static func decodeSegment(_ encoded: String) -> String? {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - base64.count % 4
        if pad < 4 {
            base64.append(String(repeating: "=", count: pad))
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Symlink identity

    /// Stable symlink item id: `sym:<encParent>:<md5>:<8-hex>` so the same ROM can appear under multiple parents
    /// without colliding and `resolveItem` can recover the parent container raw value.
    public static func symlinkIdentifier(gameMD5: String, parentItemRaw: String) -> String {
        let md5 = gameMD5.uppercased()
        let encParent = encodeSegment(parentItemRaw)
        let payload = Data("\(md5)|\(parentItemRaw)".utf8)
        let digest = SHA256.hash(data: payload)
        let suffix = digest.prefix(4).map { String(format: "%02x", $0) }.joined()
        return "\(symlinkPrefix)\(encParent):\(md5):\(suffix)"
    }

    /// Parses a symlink id; returns uppercase MD5 and decoded parent container raw value.
    public static func parseSymlink(from raw: String) -> (md5: String, parentItemRaw: String)? {
        guard raw.hasPrefix(symlinkPrefix) else { return nil }
        let rest = String(raw.dropFirst(symlinkPrefix.count))
        let parts = rest.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        let encParent = String(parts[0])
        let md5 = String(parts[1]).uppercased()
        let md5Pattern = "^[0-9A-Fa-f]{32}$"
        guard md5.count == 32, md5.range(of: md5Pattern, options: .regularExpression) != nil else { return nil }
        guard let parentRaw = decodeSegment(encParent) else { return nil }
        return (md5, parentRaw)
    }

    /// Returns uppercase MD5 from a symlink id (convenience for callers that only need the target game key).
    public static func parseSymlinkMD5(from raw: String) -> String? {
        parseSymlink(from: raw)?.md5
    }

    // MARK: - Metadata buckets

    /// Groups `publishDate` strings into a year folder key (`YYYY` or `Unknown`).
    public static func yearBucket(fromPublishDate publishDate: String?) -> String {
        guard let raw = publishDate?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "Unknown"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy"
        if dateFormatter.date(from: raw) != nil, raw.count == 4, raw.allSatisfy({ $0.isNumber }) {
            return raw
        }
        // First four consecutive digits anywhere in the string
        var digits = ""
        for character in raw where character.isNumber {
            digits.append(character)
            if digits.count == 4 { break }
        }
        if digits.count == 4, let yearValue = Int(digits), (1800...2100).contains(yearValue) {
            return digits
        }
        return "Unknown"
    }

    /// Normalized grouping key for publisher (or developer fallback in caller if desired).
    public static func publisherGroupingKey(_ publisher: String?) -> String {
        let trimmed = publisher?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return unknownGroupingKey }
        return trimmed.lowercased()
    }

    /// Normalized grouping key for region name.
    public static func regionGroupingKey(_ regionName: String?) -> String {
        let trimmed = regionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return unknownGroupingKey }
        return trimmed.lowercased()
    }

    /// Folder key and display name for user rating (`-1` = unrated).
    public static func ratingFolderKeyAndLabel(rating: Int) -> (key: String, label: String) {
        if rating < 0 || rating > 5 {
            return ("unrated", "Unrated")
        }
        if rating == 0 {
            return ("0", "0 stars")
        }
        if rating == 1 {
            return ("1", "1 star")
        }
        return ("\(rating)", "\(rating) stars")
    }

    /// Parses `rating:` folder raw values into an optional concrete star count (`nil` = unrated bucket).
    public static func ratingValue(fromRatingFolderKey key: String) -> Int? {
        if key == "unrated" { return nil }
        return Int(key)
    }
}
