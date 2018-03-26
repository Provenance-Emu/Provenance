//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVGameImporter.swift
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import CoreSpotlight

extension URLSession {
    func synchronousDataTask(urlrequest: URLRequest) throws -> (data: Data?, response: HTTPURLResponse?) {
        var data: Data?
        var response: HTTPURLResponse?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        let dataTask = self.dataTask(with: urlrequest) {
            data = $0
            response = $1 as! HTTPURLResponse?
            error = $2

            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)

        if let error = error {
            throw error
        }

        return (data, response)
    }
}

struct ImportCanidateFile {
    var filePath: URL
    var md5: String? {
        if let cached = cache.md5 {
            return cached
        } else {
            let computed = FileManager.default.md5ForFile(atPath: filePath.path, fromOffset: 0)
            cache.md5 = computed
            return computed
        }
    }

    init(filePath: URL) {
        self.filePath = filePath
    }

    // Store a cache in a nested class.
    // The struct only contains a reference to the class, not the class itself,
    // so the struct cannot prevent the class from mutating.
    private class Cache {
        var md5: String?
    }
    private var cache = Cache()
}

public typealias PVGameImporterImportStartedHandler = (_ path: String) -> Void
public typealias PVGameImporterCompletionHandler = (_ encounteredConflicts: Bool) -> Void
public typealias PVGameImporterFinishedImportingGameHandler = (_ md5Hash: String, _ modified: Bool) -> Void
public typealias PVGameImporterFinishedGettingArtworkHandler = (_ artworkURL: String) -> Void

public class PVGameImporter {

    public var importStartedHandler: PVGameImporterImportStartedHandler?
    public var completionHandler: PVGameImporterCompletionHandler?
    public var finishedImportHandler: PVGameImporterFinishedImportingGameHandler?
    public var finishedArtworkHandler: PVGameImporterFinishedGettingArtworkHandler?
    public private(set) var encounteredConflicts = false

    public private(set) var serialImportQueue: DispatchQueue = DispatchQueue(label: "com.jamsoftonline.provenance.serialImportQueue")
    public private(set) var systemToPathMap = [String: URL]()
    public private(set) var romExtensionToSystemsMap = [String: [String]]()

    // MARK: - Paths
    let documentsPath: URL = PVEmulatorConfiguration.documentsPath
    let romsImportPath: URL = PVEmulatorConfiguration.romsImportPath
    let conflictPath: URL = PVEmulatorConfiguration.documentsPath.appendingPathComponent("Conflicts", isDirectory: true)

    func path(forSystemID systemID: String) -> URL? {
        return systemToPathMap[systemID]
    }

    func systemIDsForRom(at path: URL) -> [String]? {
        let fileExtension: String = path.pathExtension.lowercased()
        return romExtensionToSystemsMap[fileExtension]
    }

    internal func isCDROM(_ romFile: ImportCanidateFile) -> Bool {
        let cdExtensions = PVEmulatorConfiguration.supportedCDFileExtensions
        let ext = romFile.filePath.pathExtension

        return cdExtensions.contains(ext)
    }

    lazy var openVGDB: OESQLiteDatabase = {
        let _openVGDB = try! OESQLiteDatabase(url: Bundle.main.url(forResource: "openvgdb", withExtension: "sqlite")!)
        return _openVGDB
    }()

