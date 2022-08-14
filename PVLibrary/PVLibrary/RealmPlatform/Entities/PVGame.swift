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

#if canImport(QuickLook)
import QuickLook
// MARK: - QLPreviewItem
extension PVGame: QLPreviewItem {
    public var previewItemURL: URL? {
        file.url
    }
}
import QuickLookThumbnailing
// MARK: - QuickLookThumbnailing
extension PVGame {
  func generateThumbnail(completion: @escaping (UIImage) -> Void) {
    // 1
    let size = CGSize(width: 128, height: 102)
    let scale = UIScreen.main.scale
      var url: URL?
      if !customArtworkURL.isEmpty {
          let oaurl = URL.init(fileURLWithPath: customArtworkURL)
          url = oaurl
      } else if !originalArtworkURL.isEmpty {
          let oaurl = URL.init(fileURLWithPath: originalArtworkURL)
          url = oaurl
      } else if let originalArtworkFile = originalArtworkFile?.url {
          let oaurl = originalArtworkFile
          url = oaurl
      }
      guard let url = url else {
          completion(UIImage())
          return
      }
      
    // 2
    let request = QLThumbnailGenerator.Request(
      fileAt: url,
      size: size,
      scale: scale,
      representationTypes: .all)
    
    // 3
    let generator = QLThumbnailGenerator.shared
    generator.generateBestRepresentation(for: request) { thumbnail, error in
      if let thumbnail = thumbnail {
        completion(thumbnail.uiImage)
      } else if let error = error {
        // Handle error
          ELOG("\(error.localizedDescription)")
      }
    }
  }
}

#endif

public final class PVGame: Object, Identifiable, PVLibraryEntry {
    @Persisted(indexed: true) public var title: String = ""
    @Persisted public var id = NSUUID().uuidString

    // TODO: This is a 'partial path' meaing it's something like {system id}.filename
    // We should make this an absolute path but would need a Realm translater and modifying
    // any methods that use this path. Everything should use PVEmulatorConfigure path(forGame:)
    // and then we just need to change that method but I haven't check that every method uses that
    // The other option is to only use the filename and then path(forGame:) would determine the
    // fully qualified path, but if we add network / cloud storage that may or may not change that.
    @Persisted public var romPath: String = ""
    @Persisted public var file: PVFile!
    public private(set) var relatedFiles = List<PVFile>()

    @Persisted public var customArtworkURL: String = ""
    @Persisted public var originalArtworkURL: String = ""
    @Persisted public var originalArtworkFile: PVImageFile?

    @Persisted public var requiresSync: Bool = true
    @Persisted(indexed: true) public var isFavorite: Bool = false

    @Persisted public var romSerial: String?
    @Persisted public var romHeader: String?
    @Persisted(indexed: true) public private(set) var importDate: Date = Date()

    @Persisted(indexed: true) public var systemIdentifier: String = ""
    @Persisted public var system: PVSystem!

    @Persisted(primaryKey: true) public var md5Hash: String = ""
    @Persisted(indexed: true) public var crc: String = ""

    // If the user has set 'always use' for a specfic core
    // We don't use PVCore incase cores are removed / deleted
    @Persisted public var userPreferredCoreID: String?

    /* Links to other objects */
    @Persisted public private(set) var saveStates = LinkingObjects<PVSaveState>(fromType: PVSaveState.self, property: "game")
    @Persisted public private(set) var cheats = LinkingObjects<PVCheats>(fromType: PVCheats.self, property: "game")
    @Persisted public private(set) var recentPlays = LinkingObjects(fromType: PVRecentGame.self, property: "game")
    @Persisted public private(set) var screenShots = List<PVImageFile>()

    @Persisted public private(set) var libraries = LinkingObjects<PVLibrary>(fromType: PVLibrary.self, property: "games")

    /* Tracking data */
    @Persisted(indexed: true) public var lastPlayed: Date?
    @Persisted(indexed: true) public var playCount: Int = 0
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

    /* Extra metadata from OpenBG */
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

    public convenience init(withFile file: PVFile, system: PVSystem) {
        self.init()
        self.file = file
        self.system = system
        systemIdentifier = system.identifier
    }

    public var validatedGame: PVGame? {
        return self.isInvalidated ? nil : self
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
        regionID = game.regionID
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
            object.regionID = regionID
            object.systemShortName = systemShortName
            object.language = language
        }
    }
}
