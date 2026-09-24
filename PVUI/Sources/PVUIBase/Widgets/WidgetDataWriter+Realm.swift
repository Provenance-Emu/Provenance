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
import PVLibrarySnapshot
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
    ///
    /// - Parameter forceIndex: Passed through to `writeLibraryIndex(force:)` to
    ///   bypass its 30s throttle (e.g. right after an import finishes).
    @MainActor
    func writeFromRealm(forceIndex: Bool = false) {
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
                .prefix(LibrarySnapshotSchema.recentGamesScanDepth)
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
                    .prefix(LibrarySnapshotSchema.maxRecentGames)
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

        writeLibraryIndex(force: forceIndex)
    }
}

// MARK: - Library index (Quick Look extensions)

/// Holds the throttle state for `writeLibraryIndex(force:)`.
///
/// `WidgetDataWriter` is `Sendable` (a plain final class), so a mutable
/// `static var` on it would be flagged as unsynchronized global mutable
/// state. `writeLibraryIndex` is `@MainActor`-only, so isolating the
/// throttle state to `@MainActor` here keeps the same 30s-throttle
/// semantics without introducing a lock.
@MainActor
private enum LibraryIndexThrottle {
    static let interval: TimeInterval = 30
    static var lastWrite: Date = .distantPast
}

public extension WidgetDataWriter {
    /// Writes the full library index the Quick Look extensions read. Throttled
    /// because it walks every game; `force` bypasses the throttle (import done).
    ///
    /// Only reads Realm fields into value types on the main actor — the
    /// filesystem work (artwork mirroring, save-state path relativisation) is
    /// deferred to the background `DispatchQueue` below so a large library
    /// doesn't block the main thread with hundreds of `fileExists`/`copyItem`
    /// calls.
    @MainActor
    func writeLibraryIndex(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(LibraryIndexThrottle.lastWrite) >= LibraryIndexThrottle.interval else { return }
        LibraryIndexThrottle.lastWrite = now

        let database = RomDatabase.sharedInstance
        let games: [LibraryIndexGame] = database.all(PVGame.self)
            .filter("contentless == false")
            .map { game in
                LibraryIndexGame(
                    filename: (game.romPath as NSString).lastPathComponent,
                    title: game.title,
                    systemName: game.system?.name ?? game.systemShortName,
                    systemIdentifier: game.systemIdentifier.isEmpty ? nil : game.systemIdentifier,
                    developer: emptyToNil(game.developer),
                    publishDate: emptyToNil(game.publishDate),
                    genre: emptyToNil(game.genres),
                    gameDescription: emptyToNil(game.gameDescription),
                    playCount: game.playCount,
                    isFavorite: game.isFavorite,
                    artworkKey: artworkKey(for: game))
            }

        // Raw artwork keys to mirror into the App Group container. The mirroring
        // itself (hash → fileExists → copyItem) is Realm-free filesystem work,
        // done in the background closure below.
        let artworkKeysToMirror: [String] = games.compactMap(\.artworkKey)

        let container = LibrarySnapshotAppGroup.containerURL
        let localDocuments = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        // Capture only plain values from each save state on the main actor.
        // `state.image?.url` is a Realm-object read and must happen here; the
        // container-prefix relativisation (string work, no I/O) moves to the
        // background closure.
        let saveStateEntries: [(filename: String, imageURL: URL?)] = database.all(PVSaveState.self).compactMap { state in
            guard let file = state.file, !file.partialPath.isEmpty else { return nil }
            return (filename: (file.partialPath as NSString).lastPathComponent, imageURL: state.image?.url)
        }

        let writer = LibraryIndexWriter(containerURL: container)
        DispatchQueue.global(qos: .utility).async {
            // Mirror local-only artwork into the App Group container so the
            // extensions can find it (side effect only — the index stores the
            // raw key, which `ArtworkResolver` hashes on read).
            for key in artworkKeysToMirror {
                _ = mirrorArtworkIntoGroup(key: key, containerURL: container, localDocuments: localDocuments)
            }

            let saves: [LibraryIndexSaveState] = saveStateEntries.compactMap { entry in
                guard let imageURL = entry.imageURL,
                      let container,
                      imageURL.path.hasPrefix(container.path) else { return nil }
                let rel = String(imageURL.path.dropFirst(container.path.count + 1))
                return LibraryIndexSaveState(filename: entry.filename, imageRelativePath: rel)
            }
            let skippedSaveCount = saveStateEntries.count - saves.count

            let ok = writer.write(games: games, saveStates: saves)
            DLOG("[WidgetDataWriter] library index write \(ok ? "ok" : "skipped") (\(games.count) games, \(saves.count) saves, \(skippedSaveCount) skipped outside group container)")
        }
    }