    public var conflictedFiles: [URL]? {
        return try? FileManager.default.contentsOfDirectory(at: conflictPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
    }

    var notificationToken: NotificationToken?

    required public init(completionHandler: PVGameImporterCompletionHandler?) {

        self.completionHandler = completionHandler

        let systems = PVSystem.all

        // Observe Results Notifications
        notificationToken = systems.observe { [unowned self] (changes: RealmCollectionChange) in
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                self.systemToPathMap = self.updateSystemToPathMap()
                self.romExtensionToSystemsMap = self.updateromExtensionToSystemsMap()
            case .update:
                self.systemToPathMap = self.updateSystemToPathMap()
                self.romExtensionToSystemsMap = self.updateromExtensionToSystemsMap()
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }
    }

    deinit {
        notificationToken?.invalidate()
    }

    @objc
    func calculateMD5(forGame game: PVGame ) -> String? {
        var offset: UInt = 0
        if game.system.enumValue == .SNES {
            offset = 16
        }

        let romPath = documentsPath.appendingPathComponent(game.romPath, isDirectory: false)
        let fm = FileManager.default
        if !fm.fileExists(atPath: romPath.path) {
            ELOG("Cannot find file at path: \(romPath)")
            return nil
        }

        return fm.md5ForFile(atPath: romPath.path, fromOffset: offset)
    }

    func importFiles(atPaths paths: [URL]) -> [URL] {

        let sortedPaths = PVEmulatorConfiguration.sortImportUURLs(urls: paths)

        // Make ImportCanidateFile structs to hold temporary metadata for import and matching
        // This is just the path and a lazy loaded md5
        let canidateFiles = sortedPaths.map { (path) -> ImportCanidateFile in
            return ImportCanidateFile(filePath: path)
        }

        // do CDs first to avoid the case where an item related to CDs is mistaken as another rom and moved
        // before processing its CD cue sheet or something
        let updatedCanidateFiles = canidateFiles.flatMap { canidate -> ImportCanidateFile? in
            if FileManager.default.fileExists(atPath: canidate.filePath.path) {
                if isCDROM(canidate), let movedToPaths = moveCDROM(toAppropriateSubfolder: canidate) {

                    // Found a CD, can add moved files now to newPaths
                    let pathsString = {return movedToPaths.map { $0.path }.joined(separator: ", ") }
                    VLOG("Found a CD. Moved files to the following paths \(pathsString())")

                    // Return nil since we don't need the ImportCanidateFile anymore
                    // Files are already moved and imported to database (in theory),
                    // or moved to conflicts dir and already set the conflists flag - jm
                    return nil
                } else if PVEmulatorConfiguration.artworkExtensions.contains(canidate.filePath.pathExtension.lowercased()), let game = PVGameImporter.importArtwork(fromPath: canidate.filePath) {
                    // Is artwork, import that
                    ILOG("Found artwork \(canidate.filePath.lastPathComponent) for game <\(game.title)>")
                    return nil
                } else {
                    return canidate
                }
            } else {
                if canidate.filePath.pathExtension != "bin" {
                    WLOG("File should have existed at \(canidate.filePath) but it might have been moved")
                }
                return nil
            }
        }

        // Add new paths from remaining canidate files
        // CD files that matched a system will be remove already at this point
        let newPaths = updatedCanidateFiles.flatMap { canidate -> URL? in
            if FileManager.default.fileExists(atPath: canidate.filePath.path) {
                if let newPath = moveROM(toAppropriateSubfolder: canidate) {
                    return newPath
                }
            }
            return nil
        }

        return newPaths
    }

    func startImport(forPaths paths: [URL]) {
        serialImportQueue.async(execute: {() -> Void in
            let newPaths = self.importFiles(atPaths: paths)
            self.getRomInfoForFiles(atPaths: newPaths, userChosenSystem: nil)
            if self.completionHandler != nil {
                DispatchQueue.main.sync(execute: {() -> Void in
                    self.completionHandler?(self.encounteredConflicts)
                })
            }
        })
    }

    func resolveConflicts(withSolutions solutions: [URL: PVSystem]) {

        solutions.forEach { (filePath, system) in
            let subfolder = system.romsDirectory

            if !FileManager.default.fileExists(atPath: subfolder.path) {
                try? FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true, attributes: nil)
            }

            let sourceFilename: String = filePath.lastPathComponent
            let sourcePath: URL = filePath
            let destinationPath: URL = subfolder.appendingPathComponent(sourceFilename, isDirectory: false)

            do {
                try FileManager.default.moveItem(at: sourcePath, to: destinationPath)
                DLOG("Moved \(sourcePath.path) to \(destinationPath.path)")
            } catch {
                ELOG("Unable to move \(sourcePath.path) to \(destinationPath.path) because: \(error.localizedDescription)")
            }

                // moved the .cue, now move .bins .imgs etc
            let relatedFileName: String = sourcePath.deletingPathExtension().lastPathComponent

            let conflictsDirContents = try? FileManager.default.contentsOfDirectory(at: conflictPath, includingPropertiesForKeys: nil, options: [])
            conflictsDirContents?.forEach { file in

                    // Crop out any extra info in the .bin files, like Game.cue and Game (Track 1).bin, we want to match up to just 'Game'
                var fileWithoutExtension: String = file.deletingPathExtension().lastPathComponent
                if fileWithoutExtension.count > relatedFileName.count {
                    // Trim the matching filename to same lentgh as possible relation string
                    fileWithoutExtension = String(fileWithoutExtension[..<relatedFileName.endIndex])
                }

                // TODO: This doesn't take into account things with (Disc) need to remove those using regex, I think. unless we d
                // Compare the trimmed string is the same as our match looking string
                if fileWithoutExtension == relatedFileName {

                        // Before moving the file, make sure the if it's a cue sheet, that the cue sheet's reference uses the same case.
                    let isCueSheet = destinationPath.pathExtension == "cue"
                    if isCueSheet {
                        let cueSheetPath = destinationPath
                        if var cuesheetContents = try? String(contentsOf: cueSheetPath, encoding: .utf8) {
                            let range = (cuesheetContents as NSString).range(of: file.lastPathComponent, options: .caseInsensitive)

                            if range.location != NSNotFound {
                                if let subRange = Range<String.Index>(range, in: cuesheetContents) {
                                    cuesheetContents.replaceSubrange(subRange, with: file.lastPathComponent)
                                }

                                do {
                                    try cuesheetContents.write(to: cueSheetPath, atomically: true, encoding: .utf8)
                                } catch {
                                    ELOG("Unable to rewrite cuesheet \(destinationPath.path) because \(error.localizedDescription)")
                                }
                            } else {
                                DLOG("Range of string <\(file)> not found in file <\(cueSheetPath.lastPathComponent)>")
                            }
                        }
                    }

                    do {
                        let newDestinationPath = subfolder.appendingPathComponent(file.lastPathComponent, isDirectory: false)
                        try FileManager.default.moveItem(at: file, to: newDestinationPath)
                    } catch {
                        ELOG("Unable to move related file from \(filePath.path) to \(subfolder.path) because: \(error.localizedDescription)")
                    }
                }
            }

            let systemRef = ThreadSafeReference(to: system)

            serialImportQueue.async(execute: {[unowned self] () -> Void in
                let realm = try! Realm()
                guard let system = realm.resolve(systemRef) else {
                    return // person was deleted
                }
                self.getRomInfoForFiles(atPaths: [destinationPath], userChosenSystem: system)

                // TODO: Shouldn't this only be colled after all conflicts have been resolved?
                if self.completionHandler != nil {
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.completionHandler?(false)
                    })
                }
            })
        } // End forEach
    }
}

public extension PVGameImporter {
    func updateSystemToPathMap() -> [String: URL] {
        let map = PVSystem.all.reduce([String: URL]()) { (dict, system) -> [String: URL] in
            var dict = dict
            dict[system.identifier] = system.romsDirectory
            return dict
        }

        return map
    }

    func updateromExtensionToSystemsMap() -> [String: [String]] {
        return PVSystem.all.reduce([String:[String]](), { (dict, system) -> [String: [String]] in
            let extensionsForSystem = system.supportedExtensions
            // Make a new dict of [ext : systemID] for each ext in extions for that ID, then merge that dictionary with the current one,
            // if the dictionary already has that key, the arrays are joined so you end up with a ext mapping to multpiple systemIDs
            let extsToCurrentSystemID = extensionsForSystem.reduce([String:[String]](), { (dict, ext) -> [String: [String]] in
                var dict = dict
                dict[ext] = [system.identifier]
                return dict
            })

            return dict.merging( extsToCurrentSystemID, uniquingKeysWith: {  var newArray = $0; newArray.append(contentsOf: $1); return newArray;  })

        })
    }
}

public extension PVGameImporter {

    /**
     Import a specifically named image file to the matching game.
     
     To update “Kart Fighter.nes”, use an image named “Kart Fighter.nes.png”.
     
     @param imageFullPath The artwork image path
     @return The game that was updated
     */
    class func importArtwork(fromPath imageFullPath: URL) -> PVGame? {

