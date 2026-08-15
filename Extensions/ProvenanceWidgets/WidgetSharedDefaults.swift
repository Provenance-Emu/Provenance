//
//  WidgetSharedDefaults.swift
//  ProvenanceWidgets
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import Foundation
import CoreGraphics
import ImageIO
import UIKit
import PVLibrary

// MARK: - Shared UserDefaults Keys

/// Keys used to share data between the main app and widget extension via App Groups.
/// The main app writes these values; widgets read them.
///
/// **App Group ID note:** `appGroupID` here reads the `APP_GROUP_IDENTIFIER` build
/// setting from Info.plist at runtime (with fallback for dev/CI builds).  This is a
/// *necessary local copy* — the widget extension cannot import PVAppIntents.
/// Deep-link URL helpers use `PVLibrary` (`PVAppConstants`), which wraps primitives.

/// The canonical sources are:
///   - PVLibrary: `PVLibrary/Sources/PVFileSystem/Paths.swift` → `public let PVAppGroupId`
///   - PVAppIntents: `PVAppIntents/Sources/PVAppIntents/AppGroupID.swift` → `internal let pvAppGroupID`
/// All three must remain in sync with the `APP_GROUP_IDENTIFIER` build setting.
public enum WidgetSharedDefaults {
    static var appGroupID: String {
        let raw = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
        guard let raw, !raw.isEmpty, !raw.contains("$(") else {
            return "group.org.provenance-emu.provenance"
        }
        return raw
    }

    /// **These keys are a local mirror.** The canonical declarations live in
    /// `PVAppIntents/Sources/PVLibrarySnapshot/LibrarySnapshotKeys.swift`, which
    /// also carries the schema version, the `recentlyAddedGames` list, and a
    /// non-trapping reader (`LibrarySnapshotReader`).
    ///
    /// TODO: link `PVLibrarySnapshot` into the ProvenanceWidgets target and
    /// delete this mirror along with `WidgetGameEntry`/`WidgetNowPlayingEntry`,
    /// which duplicate `LibrarySnapshotGame`/`LibrarySnapshotNowPlaying`.
    public enum Keys {
        /// JSON-encoded array of `WidgetGameData` written by the host app; widgets decode this into `[WidgetGameEntry]` for recent games.
        static let recentGames = "widget.recentGames"
        /// JSON-encoded `WidgetNowPlayingData` written by the host app; widgets decode this into `WidgetNowPlayingEntry` for the currently-playing track.
        static let nowPlaying = "widget.nowPlaying"
        /// Total game count (Int).
        static let gameCount = "widget.gameCount"
        /// JSON-encoded array of `WidgetGameData` written by the host app; widgets decode this into `[WidgetGameEntry]` for the art gallery rotation.
        static let galleryGames = "widget.galleryGames"
        /// JSON-encoded array of `WidgetGameData` for favorite games, sorted by title.
        static let favoriteGames = "widget.favoriteGames"
        /// Total number of distinct systems in the library (Int).
        static let systemCount = "widget.systemCount"
        /// Aggregate play time across all games, in seconds (Int).
        static let totalPlayTime = "widget.totalPlayTime"
        /// Number of games marked as favorites (Int).
        static let favoritesCount = "widget.favoritesCount"
    }

    /// Returns the App Group `UserDefaults` suite, or `nil` if the suite is unavailable
    /// (e.g. missing entitlement). Callers show empty state when this is `nil` rather
    /// than falling back to `.standard`, which could mask configuration issues.
    static var shared: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}

// MARK: - Data Models

/// Minimal game representation written by the main app and read by widgets.
public struct WidgetGameEntry: Codable, Identifiable {
    public let id: String
    public let title: String
    public let systemName: String
    /// Reverse-DNS system id (e.g. `com.provenance.snes`) when present in shared JSON; drives per-system SF Symbols in widgets.
    public let systemIdentifier: String?
    /// Relative path inside the App Group container where box art is cached.
    ///
    /// Deliberately a path and **not** image bytes: WidgetKit keeps every entry of a
    /// timeline resident (and archives them) while it renders, so a `Data` payload here
    /// is multiplied by the entry count. Views resolve the path through
    /// `WidgetSharedDefaults.artworkImage(forRelativePath:maxPixelSize:)`, which decodes
    /// straight into the pixel budget it is drawn at.
    public let artworkPath: String?
    public let lastPlayedDate: Date?

