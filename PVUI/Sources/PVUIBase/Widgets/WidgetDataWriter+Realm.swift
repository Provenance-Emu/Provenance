//
//  WidgetDataWriter+Realm.swift
//  PVUIBase
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Realm-backed convenience for pushing library state to the shared widget
//  UserDefaults.  Lives in PVUIBase (which depends on both PVLibrary and
//  PVAppIntents) so that WidgetDataWriter itself stays Realm-free.
//
//  Single source of truth for "read library → write widget data".
//  Call `WidgetDataWriter.shared.writeFromRealm()` from any mutation site
//  instead of duplicating the Realm queries inline.
//

#if canImport(PVAppIntents)
import PVAppIntents
import PVLibrary
import PVFileSystem
import PVSettings
import RealmSwift
import CryptoKit
import Defaults

public extension WidgetDataWriter {

    /// Reads the current library state from the shared Realm instance and writes
    /// widget-ready data to the App Group UserDefaults.
    ///
    /// Must be called on the **main thread** — uses `RomDatabase.sharedInstance`
    /// which is the main-thread Realm.
    ///
    /// Debouncing is handled inside `WidgetDataWriter`; rapid successive calls
    /// (e.g. during a batch import) coalesce into a single widget reload.
    @MainActor
    func writeFromRealm() {
        let database = RomDatabase.sharedInstance
        let allGames = database.all(PVGame.self)
        /// Exclude contentless pseudo-games (cores with no ROM) from widget data
        let realGames = allGames.filter("contentless == false")
        let totalCount = realGames.count
        guard totalCount > 0 else { return }

        let systemCount = database.all(PVSystem.self).count
        let totalPlayTime = realGames.sum(ofProperty: "timeSpentInGame") as Int
        let favoritesCount = realGames.filter("isFavorite == true").count

        var recentGames: [WidgetGameData] = Array(
            database.all(PVRecentGame.self)
                .sorted(byKeyPath: "lastPlayedDate", ascending: false)
                .prefix(LibrarySnapshotSchema.maxRecentGames)
        ).compactMap { recent in
            guard let game = recent.game, !game.isInvalidated, !game.contentless else { return nil }
            // PVRecentGame carries its own timestamp, which can be newer than PVGame.lastPlayed.
            return game.asSnapshotGame(lastPlayedOverride: recent.lastPlayedDate)
        }

        // Fall back to recently imported games when no games have been played yet.
        // NOTE: this makes "Recently Played" and "Recently Added" identical on a
        // fresh library — Top Shelf de-duplicates across sections for that reason.
        if recentGames.isEmpty {
            recentGames = Array(
                realGames.sorted(byKeyPath: "importDate", ascending: false)
                    .prefix(LibrarySnapshotSchema.maxGalleryGames)
            ).map { $0.asSnapshotGame }
        }

        // Favorites: up to 16 to cover the systemExtraLarge 4×4 grid.
        let favorites: [WidgetGameData] = Array(
            realGames.filter("isFavorite == true")
                .sorted(byKeyPath: "title", ascending: true)
                .prefix(LibrarySnapshotSchema.maxFavoriteGames)
        ).map { $0.asSnapshotGame }

        // Recently added: import-date order, consumed by the tvOS Top Shelf.
        let recentlyAdded: [WidgetGameData] = Array(
            realGames.sorted(byKeyPath: "importDate", ascending: false)
                .prefix(LibrarySnapshotSchema.maxRecentlyAddedGames)
        ).map { $0.asSnapshotGame }

        // Gallery: sample up to 12 *unique* games for the art-rotation widget.
        let galleryCount = min(LibrarySnapshotSchema.maxGalleryGames, totalCount)
        let gallery: [WidgetGameData]
        if totalCount <= galleryCount {
            gallery = Array(realGames.prefix(galleryCount)).map { $0.asSnapshotGame }
        } else {
            // Sample without replacement using unique random indices.
            var indices = Set<Int>(minimumCapacity: galleryCount)
            while indices.count < galleryCount {
                indices.insert(Int.random(in: 0..<totalCount))
            }
            gallery = indices.sorted().map { realGames[$0].asSnapshotGame }
        }

        writeGameData(
            recentGames: recentGames,
            galleryGames: gallery,
            favoriteGames: favorites,
            recentlyAddedGames: recentlyAdded,
            totalCount: totalCount,
            systemCount: systemCount,
            totalPlayTimeSeconds: totalPlayTime,
            favoritesCount: favoritesCount
        )
    }
}

