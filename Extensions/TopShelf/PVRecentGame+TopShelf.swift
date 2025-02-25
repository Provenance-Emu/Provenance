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
    public func contentItem() -> TVTopShelfSectionedItem? {
        guard let game = game else {
            return nil
        }

        let item = TVTopShelfSectionedItem(identifier: game.md5Hash)

        item.title = game.title

        // Set image URL if available
        let artworkURLString = game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL
        if !artworkURLString.isEmpty,
           let imageURL = URL(string: artworkURLString) {
            item.setImageURL(imageURL, for: .screenScale1x)
            item.imageShape = game.system?.imageType ?? .square
        }

        // Set play action with deep link
        item.playAction = TVTopShelfAction(url: displayURL)

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
