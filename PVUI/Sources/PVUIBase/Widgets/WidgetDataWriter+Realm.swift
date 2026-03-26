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
        let totalCount = allGames.count
        guard totalCount > 0 else { return }

        let systemCount = database.all(PVSystem.self).count
        let totalPlayTime = allGames.sum(ofProperty: "timeSpentInGame") as Int
        let favoritesCount = allGames.filter("isFavorite == true").count

        var recentGames: [WidgetGameData] = Array(
            database.all(PVRecentGame.self)
                .sorted(byKeyPath: "lastPlayedDate", ascending: false)
                .prefix(12)
        ).compactMap { recent in
            guard let game = recent.game, !game.isInvalidated else { return nil }
            return WidgetGameData(
                id: game.md5Hash,
                title: game.title,
                systemName: game.system?.shortName ?? game.system?.name ?? "",
                systemIdentifier: game.systemIdentifier.isEmpty ? nil : game.systemIdentifier,
                artworkPath: widgetArtworkPath(for: game),
                lastPlayedDate: WidgetPlayActivityTimestamp.best(
                    recentLastPlayed: recent.lastPlayedDate,
                    gameLastPlayed: game.lastPlayed,
                    importDate: game.importDate
                )
            )
        }

        // Fall back to recently imported games when no games have been played yet.
        if recentGames.isEmpty {
            recentGames = Array(
                allGames.sorted(byKeyPath: "importDate", ascending: false)
                    .prefix(12)
            ).map { game in
                WidgetGameData(
                    id: game.md5Hash,
                    title: game.title,
                    systemName: game.system?.shortName ?? game.system?.name ?? "",
                    systemIdentifier: game.systemIdentifier.isEmpty ? nil : game.systemIdentifier,
                    artworkPath: widgetArtworkPath(for: game),
                    lastPlayedDate: WidgetPlayActivityTimestamp.best(
                        recentLastPlayed: nil,
                        gameLastPlayed: game.lastPlayed,
                        importDate: game.importDate
                    )
                )
            }
        }

        // Favorites: up to 16 to cover the systemExtraLarge 4×4 grid.
        let favorites: [WidgetGameData] = Array(
            allGames.filter("isFavorite == true")
                .sorted(byKeyPath: "title", ascending: true)
                .prefix(16)
        ).map {
            WidgetGameData(id: $0.md5Hash, title: $0.title,
                           systemName: $0.system?.shortName ?? "",
                           systemIdentifier: $0.systemIdentifier.isEmpty ? nil : $0.systemIdentifier,
                           artworkPath: widgetArtworkPath(for: $0))
        }

        // Gallery: sample up to 12 *unique* games for the art-rotation widget.
        let galleryCount = min(12, totalCount)
        let gallery: [WidgetGameData]
        if totalCount <= galleryCount {
            gallery = Array(allGames.prefix(galleryCount)).map {
                WidgetGameData(id: $0.md5Hash, title: $0.title,
                               systemName: $0.system?.shortName ?? "",
                               systemIdentifier: $0.systemIdentifier.isEmpty ? nil : $0.systemIdentifier,
                               artworkPath: widgetArtworkPath(for: $0))
            }
        } else {
            // Sample without replacement using unique random indices.
            var indices = Set<Int>(minimumCapacity: galleryCount)
            while indices.count < galleryCount {
                indices.insert(Int.random(in: 0..<totalCount))
            }
            gallery = indices.sorted().map { idx in
                let g = allGames[idx]
                return WidgetGameData(id: g.md5Hash, title: g.title,
                                     systemName: g.system?.shortName ?? "",
                                     systemIdentifier: g.systemIdentifier.isEmpty ? nil : g.systemIdentifier,
                                     artworkPath: widgetArtworkPath(for: g))
            }
        }

        writeGameData(
            recentGames: recentGames,
            galleryGames: gallery,
            favoriteGames: favorites,
            totalCount: totalCount,
            systemCount: systemCount,
            totalPlayTimeSeconds: totalPlayTime,
            favoritesCount: favoritesCount
        )
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