    private func emptyToNil(_ value: String?) -> String? {
        value.flatMap { $0.isEmpty ? nil : $0 }
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

/// Returns the raw `PVMediaCache` key for a game's artwork (the custom URL if set,
/// otherwise the original URL), or `nil` when neither is present.
///
/// Realm-object read only — no filesystem I/O. Must be called on the thread that
/// owns the Realm object (the main actor).
func artworkKey(for game: PVGame) -> String? {
    let key = game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL
    return key.isEmpty ? nil : key
}

/// Mirrors a cached artwork file — identified by its raw `PVMediaCache` key — into
/// the App Group container so widget/extension processes can read it, copying it
/// from the local app sandbox on first call if needed.
///
/// Realm-free: takes only plain values, so it is safe to call off the main actor
/// (e.g. from a background queue while indexing hundreds of games).
///
/// Always targets the App Group container (the only location widget extensions can
/// read), regardless of whether the main app's `useAppGroups` setting is enabled.
///
/// - Parameters:
///   - key: The raw artwork key, as returned by `artworkKey(for:)`.
///   - containerURL: The App Group container root (e.g. `LibrarySnapshotAppGroup.containerURL`).
///   - localDocuments: The local app Documents directory, used as a fallback source
///     when the artwork hasn't been mirrored into the App Group container yet.
/// - Returns: The path relative to `containerURL`, or `nil` when the key is empty,
///   `containerURL` is unavailable, or the file cannot be found in either location.
@discardableResult
func mirrorArtworkIntoGroup(key: String, containerURL: URL?, localDocuments: URL?) -> String? {
    guard !key.isEmpty, let containerURL else { return nil }

    // Mirror PVMediaCache key derivation: MD5 hex digest of the URL string.
    let keyHash = Insecure.MD5.hash(data: Data(key.utf8))
        .map { String(format: "%02x", $0) }.joined()
    let relPath = "Documents/PVCache/\(keyHash)"

    let appGroupFile = containerURL.appendingPathComponent(relPath)

    // Fast path: file already in App Group container.
    if FileManager.default.fileExists(atPath: appGroupFile.path) {
        return relPath
    }

    // Slow path: file is in the local app Documents sandbox (useAppGroups == false).
    // Copy it to the App Group container so the widget extension can read it.
    if let localDocuments {
        let localFile = localDocuments.appendingPathComponent("PVCache/\(keyHash)")
        if FileManager.default.fileExists(atPath: localFile.path) {
            let dir = appGroupFile.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: localFile, to: appGroupFile)
            return relPath
        }
    }

    return nil
}

/// Resolves a `PVGame`'s artwork to a relative path inside the App Group container,
/// suitable for `WidgetGameData.artworkPath`. Thin wrapper around `artworkKey(for:)`
/// + `mirrorArtworkIntoGroup(key:containerURL:localDocuments:)` used by
/// `writeFromRealm()`'s bounded (~100 game) snapshot arrays, where doing the
/// filesystem work inline on the main actor is acceptable.
///
/// Returns `nil` when the artwork key is empty, the App Group container is
/// unavailable, or the file cannot be found in either location.
func widgetArtworkPath(for game: PVGame) -> String? {
    guard let key = artworkKey(for: game) else { return nil }
    // PVAppGroupId is the canonical constant (PVLibrary/PVFileSystem/Paths.swift).
    let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)
    let localDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    return mirrorArtworkIntoGroup(key: key, containerURL: container, localDocuments: localDocs)
}
#endif