// MARK: - PVGame → snapshot projection

private extension PVGame {
    /// Projects the Realm object into the value-type snapshot entry read by
    /// extensions.  Must be called on the thread that owns the Realm.
    var asSnapshotGame: WidgetGameData { asSnapshotGame(lastPlayedOverride: nil) }

    /// - Parameter lastPlayedOverride: `PVRecentGame.lastPlayedDate`, which can
    ///   be newer than `PVGame.lastPlayed`.
    func asSnapshotGame(lastPlayedOverride: Date?) -> WidgetGameData {
        WidgetGameData(
            id: md5Hash,
            title: title,
            systemName: system?.shortName ?? system?.name ?? "",
            systemIdentifier: systemIdentifier.isEmpty ? nil : systemIdentifier,
            artworkPath: widgetArtworkPath(for: self),
            lastPlayedDate: WidgetPlayActivityTimestamp.best(
                recentLastPlayed: lastPlayedOverride,
                gameLastPlayed: lastPlayed,
                importDate: importDate
            ),
            remoteArtworkURL: remoteArtworkURLString
        )
    }

    /// The http(s) artwork URL, used by Top Shelf when nothing is cached in the
    /// App Group container.  Empty local-cache keys (`PVMediaCache` hashes) are
    /// not URLs, so only absolute web URLs are surfaced.
    var remoteArtworkURLString: String? {
        let key = customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL
        guard !key.isEmpty,
              let components = URLComponents(string: key),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return key
    }
}

// MARK: - Artwork path resolution

/// Resolves a `PVGame`'s artwork to a relative path inside the App Group container,
/// suitable for `WidgetGameData.artworkPath`.
///
/// Always targets the App Group container (the only location widget extensions can
/// read), regardless of whether the main app's `useAppGroups` setting is enabled.
/// If the artwork exists in the local app sandbox but not yet in the App Group
/// container, it is copied on first call so subsequent widget refreshes find it.
///
/// Returns `nil` when the artwork key is empty, the App Group container is
/// unavailable, or the file cannot be found in either location.
private func widgetArtworkPath(for game: PVGame) -> String? {
    let artworkKey = game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL
    guard !artworkKey.isEmpty else { return nil }

    // Mirror PVMediaCache key derivation: MD5 hex digest of the URL string.
    let keyHash = Insecure.MD5.hash(data: Data(artworkKey.utf8))
        .map { String(format: "%02x", $0) }.joined()
    let relPath = "Documents/PVCache/\(keyHash)"

    // PVAppGroupId is the canonical constant (PVLibrary/PVFileSystem/Paths.swift).
    guard let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) else {
        return nil
    }

    let appGroupFile = container.appendingPathComponent(relPath)

    // Fast path: file already in App Group container.
    if FileManager.default.fileExists(atPath: appGroupFile.path) {
        return relPath
    }

    // Slow path: file is in the local app Documents sandbox (useAppGroups == false).
    // Copy it to the App Group container so the widget extension can read it.
    if let localDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let localFile = localDocs.appendingPathComponent("PVCache/\(keyHash)")
        if FileManager.default.fileExists(atPath: localFile.path) {
            let dir = appGroupFile.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: localFile, to: appGroupFile)
            return relPath
        }
    }

    return nil
}
#endif
