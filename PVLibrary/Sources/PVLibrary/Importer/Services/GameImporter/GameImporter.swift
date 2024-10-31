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
import Perception

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Merges two dictionaries
public func + <K, V>(lhs: [K: V], rhs: [K: V]) -> [K: V] {
    var combined = lhs

    for (k, v) in rhs {
        combined[k] = v
    }

    return combined
}

/// Type alias for a closure that handles the start of game import
public typealias GameImporterImportStartedHandler = (_ path: String) -> Void
/// Type alias for a closure that handles the completion of game import
public typealias GameImporterCompletionHandler = (_ encounteredConflicts: Bool) -> Void
/// Type alias for a closure that handles the finish of importing a game
public typealias GameImporterFinishedImportingGameHandler = (_ md5Hash: String, _ modified: Bool) -> Void
/// Type alias for a closure that handles the finish of getting artwork
public typealias GameImporterFinishedGettingArtworkHandler = (_ artworkURL: String?) -> Void

#if !os(tvOS)
@Observable
#else
@Perceptible
#endif
public final class GameImporter: ObservableObject {
    /// Closure called when import starts
    public var importStartedHandler: GameImporterImportStartedHandler?
    /// Closure called when import completes
    public var completionHandler: GameImporterCompletionHandler?
    /// Closure called when a game finishes importing
    public var finishedImportHandler: GameImporterFinishedImportingGameHandler?
    /// Closure called when artwork finishes downloading
    public var finishedArtworkHandler: GameImporterFinishedGettingArtworkHandler?
    /// Flag indicating if conflicts were encountered during import
    public private(set) var encounteredConflicts = false

    /// Singleton instance of GameImporter
    public static let shared: GameImporter = GameImporter()

    /// Instance of OpenVGDB for database operations
    var openVGDB = OpenVGDB.init()

    /// Queue for handling import work
    let workQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "romImporterWorkQueue"
        q.maxConcurrentOperationCount = 3 //OperationQueue.defaultMaxConcurrentOperationCount
        return q
    }()

    /// Queue for handling serial import operations
    public private(set) var serialImportQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "org.provenance-emu.provenance.serialImportQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    /// Map of system identifiers to their ROM paths
    public private(set) var systemToPathMap = [String: URL]()
    /// Map of ROM extensions to their corresponding system identifiers
    public private(set) var romExtensionToSystemsMap = [String: [String]]()

    // MARK: - Paths

    /// Path to the documents directory
    public var documentsPath: URL { get { URL.documentsPath }}
    /// Path to the ROM import directory
    public var romsImportPath: URL { Paths.romsImportPath }
    /// Path to the ROMs directory
    public var romsPath: URL { get { Paths.romsPath }}
    /// Path to the BIOS directory
    public var biosPath: URL { get { Paths.biosesPath }}

    /// Path to the conflicts directory
    public let conflictPath: URL = URL.documentsPath.appendingPathComponent("Conflicts/", isDirectory: true)

    /// Returns the path for a given system identifier
    public func path(forSystemID systemID: String) -> URL? {
        return systemToPathMap[systemID]
    }

    /// Returns the system identifiers for a given ROM path
    public func systemIDsForRom(at path: URL) -> [String]? {
        let fileExtension: String = path.pathExtension.lowercased()
        return romExtensionToSystemsMap[fileExtension]
    }

    /// Checks if a given ROM file is a CD-ROM
    internal func isCDROM(_ romFile: ImportCandidateFile) -> Bool {
        return isCDROM(romFile.filePath)
    }

    /// Checks if a given path is a CD-ROM
    private func isCDROM(_ path: URL) -> Bool {
        let cdromExtensions: Set<String> = Extensions.discImageExtensions.union(Extensions.playlistExtensions)
        let fileExtension = path.pathExtension.lowercased()
        return cdromExtensions.contains(fileExtension)
    }

    /// Checks if a given path is artwork
    private func isArtwork(_ path: URL) -> Bool {
        let artworkExtensions = Extensions.artworkExtensions
        let fileExtension = path.pathExtension.lowercased()
        return artworkExtensions.contains(fileExtension)
    }

    /// Bundle for this module
    fileprivate let ThisBundle: Bundle = Bundle.module
    /// Token for notifications
    fileprivate var notificationToken: NotificationToken?
    /// DispatchGroup for initialization
    public let initialized = DispatchGroup()

    private let importCoordinator = ImportCoordinator()

    /// Initializes the GameImporter
    fileprivate init() {
        let fm = FileManager.default
        createDefaultDirectories(fm: fm)
    }

    /// Creates default directories
    private func createDefaultDirectories(fm: FileManager) {
        createDefaultDirectory(fm, url: conflictPath)
        createDefaultDirectory(fm, url: romsPath)
        createDefaultDirectory(fm, url: romsImportPath)
        createDefaultDirectory(fm, url: biosPath)
    }

    /// Creates a default directory at the given URL
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

    /// Initializes the systems
    public func initSystems() async {
        initialized.enter()
        await self.initCorePlists()

        /// Updates the system to path map
        @Sendable func updateSystemToPathMap() async -> [String: URL] {
            let systems = PVSystem.all
            return await systems.async.reduce(into: [String: URL]()) {partialResult, system in
                partialResult[system.identifier] = system.romsDirectory
            }
        }

        /// Updates the ROM extension to systems map
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

        Task.detached { @MainActor in
            let systems = PVSystem.all

            self.notificationToken = systems.observe { [unowned self] (changes: RealmCollectionChange) in
                switch changes {
                case .initial:
                    Task.detached {
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
                    fatalError("\(error)")
                }
            }
        }
    }

    /// Initializes core plists
    fileprivate func initCorePlists() async {
        let corePlists: [EmulatorCoreInfoPlist]  = CoreLoader.getCorePlists()
        let bundle = ThisBundle
        await PVEmulatorConfiguration.updateSystems(fromPlists: [bundle.url(forResource: "systems", withExtension: "plist")!])
        await PVEmulatorConfiguration.updateCores(fromPlists: corePlists)
    }

    /// Deinitializer
    deinit {
        notificationToken?.invalidate()
    }
}

