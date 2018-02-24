//
//  PVGame.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/02/2018.
//  Copyright (c) 2018 JamSoft. All rights reserved.
//

import Foundation
import CoreGraphics
import RealmSwift

// Hack for game library having eitehr PVGame or PVRecentGame in containers
protocol PVLibraryEntry where Self: Object {}

public class PVSaveState : Object {

    @objc dynamic var game : PVGame?
    @objc dynamic var path : String?
    @objc dynamic var date : Date = Date()
    @objc dynamic var image : String?
    @objc dynamic var isAutosave : Bool = false
    
    convenience init(withGame game: PVGame, path: String, image : String? = nil, isAutosave : Bool = false) {
        self.init()
        self.game  = game
        self.path  = path
        self.image = image
        self.isAutosave = isAutosave
    }
}

public class PVGame : Object, PVLibraryEntry {
    @objc dynamic var title : String              = ""
    
    // TODO: This is a 'partial path' meaing it's something like {system id}.filename
    // We should make this an absolute path but would need a Realm translater and modifying
    // any methods that use this path. Everything should use PVEmulatorConfigure path(forGame:)
    // and then we just need to change that method but I haven't check that every method uses that
    // The other option is to only use the filename and then path(forGame:) would determine the
    // fully qualified path, but if we add network / cloud storage that may or may not change that.
    @objc dynamic var romPath : String            = ""
    @objc dynamic var customArtworkURL : String   = ""
    @objc dynamic var originalArtworkURL : String = ""

    @objc dynamic var md5Hash : String            = ""

    @objc dynamic var requiresSync : Bool         = true
    @objc dynamic var systemIdentifier : String   = ""

    @objc dynamic var isFavorite : Bool           = false

    @objc dynamic var romSerial : String          = ""
    
    @objc dynamic var importDate : Date           = Date()
    
    /* Linksj to other objects */
    var saveStates : List<PVSaveState>? = nil
    var recentPlays : List<PVRecentGame>? = nil
    
    /* Tracking data */
    @objc dynamic var lastPlayed : Date?
    @objc dynamic var playCount : Int = 0
    @objc dynamic var timeSpentInGame : Int = 0
    
    /* Extra metadata from OpenBG */
    @objc dynamic var gameDescription : String?
    @objc dynamic var boxBackArtworkURL : String?
    @objc dynamic var developer : String?
    @objc dynamic var publisher : String?
    @objc dynamic var publishDate : String?
    @objc dynamic var genres : String? // Is a comma seperated list or single entry
    @objc dynamic var referenceURL : String?
    @objc dynamic var releaseID : String?
    @objc dynamic var regionName : String?
    @objc dynamic var systemShortName : String?


//    @objc dynamic var recent: PVRecentGame?
    /*
        Primary key must be set at import time and can't be changed after.
        I had to change the import flow to calculate the MD5 before import.
        Seems sane enough since it's on the serial queue. Could always use
        an async dispatch if it's an issue. - jm
    */
    override public static func primaryKey() -> String? {
        return "md5Hash"
    }
    
    override public static func indexedProperties() -> [String] {
        return ["systemIdentifier"]
    }
}

// MARK: - Sizing

public enum PVGameBoxArtAspectRatio : CGFloat {
    case square = 1.0
    case wide = 1.45
    case tall = 0.7
}

public extension PVGame {
    var boxartAspectRatio : PVGameBoxArtAspectRatio {
        switch self.system! {
        case .SNES, .N64:
            return .wide
        case .NES, .Genesis, .Sega32X, .Atari2600, .Atari5200, .Atari7800, .WonderSwan, .WonderSwanColor:
            return .tall
        default:
            return .square
        }
    }
}

import CoreSpotlight
import MobileCoreServices
import UIKit

public extension PVGame {
    
    var url : URL {
        return URL(fileURLWithPath: self.romPath, isDirectory: false)
    }
    
    #if os(iOS)
    @available(iOS 9.0, *)
    var spotlightContentSet : CSSearchableItemAttributeSet {
        let systemName = self.systemName
        
        var description = "\(systemName ?? "")"
        
        // Determine if any of these have a value, and if so, seperate them by a space
        let optionalEntries : [String?] = [isFavorite ? "⭐" : nil,
                                           developer,
                                           publishDate != nil ? "(\(publishDate!)" : nil,
                                           regionName != nil ? "(\(regionName!))" : nil]
        let secondLine = optionalEntries.flatMap { (maybeString) -> String? in
            return maybeString
        }.joined(separator: " ")
        if !secondLine.isEmpty {
            description += "\n\(secondLine)"
        }
        
        if let g = genres, !g.isEmpty {
            let genresWithSpaces = g.components(separatedBy: ",").joined(separator: ", ")
            description += "\n\(genresWithSpaces)"
        }
        
        // Maybe should use kUTTypeData?
        let contentSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeImage as String)
        contentSet.title                   = title
        contentSet.relatedUniqueIdentifier = md5Hash
        contentSet.contentDescription      = description
        contentSet.rating                  = NSNumber(booleanLiteral: isFavorite)
        contentSet.thumbnailURL            = pathOfCachedImage
        var keywords                       = ["rom"]
        if let systemName = systemName {
            keywords.append(systemName)
        }
        if let genres = genres {
            keywords.append(contentsOf: genres.components(separatedBy: ","))
        }
        
        contentSet.keywords = keywords
        
        //            contentSet.authorNames             = [data.authorName]
        // Could generate small thumbnail here
        if let p = pathOfCachedImage?.path, let t = UIImage(contentsOfFile: p), let s = t.scaledImage(withMaxResolution: 270) {
            contentSet.thumbnailData = UIImagePNGRepresentation(s)
        }
        return contentSet
    }
    
    var pathOfCachedImage : URL? {
        let artworkKey = customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL
        if !PVMediaCache.fileExists(forKey: artworkKey) {
            return nil
        }
        let artworkURL = PVMediaCache.filePath(forKey: artworkKey)
        return artworkURL
    }
    
    var spotlightUniqueIdentifier : String {
        return "com.provenance-emu.game.\(md5Hash)"
    }
    #endif
    
    var spotlightActivity : NSUserActivity {
        let activity = NSUserActivity(activityType: "com.provenance-emu.game.play")
        activity.title = title
        activity.userInfo = ["md5" : md5Hash]

        if #available(iOS 9.0, tvOS 10.0, *) {
            activity.requiredUserInfoKeys = ["md5"]
            activity.isEligibleForSearch = true
            activity.isEligibleForHandoff = false
            
            #if os(iOS)
            activity.contentAttributeSet  = spotlightContentSet
            #endif
            activity.requiredUserInfoKeys = ["md5"]
//            activity.expirationDate       =
        }

        return activity
    }

    // Don't want to have to import GameLibraryConfiguration in Spotlight extension so copying this required code to map id to short name
    private var systemName : String? {
        return self.system?.name
    }
}
