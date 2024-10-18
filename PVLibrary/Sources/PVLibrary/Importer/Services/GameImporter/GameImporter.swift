//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  GameImporter.swift
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
import Foundation
import PVSupport
import RealmSwift
import PVCoreLoader
import AsyncAlgorithms
import PVPlists
import PVLookup
import Systems
import PVMediaCache
import PVFileSystem
import PVLogging
import PVPrimitives
import PVRealm

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public func + <K, V>(lhs: [K: V], rhs: [K: V]) -> [K: V] {
    var combined = lhs

    for (k, v) in rhs {
        combined[k] = v
    }

    return combined
}

public typealias GameImporterImportStartedHandler = (_ path: String) -> Void
public typealias GameImporterCompletionHandler = (_ encounteredConflicts: Bool) -> Void
public typealias GameImporterFinishedImportingGameHandler = (_ md5Hash: String, _ modified: Bool) -> Void
public typealias GameImporterFinishedGettingArtworkHandler = (_ artworkURL: String?) -> Void

public final class GameImporter {
    public var importStartedHandler: GameImporterImportStartedHandler?
    public var completionHandler: GameImporterCompletionHandler?
    public var finishedImportHandler: GameImporterFinishedImportingGameHandler?
    public var finishedArtworkHandler: GameImporterFinishedGettingArtworkHandler?
    public private(set) var encounteredConflicts = false

    public static let shared: GameImporter = GameImporter()
    
    lazy var openVGDB = OpenVGDB.init()

