//
//  ArtworkDownloadHealth.swift
//  PVLookup
//
//  Pure helpers for "is this artwork URL dead?" decisions, the order in which to try
//  replacement sources, and a bounded per-launch negative cache. No network or Realm here so
//  everything can be unit-tested.
//

import Foundation

// MARK: - Verdict

/// Outcome of judging one artwork download.
public enum ArtworkDownloadVerdict: Equatable, Sendable {
    /// Body is an image.
    case image
    /// The URL will not give us artwork: 403/404/410, or a non-image body served with 200.
    /// Callers should look for a different source.
    case dead(reason: String)
    /// Server error, rate limit or no response. The URL may work later, so keep it.
    case transient(reason: String)

    public var isDead: Bool {
        if case .dead = self { return true }
        return false
    }
}

// MARK: - Classifier

public enum ArtworkDownloadClassifier {
    /// HTTP statuses that mean the URL is unusable (Cloudflare challenge, removed, gone).
    public static let deadStatusCodes: Set<Int> = [403, 404, 410]

    /// Judge a response. `statusCode` is `nil` when the response was not HTTP.
    public static func classify(statusCode: Int?, data: Data) -> ArtworkDownloadVerdict {
        if let statusCode {
            if deadStatusCodes.contains(statusCode) {
                return .dead(reason: "HTTP \(statusCode)")
            }
            guard (200..<300).contains(statusCode) else {
                return .transient(reason: "HTTP \(statusCode)")
            }
        }
        guard looksLikeImage(data) else {
            return .dead(reason: data.isEmpty ? "empty body" : "non-image body (\(data.count) bytes)")
        }
        return .image
    }

    /// Cheap magic-byte sniff for the formats cover art is served in. An HTML challenge or
    /// error page served with 200 fails this.
    public static func looksLikeImage(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(12))
        guard bytes.count >= 4 else { return false }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return true }       // PNG
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return true }             // JPEG
        if bytes.starts(with: Array("GIF8".utf8)) { return true }             // GIF
        if bytes.starts(with: [0x42, 0x4D]) { return true }                   // BMP
        if bytes.starts(with: [0x49, 0x49, 0x2A, 0x00]) || bytes.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) { return true } // TIFF
        if bytes.count >= 12, bytes.starts(with: Array("RIFF".utf8)), Array(bytes[8..<12]) == Array("WEBP".utf8) { return true }
        if bytes.count >= 12, Array(bytes[4..<8]) == Array("ftyp".utf8) { return true } // HEIC / AVIF
        return false
    }
}

// MARK: - Fallback ordering

public enum ArtworkFallbackPlanner {
    /// Default cap on how many replacement URLs get downloaded per game.
    public static let defaultMaxAttempts = 4

    /// Order replacement candidates: libretro thumbnails first, then every other source,
    /// dropping the dead URL, anything already known dead, and duplicates.
    public static func order(
        libretro: [URL],
        others: [URL],
        excluding dead: Set<String>,
        isBlocked: (URL) -> Bool = { _ in false },
        maxAttempts: Int = defaultMaxAttempts
    ) -> [URL] {
        var seen = dead
        var result: [URL] = []
        for url in libretro + others {
            let key = url.absoluteString
            guard !seen.contains(key), !isBlocked(url) else { continue }
            seen.insert(key)
            result.append(url)
            if result.count >= maxAttempts { break }
        }
        return result
    }

    /// True for URLs served by the libretro thumbnail server.
    public static func isLibretroThumbnail(_ url: URL) -> Bool {
        url.host?.lowercased() == "thumbnails.libretro.com"
    }
}

// MARK: - Negative cache

/// Bounded, per-launch memory of artwork URLs (and games) that already failed, so one launch
/// does not hammer a blocked server. Never persisted: the next launch retries.
public actor ArtworkDeadURLCache {
    public static let shared = ArtworkDeadURLCache()

    private let maxEntries: Int
    private let hostBlockThreshold: Int
    private var deadURLs: Set<String> = []
    private var deadOrder: [String] = []
    private var forbiddenCounts: [String: Int] = [:]
    private var exhaustedGames: Set<String> = []
    private var exhaustedOrder: [String] = []

    public init(maxEntries: Int = 5000, hostBlockThreshold: Int = 3) {
        self.maxEntries = maxEntries
        self.hostBlockThreshold = hostBlockThreshold
    }

    /// Remember a dead URL. Repeated 403s from one host block the whole host for this launch,
    /// which is what a Cloudflare challenge on the user's network looks like.
    public func recordDead(_ url: URL, statusCode: Int? = nil) {
        Self.insert(url.absoluteString, into: &deadURLs, order: &deadOrder, limit: maxEntries)
        if statusCode == 403, let host = url.host?.lowercased() {
            forbiddenCounts[host, default: 0] += 1
        }
    }

    /// A successful download proves the host is reachable, so clear its 403 streak.
    public func recordSuccess(_ url: URL) {
        if let host = url.host?.lowercased() { forbiddenCounts[host] = nil }
    }

    public func isDead(_ url: URL) -> Bool {
        if deadURLs.contains(url.absoluteString) { return true }
        return isHostBlocked(url)
    }

    public func isHostBlocked(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return (forbiddenCounts[host] ?? 0) >= hostBlockThreshold
    }

    public func deadURLStrings() -> Set<String> { deadURLs }

    /// Every source for this game failed this launch; do not search again until `forgetExhausted`.
    public func markExhausted(gameKey: String) {
        Self.insert(gameKey, into: &exhaustedGames, order: &exhaustedOrder, limit: maxEntries)
    }

    public func isExhausted(gameKey: String) -> Bool { exhaustedGames.contains(gameKey) }

    /// Explicit refresh requests call this so the game is searched again.
    public func forgetExhausted(gameKey: String) {
        exhaustedGames.remove(gameKey)
        exhaustedOrder.removeAll { $0 == gameKey }
    }

    public func reset() {
        deadURLs.removeAll()
        deadOrder.removeAll()
        forbiddenCounts.removeAll()
        exhaustedGames.removeAll()
        exhaustedOrder.removeAll()
    }

    private static func insert(_ value: String, into set: inout Set<String>, order: inout [String], limit: Int) {
        guard set.insert(value).inserted else { return }
        order.append(value)
        if order.count > limit {
            set.remove(order.removeFirst())
        }
    }
}
