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
import AsyncAlgorithms
import Combine
import Foundation
import Perception
import PVCoreLoader
import PVFileSystem
import PVLogging
import PVLookup
import PVMediaCache
import PVPlists
import PVPrimitives
import PVRealm
import PVSupport
import PVSystems
import RealmSwift
import SwiftUI

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

    private let cdFileHandler: CDFileHandling // Add this

    private let fileManager: FileManager // Add this

    // MARK: - Paths

    /// Path to the documents directory
    public var documentsPath: URL { get { URL.documentsPath }}
    /// Path to the ROM import directory
    public var romsImportPath: URL { Paths.romsImportPath }
    /// Path to the general imports directory
    public var importsPath: URL { Paths.romsImportPath }
    /// Path to the ROMs directory
    public var romsPath: URL { get { Paths.romsPath }}
    /// Path to the BIOS directory
    public var biosPath: URL { get { Paths.biosesPath }}

    public var databaseService: any GameImporterDatabaseServicing {
        return gameImporterDatabaseService
    }

    /// Returns the path for a given system identifier
    public func path(forSystemID systemID: String) -> URL? {
        return systemToPathMap[systemID]
    }

    /// Returns the path for a given SystemIdentifier
    public func path(forSystemID systemID: SystemIdentifier) -> URL? {
        return systemToPathMap[systemID.rawValue]
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
                  _ systemsService:GameImporterSystemsService,
                  _ artworkImporter:ArtworkImporting,
                  _ cdFileHandler:CDFileHandling,
                  _ skinImporterService: SkinImporterServicing) {
        self.fileManager = fm // Initialize fileManager

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
        self.cdFileHandler = cdFileHandler // Initialize here

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
        var newItems: [ImportQueueItem] = []
        for path in paths {
            let item = ImportQueueItem(url: path, fileType: .unknown)
            newItems.append(item)
        }

        // Add all items to queue first
        for item in newItems {
            await self.addImportItemToQueue(item)
        }

        // Then re-run preProcessQueue to ensure proper organization with the new items
        await preProcessQueue()
    }

    public func addImports(forPaths paths: [URL], targetSystem: SystemIdentifier) async {
        var newItems: [ImportQueueItem] = []
        for path in paths {
            var item = ImportQueueItem(url: path, fileType: .unknown)
            item.userChosenSystem = targetSystem
            newItems.append(item)
        }

        // Add all items to queue first
        for item in newItems {
            await self.addImportItemToQueue(item)
        }

        // Then re-run preProcessQueue to ensure proper organization with the new items
        await preProcessQueue()
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
        var workQueue = await importQueueActor.getQueue()

        // Process each item to determine its type
        for i in 0..<workQueue.count {
            do {
                workQueue[i].fileType = try determineImportType(workQueue[i])
            } catch {
                ELOG("Caught error trying to assign file type \(error.localizedDescription)")
            }
        }

        // Sort the queue to make sure m3us go first
        workQueue = sortImportQueueItems(workQueue)

        // CRITICAL: Process M3U files BEFORE CUE files
        // This ensures M3U files can claim their CUE files before the CUEs are processed individually
        self.organizeM3UFiles(in: &workQueue)

        // Then organize cue/bin files for any remaining CUEs not claimed by M3Us
        self.organizeCueAndBinFiles(in: &workQueue)

        // Update the actor's queue with the fully processed queue
        await importQueueActor.updateQueue(workQueue)

        // Log the processed queue for debugging
        ILOG("Queue after preprocessing: \(workQueue.map { "\($0.url.lastPathComponent) (\($0.status.description))" })")
    }

    public func clearCompleted() async {
        await importQueueActor.clearCompleted()
    }

    /// Handle filename conflicts when moving files
    internal func handleFileNameConflict(file: PVFile, currentURL: URL, destinationURL: URL, m3uDirectory: URL) {
        // Generate a unique name by adding a suffix
        var uniqueURL = destinationURL
        var counter = 1
        let fileName = destinationURL.deletingPathExtension().lastPathComponent
        let fileExtension = destinationURL.pathExtension

        while FileManager.default.fileExists(atPath: uniqueURL.path) {
            uniqueURL = m3uDirectory.appendingPathComponent("\(fileName)_\(counter).\(fileExtension)")
            counter += 1
        }

        do {
            try FileManager.default.moveItem(at: currentURL, to: uniqueURL)
            // Update the file's partial path to reflect the new location
            let newPartialPath = file.relativeRoot.createRelativePath(fromURL: uniqueURL)
            file.partialPath = newPartialPath
            ILOG("Moved file from \(currentURL.path) to \(uniqueURL.path)")
        } catch {
            ELOG("Error moving file with conflict resolution: \(error)")
        }
    }

    /// Update file associations between games and files
    internal func updateFileAssociations(file: PVFile, game: PVGame, gameID: String, realm: Realm) {
        // Find games that have this file as their main file or in related files
        let gamesWithMainFile = realm.objects(PVGame.self).filter("file == %@", file)
        let gamesWithRelatedFile = realm.objects(PVGame.self).filter("ANY relatedFiles == %@", file)

        // Remove file from other games' relationships
        for otherGame in gamesWithMainFile {
            if otherGame.id != gameID {
                otherGame.file = nil
                ILOG("Removed file \(file.fileName) as main file from game: \(otherGame.title ?? "Unknown")")
            }
        }

        for otherGame in gamesWithRelatedFile {
            if otherGame.id != gameID {
                // Find the index of the file in the related files list and remove it
                if let index = otherGame.relatedFiles.index(of: file) {
                    otherGame.relatedFiles.remove(at: index)
                    ILOG("Removed file \(file.fileName) from related files of game: \(otherGame.title ?? "Unknown")")
                }
            }
        }

        // Add to related files of the M3U game if not already there
        if !game.relatedFiles.contains(file) {
            game.relatedFiles.append(file)
            ILOG("Added file \(file.fileName) to related files of M3U game: \(game.title ?? "Unknown")")
        }
    }

    /// Update the game's metadata with better information if available
    internal func updateGameMetadata(game: PVGame, games: [PVGame]) {
        if game.title == nil || game.title.isEmpty {
            // Try to get a better title from one of the consolidated games
            for otherGame in games {
                let title = otherGame.title
                if !title.isEmpty {
                    game.title = title
                    break
                }
            }
        }
    }

    /// Clean up empty games after consolidation
    internal func cleanupEmptyGames(games: [PVGame], gameID: String, realm: Realm) {
        for otherGame in games {
            // Skip the M3U game itself
            if otherGame.id == gameID {
                continue
            }

            // Only delete if it has no files left
            if otherGame.file == nil && otherGame.relatedFiles.isEmpty {
                ILOG("Deleting empty game: \(otherGame.title ?? "Unknown")")
                realm.delete(otherGame)
            }
        }
    }

    /// Scan a directory for files that might be related to a multi-disc game
    internal func scanDirectoryForRelatedFiles(_ directory: URL, primaryGameItem: ImportQueueItem) {
        do {
            let fileManager = FileManager.default
            let directoryContents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

            // Look for any CUE, BIN, or ISO files that might be part of a multi-disc set
            let relevantExtensions = ["cue", "bin", "iso", "img"]

            // Get the base name of the M3U to help identify related files
            let m3uBaseName = primaryGameItem.url.deletingPathExtension().lastPathComponent

            for fileURL in directoryContents {
                let fileExtension = fileURL.pathExtension.lowercased()

                // Only process files with relevant extensions
                if relevantExtensions.contains(fileExtension) {
                    let fileName = fileURL.lastPathComponent.lowercased()

                    // Check if this file might be part of the same multi-disc game
                    // Look for disc indicators in the filename
                    let isRelated = fileName.contains(m3uBaseName) ||
                    fileName.contains("disc") || fileName.contains("disk") ||
                    (fileName.contains("cd") && (fileName.contains("1") ||
                                                 fileName.contains("2") ||
                                                 fileName.contains("3")))

                    if isRelated && !primaryGameItem.resolvedAssociatedFileURLs.contains(fileURL) {
                        primaryGameItem.resolvedAssociatedFileURLs.append(fileURL)
                        ILOG("Found potentially related file for multi-disc game: \(fileName)")

                        // If this is a CUE file, try to find its BIN files
                        if fileExtension == Extensions.cue.rawValue {
                            if let binFiles = try? cdRomFileHandler.parseCueSheet(cueFileURL: fileURL) {
                                for binFile in binFiles {
                                    let binURL = directory.appendingPathComponent(binFile)
                                    if cdRomFileHandler.fileExistsAtPath(binURL) &&
                                        !primaryGameItem.resolvedAssociatedFileURLs.contains(binURL) {
                                        primaryGameItem.resolvedAssociatedFileURLs.append(binURL)
                                        ILOG("Found BIN file for related CUE: \(binFile)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            ELOG("Error scanning directory for related files: \(error)")
        }
    }

    /// Set up the primary game item for M3U processing
    internal func setupPrimaryGameItem(_ m3uQueueItem: ImportQueueItem) -> ImportQueueItem {
        let primaryGameItem = m3uQueueItem
        primaryGameItem.fileType = .cdRom
        ILOG("Using M3U as primary game item: \(primaryGameItem.url.lastPathComponent)")

        // Initialize expected associated files list if needed
        if primaryGameItem.expectedAssociatedFileNames == nil {
            primaryGameItem.expectedAssociatedFileNames = []
        }

        return primaryGameItem
    }

    /// Process all files listed in the M3U file
    internal func processFilesListedInM3U(_ fileNames: [String], primaryGameItem: ImportQueueItem, m3uURL: URL,
                                         importQueue: inout [ImportQueueItem], indicesToRemove: inout [Int]) {
        // First, add all the filenames to the expected files list
        addFilesToExpectedList(fileNames, primaryGameItem: primaryGameItem)

        // Process each file in the M3U
        for fileName in fileNames {
            let foundMatch = findAndProcessFileInQueue(fileName: fileName, primaryGameItem: primaryGameItem,
                                                     importQueue: &importQueue, indicesToRemove: &indicesToRemove)

            // If we didn't find a match in the queue, check if the file exists on disk
            if !foundMatch {
                processFileOnDisk(fileName: fileName, primaryGameItem: primaryGameItem, m3uURL: m3uURL)
            }
        }
    }

    /// Add all filenames to the expected files list
    private func addFilesToExpectedList(_ fileNames: [String], primaryGameItem: ImportQueueItem) {
        for fileName in fileNames {
            addToExpectedFilesList(fileName, primaryGameItem: primaryGameItem)
        }
    }

    /// Find and process a file in the import queue
    /// Returns true if a match was found, false otherwise
    private func findAndProcessFileInQueue(fileName: String, primaryGameItem: ImportQueueItem,
                                         importQueue: inout [ImportQueueItem], indicesToRemove: inout [Int]) -> Bool {
        // Look for the file in the queue - check both exact match and case-insensitive match
        for (index, item) in importQueue.enumerated() {
            if item.id == primaryGameItem.id {
                continue // Skip the M3U file itself
            }

            let itemFileName = item.url.lastPathComponent

            // Check if this queue item matches the M3U entry (case insensitive)
            if itemFileName.lowercased() == fileName.lowercased() {
                associateFileWithPrimaryItem(item, primaryGameItem: primaryGameItem)
                importQueue[index].status = .partial(expectedFiles: [item.url.path(percentEncoded: false)])
                indicesToRemove.append(index)

                // If this is a CUE file, process its BIN files
                if item.url.pathExtension.lowercased() == "cue" {
                    processCUEFileInQueue(item, primaryGameItem: primaryGameItem,
                                          importQueue: &importQueue, indicesToRemove: &indicesToRemove)
                }

                return true
            }
        }

        return false
    }

    /// Process a file that exists on disk
    private func processFileOnDisk(fileName: String, primaryGameItem: ImportQueueItem, m3uURL: URL) {
        let fileURL = m3uURL.deletingLastPathComponent().appendingPathComponent(fileName)

        if cdRomFileHandler.fileExistsAtPath(fileURL) {
            processExistingFileOnDisk(fileURL: fileURL, primaryGameItem: primaryGameItem)
        } else {
            // Look for similar filenames (for multi-disc games with different naming patterns)
            processSimilarFiles(fileName: fileName, primaryGameItem: primaryGameItem, m3uURL: m3uURL)
        }
    }

    /// Process a file that exists on disk
    private func processExistingFileOnDisk(fileURL: URL, primaryGameItem: ImportQueueItem) {
        // Only add if it's not already in the list
        if !primaryGameItem.resolvedAssociatedFileURLs.contains(fileURL) {
            ILOG("Found file on disk for M3U: \(fileURL.lastPathComponent)")
            primaryGameItem.resolvedAssociatedFileURLs.append(fileURL)

            // If this is a CUE file, try to find its BIN files
            if fileURL.pathExtension.lowercased() == "cue" {
                processBINFilesFromCUEOnDisk(cueURL: fileURL, primaryGameItem: primaryGameItem)
            }
        }
    }

    /// Process BIN files from a CUE file on disk
    private func processBINFilesFromCUEOnDisk(cueURL: URL, primaryGameItem: ImportQueueItem) {
        if let binFiles = try? cdRomFileHandler.parseCueSheet(cueFileURL: cueURL) {
            for binFile in binFiles {
                let binURL = cueURL.deletingLastPathComponent().appendingPathComponent(binFile)
                if cdRomFileHandler.fileExistsAtPath(binURL) && !primaryGameItem.resolvedAssociatedFileURLs.contains(binURL) {
                    primaryGameItem.resolvedAssociatedFileURLs.append(binURL)
                    ILOG("Found BIN file on disk for CUE: \(binFile)")
                } else if !primaryGameItem.expectedAssociatedFileNames!.contains(binFile) {
                    primaryGameItem.expectedAssociatedFileNames!.append(binFile)
                    ILOG("Added expected BIN file from CUE: \(binFile)")
                }
            }
        }
    }

    /// Process similar files for a given filename
    private func processSimilarFiles(fileName: String, primaryGameItem: ImportQueueItem, m3uURL: URL) {
        let directory = m3uURL.deletingLastPathComponent()
        let similarFiles = findSimilarFiles(for: fileName, in: directory)

        if !similarFiles.isEmpty {
            processSimilarFilesFound(similarFiles: similarFiles, fileName: fileName, primaryGameItem: primaryGameItem)
        } else {
            // File not in queue yet and not on disk
            ILOG("File \(fileName) from M3U not in queue yet, will be handled when it arrives")
        }
    }

    /// Process similar files that were found
    private func processSimilarFilesFound(similarFiles: [URL], fileName: String, primaryGameItem: ImportQueueItem) {
        for similarFile in similarFiles {
            if !primaryGameItem.resolvedAssociatedFileURLs.contains(similarFile) {
                primaryGameItem.resolvedAssociatedFileURLs.append(similarFile)
                ILOG("Found similar file for M3U entry \(fileName): \(similarFile.lastPathComponent)")

                // If this is a CUE file, process its BIN files
                if similarFile.pathExtension.lowercased() == "cue" {
                    processBINFilesFromSimilarCUE(cueURL: similarFile, primaryGameItem: primaryGameItem)
                }
            }
        }
    }

    /// Find files with similar names to handle different naming patterns in multi-disc games
    private func findSimilarFiles(for fileName: String, in directory: URL) -> [URL] {
        var similarFiles: [URL] = []

        do {
            // Get all files in the directory
            let directoryContents = try getDirectoryContents(directory)

            // Extract the base name without disc indicators
            let baseNameWithoutDisc = extractBaseNameWithoutDiscIndicators(from: fileName)

            // Find files with similar base names
            similarFiles = findFilesWithSimilarNames(in: directoryContents, baseNameToMatch: baseNameWithoutDisc)
        } catch {
            ELOG("Error finding similar files: \(error)")
        }

        return similarFiles
    }

    /// Get all files in a directory
    private func getDirectoryContents(_ directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        return try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    }

    /// Extract the base name without disc indicators from a filename
    private func extractBaseNameWithoutDiscIndicators(from fileName: String) -> String {
        let fileBaseName = fileName.deletingPathExtension
        var baseNameWithoutDisc = fileBaseName

        // Remove disc/CD indicators for matching
        let discIndicators = ["disc", "disk", "cd"]
        for indicator in discIndicators {
            if let range = baseNameWithoutDisc.lowercased().range(of: indicator, options: .caseInsensitive) {
                let index = baseNameWithoutDisc.distance(from: baseNameWithoutDisc.startIndex, to: range.lowerBound)
                if index > 3 { // Ensure we don't cut off too much of the name
                    baseNameWithoutDisc = String(baseNameWithoutDisc.prefix(index - 1))
                }
            }
        }

        return baseNameWithoutDisc
    }

    /// Find files with similar base names in a list of files
    private func findFilesWithSimilarNames(in files: [URL], baseNameToMatch: String) -> [URL] {
        var similarFiles: [URL] = []

        for fileURL in files {
            if isFileSimilar(fileURL: fileURL, baseNameToMatch: baseNameToMatch) {
                similarFiles.append(fileURL)
            }
        }

        return similarFiles
    }

    /// Check if a file has a similar name to the base name
    private func isFileSimilar(fileURL: URL, baseNameToMatch: String) -> Bool {
        let currentFileName = fileURL.lastPathComponent.lowercased()
        let currentBaseName = currentFileName.deletingPathExtension.lowercased()

        // Check if either name contains the other (case insensitive)
        return currentBaseName.contains(baseNameToMatch) ||
               baseNameToMatch.contains(currentBaseName)
    }

    /// Add a file to the expected files list of the primary game item
    private func addToExpectedFilesList(_ fileName: String, primaryGameItem: ImportQueueItem) {
        if !primaryGameItem.expectedAssociatedFileNames!.contains(fileName) {
            primaryGameItem.expectedAssociatedFileNames!.append(fileName)
            ILOG("Added expected file for M3U: \(fileName)")
        }
    }

    /// Associate a file with the primary game item
    private func associateFileWithPrimaryItem(_ file: ImportQueueItem, primaryGameItem: ImportQueueItem) {
        ILOG("Found associated file for M3U: \(file.url.lastPathComponent)")
        primaryGameItem.resolvedAssociatedFileURLs.append(file.url)
    }

    /// Process a CUE file found in the queue
    private func processCUEFileInQueue(_ cueItem: ImportQueueItem, primaryGameItem: ImportQueueItem,
                                       importQueue: inout [ImportQueueItem], indicesToRemove: inout [Int]) {
        // Try to parse the CUE file
        if let binFiles = try? cdRomFileHandler.parseCueSheet(cueFileURL: cueItem.url) {
            processBINFilesFromCUE(binFiles, cueURL: cueItem.url, primaryGameItem: primaryGameItem,
                                   importQueue: &importQueue, indicesToRemove: &indicesToRemove)
        } else {
            // Fallback to filename-based matching
            processBINFilesByFilename(cueItem, primaryGameItem: primaryGameItem,
                                      importQueue: &importQueue, indicesToRemove: &indicesToRemove)
        }
    }

    /// Process BIN files found by parsing a CUE file
    private func processBINFilesFromCUE(_ binFiles: [String], cueURL: URL, primaryGameItem: ImportQueueItem,
                                        importQueue: inout [ImportQueueItem], indicesToRemove: inout [Int]) {
        for binFile in binFiles {
            // Add to expected files
            addToExpectedFilesList(binFile, primaryGameItem: primaryGameItem)

            // Look for the BIN file in the queue
            if let binIndex = importQueue.firstIndex(where: { $0.url.lastPathComponent.lowercased() == binFile.lowercased() &&
                $0.id != primaryGameItem.id }) {
                let binItem = importQueue[binIndex]
                ILOG("Found BIN file for CUE: \(binItem.url.lastPathComponent)")
                primaryGameItem.resolvedAssociatedFileURLs.append(binItem.url)
                importQueue[binIndex].status = .partial(expectedFiles: [binItem.url.path(percentEncoded: false)])
                indicesToRemove.append(binIndex)
            }
        }
    }

    /// Process BIN files by guessing based on CUE filename
    private func processBINFilesByFilename(_ cueItem: ImportQueueItem, primaryGameItem: ImportQueueItem,
                                           importQueue: inout [ImportQueueItem], indicesToRemove: inout [Int]) {
        let cueBaseName = cueItem.url.deletingPathExtension().lastPathComponent
        let potentialBinName = cueBaseName + "." + Extensions.bin.rawValue

        // Add to expected files
        addToExpectedFilesList(potentialBinName, primaryGameItem: primaryGameItem)

        // Look for the BIN file in the queue
        if let binIndex = importQueue.firstIndex(where: { $0.url.lastPathComponent.lowercased() == potentialBinName.lowercased() &&
            $0.id != primaryGameItem.id }) {
            let binItem = importQueue[binIndex]
            ILOG("Found BIN file for CUE (guessed): \(binItem.url.lastPathComponent)")
            primaryGameItem.resolvedAssociatedFileURLs.append(binItem.url)
            importQueue[binIndex].status = .partial(expectedFiles: [potentialBinName])
            indicesToRemove.append(binIndex)
        }
    }

    /// Check for files on disk that might already be extracted but not in the queue
    internal func checkForFilesOnDisk(_ fileNames: [String], primaryGameItem: ImportQueueItem, m3uURL: URL) {
        // Get all files in the M3U directory
        let m3uDirectory = m3uURL.deletingLastPathComponent()
        let fileManager = FileManager.default

        do {
            let directoryContents = try fileManager.contentsOfDirectory(at: m3uDirectory, includingPropertiesForKeys: nil)

            // First check for exact matches from the M3U
            for fileName in fileNames {
                // Check near the M3U file
                let potentialPathNearM3U = m3uDirectory.appendingPathComponent(fileName)
                if cdRomFileHandler.fileExistsAtPath(potentialPathNearM3U) {
                    if !primaryGameItem.resolvedAssociatedFileURLs.contains(potentialPathNearM3U) {
                        primaryGameItem.resolvedAssociatedFileURLs.append(potentialPathNearM3U)
                        ILOG("Found file on disk for M3U: \(potentialPathNearM3U.lastPathComponent)")

                        // If this is a CUE file, try to find its BIN files
                        if potentialPathNearM3U.pathExtension.lowercased() == Extensions.cue.rawValue {
                            if let binFiles = try? cdRomFileHandler.parseCueSheet(cueFileURL: potentialPathNearM3U) {
                                for binFile in binFiles {
                                    let binURL = m3uDirectory.appendingPathComponent(binFile)
                                    if cdRomFileHandler.fileExistsAtPath(binURL) && !primaryGameItem.resolvedAssociatedFileURLs.contains(binURL) {
                                        primaryGameItem.resolvedAssociatedFileURLs.append(binURL)
                                        ILOG("Found BIN file on disk for CUE: \(binFile)")
                                    } else if !primaryGameItem.expectedAssociatedFileNames!.contains(binFile) {
                                        primaryGameItem.expectedAssociatedFileNames!.append(binFile)
                                        ILOG("Added expected BIN file from CUE: \(binFile)")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Then look for any CUE or BIN files in the same directory that might be related
            // This helps with multi-disc games where the M3U might not list all files
            for fileURL in directoryContents {
                let fileExtension = fileURL.pathExtension.lowercased()
                if (fileExtension == Extensions.cue.rawValue || fileExtension == Extensions.bin.rawValue) && !primaryGameItem.resolvedAssociatedFileURLs.contains(fileURL) {
                    // Check if this file might be part of the same game (similar filename pattern)
                    let fileName = fileURL.lastPathComponent.lowercased()
                    let m3uBaseName = m3uURL.deletingPathExtension().lastPathComponent.lowercased()

                    // If the filename contains the M3U base name or looks like a disc in a series
                    if fileName.contains(m3uBaseName) ||
                        (fileName.contains("disc") || fileName.contains("disk")) {
                        primaryGameItem.resolvedAssociatedFileURLs.append(fileURL)
                        ILOG("Found potentially related file for M3U: \(fileName)")

                        // If this is a CUE file, try to find its BIN files
                        if fileExtension == Extensions.cue.rawValue {
                            if let binFiles = try? cdRomFileHandler.parseCueSheet(cueFileURL: fileURL) {
                                for binFile in binFiles {
                                    let binURL = m3uDirectory.appendingPathComponent(binFile)
                                    if cdRomFileHandler.fileExistsAtPath(binURL) && !primaryGameItem.resolvedAssociatedFileURLs.contains(binURL) {
                                        primaryGameItem.resolvedAssociatedFileURLs.append(binURL)
                                        ILOG("Found BIN file on disk for related CUE: \(binFile)")
                                    } else if !primaryGameItem.expectedAssociatedFileNames!.contains(binFile) {
                                        primaryGameItem.expectedAssociatedFileNames!.append(binFile)
                                        ILOG("Added expected BIN file from CUE: \(binFile)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            ELOG("Error checking directory contents: \(error)")
        }
    }

    /// Process CUE files to find their associated BIN files on disk
    internal func processCUEFilesForBINs(primaryGameItem: ImportQueueItem) {
        for resolvedURL in primaryGameItem.resolvedAssociatedFileURLs where resolvedURL.pathExtension.lowercased() == Extensions.cue.rawValue {
            // Try to parse the CUE to find BIN files
            if let binFiles = try? cdRomFileHandler.parseCueSheet(cueFileURL: resolvedURL) {
                for binFile in binFiles {
                    let binPath = resolvedURL.deletingLastPathComponent().appendingPathComponent(binFile)
                    if cdRomFileHandler.fileExistsAtPath(binPath) && !primaryGameItem.resolvedAssociatedFileURLs.contains(binPath) {
                        primaryGameItem.resolvedAssociatedFileURLs.append(binPath)
                        ILOG("Found BIN file on disk for CUE: \(binPath.lastPathComponent)")
                    } else if !primaryGameItem.expectedAssociatedFileNames!.contains(binFile) {
                        primaryGameItem.expectedAssociatedFileNames!.append(binFile)
                        ILOG("Added expected BIN file from CUE: \(binFile)")
                    }
                }
            }
        }
    }

    /// Finalize the primary game item by deduplicating lists
    internal func finalizePrimaryGameItem(_ primaryGameItem: ImportQueueItem, m3uURL: URL) {
        // Deduplicate resolvedAssociatedFileURLs
        let uniqueURLs = NSOrderedSet(array: primaryGameItem.resolvedAssociatedFileURLs)
        primaryGameItem.resolvedAssociatedFileURLs = uniqueURLs.array as! [URL]

        // Deduplicate and sort expectedAssociatedFileNames
        if var currentExpected = primaryGameItem.expectedAssociatedFileNames, !currentExpected.isEmpty {
            currentExpected = Array(Set(currentExpected.map { $0.lowercased() })).sorted()
            primaryGameItem.expectedAssociatedFileNames = currentExpected.isEmpty ? nil : currentExpected
            ILOG("M3U \(m3uURL.lastPathComponent) expects associated files: \(currentExpected)")
        }

        // Log all the files that will be associated with this M3U
        ILOG("M3U \(m3uURL.lastPathComponent) has \(primaryGameItem.resolvedAssociatedFileURLs.count) associated files:")
        for (index, url) in primaryGameItem.resolvedAssociatedFileURLs.enumerated() {
            ILOG("  [\(index+1)/\(primaryGameItem.resolvedAssociatedFileURLs.count)] \(url.lastPathComponent)")
        }
    }

    internal func organizeCueAndBinFiles(in importQueue: inout [ImportQueueItem]) {
        ILOG("Starting CUE/BIN organization...")
        var i = importQueue.count - 1
        while i >= 0 {
            let currentItem = importQueue[i]

            // Skip non-CUE files
            guard currentItem.url.pathExtension.lowercased() == Extensions.cue.rawValue else {
                i -= 1
                continue
            }

            let cueItem = currentItem
            let cueURL = cueItem.url
            VLOG("Processing CUE: \(cueURL.lastPathComponent)")

            guard let referencedFileNames = try? cdRomFileHandler.parseCueSheet(cueFileURL: cueURL) else {
                WLOG("Could not parse CUE sheet: \(cueURL.lastPathComponent)")
                cueItem.fileType = .cdRom // Still mark as CD-ROM
                // Add all .bin, .img, etc. files in the same directory as expected if CUE parsing fails but they exist
                // This is a basic fallback, could be more sophisticated
                var expected: [String] = cueItem.expectedAssociatedFileNames ?? []
                let cueDir = cueURL.deletingLastPathComponent()
                if let dirContents = try? fileManager.contentsOfDirectory(at: cueDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    for fileInDir in dirContents {
                        let ext = fileInDir.pathExtension.lowercased()
                        if Extensions.discImageExtensions.contains(ext) || ext == Extensions.bin.rawValue { // Common track types
                            if !expected.contains(fileInDir.lastPathComponent) { expected.append(fileInDir.lastPathComponent) }
                        }
                    }
                }
                cueItem.expectedAssociatedFileNames = expected.isEmpty ? nil : Array(Set(expected.map { $0.lowercased() })).sorted()
                i -= 1
                continue
            }

            if referencedFileNames.isEmpty {
                WLOG("CUE sheet is empty or contains no valid file entries: \(cueURL.lastPathComponent)")
                cueItem.fileType = .cdRom // Still mark as CD-ROM
                i -= 1
                continue
            }

            var indicesToRemove: [Int] = [] // Don't remove CUE itself unless primary is found elsewhere and CUE becomes associated
            var allFilesFound = true

            for referencedFileName in referencedFileNames {
                // Try to find the referenced file in the import queue first
                if let associatedItemIndex = importQueue.firstIndex(where: { $0.url.lastPathComponent.lowercased() == referencedFileName.lowercased() && $0.id != cueItem.id }) {
                    let associatedItem = importQueue[associatedItemIndex]
                    if !cueItem.resolvedAssociatedFileURLs.contains(associatedItem.url) {
                        cueItem.resolvedAssociatedFileURLs.append(associatedItem.url)
                    }
                    // Also merge resolved files from the associated item itself
                    for resolvedURL in associatedItem.resolvedAssociatedFileURLs {
                        if !cueItem.resolvedAssociatedFileURLs.contains(resolvedURL) {
                            cueItem.resolvedAssociatedFileURLs.append(resolvedURL)
                        }
                    }
                    VLOG("Associated \(associatedItem.url.lastPathComponent) from CUE with \(cueURL.lastPathComponent)")
                    if !indicesToRemove.contains(associatedItemIndex) {
                        indicesToRemove.append(associatedItemIndex)
                    }
                    // If this file was expected, remove it from expectations
                    if var cueExpected = cueItem.expectedAssociatedFileNames {
                        cueExpected.removeAll { $0.lowercased() == referencedFileName.lowercased() }
                        cueItem.expectedAssociatedFileNames = cueExpected.isEmpty ? nil : cueExpected
                    }
                } else {
                    // File not in queue, check on disk relative to CUE.
                    let potentialPathNearCue = cueURL.deletingLastPathComponent().appendingPathComponent(referencedFileName)

                    if cdRomFileHandler.fileExistsAtPath(potentialPathNearCue) {
                        if !cueItem.resolvedAssociatedFileURLs.contains(potentialPathNearCue) {
                            cueItem.resolvedAssociatedFileURLs.append(potentialPathNearCue)
                            VLOG("Resolved \(referencedFileName) near CUE for \(cueURL.lastPathComponent)")
                        }
                        if var cueExpected = cueItem.expectedAssociatedFileNames {
                            cueExpected.removeAll { $0.lowercased() == referencedFileName.lowercased() }
                            cueItem.expectedAssociatedFileNames = cueExpected.isEmpty ? nil : cueExpected
                        }
                    } else {
                        allFilesFound = false
                        // File not in queue and not on disk: add to expected if not already resolved or expected
                        if !cueItem.resolvedAssociatedFileURLs.contains(where: { $0.lastPathComponent.lowercased() == referencedFileName.lowercased()}) {
                            var currentExpected = cueItem.expectedAssociatedFileNames ?? []
                            if !currentExpected.contains(where: {$0.lowercased() == referencedFileName.lowercased()}) {
                                currentExpected.append(referencedFileName)
                            }
                            cueItem.expectedAssociatedFileNames = currentExpected.isEmpty ? nil : Array(Set(currentExpected.map { $0.lowercased() })).sorted()
                            VLOG("Expecting \(referencedFileName) for \(cueURL.lastPathComponent)")
                        }
                    }
                }
            }

            cueItem.resolvedAssociatedFileURLs = Array(Set(cueItem.resolvedAssociatedFileURLs))
            if var currentExpected = cueItem.expectedAssociatedFileNames, !currentExpected.isEmpty {
                currentExpected = Array(Set(currentExpected.map { $0.lowercased() })).sorted()
                cueItem.expectedAssociatedFileNames = currentExpected.isEmpty ? nil : currentExpected
            }
            cueItem.fileType = .cdRom // CUE always implies CD-ROM
            cueItem.status = (cueItem.expectedAssociatedFileNames?.isEmpty ?? true) && allFilesFound ? .queued : .partial(expectedFiles: cueItem.expectedAssociatedFileNames ?? []) // Or some other status based on completeness

            indicesToRemove.sorted(by: >).forEach { indexToRemove in
                if indexToRemove < importQueue.count { // Safety check
                    let removedItem = importQueue.remove(at: indexToRemove)
                    VLOG("Removed \(removedItem.url.lastPathComponent) from queue as it was subsumed by CUE processing for \(cueURL.lastPathComponent)")
                }
            }
            VLOG("Finished processing CUE: \(cueURL.lastPathComponent)")
            i -= 1
        }
        ILOG("Finished CUE/BIN organization.")
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
        ILOG("GameImportQueue - processQueue Start Import Processing")
        NotificationCenter.default.post(name: .GameImporterDidStart, object: nil)
        // Set initial state to processing
        await MainActor.run {
            self.processingState = .processing
        }
        defer {
            DispatchQueue.main.async {
                // Only change to idle if we're not paused
                if self.processingState != .paused {
                    self.processingState = .idle
                }
                NotificationCenter.default.post(name: .GameImporterDidFinish, object: nil)
            }
        }
        // Check for items that are either queued or have a user-chosen system
        let itemsToProcess = await importQueue.filter {
            $0.status == .queued || $0.userChosenSystem != nil
        }

        guard !itemsToProcess.isEmpty else {
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
                let userInfo = [
                    PVNotificationUserInfoKeys.fileNameKey: item.url.lastPathComponent,
                    PVNotificationUserInfoKeys.md5Key: item.md5 ?? FileManager.default.md5ForFile(at: item.url),
                ]
                NotificationCenter.default.post(name: .PVGameImported, object: nil, userInfo: userInfo)
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
                let userInfo = [
                    PVNotificationUserInfoKeys.fileNameKey: item.url.lastPathComponent,
                    PVNotificationUserInfoKeys.md5Key: item.md5 ?? FileManager.default.md5ForFile(at: item.url),
                    PVNotificationUserInfoKeys.errorKey: error.localizedDescription
                ]
                NotificationCenter.default.post(name: .GameImporterFileDidFail, object: nil, userInfo: userInfo)
            case .waitingForAssociatedFiles(let expectedFiles):
                Task { @MainActor in
                    item.status = .partial(expectedFiles: expectedFiles)
                }
                updateImporterStatus("Waiting for files for \(item.url.lastPathComponent)")
                ILOG("GameImportQueue - item \(item.url.lastPathComponent) is waiting for associated files: \(expectedFiles.joined(separator: ", ")).")
            default:
                Task { @MainActor in
                    item.status = .failure(error: error)
                }
                updateImporterStatus("Failed \(item.url.lastPathComponent) with error: \(error.localizedDescription)")
                ELOG("GameImportQueue - processing item in queue: \(item.url) failed. Error: \(error.localizedDescription)")
                let userInfo = [
                    PVNotificationUserInfoKeys.fileNameKey: item.url.lastPathComponent,
                    PVNotificationUserInfoKeys.md5Key: item.md5 ?? FileManager.default.md5ForFile(at: item.url),
                    PVNotificationUserInfoKeys.errorKey: error.localizedDescription
                ]
                NotificationCenter.default.post(name: .GameImporterFileDidFail, object: nil, userInfo: userInfo)
            }
        } catch {
            ILOG("GameImportQueue - processing item in queue: \(item.url) caught error... \(error.localizedDescription)")
            Task { @MainActor in
                item.status = .failure(error: error)
            }
            updateImporterStatus("Failed \(item.url.lastPathComponent) with error: \(error.localizedDescription)")
            ELOG("GameImportQueue - processing item in queue: \(item.url) failed. Unexpected Error: \(error.localizedDescription)")
            let userInfo = [
                PVNotificationUserInfoKeys.fileNameKey: item.url.lastPathComponent,
                PVNotificationUserInfoKeys.md5Key: item.md5 ?? FileManager.default.md5ForFile(at: item.url),
                PVNotificationUserInfoKeys.errorKey: error.localizedDescription
            ]
            NotificationCenter.default.post(name: .GameImporterFileDidFail, object: nil, userInfo: userInfo)
        }
    }

    // MARK: - Cue Sheet and Associated File Handling
    private func handleLateAssociatedFile(fileURL: URL, forCompletedItem item: ImportQueueItem) async {
        ILOG("Handling late-arriving file: \(fileURL.lastPathComponent) for item: \(item.url.lastPathComponent)")

        // Check if this is a CUE file and if we need to look for BIN files
        let isCueFile = fileURL.pathExtension.lowercased() == Extensions.cue.rawValue
        var binFilesToCheck: [String] = []

        if isCueFile {
            // Try to parse the CUE file to find referenced BIN files
            if let binFiles = try? cdRomFileHandler.parseCueSheet(cueFileURL: fileURL) {
                binFilesToCheck = binFiles
                ILOG("CUE file \(fileURL.lastPathComponent) references BIN files: \(binFiles)")
            } else {
                // If we can't parse the CUE, make a guess based on filename
                let cueBaseName = fileURL.deletingPathExtension().lastPathComponent
                let potentialBinName = cueBaseName + ".bin"
                binFilesToCheck = [potentialBinName]
                ILOG("Could not parse CUE file, guessing BIN file: \(potentialBinName)")
            }
        }

        // If the item doesn't have a gameDatabaseID yet, it might be that the game hasn't been fully imported
        // In this case, we should update the item's resolvedAssociatedFileURLs and let it be processed normally
        if item.gameDatabaseID == nil {
            ILOG("Primary item \(item.url.lastPathComponent) doesn't have a gameDatabaseID yet. Adding file to its resolvedAssociatedFileURLs.")
            if !item.resolvedAssociatedFileURLs.contains(fileURL) {
                item.resolvedAssociatedFileURLs.append(fileURL)
            }

            // Remove the file from expectedAssociatedFileNames if it's there
            if var expectedFiles = item.expectedAssociatedFileNames {
                expectedFiles.removeAll { $0.lowercased() == fileURL.lastPathComponent.lowercased() }
                item.expectedAssociatedFileNames = expectedFiles.isEmpty ? nil : expectedFiles
            }

            // If this is a CUE file, add its BIN files to expected files if not already there
            if isCueFile && !binFilesToCheck.isEmpty {
                // Check if any of the BIN files already exist in the destination directory
                for binFileName in binFilesToCheck {
                    let binFileInImports = self.importsPath.appendingPathComponent(binFileName)

                    // If the BIN file exists in the imports directory, process it now
                    if FileManager.default.fileExists(atPath: binFileInImports.path) {
                        ILOG("Found BIN file \(binFileName) in imports directory for late-arriving CUE \(fileURL.lastPathComponent)")
                        // Process it as a late-arriving file
                        await handleLateAssociatedFile(fileURL: binFileInImports, forCompletedItem: item)
                    } else {
                        // Add to expected files if it doesn't exist yet
                        if item.expectedAssociatedFileNames == nil {
                            item.expectedAssociatedFileNames = [binFileName]
                            ILOG("Created expected files list with BIN file \(binFileName) for late-arriving CUE \(fileURL.lastPathComponent)")
                        } else if !item.expectedAssociatedFileNames!.contains(binFileName) {
                            item.expectedAssociatedFileNames!.append(binFileName)
                            ILOG("Added expected BIN file \(binFileName) for late-arriving CUE \(fileURL.lastPathComponent)")
                        }
                    }
                }
            }

        } else {
            // If we have a gameDatabaseID, proceed with adding the file to the database
            guard let gameID = item.gameDatabaseID else {
                ELOG("Cannot handle late associated file \(fileURL.lastPathComponent): gameDatabaseID is nil.")
                return
            }

            let realm = RomDatabase.sharedInstance.realm

            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: gameID) else {
                ELOG("Cannot handle late associated file \(fileURL.lastPathComponent): PVGame with ID \(gameID) not found.")
                return
            }

            // Determine the destination directory for the game's files.
            var destinationDirectory: URL? = nil
            if let primaryFileURL = game.file?.url, !primaryFileURL.path.isEmpty {
                destinationDirectory = primaryFileURL.deletingLastPathComponent()
            } else if let firstRelatedFileURL = game.relatedFiles.first(where: { $0.url?.path.isEmpty == false })?.url {
                destinationDirectory = firstRelatedFileURL.deletingLastPathComponent()
            }

            guard let validDestinationDirectory = destinationDirectory else {
                ELOG("Cannot determine destination directory for late associated file \(fileURL.lastPathComponent) for game \(game.title ?? "Unknown"): No existing file paths found for the game.")
                return
            }

            let destinationFileURL = validDestinationDirectory.appendingPathComponent(fileURL.lastPathComponent)

            do {
                // Move the file
                let destPathString = destinationFileURL.path
                DLOG("Moving late-arriving file from \(fileURL.path) to \(destPathString)")
                try FileManager.default.moveItem(at: fileURL, to: destinationFileURL)

                // Create PVFile and add to game
                let newPVFile = PVFile(withURL: destinationFileURL, relativeRoot: .platformDefault)

                try realm.write {
                    realm.add(newPVFile, update: Realm.UpdatePolicy.modified)
                    if !game.relatedFiles.contains(where: { $0.url == newPVFile.url }) {
                        game.relatedFiles.append(newPVFile)
                    }
                }
                ILOG("Successfully processed late-arriving file \(destinationFileURL.lastPathComponent) for game \(game.title ?? "Unknown").")

                // Update the ImportQueueItem's resolvedAssociatedFileURLs
                if !item.resolvedAssociatedFileURLs.contains(destinationFileURL) {
                    item.resolvedAssociatedFileURLs.append(destinationFileURL)
                }

                // Remove the file from expectedAssociatedFileNames if it's there
                if var expectedFiles = item.expectedAssociatedFileNames {
                    expectedFiles.removeAll { $0.lowercased() == fileURL.lastPathComponent.lowercased() }
                    item.expectedAssociatedFileNames = expectedFiles.isEmpty ? nil : expectedFiles
                }

                // If this is a CUE file, check for BIN files and add them to expected files
                if isCueFile && !binFilesToCheck.isEmpty {
                    // Check if any of the BIN files already exist in the destination directory
                    for binFileName in binFilesToCheck {
                        let binFileInImports = self.importsPath.appendingPathComponent(binFileName)

                        // If the BIN file exists in the imports directory, process it now
                        if FileManager.default.fileExists(atPath: binFileInImports.path) {
                            ILOG("Found BIN file \(binFileName) in imports directory for late-arriving CUE \(fileURL.lastPathComponent)")
                            // Process it as a late-arriving file
                            await handleLateAssociatedFile(fileURL: binFileInImports, forCompletedItem: item)
                        } else {
                            // Add to expected files if it doesn't exist yet
                            if item.expectedAssociatedFileNames == nil {
                                item.expectedAssociatedFileNames = [binFileName]
                                ILOG("Created expected files list with BIN file \(binFileName) for late-arriving CUE \(fileURL.lastPathComponent)")
                            } else if !item.expectedAssociatedFileNames!.contains(binFileName) {
                                item.expectedAssociatedFileNames!.append(binFileName)
                                ILOG("Added expected BIN file \(binFileName) for late-arriving CUE \(fileURL.lastPathComponent)")
                            }
                        }
                    }
                }

            } catch {
                ELOG("Error processing late-arriving file \(fileURL.lastPathComponent) for game \(game.title ?? "Unknown"): \(error.localizedDescription)")
                // Consider adding the file back to the import queue if the move fails
                await addImportItemToQueue(ImportQueueItem(url: fileURL, fileType: .unknown))
            }
        }
    }

    /// Process BIN files from a similar CUE file
    private func processBINFilesFromSimilarCUE(cueURL: URL, primaryGameItem: ImportQueueItem) {
        if let binFiles = try? cdRomFileHandler.parseCueSheet(cueFileURL: cueURL) {
            for binFile in binFiles { // binFile is a String, e.g., "Track 01.bin"
                let binURL = cueURL.deletingLastPathComponent().appendingPathComponent(binFile)

                // Check if the BIN file actually exists on disk
                if cdRomFileHandler.fileExistsAtPath(binURL) {
                    // If it exists, check if we haven't already added its URL to resolved files
                    if !primaryGameItem.resolvedAssociatedFileURLs.contains(binURL) {
                        primaryGameItem.resolvedAssociatedFileURLs.append(binURL)
                        ILOG("Found BIN file for similar CUE: \(binFile), added to resolvedAssociatedFileURLs for \(primaryGameItem.url.lastPathComponent)")

                        // Now, also add its name (String) to expectedAssociatedFileNames
                        // Ensure the array is initialized if it's currently nil
                        if primaryGameItem.expectedAssociatedFileNames == nil {
                            primaryGameItem.expectedAssociatedFileNames = []
                        }

                        // Add the filename if it's not already in the list
                        // It's safe to force-unwrap expectedAssociatedFileNames here because we just initialized it if it was nil.
                        if !primaryGameItem.expectedAssociatedFileNames!.contains(binFile) {
                            primaryGameItem.expectedAssociatedFileNames!.append(binFile)
                            ILOG("Added expected BIN file name from similar CUE: \(binFile) to \(primaryGameItem.url.lastPathComponent)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - ImportItemDisplayable Conformance

    // This is the version of determineImportType called internally for quick checks, non-throwing.
    // Relies on the simpler helpers above.
    private func determineImportType(_ item: ImportQueueItem) -> ImportQueueItem.FileType {
        if isBIOS(item) { return .bios }
        if isSkin(item) { return .skin }
        if isArtwork(item) { return .artwork }
        if isCDROM(item) { return .cdRom } // Covers .cue, .m3u, .iso, .chd etc.

        // Must check for archives AFTER CDROM, as some CD images can be archives (e.g. .zip containing .iso)
        // However, our current definition of cdRom covers extensions like .iso, .chd directly.
        // If an archive contains a game, it's still initially an archive until extraction.
        if Extensions.archiveExtensions.contains(item.url.pathExtension.lowercased()) { return .zip }

        if !item.url.pathExtension.isEmpty { return .game } // Default to .game if has an extension and not other types
        return .unknown
    }

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
                    item.status = .failure(error: GameImporterError.artworkImportFailed)
                }
            }
            return
        }

        // Only do system detection for non-BIOS files
        guard let systems: [SystemIdentifier] = try? await gameImporterSystemsService.determineSystems(for: item), !systems.isEmpty else {
            //this is actually an import error
            item.status = .failure(error: GameImporterError.noSystemMatched)
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
            throw GameImporterError.conflictDetected
        }

        // Check for expected files before importing game/cdRom types
        if item.fileType == .game || item.fileType == .cdRom {
            // Ensure expectedAssociatedFileNames is not nil before checking count.
            // An empty list means no files are expected.
            if let expectedFiles = item.expectedAssociatedFileNames, !expectedFiles.isEmpty {
                ILOG("Item \(item.url.lastPathComponent) still has \(expectedFiles.count) expected files. Deferring database import. Expected: \(expectedFiles)")
                throw GameImporterError.waitingForAssociatedFiles(expected: expectedFiles)
            }
            ILOG("Item \(item.url.lastPathComponent) has no pending expected files. Proceeding with database import.")
        }

        //move ImportQueueItem to appropriate file location
        try await gameImporterFileService.moveImportItem(toAppropriateSubfolder: item)

        if (item.fileType == .bios) {
            try await gameImporterDatabaseService.importBIOSIntoDatabase(queueItem: item)
        } else {
            //import the copied file into our database
            try await gameImporterDatabaseService.importGameIntoDatabase(queueItem: item)
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
        // First, check if this is a BIOS file
        let fileType = determineImportType(item)
        item.fileType = fileType // <--- SET THE FILE TYPE HERE

        if fileType == .bios {
            // For BIOS files, check if we already have a matching BIOS entry with a file
            let biosExists = await BIOSWatcher.shared.checkBIOSFile(at: item.url)
            if biosExists {
                ILOG("GameImportQueue - Skipping BIOS file that already exists in database: \(item.url.lastPathComponent)")
                return
            }
        } else if fileType == .game || fileType == .cdRom {
            // For ROM files, check if we already have a matching game entry in the database
            let isROMAlreadyImported = await isROMAlreadyInDatabase(item)
            if isROMAlreadyImported {
                ILOG("GameImportQueue - Skipping ROM file that already exists in database: \(item.url.lastPathComponent)")
                return
            }

            // Check if this is a late-arriving file that belongs to an already processed M3U or CUE
            // This is crucial for handling files that arrive after their parent M3U/CUE has been processed
            let currentQueue = await importQueueActor.getQueue()
            let successfulItems = currentQueue.filter { $0.status == .success }

            // First check for completed items that might be expecting this file
            for completedItem in successfulItems where completedItem.fileType == .cdRom {
                // Check if this file is in the expected associated files list of any completed item
                if let expectedFiles = completedItem.expectedAssociatedFileNames,
                   expectedFiles.contains(where: { $0.lowercased() == item.url.lastPathComponent.lowercased() }) {
                    ILOG("Found late-arriving file \(item.url.lastPathComponent) that belongs to completed item \(completedItem.url.lastPathComponent)")

                    // Handle the late-arriving file
                    await handleLateAssociatedFile(fileURL: item.url, forCompletedItem: completedItem)
                    return // Don't add to queue since we've handled it as a late arrival
                }

                // Check if this is a CUE file mentioned in an M3U
                if completedItem.url.pathExtension.lowercased() == Extensions.m3u.rawValue,
                   let m3uContents = try? cdRomFileHandler.parseM3U(from: completedItem.url),
                   m3uContents.contains(where: { $0.lowercased() == item.url.lastPathComponent.lowercased() }) {
                    ILOG("Found late-arriving CUE file \(item.url.lastPathComponent) that belongs to M3U \(completedItem.url.lastPathComponent)")

                    // Handle the late-arriving file
                    await handleLateAssociatedFile(fileURL: item.url, forCompletedItem: completedItem)
                    return // Don't add to queue since we've handled it as a late arrival
                }

                // Check if this is a BIN file that might be referenced by a CUE file
                // This is especially important for BIN files that arrive after their CUE
                if item.url.pathExtension.lowercased() == Extensions.bin.rawValue {
                    // Check all resolved CUE files associated with this completed item
                    for resolvedURL in completedItem.resolvedAssociatedFileURLs where resolvedURL.pathExtension.lowercased() == Extensions.cue.rawValue {
                        // Try to parse the CUE file to find referenced BIN files
                        if let binFiles = try? cdRomFileHandler.parseCueSheet(cueFileURL: resolvedURL),
                           binFiles.contains(where: { $0.lowercased() == item.url.lastPathComponent.lowercased() }) {
                            ILOG("Found late-arriving BIN file \(item.url.lastPathComponent) referenced by CUE \(resolvedURL.lastPathComponent)")

                            // Handle the late-arriving file
                            await handleLateAssociatedFile(fileURL: item.url, forCompletedItem: completedItem)
                            return // Don't add to queue since we've handled it as a late arrival
                        }
                    }

                    // If we didn't find a match in the CUE files, check if the BIN file matches the base name of any CUE
                    let binBaseName = item.url.deletingPathExtension().lastPathComponent.lowercased()

                    for resolvedURL in completedItem.resolvedAssociatedFileURLs where resolvedURL.pathExtension.lowercased() == Extensions.cue.rawValue {
                        let cueBaseName = resolvedURL.deletingPathExtension().lastPathComponent.lowercased()

                        if binBaseName == cueBaseName {
                            ILOG("Found late-arriving BIN file \(item.url.lastPathComponent) with matching base name to CUE \(resolvedURL.lastPathComponent)")

                            // Handle the late-arriving file
                            await handleLateAssociatedFile(fileURL: item.url, forCompletedItem: completedItem)
                            return // Don't add to queue since we've handled it as a late arrival
                        }
                    }
                }
            }

            // Check for duplicates in the current queue
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
            if item.url.pathExtension.lowercased() == Extensions.cue.rawValue {
                var group = [item]
                let baseName = item.url.deletingPathExtension().lastPathComponent

                // Find related bin files
                for binItem in items where binItem.url.pathExtension.lowercased() == Extensions.bin.rawValue {
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
            else if item.url.pathExtension.lowercased() == Extensions.m3u.rawValue {
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

    // Add a helper method to check if processing is paused
    private func checkIfPaused() async -> Bool {
        // Check if we're paused
        let isPaused = self.processingState == .paused
        return isPaused
    }

    /// Checks if a ROM file already exists in the database with a valid file
    /// - Parameter item: The ImportQueueItem to check
    /// - Returns: True if the ROM already exists in the database with a valid file
    private func isROMAlreadyInDatabase(_ item: ImportQueueItem) async -> Bool {
        // First try to determine the system for this ROM
        do {
            let systems = try await gameImporterSystemsService.determineSystems(for: item)
            guard !systems.isEmpty else {
                // If we can't determine the system, we can't check the database
                return false
            }

            // For each potential system, check if the ROM already exists
            for system in systems {
                // Check by filename in the system's directory
                let filename = item.url.lastPathComponent
                let partialPath = (system.rawValue as NSString).appendingPathComponent(filename)
                let similarName = RomDatabase.altName(item.url, systemIdentifier: system)

                // Check the games cache for this ROM
                let gamesCache = RomDatabase.gamesCache

                if let existingGame = gamesCache[partialPath] ?? gamesCache[similarName],
                   system.rawValue == existingGame.systemIdentifier,
                   existingGame.file != nil {
                    // The game exists in the database with a valid file
                    ILOG("Found existing game in database: \(existingGame.title) with valid file")
                    return true
                }

                // If we have an MD5 hash, check for matches by MD5
                if let md5 = item.md5?.uppercased() {
                    let realm = RomDatabase.sharedInstance.realm
                    let gamesWithSameMD5 = realm.objects(PVGame.self).filter("md5Hash == %@", md5)

                    if let existingGameWithSameMD5 = gamesWithSameMD5.first,
                       system.rawValue == existingGameWithSameMD5.systemIdentifier,
                       existingGameWithSameMD5.file != nil {
                        // The game exists in the database with a valid file and matching MD5
                        ILOG("Found existing game with same MD5 hash: \(existingGameWithSameMD5.title) with valid file")
                        return true
                    }
                }
            }

            // If we get here, the ROM doesn't exist in the database with a valid file
            return false
        } catch {
            ELOG("Error checking if ROM is already in database: \(error.localizedDescription)")
            return false
        }
    }

    /// Updates the importer status message
    private func updateImporterStatus(_ message: String) {
        importStatus = message
        ILOG("Importer status: \(message)")
    }
}

/// Extension to String to easily get filename without extension
fileprivate extension String {
    var deletingPathExtension: String {
        let url = URL(fileURLWithPath: self)
        return url.deletingPathExtension().lastPathComponent
    }
}
