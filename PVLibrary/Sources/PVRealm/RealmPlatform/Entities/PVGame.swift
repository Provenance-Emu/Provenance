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
import PVSystems

@objcMembers
public final class PVGame: RealmSwift.Object, Identifiable, PVGameLibraryEntry {
    @Persisted public var title: String = ""
    @Persisted(wrappedValue: NSUUID().uuidString, indexed: true) public var id :String

    // TODO: This is a 'partial path' meaing it's something like {system id}.filename
    // We should make this an absolute path but would need a Realm translater and modifying
    // any methods that use this path. Everything should use PVEmulatorConfigure path(forGame:)
    // and then we just need to change that method but I haven't check that every method uses that
    // The other option is to only use the filename and then path(forGame:) would determine the
    // fully qualified path, but if we add network / cloud storage that may or may not change that.
    @Persisted public var romPath: String = ""
    @Persisted public var file: PVFile?
    @Persisted public private(set) var relatedFiles: List<PVFile>

    @Persisted public var customArtworkURL: String = ""
    @Persisted public var originalArtworkURL: String = ""
    @Persisted public var originalArtworkFile: PVImageFile?
    
    public var artworkURL: String {
        get { customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL }
        set { customArtworkURL = newValue }
    }

    @Persisted public var requiresSync: Bool = true
    @Persisted(indexed: true) public var isFavorite: Bool = false

    @Persisted public var romSerial: String?
    @Persisted public var romHeader: String?
    @Persisted public private(set) var importDate: Date = Date()

    @Persisted(indexed: true) public var systemIdentifier: String = ""
    @Persisted public var system: PVSystem?

    /*
     Primary key must be set at import time and can't be changed after.
     I had to change the import flow to calculate the MD5 before import.
     Seems sane enough since it's on the serial queue. Could always use
     an async dispatch if it's an issue. - jm
     */
 
    @Persisted(primaryKey: true) public var md5Hash: String = ""
    @Persisted public var crc: String = ""

    // If the user has set 'always use' for a specfic core
    // We don't use PVCore incase cores are removed / deleted
    @Persisted public var userPreferredCoreID: String?
    
    @Persisted public var contentless: Bool = false

    /* Links to other objects */
    @Persisted(originProperty: "game") public var saveStates: LinkingObjects<PVSaveState>
    @Persisted(originProperty: "game") public var cheats: LinkingObjects<PVCheats>
    @Persisted(originProperty: "game") public var recentPlays: LinkingObjects<PVRecentGame>
    @Persisted public private(set) var screenShots: List<PVImageFile>

    @Persisted(originProperty: "games") public private(set) var libraries: LinkingObjects<PVLibrary>

    /* Tracking data */
    @Persisted public var lastPlayed: Date?
    @Persisted public var playCount: Int = 0
    @Persisted public var timeSpentInGame: Int = 0
    @Persisted public var rating: Int = -1 {
        willSet {
            assert(-1 ... 5 ~= newValue, "Setting rating out of range -1 to 5")
        }
        didSet {
            if rating > 5 || rating < -1 {
                rating = oldValue
            }
        }
    }

    /* Extra metadata from OpenVGDB */
    @Persisted public var gameDescription: String?
    @Persisted public var boxBackArtworkURL: String?
    @Persisted public var developer: String?
    @Persisted public var publisher: String?
    @Persisted public var publishDate: String?
    @Persisted public var genres: String? // Is a comma seperated list or single entry
    @Persisted public var referenceURL: String?
    @Persisted public var releaseID: String?
    @Persisted public var regionName: String?
    @Persisted public var regionID: Int?
    @Persisted public var systemShortName: String?
    @Persisted public var language: String?
    
    public var selectedDiscFilename: String?

    public var validatedGame: PVGame? { return self.isInvalidated ? nil : self }

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
    
    public static func contentlessGenerate(core: PVCore, title: String? = nil) -> PVGame {
        let systemIdentifier = core.supportedSystems.first?.identifier ?? SystemIdentifier.RetroArch.rawValue
        let game = PVGame()
        game.title = core.projectName
        game.systemIdentifier = systemIdentifier
        game.md5Hash = core.identifier // Mock MD5 hash
        game.publishDate = core.projectVersion
        game.userPreferredCoreID = core.identifier
        game.contentless = true
        game.file = PVFile.init(withPartialPath: "", relativeRoot: .caches, size: 0, md5: core.identifier)
        game.system = core.supportedSystems.first!
        return game
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
    
    var genresArray: [String] {
        genres?.components(separatedBy: ",") ?? []
    }
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
        let regionID = game.regionID
        let regionName = game.regionName
        let systemShortName = game.systemShortName
        let language = game.language
        let file = FileInfo(fileName: game.file?.fileName ?? "",
                            size: game.file?.size ?? 0,
                            md5: game.file?.md5 ?? "",
                            online: game.file?.online ?? true,
                            local: true)
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
        try! Realm().buildGame(from: self)
    }
}

public extension Realm {
    func buildGame(from game: Game) -> PVGame {
        if let existing = object(ofType: PVGame.self, forPrimaryKey: game.md5) {
            return existing
        }

        return PVGame.build { object in
            object.id = game.id
            object.title = game.title
            // TODO: Test that file is correct
            object.md5Hash = game.md5
            object.crc = game.crc
            object.isFavorite = game.isFavorite
            object.playCount = Int(game.playCount)
            object.lastPlayed = game.lastPlayed
            
            object.system = self.object(ofType: PVSystem.self, forPrimaryKey: "identifier")

            object.gameDescription = game.gameDescription
            object.boxBackArtworkURL = game.boxBackArtworkURL
            object.developer = game.developer
            object.publisher = game.publisher
            object.publishDate = game.publishDate
            object.genres = game.genres // Is a comma seperated list or single entry
            object.referenceURL = game.referenceURL
            object.releaseID = game.releaseID
            object.regionName = game.regionName
            object.regionID = game.regionID
            object.systemShortName = game.systemShortName
            object.language = game.language
            object.file =  PVFile(withPartialPath: game.file.fileName, relativeRoot: .iCloud)
        }
    }
}

// Recently played game as a predicate
//extension PVGame {
//    public static func recentlyPlayed(days: Int) -> Predicate<PVGame> {
//        return Predicate(\.date, .greaterThanOrEqualTo, Date().addingTimeInterval(-TimeInterval(days) * 24 * 60 * 60))
//    }
//}