        // Check the file exists (and is not a directory for some reason)
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: imageFullPath.path, isDirectory: &isDirectory)
        if !fileExists || isDirectory.boolValue {
            WLOG("File doesn't exist or is directory at \(imageFullPath)")
            return nil
        }

        var success = false

        // Make sure we always delete the image even on early error returns
        defer {
            if success {
                do {
                    try FileManager.default.removeItem(at: imageFullPath)
                } catch {
                    ELOG("Failed to delete image at path \(imageFullPath) \n \(error.localizedDescription)")
                }
            }
        }

        // Trim the extension off the filename
        let gameFilename: String = imageFullPath.deletingPathExtension().lastPathComponent

        // The game extension since images needs to be foo.nes.png
        let gameExtension = imageFullPath.deletingPathExtension().pathExtension

        let database = RomDatabase.sharedInstance

        if gameExtension.isEmpty {
            ILOG("Trying to import artwork that didn't contain the extension of the system")
            // This is the case where the user didn't put the gamename.nes.jpg,
            // but just gamename.jpg
            let games = database.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [gameFilename]))

            if games.count == 1, let game = games.first {
                ILOG("File for image didn't have extension for system but we found a single match for image \(imageFullPath.lastPathComponent) to game \(game.title) on system \(game.systemIdentifier)")
                guard let hash = scaleAndMoveImageToCache(imageFullPath: imageFullPath) else {
                    return nil
                }

                do {
                    try database.writeTransaction {
                        game.customArtworkURL = hash
                    }
                    success = true
                    ILOG("Set custom artwork of game \(game.title) from file \(imageFullPath.lastPathComponent)")
                } catch {
                    ELOG("Couldn't update game \(game.title) with new artwork URL \(hash)")
                }

                return game
            } else {
                VLOG("Database search returned \(games.count) results")
            }
        }

        guard let systems: [PVSystem] = PVEmulatorConfiguration.systems(forFileExtension: gameExtension), !systems.isEmpty else {
            ELOG("No system for extension \(gameExtension)")
            return nil
        }

        let cdBasedSystems = PVEmulatorConfiguration.cdBasedSystems
        let couldBelongToCDSystem = !Set(cdBasedSystems).isDisjoint(with: Set(systems))

        // Skip CD systems for non special extensions
        if (couldBelongToCDSystem && PVEmulatorConfiguration.supportedCDFileExtensions.contains(gameExtension.lowercased())) || systems.count > 1 {
            // We could get here with Sega games. They use .bin, which is CD extension.
            // See if we can match any of the potential paths to a current game
            // See if we have any current games that could match based on searching for any, [systemIDs]/filename
            guard let existingGames = findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(systems, romFilename: gameFilename) else {
                ELOG("System for extension \(gameExtension) is a CD system and {\(gameExtension)} not the right matching file type of cue or m3u")
                return nil
            }
            if existingGames.count == 1, let onlyMatch = existingGames.first {
                ILOG("We found a hit for artwork that could have been belonging to multiple games and only found one file that matched by systemid/filename. The winner is \(onlyMatch.title) for \(onlyMatch.systemIdentifier)")

                guard let hash = scaleAndMoveImageToCache(imageFullPath: imageFullPath) else {
                    ELOG("Couldn't move image, fail to set custom artowrk")
                    return nil
                }

                do {
                    try database.writeTransaction {
                        onlyMatch.customArtworkURL = hash
                    }
                    success = true
                } catch {
                    ELOG("Couldn't update game \(onlyMatch.title) with new artwork URL")
                }
                return onlyMatch
            } else {
                ELOG(
                    """
                    We got to the unlikely scenario where an extension is possibly a CD binary file, \
                    or belongs to a system, and had multiple games that matmched the filename under more than one core.
                    Since there's no sane way to determine which game it belonds to, we must quit here. Sorry.
                    """)
                return nil
            }
        }

        // We already verified that above that there's 1 and only 1 system ID that matmched so force first!
        let system = systems.first!

        // TODO: This will break if we move the ROMS to a new spot
        let gamePartialPath: String = URL(fileURLWithPath: system.identifier, isDirectory: true).appendingPathComponent(gameFilename).path
        if gamePartialPath.isEmpty {
            ELOG("Game path was empty")
            return nil
        }

        // Find the game in the database
        guard let game = database.all(PVGame.self, where: #keyPath(PVGame.romPath), value: gamePartialPath).first else {
            ELOG("Couldn't find game for path \(gamePartialPath)")
            return nil
        }

        guard let hash = scaleAndMoveImageToCache(imageFullPath: imageFullPath) else {
            return nil
        }

        do {
            try database.writeTransaction {
                game.customArtworkURL = hash
            }
            success = true
        } catch {
            ELOG("Couldn't update game with new artwork URL")
        }

        return game
    }

    fileprivate class func scaleAndMoveImageToCache(imageFullPath: URL) -> String? {
        // Read the data
        let coverArtFullData: Data
        do {
            coverArtFullData = try Data.init(contentsOf: imageFullPath, options: [])
        } catch {
            ELOG("Couldn't read data from image file \(imageFullPath.path)\n\(error.localizedDescription)")
            return nil
        }

        // Create a UIImage from the Data
        guard let coverArtFullImage = UIImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }

        // Scale the UIImage to our desired max size
        guard let coverArtScaledImage = coverArtFullImage.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)) else {
            ELOG("Failed to create scale image")
            return nil
        }

        // Create new Data from scaled image
        guard let coverArtScaledData = UIImagePNGRepresentation(coverArtScaledImage) else {
            ELOG("Failed to create data respresentation of scaled image")
            return nil
        }

        // Hash the image and save to cache
        let hash: String = (coverArtScaledData as NSData).md5Hash

        do {
            let destinationURL = try PVMediaCache.writeData(toDisk: coverArtScaledData, withKey: hash)
            VLOG("Scaled and moved image from \(imageFullPath.path) to \(destinationURL.path)")
        } catch {
            ELOG("Failed to save artwork to cache: \(error.localizedDescription)")
            return nil
        }

        return hash
    }

    fileprivate class func findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(_ systems: [PVSystem], romFilename: String) -> [PVGame]? {
        // Check if existing ROM

        let database = RomDatabase.sharedInstance

        let predicate =  NSPredicate(format: "romPath CONTAINS[c] %@", PVEmulatorConfiguration.stripDiscNames(fromFilename: romFilename))
        let allGames = database.all(PVGame.self, filter: predicate)
        let filteredGames = allGames.filter { return systems.contains($0.system) }
        return filteredGames.isEmpty ? nil : Array(filteredGames)
    }

    func getRomInfoForFiles(atPaths paths: [URL], userChosenSystem chosenSystem: PVSystem? = nil) {
        let database = RomDatabase.sharedInstance
        database.refresh()

        paths.forEach { (path) in

            let isDirectory: Bool
            if #available(iOS 9.0, *) {
                isDirectory = path.hasDirectoryPath
            } else {
                isDirectory = (try? path.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            }
            if path.lastPathComponent.hasPrefix(".") || isDirectory {
                VLOG("Skipping file with . as first character or it's a directory")
                return
            }
            autoreleasepool {
                var systemsMaybe: [PVSystem]? = nil

                let urlPath = path
                let filename = urlPath.lastPathComponent
                let fileExtensionLower = urlPath.pathExtension.lowercased()

                if let chosenSystem = chosenSystem {
                    // First check if it's a chosen system that supports CDs and this is a non-cd extension
                    if chosenSystem.usesCDs && !chosenSystem.supportedExtensions.contains(fileExtensionLower) {
                        // We're on a file that is from a CD based system but this file isn't an importable file type so skip it.
                        // This prevents us from importing .bin's for example when the .cue is already imported
                        DLOG("Skipping file <\(filename)> with extension <\(fileExtensionLower)> because not a CD for <\(chosenSystem.shortName)>")
                        return
                    }

                    systemsMaybe = [chosenSystem]
                } else {
                    systemsMaybe = PVEmulatorConfiguration.systems(forFileExtension: fileExtensionLower)
                }

                // No system found to match this file
                guard var systems = systemsMaybe else {
                    ELOG("No system matched extension {\(fileExtensionLower)}")
                    return
                }

                var maybeGame: PVGame? = nil

                if systems.count > 1 {

                    // Try to match by MD5 first
                    if let systemIDMatch = systemId(forROMCanidate: ImportCanidateFile(filePath: urlPath)), let system = database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: systemIDMatch) {
                        systems = [system]
                        DLOG("Matched \(urlPath.path) by MD5 to system \(systemIDMatch)")
                    } else {
                        // We have a conflict, multiple systems matched and couldn't find anything by MD5 match
                        let s =  systems.map({return $0.identifier}).joined(separator: ",")
                        WLOG("\(filename) matched with multiple systems (or none?): \(s). Going to do my best to figure out where it belons")

                        // NOT WHAT WHAT TO DO HERE. -jm
                        // IS IT TOO LATE TO MOVE TO CONFLICTS DIR?

                        guard let existingGames = PVGameImporter.findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(systems, romFilename: filename) else {
                            // NO matches to existing games, I suppose we move to conflicts dir
                            self.encounteredConflicts = true
                            do {
                                try FileManager.default.moveItem(at: path, to: conflictPath)
                                ILOG("It's a new game, so we moved \(filename) to conflicts dir")
                            } catch {
                                ELOG("Failed to move \(urlPath.path) to conflicts dir")
                            }
                            // Worked or failed, we're done with this file
                            return
                        }

                        if existingGames.count == 1 {
                            // Just one existing game, use that.
                            maybeGame = existingGames.first!
                        } else {
                            // We matched multiple possible systems, and multiple possible existing games
                            // This is a quagmire scenario, I guess also move to conflicts dir...
                            self.encounteredConflicts = true
                            do {
                                try FileManager.default.moveItem(at: path, to: conflictPath)
                                let matchedSystems = systems.map {return $0.identifier}.joined(separator: ", ")
                                let matchedGames = existingGames.map { $0.romPath }.joined(separator: ", ")
                                WLOG("Scanned game matched with multiple systems {\(matchedSystems)} and multiple existing games \({matchedGames}) so we moved \(filename) to conflicts dir. You figure it out!")
                            } catch {
                                ELOG("Failed to move \(urlPath.path) to conflicts dir.")
                            }
                            return
                        }
                    }
                }

                // Should only if we're here, save to !
                let system = systems.first!

                let partialPath: String = (system.identifier as NSString).appendingPathComponent(filename)

                // Check if we have this game already
                // TODO: We shoulld use the input paths array to make a query that matches any of those paths
                // and then we can use a Set with .contains instead of doing a new query here every times
                // Would instead see if contains first, then query for the full object
                // If we have a matching game from a multi-match above, use that, or run a query by path and see if there's a match there

                    // For multi-cd games, make the most inert version of the filename
                var similiarName = path.deletingPathExtension().lastPathComponent
                similiarName = PVEmulatorConfiguration.stripDiscNames(fromFilename: similiarName)

                if let existingGame = maybeGame ?? // found a match above?
                    database.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [partialPath])).first ?? // Exact filename match
                    database.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [similiarName])).first // More generic match
                {
                    // TODO: Check the MD5 mash. If it doesn't match, delete the imported game and re-import
                    // Can't update existig game since MD5 is the primary DB key and you can't update it.
                    // Downside would be that you have to then check the MD5 for every file and that would take forver
                    // perhaps we should add more info to the PVGame entry for the file modified date and compare that instead,
                    // then check md5 only if the date differs. - Joe M
                    finishUpdateOrImport(ofGame: existingGame)
                } else {
                    // New game
                    importToDatabaseROM(atPath: path, system: system)
                }
            } // autorelease pool
        } // for each
    }

    // MARK: - ROM Lookup

    public func lookupInfo(for game: PVGame) {
        let database = RomDatabase.sharedInstance
        database.refresh()
        if game.md5Hash.isEmpty {
            let offset: UInt
            switch game.system.enumValue {
            case .NES:
                offset = 16
            default:
                offset = 0
            }

            let romFullPath = PVEmulatorConfiguration.documentsPath.appendingPathComponent(game.romPath).path

            if let md5Hash = FileManager.default.md5ForFile(atPath: romFullPath, fromOffset: offset) {
                try? database.writeTransaction {
                    game.md5Hash = md5Hash
                }
            }
        }

        guard !game.md5Hash.isEmpty else {
            ELOG("Game md5 has was empty")
            return
        }

        var resultsMaybe: [[String: Any]]? = nil
        do {
            resultsMaybe = try self.searchDatabase(usingKey: "romHashMD5", value: game.md5Hash.uppercased(), systemID: game.systemIdentifier)
        } catch {
            ELOG("\(error.localizedDescription)")
        }

        if resultsMaybe == nil || resultsMaybe!.isEmpty {
            let fileName: String = URL(fileURLWithPath: game.romPath, isDirectory: true).lastPathComponent
            // Remove any extraneous stuff in the rom name such as (U), (J), [T+Eng] etc

            let nonCharRange: NSRange = (fileName as NSString).rangeOfCharacter(from: PVGameImporter.charset)
            var gameTitleLen: Int
            if nonCharRange.length > 0 && nonCharRange.location > 1 {
                gameTitleLen = nonCharRange.location - 1
            } else {
                gameTitleLen = fileName.count
            }
            let subfileName = String(fileName.prefix(gameTitleLen))
            do {
                resultsMaybe = try self.searchDatabase(usingKey: "romFileName", value: subfileName, systemID: game.systemIdentifier)
            } catch {
                ELOG("\(error.localizedDescription)")
            }
        }

        guard let results = resultsMaybe, !results.isEmpty else {
            DLOG("Unable to find ROM \(game.romPath) in DB")
            try? database.writeTransaction {
                game.requiresSync = false
            }
            return
        }

        var chosenResultMaybse: [AnyHashable: Any]? = nil
        for result: [AnyHashable: Any] in results {
            if let region = result["region"] as? String, region == "USA" {
                chosenResultMaybse = result
                break
            }
        }

        if chosenResultMaybse == nil {
            chosenResultMaybse = results.first
        }

        guard let chosenResult = chosenResultMaybse else {
            DLOG("Unable to find ROM \(game.romPath) in DB")
            return
        }

        do {
            try database.writeTransaction {
                game.requiresSync = false

                /* Optional results
                     gameTitle
                     boxImageURL
                     region
                     gameDescription
                     boxBackURL
                     developer
                     publisher
                     year
                     genres [comma array string]
                     referenceURL
                     releaseID
                     systemShortName
                     serial
                 */

                if let title = chosenResult["gameTitle"] as? String, !title.isEmpty {
                    // Remove just (Disc 1) from the title. Discs with other numbers will retain their names
                    let revisedTitle = title.replacingOccurrences(of: "\\ \\(Disc 1\\)", with: "", options: .regularExpression)

                    game.title = revisedTitle
                }

                if let boxImageURL = chosenResult["boxImageURL"] as? String, !boxImageURL.isEmpty {
                    game.originalArtworkURL = boxImageURL
                }

                if let regionName = chosenResult["region"] as? String, !regionName.isEmpty {
                    game.regionName = regionName
                }

                if let gameDescription = chosenResult["gameDescription"] as? String, !gameDescription.isEmpty {
                    game.gameDescription = gameDescription
                }

                if let boxBackURL = chosenResult["boxBackURL"] as? String, !boxBackURL.isEmpty {
                    game.boxBackArtworkURL = boxBackURL
                }

                if let developer = chosenResult["developer"] as? String, !developer.isEmpty {
                    game.developer = developer
                }

                if let publisher = chosenResult["publisher"] as? String, !publisher.isEmpty {
                    game.publisher = publisher
                }

                if let genres = chosenResult["genres"] as? String, !genres.isEmpty {
                    game.genres = genres
                }

                if let releaseDate = chosenResult["releaseDate"] as? String, !releaseDate.isEmpty {
                    game.publishDate = releaseDate
                }

                if let referenceURL = chosenResult["referenceURL"] as? String, !referenceURL.isEmpty {
                    game.referenceURL = referenceURL
                }

                if let releaseID = chosenResult["releaseID"] as? String, !releaseID.isEmpty {
                    game.releaseID = releaseID
                }

                if let systemShortName = chosenResult["systemShortName"] as? String, !systemShortName.isEmpty {
                    game.systemShortName = systemShortName
                }

                if let romSerial = chosenResult["serial"] as? String, !romSerial.isEmpty {
                    game.romSerial = romSerial
                }
            }
        } catch {
            ELOG("Failed to update game \(game.title) : \(error.localizedDescription)")
        }
     }

    public func searchDatabase(usingKey key: String, value: String, systemID: String) throws -> [[String: NSObject]]? {
        var results: [Any]? = nil
        let exactQuery = "SELECT DISTINCT releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', TEMPRomRegion as 'region', releaseDescription as 'gameDescription', releaseCoverBack as 'boxBackURL', releaseDeveloper as 'developer', releasePublisher as 'publiser', romSerial as 'serial', releaseDate as 'releaseDate', releaseGenre as 'genres', releaseReferenceURL as 'referenceURL', releaseID as 'releaseID', TEMPsystemShortName as 'systemShortName' FROM ROMs rom LEFT JOIN RELEASES release USING (romID) WHERE %@ = '%@'"
        let likeQuery = "SELECT DISTINCT romFileName, releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', TEMPRomRegion as 'region', releaseDescription as 'gameDescription', releaseCoverBack as 'boxBackURL', releaseDeveloper as 'developer', releasePublisher as 'publiser', romSerial as 'serial', releaseDate as 'releaseDate', releaseGenre as 'genres', releaseReferenceURL as 'referenceURL', releaseID as 'releaseID', systemShortName FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE %@ LIKE \"%%%@%%\" AND systemID=\"%@\" ORDER BY case when %@ LIKE \"%@%%\" then 1 else 0 end DESC"

        let dbSystemID: String = String(PVEmulatorConfiguration.databaseID(forSystemID: systemID)!)

        let queryString: String
        if key == "romFileName" {
            queryString = String(format: likeQuery, key, value, dbSystemID, key, value)
        } else {
            queryString = String(format: exactQuery, key, value)
        }

        do {
            results = try openVGDB.executeQuery(queryString)
        } catch {
            ELOG("Failed to execute query: \(error.localizedDescription)")
            throw error
        }

        return results as? [[String: NSObject]]
    }

    static var charset: CharacterSet = {
        var c = CharacterSet.punctuationCharacters
        c.remove(charactersIn: ",-+&.'")
        return c
    }()
}

