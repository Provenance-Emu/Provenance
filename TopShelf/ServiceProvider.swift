//  ServiceProvider.swift
//  TopShelf
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//
import Foundation
import RealmSwift
import TVServices

/** Enabling Top Shelf
 
 1. Enable App Groups on the TopShelf target, and specify an App Group ID
 Provenance Project -> TopShelf Target -> Capabilities Section -> App Groups
 2. Enable App Groups on the Provenance TV target, using the same App Group ID
 3. Define the value for `PVAppGroupId` in `PVAppConstants.m` to that App Group ID
 
 */

public class ServiceProvider: NSObject, TVTopShelfProvider {
    public override init() {
        super.init()

        if RealmConfiguration.supportsAppGroups {
            RealmConfiguration.setDefaultRealmConfig()
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
            let identifier = TVContentIdentifier(identifier: "id", container: nil)!
            let database = RomDatabase.sharedInstance
            
            guard let favoriteItems = TVContentItem(contentIdentifier: identifier) else {
                ELOG("Couldn't get TVContentItem for identifier \(identifier)")
                return topShelfItems
            }
            favoriteItems.title = "Favorites"
            let favoriteGames = database.all(PVGame.self, where: "isFavorite", value: true).sorted(byKeyPath: #keyPath(PVGame.title), ascending: false)
            var favoriteNames = [String]()
            var items = [TVContentItem]()
            for game: PVGame in favoriteGames {
                if let contentItem = game.contentItem(with: identifier) {
                    items.append(contentItem)
                    favoriteNames.append(game.title)
                }
            }
            favoriteItems.topShelfItems = items

            guard let recentlyPlayedItems = TVContentItem(contentIdentifier: identifier) else {
                ELOG("Couldn't get TVContentItem for identifer \(identifier)")
                return topShelfItems
            }
            recentlyPlayedItems.title = "Recently Played"
            let recentlyPlayedGames = database.all(PVRecentGame.self, sortedByKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
            items = [TVContentItem]()
            var recentlyPlayedNames = [String]()
            for game: PVRecentGame in recentlyPlayedGames {
                if let contentItem = game.contentItem(with: identifier) {
                    if favoriteNames.index(of: game.game.title) == nil {
                        items.append(contentItem)
                        recentlyPlayedNames.append(game.game.title)
                    }
                }
            }
            recentlyPlayedItems.topShelfItems = items
            topShelfItems.append(recentlyPlayedItems)
            
            // Show "recents" first
            topShelfItems.append(favoriteItems)
            
            
            guard let recentlyAddedItems = TVContentItem(contentIdentifier: identifier) else {
                ELOG("Couldn't get TVContentItem for identifier \(identifier)")
                return topShelfItems
            }
            recentlyAddedItems.title = "Recently Added"
            
            let recentlyAddedGames = database.all(PVGame.self, sortedByKeyPath:
                #keyPath(PVGame.importDate), ascending: false)
            
            items = [TVContentItem]()
            for game: PVGame in recentlyAddedGames {
                if recentlyPlayedNames.index(of: game.title) == nil {
                    if favoriteNames.index(of: game.title) == nil {
                        if let contentItem = game.contentItem(with: identifier) {
                            items.append(contentItem)
                        }
                    }
                }
            }
            recentlyAddedItems.topShelfItems = items
            topShelfItems.append(recentlyAddedItems)
        }

        return topShelfItems
    }
}
