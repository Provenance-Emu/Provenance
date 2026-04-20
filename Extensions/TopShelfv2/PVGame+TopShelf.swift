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

    /// Generates (and caches in the app group container) a retrowave placeholder
    /// PNG that matches the in-app default artwork. Returns nil if the app group
    /// container is unavailable or PNG encoding fails.
    fileprivate func placeholderArtworkURL() -> URL? {
        let ratio = PVGame.boxArtAspectPlaceholder(
            systemIdentifier: systemIdentifier,
            regionName: regionName
        ).rawValue
        return MissingArtworkGenerator.cachedPlaceholderURL(
            gameTitle: title,
            ratio: ratio,
            pattern: .rainbowNoise,
            isDarkTheme: true
        )
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
            } else if let placeholderURL = placeholderArtworkURL() {
                /// Use the same retrowave placeholder the in-app library shows for missing artwork.
                item.setImageURL(placeholderURL, for: .screenScale1x)
                item.setImageURL(placeholderURL, for: .screenScale2x)
                DLOG("TopShelf: Using retrowave placeholder for \(title): \(placeholderURL.path)")
            } else {
                WLOG("TopShelf: No artwork available for game \(title), will use default")
            }
        }

        // Create deep link URL in the format the app expects: provenance://open?md5={hash}
        if let url = URL(string: "provenance://open?md5=\(md5Hash)") {
            item.playAction = TVTopShelfAction(url: url)
            item.displayAction = TVTopShelfAction(url: url)
            DLOG("TopShelf: Set deep link for \(title): \(url.absoluteString)")
        }

        return item
    }
}

/// Extension to handle system image type mapping
extension PVSystem {
    /// Map system to appropriate top shelf image shape
    var imageType: TVTopShelfSectionedItem.ImageShape {
        switch systemIdentifier {
        case .GB, .GBC, .GBA, .NGP, .NGPC, .Lynx, .WonderSwan, .WonderSwanColor, .GameGear, .PokemonMini:
            return .square
        case .SNES, .NES, .Genesis, .MasterSystem, .N64, .Atari5200, .Atari7800, .AtariJaguar, .AtariJaguarCD:
            return .hdtv
        case .PSX, .Saturn, .Dreamcast, .PS2, .PS3, .GameCube, .Wii:
            return .hdtv
        default:
            return .square
        }
    }
}

extension PVSaveState {
    /// Builds a TopShelf item that opens this save state (falls back to opening the game if needed).
    func topShelfItem() -> TVTopShelfSectionedItem {
        let item = TVTopShelfSectionedItem(identifier: id)

        let gameTitle = game.title
        var titleComponents: [String] = [gameTitle]

        /// Add system name for context
        if let systemName = game.system?.name {
            titleComponents.append("(\(systemName))")
        }

        /// Add relative date information for better context
        let dateToShow = lastOpened ?? date
        let relativeDate = formatRelativeDate(dateToShow)
        if !relativeDate.isEmpty {
            titleComponents.append("• \(relativeDate)")
        }

        item.title = titleComponents.joined(separator: " ")

        if let system = game.system {
            item.imageShape = system.imageType
        } else {
            item.imageShape = .square
        }

        if let imageURL = resolveTopShelfImageURL() {
            item.setImageURL(imageURL, for: .screenScale1x)
            item.setImageURL(imageURL, for: .screenScale2x)
        } else if let fallbackArtworkURL = game.cachedArtworkURL {
            item.setImageURL(fallbackArtworkURL, for: .screenScale1x)
            item.setImageURL(fallbackArtworkURL, for: .screenScale2x)
        } else if let placeholderURL = game.placeholderArtworkURL() {
            /// Use the same retrowave placeholder the in-app library shows for missing artwork.
            item.setImageURL(placeholderURL, for: .screenScale1x)
            item.setImageURL(placeholderURL, for: .screenScale2x)
            DLOG("TopShelf: Using retrowave placeholder for save state of \(gameTitle): \(placeholderURL.path)")
        }

        if let url = URL(string: "provenance://open?saveStateId=\(id)") {
            item.playAction = TVTopShelfAction(url: url)
            item.displayAction = TVTopShelfAction(url: url)
        }

        return item
    }

    /// Formats a date as a relative time string (e.g., "2 hours ago", "Yesterday", "3 days ago")
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)

        if let days = components.day, days > 0 {
            if days == 1 {
                return "Yesterday"
            } else if days < 7 {
                return "\(days) days ago"
            } else if days < 30 {
                let weeks = days / 7
                return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
            } else {
                let months = days / 30
                return months == 1 ? "1 month ago" : "\(months) months ago"
            }
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }

    private func resolveTopShelfImageURL() -> URL? {
        let fileManager = FileManager.default

        if let directURL = image?.url, fileManager.fileExists(atPath: directURL.path) {
            return directURL
        }

        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId),
              let image = image else {
            return nil
        }

        let stableKeyHash = "topshelf_savestate_\(id)".md5Hash
        let stableCandidates: [URL] = [
            groupURL.appendingPathComponent("Documents/PVCache/\(stableKeyHash)"),
            groupURL.appendingPathComponent("Caches/PVCache/\(stableKeyHash)"),
            groupURL.appendingPathComponent("Library/Caches/PVCache/\(stableKeyHash)"),
            groupURL.appendingPathComponent("PVCache/\(stableKeyHash)")
        ]

        for url in stableCandidates where fileManager.fileExists(atPath: url.path) {
            return url
        }

        let relativePath = image.actualPartialPath
        let directCandidates: [URL] = [
            groupURL.appendingPathComponent("Caches").appendingPathComponent(relativePath),
            groupURL.appendingPathComponent("Documents").appendingPathComponent(relativePath),
            groupURL.appendingPathComponent(relativePath)
        ]

        for url in directCandidates where fileManager.fileExists(atPath: url.path) {
            return url
        }

        let cacheKeyCandidates: [String] = {
            guard let url = image.url else { return [] }
            return [
                url.lastPathComponent,
                url.path,
                url.absoluteString,
                "savestate_image_\(url.absoluteString)"
            ].filter { !$0.isEmpty }
        }()

        for key in cacheKeyCandidates {
            let keyHash = key.md5Hash
            let hashedCandidates: [URL] = [
                groupURL.appendingPathComponent("Documents/PVCache/\(keyHash)"),
                groupURL.appendingPathComponent("Caches/PVCache/\(keyHash)"),
                groupURL.appendingPathComponent("Library/Caches/PVCache/\(keyHash)"),
                groupURL.appendingPathComponent("PVCache/\(keyHash)")
            ]
            for url in hashedCandidates where fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
