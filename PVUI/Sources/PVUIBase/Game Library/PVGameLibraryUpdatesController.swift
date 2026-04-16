//
//  PVGameLibraryUpdatesController.swift
//  Provenance
//
//  Created by Dan Berglund on 2020-06-11.
//  Copyright 2020 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVLibrary
import PVPrimitives
import RxSwift
import RxCocoa
import CoreSpotlight
import UniformTypeIdentifiers
import PVRealm
import RealmSwift
import PVLogging
import PVFileSystem
import Combine
import Observation
#if canImport(PVAppIntents)
import PVAppIntents
#endif

//@Observable
public final class PVGameLibraryUpdatesController: ObservableObject {

    @Published
    public var conflicts: [ConflictsController.ConflictItem] = []

    public var gameImporter: any GameImporting

    public let directoryWatcher: DirectoryWatcher
    public let biosWatcher: BIOSWatcher

    private var statusCheckTimer: Timer?

    public enum State {
        case idle
        case importing
    }

    @Published
    public private(set) var state: State = .importing

    public func resume() {
        state = .importing
    }

    public func pause() {
        state = .idle
        stopObserving()
    }

    private var hudCoordinator: HUDCoordinator {
        AppState.shared.hudCoordinator
    }

    public init(gameImporter: any GameImporting, importPath: URL? = nil) {
        let importPath = importPath ?? Paths.romsImportPath

        self.gameImporter = gameImporter
        self.directoryWatcher = DirectoryWatcher(directory: importPath)
        directoryWatcher.delayedStartMonitoring()

        self.biosWatcher = .shared

        // Start lightweight ROM/BIOS/SaveState directory status watcher.
        // This triggers GameFileStatusService.refreshAllStatuses() when files
        // appear or disappear in those directories (e.g., via AirDrop, Files app,
        // iCloud Drive sync, or manual deletion).
        ROMStatusWatcher.shared.startMonitoring()

        /// Register watchers with registry for direct pause/resume control
        /// Defer registration until after initialization completes
        Task { [directoryWatcher] in
            await DirectoryWatcherRegistry.register(directoryWatcher)

            if let biosDirectoryWatcher = biosWatcher.directoryWatcher {
                await DirectoryWatcherRegistry.register(biosDirectoryWatcher)
            }
        }

        // Perform initial BIOS scan
        Task.detached(priority: .background) { [self] in
            ILOG("Performing initial BIOS scan")
            await biosWatcher.scanForBIOSFiles()
        }

        setupObservers()
        handleFileImports(importPath: importPath)
    }

    private func setupObservers() {
        setupImportHandlers()
        setupExtractionStatusObserver()
        setupCompletedFilesObserver()
        setupBIOSObserver()
    }

    private func setupImportHandlers() {
        gameImporter.importStartedHandler = { [weak self] path in
            DLOG("Import started for path: \(path)")
            Task { @MainActor [weak self] in
                DLOG("HUD state updated for import start")
                await self?.hudCoordinator.updateHUD(.title("Checking Import: \(URL(fileURLWithPath: path).lastPathComponent)"))
            }
        }

        gameImporter.finishedImportHandler = { [weak self] md5, modified in
            DLOG("Import finished for MD5: \(md5), modified: \(modified)")
            Task { @MainActor [weak self] in
                DLOG("HUD state updated for import finish")
                await self?.hudCoordinator.updateHUD(.title("Import Successful"), autoHide: true)
            }
        }

        gameImporter.completionHandler = { [weak self] encounteredConflicts in
            DLOG("Import completion handler called with conflicts: \(encounteredConflicts)")
            Task { @MainActor [weak self] in
                if encounteredConflicts {
                    DLOG("Updating conflicts due to encountered conflicts")
                    await self?.updateConflicts()
                }
                await self?.hudCoordinator.updateHUD(.hidden)
                DLOG("HUD state updated for import completion")
#if canImport(PVAppIntents)
                // Refresh widgets after library import so new games appear immediately.
                WidgetDataWriter.shared.writeFromRealm()
#endif
            }
        }
    }