    // MARK: Derived helpers (not stored)

    /// The game's MD5 hash identifier — same as `id`.
    public var md5Hash: String { id }

    /// Abbreviated system name displayed in badges. Falls back to `systemName`.
    public var systemShortName: String { systemName }

    /// Deep-link URL for launching the game from a widget tap.
    public var launchURL: URL? {
        guard !id.isEmpty else { return nil }
        return URL(string: PVOpenGameMD5URI(id))
    }

    public init(
        id: String,
        title: String,
        systemName: String,
        systemIdentifier: String? = nil,
        artworkPath: String? = nil,
        lastPlayedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.systemName = systemName
        self.systemIdentifier = systemIdentifier
        self.artworkPath = artworkPath
        self.lastPlayedDate = lastPlayedDate
    }
}

/// Library statistics written by the main app and read by the Library Stats widget.
public struct WidgetLibraryStats: Sendable {
    public let totalGames: Int
    public let totalSystems: Int
    public let totalPlayTimeSeconds: Int
    public let favoritesCount: Int

    public var totalPlayTimeFormatted: String {
        let hours = totalPlayTimeSeconds / 3600
        let minutes = (totalPlayTimeSeconds % 3600) / 60
        if hours > 0 {
            let format = NSLocalizedString(
                "widget.common.playtime-hours-minutes %lld %lld",
                bundle: .main,
                comment: "Library Stats total play time formatted as hours and minutes"
            )
            return String(format: format, locale: Locale.current, hours, minutes)
        }
        if minutes > 0 {
            let format = NSLocalizedString(
                "widget.common.playtime-minutes %lld",
                bundle: .main,
                comment: "Library Stats total play time formatted as minutes only"
            )
            return String(format: format, locale: Locale.current, minutes)
        }
        return String(
            localized: "widget.common.playtime-under-one-minute",
            defaultValue: "<1m",
            comment: "Library Stats total play time under one minute"
        )
    }
}

/// Now-playing track info written by the Music Player (#2654) and read by widgets.
public struct WidgetNowPlayingEntry: Codable {
    public let trackTitle: String
    public let artistName: String?
    public let albumTitle: String?
    /// Relative path inside the App Group container for cached album art.
    public let albumArtPath: String?
    public let timestamp: Date

    public init(
        trackTitle: String,
        artistName: String? = nil,
        albumTitle: String? = nil,
        albumArtPath: String? = nil
    ) {
        self.trackTitle = trackTitle
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.albumArtPath = albumArtPath
        self.timestamp = Date()
    }
}

// MARK: - Helpers

extension WidgetSharedDefaults {
    static func loadRecentGames() -> [WidgetGameEntry] {
        guard let data = shared?.data(forKey: Keys.recentGames) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetGameEntry].self, from: data)) ?? []
    }

    static func loadGalleryGames() -> [WidgetGameEntry] {
        guard let data = shared?.data(forKey: Keys.galleryGames) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetGameEntry].self, from: data)) ?? []
    }

    static func loadNowPlaying() -> WidgetNowPlayingEntry? {
        guard let data = shared?.data(forKey: Keys.nowPlaying) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetNowPlayingEntry.self, from: data)
    }

    static func loadGameCount() -> Int {
        shared?.integer(forKey: Keys.gameCount) ?? 0
    }

    /// Resolves a relative artwork path to a full URL inside the App Group container.
    static func artworkURL(forRelativePath path: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(path)
    }

    /// Returns up to `limit` recently-played games.
    static func loadRecentGames(limit: Int) -> [WidgetGameEntry] {
        Array(loadRecentGames().prefix(limit))
    }

    static func loadFavoriteGames() -> [WidgetGameEntry] {
        guard let data = shared?.data(forKey: Keys.favoriteGames) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetGameEntry].self, from: data)) ?? []
    }

    /// Returns up to `limit` favorite games.
    static func loadFavoriteGames(limit: Int) -> [WidgetGameEntry] {
        Array(loadFavoriteGames().prefix(limit))
    }

    static func loadLibraryStats() -> WidgetLibraryStats {
        guard let defaults = shared else {
            return WidgetLibraryStats(totalGames: 0, totalSystems: 0, totalPlayTimeSeconds: 0, favoritesCount: 0)
        }
        return WidgetLibraryStats(
            totalGames: defaults.integer(forKey: Keys.gameCount),
            totalSystems: defaults.integer(forKey: Keys.systemCount),
            totalPlayTimeSeconds: defaults.integer(forKey: Keys.totalPlayTime),
            favoritesCount: defaults.integer(forKey: Keys.favoritesCount)
        )
    }
}

