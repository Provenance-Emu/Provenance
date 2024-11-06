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
import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/*
 
 Logic how the importer should work:
 
 1. Detect if special file (BIOS, Artwork)
 1. Detect if the file is artwork
 2. Detect if file is a BIOS
 1. if single match, move to BIOS for system
 2. if multiple matches, move to all matching systems
 2. Detect if the file is a CD-ROM (bin/cue) or m3u
 3. Detect if the file is m3u
 1. Match by filename of m3u or md5 of
 1. If m3u matches, move all files in m3u to the system that's matched
 4. Detect if the file is a CD-ROM (bin/cue)
 1. match cue by md5
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 2. match by exact filename
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 3. Detect if single file ROM
 1. match by md5
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 2. match by exact filename
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 3. Match by extension
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 4. Match by partial filename contains system identifier
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 
 */

/// Import Coodinator
internal actor ImportCoordinator {
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

public protocol GameImporting {
    func initSystems() async
    
    var importStatus: String { get }
    
    var importQueue: [ImportQueueItem] { get }
    
    var processingState: ProcessingState { get }
    
    func addImport(_ item: ImportQueueItem)
    func addImports(forPaths paths: [URL])
    func startProcessing()
}


#if !os(tvOS)
@Observable
#else
@Perceptible
#endif
public final class GameImporter: GameImporting, ObservableObject {
    /// Closure called when import starts
    public var importStartedHandler: GameImporterImportStartedHandler?
    /// Closure called when import completes
    public var completionHandler: GameImporterCompletionHandler?
    /// Closure called when a game finishes importing
    public var finishedImportHandler: GameImporterFinishedImportingGameHandler?
    /// Closure called when artwork finishes downloading
    public var finishedArtworkHandler: GameImporterFinishedGettingArtworkHandler?
    /// Flag indicating if conflicts were encountered during import
    public internal(set) var encounteredConflicts = false
    
    /// Spotlight Handerls
    /// Closure called when spotlight completes
    public var spotlightCompletionHandler: GameImporterCompletionHandler?
    /// Closure called when a game finishes importing
    public var spotlightFinishedImportHandler: GameImporterFinishedImportingGameHandler?
    
    /// Singleton instance of GameImporter
    public static let shared: GameImporter = GameImporter(FileManager.default,
                                                          GameImporterFileService(),
                                                          GameImporterDatabaseService())
    
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
    public internal(set) var systemToPathMap = [String: URL]()
    /// Map of ROM extensions to their corresponding system identifiers
    public internal(set) var romExtensionToSystemsMap = [String: [String]]()
    
    // MARK: - Queue
    
    public var importStatus: String = ""
    
    public var importQueue: [ImportQueueItem] = []
    
    public var processingState: ProcessingState = .idle  // Observable state for processing status
    
    internal var gameImporterFileService:GameImporterFileServicing
    internal var gameImporterDatabaseService:GameImporterDatabaseServicing
    
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
    
    /// Bundle for this module
    fileprivate let ThisBundle: Bundle = Bundle.module
    /// Token for notifications
    fileprivate var notificationToken: NotificationToken?
    /// DispatchGroup for initialization
    public let initialized = DispatchGroup()
    
    internal let importCoordinator = ImportCoordinator()
    
    /// Initializes the GameImporter
    internal init(_ fm: FileManager,
                  _ fileService:GameImporterFileServicing,
                  _ databaseService:GameImporterDatabaseServicing) {
        gameImporterFileService = fileService
        gameImporterDatabaseService = databaseService
        
        //create defaults
        createDefaultDirectories(fm: fm)
        
        //set the romsPath propery of the db service, since it needs access
        gameImporterDatabaseService.setRomsPath(url: romsPath)
        gameImporterDatabaseService.setOpenVGDB(openVGDB)
        
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
                        ILOG("RealmCollection changed state to .initial")
                        self.systemToPathMap = await updateSystemToPathMap()
                        self.romExtensionToSystemsMap = updateromExtensionToSystemsMap()
                        self.initialized.leave()
                    }
                case .update:
                    Task.detached {
                        ILOG("RealmCollection changed state to .update")
                        self.systemToPathMap = await updateSystemToPathMap()
                        self.romExtensionToSystemsMap = updateromExtensionToSystemsMap()
                    }
                case let .error(error):
                    ELOG("RealmCollection changed state to .error")
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
    
    //MARK: Queue Management
    
    // Adds an ImportItem to the queue without starting processing
    public func addImport(_ item: ImportQueueItem) {
        addImportItemToQueue(item)
        
        startProcessing()
    }
    
    public func addImports(forPaths paths: [URL]) {
        paths.forEach({ (url) in
            addImportItemToQueue(ImportQueueItem(url: url, fileType: .unknown))
        })
        
        startProcessing()
    }

    // Public method to manually start processing if needed
    public func startProcessing() {
        // Only start processing if it's not already active
        guard processingState == .idle else { return }
        Task {
            await processQueue()
        }
    }

    // Processes each ImportItem in the queue sequentially
    private func processQueue() async {
        ILOG("GameImportQueue - processQueue beginning Import Processing")
        DispatchQueue.main.async {
            self.processingState = .processing
        }
        
        for item in importQueue where item.status == .queued {
            await processItem(item)
        }
        
        DispatchQueue.main.async {
            self.processingState = .idle  // Reset processing status when queue is fully processed
        }
        ILOG("GameImportQueue - processQueue complete Import Processing")
    }

    // Process a single ImportItem and update its status
    private func processItem(_ item: ImportQueueItem) async {
        ILOG("GameImportQueue - processing item in queue: \(item.url)")
        item.status = .processing
        updateImporterStatus("Importing \(item.url.lastPathComponent)")

        do {
            // Simulate file processing
            try await performImport(for: item)
            item.status = .success
            updateImporterStatus("Completed \(item.url.lastPathComponent)")
            ILOG("GameImportQueue - processing item in queue: \(item.url) completed.")
        } catch {
            ILOG("GameImportQueue - processing item in queue: \(item.url) caught error...")
            if error.localizedDescription.contains("Conflict") {
                item.status = .conflict
                updateImporterStatus("Conflict for \(item.url.lastPathComponent). User action needed.")
                WLOG("GameImportQueue - processing item in queue: \(item.url) restuled in conflict.")
            } else {
                item.status = .failure
                updateImporterStatus("Failed \(item.url.lastPathComponent) with error: \(error.localizedDescription)")
                ELOG("GameImportQueue - processing item in queue: \(item.url) restuled in error: \(error.localizedDescription)")
            }
        }
    }

    private func performImport(for item: ImportQueueItem) async throws {
        
        //detect type for updating UI and later processing
        if (try isBIOS(item)) { //this can throw
            item.fileType = .bios
        } else if (isCDROM(item)) {
            item.fileType = .cdRom
        } else if (isArtwork(item)) {
            item.fileType = .artwork
        } else {
            item.fileType = .game
        }
        
        var importedFiles: [URL] = []
        
        //get valid systems that this object might support
        guard let systems = try? await determineSystems(for: item), !systems.isEmpty else {
            //this is actually an import error
            item.status = .failure
            throw GameImporterError.noSystemMatched
        }
        
        //this might be a conflict if we can't infer what to do
        if item.systems.count > 1 {
            //conflict
            item.status = .conflict
            //start figuring out what to do, because this item is a conflict
            try await gameImporterFileService.moveToConflictsFolder(item, conflictsPath: conflictPath)
        }
        
        //move ImportQueueItem to appropriate file location
        try await gameImporterFileService.moveImportItem(toAppropriateSubfolder: item)
        
        //import the copied file into our database
        
        
//        do {
//            //try moving it to the correct location - we may clean this up later.
//            if let importedFile = try await importSingleFile(at: item.url) {
//                importedFiles.append(importedFile)
//            }
//            
//            //try importing the moved file[s] into the Roms DB
//            
//        } catch {
//            //TODO: what do i do here?
//            ELOG("Failed to import file at \(item.url): \(error.localizedDescription)")
//        }
        
//        await importedFiles.asyncForEach { path in
//            do {
//                try await self._handlePath(path: path, userChosenSystem: nil)
//            } catch {
//                //TODO: what do i do here?  I could just let this throw or try and process what happened...
//                ELOG("\(error)")
//            }
//        } // for each
        
        //external callers - might not be needed in the end
        self.completionHandler?(self.encounteredConflicts)
    }

    // General status update for GameImporter
    internal func updateImporterStatus(_ message: String) {
        DispatchQueue.main.async {
            self.importStatus = message
        }
    }
    
    private func addImportItemToQueue(_ item: ImportQueueItem) {
        let duplicate = importQueue.contains { existing in
            return (existing.url == item.url || existing.id == item.id) ? true : false
        }
        
        guard !duplicate else {
            WLOG("GameImportQueue - Trying to add duplicate ImportItem to import queue with url: \(item.url) and id: \(item.id)")
            return;
        }
        
        importQueue.append(item)
        ILOG("GameImportQueue - add ImportItem to import queue with url: \(item.url) and id: \(item.id)")
    }
}