    var statusExtractionSateObserver: Task<Void, Never>?
    private func setupExtractionStatusObserver() {
        let taskID = UUID()
        DLOG("Starting extraction status observer task: \(taskID)")
        statusExtractionSateObserver?.cancel()

        statusExtractionSateObserver = Task(priority: .utility) {
            defer { DLOG("Ending extraction status observer task: \(taskID)") }

            var hideTask: Task<Void, Never>?
            var isHidingHUD = false
            var lastStatus: ExtractionStatus = .idle

            for await status in extractionStatusStream() {
                guard lastStatus != status else { continue }
                lastStatus = status
                await MainActor.run {
                    DLOG("[\(taskID)] Received status: \(status)")

                    if isHidingHUD {
                        DLOG("[\(taskID)] Already hiding HUD, skipping update")
                        return
                    }

                    Task { @MainActor in
                        let hudState = Self.handleExtractionStatus(status)
                        await self.hudCoordinator.updateHUD(hudState)
                    }

                    hideTask?.cancel()

                    switch status {
                    case .completed:
                        isHidingHUD = true
                        hideTask = createHideHUDTask(taskID: taskID) {
                            isHidingHUD = false
                        }
                    case .idle:
                        hideTask = Task {
                            let hudState: HudState = .hidden
                            await self.hudCoordinator.updateHUD(hudState)
                        }
                    default:
                        break
                    }
                }
            }
        }
    }