// MARK: - Artwork decode budgets

/// Maximum pixel size (longest edge) to decode cover art at, per presentation.
///
/// **How these are derived.** Every value is `drawnPointSize × 3 × 1.5`:
/// * `× 3` — worst-case `@3x` iPhone display scale. Widgets render into the host
///   device's scale, and iPhone is the densest place these widgets appear.
/// * `× 1.5` — the box-art aspect factor. `scaledToFill` of a 3:4 cover into a box
///   that is wider than it is tall scales by `boxWidth / coverWidth`, so the cover's
///   *long* edge is drawn at `boxWidth × 1.5`. Sizing off the box width alone would
///   under-decode by a third.
///
/// `CGImageSourceCreateThumbnailAtIndex` never upscales, so a budget larger than the
/// source file is free — typical cover scans (~1000×1500) come back untouched at the
/// `hero` budget. Only a budget *below* the drawn size costs visible quality.
enum WidgetArtworkPixelBudget {

    /// Lock Screen accessory art: `accessoryCircular`, and the 40pt thumbnail in
    /// `accessoryRectangular` / `NowPlayingRectangularView`.
    /// 40pt × 3 × 1.5 = 180 → 192.
    static let accessory = 192

    /// Inset thumbnails up to 60pt: the StandBy Now Playing album thumbnail (60pt) and
    /// the Live Activity / Dynamic Island cover (16–56pt).
    /// 60pt × 3 × 1.5 = 270 → 288.
    static let inlineThumbnail = 288

    /// Cells in a dense grid — 5 or more covers rendered at once
    /// (Favorites `.systemLarge` 4×2, Favorites `.systemExtraLarge` 4×4,
    /// RecentlyPlayed `.systemExtraLarge`).
    ///
    /// Densest cell is Favorites `.systemLarge`: `(364 − 24 − 30) / 4 ≈ 77pt`
    /// → 77 × 3 × 1.5 ≈ 349. Largest is Favorites `.systemExtraLarge` on iPad
    /// (`@2x`): `(715 − 28 − 36) / 4 ≈ 163pt` → 163 × 2 × 1.5 ≈ 489. 512 covers both
    /// with no upscale, at 512 × 384 × 4 B ≈ 786 KB decoded per cover.
    static let denseGridCell = 512

    /// Cells in a sparse grid — 2 to 4 covers rendered at once
    /// (Favorites `.systemMedium`, RecentlyPlayed `.systemMedium` / `.systemLarge`).
    ///
    /// Largest such cell is Favorites `.systemMedium` 2-up: `(364 − 20 − 8) / 2 = 168pt`
    /// → 168 × 3 × 1.5 = 756 → 768.
    static let gridCell = 768

    /// A single cover filling the whole widget: the StandBy art gallery, the StandBy
    /// full-bleed background, and the `.systemSmall` hero cards.
    ///
    /// `.systemSmall` interior is ≈154pt → 154 × 3 × 1.5 ≈ 693, and StandBy enlarges a
    /// small widget to roughly a 330pt square → ≈ 990. 1024 covers both.
    ///
    /// Deliberately a *cap*: Favorites `.systemMedium` holding exactly one favorite
    /// stretches a cover across the full 344pt width, which would ask for ≈1548px.
    /// That layout crops the cover to a ~2.3:1 letterbox anyway, so the 1.5× upscale is
    /// accepted rather than paying 1152 × 1548 × 4 B ≈ 7 MB for one image.
    static let hero = 1024

