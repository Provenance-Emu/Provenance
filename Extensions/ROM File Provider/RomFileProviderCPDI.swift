//
//  RomFileProviderCPDI.swift
//  ROM File Provider
//
//  Single place for Realm → CPDI (`Game`) snapshots and browse-axis metadata (DRY/KISS).
//

import Foundation
import PVLibrary
import PVPrimitives
import PVRealm
import RealmSwift

/// Shared library access for the ROM File Provider: one Realm entry point and CPDI-only payloads past the persistence boundary.
enum RomFileProviderLibrary {

    /// Shared ``RomDatabase`` / App Group Realm (same as Spotlight / Top Shelf).
    static var realm: Realm {
        RomDatabase.sharedInstance.realm
    }

    /// One locally present ROM: immutable ``Game`` snapshot plus virtual-folder bucket fields derived from the same `PVGame`.
    struct LocalEntry {
        let game: Game
        let romURL: URL
        let publisherKey: String
        let publisherTitle: String
        let yearKey: String
        let regionKey: String
        let regionTitle: String
        let ratingKey: String
        let ratingTitle: String
    }

    /// Builds a CPDI row when `pvGame` has a valid on-disk ROM; otherwise `nil`.
    static func makeLocalEntry(from pvGame: PVGame) -> LocalEntry? {
        guard !pvGame.isInvalidated,
              let romURL = pvGame.file?.url,
              FileManager.default.fileExists(atPath: romURL.path) else {
            return nil
        }
        let game = pvGame.asDomain()
        let publisherKey = RomFileProviderVirtualPath.publisherGroupingKey(pvGame.publisher)
        let publisherTitle: String = {
            if let value = pvGame.publisher?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
            return "Unknown"
        }()
        let yearKey = RomFileProviderVirtualPath.yearBucket(fromPublishDate: pvGame.publishDate)
        let regionKey = RomFileProviderVirtualPath.regionGroupingKey(pvGame.regionName)
        let regionTitle: String = {
            if let value = pvGame.regionName?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
            return "Unknown"
        }()
        let ratingPair = RomFileProviderVirtualPath.ratingFolderKeyAndLabel(rating: pvGame.rating)
        return LocalEntry(
            game: game,
            romURL: romURL,
            publisherKey: publisherKey,
            publisherTitle: publisherTitle,
            yearKey: yearKey,
            regionKey: regionKey,
            regionTitle: regionTitle,
            ratingKey: ratingPair.key,
            ratingTitle: ratingPair.label
        )
    }

    /// Single pass over all games; returns only locally present ROM rows as CPDI snapshots.
    static func loadAllLocalEntries() -> [LocalEntry] {
        realm.objects(PVGame.self).compactMap { makeLocalEntry(from: $0) }
    }

    /// Axis for resolving a human-readable folder title from a normalized grouping key (`item(for:)` path).
    enum GroupingAxis {
        case publisher
        case region
    }

    /// First matching display string for `groupingKey`, or `"Unknown"`.
    static func displayName(axis: GroupingAxis, groupingKey: String) -> String {
        if groupingKey == RomFileProviderVirtualPath.unknownGroupingKey {
            return "Unknown"
        }
        for pvGame in realm.objects(PVGame.self) {
            guard !pvGame.isInvalidated else { continue }
            switch axis {
            case .publisher:
                guard RomFileProviderVirtualPath.publisherGroupingKey(pvGame.publisher) == groupingKey else { continue }
                let trimmed = pvGame.publisher?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !trimmed.isEmpty { return trimmed }
            case .region:
                guard RomFileProviderVirtualPath.regionGroupingKey(pvGame.regionName) == groupingKey else { continue }
                let trimmed = pvGame.regionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return "Unknown"
    }

    /// Human-readable label for a `rating:<key>` virtual folder.
    static func ratingFolderLabel(forKey key: String) -> String {
        if key == "unrated" { return "Unrated" }
        if let starCount = Int(key) {
            return RomFileProviderVirtualPath.ratingFolderKeyAndLabel(rating: starCount).label
        }
        return key
    }

    /// Sorts CPDI rows by game title for Files.app ordering.
    static func sortedByGameTitle(_ entries: [LocalEntry]) -> [LocalEntry] {
        entries.sorted { $0.game.title.localizedCaseInsensitiveCompare($1.game.title) == .orderedAscending }
    }

    // MARK: - Save States

    /// Immutable snapshot of a single save state for use past the Realm persistence boundary.
    struct SaveStateEntry {
        let id: String
        let game: Game
        let date: Date
        let isAutosave: Bool
        let userDescription: String?
        let fileURL: URL?
    }

    /// Returns all locally present save states (with an on-disk `.file`) as CPDI snapshots.
    static func loadAllSaveStateEntries() -> [SaveStateEntry] {
        realm.objects(PVSaveState.self).compactMap { pvSS -> SaveStateEntry? in
            guard !pvSS.isInvalidated,
                  let pvGame = pvSS.game, !pvGame.isInvalidated,
                  let pvFile = pvSS.file, let fileURL = pvFile.url,
                  FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            return SaveStateEntry(
                id: pvSS.id,
                game: pvGame.asDomain(),
                date: pvSS.date,
                isAutosave: pvSS.isAutosave,
                userDescription: pvSS.userDescription,
                fileURL: fileURL
            )
        }
    }

    /// Distinct games that have at least one locally present save state, sorted by title.
    static func saveStateGameFolders() -> [Game] {
        var seen = Set<String>()
        var games: [Game] = []
        for entry in loadAllSaveStateEntries() where !seen.contains(entry.game.md5) {
            seen.insert(entry.game.md5)
            games.append(entry.game)
        }
        return games.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Screenshots

    /// Immutable snapshot of a single screenshot for use past the Realm persistence boundary.
    struct ScreenshotEntry {
        let gameMD5: String
        let index: Int
        let imageURL: URL
    }

    /// Returns all locally present screenshots as CPDI snapshots.
    static func loadAllScreenshotEntries() -> [ScreenshotEntry] {
        var entries: [ScreenshotEntry] = []
        for pvGame in realm.objects(PVGame.self) {
            guard !pvGame.isInvalidated else { continue }
            let md5 = pvGame.md5Hash
            let shots = Array(pvGame.screenShots)
            for (index, pvImageFile) in shots.enumerated() {
                guard !pvImageFile.isInvalidated,
                      let url = pvImageFile.url,
                      FileManager.default.fileExists(atPath: url.path) else { continue }
                entries.append(ScreenshotEntry(gameMD5: md5, index: index, imageURL: url))
            }
        }
        return entries
    }

    /// Distinct games that have at least one locally present screenshot, sorted by title.
    static func screenshotGameFolders() -> [Game] {
        var seen = Set<String>()
        var games: [Game] = []
        for pvGame in realm.objects(PVGame.self) {
            guard !pvGame.isInvalidated else { continue }
            let md5 = pvGame.md5Hash
            guard !seen.contains(md5) else { continue }
            let hasShots = pvGame.screenShots.contains { pvImg in
                !pvImg.isInvalidated && pvImg.url.map { FileManager.default.fileExists(atPath: $0.path) } == true
            }
            if hasShots {
                seen.insert(md5)
                games.append(pvGame.asDomain())
            }
        }
        return games.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