    private func createHideHUDTask(taskID: UUID, completion: @escaping () -> Void) -> Task<Void, Never> {
        Task.detached { @MainActor in
            DLOG("[\(taskID)] Starting HUD hide delay")
            do {
                try await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    DLOG("[\(taskID)] Hiding HUD after delay")
                    Task {
                        let hudState: HudState = .hidden
                        await self.hudCoordinator.updateHUD(hudState)
                    }
                    completion()
                }
            } catch {
                DLOG("[\(taskID)] Error during hide delay: \(error)")
                completion()
            }
        }
    }

    private func setupCompletedFilesObserver() {
        let taskID = UUID()
        DLOG("Starting completed files observer task: \(taskID)")

        Task.detached(priority: .background) { [self] in
            defer { DLOG("Ending completed files observer task: \(taskID)") }

            for await completedFiles in directoryWatcher.completedFilesSequence {
                await processCompletedFiles(completedFiles)
            }
        }
    }

    private func extractionStatusStream() -> AsyncStream<ExtractionStatus> {
        let streamID = UUID()
        DLOG("Creating extraction status stream: \(streamID)")

        return AsyncStream { continuation in
            let task = Task(priority: .background) {
                defer { DLOG("Ending extraction status stream task: \(streamID)") }

                if #available(iOS 17.0, tvOS 17.0, *) {
                    await observeStatusWithTracking(streamID: streamID, continuation: continuation)
                } else {
                    await observeStatusWithTimer(streamID: streamID, continuation: continuation)
                }
            }

            continuation.onTermination = { _ in
                DLOG("Stream \(streamID) terminated, cancelling task")
                task.cancel()
                self.statusCheckTimer?.invalidate()
                self.statusCheckTimer = nil
            }
        }
    }

    @available(iOS 17.0, tvOS 17.0, *)
    private func observeStatusWithTracking(streamID: UUID, continuation: AsyncStream<ExtractionStatus>.Continuation) async {
        var lastStatus: ExtractionStatus?

        while !Task.isCancelled {
            let status = withObservationTracking {
                directoryWatcher.extractionStatus
            } onChange: {
                Task { @MainActor in
                    let newStatus = self.directoryWatcher.extractionStatus
                    if newStatus != lastStatus {
                        DLOG("[\(streamID)] Status changed to: \(newStatus)")
                        continuation.yield(newStatus)
                        lastStatus = newStatus

                        // If we reach completed or idle state, finish the stream
                        if case .completed = newStatus {
                            DLOG("[\(streamID)] Extraction completed, finishing stream")
                            continuation.finish()
                        } else if case .idle = newStatus {
                            DLOG("[\(streamID)] Extraction idle, finishing stream")
                            continuation.finish()
                        }
                    }
                }
            }

            // Only yield initial status if different
            if status != lastStatus {
                DLOG("[\(streamID)] Initial status: \(status)")
                continuation.yield(status)
                lastStatus = status

                // Check if we should finish the stream on initial status
                if case .completed = status {
                    DLOG("[\(streamID)] Initial status completed, finishing stream")
                    continuation.finish()
                    break
                } else if case .idle = status {
                    DLOG("[\(streamID)] Initial status idle, finishing stream")
                    continuation.finish()
                    break
                }
            }

            try? await Task.sleep(for: .seconds(0.1))
        }
    }

    private func observeStatusWithTimer(streamID: UUID, continuation: AsyncStream<ExtractionStatus>.Continuation) async {
        var lastStatus: ExtractionStatus?

        statusCheckTimer?.invalidate()
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let newStatus = self.directoryWatcher.extractionStatus
            if newStatus != lastStatus {
                DLOG("[\(streamID)] Timer status changed: \(newStatus)")
                continuation.yield(newStatus)
                lastStatus = newStatus
            }
        }

        let initialStatus = directoryWatcher.extractionStatus
        if initialStatus != lastStatus {
            DLOG("[\(streamID)] Timer initial status: \(initialStatus)")
            continuation.yield(initialStatus)
            lastStatus = initialStatus
        }
    }

    deinit {
        stopObserving()
    }

    func stopObserving() {
        statusCheckTimer?.invalidate()
        statusCheckTimer = nil
    }

    private func handleFileImports(importPath: URL) {
        Task {
            let initialScan = await scanInitialFiles(at: importPath)
            if !initialScan.isEmpty {
                await gameImporter.addImports(forPaths: initialScan)
            }

            for await extractedFiles in directoryWatcher.extractedFilesStream(at: importPath) {
                var readyURLs:[URL] = []
                for url in extractedFiles {
                    if await (!directoryWatcher.isWatchingFile(at: url)) {
                        readyURLs.append(url)
                    }
                }
                if (!readyURLs.isEmpty) {
                    await gameImporter.addImports(forPaths: readyURLs)
                }

                if await (!directoryWatcher.isWatchingAnyFile()) {
                    ILOG("I think all the imports are settled, might be ok to start the queue")
                    gameImporter.startProcessing()
                }
            }
        }
    }

    private func scanInitialFiles(at path: URL) async -> [URL] {
        do {
            return try await FileManager.default.contentsOfDirectory(at: path,
                                                                     includingPropertiesForKeys: nil,
                                                                     options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants,
                                                                               .skipsHiddenFiles])
        } catch {
            ELOG("Error scanning initial files: \(error)")
            return []
        }
    }

    /// auto scans ROM directories and adds to the import queue
    /// Uses incremental scanning to only check files modified since last scan
    @MainActor
    public func importROMDirectories() async {
        ILOG("PVGameLibrary: Starting Import")

        // Scan for BIOS files first
        ILOG("Starting BIOS directory scan from importROMDirectories")
        await BIOSWatcher.shared.scanForBIOSFiles()
        ILOG("Completed BIOS directory scan")

        await RomDatabase.reloadCache(force: true)
        RomDatabase.reloadFileSystemROMCache()
        let dbGames: [AnyHashable: PVGame] = await RomDatabase.gamesCache
        let dbSystems: [AnyHashable: PVSystem] = RomDatabase.systemCache
        var queueGames = false

        /// Extract all file partialPaths from games immediately after getting dbGames
        /// Use romPath directly (which is already a partial path) to avoid accessing Realm relationships
        var allPartialPaths: Set<String> = []
        var partialPathsBySystem: [String: Set<String>] = [:]
        for game in dbGames.values {
            /// Use romPath which is a direct property, avoiding Realm relationship access
            let partialPath = game.romPath
            if !partialPath.isEmpty {
                allPartialPaths.insert(partialPath)
                let systemId = game.systemIdentifier
                if partialPathsBySystem[systemId] == nil {
                    partialPathsBySystem[systemId] = Set<String>()
                }
                partialPathsBySystem[systemId]?.insert(partialPath)
            }
        }

        /// Get last scan time for incremental scanning
        let lastScanKey = "lastROMScanTime"
        let lastScanTime = UserDefaults.standard.object(forKey: lastScanKey) as? Date ?? Date.distantPast
        ILOG("Last scan time: \(lastScanTime)")

        /// Collect all files that need importing before adding them to the queue
        /// This prevents auto-start from triggering multiple times during the scan
        var allNewGames: [(files: [URL], system: SystemIdentifier)] = []

        do {
            try await RealmProvider.ensureInitialized()
        } catch {
            ELOG("Failed to initialize Realm before ROM import scan: \(error.localizedDescription)")
            return
        }
        let realm = RomDatabase.sharedInstance.realm

        for system in dbSystems.values {
            ILOG("PVGameLibrary: Scanning \(system.identifier)")
            let files = await RomDatabase.getFileSystemROMCache(for: system)

            /// Get existing partialPaths for this system (already extracted above)
            let existingPartialPaths = partialPathsBySystem[system.identifier] ?? Set<String>()
            /// Check all files, but use modification time as optimization hint
            /// Files modified since last scan definitely need checking
            /// Files not modified might still need checking if they're not in database
            let newGames = files.keys.filter { fileURL in
                let filename = fileURL.lastPathComponent
                let partialPath = (system.identifier as NSString).appendingPathComponent(filename)
                let altName = RomDatabase.altName(fileURL, systemIdentifier: system.identifier)

                /// Quick check: If file exists in cache by partialPath or altName, skip
                if dbGames.index(forKey: partialPath) != nil || dbGames.index(forKey: altName) != nil {
                    return false
                }

                /// Quick check: If partialPath is in existing paths set, skip
                if existingPartialPaths.contains(partialPath) {
                    return false
                }

                /// Optimize: If file hasn't been modified since last scan AND was scanned before,
                /// we can skip it (but files that exist but weren't scanned still need checking)
                /// However, to be safe, we'll verify the file actually exists in database by checking file path
                let filePath = fileURL.path
                let modDate = try? FileManager.default.attributesOfItem(atPath: filePath)[.modificationDate] as? Date

                /// If file hasn't been modified since last scan, do a quick verification it's actually in DB
                if let modDate = modDate, modDate <= lastScanTime {
                    /// Verify file exists in database by checking romPath (faster than URL check)
                    /// romPath stores the partial path like "{systemId}.filename" which matches our partialPath
                    let gameExists = realm.objects(PVGame.self)
                        .filter("systemIdentifier == %@ AND romPath == %@", system.identifier, partialPath)
                        .first != nil
                    if gameExists {
                        /// File exists in database, skip
                        return false
                    }
                }

                /// File doesn't exist in database (verified by cache check and optionally by path check)
                return true
            }
            if !newGames.isEmpty {
                ILOG("PVGameLibraryUpdatesController: Found \(newGames.count) new files for system \(system.identifier)")
                allNewGames.append((files: newGames, system: system.systemIdentifier))
                queueGames = true
            }
            ILOG("PVGameLibrary: Scanned \(system.identifier)")
        }

        /// Update last scan time for incremental scanning
        UserDefaults.standard.set(Date(), forKey: lastScanKey)

        /// Add all files to the queue in batches after scanning is complete
        /// This ensures auto-start only triggers once instead of per-system
        if queueGames {
            let totalFiles = allNewGames.reduce(0) { $0 + $1.files.count }
            ILOG("PVGameLibrary: Adding \(totalFiles) files to queue from \(allNewGames.count) systems")
            for (files, system) in allNewGames {
                ILOG("PVGameLibrary: Adding \(files.count) files for system \(system.rawValue)")
                await gameImporter.addImports(forPaths: files, targetSystem: system)
            }
            ILOG("PVGameLibrary: Queued all new items, starting to process")
            gameImporter.startProcessing()
        }
        ILOG("PVGameLibrary: importROMDirectories complete")
    }

    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    /// Spotlight indexing support — runs off the main actor to avoid blocking UI during boot (#2980)
    public func addImportedGames(to spotlightIndex: CSSearchableIndex = CSSearchableIndex.default(), database: RomDatabase = RomDatabase.sharedInstance) async {
        ILOG("Starting Spotlight indexing for all games")

        // Create a batch processor to handle multiple items at once
        var pendingItems: [CSSearchableItem] = []
        let batchSize = 50 // Smaller batch size for more frequent updates
        var totalIndexed = 0

        // Function to process a batch of items
        func processBatch() async {
            guard !pendingItems.isEmpty else { return }

            do {
                try await spotlightIndex.indexSearchableItems(pendingItems)
                totalIndexed += pendingItems.count
                ILOG("Indexed batch of \(pendingItems.count) items (Total: \(totalIndexed))")
                pendingItems.removeAll(keepingCapacity: true)
            } catch {
                ELOG("Error batch indexing games: \(error)")
            }
        }

        do {
            let frozenGames = try await RealmContext.withBackgroundRealm { realm -> [PVGame] in
                let allGames = realm.objects(PVGame.self)
                ILOG("Found \(allGames.count) games to process")
                return allGames.map { $0.freeze() }
            }

            ILOG("Processing \(frozenGames.count) games for indexing")

            // Process each game
            for frozenGame in frozenGames {

                // Create the searchable item
                let attributeSet = frozenGame.spotlightContentSet

                // Add keywords for better searchability
                if var keywords = attributeSet.keywords as? [String] {
                    if let systemName = frozenGame.system?.name, !keywords.contains(systemName) {
                        keywords.append(systemName)
                    }
                    if let manufacturer = frozenGame.system?.manufacturer, !keywords.contains(manufacturer) {
                        keywords.append(manufacturer)
                    }
                    attributeSet.keywords = keywords
                }

                // Create the searchable item
                let item = CSSearchableItem(
                    uniqueIdentifier: "org.provenance-emu.game.\(frozenGame.md5Hash)",
                    domainIdentifier: "org.provenance-emu.games",
                    attributeSet: attributeSet
                )

                pendingItems.append(item)

                // Process batch if we've reached the batch size
                if pendingItems.count >= batchSize {
                    await processBatch()
                }
            }

            // Process any remaining items
            await processBatch()

            // Now index save states
            await indexSaveStates(spotlightIndex: spotlightIndex)

            ILOG("Completed Spotlight indexing")
        } catch {
            ELOG("Error during Spotlight indexing: \(error)")
        }
    }

    /// Index all save states in Spotlight
    private func indexSaveStates(spotlightIndex: CSSearchableIndex) async {
        ILOG("Starting Spotlight indexing for save states")

        let saveStatesWithGames: [(saveState: PVSaveState, game: PVGame)] = try! await RealmContext.withBackgroundRealm { realm in
            let saveStates = realm.objects(PVSaveState.self)
            ILOG("Found \(saveStates.count) save states to process")
            var results: [(PVSaveState, PVGame)] = []
            results.reserveCapacity(saveStates.count)
            for saveState in saveStates where saveState.game != nil {
                if let game = saveState.game {
                    results.append((saveState.freeze(), game.freeze()))
                }
            }
            return results
        }

        var pendingItems: [CSSearchableItem] = []
        let batchSize = 50
        var totalIndexed = 0

        func processBatch() async {
            guard !pendingItems.isEmpty else { return }

            do {
                try await spotlightIndex.indexSearchableItems(pendingItems)
                totalIndexed += pendingItems.count
                ILOG("Indexed batch of \(pendingItems.count) save states (Total: \(totalIndexed))")
                pendingItems.removeAll(keepingCapacity: true)
            } catch {
                ELOG("Error batch indexing save states: \(error)")
            }
        }

        ILOG("Found \(saveStatesWithGames.count) save states with games to index")

        // Process each save state
        for (saveState, game) in saveStatesWithGames {
            // Create attribute set using the registered Provenance save-state UTI
            // com.provenance.savestate is exported in the app's Info.plist and conforms to public.data
            let attributeSet = CSSearchableItemAttributeSet(contentType: .savestate)
            let saveStateTitle = "Save State: \(game.title)"
            attributeSet.title = saveStateTitle
            attributeSet.displayName = saveStateTitle
            attributeSet.contentDescription = "Save state for \(game.title) on \(game.system?.name ?? "Unknown System")"

            // Add date information
            attributeSet.contentCreationDate = saveState.date
            attributeSet.contentModificationDate = saveState.date

            // Add screenshot thumbnail if available, fallback to game artwork.
            // Only read inline thumbnailData from local files — Data(contentsOf:) on
            // a remote URL would block the thread with a synchronous network request.
            if let imageURL = saveState.image?.url {
                attributeSet.thumbnailURL = imageURL
                if imageURL.isFileURL {
                    attributeSet.thumbnailData = try? Data(contentsOf: imageURL)
                }
            } else if let gameArtworkURL = game.pathOfCachedImage {
                attributeSet.thumbnailURL = gameArtworkURL
                if gameArtworkURL.isFileURL {
                    attributeSet.thumbnailData = try? Data(contentsOf: gameArtworkURL)
                }
            }

            // Add keywords
            var keywords = ["save state", "saved game", "provenance", "emulator"]
            if let systemName = game.system?.name {
                keywords.append(systemName)
            }
            attributeSet.keywords = keywords

            // Create searchable item
            let item = CSSearchableItem(
                uniqueIdentifier: "org.provenance-emu.savestate.\(saveState.id)",
                domainIdentifier: "org.provenance-emu.games",
                attributeSet: attributeSet
            )

            pendingItems.append(item)

            // Process batch if we've reached the batch size
            if pendingItems.count >= batchSize {
                await processBatch()
            }
        }
        // Process any remaining items
        await processBatch()
        ILOG("Completed save state indexing")
    }
    #endif


    private func processCompletedFiles(_ files: [URL]) async {
        DLOG("Processing \(files.count) completed files")

        // Filter out files that no longer exist (they may have been moved during import)
        let existingFiles = files.filter { FileManager.default.fileExists(atPath: $0.path) }

        if existingFiles.count < files.count {
            let skippedCount = files.count - existingFiles.count
            DLOG("Skipped \(skippedCount) file(s) that no longer exist (likely moved during import)")
        }

        // Process files in batches, prioritizing .m3u and .cue files
        let priorityFiles = existingFiles.filter { ["m3u", "cue"].contains($0.pathExtension.lowercased()) }
        let otherFiles = existingFiles.filter { !["m3u", "cue"].contains($0.pathExtension.lowercased()) }

        DLOG("Found \(priorityFiles.count) priority files and \(otherFiles.count) other files")

        // Process priority files first
        if !priorityFiles.isEmpty {
            DLOG("Starting import for priority files")
            await gameImporter.addImports(forPaths: priorityFiles)
            DLOG("Finished importing priority files")
        }

        // Then process other files
        if !otherFiles.isEmpty {
            DLOG("Starting import for other files")
            await gameImporter.addImports(forPaths: otherFiles)
            DLOG("Finished importing other files")
        }

        //it seems reasonable to kick off the queue here
        if state == .importing {
            gameImporter.startProcessing()
        }
    }

    var biosTask: Task<Void, Never>?
    private func setupBIOSObserver() {
        biosTask?.cancel()
        biosTask = Task(priority: .utility) {
            for await newBIOSFiles in biosWatcher.newBIOSFilesSequence {
                if state == .importing {
                    await processBIOSFiles(newBIOSFiles)
                }
            }
        }
    }

    private func processBIOSFiles(_ files: [URL]) async {
        guard state == .importing else { return }

        await files.asyncForEach { file in
            do {
                try await PVEmulatorConfiguration.validateAndImportBIOS(at: file)
                ILOG("Successfully imported BIOS file: \(file.lastPathComponent)")
            } catch {
                ELOG("Failed to import BIOS file: \(error)")
            }
        }
    }
}