// MARK: - Importing Functions

extension GameImporter {
    /// Imports files from given paths
    public func importFiles(atPaths paths: [URL]) async throws -> [URL] {
        let sortedPaths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
        var importedFiles: [URL] = []

        for path in sortedPaths {
            do {
                if let importedFile = try await importSingleFile(at: path) {
                    importedFiles.append(importedFile)
                }
            } catch {
                ELOG("Failed to import file at \(path.path): \(error.localizedDescription)")
            }
        }

        return importedFiles
    }

    /// Imports a single file from the given path
    private func importSingleFile(at path: URL) async throws -> URL? {
        guard FileManager.default.fileExists(atPath: path.path) else {
            WLOG("File doesn't exist at \(path.path)")
            return nil
        }

        if isCDROM(path) {
            return try await handleCDROM(at: path)
        } else if isArtwork(path) {
            return try await handleArtwork(at: path)
        } else {
            return try await handleROM(at: path)
        }
    }

    /// Handles importing a CD-ROM
    private func handleCDROM(at path: URL) async throws -> URL? {
        let movedToPaths = try await moveCDROM(toAppropriateSubfolder: ImportCandidateFile(filePath: path))
        if let movedToPaths = movedToPaths {
            let pathsString = movedToPaths.map { $0.path }.joined(separator: ", ")
            VLOG("Found a CD. Moved files to the following paths \(pathsString)")
        }
        return nil
    }

    /// Handles importing artwork
    private func handleArtwork(at path: URL) async throws -> URL? {
        if let game = await GameImporter.importArtwork(fromPath: path) {
            ILOG("Found artwork \(path.lastPathComponent) for game <\(game.title)>")
        }
        return nil
    }

    /// Handles importing a ROM
    private func handleROM(at path: URL) async throws -> URL? {
        let candidate = ImportCandidateFile(filePath: path)
        return try await moveROM(toAppropriateSubfolder: candidate)
    }

