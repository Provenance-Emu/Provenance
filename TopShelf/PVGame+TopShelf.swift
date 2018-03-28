//  PVGame+TopShelf.m
//  Provenance
//
//  Created by entourloop on 2018-03-29.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import TVServices

// Top shelf extensions
extension PVGame {
    public func contentItem(with containerIdentifier: TVContentIdentifier) -> TVContentItem? {

        guard let identifier = TVContentIdentifier(identifier: self.md5Hash, container: containerIdentifier),
        let item = TVContentItem(contentIdentifier: identifier) else {
            return nil
        }

        item.title = self.title
        item.imageURL = URL(string: self.customArtworkURL.isEmpty ? self.originalArtworkURL : self.customArtworkURL)
        item.imageShape = imageType
        item.displayURL = self.displayURL
        item.lastAccessedDate = self.lastPlayed
        return item
    }

    var displayURL: URL {
        var components = URLComponents()
        components.scheme = PVAppURLKey
        components.path = PVGameControllerKey
        components.queryItems = [URLQueryItem(name: PVGameMD5Key, value: self.md5Hash)]
        return (components.url)!
    }

    var imageType: TVContentItemImageShape {
        let system = self.system.enumValue

        switch system {
        case .NES, .Genesis, .SegaCD, .MasterSystem, .SG1000, .Sega32X, .Atari2600, .Atari5200, .Atari7800, .Lynx, .WonderSwan, .WonderSwanColor:
            return .poster
        case .GameGear, .GB, .GBC, .GBA, .NGP, .NGPC, .PSX, .VirtualBoy, .PCE, .PCECD, .PCFX, .SGFX, .FDS, .PokemonMini, .Unknown:
            return .square
        case .N64, .SNES:
            return .HDTV
        }
    }
}
