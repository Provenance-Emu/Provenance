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
import PVMediaCache
import PVHashing

// Top shelf extensions
extension PVGame {
    /// Gets the local cached artwork path for this game from the app group container
    var cachedArtworkURL: URL? {
        // Try custom artwork first, then original
        let artworkKey = customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL
        
        guard !artworkKey.isEmpty else {
            DLOG("TopShelf: No artwork key for game \(title)")
            return nil
        }
        
        // Get the MD5 hash of the artwork key (this is how PVMediaCache stores files)
        let keyHash = artworkKey.md5Hash
        
        // Try app group cache path first (for extension access)
        if let appGroupCachePath = appGroupCachePath(forKeyHash: keyHash) {
            if FileManager.default.fileExists(atPath: appGroupCachePath.path) {
                DLOG("TopShelf: Found artwork in app group cache for \(title)")
                return appGroupCachePath
            }
        }
        
        // Try the originalArtworkFile if available
        if let artworkFile = originalArtworkFile, let fileURL = artworkFile.url {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                DLOG("TopShelf: Found artwork in originalArtworkFile for \(title)")
                return fileURL
            }
        }
        
        // Check if the file exists in the standard cache location
        if PVMediaCache.fileExists(forKey: artworkKey) {
            if let cacheURL = PVMediaCache.filePath(forKey: artworkKey) {
                DLOG("TopShelf: Found artwork in standard cache for \(title)")
                return cacheURL
            }
        }
        
        DLOG("TopShelf: No cached artwork found for game \(title)")
        return nil
    }
    
    /// Gets the app group cache path for a given key hash
    private func appGroupCachePath(forKeyHash keyHash: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) else {
            return nil
        }
        
        // Check multiple possible locations where artwork might be stored
        let possiblePaths = [
            // App group Documents/PVCache/
            containerURL.appendingPathComponent("Documents/PVCache/\(keyHash)"),
            // App group Caches/PVCache/
            containerURL.appendingPathComponent("Caches/PVCache/\(keyHash)"),
            // App group Library/Caches/PVCache/
            containerURL.appendingPathComponent("Library/Caches/PVCache/\(keyHash)"),
            // Direct in app group
            containerURL.appendingPathComponent("PVCache/\(keyHash)")
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        
        return possiblePaths.first // Return first path for potential future use
    }
    
    /// Creates a TVTopShelfItem for this game for display in the Top Shelf
    func topShelfItem() -> TVTopShelfSectionedItem {
        let item = TVTopShelfSectionedItem(identifier: md5Hash)

        // Set basic metadata - include system name for context
        if let systemName = system?.name {
            item.title = "\(title) (\(systemName))"
        } else {
            item.title = title
        }

        // Set image shape based on system
        if let system = system {
            item.imageShape = system.imageType
        } else {
            item.imageShape = .square
        }

        // Try to get local cached artwork first
        if let localArtworkURL = cachedArtworkURL {
            item.setImageURL(localArtworkURL, for: .screenScale1x)
            item.setImageURL(localArtworkURL, for: .screenScale2x)
            DLOG("TopShelf: Using local cached artwork for \(title): \(localArtworkURL.path)")
        } else {
            // Fall back to remote URL if local cache doesn't exist
            let artworkURLString = customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL
            if !artworkURLString.isEmpty, let imageURL = URL(string: artworkURLString) {
                item.setImageURL(imageURL, for: .screenScale1x)
                item.setImageURL(imageURL, for: .screenScale2x)
                DLOG("TopShelf: Using remote artwork URL for \(title): \(artworkURLString)")
            } else {
                WLOG("TopShelf: No artwork available for game \(title), will use default")
            }
        }

        // Set display actions with deep link to game
        if let url = URL(string: "provenance://game/\(md5Hash)") {
            item.playAction = TVTopShelfAction(url: url)
            item.displayAction = TVTopShelfAction(url: url)
        }

        return item
    }
}

/// Extension to handle system image type mapping
extension PVSystem {
    /// Map system to appropriate top shelf image shape
    var imageType: TVTopShelfSectionedItem.ImageShape {
        switch systemIdentifier {
        case .GB, .GBC, .GBA, .NGP, .NGPC, .Lynx, .WS, .WSC, .GG, .PokemonMini:
            return .square
        case .SNES, .NES, .Genesis, .MasterSystem, .N64, .Atari5200, .Atari7800, .Jaguar:
            return .hdtv
        case .PSX, .Saturn, .Dreamcast, .PS2, .PS3, .GameCube, .Wii:
            return .hdtv
        default:
            return .square
        }
    }
}