    let workQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "romImporterWorkQueue"
        q.maxConcurrentOperationCount = 3 //OperationQueue.defaultMaxConcurrentOperationCount
        return q
    }()

    public private(set) var serialImportQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "org.provenance-emu.provenance.serialImportQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    public private(set) lazy var systemToPathMap = [String: URL]()
    public private(set) lazy var romExtensionToSystemsMap = [String: [String]]()

    // MARK: - Paths

    public var documentsPath: URL { get { URL.documentsPath }}
    public var romsImportPath: URL { Paths.romsImportPath }
    public var romsPath: URL { get { Paths.romsPath }}
    public var biosPath: URL { get { Paths.biosesPath }}

    public let conflictPath: URL = URL.documentsPath.appendingPathComponent("Conflicts/", isDirectory: true)

    public func path(forSystemID systemID: String) -> URL? {
        return systemToPathMap[systemID]
    }

    public func systemIDsForRom(at path: URL) -> [String]? {
        let fileExtension: String = path.pathExtension.lowercased()
        return romExtensionToSystemsMap[fileExtension]
    }

    internal func isCDROM(_ romFile: ImportCandidateFile) -> Bool {
        let cdExtensions = PVEmulatorConfiguration.supportedCDFileExtensions
        let ext = romFile.filePath.pathExtension
        if ext.lowercased() == "chd" { return false }
        return cdExtensions.contains(ext)
    }

    fileprivate let ThisBundle: Bundle = Bundle.module

    public var conflictedFiles: [URL]? {
        guard FileManager.default.fileExists(atPath: conflictPath.path),
              let files = try? FileManager.default.contentsOfDirectory(at: conflictPath,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        else {
            DLOG("")
            return nil
        }
        return files
    }

    fileprivate var notificationToken: NotificationToken?
    public let initialized = DispatchGroup()

    fileprivate func createDefaultDirectory(_ fm: FileManager, url: URL) {
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
            ILOG("Path <\(url)> doesn't exist. Creating.")
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ELOG("Error making conflicts dir <\(url)>")
                assertionFailure("Error making conflicts dir <\(url)>")
            }
        }
    }
    
    fileprivate init() {
        let fm = FileManager.default
        //we really should create default directories here to ensure there's no issue later
        //ideally some of this shouldn't be the responsibility of GameImporter, but at least for now this guarantees the directories are created.
        createDefaultDirectory(fm, url: conflictPath)
        createDefaultDirectory(fm, url: romsPath)
        createDefaultDirectory(fm, url: romsImportPath)
        createDefaultDirectory(fm, url: biosPath)
    }

    var coreLoader: CoreLoader { .shared }

    public func initSystems() async {
        initialized.enter()
        
        //this is already an async function, just await the response of this
        await self.initCorePlists()
        

        @Sendable func updateSystemToPathMap() async -> [String: URL] {
            let systems = PVSystem.all
            return await systems.async.reduce(into: [String: URL]()) {partialResult, system in
                partialResult[system.identifier] = system.romsDirectory
            }
        }

        @Sendable func updateromExtensionToSystemsMap() -> [String: [String]] {
            return PVSystem.all.reduce([String: [String]](), { (dict, system) -> [String: [String]] in
                let extensionsForSystem = system.supportedExtensions
                // Make a new dict of [ext : systemID] for each ext in extions for that ID, then merge that dictionary with the current one,
                // if the dictionary already has that key, the arrays are joined so you end up with a ext mapping to multpiple systemIDs
                let extsToCurrentSystemID = extensionsForSystem.reduce([String: [String]](), { (dict, ext) -> [String: [String]] in
                    var dict = dict
                    dict[ext] = [system.identifier]
                    return dict
                })

                return dict.merging(extsToCurrentSystemID, uniquingKeysWith: { var newArray = $0; newArray.append(contentsOf: $1); return newArray })

            })
        }

        // Observe Results Notifications
        Task.detached { @MainActor in
            let systems = PVSystem.all

            self.notificationToken = systems.observe { [unowned self] (changes: RealmCollectionChange) in
                switch changes {
                case .initial:
                    Task.detached {
                        // Results are now populated and can be accessed without blocking the UI
                        self.systemToPathMap = await updateSystemToPathMap()
                        self.romExtensionToSystemsMap = updateromExtensionToSystemsMap()
                        self.initialized.leave()
                    }
                case .update:
                    Task.detached {
                        self.systemToPathMap = await updateSystemToPathMap()
                        self.romExtensionToSystemsMap = updateromExtensionToSystemsMap()
                    }
                case let .error(error):
                    // An error occurred while opening the Realm file on the background worker thread
                    fatalError("\(error)")
                }
            }
        }
    }

    fileprivate func initCorePlists() async {

        let corePlists: [EmulatorCoreInfoPlist]  = CoreLoader.getCorePlists()

        let bundle = ThisBundle
        await PVEmulatorConfiguration.updateSystems(fromPlists: [bundle.url(forResource: "systems", withExtension: "plist")!])
        await PVEmulatorConfiguration.updateCores(fromPlists: corePlists)
    }

    deinit {
        notificationToken?.invalidate()
    }

    @objc
    public func calculateMD5(forGame game: PVGame) -> String? {
        var offset: UInt64 = 0
    
        if game.systemIdentifier == SystemIdentifier.SNES.rawValue {
            offset = SystemIdentifier.SNES.offset
        } else if let system = SystemIdentifier(rawValue: game.systemIdentifier) {
            offset = system.offset
        }

        let romPath = romsPath.appendingPathComponent(game.romPath, isDirectory: false)
        let fm = FileManager.default
        if !fm.fileExists(atPath: romPath.path) {
            ELOG("Cannot find file at path: \(romPath)")
            return nil
        }

        return fm.md5ForFile(atPath: romPath.path, fromOffset: offset)
    }

    @discardableResult
    public func importFiles(atPaths paths: [URL]) async throws -> [URL] {
        // If directory, map out sub directories if folder
        let paths: [URL] = paths.compactMap { (url) -> [URL]? in
            if url.hasDirectoryPath {
                return try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            } else {
                return [url]
            }
        }.joined().map { $0 }

        let sortedPaths = PVEmulatorConfiguration.sortImportURLs(urls: paths)

        // Make ImportCandidateFile structs to hold temporary metadata for import and matching
        // This is just the path and a lazy loaded md5
        let candidateFiles = sortedPaths.map { (path) -> ImportCandidateFile in
            ImportCandidateFile(filePath: path)
        }

        let updatedCandidateFiles =
        await Task {
            // do CDs first to avoid the case where an item related to CDs is mistaken as another rom and moved
            // before processing its CD cue sheet or something
            let updatedCandidateFiles = candidateFiles.async.compactMap { [self] candidate -> ImportCandidateFile? in
                if FileManager.default.fileExists(atPath: candidate.filePath.path) {
                    if isCDROM(candidate), let movedToPaths = try await moveCDROM(toAppropriateSubfolder: candidate) {
                        // Found a CD, can add moved files now to newPaths
                        let pathsString = { movedToPaths.map { $0.path }.joined(separator: ", ") }
                        VLOG("Found a CD. Moved files to the following paths \(pathsString())")

                        // Return nil since we don't need the ImportCandidateFile anymore
                        // Files are already moved and imported to database (in theory),
                        // or moved to conflicts dir and already set the conflists flag - jm
                        return nil
                    } else if Extensions.artworkExtensions.contains(candidate.filePath.pathExtension.lowercased()), let game = await GameImporter.importArtwork(fromPath: candidate.filePath) {
                        // Is artwork, import that
                        ILOG("Found artwork \(candidate.filePath.lastPathComponent) for game <\(game.title)>")
                        return nil
                    } else {
                        return candidate
                    }
                } else {
                    if !["bin", "iso", "img", "sub"].contains(candidate.filePath.pathExtension) {
                        WLOG("File should have existed at \(candidate.filePath) but it might have been moved")
                    }
                    await self.deleteIfJunk(candidate.filePath)

                    return nil
                }
            }
            return updatedCandidateFiles
        }.value

        // Add new paths from remaining candidate files
        // CD files that matched a system will be remove already at this point
        let newPaths = updatedCandidateFiles.compactMap { [self] candidate -> URL? in
            if FileManager.default.fileExists(atPath: candidate.filePath.path) {
                if let newPath = try await moveROM(toAppropriateSubfolder: candidate) {
                    return newPath
                }
            }
            return nil
        }

        return try await newPaths.collect()
    }

    @discardableResult
    private func deleteIfJunk(_ filePath: URL) async -> Bool {
        if filePath.lastPathComponent != "0", filePath.path.contains(Paths.romsImportPath.lastPathComponent), !Extensions.allKnownExtensions.contains(filePath.pathExtension.lowercased()) {
            let extLHS = filePath.lastPathComponent
            let extRHS = Paths.romsImportPath.lastPathComponent
            ILOG("\(extLHS) doesn't matching any known possible extensions and is in \(extRHS) directory. Deleting.")
            do {
                if FileManager.default.fileExists(atPath: filePath.path) {
                    try FileManager.default.removeItem(at: filePath)
                    ILOG("Deleted \(filePath.path).")
                }
                return true
            } catch {
                ELOG("Deletion error: \(error.localizedDescription)")
            }
        }

        return false
    }

    public func startImport(forPaths paths: [URL]) {
        // Pre-sort
        let paths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
        let scanOperation = BlockOperation {
            Task {
                do {
                    let newPaths = try await self.importFiles(atPaths: paths)
                    await self.getRomInfoForFiles(atPaths: newPaths, userChosenSystem: nil)
                } catch {
                    ELOG("\(error)")
                }
            }
        }

        let completionOperation = BlockOperation {
            if self.completionHandler != nil {
                DispatchQueue.main.sync(execute: { () -> Void in
                    self.completionHandler?(self.encounteredConflicts)
                })
            }
        }

        completionOperation.addDependency(scanOperation)
        serialImportQueue.addOperation(scanOperation)
        serialImportQueue.addOperation(completionOperation)
    }

    public func moveAndOverWrite(sourcePath: URL, destinationPath: URL) throws {
        do {
            if FileManager.default.fileExists(atPath: destinationPath.path) {
                try FileManager.default.removeItem(atPath: destinationPath.path)
            }
            try FileManager.default.moveItem(at: sourcePath, to: destinationPath)
            DLOG("Moved \(sourcePath.path) to \(destinationPath.path)")
        } catch {
            ELOG("Unable to move \(sourcePath.path) to \(destinationPath.path) because: \(error.localizedDescription)")
            throw error
        }
    }

    public func resolveConflicts(withSolutions solutions: [URL: System]) async {
        let importOperation = BlockOperation()

        await solutions.asyncForEach { filePath, system in
            let subfolder = system.romsDirectory

            if !FileManager.default.fileExists(atPath: subfolder.path, isDirectory: nil) {
                ILOG("Path <\(subfolder.path)> doesn't exist. Creating.")
                do {
                    try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    ELOG("Error making conflicts dir <\(subfolder.path)>")
                    assertionFailure("Error making conflicts dir <\(subfolder.path)>")
                }
            }

            let sourceFilename: String = filePath.lastPathComponent
            let sourcePath: URL = filePath
            let destinationPath: URL = subfolder.appendingPathComponent(sourceFilename, isDirectory: false)

            do {
                try moveAndOverWrite(sourcePath: sourcePath, destinationPath: destinationPath)
            } catch {
                ELOG("\(error)")
                // TODO: Should we return here? I just added throwing but the parent callers not sure if they should care or just log @JoeMatt 5/23
            }

            // moved the .cue, now move .bins .imgs etc
            let relatedFileName: String = sourcePath.deletingPathExtension().lastPathComponent

            let conflictsDirContents = try? FileManager.default.contentsOfDirectory(at: conflictPath, includingPropertiesForKeys: nil, options: [])
            conflictsDirContents?.forEach { file in
                var fileWithoutExtension: String = file.deletingPathExtension().lastPathComponent
                fileWithoutExtension = PVEmulatorConfiguration.stripDiscNames(fromFilename: fileWithoutExtension)
                let relatedFileName = PVEmulatorConfiguration.stripDiscNames(fromFilename: relatedFileName)
                /*
                 // Crop out any extra info in the .bin files, like Game.cue and Game (Track 1).bin, we want to match up to just 'Game'
                 if fileWithoutExtension.count > relatedFileName.count {
                 // Trim the matching filename to same lentgh as possible relation string
                 fileWithoutExtension = String(fileWithoutExtension[..<relatedFileName.endIndex])
                 }
                 // TODO: This doesn't take into account things with (Disc) need to remove those using regex, I think. unless we d
                 // Compare the trimmed string is the same as our match looking string
                 */
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
                        try moveAndOverWrite(sourcePath: file, destinationPath: newDestinationPath)
                        NSLog("Moving \(file.lastPathComponent) to \(newDestinationPath)")
                    } catch {
                        ELOG("Unable to move related file from \(filePath.path) to \(subfolder.path) because: \(error.localizedDescription)")
                    }
                }
            }

            importOperation.addExecutionBlock {
                Task {
                    ILOG("Import Files at \(destinationPath)")
                    if let system = await RomDatabase.sharedInstance.getSystemCache()[system.identifier] {
                        RomDatabase.sharedInstance.addFileSystemROMCache(system)
                    }
                    await self.getRomInfoForFiles(atPaths: [destinationPath], userChosenSystem: system)
                }
            }
        } // End forEach

        let completionOperation = BlockOperation {
            if self.completionHandler != nil {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.completionHandler?(false)
                })
            }
        }

        completionOperation.addDependency(importOperation)
        serialImportQueue.addOperation(importOperation)
        serialImportQueue.addOperation(completionOperation)
    }
}

