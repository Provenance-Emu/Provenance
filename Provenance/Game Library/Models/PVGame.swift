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

