//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVRecentGame+TopShelf.m
//  Provenance
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import TVServices

// Top shelf extensions
extension PVRecentGame {
    public func contentItem(with containerIdentifier: TVContentIdentifier) -> TVContentItem? {
        guard let game = game else {
            return nil
        }

        let identifier = TVContentIdentifier(identifier: game.md5Hash, container: containerIdentifier)
        let item = TVContentItem(contentIdentifier: identifier)

        item.title = game.title
        item.imageURL = URL(string: game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL)
        item.imageShape = game.system.imageType
        item.displayURL = displayURL
        item.lastAccessedDate = lastPlayedDate

        return item
    }

    var displayURL: URL {
        guard let game = game else {
            ELOG("Nil game")
            return URL(fileURLWithPath: "")
        }

        var components = URLComponents()
        components.scheme = PVAppURLKey
        components.path = PVGameControllerKey
        components.queryItems = [URLQueryItem(name: PVGameMD5Key, value: game.md5Hash)]
        return components.url ?? URL(fileURLWithPath: "")
    }
}