public extension GameImporter {
//    func updateSystemToPathMap() async -> [String: URL] {
//        let map = await PVSystem.all.async.reduce([String: URL]()) { (dict, system) -> [String: URL] in
//            var dict = dict
//            dict[system.identifier] = await system.romsDirectory
//            return dict
//        }
//
//        return map
//    }
//
//    func updateromExtensionToSystemsMap() -> [String: [String]] {
//        return PVSystem.all.reduce([String: [String]](), { (dict, system) -> [String: [String]] in
//            let extensionsForSystem = system.supportedExtensions
//            // Make a new dict of [ext : systemID] for each ext in extions for that ID, then merge that dictionary with the current one,
//            // if the dictionary already has that key, the arrays are joined so you end up with a ext mapping to multpiple systemIDs
//            let extsToCurrentSystemID = extensionsForSystem.reduce([String: [String]](), { (dict, ext) -> [String: [String]] in
//                var dict = dict
//                dict[ext] = [system.identifier]
//                return dict
//            })
//
//            return dict.merging(extsToCurrentSystemID, uniquingKeysWith: { var newArray = $0; newArray.append(contentsOf: $1); return newArray })
//
//        })
//    }
}

public extension GameImporter {
    /**
     Import a specifically named image file to the matching game.

     To update “Kart Fighter.nes”, use an image named “Kart Fighter.nes.png”.

     @param imageFullPath The artwork image path
     @return The game that was updated
     */
    class func importArtwork(fromPath imageFullPath: URL) async -> PVGame? {
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

