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
import PVSystems
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

    typealias ImportQueueItemType = ImportQueueItem

    func initSystems() async

    var importStatus: String { get }

    var importQueue: [ImportQueueItemType] { get }

    var processingState: ProcessingState { get }

    func addImport(_ item: ImportQueueItem)
    func addImports(forPaths paths: [URL])
    func addImports(forPaths paths: [URL], targetSystem: SystemIdentifier)

    func removeImports(at offsets: IndexSet)
    func startProcessing()

    func clearCompleted()

    func sortImportQueueItems(_ importQueueItems: [ImportQueueItemType]) -> [ImportQueueItemType]

    func importQueueContainsDuplicate(_ queue: [ImportQueueItemType], ofItem queueItem: ImportQueueItemType) -> Bool

    var importStartedHandler: GameImporterImportStartedHandler? { get set }
    /// Closure called when import completes
    var completionHandler: GameImporterCompletionHandler? { get set }
    /// Closure called when a game finishes importing
    var finishedImportHandler: GameImporterFinishedImportingGameHandler? { get set }
    /// Closure called when artwork finishes downloading
    var finishedArtworkHandler: GameImporterFinishedGettingArtworkHandler? { get set }

    /// Spotlight Handerls
    /// Closure called when spotlight completes
    var spotlightCompletionHandler: GameImporterCompletionHandler? { get set }
    /// Closure called when a game finishes importing
    var spotlightFinishedImportHandler: GameImporterFinishedImportingGameHandler? { get set }
}


