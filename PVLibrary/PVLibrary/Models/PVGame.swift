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

@objcMembers
public final class PVGame: Object, PVLibraryEntry {
    dynamic public var title: String				= ""
	dynamic public var id							= NSUUID().uuidString

    // TODO: This is a 'partial path' meaing it's something like {system id}.filename
    // We should make this an absolute path but would need a Realm translater and modifying
    // any methods that use this path. Everything should use PVEmulatorConfigure path(forGame:)
    // and then we just need to change that method but I haven't check that every method uses that
    // The other option is to only use the filename and then path(forGame:) would determine the
    // fully qualified path, but if we add network / cloud storage that may or may not change that.
    dynamic public var romPath: String            = ""
    dynamic public var file: PVFile!
	public private(set) var relatedFiles = List<PVFile>()

    dynamic public var customArtworkURL: String   = ""
    dynamic public var originalArtworkURL: String = ""
    dynamic public var originalArtworkFile: PVImageFile?

    dynamic public var requiresSync: Bool         = true
    dynamic public var isFavorite: Bool           = false

    dynamic public var romSerial: String?
	dynamic public var romHeader: String?
    dynamic public private(set) var importDate: Date           = Date()

    dynamic public var systemIdentifier: String   = ""
    dynamic public var system: PVSystem!

    dynamic public var md5Hash: String            = ""
	dynamic public var crc: String            = ""

	// If the user has set 'always use' for a specfic core
	// We don't use PVCore incase cores are removed / deleted
	dynamic public var userPreferredCoreID : String?

    /* Links to other objects */
    public private(set) var saveStates = LinkingObjects<PVSaveState>(fromType: PVSaveState.self, property: "game")
    public private(set) var recentPlays = LinkingObjects(fromType: PVRecentGame.self, property: "game")
    public private(set) var screenShots = List<PVImageFile>()

	public private(set) var libraries = LinkingObjects<PVLibrary>(fromType: PVLibrary.self, property: "games")

    /* Tracking data */
    dynamic public var lastPlayed: Date?
    dynamic public var playCount: Int = 0
    dynamic public var timeSpentInGame: Int = 0
    dynamic public var rating: Int = -1 {
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
    dynamic public var gameDescription: String?
    dynamic public var boxBackArtworkURL: String?
    dynamic public var developer: String?
    dynamic public var publisher: String?
    dynamic public var publishDate: String?
    dynamic public var genres: String? // Is a comma seperated list or single entry
    dynamic public var referenceURL: String?
    dynamic public var releaseID: String?
    dynamic public var regionName: String?
	dynamic public var regionID: Int?
    dynamic public var systemShortName: String?
	dynamic public var language: String?

    public convenience init(withFile file: PVFile, system: PVSystem) {
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
	public var isCD : Bool {
		let ext = (romPath as NSString).pathExtension
		var exts = PVEmulatorConfiguration.supportedCDFileExtensions
		exts.formUnion(["m3u"])
		return exts.contains(ext.lowercased())
	}

	public var discCount : Int {
		if isCD {
			return relatedFiles.filter({ PVEmulatorConfiguration.supportedCDFileExtensions.contains($0.pathExtension.lowercased()) }).count
		} else {
			return 0
		}
	}
}

public extension PVGame {
	public var autoSaves : Results<PVSaveState> {
		return saveStates.filter("isAutosave == true").sorted(byKeyPath: "date", ascending: false)
	}

	public var newestAutoSave : PVSaveState? {
		return autoSaves.first
	}

	public var lastAutosaveAge : TimeInterval? {
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