        guard let systems: [PVSystem] = PVEmulatorConfiguration.systemsFromCache(forFileExtension: gameExtension), !systems.isEmpty else {
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
                    """
                )
                return nil
            }
        }

        // We already verified that above that there's 1 and only 1 system ID that matmched so force first!
        guard let system = systems.first else {
            ELOG("systems empty")
            return nil
        }

        // TODO: This will break if we move the ROMS to a new spot
        // Remove extension and leading '/' so we can match 'com.provenance.vb/Tetris [SomeThing] US BLAH.vb'
        // will match with /com.provenance.vb/Tetris.vb since it becomes 'com.provenance.vb/Tetris' since I use a beginswith query
        // First try an extact match though incase there are mulitples that start with similiar
        var gamePartialPath: String = URL(fileURLWithPath: system.identifier, isDirectory: true).appendingPathComponent(gameFilename).deletingPathExtension().path
        if gamePartialPath.first == "/" {
            gamePartialPath.removeFirst()
        }

        if gamePartialPath.isEmpty {
            ELOG("Game path was empty")
            return nil
        }

        // Find the game in the database
        // First find an exact match incase there are multiples like com.provenance.vb/Teris [US].vb etc,
        // If that's null, ie no matches, do a begins with
        // TODO: Warn / error / ask if more than 1 returned
        var games = database.all(PVGame.self, where: #keyPath(PVGame.romPath), value: gamePartialPath)
        if games.isEmpty {
            // No reults, so do a beginsWith query
            games = database.all(PVGame.self, where: #keyPath(PVGame.romPath), beginsWith: gamePartialPath)
        }

        guard !games.isEmpty else {
            ELOG("Couldn't find game for path \(gamePartialPath)")
            return nil
        }

        if games.count > 1 {
            // TODO: Prompt use for which one? or change all, or all where custom artwork isn't set but only if tehre's at least one that isn't? =jm
            WLOG("There were multiple matches for \(gamePartialPath)! #\(games.count). Going with first for now until we make better code to prompt user.")
        }

        let game = games.first!

        guard let hash = scaleAndMoveImageToCache(imageFullPath: imageFullPath) else {
            ELOG("scaleAndMoveImageToCache failed")
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
            coverArtFullData = try Data(contentsOf: imageFullPath, options: [])
        } catch {
            ELOG("Couldn't read data from image file \(imageFullPath.path)\n\(error.localizedDescription)")
            return nil
        }

        // Create a UIImage from the Data
#if canImport(UIKit)
        guard let coverArtFullImage = UIImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }
        // Scale the UIImage to our desired max size
        guard let coverArtScaledImage = coverArtFullImage.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)) else {
            ELOG("Failed to create scale image")
            return nil
        }
#else
        guard let coverArtFullImage = NSImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }
        // Scale the UIImage to our desired max size
        let coverArtScaledImage = coverArtFullImage
        //        guard let coverArtScaledImage = coverArtFullImage.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)) else {
        //            ELOG("Failed to create scale image")
        //            return nil
        //        }
#endif

#if canImport(UIKit)
        // Create new Data from scaled image
        guard let coverArtScaledData = coverArtScaledImage.jpegData(compressionQuality: 0.85) else {
            ELOG("Failed to create data representation of scaled image")
            return nil
        }
#else
        let coverArtScaledData = coverArtScaledImage.jpegData(compressionQuality: 0.85)
#endif
        // Hash the image and save to cache
        let hash: String = (coverArtScaledData as NSData).md5

        do {
            let destinationURL = try PVMediaCache.writeData(toDisk: coverArtScaledData, withKey: hash)
            VLOG("Scaled and moved image from \(imageFullPath.path) to \(destinationURL.path)")
        } catch {
            ELOG("Failed to save artwork to cache: \(error.localizedDescription)")
            return nil
        }

        return hash
    }

    fileprivate class func findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(_ systems: [PVSystem]?, romFilename: String) -> [PVGame]? {
        // Check if existing ROM

        let allGames = RomDatabase.sharedInstance.getGamesCacheSync().values.filter ({
            $0.romPath.lowercased() == romFilename.lowercased()
        })
        /*
         let database = RomDatabase.sharedInstance

         let predicate = NSPredicate(format: "romPath CONTAINS[c] %@", PVEmulatorConfiguration.stripDiscNames(fromFilename: romFilename))
         let allGames = database.all(PVGame.self, filter: predicate)
         */
        // Optionally filter to specfici systems
        if let systems = systems {
            //let filteredGames = allGames.filter { systems.contains($0.system) }
            var sysIds:[String:Bool]=[:]
            systems.forEach({ sysIds[$0.identifier] = true })
            let filteredGames = allGames.filter { sysIds[$0.systemIdentifier] != nil }
            return filteredGames.isEmpty ? nil : Array(filteredGames)
        } else {
            return allGames.isEmpty ? nil : Array(allGames)
        }
    }

    func getRomInfoForFiles(atPaths paths: [URL], userChosenSystem chosenSystem: System? = nil) {
        // If directory, map out sub directories if folder
        let paths: [URL] = paths.compactMap { (url) -> [URL]? in
            if url.hasDirectoryPath {
                return try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            } else {
                return [url]
            }
        }.joined().map { $0 }

        let sortedPaths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
        sortedPaths.forEach { path in
            do {
                try self._handlePath(path: path, userChosenSystem: chosenSystem)
            } catch {
                ELOG("\(error)")
            }
        } // for each
    }

    func saveRelativePath(_ existingGame: PVGame, partialPath:String, file:URL) {
        if RomDatabase.sharedInstance.getGamesCacheSync()[partialPath] == nil {
            RomDatabase.sharedInstance.addRelativeFileCache(file, game:existingGame)
        }
    }

    func _handlePath(path: URL, userChosenSystem chosenSystem: System?) throws {
        var systemsMaybe: [PVSystem]?
        let urlPath = path
        let filename = urlPath.lastPathComponent
        let fileExtensionLower = urlPath.pathExtension.lowercased()
        let isDirectory: Bool
        isDirectory = path.hasDirectoryPath
        if path.lastPathComponent.hasPrefix(".") {
            VLOG("Skipping file with . as first character or it's a directory")
            return
        }
        // Before anything, check if this is a known ROM
        if let chosenSystem = chosenSystem, !isDirectory {
            let partialPath: String = (chosenSystem.identifier as NSString).appendingPathComponent(filename)
            // TODO: Better to use MD5 instead?
            let similarName = RomDatabase.sharedInstance.altName(path, systemIdentifier: chosenSystem.identifier)
            if let existingGame = RomDatabase.sharedInstance.getGamesCacheSync()[partialPath], chosenSystem.identifier == existingGame.systemIdentifier {
                //if let existingGame = database.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [partialPath])).first ?? // Exact filename match
                //database.all(PVGame.self, filter: NSPredicate(format: "ANY relatedFiles.partialPath = %@", argumentArray: [partialPath])).first, // Check if it's an associated file of another game
                //chosenSystem.identifier == existingGame.system.identifier { // Check it's a same system too
                //finishUpdateOrImport(ofGame: existingGame, path: path)
                // Matched, Return
                return
            } else if let existingGame = RomDatabase.sharedInstance.getGamesCacheSync()[similarName], chosenSystem.identifier == existingGame.systemIdentifier {
                saveRelativePath(existingGame, partialPath: partialPath, file:path)
                // Matched, Return
                return
            } else {
                if let system = RomDatabase.sharedInstance.getSystemCacheSync()[chosenSystem.identifier] {
                    Task.detached(priority: .utility) {
                        try await self.importToDatabaseROM(atPath: path, system: system, relatedFiles: nil)
                    }
                    return
                }
            }
        }

        // Handle folders, but only if no system ref was chosen (incase of CD folders)
        if isDirectory {
            if chosenSystem == nil {
                do {
                    let subContents = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                    if subContents.isEmpty {
                        // delete empty folders
                        try FileManager.default.removeItem(at: path)
                        ILOG("Deleted empty import folder \(path.path)")
                    } else {
                        ILOG("Found non-empty folder in imports dir. Will iterate subcontents for import")
                         subContents.forEach { subFile in
                            do {
                                try self._handlePath(path: subFile, userChosenSystem: nil)
                            } catch {
                                ELOG("\(error)")
                            }
                        }
                    }

                } catch {
                    ELOG("\(error)")
                }
                return
            }
        }
        if let chosenSystem = chosenSystem {
            if let system = RomDatabase.sharedInstance.getSystemCacheSync()[chosenSystem.identifier] {
                systemsMaybe = [system]
            }
            // First check if it's a chosen system that supports CDs and this is a non-cd extension
            if chosenSystem.usesCDs, !chosenSystem.extensions.contains(fileExtensionLower) {
                // We're on a file that is from a CD based system but this file isn't an importable file type so skip it.
                // This prevents us from importing .bin's for example when the .cue is already imported
                DLOG("Skipping file <\(filename)> with extension <\(fileExtensionLower)> because not a CD for <\(chosenSystem.shortName)>")
                return
            }
        } else {
            systemsMaybe = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtensionLower)
        }

        // No system found to match this file
        guard var systems = systemsMaybe else {
            ELOG("No system matched extension {\(fileExtensionLower)}")
            try moveAndOverWrite(sourcePath: path, destinationPath: conflictPath)
            return
        }

        var maybeGame: PVGame?

        if systems.count > 1 {
            // Try to match by MD5 first
            if let systemIDMatch = systemIdFromCache(forROMCandidate: ImportCandidateFile(filePath: urlPath)),
               let system = RomDatabase.sharedInstance.getSystemCacheSync()[systemIDMatch]
            //let system = database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: systemIDMatch)
            {
                systems = [system]
                DLOG("Matched \(urlPath.path) by MD5 to system \(systemIDMatch)")
            } else {
                // We have a conflict, multiple systems matched and couldn't find anything by MD5 match
                let s = systems.map({ $0.identifier }).joined(separator: ",")
                WLOG("\(filename) matched with multiple systems (or none?): \(s). Going to do my best to figure out where it belons")

                // NOT WHAT WHAT TO DO HERE. -jm
                // IS IT TOO LATE TO MOVE TO CONFLICTS DIR?

                guard let existingGames = GameImporter.findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(systems, romFilename: filename) else {
                    // NO matches to existing games, I suppose we move to conflicts dir
                    self.encounteredConflicts = true
                    try moveAndOverWrite(sourcePath: path, destinationPath: conflictPath)
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
                        try moveAndOverWrite(sourcePath: path, destinationPath: conflictPath)
                        let matchedSystems = systems.map { $0.identifier }.joined(separator: ", ")
                        let matchedGames = existingGames.map { $0.romPath }.joined(separator: ", ")
                        WLOG("Scanned game matched with multiple systems {\(matchedSystems)} and multiple existing games \(matchedGames) so we moved \(filename) to conflicts dir. You figure it out!")
                    } catch {
                        ELOG("Failed to move \(urlPath.path) to conflicts dir.")
                        throw error
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

        let gamesCache = RomDatabase.sharedInstance.getGamesCacheSync()

        // For multi-cd games, make the most inert version of the filename
        let similarName = RomDatabase.sharedInstance.altName(path, systemIdentifier: system.identifier)
        if let existingGame =
            maybeGame ?? // found a match above?
            gamesCache[partialPath] ??
            gamesCache[similarName],
           system.identifier == existingGame.systemIdentifier
        {
            //database.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [partialPath])).first ?? // Exact filename match
            //database.all(PVGame.self, filter: NSPredicate(format: "ANY relatedFiles.partialPath = %@", argumentArray: [partialPath])).first ?? // Check if it's an associated file of another game
            //database.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [similiarName])).first, // More generic match
            //system.enumValue == existingGame.system.enumValue { // Check it's a same system too
            // TODO: Check the MD5 mash. If it doesn't match, delete the imported game and re-import
            // Can't update existig game since MD5 is the primary DB key and you can't update it.
            // Downside would be that you have to then check the MD5 for every file and that would take forver
            // perhaps we should add more info to the PVGame entry for the file modified date and compare that instead,
            // then check md5 only if the date differs. - Joe M
            //finishUpdateOrImport(ofGame: existingGame, path: path)
            saveRelativePath(existingGame, partialPath: partialPath, file:path)
            return
        } else {
            // New game
            // TODO: Look for new related files?
            Task.detached(priority: .utility) {
                try await self.importToDatabaseROM(atPath: path, system: system, relatedFiles: nil)
            }
        }
    }

    private func importToDatabaseROM(atPath path: URL, system: PVSystem, relatedFiles: [URL]?) async throws {
        let filename = path.lastPathComponent
        let filenameSansExtension = path.deletingPathExtension().lastPathComponent
        let title: String = PVEmulatorConfiguration.stripDiscNames(fromFilename: filenameSansExtension)
        let destinationDir = (system.identifier as NSString)
        let partialPath: String = (system.identifier as NSString).appendingPathComponent(filename)
        let file = PVFile(withURL: path)
        let game = PVGame(withFile: file, system: system)
        game.romPath = partialPath
        game.title = title
        game.requiresSync = true
        var relatedPVFiles = [PVFile]()
        let files = RomDatabase.sharedInstance.getFileSystemROMCache(for: system).keys
        let name = RomDatabase.sharedInstance.altName(path, systemIdentifier: system.identifier)
        await files.asyncForEach { url in
            let relativeName=RomDatabase.sharedInstance.altName(url, systemIdentifier: system.identifier)
            if relativeName == name {
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
            }
        }
        if let relatedFiles = relatedFiles {
            for url in relatedFiles {
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
            }
        }
        guard let md5 = calculateMD5(forGame: game) else {
            ELOG("Couldn't calculate MD5 for game \(partialPath)")
            throw GameImporterError.couldNotCalculateMD5
        }
        game.relatedFiles.append(objectsIn: relatedPVFiles)
        game.md5Hash = md5
        // Write at finishUpdateOrImport
        try await finishUpdateOrImport(ofGame: game, path: path)
    }

    private func finishUpdateOrImport(ofGame game: PVGame, path: URL) async throws {
        // Only process if rom doensn't exist in DB
        if await RomDatabase.sharedInstance.getGamesCache()[game.romPath] != nil {
            throw GameImporterError.romAlreadyExistsInDatabase
        }
        var modified = false
        var game:PVGame = game
        if game.requiresSync {
            if importStartedHandler != nil {
                let fullpath = PVEmulatorConfiguration.path(forGame: game)
                Task { @MainActor in
                    self.importStartedHandler?(fullpath.path)
                }
            }
            game = lookupInfo(for: game, overwrite: true)
            modified = true
        }
        let wasModified = modified
        if finishedImportHandler != nil {
            let md5: String = game.md5Hash
//            Task { @MainActor in
                self.finishedImportHandler?(md5, wasModified)
//            }
        }
        if game.originalArtworkFile == nil {
            game = await getArtwork(forGame: game)
        }
        self.saveGame(game)
    }
    func saveGame(_ game:PVGame) {
        do {
            let database = RomDatabase.sharedInstance
            try database.writeTransaction {
                database.realm.create(PVGame.self, value:game, update:.modified)
            }
            RomDatabase.sharedInstance.addGamesCache(game)
        } catch {
            ELOG("Couldn't add new game \(error.localizedDescription)")
        }
    }
}



// MARK: - Movers

extension GameImporter {
    /**
     Looks at a candidate file (should be a cue). Tries to find .bin files that match the filename by pattern
     matching the filename up to the .cue to other files in the same directory.

     - paramater candidateFile: ImportCandidateFile of the .cue file for the CD based rom

     - returns: Returns the paths of the .bins and .cue in the new directory they were moved to. Should be a system diretory. Returns nil if a match wasn't found or an error in the process
     */
    public func moveCDROM(toAppropriateSubfolder candidateFile: ImportCandidateFile) async throws -> [URL]? {
        guard let systemsForExtension = systemIDsForRom(at: candidateFile.filePath) else {
            WLOG("No system found for import candidate file \(candidateFile.filePath.lastPathComponent)")
            return nil
        }

        var subfolderPathMaybe: URL?

        var matchedSystemID: String?

        if systemsForExtension.count > 1 {
            // Try to match by MD5 or filename
            if let systemID = self.systemId(forROMCandidate: candidateFile) {
                subfolderPathMaybe = systemToPathMap[systemID]
                matchedSystemID = systemID
            } else {
                ILOG("No MD5 match.")
                // No MD5 match, so move to conflict dir
                subfolderPathMaybe = conflictPath
                encounteredConflicts = true
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

        // Create the subfolder path if need be
        if !FileManager.default.fileExists(atPath: subfolderPath.path, isDirectory: nil) {
            do {
                ILOG("Path <\(subfolderPath)> doesn't exist. Creating.")
                try FileManager.default.createDirectory(at: subfolderPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ELOG("Unable to create \(subfolderPath) - \(error.localizedDescription)")
                return nil
            }
        }
        let newDirectory = subfolderPath
        let newCDFilePath = newDirectory.appendingPathComponent(candidateFile.filePath.lastPathComponent)

        // Try to move the CD file
        try moveAndOverWrite(sourcePath: candidateFile.filePath, destinationPath: newCDFilePath)

        var relatedFiles: [URL]?
        // moved the .cue, now move .bins .imgs etc to the destination dir (conflicts or system dir, decided above)
        if var paths = moveFiles(similarToFile: candidateFile.filePath, toDirectory: newDirectory, cuesheet: newCDFilePath) {
            paths.append(newCDFilePath)
            relatedFiles = paths
        }

        // Move the cue sheet
        if !encounteredConflicts, let systemID = matchedSystemID, let system = PVSystem.with(primaryKey: systemID) {
            // Import to DataBase
            do {
                try await importToDatabaseROM(atPath: newCDFilePath, system: system, relatedFiles: relatedFiles)
            } catch {
                ELOG("\(error)")
            }
        } // else there was a conflict, nothing to import

        return relatedFiles
    }

    public func biosEntryMatching(candidateFile: ImportCandidateFile) -> PVBIOS? {
        // Check if BIOS by filename - should possibly just only check MD5?
        if let bios = PVEmulatorConfiguration.biosEntry(forFilename: candidateFile.filePath.lastPathComponent) {
            return bios
        } else {
            // Now check by MD5 - md5 is a lazy load var
            if let fileMD5 = candidateFile.md5, let bios = PVEmulatorConfiguration.biosEntry(forMD5: fileMD5) {
                return bios
            }
        }

        return nil
    }

    public func moveROM(toAppropriateSubfolder candidateFile: ImportCandidateFile) async throws -> URL? {
        let filePath = candidateFile.filePath
        var subfolderPathMaybe: URL?

        var systemID: String?
        let fm = FileManager.default

        let extensionLowercased = filePath.pathExtension.lowercased()

        // Check if 7z
        if Extensions.archiveExtensions.contains(extensionLowercased) {
            ILOG("Candidate file is an archive, returning from moveRom()")
            return nil
        }

        // Check first if known BIOS
        if let biosEntry = biosEntryMatching(candidateFile: candidateFile) {
            ILOG("Candidate file matches as a known BIOS")
            // We have a BIOS file match
            let destinationPath = biosEntry.expectedPath
            let biosDirectory = biosEntry.system.biosDirectory

            if !fm.fileExists(atPath: biosDirectory.path) {
                do {
                    try fm.createDirectory(at: biosEntry.system.biosDirectory, withIntermediateDirectories: true, attributes: nil)
                    ILOG("Created BIOS directory \(biosDirectory)")
                } catch {
                    ELOG("Unable to create BIOS directory \(biosDirectory), \(error.localizedDescription)")
                    throw error
                }
            }

            do {
                if fm.fileExists(atPath: destinationPath.path) {
                    ILOG("BIOS already at \(destinationPath.path). Will try to delete before moving new file.")
                    try fm.removeItem(at: destinationPath)
                }
                try fm.moveItem(at: filePath, to: destinationPath)
            } catch {
                ELOG("Unable to move BIOS \(filePath.path) to \(destinationPath.path) : \(error.localizedDescription)")
                throw error
            }

            do {
                if let file = biosEntry.file {
                    try file.delete()
                }

                let file = PVFile(withURL: destinationPath)
                try RomDatabase.sharedInstance.writeTransaction {
                    biosEntry.file = file
                }
            } catch {
                ELOG("Failed to update BIOS file path in database: \(error)")
                throw error
            }
            return nil
        }

        // Check if .m3u
        if extensionLowercased == "m3u" {
            let cueFilenameWithoutExtension = filePath.deletingPathExtension().lastPathComponent
            let similarFile = PVEmulatorConfiguration.stripDiscNames(fromFilename: cueFilenameWithoutExtension)

            var foundGameMaybe = RomDatabase.sharedInstance.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [similarFile])).first

            // If don't find by the m3u partial file name matching a filename, try to see if the first line of the m3u matches any games filenames partially
            if foundGameMaybe == nil, let m3uContents = try? String(contentsOf: filePath, encoding: .utf8) {
                if var firstLine = m3uContents.components(separatedBy: .newlines).first {
                    firstLine = PVEmulatorConfiguration.stripDiscNames(fromFilename: firstLine)
                    if let game = RomDatabase.sharedInstance.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [similarFile])).first {
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
                    // Add it as an associated file
                    Task { @MainActor in
                        let file = PVFile(withURL: destinationPath)

                        RomDatabase.sharedInstance.asyncWriteTransaction {
                            game.relatedFiles.append(file)
                        }
                    }
                } catch {
                    ELOG("Failed to move m3u \(filePath.lastPathComponent) to \(directory.lastPathComponent). \(error.localizedDescription)")
                    throw error
                }
            } else {
                // See if the m3u contents has anything that matches
            }
        }

        // check by md5
        let fileMD5 = candidateFile.md5?.uppercased()

        if let fileMD5 = fileMD5,
           !fileMD5.isEmpty,
           let searchResults = try? openVGDB.searchDatabase(usingKey: "romHashMD5", value: fileMD5),
           let gotit = searchResults.first,
           let sid: Int = gotit["systemID"] as? Int,
           let system = RomDatabase.sharedInstance.all(PVSystem.self, where: "openvgDatabaseID", value: sid).first,
           let subfolderPath = self.path(forSystemID: system.identifier),
           let subPath = try _moveRomFoundSubpath(subfolderPath: subfolderPath, filePath: filePath) {
            ILOG("MD5 matched, moved to subPath <\(subPath.path)>")
            return subPath
        }

        // Done dealing with BIOS file matches
        guard let systemsForExtension = systemIDsForRom(at: filePath), !systemsForExtension.isEmpty else {
            ELOG("No system found to match \(filePath.lastPathComponent). Will call `deleteIfJunk()`")
            await deleteIfJunk(filePath)
            throw GameImporterError.noSystemMatched
        }

        if systemsForExtension.count > 1, let fileMD5 = candidateFile.md5?.uppercased() {
            // Multiple hits - Check by MD5
            var foundSystemIDMaybe: String?

            // Any results of MD5 match?
            var results: [[String: NSObject]]?
            // TODO: Would be better performance to search EVERY system MD5 in a single query? Need to rewrite searchDatabase for an array of systemIDs

            // Wait, why are we even looking at MD5, shouldn't it be filename? testing that @JoeMatt 11/27/22

            // New code, 11/22, check by filename being close to release name first
            let filename = candidateFile.filePath.deletingPathExtension().lastPathComponent
            DLOG("Will search for filename \(filename) in possible systems by extension.")

            // TODO: test if search by name works
#if false
            // TODO: test if search by system array works
            results =  try? self.searchDatabase(usingFilename: filename, systemIDs: [systemsForExtension])
#else
            for currentSystem: String in systemsForExtension {
                if let gotit = try? self.searchDatabase(usingFilename: filename, systemID: currentSystem) {
                    foundSystemIDMaybe = currentSystem
                    results = gotit
                    DLOG("Got it by filename: \(gotit.debugDescription)")
                    break
                }
            }
#endif

            if results == nil {
#if false
                // TODO: test if search by array works
                results =  try? self.searchDatabase(usingKey: "romHashMD5", value: fileMD5, systemIDs: [systemsForExtension])
#else
                for currentSystem: String in systemsForExtension {
                    if let gotit = try? self.searchDatabase(usingKey: "romHashMD5", value: fileMD5, systemID: currentSystem) {
                        foundSystemIDMaybe = currentSystem
                        results = gotit
                        DLOG("Got it: \(gotit.debugDescription)")
                        break
                    }
                }
#endif
            }

            if let results = results, !results.isEmpty {
                // We have a valid result, use the ID we found
                systemID = foundSystemIDMaybe

                if let s = systemID, let f = systemToPathMap[s] {
                    subfolderPathMaybe = f
                } else {
                    ELOG("Didn't expect any nils here")
                    throw GameImporterError.noSystemMatched
                }
            } else {
                // No matches - choose the conflicts folder to move to
                subfolderPathMaybe = conflictPath
                encounteredConflicts = true
            }
        } else {
            guard let onlySystem = systemsForExtension.first else {
                ILOG("Empty results")
                throw GameImporterError.noSystemMatched
            }

            // Only 1 result
            systemID = String(onlySystem)

            if let s = systemID, let f = systemToPathMap[s] {
                subfolderPathMaybe = f
            } else {
                ELOG("Didn't expect any nils here")
                throw GameImporterError.noSystemMatched
            }
        }

        guard let subfolderPath = subfolderPathMaybe, !subfolderPath.path.isEmpty else {
            ELOG("`subfolderPath` is nil or empty. \(subfolderPathMaybe?.path ?? "nil")")
            return nil
        }

        let currentSubPath = filePath.deletingLastPathComponent()
        if currentSubPath == subfolderPath {
            ILOG("File already is at destination, skipping move. Perhaps this was just missing from DB.")
            return nil
        } else {
            return try _moveRomFoundSubpath(subfolderPath: subfolderPath, filePath: filePath)
        }
    }

    public func _moveRomFoundSubpath(subfolderPath: URL, filePath: URL) throws -> URL? {
        let fm = FileManager.default
        var newPath: URL?

        // Try to create the directory where this ROM  goes,
        // withIntermediateDirectories == true means it won't error if exists
        if !fm.fileExists(atPath: subfolderPath.path) {
            ILOG("Directory doesn't exist, will attempt to create <\(subfolderPath.path)>")
            do {
                try fm.createDirectory(at: subfolderPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DLOG("Unable to create \(subfolderPath.path) - \(error.localizedDescription)")
                return nil
            }
        }

        //        let filenameSansExtension = filePath.deletingPathExtension().lastPathComponent
        //        let destination = subfolderPath.appendingPathComponent("\(filenameSansExtension)/\(filePath.lastPathComponent)")
        let destination = subfolderPath.appendingPathComponent(filePath.lastPathComponent)

        DLOG("'destination' == <\(destination.path)>")
        // Try to move the file to it's home
        do {
            guard fm.fileExists(atPath: filePath.path) else {
                ELOG("No file exists at source path: <\(filePath)>")
                return nil
            }
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }

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

            throw error
        }

        // We moved sucessfully
        if !encounteredConflicts {
            newPath = destination
        }
        return newPath
    }

    public func moveFiles(similarToFile inputFile: URL, toDirectory: URL, cuesheet cueSheetPath: URL) -> [URL]? {
        ILOG("Move files files similar to \(inputFile.lastPathComponent) to directory \(toDirectory.lastPathComponent) from cue sheet \(cueSheetPath.lastPathComponent)")
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
                ILOG("Found junk file. Deleting….")
                do {
                    try FileManager.default.removeItem(at: file)
                } catch {
                    ELOG("\(error.localizedDescription)")
                }
                return
            }

            // Skip the actual .7z, etc
            if Extensions.archiveExtensions.contains(file.pathExtension.lowercased()) {
                return
            }

            var filenameWithoutExtension = file.deletingPathExtension().lastPathComponent

            // Some cue's have multiple bins, like, Game.cue Game (Track 1).bin, Game (Track 2).bin ....
            // Clip down the file name to the length of the .cue to see if they start to match
            if filenameWithoutExtension.count > relatedFileName.count {
                filenameWithoutExtension = (filenameWithoutExtension as NSString).substring(with: NSRange(location: 0, length: relatedFileName.count))
                // RegEx pattern match the parentheses e.g. " (Disc 1)"
                filenameWithoutExtension = PVEmulatorConfiguration.stripDiscNames(fromFilename: filenameWithoutExtension)
            }

            if filenameWithoutExtension.contains(relatedFileName) {
                DLOG("<\(file.lastPathComponent)> was found to be similar to <\(cueSheetPath.lastPathComponent)>")
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
                    if !FileManager.default.fileExists(atPath: toDirectory.path, isDirectory: nil) {
                        ILOG("Path <\(toDirectory)> doesn't exist. Creating.")
                        try FileManager.default.createDirectory(at: toDirectory, withIntermediateDirectories: true, attributes: nil)
                    }
                    try moveAndOverWrite(sourcePath: file, destinationPath: toPath)
                    DLOG("Moved file from \(file) to \(toPath.path)")
                    filesMovedToPaths.append(toPath)
                } catch {
                    ELOG("Unable to move file from \(file.path) to \(toPath.path) - \(error.localizedDescription)")
                }
            }
            // Look for m3u's that have filenames that don't match but the contents of the file does contain this file
            else if file.pathExtension.lowercased() == "m3u", let m3uContents = try? String(contentsOf: file) {
                if m3uContents.contains(cueSheetPath.lastPathComponent) {
                    ILOG("m3u file <\(file.lastPathComponent)> contains the cue <\(cueSheetPath.lastPathComponent)>. Moving as well to \(toDirectory.lastPathComponent). Will rename to match as well.")
                    let cueFilename = cueSheetPath.deletingPathExtension().lastPathComponent
                    let newM3UFilename = "\(cueFilename).m3u"
                    let newM3UPath = toDirectory.appendingPathComponent(newM3UFilename, isDirectory: false)
                    do {
                        try moveAndOverWrite(sourcePath: file, destinationPath: newM3UPath)
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
    public func systemIdFromCache(forROMCandidate rom: ImportCandidateFile) -> String? {
        guard let md5 = rom.md5 else {
            ELOG("MD5 was blank")
            return nil
        }
        if let result = RomDatabase.sharedInstance.getArtCache(md5) ?? RomDatabase.sharedInstance.getArtCacheByFileName(rom.filePath.lastPathComponent),
           let databaseID = result["systemID"] as? Int,
           let systemID = PVEmulatorConfiguration.systemID(forDatabaseID: databaseID) {
            return systemID
        }
        return nil
    }
    
    public func systemId(forROMCandidate rom: ImportCandidateFile) -> String? {
        guard let md5 = rom.md5 else {
            ELOG("MD5 was blank")
            return nil
        }

        let fileName: String = rom.filePath.lastPathComponent

        do {
           
            if  let databaseID = try openVGDB.system(forRomMD5: md5, or: fileName),
                let systemID = PVEmulatorConfiguration.systemID(forDatabaseID: databaseID) {
                return systemID
            } else {
                ILOG("Could't match \(rom.filePath.lastPathComponent) based off of MD5 {\(md5)}")
                return nil
            }
        } catch {
            DLOG("Unable to find rom by MD5: \(error.localizedDescription)")
            return nil
        }
    }
}