/// Hud state for the game library updates controller
extension PVGameLibraryUpdatesController {
    /// Converter for `ExtractionStatus` to `HudState`
    @MainActor
    private static func handleExtractionStatus(_ status: ExtractionStatus) -> HudState {
        switch status {
        case .started(let path), .startedArchive(let path):
            return .titleAndProgress(title: labelMaker(path), progress: 0)
        case .updated(let path), .updatedArchive(let path):
            return .titleAndProgress(title: labelMaker(path), progress: 0.5)
        case .completed(_), .completedArchive(_):
            return .titleAndProgress(title: "Extraction Complete!", progress: 1)
        case .failed(let error):
            // For error states, we want to auto-dismiss after a delay
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled {
                    await AppState.shared.hudCoordinator.updateHUD(.hidden)
                }
            }
            // Return a title-only state for errors to make it more visible
            return .title("Extraction Failed: \(error.localizedDescription)", subtitle: "Tap to dismiss")
        case .idle:
            return .hidden
        }
    }

    /// Assistant for `HudState` titles.
    private static func labelMaker(_ path: URL) -> String {
        #if os(tvOS)
        return "Extracting Archive: \(path.lastPathComponent)"
        #else
        return "Extracting Archive\n\(path.lastPathComponent)"
        #endif
    }
}

