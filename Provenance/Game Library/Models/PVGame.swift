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

public class PVGame : Object, PVLibraryEntry {
    @objc dynamic var title : String = ""
    @objc dynamic var romPath : String = ""
    @objc dynamic var customArtworkURL : String = ""
    @objc dynamic var originalArtworkURL : String = ""
    
    @objc dynamic var md5Hash : String = ""

    @objc dynamic var requiresSync : Bool = true
    @objc dynamic var systemIdentifier : String = ""

    @objc dynamic var isFavorite : Bool = false

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
let PVGameBoxArtAspectRatioSquare: CGFloat = 1.0
let PVGameBoxArtAspectRatioWide: CGFloat = 1.45
let PVGameBoxArtAspectRatioTall: CGFloat = 0.7

public extension PVGame {
    @objc
    var boxartAspectRatio : CGFloat {
        var imageAspectRatio: CGFloat = PVGameBoxArtAspectRatioSquare
        if (systemIdentifier == PVSNESSystemIdentifier) || (systemIdentifier == PVN64SystemIdentifier) {
            imageAspectRatio = PVGameBoxArtAspectRatioWide
        }
        else if (systemIdentifier == PVNESSystemIdentifier) || (systemIdentifier == PVGenesisSystemIdentifier) || (systemIdentifier == PV32XSystemIdentifier) || (systemIdentifier == PV2600SystemIdentifier) || (systemIdentifier == PV5200SystemIdentifier) || (systemIdentifier == PV7800SystemIdentifier) || (systemIdentifier == PVWonderSwanSystemIdentifier) {
            imageAspectRatio = PVGameBoxArtAspectRatioTall
        }
        return imageAspectRatio
    }
}

import CoreSpotlight
import MobileCoreServices
import UIKit

public extension PVGame {
    
    #if os(iOS)
    @available(iOS 9.0, *)
    var spotlightContentSet : CSSearchableItemAttributeSet {
        let systemName = self.systemName
        
        var description = "\(systemName ?? "")"
        if isFavorite {
            description += "\n⭐"
        }
        
        // Maybe should use kUTTypeData?
        let contentSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeImage as String)
        contentSet.title                   = title
        contentSet.relatedUniqueIdentifier = md5Hash
        contentSet.contentDescription      = description
        contentSet.rating                  = NSNumber(booleanLiteral: isFavorite)
        contentSet.thumbnailURL            = pathOfCachedImage
        contentSet.keywords                = ["rom", systemName ?? ""]
//        contentSet.path                    = romPath
        
        //            contentSet.authorNames             = [data.authorName]
        // Could generate small thumbnail here
        if let p = pathOfCachedImage?.path, let t = UIImage(contentsOfFile: p), let s = t.scaledImage(withMaxResolution: 270) {
            contentSet.thumbnailData = UIImagePNGRepresentation(s)
        }
        return contentSet
    }
    
    var pathOfCachedImage : URL? {
        let artworkKey = customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL
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
        
        guard let plist = Bundle.main.url(forResource: "systems", withExtension: "plist"), let systems = NSArray.init(contentsOf: plist) as? [[String: Any]] else {
            ELOG("Couldn't read systems plist")
            return nil
        }

        for system in systems {
            if let ident = system[PVSystemIdentifierKey] as? String, ident == systemIdentifier {
                return system[PVShortSystemNameKey] as? String
            }
        }
        return nil
    }
}
