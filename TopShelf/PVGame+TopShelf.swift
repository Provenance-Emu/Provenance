//  PVGame+TopShelf.m
//  Provenance
//
//  Created by entourloop on 2018-03-29.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import PVLibrary
import TVServices

// Top shelf extensions
extension PVGame {
    public func contentItem(with containerIdentifier: TVContentIdentifier) -> TVContentItem? {
        let identifier = TVContentIdentifier(identifier: md5Hash, container: containerIdentifier)
        let item = TVContentItem(contentIdentifier: identifier)

        item.title = title
        item.imageURL = URL(string: customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL)
        item.imageShape = system.imageType
        item.displayURL = displayURL
        item.lastAccessedDate = lastPlayed
        return item
    }

    var displayURL: URL {
        var components = URLComponents()
        components.scheme = PVAppURLKey
        components.path = PVGameControllerKey
        components.queryItems = [URLQueryItem(name: PVGameMD5Key, value: self.md5Hash)]
        return (components.url)!
    }
}
