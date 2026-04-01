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

}
