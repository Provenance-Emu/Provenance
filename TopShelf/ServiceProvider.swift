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
			guard let identifier = TVContentIdentifier(identifier: "id", container: nil) else {
				ELOG("Failed to init.")
				return topShelfItems
			}

            guard let recentItems = TVContentItem(contentIdentifier: identifier) else {
                ELOG("Couldnt get TVContentItem for idenitifer \(identifier)")
                return topShelfItems
            }

            recentItems.title = "Recently Played"

            let database = RomDatabase.sharedInstance

            let recentGames = database.all(PVRecentGame.self, sortedByKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)

            var items = [TVContentItem]()
            for game: PVRecentGame in recentGames {
                if let contentItem = game.contentItem(with: identifier) {
                    items.append(contentItem)
                }
            }

            recentItems.topShelfItems = items
            topShelfItems.append(recentItems)
        }

        return topShelfItems
    }
}
