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
import Combine

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public class SkinImporterInjector: SkinImporterServicing {
    public static let shared = SkinImporterInjector()
    private init() {}
    
    public var service: (any SkinImporterServicing)?
    
    public func importSkin(from url: URL) async throws {
//        if url.startAccessingSecurityScopedResource() {
        try await service?.importSkin(from: url)
        if url.path(percentEncoded: false).contains("Imports") {
            Task {
                try await FileManager.default.removeItem(at: url)
            }
        }
    }
}

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

/// Actor for managing the import queue with thread safety
public actor ImportQueueActor {
    /// Subject to publish queue changes
    let queueSubject = CurrentValueSubject<[ImportQueueItem], Never>([])    
    
    /// The current queue of import items
    private(set) var queue: [ImportQueueItem] = [] {
        didSet {
            // Schedule auto-start if there are queued items OR items with a user-chosen system
            if queue.contains(where: {
                $0.status == .queued || $0.userChosenSystem != nil
            }) {
                autoStartCallback()
            }
            
            // Update the published queue on the main thread
            Task { @MainActor in
                // Send the updated queue to the subject
                await queueSubject.send(queue)
                
                // Call the queue update handler to notify subscribers (for backward compatibility)
                await queueUpdateHandler?(queue)
            }
        }
    }
    
    // Callback that will be invoked when the queue changes
    private var queueUpdateHandler: (([ImportQueueItem]) -> Void)?
    
    /// Sets the queue update handler from outside the actor
    func setQueueUpdateHandler(_ handler: @escaping ([ImportQueueItem]) -> Void) {
        self.queueUpdateHandler = handler
    }
    
    private var autoStartCallback: () -> Void
    
    init(autoStartCallback: @escaping () -> Void) {
        self.autoStartCallback = autoStartCallback
    }
    
    /// Updates the auto-start callback function
    /// This is used to avoid circular references during initialization
    func setAutoStartCallback(_ callback: @escaping () -> Void) {
        self.autoStartCallback = callback
    }
    
    func getQueue() -> [ImportQueueItem] {
        return queue
    }
    
    func addImport(_ item: ImportQueueItem) {
        queue.append(item)
    }
    
    func addImports(_ items: [ImportQueueItem]) {
        queue.append(contentsOf: items)
    }
    
    func removeImports(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
    }
    
    func clearCompleted() {
        queue = queue.filter({
            switch $0.status {
            case .success: return false
            default: return true
            }
        })
    }
    
    func updateQueue(_ newQueue: [ImportQueueItem]) {
        queue = newQueue
    }
    
    func getItem(at index: Int) -> ImportQueueItem? {
        guard index < queue.count else { return nil }
        return queue[index]
    }
    
    func containsDuplicate(ofItem queueItem: ImportQueueItem, comparator: (ImportQueueItem, ImportQueueItem) -> Bool) -> Bool {
        return queue.contains(where: { comparator($0, queueItem) })
    }
    
    func organizeCueAndBinFiles() {
        var updatedQueue = queue
        for cueIndex in updatedQueue.indices.reversed() where updatedQueue[cueIndex].url.pathExtension.lowercased() == "cue" {
            let cueItem = updatedQueue[cueIndex]
            let cueFilename = cueItem.url.lastPathComponent
            
            if let cueContents = try? String(contentsOf: cueItem.url) {
                let cueLines = cueContents.components(separatedBy: .newlines)
                
                for line in cueLines where line.contains("FILE") && line.contains("BINARY") {
                    if let binFilename = extractBinFilename(from: line) {
                        if let binIndex = updatedQueue.firstIndex(where: { item in
                            item.url.lastPathComponent.lowercased() == binFilename.lowercased()
                        }) {
                            let binItem = updatedQueue[binIndex]
                            cueItem.childQueueItems.append(binItem)
                            updatedQueue.remove(at: binIndex)
                        }
                    }
                }
            }
        }
        queue = updatedQueue
    }
    
    func organizeM3UFiles() {
        var updatedQueue = queue
        for m3uIndex in updatedQueue.indices.reversed() where updatedQueue[m3uIndex].url.pathExtension.lowercased() == "m3u" {
            let m3uItem = updatedQueue[m3uIndex]
            let baseFileName = m3uItem.url.deletingPathExtension().lastPathComponent
            
            if let m3uContents = try? String(contentsOf: m3uItem.url) {
                let m3uLines = m3uContents.components(separatedBy: .newlines)
                
                for line in m3uLines where !line.isEmpty && !line.hasPrefix("#") {
                    let cueFilename = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let cueIndex = updatedQueue.firstIndex(where: { item in
                        item.url.lastPathComponent.lowercased() == cueFilename.lowercased()
                    }) {
                        let cueItem = updatedQueue[cueIndex]
                        m3uItem.childQueueItems.append(cueItem)
                        updatedQueue.remove(at: cueIndex)
                    }
                }
            }
        }
        queue = updatedQueue
    }
    
    private func extractBinFilename(from line: String) -> String? {
        let components = line.components(separatedBy: "\"")
        guard components.count >= 3 else { return nil }
        return components[1]
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

public enum ProcessingState {
    case idle
    case processing
    case paused
}

public protocol GameImporting {

    typealias ImportQueueItemType = ImportQueueItem

    func initSystems() async

    var importStatus: String { get }

    var importQueue: [ImportQueueItemType] { get async }
    
    /// Publisher that emits the current import queue whenever it changes
    var importQueuePublisher: AnyPublisher<[ImportQueueItemType], Never> { get }

    var processingState: ProcessingState { get }

    func addImport(_ item: ImportQueueItem) async
    func addImports(forPaths paths: [URL]) async
    func addImports(forPaths paths: [URL], targetSystem: SystemIdentifier) async

    func removeImports(at offsets: IndexSet)  async
    func startProcessing()

    /// Pauses the import processing
    /// Items can still be added to or removed from the queue while paused
    func pause()

    /// Resumes the import processing if it was paused
    func resume()

    func clearCompleted() async

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
//#els
@Perceptible
//#endif
public final class GameImporter: GameImporting, ObservableObject {
    
    /// Publisher that emits the current import queue whenever it changes
    public var importQueuePublisher: AnyPublisher<[ImportQueueItemType], Never> {
        // Create a publisher that connects to the queue actor's subject
        return importQueueSubject.eraseToAnyPublisher()
    }
    
    /// Subject that publishes import queue updates
    private let importQueueSubject = CurrentValueSubject<[ImportQueueItemType], Never>([]) 

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
                                                          DefaultCDFileHandler(),
                                                          SkinImporterInjector.shared
        )

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
    
    // Actor to manage the import queue with thread safety
    public let importQueueActor: ImportQueueActor
    
    // Public computed property to access the import queue
    public var importQueue: [ImportQueueItem] {
        get async {
            await importQueueActor.getQueue()
        }
    }

    public var processingState: ProcessingState = .idle  // Observable state for processing status

    internal var gameImporterFileService:GameImporterFileServicing
    internal var gameImporterDatabaseService:any GameImporterDatabaseServicing
    internal var gameImporterSystemsService:any GameImporterSystemsServicing
    internal var gameImporterArtworkImporter:any ArtworkImporting
    internal var cdRomFileHandler:CDFileHandling
    internal var skinImporterService: any SkinImporterServicing

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
                  _ cdFileHandler:CDFileHandling,
                  _ skinImporterService: SkinImporterServicing) {
        // Create a local function for the auto-start callback that doesn't capture self
        // This avoids the circular reference issue
        func autoStartCallback() {
            // We'll set up the actual implementation after initialization
        }
        
        // Initialize the import queue actor with the placeholder callback
        self.importQueueActor = ImportQueueActor(autoStartCallback: autoStartCallback)
        
        self.skinImporterService = skinImporterService
        self.gameImporterFileService = fileService
        self.gameImporterDatabaseService = databaseService
        self.gameImporterSystemsService = systemsService
        self.gameImporterArtworkImporter = artworkImporter
        self.cdRomFileHandler = cdFileHandler
        
        // Set up the queue update handler for logging purposes
        Task {
            // Use the proper method to set the queue update handler
            await importQueueActor.setQueueUpdateHandler { queue in
                Task { @MainActor in
                    // Log queue updates
                    VLOG("GameImporter: Import queue updated with \(queue.count) items")
                }
            }
        }

        //create defaults
        createDefaultDirectories(fm: fm)

        //set service dependencies
        gameImporterDatabaseService.setRomsPath(url: romsPath)

        gameImporterArtworkImporter.setSystemsService(gameImporterSystemsService)
        
        // Now set up the actual auto-start callback implementation
        Task {
            await importQueueActor.setAutoStartCallback { [weak self] in
                guard let self = self else { return }
                self.importAutoStartDelayTask?.cancel()
                self.importAutoStartDelayTask = Task.detached {
                    await try? Task.sleep(for: .seconds(1))
                    self.startProcessing()
                }
            }
        }
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
                        
                        // Set up the queue subscription after all members are initialized
                        self.setupQueueSubscription()
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
    
    /// Sets up the subscription to the import queue actor's queue subject
    /// This must be called after all members are initialized
    private func setupQueueSubscription() {
        ILOG("GameImporter: Setting up queue subscription")
        
        // Set up a task to connect the ImportQueueActor's queueSubject to our importQueueSubject
        Task {
            do {
                // Create a continuous stream from the actor's subject
                for await queue in await self.importQueueActor.queueSubject.values {
                    // Update our subject on the main thread
                    await MainActor.run {
                        self.importQueueSubject.send(queue)
                    }
                }
            } catch {
                ELOG("GameImporter: Error in queue subscription - \(error)")
            }
        }
    }

    /// Initializes core plists
    fileprivate func initCorePlists() async {
        let bundle = ThisBundle
        await PVEmulatorConfiguration.updateSystems(fromPlists: [bundle.url(forResource: "systems", withExtension: "plist")!])
        let corePlists: [EmulatorCoreInfoPlist]  = CoreLoader.getCorePlists()
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

    // Adds an ImportItem to the queue without starting processing
    public func addImport(_ item: ImportQueueItem) async {
        await self.addImportItemToQueue(item)
    }

    public func addImports(forPaths paths: [URL]) async {
        for path in paths {
            await self.addImportItemToQueue(ImportQueueItem(url: path, fileType: .unknown))
        }
    }

    public func addImports(forPaths paths: [URL], targetSystem: SystemIdentifier) async {
        for path in paths {
            var item = ImportQueueItem(url: path, fileType: .unknown)
            item.userChosenSystem = targetSystem
            await self.addImportItemToQueue(item)
        }
    }

    public func removeImports(at offsets: IndexSet) async {
        // Get items to remove
        var itemsToRemove: [ImportQueueItem] = []
        for index in offsets {
            if let item = await importQueueActor.getItem(at: index) {
                itemsToRemove.append(item)
            }
        }
        
        // Remove files
        for item in itemsToRemove {
            do {
                try gameImporterFileService.removeImportItemFile(item)
            } catch {
                ELOG("removeImports - Failed to delete file at \(item.url): \(error)")
            }
        }

        // Remove from queue
        await importQueueActor.removeImports(at: offsets)
    }

    // Public method to manually start processing if needed
    public func startProcessing() {
        // Only start processing if it's idle (not processing or paused)
        guard processingState == .idle else {
            // If we're paused, resume processing
            if processingState == .paused {
                resume()
            }
            return
        }

        self.processingState = .processing
        Task.detached { [self] in
            await preProcessQueue()
            await processQueue()
        }
    }

    // MARK: Processing functions
//    @MainActor
    private func preProcessQueue() async {
        // Get the current queue
        let currentQueue = await importQueueActor.getQueue()
        
        // Process each item to determine its type
        var processedQueue = currentQueue
        for i in 0..<processedQueue.count {
            do {
                processedQueue[i].fileType = try determineImportType(processedQueue[i])
            } catch {
                ELOG("Caught error trying to assign file type \(error.localizedDescription)")
            }
        }
        
        // Sort the queue to make sure m3us go first
        processedQueue = sortImportQueueItems(processedQueue)
        
        // Update the queue with processed items
        await importQueueActor.updateQueue(processedQueue)
        
        // Organize cue/bin files and m3u files
        await importQueueActor.organizeCueAndBinFiles()
        await importQueueActor.organizeM3UFiles()
    }

    public func clearCompleted() async {
        await importQueueActor.clearCompleted()
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

    // Processes items in the queue in parallel with controlled concurrency
    private func processQueue() async {
        // Check for items that are either queued or have a user-chosen system
        let itemsToProcess = await importQueue.filter {
            $0.status == .queued || $0.userChosenSystem != nil
        }
        
        guard !itemsToProcess.isEmpty else {
            DispatchQueue.main.async {
                // Only change to idle if we're not paused
                if self.processingState != .paused {
                    self.processingState = .idle
                }
            }
            return
        }
        
        ILOG("GameImportQueue - processQueue beginning Import Processing with \(itemsToProcess.count) items")
        
        // Only update to processing if we're not paused
        if processingState != .paused {
            DispatchQueue.main.async {
                self.processingState = .processing
            }
        }
        
        // Group related files that should be processed together
        let groupedItems = groupRelatedFiles(itemsToProcess)
        ILOG("Grouped \(itemsToProcess.count) items into \(groupedItems.count) processing groups")
        
        // Maximum number of concurrent imports
        let maxConcurrentImports = 4
        
        // Process groups in parallel with controlled concurrency
        await withTaskGroup(of: Void.self) { group in
            var activeTaskCount = 0
            
            for fileGroup in groupedItems {
                // Check if we've been paused before adding each group
                if await checkIfPaused() {
                    ILOG("GameImportQueue - processing paused, waiting for resume")
                    break
                }
                
                // Wait until we have capacity for more tasks
                while activeTaskCount >= maxConcurrentImports {
                    // Wait for a task to complete
                    await group.next()
                    activeTaskCount -= 1
                }
                
                // Add a new task for this group
                group.addTask {
                    for item in fileGroup {
                        // If there's a user-chosen system, ensure the item is queued
                        if item.userChosenSystem != nil {
                            item.status = .queued
                        }
                        await self.processItem(item)
                    }
                }
                
                activeTaskCount += 1
            }
            
            // Wait for all remaining tasks to complete
            await group.waitForAll()
        }
        
        DispatchQueue.main.async {
            // Only change to idle if we're not paused
            if self.processingState != .paused {
                self.processingState = .idle
            }
        }
        ILOG("GameImportQueue - processQueue complete Import Processing")
    }

    // Process a single ImportItem and update its status
    public func processItem(_ item: ImportQueueItem) async {
        ILOG("GameImportQueue - processing item in queue: \(item.url)")
        Task { @MainActor in
            item.status = .processing
        }
        updateImporterStatus("Importing \(item.url.lastPathComponent)")

        do {
            // Simulate file processing
            try await performImport(for: item)
            Task { @MainActor in
                item.status = .success
            }
            updateImporterStatus("Completed \(item.url.lastPathComponent)")
            ILOG("GameImportQueue - processing item in queue: \(item.url) completed.")
        } catch let error as GameImporterError {
            switch error {
            case .conflictDetected:
                Task { @MainActor in
                    item.status = .conflict
                }
                updateImporterStatus("Conflict for \(item.url.lastPathComponent). User action needed.")
                WLOG("GameImportQueue - processing item in queue: \(item.url) restuled in conflict.")
            default:
                Task { @MainActor in
                    item.status = .failure
                    item.errorValue = error.localizedDescription
                }
                updateImporterStatus("Failed \(item.url.lastPathComponent) with error: \(error.localizedDescription)")
                ELOG("GameImportQueue - processing item in queue: \(item.url) restuled in error: \(error.localizedDescription)")
            }
        } catch {
            ILOG("GameImportQueue - processing item in queue: \(item.url) caught error... \(error.localizedDescription)")
            Task { @MainActor in
                item.status = .failure
            }
            updateImporterStatus("Failed \(item.url.lastPathComponent) with error: \(error.localizedDescription)")
            ELOG("GameImportQueue - processing item in queue: \(item.url) restuled in error: \(error.localizedDescription)")
        }
    }

    private func determineImportType(_ item: ImportQueueItem) -> ImportQueueItem.FileType {
        //detect type for updating UI and later processing
        if (isSkin(item)) { return .skin }
        else if (isArtwork(item)) { return .artwork }
        else if (isBIOS(item)) { return .bios }
        else if (isCDROM(item)) { return .cdRom }
        else { return .game }
    }
    
    /// Groups related files that should be processed together
    /// - Parameter items: The items to group
    /// - Returns: An array of item groups, where each group contains related files
    private func groupRelatedFiles(_ items: [ImportQueueItem]) -> [[ImportQueueItem]] {
        var result: [[ImportQueueItem]] = []
        var processedItems = Set<String>()
        
        // First pass: group CD-ROM related files (cue/bin pairs)
        for item in items {
            let itemPath = item.url.path
            
            // Skip if already processed
            if processedItems.contains(itemPath) {
                continue
            }
            
            // If it's a cue file, find related bin files
            if item.url.pathExtension.lowercased() == "cue" {
                var group = [item]
                let baseName = item.url.deletingPathExtension().lastPathComponent
                
                // Find related bin files
                for binItem in items where binItem.url.pathExtension.lowercased() == "bin" {
                    let binBaseName = binItem.url.deletingPathExtension().lastPathComponent
                    if binBaseName.contains(baseName) || baseName.contains(binBaseName) {
                        group.append(binItem)
                        processedItems.insert(binItem.url.path)
                    }
                }
                
                result.append(group)
                processedItems.insert(itemPath)
            }
            // If it's an m3u file, find related files
            else if item.url.pathExtension.lowercased() == "m3u" {
                var group = [item]
                
                // Try to read the m3u file to find referenced files
                if let content = try? String(contentsOf: item.url) {
                    let lines = content.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty && !line.hasPrefix("#") {
                        // Find the referenced file in our items list
                        for refItem in items {
                            if refItem.url.lastPathComponent == line || refItem.url.path.hasSuffix("/\(line)") {
                                group.append(refItem)
                                processedItems.insert(refItem.url.path)
                            }
                        }
                    }
                }
                
                result.append(group)
                processedItems.insert(itemPath)
            }
        }
        
        // Second pass: add remaining items as individual groups
        for item in items {
            if !processedItems.contains(item.url.path) {
                result.append([item])
                processedItems.insert(item.url.path)
            }
        }
        
        return result
    }

//    @MainActor
    private func performImport(for item: ImportQueueItem) async throws {
        ILOG("Starting import for file: \(item.url.lastPathComponent)")

        //ideally this wouldn't be needed here because we'd have done it elsewhere
        item.fileType = try determineImportType(item)
        ILOG("Determined file type: \(item.fileType)")
        
        if item.fileType == .skin {
            ILOG("Processing as Skin file")
            do {
                try await skinImporterService.importSkin(from: item.url)
                //try await gameImporterDatabaseService.importBIOSIntoDatabase(queueItem: item)
                ILOG("Successfully imported BIOS file")
                Task { @MainActor in
                    item.status = .success
                }
                return
            } catch {
                ELOG("Failed to import BIOS file: \(error)")
                throw error
            }
        }

        // Handle BIOS files first, before any system detection
        if item.fileType == .bios {
            ILOG("Processing as BIOS file")
            do {
                try await gameImporterDatabaseService.importBIOSIntoDatabase(queueItem: item)
                ILOG("Successfully imported BIOS file")
                Task { @MainActor in
                    item.status = .success
                }
                return
            } catch {
                ELOG("Failed to import BIOS file: \(error)")
                throw error
            }
        }

        if item.fileType == .artwork {
            //TODO: what do i do with the PVGame result here?
            if let _ = await gameImporterArtworkImporter.importArtworkItem(item) {
                Task { @MainActor in
                    item.status = .success
                }
            } else {
                Task { @MainActor in
                    item.status = .failure
                }
            }
            return
        }

        // Only do system detection for non-BIOS files
        guard let systems: [SystemIdentifier] = try? await gameImporterSystemsService.determineSystems(for: item), !systems.isEmpty else {
            //this is actually an import error
            item.status = .failure
            ELOG("No system matched for this Import Item: \(item.url.lastPathComponent)")
            
            // Delete the file if it exists and is in the imports directory
            if item.url.path.contains("/Imports/") && FileManager.default.fileExists(atPath: item.url.path) {
                do {
                    try await FileManager.default.removeItem(at: item.url)
                    ILOG("Deleted file with no matching system: \(item.url.path)")
                } catch {
                    ELOG("Failed to delete file with no matching system: \(error.localizedDescription)")
                }
            }
            
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

    private func addImportItemToQueue(_ item: ImportQueueItem) async {
        // Check for duplicates using the actor
        let isDuplicate = await importQueueActor.containsDuplicate(ofItem: item) { existing, newItem in
            // Check if the URL is the same
            if existing.url == newItem.url {
                return true
            }
            
            // Check if the filename is the same and in the same directory
            if existing.url.lastPathComponent == newItem.url.lastPathComponent &&
               existing.url.deletingLastPathComponent() == newItem.url.deletingLastPathComponent() {
                return true
            }
            
            // Check MD5 if available
            if let existingMd5 = existing.md5?.uppercased(),
               let newMd5 = newItem.md5?.uppercased(),
               existingMd5 == newMd5 {
                return true
            }
            
            // Recursively check child items
            if !existing.childQueueItems.isEmpty {
                return self.importQueueContainsDuplicate(existing.childQueueItems, ofItem: newItem)
            }
            
            return false
        }
        
        guard !isDuplicate else {
            WLOG("GameImportQueue - Trying to add duplicate ImportItem to import queue with url: \(item.url) and id: \(item.id)")
            return
        }

        await importQueueActor.addImport(item)
        ILOG("GameImportQueue - add ImportItem to import queue with url: \(item.url) and id: \(item.id)")
    }

    /// Pauses the import processing
    /// Items can still be added to or removed from the queue while paused
    public func pause() {
        guard processingState == .processing else { return }

        ILOG("GameImportQueue - Pausing import processing")
        DispatchQueue.main.async {
            self.processingState = .paused
            self.updateImporterStatus("Import processing paused")
        }
    }

    /// Resumes the import processing if it was paused
    public func resume() {
        guard processingState == .paused else { return }

        ILOG("GameImportQueue - Resuming import processing")
        DispatchQueue.main.async {
            self.processingState = .processing
            self.updateImporterStatus("Resuming import processing")
        }

        // Restart processing
        Task.detached { [self] in
            await processQueue()
        }
    }

    // Add a helper method to check if processing is paused
    private func checkIfPaused() async -> Bool {
        // Check if we're paused
        var isPaused = false
        await MainActor.run {
            isPaused = self.processingState == .paused
        }
        return isPaused
    }
}
