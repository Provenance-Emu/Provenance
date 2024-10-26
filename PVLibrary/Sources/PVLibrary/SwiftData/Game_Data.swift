//
//  Game_Data.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData) && !os(tvOS)
import SwiftData

@Model
public class RecentGame_Data {
    public var game: Game_Data
    public var lastPlayedDate: Date = Date()
    public var core: Core_Data?
    
    init(game: Game_Data, lastPlayedDate: Date, core: Core_Data? = nil) {
        self.game = game
        self.lastPlayedDate = lastPlayedDate
        self.core = core
    }
}


@Model
public class Game_Data {
    @Attribute(.spotlight)
    public var title: String = ""
    
    @Attribute(.unique)
    public var id :String = NSUUID().uuidString
    
    // TODO: This is a 'partial path' meaing it's something like {system id}.filename
    // We should make this an absolute path but would need a Realm translater and modifying
    // any methods that use this path. Everything should use PVEmulatorConfigure path(forGame:)
    // and then we just need to change that method but I haven't check that every method uses that
    // The other option is to only use the filename and then path(forGame:) would determine the
    // fully qualified path, but if we add network / cloud storage that may or may not change that.
    public var romPath: String = ""
    public var file: File_Data!
    public private(set) var relatedFiles: [File_Data]

    public var customArtworkURL: String = ""
    public var originalArtworkURL: String = ""
    public var originalArtworkFile: ImageFile_Data?

    public var requiresSync: Bool = true
    public var isFavorite: Bool = false

    public var romSerial: String?
    public var romHeader: String?
    public private(set) var importDate: Date = Date()

    public var systemIdentifier: String = ""
    public var system: System_Data!

    @Attribute(.unique)
    public var md5Hash: String = ""
    @Attribute(.unique)
    public var crc: String = ""

    // If the user has set 'always use' for a specfic core
    // We don't use PVCore incase cores are removed / deleted
    public var userPreferredCoreID: String?

    /* Links to other objects */
    public private(set) var saveStates: [SaveState_Data]
    public private(set) var cheats: [Cheats_Data]
//    public private(set) var recentPlay: [RecentGame_Data]
    public private(set) var screenShots: [ImageFile_Data]

    public private(set) var libraries: [Library_Data]

    /* Tracking data */
    public var lastPlayed: Date?
    public var playCount: Int = 0
    public var timeSpentInGame: Int = 0
    public var rating: Int = -1 {
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
    @Attribute(.spotlight)
    public var gameDescription: String?
    public var boxBackArtworkURL: String?
    @Attribute(.spotlight)
    public var developer: String?
    @Attribute(.spotlight)
    public var publisher: String?
    public var publishDate: String?
    @Attribute(.spotlight)
    public var genres: String? // Is a comma seperated list or single entry
    public var referenceURL: String?
    public var releaseID: String?
    public var regionName: String?
    public var regionID: Int
    public var systemShortName: String?
    public var language: String?

//    public var validatedGame: Game_Data? { return self.isInvalidated ? nil : self }

    init(title: String, id: String, romPath: String, file: File_Data!, relatedFiles: [File_Data], customArtworkURL: String, originalArtworkURL: String, originalArtworkFile: ImageFile_Data? = nil, requiresSync: Bool, isFavorite: Bool, romSerial: String? = nil, romHeader: String? = nil, importDate: Date, systemIdentifier: String, system: System_Data!, md5Hash: String, crc: String, userPreferredCoreID: String? = nil, saveStates: [SaveState_Data], cheats: [Cheats_Data], screenShots: [ImageFile_Data], libraries: [Library_Data], lastPlayed: Date? = nil, playCount: Int, timeSpentInGame: Int, rating: Int, gameDescription: String? = nil, boxBackArtworkURL: String? = nil, developer: String? = nil, publisher: String? = nil, publishDate: String? = nil, genres: String? = nil, referenceURL: String? = nil, releaseID: String? = nil, regionName: String? = nil, regionID: Int, systemShortName: String? = nil, language: String? = nil) {
        self.title = title
        self.id = id
        self.romPath = romPath
        self.file = file
        self.relatedFiles = relatedFiles
        self.customArtworkURL = customArtworkURL
        self.originalArtworkURL = originalArtworkURL
        self.originalArtworkFile = originalArtworkFile
        self.requiresSync = requiresSync
        self.isFavorite = isFavorite
        self.romSerial = romSerial
        self.romHeader = romHeader
        self.importDate = importDate
        self.systemIdentifier = systemIdentifier
        self.system = system
        self.md5Hash = md5Hash
        self.crc = crc
        self.userPreferredCoreID = userPreferredCoreID
        self.saveStates = saveStates
        self.cheats = cheats
        self.screenShots = screenShots
        self.libraries = libraries
        self.lastPlayed = lastPlayed
        self.playCount = playCount
        self.timeSpentInGame = timeSpentInGame
        self.rating = rating
        self.gameDescription = gameDescription
        self.boxBackArtworkURL = boxBackArtworkURL
        self.developer = developer
        self.publisher = publisher
        self.publishDate = publishDate
        self.genres = genres
        self.referenceURL = referenceURL
        self.releaseID = releaseID
        self.regionName = regionName
        self.regionID = regionID
        self.systemShortName = systemShortName
        self.language = language
    }
}
#endif
