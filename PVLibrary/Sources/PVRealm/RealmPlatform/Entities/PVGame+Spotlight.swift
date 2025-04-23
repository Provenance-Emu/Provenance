//
//  PVGame+Spotlight.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

#if canImport(CoreSpotlight)
import CoreSpotlight
#endif

import CoreServices
import PVMediaCache

#if canImport(UIKit)
import UIKit
#else
import AppKit
typealias UIImage = NSImage
#endif
// import UIKit

public extension PVGame {
    var url: URL? { get {
        return file?.url
    }}

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    var spotlightContentSet: CSSearchableItemAttributeSet {
        guard !isInvalidated else {
            return CSSearchableItemAttributeSet()
        }

        /// Create a content set using a more specific UTType for better handling
        let contentSet = CSSearchableItemAttributeSet(itemContentType: "org.provenance-emu.game")

        // Primary metadata
        contentSet.title = title
        contentSet.relatedUniqueIdentifier = md5Hash

        // System information
        let systemName = self.systemName

        // Create a rich, structured description
        var descriptionComponents: [String] = []

        // System name as first line
        if let systemName = systemName {
            descriptionComponents.append("\(systemName)")
        }

        // Second line with optional metadata
        var secondLineComponents: [String] = []
        if isFavorite {
            secondLineComponents.append("⭐ Favorite")
        }
        if let developer = developer, !developer.isEmpty {
            secondLineComponents.append(developer)
        }
        if let publishDate = publishDate {
            secondLineComponents.append("(\(publishDate))")
        }
        if let regionName = regionName, !regionName.isEmpty {
            secondLineComponents.append("Region: \(regionName)")
        }

        if !secondLineComponents.isEmpty {
            descriptionComponents.append(secondLineComponents.joined(separator: " | "))
        }

        // Genres as third line
        if let g = genres, !g.isEmpty {
            let genresWithSpaces = g.components(separatedBy: ",").joined(separator: ", ")
            descriptionComponents.append("Genres: \(genresWithSpaces)")
        }

        // Combine all description components
        contentSet.contentDescription = descriptionComponents.joined(separator: "\n")

        // Rating (for favorited games)
        contentSet.rating = NSNumber(value: isFavorite ? 5 : 0)

        // Images
        contentSet.thumbnailURL = pathOfCachedImage

        // Add a high-quality thumbnail
        if let imagePath = pathOfCachedImage?.path,
           let image = UIImage(contentsOfFile: imagePath) {
            // Try to get a high-quality thumbnail
            let size = CGSize(width: 300, height: 300)
            if let scaledImage = image.scaledImage(withMaxResolution: 300) {
                contentSet.thumbnailData = scaledImage.jpegData(compressionQuality: 0.9)
            } else {
                // Fallback to original image data
                contentSet.thumbnailData = image.jpegData(compressionQuality: 0.8)
            }
        }

        // Comprehensive keywords for better search
        var keywords: [String] = ["rom", "game", "emulator", "provenance"]

        // Add system name and manufacturer
        if let systemName = systemName {
            keywords.append(systemName)
            // Add variations of the system name for better matching
            if systemName.contains(" ") {
                keywords.append(contentsOf: systemName.components(separatedBy: " "))
            }
        }

        if let manufacturer = system?.manufacturer {
            keywords.append(manufacturer)
        }

        // Add all genres
        if let genres = genres, !genres.isEmpty {
            keywords.append(contentsOf: genres.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        }

        // Add developer
        if let developer = developer, !developer.isEmpty {
            keywords.append(developer)
        }

        // Add region
        if let regionName = regionName, !regionName.isEmpty {
            keywords.append(regionName)
        }

        // Add variations of the title for better matching
        keywords.append(title)
        if title.contains(" ") {
            let titleWords = title.components(separatedBy: " ")
            keywords.append(contentsOf: titleWords.filter { $0.count > 2 }) // Only add words longer than 2 characters
        }

        // Convert to NSArray for CoreSpotlight
        contentSet.keywords = keywords

        // Additional metadata
        contentSet.contentType = systemName
        if let system = system {
            // Convert publishDate (String) to NSDate if available
            if let publishDate = publishDate {
                // Use a date formatter to convert the string to a date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy" // Assuming the publish date is just a year
                if let date = dateFormatter.date(from: publishDate) {
                    contentSet.contentCreationDate = date
                }
            }
            contentSet.subject = "\(system.manufacturer) \(system.name)"
        }

        // Make the item displayable in Spotlight
        contentSet.supportsNavigation = true

        return contentSet
    }

    var pathOfCachedImage: URL? {
        let artworkKey = customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL
        if artworkKey.isEmpty || !PVMediaCache.fileExists(forKey: artworkKey) {
            return nil
        }
        let artworkURL = PVMediaCache.filePath(forKey: artworkKey)
        return artworkURL
    }

    var spotlightUniqueIdentifier: String {
        guard !self.isInvalidated else { return "invalid" }
        return "org.provenance-emu.game.\(md5Hash)"
    }
#endif

    var spotlightActivity: NSUserActivity {
        guard !self.isInvalidated else { return NSUserActivity() }
        let activity = NSUserActivity(activityType: "org.provenance-emu.game-search")
        activity.title = title
        activity.userInfo = ["md5": md5Hash]

        activity.requiredUserInfoKeys = ["md5"]
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = true

        #if os(iOS)
        activity.persistentIdentifier = spotlightUniqueIdentifier
        activity.contentAttributeSet = spotlightContentSet
        #endif

        // Set a web URL for fallback
        activity.webpageURL = URL(string: "provenance://game/\(md5Hash)")

        return activity
    }

    // Don't want to have to import GameLibraryConfiguration in Spotlight
    // extension so copying this required code to map id to short name
    private var systemName: String? {
        return system?.name
    }
}
