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
import OSLog
import CryptoKit

private let kRealmFilename = "default.realm"
private let kSchemaVersion: UInt64 = 25
private let kFallbackAppGroupId = "group.org.provenance-emu.provenance"
private let logger = Logger(subsystem: "org.provenance-emu.ProvenanceWidgets", category: "WidgetDataProvider")

/// Reads the App Group identifier from the extension's Info.plist (APP_GROUP_IDENTIFIER),
/// falling back to the well-known default.  Strings containing "$(" are unexpanded
/// Xcode build-setting placeholders and are treated as missing.
private var kProvenanceAppGroupId: String {
    let rawValue = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String
    if let value = rawValue, !value.isEmpty, !value.contains("$(") {
        return value
    }
    return kFallbackAppGroupId
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
        do {
            return try Realm(configuration: config)
        } catch {
            // Log so that widget failures surface in Console.app rather than silently
            // returning empty state. Callers treat nil as "no data available".
            logger.error("Failed to open Realm: \(error.localizedDescription, privacy: .public)")
            return nil
        }
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

        // Use Realm's distinct query instead of materialising the full result set
        let totalSystems = games.distinct(by: ["systemIdentifier"]).count

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
        // Load artwork bytes at provider time so the view never does synchronous disk I/O.
        let artworkData: Data? = loadArtworkData(for: game)

        return WidgetGameEntry(
            id: game.id,
            title: game.title,
            md5Hash: game.md5Hash,
            systemIdentifier: game.systemIdentifier,
            systemShortName: game.systemShortName ?? "",
            artworkData: artworkData,
            lastPlayedDate: lastPlayedDate,
            isFavorite: game.isFavorite
        )
    }

    /// Reads artwork bytes from disk once at timeline-generation time.
    /// The main app stores artwork via PVMediaCache using the MD5 digest of the URL key
    /// as the on-disk filename.  This mirrors the lookup used by the TopShelf extension.
    private func loadArtworkData(for game: PVGameProxy) -> Data? {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: kProvenanceAppGroupId) else {
            return nil
        }

        let artworkKey = game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL
        guard !artworkKey.isEmpty else { return nil }

        let keyHash = artworkKey.md5HexString
        let fm = FileManager.default

        // Mirror the candidate paths checked by TopShelf / PVMediaCache
        let candidatePaths: [URL] = [
            groupURL.appendingPathComponent("Documents/PVCache/\(keyHash)"),
            groupURL.appendingPathComponent("Caches/PVCache/\(keyHash)"),
            groupURL.appendingPathComponent("Library/Caches/PVCache/\(keyHash)"),
            groupURL.appendingPathComponent("PVCache/\(keyHash)")
        ]

        for url in candidatePaths {
            if fm.fileExists(atPath: url.path), let data = try? Data(contentsOf: url) {
                return data
            }
        }

        // Fallback: treat the key as an absolute file path
        if artworkKey.hasPrefix("/"), fm.fileExists(atPath: artworkKey),
           let data = try? Data(contentsOf: URL(fileURLWithPath: artworkKey)) {
            return data
        }

        return nil
    }

}

// MARK: - String+MD5

private extension String {
    /// Lowercase hex MD5 digest — mirrors PVMediaCache's cache key derivation.
    var md5HexString: String {
        let digest = Insecure.MD5.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Realm Proxy Objects
// Lightweight Realm objects that mirror PVGame / PVRecentGame without depending on PVLibrary.
// Widget extensions cannot link against PVLibrary (it pulls in UIKit and other app-only deps),
// so we redeclare only the properties we need here with the same Realm persisted key paths.
// IMPORTANT: indexed annotations must match the main schema exactly to avoid schema mismatch
// errors when opening the Realm in read-only mode.

/// Mirrors PVGame — keep property names in sync with the main app's PVGame schema.
/// All value-type @Persisted properties are declared here so that opening the existing
/// Realm in read-only mode does not trigger a schema-mismatch error.
/// Object/List links that reference types outside objectTypes (e.g. PVFile, PVSystem)
/// are intentionally omitted — Realm ignores undeclared link columns in read-only mode.
final class PVGameProxy: Object {
    // Must match the on-disk table name created by the main app.
    override class func className() -> String { "PVGame" }
    @Persisted(primaryKey: true) var md5Hash: String = ""
    @Persisted(indexed: true) var id: String = ""
    @Persisted var title: String = ""
    @Persisted var romPath: String = ""
    @Persisted var customArtworkURL: String = ""
    @Persisted var originalArtworkURL: String = ""
    @Persisted var requiresSync: Bool = true
    @Persisted(indexed: true) var isFavorite: Bool = false
    @Persisted var cloudRecordID: String?
    @Persisted var isDownloaded: Bool = true
    @Persisted var hasCloudAssets: Bool = false
    @Persisted var fileSize: Int = 0
    @Persisted var lastCloudSyncDate: Date?
    @Persisted var romSerial: String?
    @Persisted var romHeader: String?
    @Persisted var importDate: Date = Date()
    @Persisted(indexed: true) var systemIdentifier: String = ""
    @Persisted var crc: String = ""
    @Persisted var userPreferredCoreID: String?
    @Persisted var contentless: Bool = false
    @Persisted var lastPlayed: Date?
    @Persisted var playCount: Int = 0
    @Persisted var timeSpentInGame: Int = 0
    @Persisted var rating: Int = -1
    @Persisted var systemShortName: String?
    @Persisted var gameDescription: String?
    @Persisted var boxBackArtworkURL: String?
    @Persisted var developer: String?
    @Persisted var publisher: String?
    @Persisted var publishDate: String?
    @Persisted var genres: String?
    @Persisted var referenceURL: String?
    @Persisted var releaseID: String?
    @Persisted var regionName: String?
    @Persisted var regionID: Int?
    @Persisted var language: String?
}

/// Mirrors PVCore — minimal proxy used so PVRecentGame.core (PVCore?) can be represented
/// without depending on the full PVCore type from PVLibrary. Additional persisted
/// properties are intentionally omitted; Realm will ignore undeclared columns when
/// opening the existing Realm file in read-only mode.
final class PVCoreProxy: Object {
    // Must match the on-disk table name created by the main app.
    override class func className() -> String { "PVCore" }
}

/// Mirrors PVRecentGame — keep property names and optionality in sync with the main app's
/// PVRecentGame schema so that opening the existing Realm in read-only mode does not
/// trigger schema-mismatch errors.
final class PVRecentGameProxy: Object {
    // Must match the on-disk table name created by the main app.
    override class func className() -> String { "PVRecentGame" }
    @Persisted(wrappedValue: UUID().uuidString) var id: String
    @Persisted var game: PVGameProxy
    @Persisted var core: PVCoreProxy?
    @Persisted(wrappedValue: Date(), indexed: true) var lastPlayedDate: Date
}
#endif