extension PVGameLibraryUpdatesController: ConflictsController {
    public func resolveConflicts(withSolutions solutions: [URL : System]) async {
        //TODO: fix this
//        await gameImporter.resolveConflicts(withSolutions: solutions)
        await updateConflicts()
    }

    public func deleteConflict(path: URL) async {
        DLOG("Deleting conflict file at: \(path.path)")

        // First find and remove the item from the import queue using Task to handle async property
        Task {
            let importQueue = await gameImporter.importQueue
            if let index = importQueue.firstIndex(where: { $0.url == path }) {
                DLOG("Found matching item in import queue, removing at index \(index)")
                await gameImporter.removeImports(at: IndexSet(integer: index))
            }
        }

        // Then delete the actual file
        do {
            try FileManager.default.removeItem(at: path)
            DLOG("Successfully deleted file")
        } catch {
            ELOG("Failed to delete file: \(error.localizedDescription)")
        }

        await updateConflicts()
    }

    public func updateConflicts() async {
        await MainActor.run {
            /// Conflicts are now handled directly by GameImporter
            /// This method is kept for ConflictsController protocol compliance
            /// but conflicts are managed internally by the importer
            self.conflicts = []
        }
    }
}

/// Picked documents controller handler
public extension PVGameLibraryUpdatesController {
    func handlePickedDocuments(_ urls: [URL]) {
        // Start async file copying with progress tracking
        Task {
            await copyFilesToImports(urls: urls)
        }
    }

