//
//  PVGame.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/02/2018.
//  Copyright (c) 2018 JamSoft. All rights reserved.
//

import Foundation
import RealmSwift
import AsyncAlgorithms
import PVPrimitives
import PVFileSystem

@objcMembers
public final class PVGame: RealmSwift.Object, Identifiable, PVGameLibraryEntry {
    public dynamic var title: String = ""
    public dynamic var id :String = NSUUID().uuidString

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

    public var validatedGame: PVGame? { return self.isInvalidated ? nil : self }

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

    public static func mockGenerate(systemID: String? = nil, count: Int = 10) -> [PVGame] {
        let systemIdentifier = systemID ?? "mock.system"
        return (1...count).map { index in
            let game = PVGame()
            game.title = "Mock Game \(index)"
            game.systemIdentifier = systemIdentifier
            game.md5Hash = UUID().uuidString // Mock MD5 hash
            game.publishDate = String("\(1980 + count)")
            return game
        }
    }
}

public extension PVGame {
    convenience init(withFile file: PVFile, system: PVSystem) {
        self.init()
        self.file = file
        self.system = system
        systemIdentifier = system.identifier
    }
}

public extension PVGame {
    var isCD: Bool {
        let ext = (romPath as NSString).pathExtension
        let exts = Extensions.discImageExtensions.union(Extensions.playlistExtensions)
        return exts.contains(ext.lowercased())
    }

    var discCount: Int { get {

        @Sendable func _isM3U(_ file: PVFile) -> Bool { file.pathExtension.lowercased() != "m3u" }
        @Sendable func _isCD(_ file: PVFile) -> Bool { Extensions.discImageExtensions.contains(file.pathExtension.lowercased()) }
        let relatedFilesArray = relatedFiles.toArray()

        if self.isCD {
            let filtered = relatedFilesArray
                .filter({ _isM3U($0) })
                .filter({ _isCD($0)}).map(\.self)
                .count
            return filtered
        } else {
            return 0
        }
    }}
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
        let id = game.id
        let title = game.title
        let systemIdentifier = game.systemIdentifier
        let md5 = game.md5Hash
        let crc = game.crc
        let isFavorite = game.isFavorite
        let playCount = UInt(game.playCount)
        let lastPlayed = game.lastPlayed
        let boxBackArtworkURL = game.boxBackArtworkURL
        let developer = game.developer
        let publisher = game.publisher
        let genres = game.genres
        let referenceURL = game.referenceURL
        let releaseID = game.releaseID
        let regionID = game.regionID.value
        let regionName = game.regionName
        let systemShortName = game.systemShortName
        let language = game.language
        let file = FileInfo(fileName: game.file.fileName, size: game.file.size, md5: game.file.md5, online: game.file.online, local: true)
        let gameDescription = game.gameDescription
        let publishDate = game.publishDate
        // TODO: Screenshots
        self.init(id: id, title: title, file: file, systemIdentifier: systemIdentifier, md5: md5, crc: crc, isFavorite: isFavorite, playCount: playCount, lastPlayed: lastPlayed, gameDescription: gameDescription, boxBackArtworkURL: boxBackArtworkURL, developer: developer, publisher: publisher, publishDate: publishDate, genres: genres, referenceURL: referenceURL, releaseID: releaseID, regionName: regionName, regionID: regionID, systemShortName: systemShortName, language: language)
    }

//    init(withGame game: Game_Data) {
//        let id = game.id
//        let title = game.title
//        let systemIdentifier = game.systemIdentifier
//        let md5 = game.md5Hash
//        let crc = game.crc
//        let isFavorite = game.isFavorite
//        let playCount = UInt(game.playCount)
//        let lastPlayed = game.lastPlayed
//        let boxBackArtworkURL = game.boxBackArtworkURL
//        let developer = game.developer
//        let publisher = game.publisher
//        let genres = game.genres
//        let referenceURL = game.referenceURL
//        let releaseID = game.releaseID
//        let regionID = game.regionID
//        let regionName = game.regionName
//        let systemShortName = game.systemShortName
//        let language = game.language
//        let file = FileInfo(fileName: game.file.partialPath, size: game.file.size, md5: game.file.md5, online: game.file.online, local: true)
//        let gameDescription = game.gameDescription
//        let publishDate = game.publishDate
//        // TODO: Screenshots
//        self.init(id: id, title: title, file: file, systemIdentifier: systemIdentifier, md5: md5, crc: crc, isFavorite: isFavorite, playCount: playCount, lastPlayed: lastPlayed, gameDescription: gameDescription, boxBackArtworkURL: boxBackArtworkURL, developer: developer, publisher: publisher, publishDate: publishDate, genres: genres, referenceURL: referenceURL, releaseID: releaseID, regionName: regionName, regionID: regionID, systemShortName: systemShortName, language: language)
//    }
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
            object.file =  PVFile(withPartialPath: file.fileName)
        }
    }
}

// Recently played game as a predicate
//extension PVGame {
//    public static func recentlyPlayed(days: Int) -> Predicate<PVGame> {
//        return Predicate(\.date, .greaterThanOrEqualTo, Date().addingTimeInterval(-TimeInterval(days) * 24 * 60 * 60))
//    }
//}
