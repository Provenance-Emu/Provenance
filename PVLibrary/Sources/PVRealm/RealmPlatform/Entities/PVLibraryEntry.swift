//
//  PVLibraryEntry.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/3/24.
//

import Foundation
import RealmSwift
import AsyncAlgorithms
import PVPrimitives

// Hack for game library having eitehr PVGame or PVRecentGame in containers
public protocol PVLibraryEntry where Self: RealmSwift.Object {
    
}

public protocol PVRecentGameLibraryEntry: PVLibraryEntry {
    dynamic var game: PVGame! { get }
    dynamic var lastPlayedDate: Date { get }
    dynamic var core: PVCore? { get }
}

public protocol PVGameLibraryEntry: PVLibraryEntry {
    
       dynamic var title: String { get }
       dynamic var id: String { get }

       dynamic var romPath: String { get }
       dynamic var file: PVFile! { get }
       var relatedFiles: List<PVFile> { get }

       dynamic var customArtworkURL: String { get }
       dynamic var originalArtworkURL: String { get }
       dynamic var originalArtworkFile: PVImageFile? { get }

       dynamic var requiresSync: Bool { get }
       dynamic var isFavorite: Bool { get }

       dynamic var romSerial: String? { get }
       dynamic var romHeader: String?{ get }
       dynamic var importDate: Date { get }

       dynamic var systemIdentifier: String { get }
       dynamic var system: PVSystem! { get }

       dynamic var md5Hash: String { get }
       dynamic var crc: String { get }

       // If the user has set 'always use' for a specfic core
       // We don't use PVCore incase cores are removed / deleted
       dynamic var userPreferredCoreID: String? { get }

       /* Links to other objects */
       var saveStates:LinkingObjects<PVSaveState> { get }
       var cheats: LinkingObjects<PVCheats> { get }
       var recentPlays: LinkingObjects<PVRecentGame> { get }
       var screenShots: List<PVImageFile> { get }

       var libraries: LinkingObjects<PVLibrary> { get }

       /* Tracking data */
       dynamic var lastPlayed: Date? { get  }
       dynamic var playCount: Int { get  }
       dynamic var timeSpentInGame: Int { get }
       dynamic var rating: Int { get }

       /* Extra metadata from OpenVGDB and others */
       dynamic var gameDescription: String? { get }
       dynamic var boxBackArtworkURL: String? { get }
       dynamic var developer: String? { get }
       dynamic var publisher: String? { get }
       dynamic var publishDate: String? { get }
       dynamic var genres: String? { get } // Is a comma seperated list or single entry
       dynamic var referenceURL: String? { get }
       dynamic var releaseID: String? { get  }
       dynamic var regionName: String? { get }
       var regionID: Int? { get }
       dynamic var systemShortName: String? { get }
       dynamic var language: String? { get }

       var validatedGame: PVGame? { get }
}
