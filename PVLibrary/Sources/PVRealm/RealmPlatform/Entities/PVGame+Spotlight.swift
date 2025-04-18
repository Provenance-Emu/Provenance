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
        
            let systemName = self.systemName

            var description = "\(systemName ?? "")"

            // Determine if any of these have a value, and if so, seperate them by a space
            let optionalEntries: [String?] = [isFavorite ? "⭐" : nil,
                                              developer,
                                              publishDate != nil ? "(\(publishDate!)" : nil,
                                              regionName != nil ? "(\(regionName!))" : nil]

        let secondLine = optionalEntries.compactMap { (maybeString) -> String? in
            maybeString
        }.joined(separator: " ")
            if !secondLine.isEmpty {
                description += "\n\(secondLine)"
            }

            if let g = genres, !g.isEmpty, !md5Hash.isEmpty {
                let genresWithSpaces = g.components(separatedBy: ",").joined(separator: ", ")
                description += "\n\(genresWithSpaces)"
            }

            // Maybe should use kUTTypeData?
            let contentSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeImage as String)
            contentSet.title = title
            contentSet.relatedUniqueIdentifier = md5Hash
            contentSet.contentDescription = description
            contentSet.rating = NSNumber(value: isFavorite)
            contentSet.thumbnailURL = pathOfCachedImage
            var keywords = ["rom"]
            if let systemName = systemName {
                keywords.append(systemName)
            }
            if let genres = genres {
                keywords.append(contentsOf: genres.components(separatedBy: ","))
            }

            contentSet.keywords = keywords

            //            contentSet.authorNames             = [data.authorName]
            // Could generate small thumbnail here
            if let p = pathOfCachedImage?.path,
               let t = UIImage(contentsOfFile: p),
               let s = t.scaledImage(withMaxResolution: 270) {
                contentSet.thumbnailData = s.jpegData(compressionQuality: 0.95)
            }
            return contentSet
        }

    var pathOfCachedImage: URL? {
            let artworkKey = customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL
            if !PVMediaCache.fileExists(forKey: artworkKey) {
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
        let activity = NSUserActivity(activityType: "org.provenance-emu.game.play")
        activity.title = title
        activity.userInfo = ["md5": md5Hash]

        activity.requiredUserInfoKeys = ["md5"]
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = false

        #if os(iOS)
            activity.contentAttributeSet = spotlightContentSet
        #endif
        activity.requiredUserInfoKeys = ["md5"]
        //            activity.expirationDate       =

        return activity
    }

    // Don't want to have to import GameLibraryConfiguration in Spotlight
    // extension so copying this required code to map id to short name
    private var systemName: String? {
        return system?.name
    }
}
