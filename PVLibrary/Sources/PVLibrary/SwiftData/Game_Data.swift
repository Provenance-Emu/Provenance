//
//  Game_Data.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

import SwiftData

@Model
public class Game_Data {
    public var title: String = ""

    @Attribute(.unique) public var id: String = UUID().uuidString

    // TODO: This is a 'partial path' meaning it's something like {system id}.filename
    // We should make this an absolute path but would need a migration and modifying
    // any methods that use this path. Everything should use PVEmulatorConfigure path(forGame:)
    // and then we just need to change that method but I haven't checked that every method uses that.
    // The other option is to only use the filename and then path(forGame:) would determine the
    // fully qualified path, but if we add network / cloud storage that may or may not change that.
    public var romPath: String = ""

    // One-to-one: primary ROM file (game owns the file record)
    @Relationship(deleteRule: .cascade)
    public var file: File_Data?

    // One-to-many: related ROM files (e.g. multi-disc)
    @Relationship(deleteRule: .cascade)
    public var relatedFiles: [File_Data] = []

    public var customArtworkURL: String = ""
    public var originalArtworkURL: String = ""

    // One-to-one: cached artwork image (game owns the image record)
    @Relationship(deleteRule: .cascade)
    public var originalArtworkFile: ImageFile_Data?

    public var requiresSync: Bool = true
    public var isFavorite: Bool = false

    public var romSerial: String?
    public var romHeader: String?
    public var importDate: Date = Date()

    public var systemIdentifier: String = ""

    // Many-to-one: the system this game belongs to (inverse of System_Data.games)
    public var system: System_Data?

    @Attribute(.unique) public var md5Hash: String
    public var crc: String = ""

    // If the user has set 'always use' for a specific core
    // We don't use Core_Data directly in case cores are removed / deleted
    public var userPreferredCoreID: String?

    // One-to-many: save states for this game (game owns its save states)
    @Relationship(deleteRule: .cascade, inverse: \SaveState_Data.game)
    public var saveStates: [SaveState_Data] = []

    // One-to-many: cheats for this game (game owns its cheats)
    @Relationship(deleteRule: .cascade, inverse: \Cheats_Data.game)
    public var cheats: [Cheats_Data] = []

    // One-to-many: screenshots (game owns its screenshots)
    @Relationship(deleteRule: .cascade)
    public var screenShots: [ImageFile_Data] = []

    // Many-to-many: libraries this game belongs to (inverse on Library_Data.games)
    public var libraries: [Library_Data] = []

    /* Tracking data */
    public var lastPlayed: Date?
    public var playCount: Int = 0
    public var timeSpentInGame: Int = 0

    // Rating: -1 means unrated; valid range is -1...5
    // Note: property observers removed for SwiftData compatibility
    public var rating: Int = -1

    /* Extra metadata from OpenVGDB */
    public var gameDescription: String?
    public var boxBackArtworkURL: String?
    public var developer: String?
    public var publisher: String?
    public var publishDate: String?
    public var genres: String? // Comma-separated list or single entry
    public var referenceURL: String?
    public var releaseID: String?
    public var regionName: String?
    public var regionID: Int?
    public var systemShortName: String?
    public var language: String?

    // MARK: - CloudKit Sync Fields

    /// CloudKit record ID once the ROM has been confirmed in the private database.
    /// Uses deterministic format "rom_<md5>" — see CloudKitSchema.RecordIDGenerator.
    public var cloudRecordID: String?

    /// Whether the ROM file is stored locally on this device.
    public var isDownloaded: Bool = true

    /// Whether CloudKit holds a verified CKAsset for this game's ROM file.
    public var hasCloudAssets: Bool = false

    /// Cached ROM file size in bytes (avoids stat(2) calls during sync batching).
    public var fileSize: Int = 0

    /// Date of the last successful CloudKit sync round-trip for this game.
    public var lastCloudSyncDate: Date?

    // MARK: - Computed helpers

    public var artworkURL: String {
        get {
            customArtworkURL.isEmpty ? originalArtworkURL : customArtworkURL
        }
        set {
            customArtworkURL = newValue
        }
    }

    public init(title: String = "", id: String = UUID().uuidString,
                romPath: String = "", file: File_Data? = nil,
                relatedFiles: [File_Data] = [], customArtworkURL: String = "",
                originalArtworkURL: String = "", originalArtworkFile: ImageFile_Data? = nil,
                requiresSync: Bool = true, isFavorite: Bool = false,
                romSerial: String? = nil, romHeader: String? = nil,
                importDate: Date = Date(), systemIdentifier: String = "",
                system: System_Data? = nil, md5Hash: String, crc: String = "",
                userPreferredCoreID: String? = nil, saveStates: [SaveState_Data] = [],
                cheats: [Cheats_Data] = [], screenShots: [ImageFile_Data] = [],
                libraries: [Library_Data] = [], lastPlayed: Date? = nil,
                playCount: Int = 0, timeSpentInGame: Int = 0, rating: Int = -1,
                gameDescription: String? = nil, boxBackArtworkURL: String? = nil,
                developer: String? = nil, publisher: String? = nil,
                publishDate: String? = nil, genres: String? = nil,
                referenceURL: String? = nil, releaseID: String? = nil,
                regionName: String? = nil, regionID: Int? = nil,
                systemShortName: String? = nil, language: String? = nil) {
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

public extension Game_Data {
    var genresArray: [String] {
        genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
}
