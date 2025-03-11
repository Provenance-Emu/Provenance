//  ServiceProvider.swift
//  TopShelf
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//
import Foundation
import PVLibrary
import PVSupport
import RealmSwift
import TVServices

/** Enabling Top Shelf

 1. Enable App Groups on the TopShelf target, and specify an App Group ID
 Provenance Project -> TopShelf Target -> Capabilities Section -> App Groups
 2. Enable App Groups on the Provenance TV target, using the same App Group ID
 3. Define the value for `PVAppGroupId` in `PVAppConstants.m` to that App Group ID

 */

@objc(ServiceProvider)
public final class ServiceProvider: TVTopShelfContentProvider {
    public override init() {
        if RealmConfiguration.supportsAppGroups {
            RomDatabase.refresh()
        } else {
            ELOG("App doesn't support groups. Check \(PVAppGroupId) is a valid group id")
        }
    }

    // MARK: - TVTopShelfContentProvider protocol

    public var topShelfContent: TVTopShelfContent {
        guard RealmConfiguration.supportsAppGroups else {
            return TVTopShelfSectionedContent(sections: [])
        }

        let database = RomDatabase.sharedInstance

        // Create sections
        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []

        // Add Favorites section
        if let favoritesSection = createFavoriteSection(database: database) {
            sections.append(favoritesSection)
        }

        // Add Recently Played section
        if let recentlyPlayedSection = createRecentlyPlayedSection(database: database) {
            sections.append(recentlyPlayedSection)
        }

        // Add Recently Added section
        if let recentlyAddedSection = createRecentlyAddedSection(database: database) {
            sections.append(recentlyAddedSection)
        }

        return TVTopShelfSectionedContent(sections: sections)
    }

    // MARK: - Private Helpers

    private func createRecentlyAddedSection(database: RomDatabase) -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        let recentlyAddedGames = database.all(PVGame.self, sortedByKeyPath: #keyPath(PVGame.importDate), ascending: false)
        let items = Array(recentlyAddedGames.map { $0.topShelfItem() })

        guard !items.isEmpty else { return nil }

        return TVTopShelfItemCollection(items: items)
    }

    private func createRecentlyPlayedSection(database: RomDatabase) -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        let recentlyPlayedGames = database.all(PVRecentGame.self, sortedByKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
        let items = Array(recentlyPlayedGames.compactMap { recentGame -> TVTopShelfSectionedItem? in
            // Get the actual game from the recent game reference
            if let game = database.object(ofType: PVGame.self, wherePrimaryKeyEquals: recentGame.game.md5Hash) {
                return game.topShelfItem()
            }
            return nil
        })

        guard !items.isEmpty else { return nil }

        return TVTopShelfItemCollection(items: items)
    }

    private func createFavoriteSection(database: RomDatabase) -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        let favoriteGames = database.all(PVGame.self, where: "isFavorite", value: true)
            .sorted(byKeyPath: #keyPath(PVGame.title), ascending: false)
        let items = Array(favoriteGames.map { $0.topShelfItem() })

        guard !items.isEmpty else { return nil }

        return TVTopShelfItemCollection(items: items)
    }
}