// MARK: - Movers
extension PVGameImporter {
    /**
        Looks at a canidate file (should be a cue). Tries to find .bin files that match the filename by pattern
        matching the filename up to the .cue to other files in the same directory.
     
     - paramater canidateFile: ImportCanidateFile of the .cue file for the CD based rom
     
     - returns: Returns the paths of the .bins and .cue in the new directory they were moved to. Should be a system diretory. Returns nil if a match wasn't found or an error in the process
     */
    func moveCDROM(toAppropriateSubfolder canidateFile: ImportCanidateFile) -> [URL]? {

        guard let systemsForExtension = systemIDsForRom(at: canidateFile.filePath) else {
            WLOG("No sytem found for import canidate file \(canidateFile.filePath.lastPathComponent)")
            return nil
        }

        var subfolderPathMaybe: URL? = nil

        var matchedSystemID: String?

        if systemsForExtension.count > 1 {
            // Try to match by MD5 or filename
            if let systemID = self.systemId(forROMCanidate: canidateFile) {
                subfolderPathMaybe = systemToPathMap[systemID]
                matchedSystemID = systemID
            } else {
                ILOG("No MD5 match.")
                // No MD5 match, so move to conflict dir
                subfolderPathMaybe = self.conflictPath
                self.encounteredConflicts = true
            }
        } else {
            if let onlySystemID = systemsForExtension.first {
                subfolderPathMaybe = systemToPathMap[onlySystemID]
                matchedSystemID = onlySystemID
            }
        }

        guard let subfolderPath = subfolderPathMaybe else {
            DLOG("subfolderPathMaybe is nil")
            return nil
        }

        // Create the subfulder path if need be
        do {
            try FileManager.default.createDirectory(at: subfolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Unable to create \(subfolderPath) - \(error.localizedDescription)")
            return nil
        }

        let newDirectory = subfolderPath
        let newCueSheetPath = newDirectory.appendingPathComponent(canidateFile.filePath.lastPathComponent)

        // Try to move the CD file
        do {
            try FileManager.default.moveItem(at: canidateFile.filePath, to: newCueSheetPath)
            ILOG("Moving item \(canidateFile.filePath.path) to \(newCueSheetPath.path)")
        } catch {
            ELOG("Unable move CD file to create \(canidateFile.filePath) - \(error.localizedDescription)")
            return nil
        }

        // Move the cue sheet
        if !encounteredConflicts, let systemID = matchedSystemID, let system = PVSystem.with(primaryKey: systemID) {
            // Import to DataBase
            importToDatabaseROM(atPath: newCueSheetPath, system: system)
        } // else there was a conflict, nothing to import

        // moved the .cue, now move .bins .imgs etc to the destination dir (conflicts or system dir, decided above)
        if var paths = moveFiles(similiarToFile: canidateFile.filePath, toDirectory: newDirectory, cuesheet: newCueSheetPath) {
            paths.append(newCueSheetPath)
            return paths
        } else {
            return nil
        }
    }

    // TODO: Mabye this should throw
    @discardableResult
    private func importToDatabaseROM(atPath path: URL, system: PVSystem) -> PVGame? {
        let database = RomDatabase.sharedInstance

        let filename = path.lastPathComponent
        let title: String = PVEmulatorConfiguration.stripDiscNames(fromFilename: path.deletingPathExtension().lastPathComponent)
        let partialPath: String = (system.identifier as NSString).appendingPathComponent(filename)

        let file = PVFile(withURL: path)

        let game = PVGame(withFile: file, system: system)
        game.romPath = partialPath
        game.title = title
        game.requiresSync = true

        guard let md5 = calculateMD5(forGame: game) else {
            ELOG("Couldn't calculate MD5 for game \(partialPath)")
            return nil
        }

        game.md5Hash = md5

        do {
            try database.add(game, update: true)
        } catch {
            ELOG("Couldn't add new game \(title): \(error.localizedDescription)")
            return nil
        }

        finishUpdateOrImport(ofGame: game)
        return game
    }

    private func finishUpdateOrImport(ofGame game: PVGame) {
        var modified = false

        if game.requiresSync {
            if self.importStartedHandler != nil {
                let fullpath = PVEmulatorConfiguration.path(forGame: game)
                DispatchQueue.main.async(execute: {() -> Void in
                    self.importStartedHandler?(fullpath.path)
                })
            }
            lookupInfo(for: game)
            modified = true
        }

        if self.finishedImportHandler != nil {
            let md5: String = game.md5Hash
            DispatchQueue.main.async(execute: {() -> Void in
                self.finishedImportHandler?(md5, modified)
            })
        }
        getArtwork(forGame: game)
    }

    func biosEntryMatcing(canidateFile: ImportCanidateFile) -> PVBIOS? {
        // Check if BIOS by filename - should possibly just only check MD5?
        if let bios = PVEmulatorConfiguration.biosEntry(forFilename: canidateFile.filePath.lastPathComponent) {
            return bios
        } else {
            // Now check by MD5 - md5 is a lazy load var
            if let fileMD5 = canidateFile.md5, let bios = PVEmulatorConfiguration.biosEntry(forMD5: fileMD5) {
                return bios
            }
        }

        return nil
    }

    func getArtwork(forGame game: PVGame) {
        let url = game.originalArtworkURL
        if url.isEmpty || PVMediaCache.fileExists(forKey: url) {
            return
        }

        DLOG("Starting Artwork download for \(url)")

        guard let artworkURL = URL(string: url) else {
            return
        }

        let request = URLRequest(url: artworkURL)
        let urlResponseMaybe: HTTPURLResponse?

        // TODO: Is a synchronous data task just a bad idea here?
        let dataMaybe: Data?
        do {
            (dataMaybe, urlResponseMaybe) = try URLSession.shared.synchronousDataTask(urlrequest: request)
        } catch {
            DLOG("error downloading artwork from: \(url) -- \(error.localizedDescription)")
            return
        }

        guard let data = dataMaybe, let urlResponse = urlResponseMaybe else {
            ELOG("No response or data")
            return
        }

        if urlResponse.statusCode != 200 {
            DLOG("HTTP Error: \(urlResponse.statusCode). \nResponse: \(urlResponse)")
        }

        if let artwork = UIImage(data: data) {
            do {
                let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: url)
                try RomDatabase.sharedInstance.writeTransaction {
                    let file = PVImageFile(withURL: localURL)
                    game.originalArtworkFile = file
                }
            } catch { ELOG("\(error.localizedDescription)") }
        }

        if finishedArtworkHandler != nil {
            DispatchQueue.main.sync(execute: {() -> Void in
                self.finishedArtworkHandler?(url)
            })
        }
    }

