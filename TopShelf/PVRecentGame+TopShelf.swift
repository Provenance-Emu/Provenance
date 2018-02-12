//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVRecentGame+TopShelf.m
//  Provenance
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import TVServices

// Top shelf extensions
extension PVRecentGame {
    public func contentItem(with containerIdentifier: TVContentIdentifier) -> TVContentItem? {
        guard let game = game else {
            return nil
        }
        
        guard let identifier = TVContentIdentifier(identifier: game.md5Hash, container: containerIdentifier),
        let item = TVContentItem(contentIdentifier: identifier) else {
            return nil
        }
        
        item.title = game.title
        item.imageURL = URL(string: game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL)
        item.imageShape = imageType
        item.displayURL = self.displayURL
        item.lastAccessedDate = lastPlayedDate
        return item
    }
    
    var displayURL : URL {
        var components = URLComponents()
        components.scheme = PVAppURLKey
        components.path = PVGameControllerKey
        components.queryItems = [URLQueryItem(name: PVGameMD5Key, value: game!.md5Hash)]
        return (components.url)!
    }
    
    var imageType : TVContentItemImageShape {
        let posterSystems : [String] = [PVNESSystemIdentifier, PVGenesisSystemIdentifier, PVSegaCDSystemIdentifier, PVMasterSystemSystemIdentifier, PVSG1000SystemIdentifier, PV32XSystemIdentifier, PV2600SystemIdentifier, PV5200SystemIdentifier, PV7800SystemIdentifier, PVLynxSystemIdentifier, PVWonderSwanSystemIdentifier]
        
        let squareSystems : [String] = [PVGameGearSystemIdentifier, PVGBSystemIdentifier, PVGBCSystemIdentifier, PVGBASystemIdentifier, PVNGPSystemIdentifier, PVNGPCSystemIdentifier, PVPSXSystemIdentifier, PVVirtualBoySystemIdentifier, PVPCESystemIdentifier, PVPCECDSystemIdentifier, PVPCFXSystemIdentifier, PVFDSSystemIdentifier, PVPokemonMiniSystemIdentifier]
        
        let wideSystems  : [String] = [PVN64SystemIdentifier, PVSNESSystemIdentifier]
        
        let systemIdentifier = game?.systemIdentifier ?? ""
        
        if posterSystems.contains(systemIdentifier ){
            return .poster
        } else if squareSystems.contains(systemIdentifier) {
            return .square
        } else if wideSystems.contains(systemIdentifier) {
            return .HDTV
        } else {
            return .HDTV
        }
    }
}