    public func startImport(forPaths paths: [URL]) {
        // Pre-sort
        let paths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
        let scanOperation = BlockOperation {
            Task {
                do {
                    let newPaths = try await self.importFiles(atPaths: paths)
                    self.getRomInfoForFiles(atPaths: newPaths, userChosenSystem: nil)
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
}

// MARK: - Moving Functions

extension GameImporter {
    /// Moves a CD-ROM to the appropriate subfolder
    private func moveCDROM(toAppropriateSubfolder candidate: ImportCandidateFile) async throws -> [URL]? {
        guard isCDROM(candidate.filePath) else {
            return nil
        }

        let fileManager = FileManager.default
        let fileName = candidate.filePath.lastPathComponent

        guard let system = try? await determineSystem(for: candidate) else {
            throw GameImporterError.unsupportedSystem
        }

        let destinationFolder = system.romsDirectory
        let destinationPath = destinationFolder.appendingPathComponent(fileName)

        do {
            try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true, attributes: nil)
            try fileManager.moveItem(at: candidate.filePath, to: destinationPath)
            let relatedFiles = try await moveRelatedFiles(for: candidate, to: destinationFolder)
            return [destinationPath] + relatedFiles
        } catch {
            throw GameImporterError.failedToMoveCDROM(error)
        }
    }

    /// Moves a ROM to the appropriate subfolder
    private func moveROM(toAppropriateSubfolder candidate: ImportCandidateFile) async throws -> URL? {
        guard !isCDROM(candidate.filePath) else {
            return nil
        }

        let fileManager = FileManager.default
        let fileName = candidate.filePath.lastPathComponent

        guard let system = try? await determineSystem(for: candidate) else {
            throw GameImporterError.unsupportedSystem
        }

        let destinationFolder = system.romsDirectory
        let destinationPath = destinationFolder.appendingPathComponent(fileName)

        do {
            try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true, attributes: nil)
            try fileManager.moveItem(at: candidate.filePath, to: destinationPath)
            return destinationPath
        } catch {
            throw GameImporterError.failedToMoveROM(error)
        }
    }

    /// Moves related files for a given candidate
    private func moveRelatedFiles(for candidate: ImportCandidateFile, to destinationFolder: URL) async throws -> [URL] {
        let fileManager = FileManager.default
        let fileName = candidate.filePath.deletingPathExtension().lastPathComponent
        let sourceFolder = candidate.filePath.deletingLastPathComponent()

        let relatedFiles = try fileManager.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil)
            .filter { $0.deletingPathExtension().lastPathComponent == fileName && $0 != candidate.filePath }

        return try await withThrowingTaskGroup(of: URL.self) { group in
            for file in relatedFiles {
                group.addTask {
                    let destination = destinationFolder.appendingPathComponent(file.lastPathComponent)
                    try fileManager.moveItem(at: file, to: destination)
                    return destination
                }
            }

            var movedFiles: [URL] = []
            for try await movedFile in group {
                movedFiles.append(movedFile)
            }
            return movedFiles
        }
    }

    /// Moves a file and overwrites if it already exists at the destination
    public func moveAndOverWrite(sourcePath: URL, destinationPath: URL) throws {
        let fileManager = FileManager.default

        // If file exists at destination, remove it first
        if fileManager.fileExists(atPath: destinationPath.path) {
            try fileManager.removeItem(at: destinationPath)
        }

        // Now move the file
        try fileManager.moveItem(at: sourcePath, to: destinationPath)
    }
}

// MARK: - Conflict Resolution

extension GameImporter {
    /// Resolves conflicts with given solutions
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
            }

            let relatedFileName: String = sourcePath.deletingPathExtension().lastPathComponent

            let conflictsDirContents = try? FileManager.default.contentsOfDirectory(at: conflictPath, includingPropertiesForKeys: nil, options: [])
            conflictsDirContents?.forEach { file in
                var fileWithoutExtension: String = file.deletingPathExtension().lastPathComponent
                fileWithoutExtension = PVEmulatorConfiguration.stripDiscNames(fromFilename: fileWithoutExtension)
                let relatedFileName = PVEmulatorConfiguration.stripDiscNames(fromFilename: relatedFileName)

                if fileWithoutExtension == relatedFileName {
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
                    if let system = RomDatabase.systemCache[system.identifier] {
                        RomDatabase.addFileSystemROMCache(system)
                    }
                    self.getRomInfoForFiles(atPaths: [destinationPath], userChosenSystem: system)
                }
            }
        }

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