    /// Budget for a system-family widget that draws `artworkCount` covers at once.
    ///
    /// Keyed on the count rather than the family because peak memory is
    /// `count × budget`: a lone cover can afford the full `hero` budget, a 4×4 grid
    /// cannot.
    static func budget(forSimultaneousArtworkCount artworkCount: Int) -> Int {
        switch artworkCount {
        case ...1: return hero
        case 2...4: return gridCell
        default: return denseGridCell
        }
    }
}

// MARK: - Artwork decoding

extension WidgetSharedDefaults {

    /// Options for `CGImageSourceCreateWithURL`.
    ///
    /// `kCGImageSourceShouldCache: false` stops the *source* from retaining a
    /// full-resolution decode next to the thumbnail we actually asked for.
    private static let artworkSourceOptions: CFDictionary = [
        kCGImageSourceShouldCache: false
    ] as CFDictionary

    /// Thumbnail options for a given pixel budget.
    ///
    /// * `FromImageAlways` — ignore the (usually tiny) embedded EXIF thumbnail.
    /// * `WithTransform` — honour EXIF orientation so rotated art is not flipped.
    /// * `ShouldCacheImmediately` — decode now, on the timeline/render thread, rather
    ///   than lazily at first draw.
    private static func artworkThumbnailOptions(maxPixelSize: Int) -> CFDictionary {
        [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
    }

    /// Decodes App Group artwork *directly* at no more than `maxPixelSize` on its
    /// longest edge.
    ///
    /// A widget extension has the tightest memory budget on iOS, and `UIImage(data:)`
    /// decodes at the source resolution no matter how small the image is drawn — a
    /// 1500×2000 cover costs ~12 MB whether it lands in a 40pt accessory circle or a
    /// full-bleed StandBy panel. `CGImageSourceCreateThumbnailAtIndex` decodes into the
    /// requested budget instead, so the full-resolution bitmap never exists. Resizing
    /// after the fact does not help: it still pays the full decode first.
    ///
    /// This mirrors `ArtworkDownsampler` in `PVMediaCache` (the canonical
    /// implementation, same ImageIO option set) rather than importing it: `PVMediaCache`
    /// pulls in RxSwift/RxCocoa/RxRealm/Realm, which is not weight this extension should
    /// carry for two ImageIO calls, and its `ArtworkDownsampleTarget` budgets are sized
    /// for in-app grids, not widget families.
    ///
    /// Reading through `CGImageSourceCreateWithURL` also memory-maps the file, so unlike
    /// `Data(contentsOf:)` the encoded bytes are never resident in full either.
    ///
    /// - Returns: `nil` when the path is unresolvable, undecodable, or is an iCloud
    ///   ubiquity placeholder that has not been downloaded yet — reading one of those
    ///   would block on a network fetch. Callers show their placeholder until a later
    ///   timeline refresh finds the file present.
    static func artworkImage(forRelativePath path: String, maxPixelSize: Int) -> UIImage? {
        guard let url = artworkURL(forRelativePath: path) else { return nil }
        if url.isUbiquitousPlaceholder { return nil }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, artworkSourceOptions),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(
                  source,
                  0,
                  artworkThumbnailOptions(maxPixelSize: maxPixelSize)
              )
        else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}

// MARK: - URL iCloud helpers

private extension URL {
    /// `true` when the URL points to an iCloud ubiquity item that has not yet been
    /// downloaded to this device.  Reading such a URL would trigger a blocking network
    /// fetch, so callers should treat it as absent and wait for the next refresh.
    var isUbiquitousPlaceholder: Bool {
        guard (try? resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true else {
            return false
        }
        let status = (try? resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus) ?? .notDownloaded
        return status != .current
    }
}
#endif
