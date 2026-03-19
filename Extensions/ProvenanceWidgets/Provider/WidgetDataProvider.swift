//
//  WidgetDataProvider.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import Foundation
import RealmSwift

private let kRealmFilename = "default.realm"
private let kSchemaVersion: UInt64 = 25

/// Reads the App Group identifier from the extension's Info.plist (APP_GROUP_IDENTIFIER),
/// falling back to the well-known default so the widget doesn't silently fail when
/// a custom App Group ID is configured at build time.
private var kProvenanceAppGroupId: String {
    Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String
        ?? "group.org.provenance-emu.provenance"
}

/// Read-only Realm access for widget timeline providers.
/// All access is read-only and occurs on the calling thread.
/// Mirrors the pattern used by SpotlightImportExtension.
final class WidgetDataProvider {

    // MARK: - Realm Access

    private func makeRealmConfig() -> Realm.Configuration? {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: kProvenanceAppGroupId) else {
            return nil
        }

        // On iOS, the container URL itself is the root
        let realmURL = groupURL.appendingPathComponent(kRealmFilename, isDirectory: false)

        return Realm.Configuration(
            fileURL: realmURL,
            schemaVersion: kSchemaVersion,
            objectTypes: [PVGameProxy.self, PVRecentGameProxy.self],
            readOnly: true
        )
    }

    private func openRealm() -> Realm? {
        guard let config = makeRealmConfig() else { return nil }
        return try? Realm(configuration: config)
    }

    // MARK: - Recently Played

    /// Returns up to `limit` recently-played games sorted by most recent play date.
    func recentGames(limit: Int) -> [WidgetGameEntry] {
        guard let realm = openRealm() else { return [] }

        let results = realm.objects(PVRecentGameProxy.self)
            .sorted(byKeyPath: "lastPlayedDate", ascending: false)

        return Array(results.prefix(limit)).compactMap { recent in
            guard let game = recent.game, !game.isInvalidated else { return nil }
            return widgetEntry(from: game, lastPlayedDate: recent.lastPlayedDate)
        }
    }

    // MARK: - Favorites

    /// Returns up to `limit` favorite games sorted by title.
    func favoriteGames(limit: Int) -> [WidgetGameEntry] {
        guard let realm = openRealm() else { return [] }

        let results = realm.objects(PVGameProxy.self)
            .filter("isFavorite == true")
            .sorted(byKeyPath: "title", ascending: true)

        return Array(results.prefix(limit)).map { widgetEntry(from: $0, lastPlayedDate: $0.lastPlayed) }
    }

    // MARK: - Library Stats

    func libraryStats() -> LibraryStatsData {
        guard let realm = openRealm() else {
            return LibraryStatsData(totalGames: 0, totalSystems: 0, totalPlayTimeSeconds: 0, favoritesCount: 0)
        }

        let games = realm.objects(PVGameProxy.self)
        let totalGames = games.count
        let favoritesCount = games.filter("isFavorite == true").count

        // Collect unique system identifiers
        let systemIdentifiers = Set(games.compactMap { $0.systemIdentifier })
        let totalSystems = systemIdentifiers.count

        // Sum total play time
        let totalPlayTimeSeconds = games.sum(ofProperty: "timeSpentInGame") as Int

        return LibraryStatsData(
            totalGames: totalGames,
            totalSystems: totalSystems,
            totalPlayTimeSeconds: totalPlayTimeSeconds,
            favoritesCount: favoritesCount
        )
    }

    // MARK: - Helpers

    private func widgetEntry(from game: PVGameProxy, lastPlayedDate: Date?) -> WidgetGameEntry {
        // Resolve the artwork path from the app group container
        let artworkPath: String? = resolveArtworkPath(for: game)

        return WidgetGameEntry(
            id: game.id,
            title: game.title,
            md5Hash: game.md5Hash,
            systemIdentifier: game.systemIdentifier,
            systemShortName: game.systemShortName ?? "",
            artworkPath: artworkPath,
            lastPlayedDate: lastPlayedDate,
            isFavorite: game.isFavorite
        )
    }

    private func resolveArtworkPath(for game: PVGameProxy) -> String? {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: kProvenanceAppGroupId) else {
            return nil
        }

        let artworkURL = game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL
        guard !artworkURL.isEmpty else { return nil }

        // Artwork URLs may be absolute paths or relative paths within the group container
        if artworkURL.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: artworkURL) ? artworkURL : nil
        } else {
            let candidatePath = groupURL.appendingPathComponent(artworkURL).path
            return FileManager.default.fileExists(atPath: candidatePath) ? candidatePath : nil
        }
    }
}

// MARK: - Realm Proxy Objects
// Lightweight Realm objects that mirror PVGame / PVRecentGame without depending on PVLibrary.
// Widget extensions cannot link against PVLibrary (it pulls in UIKit and other app-only deps),
// so we redeclare only the properties we need here with the same Realm persisted key paths.
// IMPORTANT: indexed annotations must match the main schema exactly to avoid schema mismatch
// errors when opening the Realm in read-only mode.

/// Mirrors PVGame — keep property names in sync with the main app's PVGame schema.
final class PVGameProxy: Object {
    @Persisted(primaryKey: true) var md5Hash: String = ""
    @Persisted(indexed: true) var id: String = ""
    @Persisted var title: String = ""
    @Persisted(indexed: true) var systemIdentifier: String = ""
    @Persisted var systemShortName: String?
    @Persisted var customArtworkURL: String = ""
    @Persisted var originalArtworkURL: String = ""
    @Persisted(indexed: true) var isFavorite: Bool = false
    @Persisted var lastPlayed: Date?
    @Persisted var playCount: Int = 0
    @Persisted var timeSpentInGame: Int = 0
}

/// Mirrors PVRecentGame — keep property names in sync with the main app's PVRecentGame schema.
final class PVRecentGameProxy: Object {
    @Persisted var id: String = ""
    @Persisted var game: PVGameProxy?
    @Persisted(indexed: true) var lastPlayedDate: Date = Date()
}
#endif
