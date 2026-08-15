//  ServiceProvider.swift
//  TopShelf
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//
//  Reads the App Group *library snapshot* written by the host app — it never
//  opens the Realm database.
//
//  Why: there is no extension→host-app IPC on tvOS, and Top Shelf is queried
//  precisely when Provenance is not running.  The previous implementation
//  called `RomDatabase.sharedInstance` (which force-tries `RomDatabase()` and
//  `Realm(configuration:)`), so an unreadable, mid-migration, or
//  memory-pressured database crashed the extension instead of degrading.
//  `LibrarySnapshotReader` cannot trap: every failure path yields empty.
//
import Foundation
import PVLibrarySnapshot
import TVServices

@objc(ServiceProvider)
public final class ServiceProvider: TVTopShelfContentProvider {
    /// Maximum number of games to show in each section.
    private static let maxGamesPerSection = 10

    /// Deep link that simply opens the app, used for the empty state.
    private static let openAppURLString = "provenance://"

    /// Deep-link template for launching a specific game.
    /// Mirrors `PVAppURLKey` + `PVGameControllerKey` + `PVGameMD5Key` in PVLibrary;
    /// duplicated here so this extension does not link PVLibrary at all.
    private static let openGameURLPrefix = "provenance://open?md5="

    private let snapshot = LibrarySnapshotReader()

    // MARK: - TVTopShelfContentProvider

    public override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        guard snapshot.isAvailable else {
            return emptyStateContent()
        }

        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
        /// Games already shown in an earlier section.  On a fresh library the
        /// host app backfills "recently played" from import order, which would
        /// otherwise make the last section a duplicate of the first.
        var seen = Set<String>()

        func addSection(_ list: LibrarySnapshotList, title: String) {
            let games = snapshot.games(list, limit: Self.maxGamesPerSection)
                .filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
            guard !games.isEmpty else { return }
            let collection = TVTopShelfItemCollection(items: games.map(Self.topShelfItem(for:)))
            collection.title = title
            sections.append(collection)
        }

        addSection(.recentlyPlayed, title: Self.sectionTitleRecentlyPlayed)
        addSection(.favorites, title: Self.sectionTitleFavorites)
        addSection(.recentlyAdded, title: Self.sectionTitleRecentlyAdded)

        guard !sections.isEmpty else { return emptyStateContent() }
        return TVTopShelfSectionedContent(sections: sections)
    }

    // MARK: - Item construction

    private static func topShelfItem(for game: LibrarySnapshotGame) -> TVTopShelfSectionedItem {
        let item = TVTopShelfSectionedItem(identifier: game.id)
        item.title = game.systemName.isEmpty ? game.title : "\(game.title) (\(game.systemName))"
        switch LibraryArtworkShape.shape(forSystemIdentifier: game.systemIdentifier) {
        case .square: item.imageShape = .square
        case .wide: item.imageShape = .hdtv
        }

        // `bestArtworkURL` prefers the App Group cache and falls back to the
        // remote artwork URL, matching the previous Realm-backed behaviour.
        if let artworkURL = game.bestArtworkURL {
            item.setImageURL(artworkURL, for: .screenScale1x)
            item.setImageURL(artworkURL, for: .screenScale2x)
        }

        if let url = URL(string: Self.openGameURLPrefix + game.id) {
            item.playAction = TVTopShelfAction(url: url)
            item.displayAction = TVTopShelfAction(url: url)
        }

        return item
    }

    // MARK: - Empty state

    /// Shown when the host app has never written a snapshot (first launch,
    /// missing App Group entitlement, or a snapshot from a newer build).
    /// Deliberately *not* diagnostic text — that would ship to users.
    private func emptyStateContent() -> (any TVTopShelfContent)? {
        let item = TVTopShelfSectionedItem(identifier: "provenance.openApp")
        item.title = Self.emptyStateTitle
        item.imageShape = .square
        if let url = URL(string: Self.openAppURLString) {
            item.playAction = TVTopShelfAction(url: url)
            item.displayAction = TVTopShelfAction(url: url)
        }

        var items = [item]
#if DEBUG
        items.append(contentsOf: debugDiagnosticItems())
#endif
        let section = TVTopShelfItemCollection(items: items)
        section.title = Self.emptyStateSectionTitle
        return TVTopShelfSectionedContent(sections: [section])
    }

#if DEBUG
    private func debugDiagnosticItems() -> [TVTopShelfSectionedItem] {
        var messages: [String] = ["App Group: \(LibrarySnapshotAppGroup.identifier)"]
        if LibrarySnapshotAppGroup.defaults == nil {
            messages.append("App Group UserDefaults suite unavailable")
        }
        if !snapshot.isSchemaSupported {
            messages.append("Snapshot schema v\(snapshot.schemaVersion) is newer than this build")
        }
        if let updatedAt = snapshot.updatedAt {
            messages.append("Snapshot written \(updatedAt)")
        } else {
            messages.append("Snapshot never written")
        }
        return messages.enumerated().map { index, message in
            let item = TVTopShelfSectionedItem(identifier: "provenance.debug.\(index)")
            item.title = message
            item.imageShape = .square
            return item
        }
    }
#endif

    // MARK: - Localized strings

    private static let sectionTitleRecentlyPlayed = NSLocalizedString(
        "topshelf.section.recently-played", value: "Recently Played",
        comment: "Top Shelf section heading for recently played games"
    )
    private static let sectionTitleFavorites = NSLocalizedString(
        "topshelf.section.favorites", value: "Favorites",
        comment: "Top Shelf section heading for favorite games"
    )
    private static let sectionTitleRecentlyAdded = NSLocalizedString(
        "topshelf.section.recently-added", value: "Recently Added",
        comment: "Top Shelf section heading for recently imported games"
    )
    private static let emptyStateTitle = NSLocalizedString(
        "topshelf.empty.open-app", value: "Open Provenance",
        comment: "Top Shelf item shown when no game library data is available yet"
    )
    private static let emptyStateSectionTitle = NSLocalizedString(
        "topshelf.empty.section", value: "Provenance",
        comment: "Top Shelf section heading for the empty state"
    )
}