    func moveROM(toAppropriateSubfolder canidateFile: ImportCanidateFile) -> URL? {

        let filePath = canidateFile.filePath
        var newPath: URL? = nil
        var subfolderPathMaybe: URL? = nil

        var systemID: String? = nil
        let fm = FileManager.default

        let extensionLowercased = filePath.pathExtension.lowercased()

        // Check if zip
        if PVEmulatorConfiguration.archiveExtensions.contains(extensionLowercased) {
            return nil
        }

        // Check first if known BIOS
        if let biosEntry = biosEntryMatcing(canidateFile: canidateFile) {
            // We have a BIOS file match
            let destiaionPath = biosEntry.expectedPath
            let biosDirectory = biosEntry.system.biosDirectory

            do {
                if !fm.fileExists(atPath: biosDirectory.path) {
                    try fm.createDirectory(at: biosEntry.system.biosDirectory, withIntermediateDirectories: true, attributes: nil)
                    ILOG("Created BIOS directory \(biosDirectory)")
                }
            } catch {
                ELOG("Unable to create BIOS directory \(biosDirectory), \(error.localizedDescription)")
                return nil
            }

            do {
                if fm.fileExists(atPath: destiaionPath.path) {
                    ILOG("BIOS already at \(destiaionPath.path). Will try to delete before moving new file.")
                    try fm.removeItem(at: destiaionPath)
                }
                try fm.moveItem(at: filePath, to: destiaionPath)
            } catch {
                ELOG("Unable to move BIOS \(filePath.path) to \(destiaionPath.path) : \(error.localizedDescription)")
            }

            do {
                if let file = biosEntry.file {
                    try file.delete()
                }

                try RomDatabase.sharedInstance.writeTransaction {
                    let file = PVFile.init(withURL: destiaionPath)
                    biosEntry.file = file
                }
            } catch {
                ELOG("Failed to update BIOS file path in database: \(error)")
            }
            return nil
        }

        // Check if .m3u
        if extensionLowercased == "m3u" {
            let cueFilenameWithoutExtension = filePath.deletingPathExtension().lastPathComponent
            let similiarFile = PVEmulatorConfiguration.stripDiscNames(fromFilename: cueFilenameWithoutExtension)

            var foundGameMaybe = RomDatabase.sharedInstance.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [similiarFile])).first

