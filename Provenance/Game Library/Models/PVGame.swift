//
//  PVGame.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/02/2018.
//  Copyright (c) 2018 JamSoft. All rights reserved.
//

import Foundation
import RealmSwift

// Hack for game library having eitehr PVGame or PVRecentGame in containers
protocol PVLibraryEntry where Self: Object {}

@objcMembers public class PVGame: Object, PVLibraryEntry {
    dynamic var title: String				= ""
	dynamic var id							= NSUUID().uuidString

    // TODO: This is a 'partial path' meaing it's something like {system id}.filename
    // We should make this an absolute path but would need a Realm translater and modifying
    // any methods that use this path. Everything should use PVEmulatorConfigure path(forGame:)
    // and then we just need to change that method but I haven't check that every method uses that
    // The other option is to only use the filename and then path(forGame:) would determine the
    // fully qualified path, but if we add network / cloud storage that may or may not change that.
    dynamic var romPath: String            = ""
    dynamic var file: PVFile!
	var relatedFiles = List<PVFile>()

    dynamic var customArtworkURL: String   = ""
    dynamic var originalArtworkURL: String = ""
    dynamic var originalArtworkFile: PVImageFile?

    dynamic var requiresSync: Bool         = true
    dynamic var isFavorite: Bool           = false

    dynamic var romSerial: String?
	dynamic var romHeader: String?
    dynamic var importDate: Date           = Date()

    dynamic var systemIdentifier: String   = ""
    dynamic var system: PVSystem!

    dynamic var md5Hash: String            = ""

	// If the user has set 'always use' for a specfic core
	// We don't use PVCore incase cores are removed / deleted
	dynamic var userPreferredCoreID : String?

    /* Links to other objects */
    var saveStates = LinkingObjects<PVSaveState>(fromType: PVSaveState.self, property: "game")
    var recentPlays = LinkingObjects(fromType: PVRecentGame.self, property: "game")
    var screenShots = List<PVImageFile>()

	var libraries = LinkingObjects<PVLibrary>(fromType: PVLibrary.self, property: "games")

    /* Tracking data */
    dynamic var lastPlayed: Date?
    dynamic var playCount: Int = 0
    dynamic var timeSpentInGame: Int = 0
    dynamic var rating: Int = -1 {
        willSet {
            assert(-1 ... 5 ~= newValue, "Setting rating out of range -1 to 5")
        }
        didSet {
            if rating > 5 || rating < -1 {
                rating = oldValue
            }
        }
    }

    /* Extra metadata from OpenBG */
    dynamic var gameDescription: String?
    dynamic var boxBackArtworkURL: String?
    dynamic var developer: String?
    dynamic var publisher: String?
    dynamic var publishDate: String?
    dynamic var genres: String? // Is a comma seperated list or single entry
    dynamic var referenceURL: String?
    dynamic var releaseID: String?
    dynamic var regionName: String?
	dynamic var regionID: Int?
    dynamic var systemShortName: String?
	dynamic var language: String?

    convenience init(withFile file: PVFile, system: PVSystem) {
        self.init()
        self.file = file
        self.system = system
        self.systemIdentifier = system.identifier
    }

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

public extension PVGame {
	var isCD : Bool {
		let ext = (romPath as NSString).pathExtension
		var exts = PVEmulatorConfiguration.supportedCDFileExtensions
		exts.formUnion(["m3u"])
		return exts.contains(ext.lowercased())
	}

	var discCount : Int {
		if isCD {
			return relatedFiles.filter({ PVEmulatorConfiguration.supportedCDFileExtensions.contains($0.pathExtension.lowercased()) }).count
		} else {
			return 0
		}
	}
}

public extension PVGame {
	var autoSaves : Results<PVSaveState> {
		return saveStates.filter("isAutosave == true").sorted(byKeyPath: "date", ascending: false)
	}

	var newestAutoSave : PVSaveState? {
		return autoSaves.first
	}

	var lastAutosaveAge : TimeInterval? {
		guard let first = autoSaves.first else {
			return nil
		}

		return first.date.timeIntervalSinceNow * -1
	}
}

//public extension PVGame {
//    // Support older code
//    var md5Hash : String {
//        return file.md5!
//    }
//}
