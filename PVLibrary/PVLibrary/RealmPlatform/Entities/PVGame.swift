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
public final class PVGame: Object, Identifiable, PVLibraryEntry {
    public dynamic var title: String = ""
    public dynamic var id = NSUUID().uuidString

    // TODO: This is a 'partial path' meaing it's something like {system id}.filename
    // We should make this an absolute path but would need a Realm translater and modifying
    // any methods that use this path. Everything should use PVEmulatorConfigure path(forGame:)
    // and then we just need to change that method but I haven't check that every method uses that
    // The other option is to only use the filename and then path(forGame:) would determine the
    // fully qualified path, but if we add network / cloud storage that may or may not change that.
    public dynamic var romPath: String = ""
    public dynamic var file: PVFile!
    public private(set) var relatedFiles = List<PVFile>()

    public dynamic var customArtworkURL: String = ""
    public dynamic var originalArtworkURL: String = ""
    public dynamic var originalArtworkFile: PVImageFile?

    public dynamic var requiresSync: Bool = true
    public dynamic var isFavorite: Bool = false

    public dynamic var romSerial: String?
    public dynamic var romHeader: String?
    public private(set) dynamic var importDate: Date = Date()

    public dynamic var systemIdentifier: String = ""
    public dynamic var system: PVSystem!

    public dynamic var md5Hash: String = ""
    public dynamic var crc: String = ""

    // If the user has set 'always use' for a specfic core
    // We don't use PVCore incase cores are removed / deleted
    public dynamic var userPreferredCoreID: String?

    /* Links to other objects */
    public private(set) var saveStates = LinkingObjects<PVSaveState>(fromType: PVSaveState.self, property: "game")
    public private(set) var cheats = LinkingObjects<PVCheats>(fromType: PVCheats.self, property: "game")
    public private(set) var recentPlays = LinkingObjects(fromType: PVRecentGame.self, property: "game")
    public private(set) var screenShots = List<PVImageFile>()

    public private(set) var libraries = LinkingObjects<PVLibrary>(fromType: PVLibrary.self, property: "games")

    /* Tracking data */
    public dynamic var lastPlayed: Date?
    public dynamic var playCount: Int = 0
    public dynamic var timeSpentInGame: Int = 0
    public dynamic var rating: Int = -1 {
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
    public dynamic var gameDescription: String?
    public dynamic var boxBackArtworkURL: String?
    public dynamic var developer: String?
    public dynamic var publisher: String?
    public dynamic var publishDate: String?
    public dynamic var genres: String? // Is a comma seperated list or single entry
    public dynamic var referenceURL: String?
    public dynamic var releaseID: String?
    public dynamic var regionName: String?
    public var regionID = RealmProperty<Int?>()
    public dynamic var systemShortName: String?
    public dynamic var language: String?

    public convenience init(withFile file: PVFile, system: PVSystem) {
        self.init()
        self.file = file
        self.system = system
        systemIdentifier = system.identifier
    }
    
    public var validatedGame: PVGame? {
        return self.isInvalidated ? nil : self
    }

    /*
     Primary key must be set at import time and can't be changed after.
     I had to change the import flow to calculate the MD5 before import.
     Seems sane enough since it's on the serial queue. Could always use
     an async dispatch if it's an issue. - jm
     */
    public override static func primaryKey() -> String? {
        return "md5Hash"
    }

    public override static func indexedProperties() -> [String] {
        return ["systemIdentifier"]
    }
}

public extension PVGame {
    var isCD: Bool {
        let ext = (romPath as NSString).pathExtension
        var exts = PVEmulatorConfiguration.supportedCDFileExtensions
        exts.formUnion(["m3u"])
        return exts.contains(ext.lowercased())
    }

    var discCount: Int {
        if isCD {
            return relatedFiles.filter({ PVEmulatorConfiguration.supportedCDFileExtensions.contains($0.pathExtension.lowercased()) }).count
        } else {
            return 0
        }
    }
}

extension PVGame: Filed, LocalFileProvider {}

public extension PVGame {
    var autoSaves: Results<PVSaveState> {
        return saveStates.filter("isAutosave == true").sorted(byKeyPath: "date", ascending: false)
    }

    var newestAutoSave: PVSaveState? {
        return autoSaves.first
    }

    var lastAutosaveAge: TimeInterval? {
        guard let first = autoSaves.first else {
            return nil
        }

        return first.date.timeIntervalSinceNow * -1
    }
}

// MARK: Conversions

public extension Game {
    init(withGame game: PVGame) {
        id = game.id
        title = game.title
        systemIdentifier = game.systemIdentifier
        md5 = game.md5Hash
        crc = game.crc
        isFavorite = game.isFavorite
        playCount = UInt(game.playCount)
        lastPlayed = game.lastPlayed
        boxBackArtworkURL = game.boxBackArtworkURL
        developer = game.developer
        publisher = game.publisher
        genres = game.genres
        referenceURL = game.referenceURL
        releaseID = game.releaseID
        regionID = game.regionID.value
        regionName = game.regionName
        systemShortName = game.systemShortName
        language = game.language
        file = FileInfo(fileName: game.file.fileName, size: game.file.size, md5: game.file.md5, online: game.file.online, local: true)
        gameDescription = game.gameDescription
        publishDate = game.publishDate
        // TODO: Screenshots
    }
}

extension PVGame: DomainConvertibleType {
    public typealias DomainType = Game

    public func asDomain() -> Game {
        return Game(withGame: self)
    }
}

extension Game: RealmRepresentable {
    public var uid: String {
        return md5
    }

    public func asRealm() -> PVGame {
        let realm = try! Realm()
        if let existing = realm.object(ofType: PVGame.self, forPrimaryKey: md5) {
            return existing
        }

        return PVGame.build { object in
            object.id = id
            object.title = title
            // TODO: Test that file is correct
            object.file = PVFile(withPartialPath: file.fileName)
            object.md5Hash = md5
            object.crc = crc
            object.isFavorite = isFavorite
            object.playCount = Int(playCount)
            object.lastPlayed = lastPlayed

            let realm = try! Realm()
            object.system = realm.object(ofType: PVSystem.self, forPrimaryKey: "identifier")

            object.gameDescription = gameDescription
            object.boxBackArtworkURL = boxBackArtworkURL
            object.developer = developer
            object.publisher = publisher
            object.publishDate = publishDate
            object.genres = genres // Is a comma seperated list or single entry
            object.referenceURL = referenceURL
            object.releaseID = releaseID
            object.regionName = regionName
            object.regionID.value = regionID
            object.systemShortName = systemShortName
            object.language = language
        }
    }
}