// MARK: - Artwork Handling

public extension GameImporter {
    /// Imports artwork from a given path
    class func importArtwork(fromPath imageFullPath: URL) async -> PVGame? {
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: imageFullPath.path, isDirectory: &isDirectory)
        if !fileExists || isDirectory.boolValue {
            WLOG("File doesn't exist or is directory at \(imageFullPath)")
            return nil
        }

        var success = false

        defer {
            if success {
                do {
                    try FileManager.default.removeItem(at: imageFullPath)
                } catch {
                    ELOG("Failed to delete image at path \(imageFullPath) \n \(error.localizedDescription)")
                }
            }
        }

        let gameFilename: String = imageFullPath.deletingPathExtension().lastPathComponent
        let gameExtension = imageFullPath.deletingPathExtension().pathExtension
        let database = RomDatabase.sharedInstance

        if gameExtension.isEmpty {
            ILOG("Trying to import artwork that didn't contain the extension of the system")
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

        if (couldBelongToCDSystem && PVEmulatorConfiguration.supportedCDFileExtensions.contains(gameExtension.lowercased())) || systems.count > 1 {
            guard let existingGames = findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(systems, romFilename: gameFilename) else {
                ELOG("System for extension \(gameExtension) is a CD system and {\(gameExtension)} not the right matching file type of cue or m3u")
                return nil
            }
            if existingGames.count == 1, let onlyMatch = existingGames.first {
                ILOG("We found a hit for artwork that could have been belonging to multiple games and only found one file that matched by systemid/filename. The winner is \(onlyMatch.title) for \(onlyMatch.systemIdentifier)")

                guard let hash = scaleAndMoveImageToCache(imageFullPath: imageFullPath) else {
                    ELOG("Couldn't move image, fail to set custom artwork")
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
                ELOG("We got to the unlikely scenario where an extension is possibly a CD binary file, or belongs to a system, and had multiple games that matched the filename under more than one core.")
                return nil
            }
        }

        guard let system = systems.first else {
            ELOG("systems empty")
            return nil
        }

        var gamePartialPath: String = URL(fileURLWithPath: system.identifier, isDirectory: true).appendingPathComponent(gameFilename).deletingPathExtension().path
        if gamePartialPath.first == "/" {
            gamePartialPath.removeFirst()
        }

        if gamePartialPath.isEmpty {
            ELOG("Game path was empty")
            return nil
        }

        var games = database.all(PVGame.self, where: #keyPath(PVGame.romPath), value: gamePartialPath)
        if games.isEmpty {
            games = database.all(PVGame.self, where: #keyPath(PVGame.romPath), beginsWith: gamePartialPath)
        }

        guard !games.isEmpty else {
            ELOG("Couldn't find game for path \(gamePartialPath)")
            return nil
        }

        if games.count > 1 {
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

    /// Scales and moves an image to the cache
    fileprivate class func scaleAndMoveImageToCache(imageFullPath: URL) -> String? {
        let coverArtFullData: Data
        do {
            coverArtFullData = try Data(contentsOf: imageFullPath, options: [])
        } catch {
            ELOG("Couldn't read data from image file \(imageFullPath.path)\n\(error.localizedDescription)")
            return nil
        }

#if canImport(UIKit)
        guard let coverArtFullImage = UIImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }
        guard let coverArtScaledImage = coverArtFullImage.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)) else {
            ELOG("Failed to create scale image")
            return nil
        }
#else
        guard let coverArtFullImage = NSImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }
        let coverArtScaledImage = coverArtFullImage
#endif

#if canImport(UIKit)
        guard let coverArtScaledData = coverArtScaledImage.jpegData(compressionQuality: 0.85) else {
            ELOG("Failed to create data representation of scaled image")
            return nil
        }
#else
        let coverArtScaledData = coverArtScaledImage.jpegData(compressionQuality: 0.85)
#endif

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
}

// MARK: - System Management

extension GameImporter {

    /// Matches a system based on the file name
    private func matchSystemByFileName(_ fileName: String) async throws -> PVSystem? {
        let systems = PVEmulatorConfiguration.systems
        let lowercasedFileName = fileName.lowercased()
        let fileExtension = (fileName as NSString).pathExtension.lowercased()

        // First, try to match based on file extension
        if let systemsForExtension = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) {
            if systemsForExtension.count == 1 {
                return systemsForExtension[0]
            } else if systemsForExtension.count > 1 {
                // If multiple systems match the extension, try to narrow it down
                for system in systemsForExtension {
                    if await doesFileNameMatch(lowercasedFileName, forSystem: system) {
                        return system
                    }
                }
            }
        }

        // If extension matching fails, try other methods
        for system in systems {
            if await doesFileNameMatch(lowercasedFileName, forSystem: system) {
                return system
            }
        }

        // If no match found, try querying the OpenVGDB
        do {
            if let results = try await openVGDB.searchDatabase(usingFilename: fileName),
               let firstResult = results.first,
               let systemID = firstResult["systemID"] as? Int,
               let system = PVEmulatorConfiguration.system(forDatabaseID: systemID) {
                return system
            }
        } catch {
            ELOG("Error querying OpenVGDB for filename: \(error.localizedDescription)")
        }

        return nil
    }

    /// Checks if a file name matches a given system
    private func doesFileNameMatch(_ lowercasedFileName: String, forSystem system: PVSystem) async -> Bool {
        // Check if the filename contains the system's name or abbreviation
        if lowercasedFileName.contains(system.name.lowercased()) ||
           lowercasedFileName.contains(system.shortName.lowercased()) {
            return true
        }

        // Check against known filename patterns for the system
        let patterns = filenamePatterns(forSystem: system)
        for pattern in patterns {
            if lowercasedFileName.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        // Check against a list of known game titles for the system
        if await isKnownGameTitle(lowercasedFileName, forSystem: system) {
            return true
        }

        return false
    }

    /// Checks if a file name matches a known game title for a given system
    private func isKnownGameTitle(_ lowercasedFileName: String, forSystem system: PVSystem) async -> Bool {
        do {
            // Remove file extension and common parenthetical information
            let cleanedFileName = cleanFileName(lowercasedFileName)

            // Search the database using the cleaned filename
            if let results = try await openVGDB.searchDatabase(usingFilename: cleanedFileName, systemID: system.openvgDatabaseID) {
                // Check if we have any results
                if !results.isEmpty {
                    // Optionally, you can add more strict matching here
                    for result in results {
                        if let gameTitle = result["gameTitle"] as? String,
                           cleanFileName(gameTitle.lowercased()) == cleanedFileName {
                            return true
                        }
                    }
                }
            }
        } catch {
            ELOG("Error searching OpenVGDB for known game title: \(error.localizedDescription)")
        }
        return false
    }

    /// Cleans a file name
    private func cleanFileName(_ fileName: String) -> String {
        var cleaned = fileName.lowercased()

        // Remove file extension
        if let dotIndex = cleaned.lastIndex(of: ".") {
            cleaned = String(cleaned[..<dotIndex])
        }

        // Remove common parenthetical information
        let parentheticalPatterns = [
            "\\(.*?\\)",           // Matches anything in parentheses
            "\\[.*?\\]",           // Matches anything in square brackets
            "\\(u\\)",             // Common ROM notation for USA
            "\\(e\\)",             // Common ROM notation for Europe
            "\\(j\\)",             // Common ROM notation for Japan
            "\\(usa\\)",
            "\\(europe\\)",
            "\\(japan\\)",
            "\\(world\\)",
            "v1\\.0",
            "v1\\.1",
            // Add more patterns as needed
        ]

        for pattern in parentheticalPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        // Remove extra spaces and trim
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    /// Retrieves filename patterns for a given system
    private func filenamePatterns(forSystem system: PVSystem) -> [String] {
        let systemName = system.name.lowercased()
        let shortName = system.shortName.lowercased()

        var patterns: [String] = []

        // Add pattern for full system name
        patterns.append("\\b\(systemName)\\b")

        // Add pattern for short name
        patterns.append("\\b\(shortName)\\b")

        // Add some common variations and abbreviations
        switch system.identifier {
        case "com.provenance.nes":
            patterns.append("\\b(nes|nintendo)\\b")
        case "com.provenance.snes":
            patterns.append("\\b(snes|super\\s*nintendo)\\b")
        case "com.provenance.genesis":
            patterns.append("\\b(genesis|mega\\s*drive|md)\\b")
        case "com.provenance.gba":
            patterns.append("\\b(gba|game\\s*boy\\s*advance)\\b")
        case "com.provenance.n64":
            patterns.append("\\b(n64|nintendo\\s*64)\\b")
        case "com.provenance.psx":
            patterns.append("\\b(psx|playstation|ps1)\\b")
        // Add more cases for other systems as needed
        default:
            // For systems without specific patterns, we'll just use the general ones created above
            break
        }

        return patterns
    }

    /// Determines the system for a given candidate file
    private func determineSystemFromContent(for candidate: ImportCandidateFile, possibleSystems: [PVSystem]) async throws -> PVSystem {
        // Implement logic to determine system based on file content or metadata
        // This could involve checking file headers, parsing content, or using a database of known games

        let fileName = candidate.filePath.deletingPathExtension().lastPathComponent

        for system in possibleSystems {
            do {
                if let results = try openVGDB.searchDatabase(usingFilename: fileName, systemID: system.openvgDatabaseID),
                   !results.isEmpty {
                    ILOG("System determined by filename match in OpenVGDB: \(system.name)")
                    return system
                }
            } catch {
                ELOG("Error searching OpenVGDB for system \(system.name): \(error.localizedDescription)")
            }
        }

        // If we couldn't determine the system, try a more detailed search
        if let fileMD5 = candidate.md5?.uppercased(), !fileMD5.isEmpty {
            do {
                if let results = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: fileMD5),
                   let firstResult = results.first,
                   let systemID = firstResult["systemID"] as? Int,
                   let system = possibleSystems.first(where: { $0.openvgDatabaseID == systemID }) {
                    ILOG("System determined by MD5 match in OpenVGDB: \(system.name)")
                    return system
                }
            } catch {
                ELOG("Error searching OpenVGDB by MD5: \(error.localizedDescription)")
            }
        }

        // If still no match, try to determine based on file content
        // This is a placeholder for more advanced content-based detection
        // You might want to implement system-specific logic here
        for system in possibleSystems {
            if await doesFileContentMatch(candidate, forSystem: system) {
                ILOG("System determined by file content match: \(system.name)")
                return system
            }
        }

        // If we still couldn't determine the system, return the first possible system as a fallback
        WLOG("Could not determine system from content, using first possible system as fallback")
        return possibleSystems[0]
    }

    /// Checks if a file content matches a given system
    private func doesFileContentMatch(_ candidate: ImportCandidateFile, forSystem system: PVSystem) async -> Bool {
        // Implement system-specific file content matching logic here
        // This could involve checking file headers, file structure, or other system-specific traits
        // For now, we'll return false as a placeholder
        return false
    }

    /// Determines the system for a given candidate file
    private func determineSystem(for candidate: ImportCandidateFile) async throws -> PVSystem {
        guard let md5 = candidate.md5?.uppercased() else {
            throw GameImporterError.couldNotCalculateMD5
        }

        let fileExtension = candidate.filePath.pathExtension.lowercased()

        // Check if it's a CD-based game first
        if PVEmulatorConfiguration.supportedCDFileExtensions.contains(fileExtension) {
            if let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) {
                if systems.count == 1 {
                    return systems[0]
                } else if systems.count > 1 {
                    // For CD games with multiple possible systems, use content detection
                    return try await determineSystemFromContent(for: candidate, possibleSystems: systems)
                }
            }
        }

        // Try to find system by MD5 using OpenVGDB
        if let results = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: md5),
           let firstResult = results.first,
           let systemID = firstResult["systemID"] as? NSNumber,
           let system = PVEmulatorConfiguration.system(forIdentifier: String(systemID.intValue)) {
            ILOG("System determined by MD5 match: \(system.name)")

            // Check if this ROM is already being imported
            guard await importCoordinator.checkAndRegisterImport(md5: md5) else {
                throw GameImporterError.romAlreadyExistsInDatabase
            }

            return system
        }

        // If MD5 lookup fails, try to determine the system based on file extension
        if let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) {
            if systems.count == 1 {
                return systems[0]
            } else if systems.count > 1 {
                // If multiple systems support this extension, try to determine based on file content or metadata
                return try await determineSystemFromContent(for: candidate, possibleSystems: systems)
            }
        }

