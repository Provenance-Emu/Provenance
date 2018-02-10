//  ServiceProvider.swift
//  TopShelf
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//
import Foundation
import Realm
import TVServices

/** Enabling Top Shelf
 
 1. Enable App Groups on the TopShelf target, and specify an App Group ID
 Provenance Project -> TopShelf Target -> Capabilities Section -> App Groups
 2. Enable App Groups on the Provenance TV target, using the same App Group ID
 3. Define the value for `PVAppGroupId` in `PVAppConstants.m` to that App Group ID
 
 */

class ServiceProvider: NSObject, TVTopShelfProvider {
    override init() {
        super.init()
        
        if RLMRealmConfiguration.supportsAppGroup {
            RLMRealmConfiguration.setRealmConfig()
        }
    }
    
    // MARK: - TVTopShelfProvider protocol
    var topShelfStyle: TVTopShelfContentStyle {
        // Return desired Top Shelf style.
        return .sectioned
    }
    
    var topShelfItems: [TVContentItem] {
        var topShelfItems = [AnyHashable]()
        if RLMRealmConfiguration.supportsAppGroup {
            let identifier = TVContentIdentifier(identifier: "id", container: nil)!
            let recentItems = TVContentItem(contentIdentifier: identifier)
            recentItems?.title = "Recently Played"
            
            let recents: RLMResults? = PVRecentGame.allObjects
            let recentGames: NSFastEnumeration? = recents?.sortedResults(usingProperty: "lastPlayedDate", ascending: false)
            
            var items = [TVContentItem]()
            for game: PVRecentGame in recentGames {
                items.append(game.contentItem(with: identifier))
            }
            
            recentItems?.topShelfItems = items
            topShelfItems.append(recentItems)
        }
        return topShelfItems
    }
}

