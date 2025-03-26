//
//  ImportExtension.swift
//  SpotlightImportExtension
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import CoreSpotlight
import PVLibrary
import PVSupport
import RealmSwift

// https://developer.apple.com/documentation/corespotlight/csimportextension

class ImportExtension: CSImportExtension {
    
    override func update(_ attributes: CSSearchableItemAttributeSet, forFileAt: URL) throws {
        // Add attributes that describe the file at contentURL.
        // Throw an error with details on failure.
        #warning("TODO: Make this search the database for the file and add attributes")
        #warning("TODO: Make this support save states, cheats, and other related objects")

        if RealmConfiguration.supportsAppGroups {
            guard let md5Hash = FileManager.default.md5ForFile(at: forFileAt, fromOffset: 0)  else {
                WLOG("No MD5 hash found for file")
                return
            }
            let database = RomDatabase.sharedInstance
            
            guard let game = database.all(PVGame.self, filter: NSPredicate(format: "md5Hash IN %@", md5Hash)).first else {
                WLOG("No game found for file")
                return
            }
            
            attributes.displayName = game.title
            attributes.contentDescription = game.gameDescription
            attributes.keywords = game.genres?.split(separator: ",").map(String.init)
            
            let customArtworkURL = game.customArtworkURL
            let artworkURL = game.originalArtworkURL
            if !customArtworkURL.isEmpty {
                attributes.thumbnailURL = URL(string: customArtworkURL)
            } else if !artworkURL.isEmpty {
                attributes.thumbnailURL = URL(string: artworkURL)
            }
                    
        } else {
            WLOG("App Groups not setup")
        }
    }
    
}
