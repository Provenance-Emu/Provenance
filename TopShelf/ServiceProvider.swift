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

public final class ServiceProvider: NSObject, TVTopShelfProvider {
    public override init() {
        super.init()

        if RealmConfiguration.supportsAppGroups {
            let database = RomDatabase.sharedInstance
            database.refresh()
        } else {
            ELOG("App doesn't support groups. Check \(PVAppGroupId) is a valid group id")
        }
    }

    // MARK: - TVTopShelfProvider protocol

    public var topShelfStyle: TVTopShelfContentStyle {
        // Return desired Top Shelf style.
        return .sectioned
    }

    public var topShelfItems: [TVContentItem] {
        var topShelfItems = [TVContentItem]()
        if RealmConfiguration.supportsAppGroups {
            let identifier = TVContentIdentifier(identifier: "id", container: nil)
            let database = RomDatabase.sharedInstance

            topShelfItems.append(favoriteTopShelfItems(identifier: identifier, database: database)!)
            topShelfItems.append(recentlyPlayedTopShelfItems(identifier: identifier, database: database)!)
            topShelfItems.append(recentlyAddedTopShelfItems(identifier: identifier, database: database)!)
        }

        return topShelfItems
    }

    private func recentlyAddedTopShelfItems(identifier: TVContentIdentifier, database: RomDatabase) -> TVContentItem? {
        let recentlyAddedItems = TVContentItem(contentIdentifier: identifier)

        recentlyAddedItems.title = "Recently Added"
        let recentlyAddedGames = database.all(PVGame.self, sortedByKeyPath:
            #keyPath(PVGame.importDate), ascending: false)
        recentlyAddedItems.topShelfItems = recentlyAddedGames.map({ $0.contentItem(with: identifier)! })
        return recentlyAddedItems
    }

    private func recentlyPlayedTopShelfItems(identifier: TVContentIdentifier, database: RomDatabase) -> TVContentItem? {
        let recentlyPlayedItems = TVContentItem(contentIdentifier: identifier)

        recentlyPlayedItems.title = "Recently Played"
        let recentlyPlayedGames = database.all(PVRecentGame.self, sortedByKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
        recentlyPlayedItems.topShelfItems = recentlyPlayedGames.map({ $0.contentItem(with: identifier)! })
        return recentlyPlayedItems
    }

    private func favoriteTopShelfItems(identifier: TVContentIdentifier, database: RomDatabase) -> TVContentItem? {
        let favoriteItems = TVContentItem(contentIdentifier: identifier)

        favoriteItems.title = "Favorites"
        let favoriteGames = database.all(PVGame.self, where: "isFavorite", value: true).sorted(byKeyPath: #keyPath(PVGame.title), ascending: false)
        favoriteItems.topShelfItems = favoriteGames.map({ $0.contentItem(with: identifier)! })
        return favoriteItems
    }
}
