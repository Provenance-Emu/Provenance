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
import Perception

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
    /// Tracks archive files being extracted by their URL path to prevent re-adding during extraction
    private var extractingArchives: Set<String> = []

    func checkAndRegisterImport(md5: String) -> Bool {
        guard !activeImports.contains(md5) else { return false }
        activeImports.insert(md5)
        return true
    }

    func completeImport(md5: String) {
        activeImports.remove(md5)
    }

    /// Registers an archive file as being extracted to prevent DirectoryWatcher from re-adding it
    func registerExtractingArchive(url: URL) {
        extractingArchives.insert(url.path)
    }

    /// Unregisters an archive file after extraction completes
    func unregisterExtractingArchive(url: URL) {
        extractingArchives.remove(url.path)
    }

    /// Checks if an archive is currently being extracted
    func isExtractingArchive(url: URL) -> Bool {
        return extractingArchives.contains(url.path)
    }
}

/// Actor for managing the import queue with thread safety
public actor ImportQueueActor {
    /// Subject to publish queue changes
    let queueSubject = CurrentValueSubject<[ImportQueueItem], Never>([])

    /// The current queue of import items
    private(set) var queue: [ImportQueueItem] = [] {
        didSet {
            generation &+= 1
            let queuedCount = queue.filter { $0.status == .queued }.count
            ILOG("ImportQueueActor: Queue updated - \(queue.count) total items, \(queuedCount) queued")

            // Schedule auto-start whenever there are items queued for processing
            if queuedCount > 0 {
                ILOG("ImportQueueActor: Triggering auto-start callback (\(queuedCount) queued items)")
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
    private var generation: UInt64 = 0

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

    func getQueueSnapshot() -> (queue: [ImportQueueItem], generation: UInt64) {
        return (queue, generation)
    }

    func currentGeneration() -> UInt64 {
        return generation
    }

    func addImport(_ item: ImportQueueItem) {
        // Check for duplicates before adding to prevent race conditions
        // This is especially important when DirectoryWatcher and extractAndImportArchive both try to add the same file
        let isDuplicate = queue.contains { existing in
            // Check if the URL is the same
            if existing.url == item.url {
                return true
            }
            // Check if the filename is the same and in the same directory
            if existing.url.lastPathComponent == item.url.lastPathComponent &&
                existing.url.deletingLastPathComponent() == item.url.deletingLastPathComponent() {
                return true
            }
            // Check MD5 if available
            if let existingMd5 = existing.md5?.uppercased(),
               let itemMd5 = item.md5?.uppercased(),
               existingMd5 == itemMd5 {
                return true
            }
            return false
        }

        if isDuplicate {
            // Don't add duplicate items - this prevents race conditions when both
            // extractAndImportArchive and DirectoryWatcher try to add the same file
            VLOG("ImportQueueActor: Skipping duplicate item \(item.url.lastPathComponent) (already in queue)")
            return
        }

        ILOG("ImportQueueActor: Adding item to queue: \(item.url.lastPathComponent) (status: \(item.status))")
        queue.append(item)
    }

    func addImports(_ items: [ImportQueueItem]) {
        queue.append(contentsOf: items)
    }

    func removeImports(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
    }

    /// Removes an item from the queue by matching its URL
    func removeImport(byURL url: URL) {
        queue.removeAll { $0.url == url }
    }

    /// Removes an item from the queue by matching its ID
    func removeImport(byID id: UUID) {
        queue.removeAll { $0.id == id }
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

    @discardableResult
    func replaceQueue(ifGenerationMatches expectedGeneration: UInt64, with newQueue: [ImportQueueItem]) -> Bool {
        guard generation == expectedGeneration else { return false }
        queue = newQueue
        return true
    }

    func getItem(at index: Int) -> ImportQueueItem? {
        guard index < queue.count else { return nil }
        return queue[index]
    }

    func containsDuplicate(ofItem queueItem: ImportQueueItem, comparator: (ImportQueueItem, ImportQueueItem) -> Bool) -> Bool {
        return queue.contains(where: { existing in
            guard existing.status.blocksDuplicateProcessing else { return false }
            return comparator(existing, queueItem)
        })
    }
}

actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.permits = max(1, value)
    }

    func wait() async {
        if permits > 0 {
            permits -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if let continuation = waiters.first {
            waiters.removeFirst()
            continuation.resume()
        } else {
            permits += 1
        }
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

    /// Flag indicating if import is paused specifically for emulation (should not auto-resume)
    @MainActor public private(set) var isPausedForEmulation: Bool = false

    var importAutoStartDelayTask: Task<Void, Never>?

    // Task management for preventing concurrent processing
    private var currentProcessingTask: Task<Void, Never>?
    private var currentTimeoutTask: Task<Void, Never>?
    private let processingTaskLock = NSLock()

    // Timeout configuration for hung task detection
    private let processingTimeoutDuration: TimeInterval = 600 // 10 minutes
    private var processingStartTime: Date?
    private var autoRestartAvailableAt: Date?
    private var lastPreprocessedQueueGeneration: UInt64?

    // Actor to manage the import queue with thread safety
    public let importQueueActor: ImportQueueActor

    // Public computed property to access the import queue
    public var importQueue: [ImportQueueItem] {
        get async {
            await importQueueActor.getQueue()
        }
    }

    @MainActor
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
        #if DEBUG
        Task {
            // Use the proper method to set the queue update handler
            await importQueueActor.setQueueUpdateHandler { queue in
                Task { @MainActor in
                    // Log queue updates
                    VLOG("GameImporter: Import queue updated with \(queue.count) items")
                }
            }
        }
        #endif

        //create defaults
        createDefaultDirectories(fm: fm)

        //set service dependencies
        gameImporterDatabaseService.setRomsPath(url: romsPath)

        gameImporterArtworkImporter.setSystemsService(gameImporterSystemsService)

        // Now set up the actual auto-start callback implementation
        Task {
            await importQueueActor.setAutoStartCallback { [weak self] in
                guard let self = self else { return }

                Task {
                    ILOG("GameImporter: Auto-start callback triggered")

                    // Always try to start processing - startProcessingSafely will handle state checks
                    await self.startProcessingSafely(trigger: "auto")
                }
            }
        }

        // Listen for items being requeued (e.g., when user selects system for partial item)
        NotificationCenter.default.addObserver(
            forName: .GameImporterQueueItemRequeued,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            Task {
                ILOG("GameImporter: Queue item requeued, restarting processing if needed")
                await self.restartProcessingIfQueueHasPendingWork(context: "item-requeued")
            }
        }
    }


    /// Creates default directories
    private func createDefaultDirectories(fm: FileManager) {
        // Core roots
        createDefaultDirectory(fm, url: romsPath)
        createDefaultDirectory(fm, url: romsImportPath)
        createDefaultDirectory(fm, url: biosPath)

        // Additional roots
        createDefaultDirectory(fm, url: Paths.saveSavesPath)
        createDefaultDirectory(fm, url: Paths.batterySavesPath)
        createDefaultDirectory(fm, url: Paths.screenShotsPath)

        // DeltaSkins directory
        let deltaSkinsURL = URL.documentsPath.appendingPathComponent("DeltaSkins", isDirectory: true)
        createDefaultDirectory(fm, url: deltaSkinsURL)

        // Per-system ROM subfolders
        for system in PVSystem.all {
            let systemDir = Paths.romsPath(forSystemIdentifier: system.identifier)
            createDefaultDirectory(fm, url: systemDir)
        }
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
    @MainActor
    public func initSystems() async {
        initialized.enter()

        do {
            try await RealmProvider.ensureInitialized()
        } catch {
            ELOG("GameImporter: Failed to initialize Realm before initSystems: \(error.localizedDescription)")
            initialized.leave()
            return
        }

        await self.initCorePlists()

        /// Updates the system to path map
        @MainActor
        @Sendable func updateSystemToPathMap() async -> [String: URL] {
            let systems = PVSystem.all.toArray()
            return await systems.async.reduce(into: [String: URL]()) {partialResult, system in
                partialResult[system.identifier] = system.romsDirectory
            }
        }

        /// Updates the ROM extension to systems map
        @MainActor
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

        let systems = PVSystem.all

        self.notificationToken = systems.observe { [unowned self] (changes: RealmCollectionChange) in
            switch changes {
            case .initial:
                Task { @MainActor in
                    ILOG("RealmCollection changed state to .initial")
                    self.systemToPathMap = await updateSystemToPathMap()
                    self.initialized.leave()

                    // Set up the queue subscription after all members are initialized
                    self.setupQueueSubscription()
                }
            case .update:
                Task { @MainActor in
                    ILOG("RealmCollection changed state to .update")
                    self.systemToPathMap = await updateSystemToPathMap()
                }
            case let .error(error):
                ELOG("RealmCollection changed state to .error")
                fatalError("\(error)")
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

        // Check for duplicates in queue first (applies to all files, including imports folder)
        // This prevents re-adding files that are already being processed
        var itemsToAdd: [ImportQueueItem] = []
        let currentQueue = await importQueueActor.getQueue()

        for item in newItems {
            let isDuplicateInQueue = currentQueue.contains { existing in
                // Check if URL matches
                if existing.url == item.url {
                    return true
                }
                // Check if filename and directory match
                if existing.url.lastPathComponent == item.url.lastPathComponent &&
                    existing.url.deletingLastPathComponent() == item.url.deletingLastPathComponent() {
                    return true
                }
                // Check MD5 if available
                if let existingMd5 = existing.md5?.uppercased(),
                   let itemMd5 = item.md5?.uppercased(),
                   existingMd5 == itemMd5 {
                    return true
                }
                return false
            }

            if !isDuplicateInQueue {
                itemsToAdd.append(item)
            }
        }

        if itemsToAdd.count < newItems.count {
            let skippedCount = newItems.count - itemsToAdd.count
            ILOG("GameImporter: Skipped \(skippedCount) file(s) already in import queue")
        }

        // Fast-path: Check if all remaining files are in imports folder (new files, skip expensive batch check)
        let allInImports = itemsToAdd.allSatisfy { $0.url.path.contains("/Imports/") }

        if allInImports {
            // Files in imports folder are new, skip expensive batch duplicate check
            // Individual thorough checks will happen in addImportItemToQueue
            ILOG("GameImporter: All \(itemsToAdd.count) files are in imports folder, skipping batch duplicate check")
            newItems = itemsToAdd
        } else {
            // Batch check for existing games before adding to queue (more efficient for ROMs folder scans)
            let existingURLs = await batchCheckExistingGames(itemsToAdd)
            let finalItemsToAdd = itemsToAdd.filter { !existingURLs.contains($0.url) }

            if existingURLs.count > 0 {
                let fileNames = existingURLs.map { $0.lastPathComponent }.prefix(3).joined(separator: ", ")
                let moreFiles = existingURLs.count > 3 ? " and \(existingURLs.count - 3) more" : ""
                ILOG("Skipping \(existingURLs.count) file(s) that already exist in library: \(fileNames)\(moreFiles)")
                await MainActor.run {
                    self.updateImporterStatus("Skipped \(existingURLs.count) duplicate file(s)")
                }
            }

            // Update newItems to only include items to add
            newItems = finalItemsToAdd
        }

        // Add items to queue (will do quick checks for imports folder files)
        for item in newItems {
            await self.addImportItemToQueue(item)
        }

        // Then re-run preProcessQueue to ensure proper organization with the new items
        await preProcessQueue()
    }

    public func addImports(forPaths paths: [URL], targetSystem: SystemIdentifier) async {
        // Check if paused for emulation
        let pausedForEmulation = await MainActor.run { isPausedForEmulation }
        if pausedForEmulation {
            ILOG("GameImporter: Skipping addImports - paused for emulation")
            return
        }

        var newItems: [ImportQueueItem] = []
        for path in paths {
            var item = ImportQueueItem(url: path, fileType: .unknown)
            item.userChosenSystem = targetSystem
            newItems.append(item)
        }

        ILOG("GameImporter: addImports called with \(paths.count) paths for system \(targetSystem.rawValue)")

        // Check for duplicates in queue first (applies to all files)
        // This prevents re-adding files that are already being processed
        var itemsToCheck: [ImportQueueItem] = []
        let currentQueue = await importQueueActor.getQueue()

        for item in newItems {
            let isDuplicateInQueue = currentQueue.contains { existing in
                // Check if URL matches
                if existing.url == item.url {
                    return true
                }
                // Check if filename and directory match
                if existing.url.lastPathComponent == item.url.lastPathComponent &&
                    existing.url.deletingLastPathComponent() == item.url.deletingLastPathComponent() {
                    return true
                }
                // Check MD5 if available
                if let existingMd5 = existing.md5?.uppercased(),
                   let itemMd5 = item.md5?.uppercased(),
                   existingMd5 == itemMd5 {
                    return true
                }
                return false
            }

            if !isDuplicateInQueue {
                itemsToCheck.append(item)
            }
        }

        if itemsToCheck.count < newItems.count {
            let skippedCount = newItems.count - itemsToCheck.count
            ILOG("GameImporter: Skipped \(skippedCount) file(s) already in import queue (target system: \(targetSystem.rawValue))")
        }

        /// Batch check for existing games before adding to queue (more efficient)
        let existingURLs = await batchCheckExistingGames(itemsToCheck)
        let itemsToAdd = itemsToCheck.filter { !existingURLs.contains($0.url) }

        if existingURLs.count > 0 {
            let fileNames = existingURLs.map { $0.lastPathComponent }.prefix(3).joined(separator: ", ")
            let moreFiles = existingURLs.count > 3 ? " and \(existingURLs.count - 3) more" : ""
            ILOG("GameImporter: Skipping \(existingURLs.count) file(s) that already exist in library: \(fileNames)\(moreFiles) (target system: \(targetSystem.rawValue))")
            await MainActor.run {
                self.updateImporterStatus("Skipped \(existingURLs.count) duplicate file(s)")
            }
        }

        ILOG("GameImporter: Adding \(itemsToAdd.count) files to queue after filtering (from \(paths.count) total)")

        // Add filtered items to queue
        var addedCount = 0
        var skippedCount = 0
        for item in itemsToAdd {
            let beforeCount = await importQueueActor.getQueue().count
            await self.addImportItemToQueue(item)
            let afterCount = await importQueueActor.getQueue().count
            if afterCount > beforeCount {
                addedCount += 1
            } else {
                skippedCount += 1
                VLOG("GameImporter: File \(item.url.lastPathComponent) was not added to queue (duplicate check or other filter)")
            }
        }

        ILOG("GameImporter: Successfully added \(addedCount) items to queue, \(skippedCount) were skipped (duplicates/filters)")

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
        Task {
            ILOG("GameImporter: startProcessing() called (manual BEGIN button)")

            // Force kill any stuck tasks first
            processingTaskLock.lock()
            if let existingTask = currentProcessingTask {
                let isRunning = !existingTask.isCancelled
                ILOG("GameImporter: BEGIN button - killing existing task (running: \(isRunning))")
                existingTask.cancel()
                currentProcessingTask = nil
                currentTimeoutTask?.cancel()
                currentTimeoutTask = nil
                processingStartTime = nil
            }
            processingTaskLock.unlock()

            // Reset state to idle so we can start fresh
            await MainActor.run {
                self.processingState = .idle
            }

            // Now start processing
            await startProcessingSafely(trigger: "manual-begin")
        }
    }

    private func hasActiveProcessingTask() -> Bool {
        processingTaskLock.lock()
        defer { processingTaskLock.unlock() }
        guard let task = currentProcessingTask else { return false }
        return !task.isCancelled
    }

    private func normalizedProcessingState(reason: String) async -> ProcessingState {
        let state = await MainActor.run { processingState }
        guard state == .processing else {
            return state
        }

        // Check if we have an active task
        let hasActiveTask = hasActiveProcessingTask()

        // Also check if we have queued items - if we do and task seems stuck, kill it
        let queueSnapshot = await importQueueActor.getQueue()
        let queuedItems = queueSnapshot.filter { $0.status == .queued }

        if !hasActiveTask {
            await MainActor.run {
                self.processingState = .idle
                self.updateImporterStatus("Import queue recovered (\(reason))")
            }
            ILOG("GameImporter: Reset stale processing state (\(reason)) - no active processing task")
            return .idle
        }

        // If we have queued items but task has been running for a while, check if it's stuck
        if !queuedItems.isEmpty {
            processingTaskLock.lock()
            let startTime = processingStartTime
            processingTaskLock.unlock()

            if let startTime = startTime {
                let elapsed = Date().timeIntervalSince(startTime)
                // If task has been running for more than 30 seconds with queued items, it's probably stuck
                if elapsed > 30 {
                    ILOG("GameImporter: Detected stuck processing task (running for \(String(format: "%.1f", elapsed))s with \(queuedItems.count) queued items) - killing and restarting")

                    // Kill the stuck task
                    processingTaskLock.lock()
                    currentProcessingTask?.cancel()
                    currentProcessingTask = nil
                    currentTimeoutTask?.cancel()
                    currentTimeoutTask = nil
                    processingStartTime = nil
                    processingTaskLock.unlock()

                    await MainActor.run {
                        self.processingState = .idle
                    }

                    return .idle
                }
            }
        }

        return state
    }

    private func restartProcessingIfQueueHasPendingWork(context: String) async {
        let queueSnapshot = await importQueueActor.getQueue()
        let queuedItems = queueSnapshot.filter { $0.status == .queued }
        guard !queuedItems.isEmpty else { return }

        let currentState = await MainActor.run { processingState }
        guard currentState == .idle else {
            VLOG("GameImporter: Skipping auto-restart (\(context)) - state \(currentState)")
            return
        }

        var restartDelay: TimeInterval?
        processingTaskLock.lock()
        if let nextAvailable = autoRestartAvailableAt {
            let delta = nextAvailable.timeIntervalSinceNow
            if delta > 0 {
                restartDelay = delta
            } else {
                autoRestartAvailableAt = nil
            }
        }
        processingTaskLock.unlock()

        if let delay = restartDelay {
            ILOG("GameImporter: Delaying auto-restart (\(context)) by \(String(format: "%.2f", delay))s")
            Task.detached { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(delay))
                await self.restartProcessingIfQueueHasPendingWork(context: context)
            }
            return
        }

        ILOG("GameImporter: Auto-restarting processing (\(context)) for \(queuedItems.count) queued item(s)")
        await startProcessingSafely(trigger: context)
    }

    // Thread-safe method to start processing with proper task management
    private func startProcessingSafely(trigger: String = "manual") async {
        ILOG("GameImporter: startProcessingSafely called (trigger: \(trigger))")

        // Check state on main actor, normalizing when needed
        let currentState = await normalizedProcessingState(reason: trigger)
        ILOG("GameImporter: Normalized state: \(currentState)")

        // If we're paused, check if we should auto-resume
        if currentState == .paused {
            // Don't auto-resume if paused for emulation
            let pausedForEmulation = await MainActor.run { isPausedForEmulation }
            if pausedForEmulation {
                ILOG("GameImporter: Skipping auto-resume - paused for emulation")
                return
            }
            ILOG("GameImporter: Resuming from paused state")
            await resumeSafely()
            return
        }

        // Check queue before checking task status
        let queueSnapshot = await importQueueActor.getQueue()
        let queuedCount = queueSnapshot.filter { $0.status == .queued }.count

        // Use lock ONLY for checking/setting task reference - release before async operations
        let shouldStart: Bool = {
            processingTaskLock.lock()
            defer { processingTaskLock.unlock() }

            // Double-check we don't already have a processing task
            if let existingTask = currentProcessingTask {
                let isRunning = !existingTask.isCancelled
                ILOG("GameImporter: Existing processing task found (running: \(isRunning))")

                // Check if task is actually making progress
                if let startTime = processingStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)

                    // If task has been running for more than 10 seconds with queued items, it's stuck
                    if elapsed > 10 && queuedCount > 0 {
                        ILOG("GameImporter: Task appears stuck (running \(String(format: "%.1f", elapsed))s with \(queuedCount) queued) - killing it")
                        existingTask.cancel()
                        currentProcessingTask = nil
                        currentTimeoutTask?.cancel()
                        currentTimeoutTask = nil
                        processingStartTime = nil
                        return true
                    }
                }

                if !isRunning {
                    // Task exists but is cancelled/completed - clear it
                    currentProcessingTask = nil
                    return true
                }
                return false
            }
            return true
        }()

        guard shouldStart else {
            ILOG("GameImporter: Skipping start processing (\(trigger)) - task already running")
            return
        }

        processingTaskLock.lock()
        autoRestartAvailableAt = nil
        processingTaskLock.unlock()

        ILOG("GameImporter: Starting processing safely (\(trigger))")

        // Set state to processing on main actor (lock released, safe to await)
        await MainActor.run {
            self.processingState = .processing
        }

        // Record processing start time and create tasks (lock released, safe to do async work)
        let startTime = Date()

        // Create and store the processing task
        let processingTask = Task.detached { [weak self] in
            guard let self = self else { return }

            defer {
                // Clean up task references when done
                self.processingTaskLock.lock()
                self.currentProcessingTask = nil
                self.currentTimeoutTask?.cancel()
                self.currentTimeoutTask = nil
                self.processingStartTime = nil
                self.processingTaskLock.unlock()

                Task { [weak self] in
                    await self?.restartProcessingIfQueueHasPendingWork(context: "post-run")
                }
            }

            // Preprocess queue first (fast with generation tracking)
            await self.preProcessQueue()
            // Then process items continuously until queue is empty
            await self.processQueue()
        }

        // Create timeout task to detect hung processing
        let timeoutTask = Task.detached { [weak self] in
            guard let self = self else { return }

            // Wait for timeout duration
            do {
                try await Task.sleep(for: .seconds(self.processingTimeoutDuration))
            } catch {
                // Task was cancelled (normal completion)
                return
            }

            // Check if processing task is still running
            await self.handleProcessingTimeout()
        }

        // Store task references while holding lock (minimal lock scope)
        processingTaskLock.lock()
        currentProcessingTask = processingTask
        currentTimeoutTask = timeoutTask
        processingStartTime = startTime
        processingTaskLock.unlock()
    }

    /// Handles timeout recovery when processing task hangs
    private func handleProcessingTimeout() async {
        processingTaskLock.lock()
        defer { processingTaskLock.unlock() }

        // Check if we still have a processing task (it might have completed just before timeout)
        guard let processingTask = currentProcessingTask else {
            VLOG("GameImporter: Timeout triggered but processing task already completed")
            return
        }

        let startTime = processingStartTime ?? Date()
        let duration = Date().timeIntervalSince(startTime)

        ELOG("GameImporter: Processing task timeout detected after \(Int(duration)) seconds (limit: \(Int(processingTimeoutDuration))s)")
        ELOG("GameImporter: Cancelling hung processing task and resetting state")

        // Cancel the hung processing task
        processingTask.cancel()

        // Clean up task references
        currentProcessingTask = nil
        currentTimeoutTask = nil
        processingStartTime = nil

        // Reset state to idle on main actor with helpful message
        await MainActor.run {
            self.processingState = .idle
            self.updateImporterStatus("Import processing timed out. Check the import queue for any failed items and try again.")
        }

        /// Post notification about timeout with user-friendly message
        NotificationCenter.default.post(
            name: .GameImporterDidFinish,
            object: nil,
            userInfo: [
                "reason": "timeout_recovery",
                "message": "Import processing took too long and was cancelled. Check the import queue and try importing files in smaller batches."
            ]
        )

        ILOG("GameImporter: Processing state reset to idle after timeout recovery")

        // Optionally restart processing after a brief delay to avoid immediate re-hang
        // Only restart if there are items in the queue
        let queue = await importQueueActor.getQueue()
        let queuedItemsCount = queue.filter { $0.status == .queued || $0.userChosenSystem != nil }.count
        if queuedItemsCount > 0 {
            ILOG("GameImporter: Scheduling delayed restart after timeout recovery (\(queuedItemsCount) items in queue)")
            processingTaskLock.lock()
            autoRestartAvailableAt = Date().addingTimeInterval(5)
            processingTaskLock.unlock()

            Task.detached { [weak self] in
                await self?.restartProcessingIfQueueHasPendingWork(context: "timeout")
            }
        }
    }

    // MARK: Processing functions
    //    @MainActor
    private func preProcessQueue() async {
        ILOG("GameImporter: preProcessQueue() called")
        var retryCount = 0
        let maxRetries = 10 // Prevent infinite loops

        while retryCount < maxRetries {
            retryCount += 1
            if retryCount > 1 {
                ILOG("GameImporter: preProcessQueue() retry #\(retryCount)")
            }

            // Get the current queue snapshot with generation tracking
            let snapshot = await importQueueActor.getQueueSnapshot()
            var workQueue = snapshot.queue
            let snapshotGeneration = snapshot.generation
            ILOG("GameImporter: preProcessQueue() - snapshot has \(workQueue.count) items, generation \(snapshotGeneration)")

            if let lastGeneration = lastPreprocessedQueueGeneration,
               lastGeneration == snapshotGeneration {
                ILOG("GameImporter: Skipping queue preprocessing (generation \(snapshotGeneration) already processed)")
                return
            }

            // Process each item to determine its type using adaptive concurrency
            ILOG("GameImporter: preProcessQueue() - determining file types for \(workQueue.count) items")
            let sizeThreshold = 64
            if workQueue.count > sizeThreshold {
                let processorCount = max(ProcessInfo.processInfo.activeProcessorCount, 2)
                let chunkSize = max(workQueue.count / processorCount, 16)

                await withTaskGroup(of: Void.self) { group in
                    for chunkStart in stride(from: 0, to: workQueue.count, by: chunkSize) {
                        let chunkEnd = min(chunkStart + chunkSize, workQueue.count)
                        group.addTask { [self] in
                            for i in chunkStart..<chunkEnd {
                                let currentType = workQueue[i].fileType
                                if currentType == .skin || currentType == .artwork || currentType == .bios {
                                    continue
                                }
                                workQueue[i].fileType = self.determineImportType(workQueue[i])
                            }
                        }
                    }
                    await group.waitForAll()
                }
            } else {
        for i in 0..<workQueue.count {
            let currentType = workQueue[i].fileType
            if currentType == .skin || currentType == .artwork || currentType == .bios {
                        continue
            }
                    workQueue[i].fileType = self.determineImportType(workQueue[i])
                }
        }

            ILOG("GameImporter: preProcessQueue() - file types determined, sorting and organizing")

        // Sort the queue to make sure m3us go first
        workQueue = sortImportQueueItems(workQueue)

        // CRITICAL: Process M3U files BEFORE CUE files
        self.organizeM3UFiles(in: &workQueue)

        // Then organize cue/bin files for any remaining CUEs not claimed by M3Us
        self.organizeCueAndBinFiles(in: &workQueue)

            ILOG("GameImporter: preProcessQueue() - attempting to replace queue (generation \(snapshotGeneration))")

            // Attempt to update queue only if snapshot is still current
            let didReplace = await importQueueActor.replaceQueue(ifGenerationMatches: snapshotGeneration,
                                                                 with: workQueue)

            if didReplace {
                lastPreprocessedQueueGeneration = await importQueueActor.currentGeneration()
                ILOG("GameImporter: preProcessQueue() completed successfully - \(workQueue.count) items processed")
                ILOG("Queue after preprocessing: \(workQueue.map { "\($0.url.lastPathComponent) (\($0.status.description))" })")
                return
            } else {
                ILOG("GameImporter: Queue changed during preprocessing (gen \(snapshotGeneration)), retrying")
                // Small delay to avoid tight loop
                try? await Task.sleep(for: .milliseconds(50))
            }
        }

        // If we hit max retries, log error but continue anyway
        ELOG("GameImporter: preProcessQueue() hit max retries (\(maxRetries)), continuing with current queue state")
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
                // Check both by filename and by same directory + filename (for extracted files)
                let cueDirectory = cueURL.deletingLastPathComponent()
                let potentialPathNearCue = cueDirectory.appendingPathComponent(referencedFileName)

                if let associatedItemIndex = importQueue.firstIndex(where: { item in
                    // Match by exact filename (case-insensitive)
                    item.url.lastPathComponent.lowercased() == referencedFileName.lowercased() && item.id != cueItem.id
                }) {
                    let associatedItem = importQueue[associatedItemIndex]

                    // Also check if it's in the same directory (for extracted files)
                    let isInSameDirectory = associatedItem.url.deletingLastPathComponent() == cueDirectory

                    if isInSameDirectory || associatedItem.url.lastPathComponent.lowercased() == referencedFileName.lowercased() {
                        if !cueItem.resolvedAssociatedFileURLs.contains(associatedItem.url) {
                            cueItem.resolvedAssociatedFileURLs.append(associatedItem.url)
                        }
                        // Also merge resolved files from the associated item itself
                        for resolvedURL in associatedItem.resolvedAssociatedFileURLs {
                            if !cueItem.resolvedAssociatedFileURLs.contains(resolvedURL) {
                                cueItem.resolvedAssociatedFileURLs.append(resolvedURL)
                            }
                        }
                        ILOG("Associated \(associatedItem.url.lastPathComponent) from CUE with \(cueURL.lastPathComponent)")
                        if !indicesToRemove.contains(associatedItemIndex) {
                            indicesToRemove.append(associatedItemIndex)
                        }
                        // If this file was expected, remove it from expectations
                        if var cueExpected = cueItem.expectedAssociatedFileNames {
                            cueExpected.removeAll { $0.lowercased() == referencedFileName.lowercased() }
                            cueItem.expectedAssociatedFileNames = cueExpected.isEmpty ? nil : cueExpected
                        }
                        continue // Found in queue, move to next file
                    }
                }

                // File not in queue, check on disk relative to CUE
                if cdRomFileHandler.fileExistsAtPath(potentialPathNearCue) {
                    if !cueItem.resolvedAssociatedFileURLs.contains(potentialPathNearCue) {
                        cueItem.resolvedAssociatedFileURLs.append(potentialPathNearCue)
                        ILOG("Resolved \(referencedFileName) near CUE for \(cueURL.lastPathComponent)")
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
                        ILOG("Expecting \(referencedFileName) for \(cueURL.lastPathComponent)")
                    }
                }
            }

            cueItem.resolvedAssociatedFileURLs = Array(Set(cueItem.resolvedAssociatedFileURLs))
            if var currentExpected = cueItem.expectedAssociatedFileNames, !currentExpected.isEmpty {
                currentExpected = Array(Set(currentExpected.map { $0.lowercased() })).sorted()
                cueItem.expectedAssociatedFileNames = currentExpected.isEmpty ? nil : currentExpected
            }
            cueItem.fileType = .cdRom // CUE always implies CD-ROM

            // Set CD-ROM systems for CUE files so they show the right system selection list
            if cueItem.systems.isEmpty {
                // Get all systems that support CD-ROM formats (disc images + playlists + bin tracks)
                let cdRomExtensions = Extensions.discImageExtensions
                    .union(Extensions.playlistExtensions)
                    .union([Extensions.bin.rawValue])

                let cdRomSystems = Array(PVSystem.all
                    .filter { system in
                        system.supportedExtensions.contains { ext in
                            cdRomExtensions.contains(ext.lowercased())
                        }
                    }
                    .compactMap { SystemIdentifier(rawValue: $0.identifier) })

                if !cdRomSystems.isEmpty {
                    cueItem.systems = cdRomSystems
                    ILOG("Set CD-ROM systems for CUE \(cueURL.lastPathComponent): \(cdRomSystems.map { $0.rawValue }.joined(separator: ", "))")
                }
            }

            cueItem.status = (cueItem.expectedAssociatedFileNames?.isEmpty ?? true) && allFilesFound ? .queued : .partial(expectedFiles: cueItem.expectedAssociatedFileNames ?? []) // Or some other status based on completeness

            // Remove associated files from queue BEFORE they can be processed as standalone items
            indicesToRemove.sorted(by: >).forEach { indexToRemove in
                if indexToRemove < importQueue.count { // Safety check
                    let removedItem = importQueue.remove(at: indexToRemove)
                    ILOG("Removed \(removedItem.url.lastPathComponent) from queue as it was subsumed by CUE processing for \(cueURL.lastPathComponent)")
                }
            }
            VLOG("Finished processing CUE: \(cueURL.lastPathComponent)")
            i -= 1
        }
        ILOG("Finished CUE/BIN organization.")
    }

    private struct QueueSortKey: Comparable {
        let priority: Int
        let normalizedName: String
        let fileExtension: String
        let fileName: String

        static func < (lhs: QueueSortKey, rhs: QueueSortKey) -> Bool {
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            if lhs.normalizedName != rhs.normalizedName {
                return lhs.normalizedName < rhs.normalizedName
            }
            if lhs.fileExtension != rhs.fileExtension {
                return lhs.fileExtension < rhs.fileExtension
            }
            return lhs.fileName < rhs.fileName
        }
    }

    private func extensionPriority(for ext: String) -> Int {
        if ext == Extensions.m3u.rawValue {
            return 0
        }
        if ext == Extensions.cue.rawValue {
            return 1
        }
        if Extensions.artworkExtensions.contains(ext) {
            return 4
        }
        return 2
    }

    private func sortKey(for item: ImportQueueItem) -> QueueSortKey {
        let filename = item.url.lastPathComponent
        let normalizedName = PVEmulatorConfiguration.stripDiscNames(fromFilename: filename).lowercased()
        let ext = item.url.pathExtension.lowercased()

        return QueueSortKey(
            priority: extensionPriority(for: ext),
            normalizedName: normalizedName,
            fileExtension: ext,
            fileName: filename.lowercased()
        )
    }

    public func sortImportQueueItems(_ importQueueItems: [ImportQueueItem]) -> [ImportQueueItem] {
        VLOG("sortImportQueueItems...begin")
        VLOG(importQueueItems.map { $0.url.lastPathComponent }.joined(separator: ", "))

        let sorted = importQueueItems.enumerated().sorted { lhs, rhs in
            let leftKey = sortKey(for: lhs.element)
            let rightKey = sortKey(for: rhs.element)

            if leftKey == rightKey {
                return lhs.offset < rhs.offset
            }

            return leftKey < rightKey
        }.map { $0.element }

        VLOG(sorted.map { $0.url.lastPathComponent }.joined(separator: ", "))
        VLOG("sortImportQueueItems...end")
        return sorted
    }

    // Processes items in the queue in parallel with controlled concurrency
    private func processQueue() async {
        ILOG("GameImportQueue - processQueue() called")

        // Ensure we're in processing state
            await MainActor.run {
            if self.processingState != .processing {
                ILOG("GameImporter: processQueue setting state to processing")
                self.processingState = .processing
                }
        }

        NotificationCenter.default.post(name: .GameImporterDidStart, object: nil)

        let maxConcurrentImports = 4
        let semaphore = AsyncSemaphore(value: maxConcurrentImports)
        var processedCount = 0

        // Process queue in a loop until empty or paused
        while true {
            // Check if paused
            if await checkIfPaused() {
                ILOG("GameImportQueue - processing paused")
                break
            }

            // Get current queue snapshot and filter for queued items
            let currentQueue = await importQueueActor.getQueue()
            let itemsToProcess = currentQueue.filter { $0.status == .queued }

            guard !itemsToProcess.isEmpty else {
                ILOG("GameImportQueue - No items to process, queue empty")
                break
            }

            ILOG("GameImportQueue - Processing \(itemsToProcess.count) queued item(s)")

        // Group related files that should be processed together
        let groupedItems = groupRelatedFiles(itemsToProcess)
        ILOG("Grouped \(itemsToProcess.count) items into \(groupedItems.count) processing groups")

        // Prioritize groups: small files first, CD-ROMs last
        let prioritizedGroups = prioritizeImportGroups(groupedItems)

            // Process all groups
        await withTaskGroup(of: Void.self) { group in
            for fileGroup in prioritizedGroups {
                if await checkIfPaused() {
                    break
                }

                    await semaphore.wait()

                    group.addTask { [weak self] in
                        defer { Task { await semaphore.signal() } }
                        guard let self else { return }

                    for item in fileGroup {
                            if await self.checkIfPaused() { break }
                        await self.processItem(item)
                            processedCount += 1
                    }
                }
            }

            await group.waitForAll()
        }

            // Small delay to allow new items to be added
            try? await Task.sleep(for: .milliseconds(100))
        }

        ILOG("GameImportQueue - processQueue complete, processed \(processedCount) item(s)")

        // Only change to idle if we're not paused
        await MainActor.run {
            if self.processingState != .paused {
                ILOG("GameImporter: processQueue finished, setting state to idle")
                self.processingState = .idle

                // Process enhanced artwork search queue after imports complete (lower priority)
                Task.detached(priority: .utility) {
                    try? await Task.sleep(for: .seconds(3))
                    await ArtworkSearchQueue.shared.processPendingSearches()
                }
            } else {
                ILOG("GameImporter: processQueue finished but staying paused")
            }
            NotificationCenter.default.post(name: .GameImporterDidFinish, object: nil)
        }
    }

    // Process a single ImportItem and update its status
    public func processItem(_ item: ImportQueueItem) async {
        let itemName = item.url.lastPathComponent
        ILOG("GameImportQueue - processing item in queue: \(itemName)")

        // Skip .bin files that might belong to a CUE file - they should be grouped by organizeCueAndBinFiles
        if item.url.pathExtension.lowercased() == Extensions.bin.rawValue {
            let currentQueue = await importQueueActor.getQueue()
            let cueDirectory = item.url.deletingLastPathComponent()
            let binBaseName = item.url.deletingPathExtension().lastPathComponent

            // Check if there's a CUE file in the same directory that might reference this bin
            if let cueItem = currentQueue.first(where: { cue in
                cue.url.pathExtension.lowercased() == Extensions.cue.rawValue &&
                cue.url.deletingLastPathComponent() == cueDirectory &&
                (cue.url.deletingPathExtension().lastPathComponent.lowercased() == binBaseName.lowercased() ||
                 cue.resolvedAssociatedFileURLs.contains(item.url) ||
                 cue.expectedAssociatedFileNames?.contains(where: { $0.lowercased() == item.url.lastPathComponent.lowercased() }) == true)
            }) {
                ILOG("Skipping bin file \(itemName) - it belongs to CUE file \(cueItem.url.lastPathComponent)")
                // Remove this bin file from queue - it should be handled by the CUE
                await importQueueActor.removeImport(byID: item.id)
                return
            }
        }

        // Set status to processing on main actor for thread safety
        await MainActor.run {
            item.status = .processing
            updateImporterStatus("Importing \(itemName)")
        }

        do {
            ILOG("GameImportQueue - About to call performImport for: \(itemName)")

            // Add detailed timing for debugging hangs
            let startTime = Date()
            try await performImport(for: item)
            let duration = Date().timeIntervalSince(startTime)

            ILOG("GameImportQueue - performImport completed for: \(itemName) in \(String(format: "%.2f", duration))s")

            // Compute MD5 off the main thread before posting notification
            let md5Value = await item.md5Async()
            await MainActor.run {
                if let finalSystem = item.userChosenSystem ?? item.resolvedSystem ?? item.targetSystem() {
                    item.resolvedSystem = finalSystem
                }
                item.status = .success
                item.userChosenSystem = nil
                let userInfo = [
                    PVNotificationUserInfoKeys.fileNameKey: itemName,
                    PVNotificationUserInfoKeys.md5Key: md5Value as Any,
                ]
                NotificationCenter.default.post(name: .PVGameImported, object: nil, userInfo: userInfo)
            }
            updateImporterStatus("Completed \(itemName)")
            ILOG("GameImportQueue - processing item in queue: \(itemName) completed successfully.")
        } catch let error as GameImporterError {
            let errorMd5 = await item.md5Async()
            await MainActor.run {
                switch error {
                case .conflictDetected:
                    item.status = .conflict
                    updateImporterStatus("Conflict detected for \(itemName). This file matches multiple systems. Please select the correct system in the import queue.")
                    WLOG("GameImportQueue - processing item in queue: \(itemName) resulted in conflict.")

                case .waitingForAssociatedFiles(let expectedFiles):
                    item.status = .partial(expectedFiles: expectedFiles)
                    let fileList = expectedFiles.prefix(3).joined(separator: ", ")
                    let moreFiles = expectedFiles.count > 3 ? " and \(expectedFiles.count - 3) more" : ""
                    updateImporterStatus("Waiting for required files for \(itemName): \(fileList)\(moreFiles)")
                    ILOG("GameImportQueue - item \(itemName) is waiting for associated files: \(expectedFiles.joined(separator: ", ")).")

                default:
                    item.status = .failure(error: error)
                    updateImporterStatus("Failed \(itemName) with error: \(error.localizedDescription)")
                    ELOG("GameImportQueue - processing item in queue: \(itemName) failed. Error: \(error.localizedDescription)")
                }

                if case .waitingForAssociatedFiles = error {
                } else {
                    let userInfo: [String: Any] = [
                        PVNotificationUserInfoKeys.fileNameKey: itemName,
                        PVNotificationUserInfoKeys.md5Key: errorMd5 as Any,
                        PVNotificationUserInfoKeys.errorKey: error.localizedDescription
                    ]
                    NotificationCenter.default.post(name: .GameImporterFileDidFail, object: nil, userInfo: userInfo)
                }
            }
        } catch {
            ELOG("GameImportQueue - processing item in queue: \(itemName) caught unexpected error: \(error.localizedDescription)")

            let errorMd5 = await item.md5Async()
            await MainActor.run {
                item.status = .failure(error: error)
                updateImporterStatus("Failed \(itemName) with error: \(error.localizedDescription)")

                let userInfo: [String: Any] = [
                    PVNotificationUserInfoKeys.fileNameKey: itemName,
                    PVNotificationUserInfoKeys.md5Key: errorMd5 as Any,
                    PVNotificationUserInfoKeys.errorKey: error.localizedDescription
                ]
                NotificationCenter.default.post(name: .GameImporterFileDidFail, object: nil, userInfo: userInfo)
            }
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

            // Track bin files to process after Realm work
            var binFilesToProcess: [URL] = []
            var processingFailed = false

            do {
                // Step 1: Sync Realm work - get game info, move file, update database
                let result: (destinationURL: URL, gameTitle: String)? = try await RealmContext.withBackgroundRealm { realm in
                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: gameID) else {
                        ELOG("Cannot handle late associated file \(fileURL.lastPathComponent): PVGame with ID \(gameID) not found.")
                        return nil
                    }

                    var destinationDirectory: URL? = nil
                    if let primaryFileURL = game.file?.url, !primaryFileURL.path.isEmpty {
                        destinationDirectory = primaryFileURL.deletingLastPathComponent()
                    } else if let firstRelatedFileURL = game.relatedFiles.first(where: { $0.url?.path.isEmpty == false })?.url {
                        destinationDirectory = firstRelatedFileURL.deletingLastPathComponent()
                    }

                    guard let validDestinationDirectory = destinationDirectory else {
                        ELOG("Cannot determine destination directory for late associated file \(fileURL.lastPathComponent) for game \(game.title ?? "Unknown"): No existing file paths found for the game.")
                        return nil
                    }

                    let destinationFileURL = validDestinationDirectory.appendingPathComponent(fileURL.lastPathComponent)

                    let destPathString = destinationFileURL.path
                    DLOG("Moving late-arriving file from \(fileURL.path) to \(destPathString)")
                    try FileManager.default.moveItem(at: fileURL, to: destinationFileURL)

                    let newPVFile = PVFile(withURL: destinationFileURL, relativeRoot: .platformDefault)

                    try realm.write {
                        realm.add(newPVFile, update: Realm.UpdatePolicy.modified)
                        if !game.relatedFiles.contains(where: { $0.url == newPVFile.url }) {
                            game.relatedFiles.append(newPVFile)
                        }
                    }

                    return (destinationFileURL, game.title ?? "Unknown")
                }

                guard let result = result else { return }

                ILOG("Successfully processed late-arriving file \(result.destinationURL.lastPathComponent) for game \(result.gameTitle).")

                if !item.resolvedAssociatedFileURLs.contains(result.destinationURL) {
                    item.resolvedAssociatedFileURLs.append(result.destinationURL)
                }

                if var expectedFiles = item.expectedAssociatedFileNames {
                    expectedFiles.removeAll { $0.lowercased() == fileURL.lastPathComponent.lowercased() }
                    item.expectedAssociatedFileNames = expectedFiles.isEmpty ? nil : expectedFiles
                }

                // Collect bin files to process
                if isCueFile && !binFilesToCheck.isEmpty {
                    for binFileName in binFilesToCheck {
                        let binFileInImports = self.importsPath.appendingPathComponent(binFileName)
                        if FileManager.default.fileExists(atPath: binFileInImports.path) {
                            ILOG("Found BIN file \(binFileName) in imports directory for late-arriving CUE \(fileURL.lastPathComponent)")
                            binFilesToProcess.append(binFileInImports)
                        } else {
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
                ELOG("Error processing late-arriving file \(fileURL.lastPathComponent) for game ID \(gameID): \(error.localizedDescription)")
                processingFailed = true
            }

            // Step 2: Async work outside Realm closure
            if processingFailed {
                await addImportItemToQueue(ImportQueueItem(url: fileURL, fileType: .unknown))
            }

            for binFileURL in binFilesToProcess {
                await handleLateAssociatedFile(fileURL: binFileURL, forCompletedItem: item)
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
        // Check skins first - trivial extension/directory check, no expensive operations needed
        if isSkin(item) { return .skin }
        // Check artwork next - also trivial extension check
        if isArtwork(item) { return .artwork }
        // BIOS check is expensive (database lookups, MD5 checks), so do it after cheap checks
        if isBIOS(item) { return .bios }
        if isCDROM(item) { return .cdRom } // Covers .cue, .m3u, .iso, .chd etc.

        // Check for zip files - if in a system directory that supports zip-as-ROM, treat as game
        if item.url.pathExtension.lowercased() == "zip" {
            // Check if file is in a system directory that supports zip
            if let systemFromPath = SystemIdentifier(rawValue: item.url.deletingLastPathComponent().lastPathComponent),
               let pvSystem = PVSystem.all.first(where: { $0.identifier == systemFromPath.rawValue }),
               pvSystem.supportedExtensions.contains("zip") {
                // This is a zip-as-ROM file, treat it as a game
                return .game
            }
            // Check if user explicitly chose a system that supports zip
            if let userSystem = item.userChosenSystem,
               let pvSystem = PVSystem.all.first(where: { $0.identifier == userSystem.rawValue }),
               pvSystem.supportedExtensions.contains("zip") {
                // User chose a system that supports zip, treat as game
                return .game
            }
            // Otherwise, treat as archive that needs extraction
            return .zip
        }

        // Check for other archive types
        if Extensions.archiveExtensions.contains(item.url.pathExtension.lowercased()) { return .zip }

        if !item.url.pathExtension.isEmpty { return .game } // Default to .game if has an extension and not other types
        return .unknown
    }

    /// Checks if an archive should be kept as-is (e.g., MAME ROMs) or extracted
    /// Uses ArchiveZipSupportChecker to determine if archive is the ROM itself
    /// Returns the matching system identifier if archive should be kept as-is, nil if it should be extracted
    private func checkArchiveMatch(_ item: ImportQueueItem) async -> SystemIdentifier? {
        let fileExtension = item.url.pathExtension.lowercased()

        // Only check zip, 7z, and rar archives
        guard Extensions.archiveExtensions.contains(fileExtension) else {
            return nil
        }

        // Use ArchiveZipSupportChecker to determine if this archive should be kept as-is
        // This handles MAME/CPS1/2/3 ROMs that are stored as zip files
        let (shouldKeep, systemID) = await ArchiveZipSupportChecker.shared.shouldKeepArchiveAsIs(item.url)

        if shouldKeep, let systemID = systemID {
            ILOG("Archive \(item.url.lastPathComponent) should be kept as-is for system \(systemID.rawValue)")
            return systemID
        }

        // Archive should be extracted - return nil to trigger extraction
        ILOG("Archive \(item.url.lastPathComponent) should be extracted (not a ROM archive)")
        return nil
    }

    /// Extracts an archive flatly and imports its contents
    private func extractAndImportArchive(_ item: ImportQueueItem) async throws {
        let archiveURL = item.url
        let fileExtension = archiveURL.pathExtension.lowercased()

        ILOG("Extracting archive \(archiveURL.lastPathComponent) for import")

        // Verify file exists and is readable
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            ELOG("Archive file does not exist: \(archiveURL.path)")
            throw GameImporterError.unsupportedFile
        }

        // Ensure file is fully written and not locked before attempting extraction
        // Add a small delay to ensure file system has finished writing
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay

        // Try to verify file is readable and not locked
        // Attempt to open the file multiple times if needed
        var fileReadable = false
        for attempt in 1...5 {
            // Try to read file attributes first (less intrusive than opening a handle)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: archiveURL.path),
               let fileSize = attributes[.size] as? Int64,
               fileSize > 0 {
                // File exists and has size, try to open it
                if let fileHandle = try? FileHandle(forReadingFrom: archiveURL) {
                    fileHandle.closeFile()
                    // Small delay after closing to ensure file handle is fully released
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                    fileReadable = true
                    break
                } else {
                    ILOG("Archive file appears locked (attempt \(attempt)/5), waiting...")
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                }
            } else {
                ILOG("Archive file has no size or invalid attributes (attempt \(attempt)/5), waiting...")
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            }
        }

        guard fileReadable else {
            let error = ArchiveError.extractionFailed("Archive file is locked or not readable: \(archiveURL.lastPathComponent). Please ensure the file is not being accessed by another process.")
            ELOG(error.localizedDescription)
            throw error
        }

        // Detect actual archive type from file signature (not just extension)
        // This handles cases where files have wrong extensions (e.g., .zip file that's actually 7z)
        let detectedArchiveType: ArchiveType?
        if let fileHandle = try? FileHandle(forReadingFrom: archiveURL) {
            let signature = fileHandle.readData(ofLength: 4)
            fileHandle.closeFile()

            // Detect archive type from signature
            if signature.count >= 2 {
                if signature[0] == 0x50 && signature[1] == 0x4B {
                    // ZIP signature: PK (0x50 0x4B)
                    detectedArchiveType = .zip
                    ILOG("Detected ZIP archive from signature: \(archiveURL.lastPathComponent)")
                } else if signature.count >= 4 && signature[0] == 0x37 && signature[1] == 0x7A && signature[2] == 0xBC && signature[3] == 0xAF {
                    // 7z signature: 37 7A BC AF
                    detectedArchiveType = .sevenZip
                    ILOG("Detected 7z archive from signature (file has .\(fileExtension) extension): \(archiveURL.lastPathComponent)")
                } else {
                    // Try extension-based detection as fallback
                    detectedArchiveType = ArchiveType(rawValue: fileExtension)
                    if detectedArchiveType != nil {
                        ILOG("Using extension-based detection for \(archiveURL.lastPathComponent): \(detectedArchiveType!.rawValue)")
                    }
                }
            } else {
                detectedArchiveType = ArchiveType(rawValue: fileExtension)
            }
        } else {
            // Fallback to extension-based detection if we can't read the file
            detectedArchiveType = ArchiveType(rawValue: fileExtension)
        }

        guard let archiveType = detectedArchiveType else {
            ELOG("Unsupported archive type: \(fileExtension) - \(archiveURL.lastPathComponent)")
            throw GameImporterError.unsupportedFile
        }

        // Check if RAR is requested (not currently supported)
        if archiveType == .rar {
            ELOG("RAR extraction is not currently supported. Please extract manually or convert to ZIP/7Z.")
            throw ArchiveError.extractionFailed("RAR extraction is not supported. Please extract manually or convert to ZIP/7Z.")
        }

        // Create extractors (these are internal classes in PVLibrary module)
        let extractors: [ArchiveType: ArchiveExtractor] = [
            .zip: ZipExtractor(),
            .sevenZip: SevenZipExtractor(),
            .tar: TarExtractor(),
            .bzip2: BZip2Extractor(),
            .gzip: GZipExtractor()
        ]

        guard let extractor = extractors[archiveType] else {
            ELOG("No extractor available for archive type: \(archiveType.rawValue)")
            throw ArchiveError.extractionFailed("No extractor available for archive type: \(archiveType.rawValue)")
        }

        // Extract to temp directory
        let tempExtractionDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchiveExtraction")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempExtractionDir, withIntermediateDirectories: true, attributes: nil)

        defer {
            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempExtractionDir)
        }

        // Extract files flatly (preserve only filenames, flatten directory structure)
        var extractedFiles: [URL] = []
        var extractionError: Error?
        // Track processed filenames to detect legitimate conflicts (multiple files with same name in archive)
        var processedFilenames = Set<String>()

        do {
            // For 7z files, add a small delay after extraction to ensure async writes complete
            // This is a workaround for SevenZipExtractor's async Task issue
            let is7z = archiveType == .sevenZip

            ILOG("Starting extraction stream for \(archiveType.rawValue) archive")
            var fileCount = 0

            for try await extractedFile in extractor.extract(at: archiveURL, to: tempExtractionDir, progress: { [weak self] progress in
                let progressPercent = Int(progress * 100)
                VLOG("Extraction progress: \(progressPercent)%")
                Task { @MainActor in
                    self?.updateImporterStatus("Extracting \(archiveURL.lastPathComponent): \(progressPercent)%")
                }
            }) {
                fileCount += 1
                VLOG("Received extracted file #\(fileCount): \(extractedFile.path)")

                // For 7z files, wait a bit to ensure file writes complete (workaround for async Task bug)
                if is7z {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay per file
                }

                // Verify extracted file exists
                var fileExists = FileManager.default.fileExists(atPath: extractedFile.path)
                if !fileExists {
                    WLOG("Extracted file does not exist: \(extractedFile.path)")
                    // For 7z, wait longer and retry once
                    if is7z {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                        fileExists = FileManager.default.fileExists(atPath: extractedFile.path)
                        if fileExists {
                            VLOG("File appeared after delay: \(extractedFile.path)")
                        } else {
                            continue
                        }
                    } else {
                        continue
                    }
                }

                guard fileExists else {
                    continue
                }

                // Skip directories
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: extractedFile.path, isDirectory: &isDirectory),
                      !isDirectory.boolValue else {
                    VLOG("Skipping directory: \(extractedFile.path)")
                    continue
                }

                // Flatten: only use filename, ignore directory structure
                let fileName = extractedFile.lastPathComponent
                let flatDestination = tempExtractionDir.appendingPathComponent(fileName)

                // If file is in a subdirectory, move it to the root
                if extractedFile.deletingLastPathComponent() != tempExtractionDir {
                    // Only rename if we've already processed a file with this name in this extraction session
                    // This prevents false positives from file system checks
                    var finalFlatURL = flatDestination
                    if processedFilenames.contains(fileName.lowercased()) {
                        // Legitimate conflict: multiple files with same name in archive
                        var counter = 1
                        let nameWithoutExt = flatDestination.deletingPathExtension().lastPathComponent
                        let ext = flatDestination.pathExtension
                        repeat {
                            finalFlatURL = tempExtractionDir.appendingPathComponent("\(nameWithoutExt)_\(counter).\(ext)")
                            counter += 1
                        } while processedFilenames.contains(finalFlatURL.lastPathComponent.lowercased())
                    }

                    if extractedFile != finalFlatURL {
                        try FileManager.default.moveItem(at: extractedFile, to: finalFlatURL)
                    }
                    extractedFiles.append(finalFlatURL)
                    processedFilenames.insert(finalFlatURL.lastPathComponent.lowercased())
                } else {
                    // File is already in root - check if we've seen this filename before
                    if processedFilenames.contains(fileName.lowercased()) {
                        // Legitimate conflict: rename it
                        var counter = 1
                        let nameWithoutExt = flatDestination.deletingPathExtension().lastPathComponent
                        let ext = flatDestination.pathExtension
                        var finalFlatURL = flatDestination
                        repeat {
                            finalFlatURL = tempExtractionDir.appendingPathComponent("\(nameWithoutExt)_\(counter).\(ext)")
                            counter += 1
                        } while FileManager.default.fileExists(atPath: finalFlatURL.path) || processedFilenames.contains(finalFlatURL.lastPathComponent.lowercased())

                        try FileManager.default.moveItem(at: extractedFile, to: finalFlatURL)
                        extractedFiles.append(finalFlatURL)
                        processedFilenames.insert(finalFlatURL.lastPathComponent.lowercased())
                    } else {
                        extractedFiles.append(extractedFile)
                        processedFilenames.insert(fileName.lowercased())
                    }
                }
            }

            ILOG("Extraction stream completed. Processed \(fileCount) files, \(extractedFiles.count) valid files")

            // For 7z files, add additional delay at end to ensure all async writes complete
            if is7z {
                ILOG("Waiting for 7z async writes to complete...")
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
                // Re-verify files exist after delay and scan directory for any missed files
                let existingFiles = extractedFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
                if existingFiles.count != extractedFiles.count {
                    WLOG("Some 7z files disappeared after delay. Original: \(extractedFiles.count), After delay: \(existingFiles.count)")
                    // Try to find files in the temp directory
                    if let dirContents = try? FileManager.default.contentsOfDirectory(at: tempExtractionDir, includingPropertiesForKeys: nil) {
                        let foundFiles = dirContents.filter { url in
                            var isDir: ObjCBool = false
                            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
                        }
                        ILOG("Found \(foundFiles.count) files in temp directory after delay")
                        extractedFiles = foundFiles
                    } else {
                        extractedFiles = existingFiles
                    }
                } else {
                    extractedFiles = existingFiles
                }
            }
        } catch {
            extractionError = error
            ELOG("Failed to extract archive \(archiveURL.lastPathComponent): \(error.localizedDescription)")
            if let nsError = error as NSError? {
                ELOG("Error domain: \(nsError.domain), code: \(nsError.code), userInfo: \(nsError.userInfo)")
            }
            if let archiveError = error as? ArchiveError {
                ELOG("ArchiveError details: \(archiveError)")
            }
            // Check file size for 7z files (might be too large)
            if archiveType == .sevenZip {
                if let fileSize = try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? Int64 {
                    let sizeMB = fileSize / 1_000_000
                    ELOG("7z file size: \(fileSize) bytes (\(sizeMB) MB)")
                    // Increased limit: 1GB to support larger archives
                    let maxSize: Int64 = 1_000_000_000 // 1GB
                    if fileSize > maxSize {
                        let maxMB = maxSize / 1_000_000
                        throw ArchiveError.extractionFailed("7z file is too large (\(sizeMB) MB). Maximum supported size is \(maxMB) MB. Please extract manually or use ZIP format for larger archives.")
                    } else if fileSize > 500_000_000 { // 500MB
                        WLOG("7z file \(archiveURL.lastPathComponent) is large (\(sizeMB) MB). Extraction may use significant memory.")
                    }
                }
            }
        }

        // If extraction failed, throw the error
        if let error = extractionError {
            if let archiveError = error as? ArchiveError {
                throw archiveError
            } else {
                throw ArchiveError.extractionFailed("Failed to extract \(archiveType.rawValue) archive: \(error.localizedDescription)")
            }
        }

        // Check if we got any files, with fallback for 7z async issue
        if extractedFiles.isEmpty {
            ELOG("No files were extracted from archive \(archiveURL.lastPathComponent)")
            // For 7z, this might be due to async write issue - check directory contents
            if archiveType == .sevenZip {
                if let dirContents = try? FileManager.default.contentsOfDirectory(at: tempExtractionDir, includingPropertiesForKeys: nil) {
                    let files = dirContents.filter { url in
                        var isDir: ObjCBool = false
                        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
                    }
                    if !files.isEmpty {
                        ILOG("Found \(files.count) files in temp directory despite empty extraction list")
                        extractedFiles = files
                    }
                }
            }

            guard !extractedFiles.isEmpty else {
                throw ArchiveError.extractionFailed("No files were extracted from archive. The archive may be corrupted or in an unsupported format.")
            }
        }

        ILOG("Extracted \(extractedFiles.count) files from archive \(archiveURL.lastPathComponent)")

        // Move extracted files to imports directory for processing
        let importsPath = self.importsPath
        var filesToImport: [URL] = []

        for extractedFile in extractedFiles {
            let fileName = extractedFile.lastPathComponent
            let destinationURL = importsPath.appendingPathComponent(fileName)

            // Handle filename conflicts
            var finalDestinationURL = destinationURL
            var counter = 1
            while FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                let nameWithoutExt = destinationURL.deletingPathExtension().lastPathComponent
                let ext = destinationURL.pathExtension
                finalDestinationURL = importsPath.appendingPathComponent("\(nameWithoutExt)_\(counter).\(ext)")
                counter += 1
            }

            try FileManager.default.moveItem(at: extractedFile, to: finalDestinationURL)
            filesToImport.append(finalDestinationURL)
        }

        // Clean up metadata files that won't match any system
        let metadataExtensions: Set<String> = ["txt", "md", "url", "nfo", "dat", "xml", "json", "html", "htm"]
        var cleanedCount = 0

        for fileURL in filesToImport {
            let fileName = fileURL.lastPathComponent.lowercased()
            let ext = fileURL.pathExtension.lowercased()

            // Check if it's a metadata file by extension or filename pattern
            let isMetadataFile = metadataExtensions.contains(ext) ||
                                fileName.hasPrefix("readme") ||
                                fileName == "license" ||
                                fileName.hasSuffix(".txt") && (fileName.contains("readme") || fileName.contains("license") || fileName.contains("info"))

            if isMetadataFile {
                // Check if this file could be a ROM by checking if it matches any system
                let testItem = ImportQueueItem(url: fileURL, fileType: .unknown)
                do {
                    let systems = try await gameImporterSystemsService.determineSystems(for: testItem)
                    if systems.isEmpty {
                        // No system matches, delete metadata file
                        try await FileManager.default.removeItem(at: fileURL)
                        cleanedCount += 1
                        ILOG("Deleted metadata file: \(fileURL.lastPathComponent)")
                    }
                } catch {
                    // If we can't determine systems, assume it's metadata and delete
                    try? await FileManager.default.removeItem(at: fileURL)
                    cleanedCount += 1
                    ILOG("Deleted metadata file (error determining systems): \(fileURL.lastPathComponent)")
                }
            }
        }

        if cleanedCount > 0 {
            ILOG("Cleaned up \(cleanedCount) metadata files after extraction")
        }

        // Remove cleaned files from import list
        filesToImport = filesToImport.filter { FileManager.default.fileExists(atPath: $0.path) }

        // Add extracted files to import queue
        if !filesToImport.isEmpty {
            await MainActor.run {
                updateImporterStatus("Importing \(filesToImport.count) extracted file(s) from \(archiveURL.lastPathComponent)")
            }
            await addImports(forPaths: filesToImport)
            ILOG("Added \(filesToImport.count) extracted files to import queue")
        }

        // Delete original archive after successful extraction
        try await FileManager.default.removeItem(at: archiveURL)
        ILOG("Deleted original archive after extraction: \(archiveURL.lastPathComponent)")
    }

    private func performImport(for item: ImportQueueItem) async throws {
        let fileName = item.url.lastPathComponent
        ILOG("Starting import for file: \(fileName)")

        //ideally this wouldn't be needed here because we'd have done it elsewhere
        ILOG("About to determine import type for: \(fileName)")
        let typeStartTime = Date()
        item.fileType = try determineImportType(item)
        let typeDuration = Date().timeIntervalSince(typeStartTime)
        ILOG("Determined file type: \(item.fileType) for \(fileName) in \(String(format: "%.2f", typeDuration))s")

        // Handle BIOS files first - BIOS files should never be extracted as archives
        // This check ensures BIOS files are detected even if they have .zip extension
        if item.fileType == .bios {
            ILOG("Processing as BIOS file (detected before archive handling)")
            do {
                try await gameImporterDatabaseService.importBIOSIntoDatabase(queueItem: item)
                await MainActor.run {
                    item.status = .success
                }
                ILOG("Successfully imported BIOS file: \(item.url.lastPathComponent)")
                return
            } catch {
                ELOG("Failed to import BIOS file: \(error.localizedDescription)")
                await MainActor.run {
                    item.status = .failure(error: error)
                }
                throw error
            }
        }

        // Handle archive files - check if they match by filename or MD5 first
        if item.fileType == .zip {
            // Check if archive matches in database (should be kept as-is)
            // Note: checkArchiveMatch handles all archive extensions, not just zip
            if let matchingSystem = await checkArchiveMatch(item) {
                ILOG("Archive \(fileName) matches system \(matchingSystem.rawValue) in database - keeping as-is")
                // Update file type to game/cdRom based on system
                if let pvSystem = PVSystem.all.first(where: { $0.identifier == matchingSystem.rawValue }) {
                    // Check if system supports CD-ROM formats
                    let cdRomExtensions = Extensions.discImageExtensions
                        .union(Extensions.playlistExtensions)
                        .union([Extensions.bin.rawValue])
                    let hasCDRomSupport = pvSystem.supportedExtensions.contains(where: { cdRomExtensions.contains($0.lowercased()) })
                    item.fileType = hasCDRomSupport ? .cdRom : .game
                } else {
                    item.fileType = .game
                }
                // Set the system so it can be processed normally
                item.systems = [matchingSystem]
                // Continue with normal import flow
            } else {
                // Archive doesn't match - extract and import contents
                ILOG("Archive \(fileName) doesn't match in database - extracting and importing contents")

                // Set status to extracting before starting extraction
                await MainActor.run {
                    item.status = .extracting
                    updateImporterStatus("Extracting \(fileName)")
                }

                // Register archive as being extracted to prevent DirectoryWatcher from re-adding it
                await importCoordinator.registerExtractingArchive(url: item.url)

                do {
                    try await extractAndImportArchive(item)

                    // Remove the ZIP item from the queue after successful extraction
                    await importQueueActor.removeImport(byID: item.id)
                    ILOG("Removed ZIP archive item from queue after successful extraction: \(fileName)")

                    // Unregister archive from extraction tracking
                    await importCoordinator.unregisterExtractingArchive(url: item.url)

                    // Don't set status or return - item is removed from queue
                    return
                } catch {
                    // Unregister on error so it can be retried
                    await importCoordinator.unregisterExtractingArchive(url: item.url)

                    // Set failure status on error
                    await MainActor.run {
                        item.status = .failure(error: error)
                        updateImporterStatus("Failed to extract \(fileName): \(error.localizedDescription)")
                    }
                    throw error
                }
            }
        }

        if item.fileType == .skin {
            ILOG("Processing as Skin file")
            do {
                try await skinImporterService.importSkin(from: item.url)
                await MainActor.run {
                    item.status = .success
                }
                ILOG("Successfully imported skin file: \(item.url.lastPathComponent)")
                return
            } catch {
                ELOG("Failed to import skin file: \(error.localizedDescription)")
                await MainActor.run {
                    item.status = .failure(error: error)
                }
                throw error
            }
        }

        // Handle BIOS files first, before any system detection
        if item.fileType == .bios {
            ILOG("Processing as BIOS file")
            do {
                try await gameImporterDatabaseService.importBIOSIntoDatabase(queueItem: item)
                await MainActor.run {
                    item.status = .success
                }
                ILOG("Successfully imported BIOS file: \(item.url.lastPathComponent)")
                return
            } catch {
                ELOG("Failed to import BIOS file: \(error.localizedDescription)")
                await MainActor.run {
                    item.status = .failure(error: error)
                }
                throw error
            }
        }

        if item.fileType == .artwork {
            ILOG("Processing as Artwork file")
            do {
                if let _ = await gameImporterArtworkImporter.importArtworkItem(item) {
                    await MainActor.run {
                        item.status = .success
                    }
                    ILOG("Successfully imported artwork file: \(item.url.lastPathComponent)")
                } else {
                    await MainActor.run {
                        item.status = .failure(error: GameImporterError.artworkImportFailed)
                    }
                    ELOG("Artwork import returned nil for: \(item.url.lastPathComponent)")
                    throw GameImporterError.artworkImportFailed
                }
            } catch {
                ELOG("Failed to import artwork file: \(error.localizedDescription)")
                await MainActor.run {
                    item.status = .failure(error: error)
                }
                throw error
            }
            return
        }

        // Only do system detection for non-BIOS files
        ILOG("About to determine systems for: \(fileName)")
        let systemsStartTime = Date()
        let systems: [SystemIdentifier]
        do {
            systems = try await gameImporterSystemsService.determineSystems(for: item)
            let systemsDuration = Date().timeIntervalSince(systemsStartTime)
            ILOG("Determined systems for \(fileName) in \(String(format: "%.2f", systemsDuration))s: \(systems.map { $0.rawValue }.joined(separator: ", "))")
            guard !systems.isEmpty else {
                throw GameImporterError.noSystemMatched
            }
        } catch {
            // Handle system determination failure
            ELOG("Failed to determine systems for Import Item: \(item.url.lastPathComponent) - \(error.localizedDescription)")

            // Set status on main actor for thread safety
            await MainActor.run {
                item.status = .failure(error: GameImporterError.noSystemMatched)
            }

            // Clean up file if it's in imports directory
            await cleanupFailedImportFile(item.url)

            throw GameImporterError.noSystemMatched
        }

        //update item's candidate systems with the result of determineSystems
        item.systems = systems

        //this might be a conflict if we can't infer what to do
        //for BIOS, we can handle multiple systems, so allow that to proceed
        if item.fileType != .bios && item.targetSystem() == nil {
            //conflict - set status on main actor for thread safety
            await MainActor.run {
                item.status = .conflict
            }
            WLOG("System conflict detected for \(item.url.lastPathComponent): multiple systems possible (\(systems.map { $0.rawValue }.joined(separator: ", ")))")
            throw GameImporterError.conflictDetected
        }

        // Check for expected files before importing game/cdRom types
        // Skip this check if user has explicitly selected a system - they've made a decision to proceed
        if item.fileType == .game || item.fileType == .cdRom {
            // If user has selected a system, proceed even if some files aren't resolved yet
            // (they may be on disk but not in resolvedAssociatedFileURLs, or user wants to proceed anyway)
            if item.userChosenSystem == nil {
                // Check if there are expected files that haven't been resolved yet
                if let expectedFiles = item.expectedAssociatedFileNames, !expectedFiles.isEmpty {
                    // Verify that all expected files are actually resolved
                    let unresolvedFiles = expectedFiles.filter { expectedFileName in
                        !item.resolvedAssociatedFileURLs.contains { $0.lastPathComponent.lowercased() == expectedFileName.lowercased() }
                    }

                    if !unresolvedFiles.isEmpty {
                        ILOG("Item \(item.url.lastPathComponent) still has \(unresolvedFiles.count) unresolved expected files. Deferring database import. Unresolved: \(unresolvedFiles)")
                        throw GameImporterError.waitingForAssociatedFiles(expected: unresolvedFiles)
                    } else {
                        ILOG("Item \(item.url.lastPathComponent) has all expected files resolved. Proceeding with database import.")
                        // Clear expected files since they're all resolved
                        item.expectedAssociatedFileNames = nil
                    }
                } else {
                    ILOG("Item \(item.url.lastPathComponent) has no pending expected files. Proceeding with database import.")
                }
            } else {
                // User has selected a system - proceed with import
                // Check on disk for any missing files before importing
                if let expectedFiles = item.expectedAssociatedFileNames, !expectedFiles.isEmpty {
                    let cueDirectory = item.url.deletingLastPathComponent()
                    for expectedFileName in expectedFiles {
                        let expectedPath = cueDirectory.appendingPathComponent(expectedFileName)
                        if FileManager.default.fileExists(atPath: expectedPath.path) {
                            if !item.resolvedAssociatedFileURLs.contains(expectedPath) {
                                item.resolvedAssociatedFileURLs.append(expectedPath)
                                ILOG("Found expected file on disk: \(expectedFileName)")
                            }
                        }
                    }
                    // Clear expected files list - we've checked on disk
                    item.expectedAssociatedFileNames = nil
                }
                ILOG("Item \(item.url.lastPathComponent) has user-selected system \(item.userChosenSystem!.rawValue), proceeding with import")
            }
        }

        // Move ImportQueueItem to appropriate file location with proper error handling
        ILOG("About to move file for: \(fileName)")
        let moveStartTime = Date()
        do {
            try await gameImporterFileService.moveImportItem(toAppropriateSubfolder: item)
            let moveDuration = Date().timeIntervalSince(moveStartTime)
            ILOG("Successfully moved \(fileName) to destination in \(String(format: "%.2f", moveDuration))s")
        } catch {
            // Check if the error is about file deletion failure
            // If the file was successfully moved/imported but deletion failed, don't fail the import
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("couldn't be removed") || errorDescription.contains("couldn't be deleted") {
                // File was likely successfully imported but couldn't be deleted from Imports
                // Check if file was actually moved by checking destinationUrl or if source file no longer exists
                let wasMoved = item.destinationUrl != nil || !FileManager.default.fileExists(atPath: item.url.path)
                if wasMoved {
                    WLOG("File \(item.url.lastPathComponent) was successfully imported but couldn't be deleted from Imports folder. This is non-fatal - continuing with import.")
                    // Continue with import - the file cleanup can happen later or DirectoryWatcher will handle it
                } else {
                    // File wasn't moved, this is a real error
                    ELOG("Failed to move import item \(item.url.lastPathComponent): \(error.localizedDescription)")
                    await cleanupFailedImportFile(item.url)
                    throw error
                }
            } else {
                // Other errors are real failures
                ELOG("Failed to move import item \(item.url.lastPathComponent): \(error.localizedDescription)")
                await cleanupFailedImportFile(item.url)
                throw error
            }
        }

        // Import into database with proper error handling
        ILOG("About to import \(fileName) into database (type: \(item.fileType))")
        let dbStartTime = Date()
        do {
            if item.fileType == .bios {
                try await gameImporterDatabaseService.importBIOSIntoDatabase(queueItem: item)
                let dbDuration = Date().timeIntervalSince(dbStartTime)
                ILOG("Successfully imported BIOS \(fileName) into database in \(String(format: "%.2f", dbDuration))s")
            } else {
                try await gameImporterDatabaseService.importGameIntoDatabase(queueItem: item)
                let dbDuration = Date().timeIntervalSince(dbStartTime)
                ILOG("Successfully imported game \(fileName) into database in \(String(format: "%.2f", dbDuration))s")
            }
        } catch {
            ELOG("Failed to import \(item.url.lastPathComponent) into database: \(error.localizedDescription)")
            // Clean up moved files if database import fails
            if let destinationURL = item.destinationUrl {
                await cleanupFailedImportFile(destinationURL)
            }
            throw error
        }
    }

    /// Checks the queue and all child elements in the queue to see if this file exists.  if it does, return true, else return false.
    /// Duplicates are considered if the filename, id, or md5 matches
    public func importQueueContainsDuplicate(_ queue: [ImportQueueItem], ofItem queueItem: ImportQueueItem) -> Bool {
        let duplicate = queue.contains { existing in
            guard existing.status.blocksDuplicateProcessing else {
                return false
            }

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

    /// Batch checks multiple items for existing games in database (more efficient than individual checks)
    /// Also updates CloudKit-created games that are missing local file references.
    /// - Parameter items: Items to check
    /// - Returns: Set of URLs that already exist in database with valid local files
    private func batchCheckExistingGames(_ items: [ImportQueueItem]) async -> Set<URL> {
        // Check if paused for emulation
        let pausedForEmulation = await MainActor.run { isPausedForEmulation }
        if pausedForEmulation {
            ILOG("GameImporter: Skipping batchCheckExistingGames - paused for emulation")
            return []
        }

        do {
            try await RealmProvider.ensureInitialized()
        } catch {
            ELOG("GameImporter: Failed to initialize Realm for batch check: \(error.localizedDescription)")
            return []
        }

        // Structure to hold games that need updating (collected without blocking main thread)
        struct GameUpdateInfo {
            let md5Hash: String
            let fileURL: URL
            let partialPath: String
            let title: String
        }

        ILOG("GameImporter: batchCheckExistingGames checking \(items.count) items")

        // Step 1: Query Realm and identify matches (on main actor but just reads)
        let (existingURLs, gamesToUpdate): (Set<URL>, [GameUpdateInfo]) = await MainActor.run {
            var existingURLs = Set<URL>()
            var gamesToUpdate: [GameUpdateInfo] = []

            let realm = RomDatabase.sharedInstance.realm

            /// Group items by system directory for efficient batch queries
            let itemsBySystem = Dictionary(grouping: items) { item -> String in
                item.url.deletingLastPathComponent().lastPathComponent
            }

            for (systemDir, systemItems) in itemsBySystem {
                guard let systemID = SystemIdentifier(rawValue: systemDir) else {
                    WLOG("GameImporter: batchCheckExistingGames - Invalid system directory: \(systemDir)")
                    continue
                }

                DLOG("GameImporter: batchCheckExistingGames - Checking \(systemItems.count) items for system \(systemID.rawValue)")

                /// Batch query: Get all games for this system at once (single query instead of per-file)
                let allGamesForSystem = realm.objects(PVGame.self)
                    .filter("systemIdentifier == %@", systemID.rawValue)

                /// Build lookup dictionaries for fast in-memory checking
                var romPathsToGame = [String: PVGame]()
                var md5ToGame = [String: PVGame]()
                var filePathsSet = Set<String>()

                for game in allGamesForSystem {
                    if !game.romPath.isEmpty {
                        romPathsToGame[game.romPath] = game
                    }
                    if !game.md5Hash.isEmpty {
                        md5ToGame[game.md5Hash.uppercased()] = game
                    }
                    if let fileURL = game.file?.url?.path {
                        filePathsSet.insert(fileURL)
                    }
                }

                DLOG("GameImporter: batchCheckExistingGames - Built lookup sets: \(romPathsToGame.count) romPaths, \(md5ToGame.count) MD5s, \(filePathsSet.count) file paths")

                /// Now check each item against the pre-built sets (fast in-memory lookups)
                /// NOTE: We intentionally DO NOT access item.md5 here because that triggers
                /// expensive MD5 computation on the main thread. Filename matching is sufficient
                /// for duplicate detection. MD5 will be computed later during import if needed.
                for item in systemItems {
                    let filename = item.url.lastPathComponent
                    let partialPath = (systemID.rawValue as NSString).appendingPathComponent(filename)

                    // Helper to check if game needs update and collect info
                    func checkGame(_ game: PVGame, fileURL: URL, partialPath: String) {
                        if game.isDownloaded && game.file != nil {
                            // Game is complete, just mark as existing
                            existingURLs.insert(fileURL)
                        } else {
                            // CloudKit-created game needs local file update
                            gamesToUpdate.append(GameUpdateInfo(
                                md5Hash: game.md5Hash,
                                fileURL: fileURL,
                                partialPath: partialPath,
                                title: game.title
                            ))
                            existingURLs.insert(fileURL)
                        }
                    }

                    /// Fast-path: Check by romPath (in-memory set lookup)
                    if let existingGame = romPathsToGame[partialPath] {
                        checkGame(existingGame, fileURL: item.url, partialPath: partialPath)
                        continue
                    }

                    /// Check by file path (in-memory set lookup)
                    if filePathsSet.contains(item.url.path) {
                        VLOG("GameImporter: batchCheckExistingGames - Found existing game by file path: \(filename)")
                        existingURLs.insert(item.url)
                        continue
                    }

                    /// Check by filename match against existing games (case-insensitive)
                    /// This is faster than MD5 and catches most duplicates
                    let lowercaseFilename = filename.lowercased()
                    for (romPath, game) in romPathsToGame {
                        if romPath.lowercased().hasSuffix(lowercaseFilename) {
                            checkGame(game, fileURL: item.url, partialPath: partialPath)
                            break
                        }
                    }
                }
            }

            return (existingURLs, gamesToUpdate)
        }

        // Step 2: Batch update games that need local file info (single write transaction)
        if !gamesToUpdate.isEmpty {
            await MainActor.run {
                let realm = RomDatabase.sharedInstance.realm
                var updatedCount = 0

                do {
                    try realm.write {
                        for info in gamesToUpdate {
                            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: info.md5Hash) else { continue }

                            if game.file == nil {
                                let pvFile = PVFile(withURL: info.fileURL)
                                game.file = pvFile
                            } else if let existingFile = game.file {
                                if existingFile.partialPath != info.partialPath {
                                    existingFile.partialPath = info.partialPath
                                }
                            }
                            game.isDownloaded = true
                            updatedCount += 1
                        }
                    }
                    ILOG("GameImporter: batchCheckExistingGames - Updated \(updatedCount) CloudKit-created games with local files")
                } catch {
                    ELOG("[CLOUD SYNC FIX] Failed to batch update games: \(error.localizedDescription)")
                }
            }
        }

        ILOG("GameImporter: batchCheckExistingGames - Found \(existingURLs.count) existing files out of \(items.count) checked")
        return existingURLs
    }

    private func addImportItemToQueue(_ item: ImportQueueItem) async {
        // Check if this archive is currently being extracted (prevents DirectoryWatcher from re-adding it)
        let isExtracting = await importCoordinator.isExtractingArchive(url: item.url)
        if isExtracting {
            ILOG("GameImportQueue - Skipping archive file that is currently being extracted: \(item.url.lastPathComponent)")
            return
        }

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
            // Add BIOS file to queue
            await importQueueActor.addImport(item)
            ILOG("GameImportQueue - Added BIOS file to import queue: \(item.url.lastPathComponent)")
            return
        } else if fileType == .artwork {
            // For artwork files, always add to queue (they may update artwork for existing games)
            // No duplicate check needed - artwork files should always be processed
            await importQueueActor.addImport(item)
            ILOG("GameImportQueue - Added artwork file to import queue: \(item.url.lastPathComponent)")
            return
        } else if fileType == .skin {
            // For skin files (.deltaskin, .manicskin), always add to queue
            // No duplicate check needed - skin files should always be processed
            await importQueueActor.addImport(item)
            ILOG("GameImportQueue - Added skin file to import queue: \(item.url.lastPathComponent)")
            return
        } else if fileType == .game || fileType == .cdRom {
            // Check for duplicates in the current queue FIRST (before database checks)
            // This prevents adding files that are already being processed
            // We check twice: once here and once right before adding to ensure atomicity
            let isDuplicateInQueue = await importQueueActor.containsDuplicate(ofItem: item) { [weak self] existing, newItem in
                guard let self = self else { return false }

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

            if isDuplicateInQueue {
                WLOG("GameImportQueue - Skipping ROM file already in queue: \(item.url.lastPathComponent)")
                return
            }

            // Check again right before adding to ensure atomicity (prevents race conditions with DirectoryWatcher)
            // This is critical for files extracted from archives that DirectoryWatcher might also detect
            let isDuplicateBeforeAdd = await importQueueActor.containsDuplicate(ofItem: item) { [weak self] existing, newItem in
                guard let self = self else { return false }

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

            if isDuplicateBeforeAdd {
                WLOG("GameImportQueue - Skipping ROM file already in queue (duplicate detected right before add): \(item.url.lastPathComponent)")
                return
            }

            // For ROM files, check if we already have a matching game entry in the database BEFORE adding to queue
            // This prevents race conditions where the item gets processed before it can be removed
            // Skip expensive check if userChosenSystem is set (meaning it came from scan and was already batch-checked)
            let isInImportsFolder = item.url.path.contains("/Imports/")

            if !isInImportsFolder {
                // Full check for files not in imports folder (e.g., re-scanning ROMs folder)
                // Even if userChosenSystem is set, batchCheckExistingGames doesn't check MD5,
                // so we need to do a full check here to catch MD5 duplicates
                let isROMAlreadyImported = await isROMAlreadyInDatabase(item)
                if isROMAlreadyImported {
                    ILOG("GameImportQueue - Skipping ROM file that already exists in database: \(item.url.lastPathComponent)")
                    return
                }
            }

            // Stage the item in the queue so the UI reflects processing immediately
            // Only add to queue after confirming it's not a duplicate
            await importQueueActor.addImport(item)
            ILOG("GameImportQueue - Staged import item: \(item.url.lastPathComponent) (id: \(item.id))")

            // Check if this is a late-arriving file that belongs to an already processed M3U or CUE
            // Only check for CD-ROM related files to avoid expensive queue iteration for regular ROMs
            // Skip this check for files in Imports folder (they're new files, not late arrivals)
            //let isInImportsFolder = item.url.path.contains("/Imports/")
            if !isInImportsFolder && (fileType == .cdRom || item.url.pathExtension.lowercased() == Extensions.bin.rawValue) {
                let currentQueue = await importQueueActor.getQueue()
                let successfulItems = currentQueue.filter { $0.status == .success }

                // Limit check to recent successful items to avoid expensive iteration
                let recentSuccessfulItems = Array(successfulItems.suffix(50)) // Only check last 50 successful items

                // First check for completed items that might be expecting this file
                for completedItem in recentSuccessfulItems where completedItem.fileType == .cdRom {
                    // Check if this file is in the expected associated files list of any completed item
                    if let expectedFiles = completedItem.expectedAssociatedFileNames,
                       expectedFiles.contains(where: { $0.lowercased() == item.url.lastPathComponent.lowercased() }) {
                        ILOG("Found late-arriving file \(item.url.lastPathComponent) that belongs to completed item \(completedItem.url.lastPathComponent)")

                        // Handle the late-arriving file
                        await handleLateAssociatedFile(fileURL: item.url, forCompletedItem: completedItem)
                            await importQueueActor.removeImport(byID: item.id)
                        return // Don't add to queue since we've handled it as a late arrival
                    }

                    // Check if this is a CUE file mentioned in an M3U
                    if completedItem.url.pathExtension.lowercased() == Extensions.m3u.rawValue,
                       let m3uContents = try? cdRomFileHandler.parseM3U(from: completedItem.url),
                       m3uContents.contains(where: { $0.lowercased() == item.url.lastPathComponent.lowercased() }) {
                        ILOG("Found late-arriving CUE file \(item.url.lastPathComponent) that belongs to M3U \(completedItem.url.lastPathComponent)")

                        // Handle the late-arriving file
                        await handleLateAssociatedFile(fileURL: item.url, forCompletedItem: completedItem)
                            await importQueueActor.removeImport(byID: item.id)
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
                                    await importQueueActor.removeImport(byID: item.id)
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
                                await importQueueActor.removeImport(byID: item.id)
                                return // Don't add to queue since we've handled it as a late arrival
                            }
                        }
                    }
                }
            }
        } else {
            // Handle other file types (zip, unknown, etc.) - add them to queue for processing
            // Skip duplicate check for unknown/zip files in imports folder (they're new)
            let isInImportsFolder = item.url.path.contains("/Imports/")
            if isInImportsFolder {
                // For files in imports folder, skip expensive checks and add directly
                await importQueueActor.addImport(item)
                ILOG("GameImportQueue - Added \(fileType) file to import queue: \(item.url.lastPathComponent)")
            } else {
                // For files not in imports folder, check for duplicates first
                let isDuplicate = await importQueueActor.containsDuplicate(ofItem: item) { existing, newItem in
                    return existing.url == newItem.url ||
                           (existing.url.lastPathComponent == newItem.url.lastPathComponent &&
                            existing.url.deletingLastPathComponent() == newItem.url.deletingLastPathComponent())
                }

                guard !isDuplicate else {
                    WLOG("GameImportQueue - Skipping duplicate \(fileType) file: \(item.url.lastPathComponent)")
                    return
                }

                await importQueueActor.addImport(item)
                ILOG("GameImportQueue - Added \(fileType) file to import queue: \(item.url.lastPathComponent)")
            }
        }
    }

    /// Pauses the import processing
    /// Items can still be added to or removed from the queue while paused
    public func pause() {
        Task { @MainActor in
            guard processingState == .processing else { return }

            ILOG("GameImportQueue - Pausing import processing")
            processingState = .paused
            updateImporterStatus("Import processing paused")

            // Cancel timeout task when pausing to avoid false timeout triggers
            processingTaskLock.lock()
            currentTimeoutTask?.cancel()
            currentTimeoutTask = nil
            processingTaskLock.unlock()
        }
    }

    /// Pauses the import processing specifically for emulation
    /// This prevents auto-resume while emulation is active
    public func pauseForEmulation() {
        Task { @MainActor in
            ILOG("GameImportQueue - Pausing import processing for emulation")
            isPausedForEmulation = true

            workQueue.isSuspended = true
            serialImportQueue.isSuspended = true

            // Also pause normal processing if it's running
            if processingState == .processing {
                processingState = .paused
                updateImporterStatus("Import paused for emulation")

                // Cancel any in-flight processing immediately
                processingTaskLock.lock()
                currentProcessingTask?.cancel()
                currentProcessingTask = nil
                currentTimeoutTask?.cancel()
                currentTimeoutTask = nil
                processingStartTime = nil
                processingTaskLock.unlock()

                // Cancel queued operations so nothing continues
                workQueue.cancelAllOperations()
                serialImportQueue.cancelAllOperations()
            }
        }
    }

    /// Resumes import processing after emulation ends
    /// Called when emulation stops and user returns to library
    public func resumeFromEmulation() {
        Task { @MainActor in
            guard isPausedForEmulation else { return }

            ILOG("GameImportQueue - Resuming import processing after emulation")
            isPausedForEmulation = false

            workQueue.isSuspended = false
            serialImportQueue.isSuspended = false

            // Resume processing if there are queued items
            let queueSnapshot = await importQueueActor.getQueue()
            let queuedCount = queueSnapshot.filter { $0.status == .queued }.count
            if queuedCount > 0 {
                await resumeSafely()
            }
        }
    }

    /// Resumes the import processing if it was paused
    public func resume() {
        Task {
            await resumeSafely()
        }
    }

    // Thread-safe method to resume processing
    private func resumeSafely() async {
        let currentState = await MainActor.run { processingState }
        guard currentState == .paused else {
            VLOG("GameImporter: Skipping resume - not paused (state: \(currentState))")
            return
        }

        ILOG("GameImportQueue - Resuming import processing safely")

        // Cancel any pending auto-start tasks
        importAutoStartDelayTask?.cancel()
        importAutoStartDelayTask = nil

        // Use the safe start method which handles task management
        await MainActor.run {
            processingState = .idle  // Reset to idle so startProcessingSafely can proceed
        }

        await startProcessingSafely()
    }

    /// Manually trigger timeout recovery if processing appears stuck
    /// This can be called externally if the UI detects a hung state
    public func recoverFromTimeout() {
        Task {
            await handleProcessingTimeout()
        }
    }

    /// Get current processing duration for debugging
    public func getCurrentProcessingDuration() -> TimeInterval? {
        guard let startTime = processingStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    /// Groups related files that should be processed together
    /// - Parameter items: The items to group
    /// - Returns: An array of item groups, where each group contains related files
    private func groupRelatedFiles(_ items: [ImportQueueItem]) -> [[ImportQueueItem]] {
        guard !items.isEmpty else { return [] }

        var remaining = Set(items.map { $0.id })
        var groups: [[ImportQueueItem]] = []

        let itemsByFilename = Dictionary(grouping: items) { $0.url.lastPathComponent.lowercased() }
        let itemsByBaseName = Dictionary(grouping: items) { $0.url.deletingPathExtension().lastPathComponent.lowercased() }

        for item in items {
            guard remaining.contains(item.id) else { continue }

            let ext = item.url.pathExtension.lowercased()
            switch ext {
            case Extensions.m3u.rawValue:
                let group = groupForM3U(item, itemsByFilename: itemsByFilename, remaining: &remaining)
                groups.append(group)
            case Extensions.cue.rawValue:
                let group = groupForCue(item,
                                        itemsByFilename: itemsByFilename,
                                        itemsByBaseName: itemsByBaseName,
                                        remaining: &remaining)
                groups.append(group)
            default:
                remaining.remove(item.id)
                groups.append([item])
            }
        }

        return groups
    }

    private func groupForM3U(_ item: ImportQueueItem,
                             itemsByFilename: [String: [ImportQueueItem]],
                             remaining: inout Set<UUID>) -> [ImportQueueItem] {
        var group: [ImportQueueItem] = []
        appendIfPending(item, to: &group, remaining: &remaining)

        guard let fileNames = try? cdRomFileHandler.parseM3U(from: item.url) else {
            return group
        }

        for entry in fileNames {
            let normalizedName = normalizedFileComponent(entry)
            guard let matches = itemsByFilename[normalizedName] else { continue }
            for candidate in matches {
                appendIfPending(candidate, to: &group, remaining: &remaining)
            }
        }

        return group
    }

    private func groupForCue(_ cueItem: ImportQueueItem,
                             itemsByFilename: [String: [ImportQueueItem]],
                             itemsByBaseName: [String: [ImportQueueItem]],
                             remaining: inout Set<UUID>) -> [ImportQueueItem] {
        var group: [ImportQueueItem] = []
        appendIfPending(cueItem, to: &group, remaining: &remaining)

        var referencedFiles: [String] = []
        if let cueEntries = try? cdRomFileHandler.parseCueSheet(cueFileURL: cueItem.url) {
            referencedFiles = cueEntries.map(normalizedFileComponent)
        } else {
            referencedFiles = [cueItem.url.deletingPathExtension().lastPathComponent.lowercased()]
        }

        for reference in referencedFiles {
            guard let candidates = itemsByFilename[reference] else { continue }
            for candidate in candidates {
                appendIfPending(candidate, to: &group, remaining: &remaining)
            }
        }

        if group.count == 1 {
            let baseName = cueItem.url.deletingPathExtension().lastPathComponent.lowercased()
            if let candidates = itemsByBaseName[baseName] {
                for candidate in candidates where candidate.id != cueItem.id {
                    appendIfPending(candidate, to: &group, remaining: &remaining)
                }
            }
        }

        return group
    }

    private func normalizedFileComponent(_ component: String) -> String {
        return (component as NSString).lastPathComponent.lowercased()
    }

    private func appendIfPending(_ item: ImportQueueItem,
                                 to group: inout [ImportQueueItem],
                                 remaining: inout Set<UUID>) {
        if remaining.remove(item.id) != nil {
            group.append(item)
        }
    }

    /// Prioritizes import groups for optimal processing order
    /// Small files first, CD-ROMs last, multi-file groups after single files
    /// - Parameter groups: Groups of related import items
    /// - Returns: Prioritized groups sorted by processing efficiency
    private func prioritizeImportGroups(_ groups: [[ImportQueueItem]]) -> [[ImportQueueItem]] {
        return groups.sorted { lhsGroup, rhsGroup in
            let lhsScore = priorityScore(for: lhsGroup)
            let rhsScore = priorityScore(for: rhsGroup)
            return lhsScore < rhsScore
        }
    }

    /// Calculates priority score for a group of import items (lower = higher priority)
    /// - Parameter group: Group of related import items
    /// - Returns: Priority score (lower values processed first)
    private func priorityScore(for group: [ImportQueueItem]) -> Int {
        guard let firstItem = group.first else { return Int.max }

        var score = 0

        // CD-ROMs get lowest priority (processed last)
        if firstItem.fileType == .cdRom {
            score += 10000
        }

        // Multi-file groups (CUE/BIN, M3U) get lower priority
        if group.count > 1 {
            score += 5000
        }

        // Calculate total file size for the group
        var totalSize: Int64 = 0
        for item in group {
            if let size = item.fileSize() {
                totalSize += size
            }
        }

        // Larger files get lower priority (processed later)
        // Add size in MB to score
        score += Int(totalSize / 1_000_000)

        return score
    }

    // Add a helper method to check if processing is paused
    private func checkIfPaused() async -> Bool {
        // Check if we're paused
        let isPaused = (await self.processingState) == .paused
        return isPaused
    }

    /// Checks if a ROM file already exists in the database with a valid file
    /// Uses fast-path duplicate detection (file size) before expensive MD5 calculation
    /// - Parameter item: The ImportQueueItem to check
    /// - Returns: True if the ROM already exists in the database with a valid file
    private func isROMAlreadyInDatabase(_ item: ImportQueueItem) async -> Bool {
        let gamesCache = RomDatabase.gamesCache
        let filePath = item.url.path

        /// Fast-path: Quick duplicate check using file size (before expensive MD5)
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64 {
            let duplicateFound = try! await RealmContext.withBackgroundRealm { realm -> Bool in
                let gamesWithSameSize = realm.objects(PVGame.self).filter("file.sizeCache == %@", Int(fileSize))
                guard let gameWithSameSize = gamesWithSameSize.first else {
                    return false
                }
                let filename = item.url.lastPathComponent
                if let systemID = SystemIdentifier(rawValue: item.url.deletingLastPathComponent().lastPathComponent) {
                    let partialPath = (systemID.rawValue as NSString).appendingPathComponent(filename)
                    if gameWithSameSize.romPath == partialPath {
                        ILOG("Found existing game by file size and romPath match: \(gameWithSameSize.title ?? "Unknown")")
                        return true
                    }
                }
                if let gameFile = gameWithSameSize.file,
                   gameFile.url?.path == filePath {
                    ILOG("Found existing game by file path match: \(gameWithSameSize.title ?? "Unknown")")
                    return true
                }
                return false
            }
            if duplicateFound {
                return true
            }
        }

        /// If file is already in a system ROM directory, check that system first (avoids expensive system detection)
        if let systemFromPath = SystemIdentifier(rawValue: item.url.deletingLastPathComponent().lastPathComponent) {
            let filename = item.url.lastPathComponent
            let partialPath = (systemFromPath.rawValue as NSString).appendingPathComponent(filename)
            let similarName = RomDatabase.altName(item.url, systemIdentifier: systemFromPath)

            /// Check cache by partialPath and altName
            if let existingGame = gamesCache[partialPath] ?? gamesCache[similarName],
               systemFromPath.rawValue == existingGame.systemIdentifier,
               existingGame.file != nil {
                /// Verify file path matches (handles cases where file moved but cache not updated)
                if let gameFileURL = existingGame.file?.url,
                   gameFileURL.path == filePath {
                    ILOG("Found existing game in database by path system check: \(existingGame.title ?? "Unknown")")
                    return true
                }
            }

            /// Check by MD5 for this system (fast lookup - primary key is very fast)
            if let md5 = item.md5?.uppercased() {
                let md5Duplicate = try! await RealmContext.withBackgroundRealm { realm -> Bool in
                    if let gameWithSameMD5 = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
                       systemFromPath.rawValue == gameWithSameMD5.systemIdentifier,
                       gameWithSameMD5.file != nil {
                        ILOG("Found existing game with same MD5 hash by path system: \(gameWithSameMD5.title ?? "Unknown")")
                        return true
                    }
                    return false
                }
                if md5Duplicate {
                    return true
                }
            }
        }

        /// Check if file path matches any existing game's file URL (for files not already checked above)
        /// Files in ROMs/system subfolders (e.g., ROMs/com.provenance.nes/) are already handled above (lines 2545-2577)
        /// This check handles:
        ///   1. Files in Imports folder
        ///   2. Files in ROMs root (ROMs/ directly, not in a system subfolder)
        ///   3. Files outside ROMs directory entirely
        let isInImportsFolder = filePath.contains("/Imports/")
        let isInRomsRoot = filePath.hasPrefix(romsPath.path) &&
                          item.url.deletingLastPathComponent().path == romsPath.path
        let isOutsideRomsDirectory = !filePath.hasPrefix(romsPath.path)
        let needsPathCheck = isInImportsFolder || isInRomsRoot || isOutsideRomsDirectory

        if needsPathCheck {
            /// Query Realm directly on current thread instead of iterating cache to avoid thread safety issues
            let fileDuplicate = try! await RealmContext.withBackgroundRealm { realm -> Bool in
                let fileURL = URL(fileURLWithPath: filePath)
                let filename = fileURL.lastPathComponent

                let gamesWithMatchingFile = realm.objects(PVGame.self)
                    .filter("romPath ENDSWITH %@", filename)
                guard let matchingGame = gamesWithMatchingFile.first else { return false }

                if let systemID = SystemIdentifier(rawValue: item.url.deletingLastPathComponent().lastPathComponent) {
                    let expectedRomPath = (systemID.rawValue as NSString).appendingPathComponent(filename)
                    if matchingGame.romPath == expectedRomPath {
                        ILOG("Found existing game by romPath match: \(matchingGame.title ?? "Unknown") at \(filePath)")
                        return true
                    }
                }
                if let gameFileURL = matchingGame.file?.url,
                   gameFileURL.path == filePath {
                    ILOG("Found existing game by file path: \(matchingGame.title ?? "Unknown") at \(filePath)")
                    return true
                }
                return false
            }

            if fileDuplicate {
                return true
            }
        }

        /// Fallback: try to determine systems (more expensive, but needed for files not in ROM directories)
        do {
            let systems = try await gameImporterSystemsService.determineSystems(for: item)
            guard !systems.isEmpty else {
                return false
            }

            /// For each potential system, check if the ROM already exists
            for system in systems {
                let filename = item.url.lastPathComponent
                let partialPath = (system.rawValue as NSString).appendingPathComponent(filename)
                let similarName = RomDatabase.altName(item.url, systemIdentifier: system)

                /// Check cache for game keys, but query Realm for actual file access to avoid thread issues
                /// Extract primitive values from cached object before async operation
                if let cachedGame = gamesCache[partialPath] ?? gamesCache[similarName] {
                    let cachedSystemId = cachedGame.systemIdentifier
                    let cachedGameId = cachedGame.id

                    if system.rawValue == cachedSystemId {
                        /// Query Realm on current thread to verify file exists
                        let existsInRealm = try! await RealmContext.withRealm { realm -> Bool in
                            if let existingGame = realm.object(ofType: PVGame.self, forPrimaryKey: cachedGameId),
                               existingGame.file != nil {
                                ILOG("Found existing game in database: \(existingGame.title ?? "Unknown")")
                                return true
                            }
                            return false
                        }
                        if existsInRealm {
                            return true
                        }
                    }
                }

                /// Check by MD5 for this system
                if let md5 = item.md5?.uppercased() {
                    let md5Exists = try! await RealmContext.withRealm { realm -> Bool in
                        if let gameWithSameMD5 = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
                           system.rawValue == gameWithSameMD5.systemIdentifier,
                           gameWithSameMD5.file != nil {
                            ILOG("Found existing game with same MD5 hash: \(gameWithSameMD5.title ?? "Unknown")")
                            return true
                        }
                        return false
                    }
                    if md5Exists {
                        return true
                    }
                }
            }

            return false
        } catch {
            ELOG("Error checking if ROM is already in database: \(error.localizedDescription)")
            return false
        }
    }

    /// Updates the importer status message
    private func updateImporterStatus(_ message: String) {
        Task { @MainActor in
            self.importStatus = message
        }
        ILOG("Importer status: \(message)")
    }

    /// Fast filename-based duplicate check for files in imports folder
    /// Only checks if a game with the same filename already exists (no expensive MD5 calculation)
    private func quickFilenameDuplicateCheck(_ filename: String) async -> Bool {
       try! await RealmContext.withBackgroundRealm { realm in
            let gamesWithMatchingFile = realm.objects(PVGame.self)
                .filter("romPath ENDSWITH %@", filename)

            if let matchingGame = gamesWithMatchingFile.first,
               matchingGame.file != nil {
                VLOG("Quick filename check found existing game: \(matchingGame.title ?? "Unknown")")
                return true
            }
            return false
        }
    }

    /// Safely cleans up failed import files with proper error handling
    private func cleanupFailedImportFile(_ fileURL: URL) async {
        guard fileURL.path.contains("/Imports/") && FileManager.default.fileExists(atPath: fileURL.path) else {
            return // Only clean up files in imports directory that actually exist
        }

        do {
            try await FileManager.default.removeItem(at: fileURL)
            ILOG("Cleaned up failed import file: \(fileURL.path)")
        } catch {
            ELOG("Failed to clean up import file \(fileURL.path): \(error.localizedDescription)")
            // Don't throw here - cleanup failure shouldn't stop the import process
        }
    }
}

/// Extension to String to easily get filename without extension
fileprivate extension String {
    var deletingPathExtension: String {
        let url = URL(fileURLWithPath: self)
        return url.deletingPathExtension().lastPathComponent
    }
}