                // If don't find by the m3u partial file name matching a filename, try to see if the first line of the m3u matches any games filenames partially
            if foundGameMaybe == nil, let m3uContents = try? String(contentsOf: filePath, encoding: .utf8) {
                if var firstLine = m3uContents.components(separatedBy: .newlines).first {
                    firstLine = PVEmulatorConfiguration.stripDiscNames(fromFilename: firstLine)
                    if let game = RomDatabase.sharedInstance.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [similiarFile])).first {
                        foundGameMaybe = game
                    }
                }
            }

            if let game = foundGameMaybe {
                ILOG("Found game <\(game.title)> that matches .m3u <\(filePath.lastPathComponent)>")
                let directory = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: game.systemIdentifier)
                let nameWithoutExtension = ((game.romPath as NSString).lastPathComponent as NSString).deletingPathExtension
                let newFilename = "\(nameWithoutExtension).m3u"
                let destinationPath = directory.appendingPathComponent(newFilename, isDirectory: false)
                do {
                    try FileManager.default.moveItem(at: filePath, to: destinationPath)
                    ILOG("Moved <\(filePath.lastPathComponent)> to \(directory.lastPathComponent)")
                } catch {
                    ELOG("Failed to move m3u \(filePath.lastPathComponent) to \(directory.lastPathComponent). \(error.localizedDescription)")
                }
            } else {
                // See if the m3u contents has anything that matches

            }
        }

        // Done dealing with BIOS file matches
        guard let systemsForExtension = systemIDsForRom(at: filePath), !systemsForExtension.isEmpty else {
            ELOG("No system found to match \(filePath.lastPathComponent)")
            return nil
        }

        if systemsForExtension.count > 1, let fileMD5 = canidateFile.md5?.uppercased() {
            // Multiple hits - Check by MD5
            var foundSystemIDMaybe: String?

            // Any results of MD5 match?
            var results: [[String: NSObject]]?
            for currentSystem: String in systemsForExtension {
                // TODO: Would be better performance to search EVERY system MD5 in a single query?
                if let gotit = try? self.searchDatabase(usingKey: "romHashMD5", value: fileMD5, systemID: currentSystem) {
                    foundSystemIDMaybe = currentSystem
                    results = gotit
                    break
                }
            }

            if let results = results, !results.isEmpty {

                // We have a valid result, use the ID we found
                systemID = foundSystemIDMaybe

                if let s = systemID, let f = systemToPathMap[s] {
                    subfolderPathMaybe = f
                } else {
                    ELOG("Didn't expecte any nils here")
                    return nil
                }
            } else {
                // No matches - choose the conflicts folder to move to
                subfolderPathMaybe = self.conflictPath
                self.encounteredConflicts = true
            }
        } else {
            guard let onlySystem = systemsForExtension.first else {
                ILOG("Empty results")
                return nil
            }

            // Only 1 result
            systemID = String(onlySystem)

            if let s = systemID, let f = systemToPathMap[s] {
                subfolderPathMaybe = f
            } else {
                ELOG("Didn't expecte any nils here")
                return nil
            }
        }

        guard let subfolderPath = subfolderPathMaybe, !subfolderPath.path.isEmpty else {
            return nil
        }

        // Try to create the directory where this ROM  goes,
        // withIntermediateDirectories == true means it won't error if exists
        do {
            try fm.createDirectory(at: subfolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            DLOG("Unable to create \(subfolderPath.path) - \(error.localizedDescription)")
            return nil
        }

        let destination = subfolderPath.appendingPathComponent(filePath.lastPathComponent)

        // Try to move the filel to it's home
        do {
            try fm.moveItem(at: filePath, to: destination)
            ILOG("Moved file \(filePath.path) to directory \(destination.path)")
        } catch {

            ELOG("Unable to move file from \(filePath) to \(subfolderPath) - \(error.localizedDescription)")

            switch error {
            case CocoaError.fileWriteFileExists:
                ILOG("File already exists, Deleing from import folder to prevent recursive attempts to move")
                do {
                    try fm.removeItem(at: filePath)
                } catch {
                    ELOG("Unable to delete \(filePath.path) (after trying to move and getting 'file exists error', because \(error.localizedDescription)")
                }
            default:
                break
            }

            return nil
        }

        // We moved sucessfully
        if !self.encounteredConflicts {
            newPath = destination
        }
        return newPath
    }

    func moveFiles(similiarToFile inputFile: URL, toDirectory: URL, cuesheet cueSheetPath: URL) -> [URL]? {
        ILOG("Move files files similiar to \(inputFile.lastPathComponent) to directory \(toDirectory.lastPathComponent) from cue sheet \(cueSheetPath.lastPathComponent)")
        let relatedFileName: String = PVEmulatorConfiguration.stripDiscNames(fromFilename: inputFile.deletingPathExtension().lastPathComponent)

        let contents: [URL]
        let fromDirectory = inputFile.deletingLastPathComponent()
        do {
            contents = try FileManager.default.contentsOfDirectory(at: fromDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
        } catch {
            ELOG("Error scanning \(fromDirectory.path), \(error.localizedDescription)")
            return nil
        }

        var filesMovedToPaths = [URL]()
        contents.forEach { file in
            if file.path.contains("_MACOSX") {
                ILOG("Found a file with __MACOSX. Need to delete this.")
                do {
                    try FileManager.default.removeItem(at: file)
                } catch {
                    ELOG("\(error.localizedDescription)")
                }
                return
            }

            var filenameWithoutExtension = file.deletingPathExtension().lastPathComponent

            // Some cue's have multiple bins, like, Game.cue Game (Track 1).bin, Game (Track 2).bin ....
            // Clip down the file name to the length of the .cue to see if they start to match
            if filenameWithoutExtension.count > relatedFileName.count {
                filenameWithoutExtension = (filenameWithoutExtension as NSString).substring(with: NSRange(location: 0, length: relatedFileName.count))
                    // RegEx pattern match the parentheses e.g. " (Disc 1)"
                filenameWithoutExtension =  PVEmulatorConfiguration.stripDiscNames(fromFilename: filenameWithoutExtension)
            }

            if filenameWithoutExtension.contains(relatedFileName) {
                DLOG("<\(file.lastPathComponent)> was found to be similiar to <\(cueSheetPath.lastPathComponent)>")
                // Before moving the file, make sure the cue sheet's reference uses the same case.
                if !cueSheetPath.path.isEmpty {
                    do {
                        var cuesheet = try String(contentsOf: cueSheetPath)
                        cuesheet = cuesheet.replacingOccurrences(of: filenameWithoutExtension, with: filenameWithoutExtension, options: .caseInsensitive, range: nil)

                        do {
                            try cuesheet.write(to: cueSheetPath, atomically: false, encoding: .utf8)
                        } catch {
                            ELOG("Unable to rewrite cuesheet \(cueSheetPath.path) because \(error.localizedDescription)")
                        }

                    } catch {
                        ELOG("Unable to read cue sheet \(cueSheetPath.path) because \(error.localizedDescription)")
                    }
                }

                if !FileManager.default.fileExists(atPath: file.path) {
                    ELOG("Source file \(file.path) doesn't exist!")
                    return
                }

                let toPath = toDirectory.appendingPathComponent(file.lastPathComponent, isDirectory: false)

                do {
                    try FileManager.default.createDirectory(at: toDirectory, withIntermediateDirectories: true, attributes: nil)
                    try FileManager.default.moveItem(at: file, to: toPath)
                    DLOG("Moved file from \(file) to \(toPath.path)")
                    filesMovedToPaths.append(toPath)
                } catch {
                    ELOG("Unable to move file from \(file.path) to \(toPath.path) - \(error.localizedDescription)")
                }
            }
                // Look for m3u's that have filenames that don't match but the contents of the file does contain this file
            else if file.pathExtension.lowercased() == "m3u", let m3uContents = try? String.init(contentsOf: file) {
                if m3uContents.contains(cueSheetPath.lastPathComponent) {
                    ILOG("m3u file <\(file.lastPathComponent)> contains the cue <\(cueSheetPath.lastPathComponent)>. Moving as well to \(toDirectory.lastPathComponent). Will rename to match as well.")
                    let cueFilename = cueSheetPath.deletingPathExtension().lastPathComponent
                    let newM3UFilename = "\(cueFilename).m3u"
                    let newM3UPath = toDirectory.appendingPathComponent(newM3UFilename, isDirectory: false)
                    do {
                        try FileManager.default.moveItem(at: file, to: newM3UPath)
                        filesMovedToPaths.append(newM3UPath)
                    } catch {
                        ELOG("Failed to move m3u \(file.lastPathComponent) to directory \(toDirectory.lastPathComponent)")
                    }
                }
            }
        }

        return filesMovedToPaths.isEmpty ? nil : filesMovedToPaths
    }

    // Helper
    func systemId(forROMCanidate rom: ImportCanidateFile) -> String? {
        guard let md5 = rom.md5 else {
            ELOG("MD5 was blank")
            return nil
        }

        let fileName: String = rom.filePath.lastPathComponent
        let queryString = "SELECT DISTINCT systemID FROM ROMs WHERE romHashMD5 = '\(md5)' OR romFileName = '\(fileName)'"

        do {
            // var results: [[String: NSObject]]? = nil
            let results = try openVGDB.executeQuery(queryString)
            if
                let match = results.first,
                let databaseID = match["systemID"] as? Int,
                let systemID = PVEmulatorConfiguration.systemID(forDatabaseID: databaseID) {
                return systemID
            } else {
                ILOG("Could't match \(rom.filePath.lastPathComponent) based off of MD5 {md5}")
                return nil
            }
        } catch {
            DLOG("Unable to find rom by MD5: \(error.localizedDescription)")
            return nil
        }
    }
}