    /// Async file copying with progress tracking
    private func copyFilesToImports(urls: [URL]) async {
        for url in urls {
            await copyFileToImports(from: url)
        }
    }

    private func copyFileToImports(from sourceURL: URL) async {
        let secureDoc = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if secureDoc {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationURL = Paths.romsImportPath.appendingPathComponent(sourceURL.lastPathComponent)

        // Start tracking the copy operation
        let operationId = await FileCopyProgressTracker.shared.startCopyOperation(
            sourceURL: sourceURL,
            destinationURL: destinationURL
        )

        do {
            // Update status to copying
            await FileCopyProgressTracker.shared.updateProgress(
                operationId: operationId,
                copiedBytes: 0,
                status: .copying
            )

            if sourceURL.hasDirectoryPath {
                try await copyDirectoryWithProgress(from: sourceURL, to: destinationURL, operationId: operationId)
            } else {
                try await copyFileWithProgress(from: sourceURL, to: destinationURL, operationId: operationId)
            }

            // Mark as completed
            await FileCopyProgressTracker.shared.completeCopyOperation(
                operationId: operationId,
                success: true
            )

            ILOG("Copied file from \(sourceURL.path) to \(destinationURL.path)")

            // Let DirectoryWatcher handle import queue addition — it has proper file stability
            // detection (waits for writes to complete) that prevents race conditions.
            // Previously, both this explicit call AND the watcher would fire, causing
            // double-processing of zip files and GUID-related import errors.

        } catch {
            // Mark as failed
            await FileCopyProgressTracker.shared.completeCopyOperation(
                operationId: operationId,
                success: false,
                error: error
            )

            ELOG("Failed to copy file from \(sourceURL.path) to \(destinationURL.path). Error: \(error)")
        }
    }

    /// Copy a single file with progress tracking
    private func copyFileWithProgress(from sourceURL: URL, to destinationURL: URL, operationId: UUID) async throws {
        // For cloud files, we need to handle them differently
        if sourceURL.absoluteString.lowercased().contains("icloud") ||
           sourceURL.absoluteString.lowercased().contains("ubiquity") {
            try await copyCloudFileWithProgress(from: sourceURL, to: destinationURL, operationId: operationId)
        } else {
            try await copyLocalFileWithProgress(from: sourceURL, to: destinationURL, operationId: operationId)
        }
    }

    /// Copy a cloud file with progress tracking
    private func copyCloudFileWithProgress(from sourceURL: URL, to destinationURL: URL, operationId: UUID) async throws {
        // Update status to downloading
        await FileCopyProgressTracker.shared.updateProgress(
            operationId: operationId,
            copiedBytes: 0,
            status: .downloading
        )

        // For cloud files, we need to coordinate the download first
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var success = false

        coordinator.coordinate(readingItemAt: sourceURL, options: .withoutChanges, error: &error) { (readingURL) in
            do {
                // Get file size for progress tracking
                let resources = try readingURL.resourceValues(forKeys: [.fileSizeKey])
                let totalBytes = Int64(resources.fileSize ?? 0)

                // Copy the file
                try FileManager.default.copyItem(at: readingURL, to: destinationURL)

                // Update progress to completed
                Task {
                    await FileCopyProgressTracker.shared.updateProgress(
                        operationId: operationId,
                        copiedBytes: totalBytes,
                        status: .completed
                    )
                }

                success = true
            } catch {
                ELOG("Failed to copy cloud file: \(error.localizedDescription)")
            }
        }

        if let error = error {
            throw error
        }

        if !success {
            throw NSError(domain: "FileCopyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to copy cloud file"])
        }
    }

