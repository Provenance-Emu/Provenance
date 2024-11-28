//
//  PVGameLibraryUpdatesController.swift
//  Provenance
//
//  Created by Dan Berglund on 2020-06-11.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVLibrary
import PVPrimitives
import RxSwift
import RxCocoa
import CoreSpotlight
import PVRealm
import RealmSwift
import PVLogging
import PVFileSystem
import Combine
import Observation
import Perception

//@Observable
public final class PVGameLibraryUpdatesController: ObservableObject {

    @Published
    public var conflicts: [ConflictsController.ConflictItem] = []

    public var gameImporter: any GameImporting

    private let directoryWatcher: DirectoryWatcher
    private let conflictsWatcher: ConflictsWatcher
    private let biosWatcher: BIOSWatcher

    private var statusCheckTimer: Timer?

    private var hudCoordinator: HUDCoordinator {
        AppState.shared.hudCoordinator
    }

    public init(gameImporter: any GameImporting, importPath: URL? = nil) {
        let importPath = importPath ?? Paths.romsImportPath

        self.gameImporter = gameImporter
        self.directoryWatcher = DirectoryWatcher(directory: importPath)
        directoryWatcher.delayedStartMonitoring()

        self.conflictsWatcher = .shared
        self.biosWatcher = .shared

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
            }
        }
    }

    var statusExtractionSateObserver: Task<Void, Never>?
    private func setupExtractionStatusObserver() {
        let taskID = UUID()
        DLOG("Starting extraction status observer task: \(taskID)")
        statusExtractionSateObserver?.cancel()

        statusExtractionSateObserver = Task {
            defer { DLOG("Ending extraction status observer task: \(taskID)") }

            var hideTask: Task<Void, Never>?
            var isHidingHUD = false

            for await status in extractionStatusStream() {
                await MainActor.run {
                    DLOG("[\(taskID)] Received status: \(status)")

                    if isHidingHUD {
                        DLOG("[\(taskID)] Already hiding HUD, skipping update")
                        return
                    }

                    Task {
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

        Task {
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
            let task = Task {
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
                let newStatus = self.directoryWatcher.extractionStatus
                if newStatus != lastStatus {
                    DLOG("[\(streamID)] Status changed: \(newStatus)")
                    continuation.yield(newStatus)
                    lastStatus = newStatus
                }
            }

            if status != lastStatus {
                DLOG("[\(streamID)] Initial status: \(status)")
                continuation.yield(status)
                lastStatus = status
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
                gameImporter.addImports(forPaths: initialScan)
            }

            for await extractedFiles in directoryWatcher.extractedFilesStream(at: importPath) {
                var readyURLs:[URL] = []
                for url in extractedFiles {
                    if await (!directoryWatcher.isWatchingFile(at: url)) {
                        readyURLs.append(url)
                    }
                }
                if (!readyURLs.isEmpty) {
                    gameImporter.addImports(forPaths: readyURLs)
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
    public func importROMDirectories() async {
        ILOG("PVGameLibrary: Starting Import")
        RomDatabase.reloadCache(force: true)
        RomDatabase.reloadFileSystemROMCache()
        let dbGames: [AnyHashable: PVGame] = await RomDatabase.gamesCache
        let dbSystems: [AnyHashable: PVSystem] = RomDatabase.systemCache
        var queueGames = false

        for system in dbSystems.values {
            ILOG("PVGameLibrary: Importing \(system.identifier)")
            let files = await RomDatabase.getFileSystemROMCache(for: system)
            let newGames = files.keys.filter {
                dbGames.index(forKey: (system.identifier as NSString).appendingPathComponent($0.lastPathComponent)) == nil
            }
            if !newGames.isEmpty {
                ILOG("PVGameLibraryUpdatesController: Adding \(newGames) to the queue")
                gameImporter.addImports(forPaths: newGames, targetSystem:system)
                queueGames = true
            }
            ILOG("PVGameLibrary: Added items for \(system.identifier) to queue")
        }
        if (queueGames) {
            ILOG("PVGameLibrary: Queued new items, starting to process")
            gameImporter.startProcessing()
        }
        ILOG("PVGameLibrary: importROMDirectories complete")
    }

    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    /// Spotlight indexing support
    @MainActor
    public func addImportedGames(to spotlightIndex: CSSearchableIndex, database: RomDatabase) async {
        enum ImportEvent {
            case finished(md5: String, modified: Bool)
            case completed(encounteredConflicts: Bool)
        }

        /// Create a batch processor to handle multiple items at once
        var pendingItems: [CSSearchableItem] = []
        let batchSize = 50 /// Smaller batch size for more frequent updates

        func processBatch() async {
            guard !pendingItems.isEmpty else { return }

            do {
                try await spotlightIndex.indexSearchableItems(pendingItems)
                DLOG("Indexed batch of \(pendingItems.count) items")
                pendingItems.removeAll(keepingCapacity: true)
            } catch {
                ELOG("Error batch indexing games: \(error)")
            }
        }

        let eventStream = AsyncStream<ImportEvent> { continuation in
            GameImporter.shared.spotlightFinishedImportHandler = { md5, modified in
                continuation.yield(.finished(md5: md5, modified: modified))
            }
            GameImporter.shared.spotlightCompletionHandler = { encounteredConflicts in
                continuation.yield(.completed(encounteredConflicts: encounteredConflicts))
                continuation.finish()
            }
        }

        for await event in eventStream {
            switch event {
            case .finished(let md5, _):
                do {
                    let realm = try await Realm()
                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) else {
                        DLOG("No game found for MD5: \(md5)")
                        continue
                    }

                    /// Create a detached copy of the game object
                    let detachedGame = game.detached()

                    let item = CSSearchableItem(
                        uniqueIdentifier: detachedGame.spotlightUniqueIdentifier,
                        domainIdentifier: "org.provenance-emu.game",
                        attributeSet: detachedGame.spotlightContentSet
                    )

                    pendingItems.append(item)

                    /// Process batch if we've reached the batch size
                    if pendingItems.count >= batchSize {
                        await processBatch()
                    }

                } catch {
                    ELOG("Error accessing Realm or indexing game (MD5: \(md5)): \(error)")
                }
            case .completed:
                /// Process any remaining items
                await processBatch()
                break
            }
        }

        /// Clean up handlers
        GameImporter.shared.spotlightFinishedImportHandler = nil
        GameImporter.shared.spotlightCompletionHandler = nil
    }
    #endif


    private func processCompletedFiles(_ files: [URL]) async {
        DLOG("Processing \(files.count) completed files")

        // Process files in batches, prioritizing .m3u and .cue files
        let priorityFiles = files.filter { ["m3u", "cue"].contains($0.pathExtension.lowercased()) }
        let otherFiles = files.filter { !["m3u", "cue"].contains($0.pathExtension.lowercased()) }

        DLOG("Found \(priorityFiles.count) priority files and \(otherFiles.count) other files")

        // Process priority files first
        if !priorityFiles.isEmpty {
            DLOG("Starting import for priority files")
            gameImporter.addImports(forPaths: priorityFiles)
            DLOG("Finished importing priority files")
        }

        // Then process other files
        if !otherFiles.isEmpty {
            DLOG("Starting import for other files")
            gameImporter.addImports(forPaths: otherFiles)
            DLOG("Finished importing other files")
        }

        //it seems reasonable to kick off the queue here
//        gameImporter.startProcessing()
    }

    private func setupBIOSObserver() {
        Task {
            for await newBIOSFiles in biosWatcher.newBIOSFilesSequence {
                await processBIOSFiles(newBIOSFiles)
            }
        }
    }

    private func processBIOSFiles(_ files: [URL]) async {
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
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            ELOG("\(error.localizedDescription)")
        }
        await updateConflicts()
    }

    public func updateConflicts() async {
        await MainActor.run {
//            let conflictsPath = gameImporter.conflictPath
//            guard let filesInConflictsFolder = try? FileManager.default.contentsOfDirectory(at: conflictsPath, includingPropertiesForKeys: nil, options: []) else {
//                self.conflicts = []
//                return
//            }
            let filesInConflictsFolder = conflictsWatcher.conflictFiles

            //TODO: fix alongside conflicts
//            let sortedFiles = PVEmulatorConfiguration.sortImportURLs(urls: filesInConflictsFolder)
//
//            self.conflicts = sortedFiles.compactMap { file -> (path: URL, candidates: [System])? in
//                let candidates = RomDatabase.systemCache.values
//                    .filter { $0.supportedExtensions.contains(file.pathExtension.lowercased()) }
//                    .map { $0.asDomain() }
//
//                return candidates.isEmpty ? nil : .init((path: file, candidates: candidates))
//            }
        }
    }
}

/// Picked documents controller handler
public extension PVGameLibraryUpdatesController {
    func handlePickedDocuments(_ urls: [URL]) {
        for url in urls {
            copyFileToImports(from: url)
        }
    }

    private func copyFileToImports(from sourceURL: URL) {
        let secureDoc = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if secureDoc {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationURL = Paths.romsImportPath.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            if sourceURL.hasDirectoryPath {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            } else {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            }
            ILOG("Copied file from \(sourceURL.path) to \(destinationURL.path)")
        } catch {
            ELOG("Failed to copy file from \(sourceURL.path) to \(destinationURL.path). Error: \(error)")
        }
    }
}