        throw GameImporterError.noSystemMatched
    }

    /// Retrieves the system ID from the cache for a given ROM candidate
    public func systemIdFromCache(forROMCandidate rom: ImportCandidateFile) -> String? {
        guard let md5 = rom.md5 else {
            ELOG("MD5 was blank")
            return nil
        }
        if let result = RomDatabase.artMD5DBCache[md5] ?? RomDatabase.getArtCacheByFileName(rom.filePath.lastPathComponent),
           let databaseID = result["systemID"] as? Int,
           let systemID = PVEmulatorConfiguration.systemID(forDatabaseID: databaseID) {
            return systemID
        }
        return nil
    }

    /// Matches a system based on the ROM candidate
    public func systemId(forROMCandidate rom: ImportCandidateFile) -> String? {
        guard let md5 = rom.md5 else {
            ELOG("MD5 was blank")
            return nil
        }

        let fileName: String = rom.filePath.lastPathComponent

        do {
            if let databaseID = try openVGDB.system(forRomMD5: md5, or: fileName),
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

/// ROM Query
public extension GameImporter {

    /// Retrieves ROM information for files at given paths
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
}

// Crap, bad crap
extension GameImporter {

    /// Calculates the MD5 hash for a given game
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

    /// Saves the relative path for a given game
    func saveRelativePath(_ existingGame: PVGame, partialPath:String, file:URL) {
        Task {
            if await RomDatabase.gamesCache[partialPath] == nil {
                await RomDatabase.addRelativeFileCache(file, game:existingGame)
            }
        }
    }

    /// Handles the import of a path
    func _handlePath(path: URL, userChosenSystem chosenSystem: System?) throws {
        // Skip hidden files and directories
        if path.lastPathComponent.hasPrefix(".") {
            VLOG("Skipping hidden file or directory: \(path.lastPathComponent)")
            return
        }

        let isDirectory = path.hasDirectoryPath
        let filename = path.lastPathComponent
        let fileExtensionLower = path.pathExtension.lowercased()

        // Handle directories
        if isDirectory {
            try handleDirectory(path: path, chosenSystem: chosenSystem)
            return
        }

        // Handle files
        let systems = try determineSystems(for: path, chosenSystem: chosenSystem)

        // Handle conflicts
        if systems.count > 1 {
            try handleSystemConflict(path: path, systems: systems)
            return
        }

        guard let system = systems.first else {
            ELOG("No system matched extension {\(fileExtensionLower)}")
            try moveToConflictsDirectory(path: path)
            return
        }

        try importGame(path: path, system: system)
    }

    // Helper functions

    /// Handles a directory
    private func handleDirectory(path: URL, chosenSystem: System?) throws {
        guard chosenSystem == nil else { return }

        do {
            let subContents = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            if subContents.isEmpty {
                try FileManager.default.removeItem(at: path)
                ILOG("Deleted empty import folder \(path.path)")
            } else {
                ILOG("Found non-empty folder in imports dir. Will iterate subcontents for import")
                for subFile in subContents {
                    try self._handlePath(path: subFile, userChosenSystem: nil)
                }
            }
        } catch {
            ELOG("Error handling directory: \(error)")
            throw error
        }
    }

    /// Determines the systems for a given path
    private func determineSystems(for path: URL, chosenSystem: System?) throws -> [PVSystem] {
        if let chosenSystem = chosenSystem {
            if let system = RomDatabase.systemCache[chosenSystem.identifier] {
                return [system]
            }
        }

        let fileExtensionLower = path.pathExtension.lowercased()
        return PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtensionLower) ?? []
    }

    /// Handles a system conflict
    private func handleSystemConflict(path: URL, systems: [PVSystem]) throws {
        if let systemIDMatch = systemIdFromCache(forROMCandidate: ImportCandidateFile(filePath: path)),
           let system = RomDatabase.systemCache[systemIDMatch] {
            try importGame(path: path, system: system)
        } else {
            try handleMultipleSystemMatch(path: path, systems: systems)
        }
    }

    /// Handles a multiple system match
    private func handleMultipleSystemMatch(path: URL, systems: [PVSystem]) throws {
        let filename = path.lastPathComponent
        guard let existingGames = GameImporter.findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(systems, romFilename: filename) else {
            self.encounteredConflicts = true
            try moveToConflictsDirectory(path: path)
            return
        }

        if existingGames.count == 1 {
            try importGame(path: path, system: systems.first!)
        } else {
            self.encounteredConflicts = true
            try moveToConflictsDirectory(path: path)
            let matchedSystems = systems.map { $0.identifier }.joined(separator: ", ")
            let matchedGames = existingGames.map { $0.romPath }.joined(separator: ", ")
            WLOG("Scanned game matched with multiple systems {\(matchedSystems)} and multiple existing games \(matchedGames) so we moved \(filename) to conflicts dir. You figure it out!")
        }
    }

    private func importGame(path: URL, system: PVSystem) throws {
        let filename = path.lastPathComponent
        let partialPath = (system.identifier as NSString).appendingPathComponent(filename)
        let similarName = RomDatabase.altName(path, systemIdentifier: system.identifier)

        let gamesCache = RomDatabase.gamesCache

        if let existingGame = gamesCache[partialPath] ?? gamesCache[similarName],
           system.identifier == existingGame.systemIdentifier {
            saveRelativePath(existingGame, partialPath: partialPath, file: path)
        } else {
            Task.detached(priority: .utility) {
                try await self.importToDatabaseROM(atPath: path, system: system, relatedFiles: nil)
            }
        }
    }

    /// Moves a file to the conflicts directory
    private func moveToConflictsDirectory(path: URL) throws {
        let destination = conflictPath.appendingPathComponent(path.lastPathComponent)
        try moveAndOverWrite(sourcePath: path, destinationPath: destination)
    }

    /// Imports a ROM to the database
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
        let files = RomDatabase.getFileSystemROMCache(for: system).keys
        let name = RomDatabase.altName(path, systemIdentifier: system.identifier)

        await files.asyncForEach { url in
            let relativeName = RomDatabase.altName(url, systemIdentifier: system.identifier)
            if relativeName == name {
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
            }
        }

        if let relatedFiles = relatedFiles {
            for url in relatedFiles {
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
            }
        }

        guard let md5 = calculateMD5(forGame: game)?.uppercased() else {
            ELOG("Couldn't calculate MD5 for game \(partialPath)")
            throw GameImporterError.couldNotCalculateMD5
        }

        defer {
            Task {
                await importCoordinator.completeImport(md5: md5)
            }
        }

        game.relatedFiles.append(objectsIn: relatedPVFiles)
        game.md5Hash = md5
        try await finishUpdateOrImport(ofGame: game, path: path)
    }

    /// Finishes the update or import of a game
    private func finishUpdateOrImport(ofGame game: PVGame, path: URL) async throws {
        // Only process if rom doensn't exist in DB
        if await RomDatabase.gamesCache[game.romPath] != nil {
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

    /// Saves a game to the database
    func saveGame(_ game:PVGame) {
        do {
            let database = RomDatabase.sharedInstance
            try database.writeTransaction {
                database.realm.create(PVGame.self, value:game, update:.modified)
            }
            RomDatabase.addGamesCache(game)
        } catch {
            ELOG("Couldn't add new game \(error.localizedDescription)")
        }
    }

    /// Finds any current game that could belong to any of the given systems
    fileprivate class func findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(_ systems: [PVSystem]?, romFilename: String) -> [PVGame]? {
        // Check if existing ROM

        let allGames = RomDatabase.gamesCache.values.filter ({
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
}

private actor ImportCoordinator {
    private var activeImports: Set<String> = []

    func checkAndRegisterImport(md5: String) -> Bool {
        guard !activeImports.contains(md5) else { return false }
        activeImports.insert(md5)
        return true
    }

    func completeImport(md5: String) {
        activeImports.remove(md5)
    }
}