//#if !os(tvOS)
//@Observable
//#else
@Perceptible
//#endif
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
                                                          GameImporterDatabaseService(),
                                                          GameImporterSystemsService(),
                                                          ArtworkImporter(),
                                                          DefaultCDFileHandler())

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
    // MARK: - Queue

    public var importStatus: String = ""

    var importAutoStartDelayTask: Task<Void, Never>?
    public var importQueue: [ImportQueueItem] = [] {
        didSet {
            // Schedule auto-start if there are queued items OR items with a user-chosen system
            if importQueue.contains(where: {
                $0.status == .queued || $0.userChosenSystem != nil
            }) {
                importAutoStartDelayTask?.cancel()
                importAutoStartDelayTask = Task {
                    await try? Task.sleep(for: .seconds(1))
                    self.startProcessing()
                }
            }
        }
    }

    public var processingState: ProcessingState = .idle  // Observable state for processing status

    internal var gameImporterFileService:GameImporterFileServicing
    internal var gameImporterDatabaseService:any GameImporterDatabaseServicing
    internal var gameImporterSystemsService:any GameImporterSystemsServicing
    internal var gameImporterArtworkImporter:any ArtworkImporting
    internal var cdRomFileHandler:CDFileHandling

    // MARK: - Paths

    /// Path to the documents directory
    public var documentsPath: URL { get { URL.documentsPath }}
    /// Path to the ROM import directory
    public var romsImportPath: URL { Paths.romsImportPath }
    /// Path to the ROMs directory
    public var romsPath: URL { get { Paths.romsPath }}
    /// Path to the BIOS directory
    public var biosPath: URL { get { Paths.biosesPath }}

    public var databaseService: any GameImporterDatabaseServicing {
        return gameImporterDatabaseService
    }

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
                  _ databaseService:GameImporterDatabaseServicing,
                  _ systemsService:GameImporterSystemsServicing,
                  _ artworkImporter:ArtworkImporting,
                  _ cdFileHandler:CDFileHandling) {
        gameImporterFileService = fileService
        gameImporterDatabaseService = databaseService
        gameImporterSystemsService = systemsService
        gameImporterArtworkImporter = artworkImporter
        cdRomFileHandler = cdFileHandler

        //create defaults
        createDefaultDirectories(fm: fm)

        //set service dependencies
        gameImporterDatabaseService.setRomsPath(url: romsPath)

        gameImporterArtworkImporter.setSystemsService(gameImporterSystemsService)
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
                        self.initialized.leave()
                    }
                case .update:
                    Task.detached {
                        ILOG("RealmCollection changed state to .update")
                        self.systemToPathMap = await updateSystemToPathMap()
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

    public func getArtwork(forGame game: PVGame) async -> PVGame {
        return await gameImporterDatabaseService.getArtwork(forGame: game)
    }

    /// Deinitializer
    deinit {
        notificationToken?.invalidate()
    }

    //MARK: Public Queue Management

    // Inside your GameImporter class
    private let importQueueLock = NSLock()

    // Adds an ImportItem to the queue without starting processing
    public func addImport(_ item: ImportQueueItem) {
        importQueueLock.lock()
        defer { importQueueLock.unlock() }

        self.addImportItemToQueue(item)
    }

    public func addImports(forPaths paths: [URL]) {
        importQueueLock.lock()
        defer { importQueueLock.unlock() }

        for path in paths {
            self.addImportItemToQueue(ImportQueueItem(url: path, fileType: .unknown))
        }
    }

    @MainActor
    public func addImports(forPaths paths: [URL], targetSystem: SystemIdentifier) {
        importQueueLock.lock()
        defer { importQueueLock.unlock() }

        for path in paths {
            var item = ImportQueueItem(url: path, fileType: .unknown)
            item.userChosenSystem = targetSystem
            self.addImportItemToQueue(item)
        }
    }

    public func removeImports(at offsets: IndexSet) {
        importQueueLock.lock()
        defer { importQueueLock.unlock() }

        for index in offsets {
            let item = importQueue[index]

            // Try to delete the associated file
            do {
                try gameImporterFileService.removeImportItemFile(item)
            } catch {
                ELOG("removeImports - Failed to delete file at \(item.url): \(error)")
            }
        }

        importQueue.remove(atOffsets: offsets)
    }

    // Public method to manually start processing if needed
    public func startProcessing() {
        // Only start processing if it's not already active
        guard processingState == .idle else { return }
        self.processingState = .processing
        Task { @MainActor in
            await preProcessQueue()
            await processQueue()
        }
    }

    //MARK: Processing functions
    @MainActor
    private func preProcessQueue() async {
        importQueueLock.lock()
        defer { importQueueLock.unlock() }

        //determine the type for all items in the queue
        for importItem in self.importQueue {
            //ideally this wouldn't be needed here
            do {
                importItem.fileType = try determineImportType(importItem)
            } catch {
                ELOG("Caught error trying to assign file type \(error.localizedDescription)")
                //caught an error trying to assign file type
            }

        }

        //sort the queue to make sure m3us go first
        importQueue = sortImportQueueItems(importQueue)

        //thirdly, we need to parse the queue and find any children for cue files
        organizeCueAndBinFiles(in: &importQueue)

        //lastly, move and cue (and child bin) files under the parent m3u (if they exist)
        organizeM3UFiles(in: &importQueue)
    }

    public func clearCompleted() {
        self.importQueue = self.importQueue.filter({
            switch $0.status {
            case .success: return false
            default: return true
            }
        })
    }

    internal func organizeM3UFiles(in importQueue: inout [ImportQueueItem]) {

        for m3uitem in importQueue where m3uitem.url.pathExtension.lowercased() == "m3u" {
            let baseFileName = m3uitem.url.deletingPathExtension().lastPathComponent

            do {
                let files = try cdRomFileHandler.readM3UFileContents(from: m3uitem.url)

                // Move all referenced files
                for filename in files {
                    if let cueIndex = importQueue.firstIndex(where: { item in
                        item.url.lastPathComponent == filename
                    }) {
                        // Remove the .bin item from the queue and add it as a child of the .cue item
                        let cueItem = importQueue[cueIndex]
                        cueItem.fileType = .cdRom

                        if (cueItem.status == .partial) {
                            m3uitem.status = .partial
                        } else {
                            //cue item is ready, re-parent
                            importQueue.remove(at: cueIndex)
                            m3uitem.childQueueItems.append(cueItem)
                        }
                    } else if let _ = m3uitem.childQueueItems.firstIndex(where: { item in
                        item.url.lastPathComponent == filename
                    }) {
                        //nothing to do, the target .cue is already a child of this m3u item
                        ILOG("M3U File already has - \(baseFileName) as a child of this import item.")
                    } else {
                        WLOG("M3U File is missing 1 or more cue items, marking as partial - \(baseFileName)")
                        m3uitem.status = .partial
                    }
                }

                if (m3uitem.childQueueItems.count != files.count) {
                    m3uitem.status = .partial
                } else {
                    m3uitem.status = .queued
                    m3uitem.status = m3uitem.getStatusForItem()
                }
            } catch {
                ELOG("Caught an error looking for a corresponding .cues to \(baseFileName) - probably bad things happening")
                m3uitem.status = .partial
            }
        }
    }

    // Function to process ImportQueueItems and associate .bin files with corresponding .cue files
    internal func organizeCueAndBinFiles(in importQueue: inout [ImportQueueItem]) {
        // Loop through a copy of the queue to avoid mutation issues while iterating
        for cueItem in importQueue where cueItem.url.pathExtension.lowercased() == "cue" {
            // Extract the base name of the .cue file (without extension)
            let baseFileName = cueItem.url.deletingPathExtension().lastPathComponent

            do {
                let candidateBinFileNames = try cdRomFileHandler.findAssociatedBinFileNames(for: cueItem)
                if !candidateBinFileNames.isEmpty {
                    let cueDirectory = cueItem.url.deletingLastPathComponent()
                    let candidateBinUrls = cdRomFileHandler.candidateBinUrls(for: candidateBinFileNames, in: [cueDirectory, conflictPath])
                    for candidateBinUrl in candidateBinUrls {
                        // Find any .bin item in the queue that matches the .cue base file name
                        if let binIndex = importQueue.firstIndex(where: { item in
                            item.url == candidateBinUrl
                        }) {
                            let binItem = importQueue[binIndex]
                            // Check if the .bin file exists and add to the array if it does
                            if cdRomFileHandler.fileExistsAtPath(binItem.url) {
                                DLOG("Located corresponding .bin for cue \(baseFileName) - re-parenting queue item")
                                // Remove the .bin item from the queue and add it as a child of the .cue item
                                let binItem = importQueue.remove(at: binIndex)
                                binItem.fileType = .cdRom
                                cueItem.childQueueItems.append(binItem)
                            } else {
                                WLOG("Located the corresponding bin item for \(baseFileName) - but corresponding bin file not detected.  Set status to .partial")
                                cueItem.status = .partial
                            }
                        } else {
                            WLOG("Located the corresponding bin[s] for \(baseFileName) - but no corresponding QueueItem detected.  Consider creating one here?")
                            cueItem.status = .partial
                        }
                    }

                    if (candidateBinFileNames.count != cueItem.childQueueItems.count) {
                        WLOG("Cue File is missing 1 or more bin urls, marking as not ready - \(baseFileName)")
                        cueItem.status = .partial
                    } else {
                        cueItem.status = .queued
                    }
                } else {
                    //this is probably some kind of error...
                    ELOG("Found a .cue \(baseFileName) without a .bin - probably file system didn't settle yet")
                    cueItem.status = .partial
                }
            } catch {
                ELOG("Caught an error looking for a corresponding .bin to \(baseFileName) - probably bad things happening - \(error.localizedDescription)")
            }
        }
    }

    internal func cmpSpecialExt(obj1Extension: String, obj2Extension: String) -> Bool {
        // Ensure .m3u files are sorted first
        if obj1Extension == Extensions.m3u.rawValue && obj2Extension != Extensions.m3u.rawValue {
            return true
        } else if obj2Extension == Extensions.m3u.rawValue && obj1Extension != Extensions.m3u.rawValue {
            return false
        }

        // Ensure .cue files are sorted second (after .m3u)
        if obj1Extension == Extensions.cue.rawValue && obj2Extension != Extensions.m3u.rawValue && obj2Extension != Extensions.cue.rawValue {
            return true
        } else if obj2Extension == Extensions.cue.rawValue && obj1Extension != Extensions.m3u.rawValue && obj1Extension != Extensions.cue.rawValue {
            return false
        }

        // Sort artwork extensions last
        let isObj1Artwork = Extensions.artworkExtensions.contains(obj1Extension)
        let isObj2Artwork = Extensions.artworkExtensions.contains(obj2Extension)

        if isObj1Artwork && !isObj2Artwork {
            return false
        } else if isObj2Artwork && !isObj1Artwork {
            return true
        }

        // Default alphanumeric sorting for non-artwork and intra-artwork sorting
        return obj1Extension > obj2Extension
    }


    internal func cmp(obj1: ImportQueueItem, obj2: ImportQueueItem) -> Bool {
        let url1 = obj1.url
        let url2 = obj2.url
        let obj1Filename = url1.lastPathComponent
        let obj2Filename = url2.lastPathComponent
        let obj1Extension = url1.pathExtension.lowercased()
        let obj2Extension = url2.pathExtension.lowercased()
        let name1=PVEmulatorConfiguration.stripDiscNames(fromFilename: obj1Filename)
        let name2=PVEmulatorConfiguration.stripDiscNames(fromFilename: obj2Filename)
        if name1 == name2 {
             // Standard sort
            if obj1Extension == obj2Extension {
                return obj1Filename < obj2Filename
            }
            return obj1Extension > obj2Extension
        } else {
            return name1 < name2
        }
    }

    public func sortImportQueueItems(_ importQueueItems: [ImportQueueItem]) -> [ImportQueueItem] {
        VLOG("sortImportQueueItems...begin")
        VLOG(importQueueItems.map { $0.url.lastPathComponent }.joined(separator: ", "))

        var ext:[String:[ImportQueueItem]] = [:]
        // separate array by file extension
        importQueueItems.forEach({ (queueItem) in
            let fileExt = queueItem.url.pathExtension.lowercased()
            if var itemsWithExtension = ext[fileExt] {
                itemsWithExtension.append(queueItem)
                ext[fileExt]=itemsWithExtension
            } else {
                ext[fileExt]=[queueItem]
            }
        })
        // sort
        var sorted: [ImportQueueItem] = []
        ext.keys
            .sorted(by: cmpSpecialExt)
            .forEach {
            if let values = ext[$0] {
                let values = values.sorted { (obj1, obj2) -> Bool in
                    return cmp(obj1: obj1, obj2: obj2)
                }
                sorted.append(contentsOf: values)
                ext[$0] = values
            }
        }
        VLOG(sorted.map { $0.url.lastPathComponent }.joined(separator: ", "))
        VLOG("sortImportQueueItems...end")
        return sorted
    }

    // Processes each ImportItem in the queue sequentially
    @MainActor
    private func processQueue() async {
        // Check for items that are either queued or have a user-chosen system
        let itemsToProcess = importQueue.filter {
            $0.status == .queued || $0.userChosenSystem != nil
        }

        guard !itemsToProcess.isEmpty else {
            DispatchQueue.main.async {
                self.processingState = .idle
            }
            return
        }

        ILOG("GameImportQueue - processQueue beginning Import Processing")
        DispatchQueue.main.async {
            self.processingState = .processing
        }

        for item in itemsToProcess {
            // If there's a user-chosen system, ensure the item is queued
            if item.userChosenSystem != nil {
                item.status = .queued
            }
            await processItem(item)
        }

        DispatchQueue.main.async {
            self.processingState = .idle
        }
        ILOG("GameImportQueue - processQueue complete Import Processing")
    }

    // Process a single ImportItem and update its status
    @MainActor
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
        } catch let error as GameImporterError {
            switch error {
            case .conflictDetected:
                item.status = .conflict
                updateImporterStatus("Conflict for \(item.url.lastPathComponent). User action needed.")
                WLOG("GameImportQueue - processing item in queue: \(item.url) restuled in conflict.")
            default:
                item.status = .failure
                item.errorValue = error.localizedDescription
                updateImporterStatus("Failed \(item.url.lastPathComponent) with error: \(error.localizedDescription)")
                ELOG("GameImportQueue - processing item in queue: \(item.url) restuled in error: \(error.localizedDescription)")
            }
        } catch {
            ILOG("GameImportQueue - processing item in queue: \(item.url) caught error... \(error.localizedDescription)")
            item.status = .failure
            updateImporterStatus("Failed \(item.url.lastPathComponent) with error: \(error.localizedDescription)")
            ELOG("GameImportQueue - processing item in queue: \(item.url) restuled in error: \(error.localizedDescription)")
        }
    }

    private func determineImportType(_ item: ImportQueueItem) throws -> FileType {
        //detect type for updating UI and later processing
        if (try isBIOS(item)) { //this can throw
            return .bios
        } else if (isCDROM(item)) {
            return .cdRom
        } else if (isArtwork(item)) {
            return .artwork
        } else {
            return .game
        }
    }

    @MainActor
    private func performImport(for item: ImportQueueItem) async throws {
        ILOG("Starting import for file: \(item.url.lastPathComponent)")

        //ideally this wouldn't be needed here because we'd have done it elsewhere
        item.fileType = try determineImportType(item)
        ILOG("Determined file type: \(item.fileType)")

        // Handle BIOS files first, before any system detection
        if item.fileType == .bios {
            ILOG("Processing as BIOS file")
            do {
                try await gameImporterDatabaseService.importBIOSIntoDatabase(queueItem: item)
                ILOG("Successfully imported BIOS file")
                item.status = .success
                return
            } catch {
                ELOG("Failed to import BIOS file: \(error)")
                throw error
            }
        }

        if item.fileType == .artwork {
            //TODO: what do i do with the PVGame result here?
            if let _ = await gameImporterArtworkImporter.importArtworkItem(item) {
                item.status = .success
            } else {
                item.status = .failure
            }
            return
        }

        // Only do system detection for non-BIOS files
        guard let systems: [SystemIdentifier] = try? await gameImporterSystemsService.determineSystems(for: item), !systems.isEmpty else {
            //this is actually an import error
            item.status = .failure
            ELOG("No system matched for this Import Item: \(item.url.lastPathComponent)")
            throw GameImporterError.noSystemMatched
        }

        //update item's candidate systems with the result of determineSystems
        item.systems = systems

        //this might be a conflict if we can't infer what to do
        //for BIOS, we can handle multiple systems, so allow that to proceed
        if item.fileType != .bios && item.targetSystem() == nil {
            //conflict
            item.status = .conflict
            //start figuring out what to do, because this item is a conflict
//            try await gameImporterFileService.moveToConflictsFolder(item, conflictsPath: conflictPath)
            throw GameImporterError.conflictDetected
        }

        //move ImportQueueItem to appropriate file location
        try await gameImporterFileService.moveImportItem(toAppropriateSubfolder: item)

        if (item.fileType == .bios) {
            try await gameImporterDatabaseService.importBIOSIntoDatabase(queueItem: item)
        } else {
            //import the copied file into our database
            try await gameImporterDatabaseService.importGameIntoDatabase(queueItem: item)
        }

        //if everything went well and no exceptions, we're clear to indicate a successful import

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
//        self.completionHandler?(self.encounteredConflicts)
    }

    // General status update for GameImporter
    internal func updateImporterStatus(_ message: String) {
        DispatchQueue.main.async {
            self.importStatus = message
        }
    }

    /// Checks the queue and all child elements in the queue to see if this file exists.  if it does, return true, else return false.
    /// Duplicates are considered if the filename, id, or md5 matches
    public func importQueueContainsDuplicate(_ queue: [ImportQueueItem], ofItem queueItem: ImportQueueItem) -> Bool {
        let duplicate = queue.contains { existing in
            if (existing.url.lastPathComponent.lowercased() == queueItem.url.lastPathComponent.lowercased()
                || existing.id == queueItem.id)
            {
                return true
            }

            if let eMd5 = existing.md5?.uppercased(),
                let newMd5 = queueItem.md5?.uppercased(),
                eMd5 == newMd5
            {
                return true
            }

            if (!existing.childQueueItems.isEmpty) {
                //check the child queue items for duplicates
                return self.importQueueContainsDuplicate(existing.childQueueItems, ofItem: queueItem)
            }
            // DLOG("Duplicate Queue Item not detected for \(existing.url.lastPathComponent.lowercased()) - compared with \(queueItem.url.lastPathComponent.lowercased())")
            return false
        }

        return duplicate
    }

    private func addImportItemToQueue(_ item: ImportQueueItem) {
        guard !importQueueContainsDuplicate(self.importQueue, ofItem: item) else {
            WLOG("GameImportQueue - Trying to add duplicate ImportItem to import queue with url: \(item.url) and id: \(item.id)")
            return;
        }

        importQueue.append(item)
        ILOG("GameImportQueue - add ImportItem to import queue with url: \(item.url) and id: \(item.id)")
    }
}
