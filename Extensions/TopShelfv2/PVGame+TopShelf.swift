//  PVGame+TopShelf.swift
//  Provenance
//
//  Created by entourloop on 2018-03-29.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import Foundation
import PVLibrary
import TVServices
import PVLogging

// Top shelf extensions
extension PVGame {
    /// Creates a TVTopShelfItem for this game for display in the Top Shelf
    func topShelfItem() -> TVTopShelfSectionedItem {
        // Create a sectioned content item
        let item = TVTopShelfSectionedItem(identifier: md5Hash)

        // Set basic metadata
        // Include system name in title if available
        if let systemName = system?.name {
            item.title = "\(title) (\(systemName))"
        } else {
            item.title = title
        }

        // Set image URL if available
        let artworkURLString = customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL
        if !artworkURLString.isEmpty, let imageURL = URL(string: artworkURLString) {
            // Set image shape based on system
            if let system = system {
                item.imageShape = system.imageType
            } else {
                item.imageShape = .square
            }

            // Set the image URL
            item.setImageURL(imageURL, for: .screenScale1x)
            DLOG("TopShelf: Set image URL for \(title): \(imageURL.path)")
        } else {
            // If no image URL is available, log a warning
            WLOG("TopShelf: No artwork URL available for game \(title)")
        }

        // Set display actions with deep link to game
        item.playAction = TVTopShelfAction(url: URL(string: "provenance://game/\(md5Hash)")!)

        return item
    }
}

/// Extension to handle system image type mapping
extension PVSystem {
    /// Map system to appropriate top shelf image shape
    var imageType: TVTopShelfSectionedItem.ImageShape {
        switch systemIdentifier {
        case .GB, .GBC, .GBA:
            return .square
        case .SNES, .NES, .Genesis, .MasterSystem:
            return .hdtv
        default:
            return .square
        }
    }
}