    /// Copy a local file with progress tracking
    private func copyLocalFileWithProgress(from sourceURL: URL, to destinationURL: URL, operationId: UUID) async throws {
        // For local files, we can use the standard copy method
        // In the future, we could implement chunked copying for very large files
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        // Get the final file size and update progress
        let resources = try destinationURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = Int64(resources.fileSize ?? 0)

        await FileCopyProgressTracker.shared.updateProgress(
            operationId: operationId,
            copiedBytes: fileSize,
            status: .completed
        )
    }

    /// Copy a directory with progress tracking
    private func copyDirectoryWithProgress(from sourceURL: URL, to destinationURL: URL, operationId: UUID) async throws {
        // For directories, we use the standard copy method
        // In the future, we could implement recursive progress tracking
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        // Calculate total directory size and update progress
        let directorySize = try calculateDirectorySize(at: destinationURL)

        await FileCopyProgressTracker.shared.updateProgress(
            operationId: operationId,
            copiedBytes: directorySize,
            status: .completed
        )
    }

    /// Calculate the total size of a directory
    private func calculateDirectorySize(at url: URL) throws -> Int64 {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: resourceKeys)

        var totalSize: Int64 = 0

        while let fileURL = enumerator?.nextObject() as? URL {
            let resources = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if resources.isRegularFile == true {
                totalSize += Int64(resources.fileSize ?? 0)
            }
        }

        return totalSize
    }
}
