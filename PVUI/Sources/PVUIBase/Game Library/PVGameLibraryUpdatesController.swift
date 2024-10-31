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
    public var hudState: HudState = .hidden

    @Published
    public var conflicts: [ConflictsController.ConflictItem] = []

    private let gameImporter: GameImporter
    private let directoryWatcher: DirectoryWatcher
    private let conflictsWatcher: ConflictsWatcher
    private let biosWatcher: BIOSWatcher

    private var statusCheckTimer: Timer?

    public enum HudState {
        case hidden
        case title(String)
        case titleAndProgress(title: String, progress: Float)
    }

    public init(gameImporter: GameImporter, importPath: URL? = nil) {
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
            self?.hudState = .title("Checking Import: \(URL(fileURLWithPath: path).lastPathComponent)")
            DLOG("HUD state updated for import start")
        }

        gameImporter.finishedImportHandler = { [weak self] md5, modified in
            DLOG("Import finished for MD5: \(md5), modified: \(modified)")
            self?.hudState = .title("Import Successful")
            DLOG("HUD state updated for import finish")
        }

        gameImporter.completionHandler = { [weak self] encounteredConflicts in
            DLOG("Import completion handler called with conflicts: \(encounteredConflicts)")
            if encounteredConflicts {
                Task { @MainActor in
                    DLOG("Updating conflicts due to encountered conflicts")
                    await self?.updateConflicts()
                }
            }
            self?.hudState = .hidden
            DLOG("HUD state hidden after completion")
        }
    }

    private func setupExtractionStatusObserver() {
        let taskID = UUID()
        DLOG("Starting extraction status observer task: \(taskID)")

        Task {
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

                    self.hudState = Self.handleExtractionStatus(status)

                    hideTask?.cancel()

                    switch status {
                    case .completed:
                        isHidingHUD = true
                        hideTask = createHideHUDTask(taskID: taskID) {
                            isHidingHUD = false
                        }
                    case .idle:
                        self.hudState = .hidden
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
                    self.hudState = .hidden
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
                await gameImporter.startImport(forPaths: initialScan)
            }

            for await extractedFiles in directoryWatcher.extractedFilesStream(at: importPath) {
                await gameImporter.startImport(forPaths: extractedFiles)
            }
        }
    }

    private func scanInitialFiles(at path: URL) async -> [URL] {
        do {
            return try await FileManager.default.contentsOfDirectory(at: path,
                                                                     includingPropertiesForKeys: nil,
                                                                     options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants])
        } catch {
            ELOG("Error scanning initial files: \(error)")
            return []
        }
    }

    public func importROMDirectories() async {
        ILOG("PVGameLibrary: Starting Import")
        RomDatabase.reloadCache(force: true)
        RomDatabase.reloadFileSystemROMCache()
        let dbGames: [AnyHashable: PVGame] = await RomDatabase.gamesCache
        let dbSystems: [AnyHashable: PVSystem] = RomDatabase.systemCache

        for system in dbSystems.values {
            ILOG("PVGameLibrary: Importing \(system.identifier)")
            let files = await RomDatabase.getFileSystemROMCache(for: system)
            let newGames = files.keys.filter {
                dbGames.index(forKey: (system.identifier as NSString).appendingPathComponent($0.lastPathComponent)) == nil
            }
            if !newGames.isEmpty {
                ILOG("PVGameLibraryUpdatesController: Importing \(newGames)")
                await gameImporter.getRomInfoForFiles(atPaths: newGames, userChosenSystem: system.asDomain())
                #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
                await MainActor.run {
                    Task {
                        await self.addImportedGames(to: CSSearchableIndex.default(), database: RomDatabase.sharedInstance)
                    }
                }
                #endif
            }
            ILOG("PVGameLibrary: Imported OK \(system.identifier)")
        }
        ILOG("PVGameLibrary: Import Complete")
    }

    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    /// Spotlight indexing support
    @MainActor
    public func addImportedGames(to spotlightIndex: CSSearchableIndex, database: RomDatabase) async {
        enum ImportEvent {
            case finished(md5: String, modified: Bool)
            case completed(encounteredConflicts: Bool)
        }

        let eventStream = AsyncStream<ImportEvent> { continuation in
            GameImporter.shared.finishedImportHandler = { md5, modified in
                continuation.yield(.finished(md5: md5, modified: modified))
            }
            GameImporter.shared.completionHandler = { encounteredConflicts in
                continuation.yield(.completed(encounteredConflicts: encounteredConflicts))
                continuation.finish()
            }
        }

        for await event in eventStream {
            switch event {
            case .finished(let md5, _):
                addGameToSpotlight(md5: md5, spotlightIndex: spotlightIndex, database: database)
            case .completed:
                break
            }
        }

        // Clean up handlers
        GameImporter.shared.finishedImportHandler = nil
        GameImporter.shared.completionHandler = nil
    }

    /// Assitant for Spotlight indexing
    @MainActor
    private func addGameToSpotlight(md5: String, spotlightIndex: CSSearchableIndex, database: RomDatabase) {
        do {
            let realm = try Realm()
            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) else {
                DLOG("No game found for MD5: \(md5)")
                return
            }

            // Create a detached copy of the game object
            let detachedGame = game.detached()

            let item = CSSearchableItem(uniqueIdentifier: detachedGame.spotlightUniqueIdentifier,
                                        domainIdentifier: "org.provenance-emu.game",
                                        attributeSet: detachedGame.spotlightContentSet)

            spotlightIndex.indexSearchableItems([item]) { error in
                if let error = error {
                    ELOG("Error indexing game (MD5: \(md5)): \(error)")
                }
            }
        } catch {
            ELOG("Error accessing Realm or indexing game (MD5: \(md5)): \(error)")
        }
    }
    #endif

    /// Converter for `ExtractionStatus` to `HudState`
    @MainActor
    private static func handleExtractionStatus(_ status: ExtractionStatus) -> HudState {
        switch status {
        case .started(let path):
            return .titleAndProgress(title: labelMaker(path), progress: 0)
        case .updated(let path):
            return .titleAndProgress(title: labelMaker(path), progress: 0.5)
        case .completed(_):
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

    private func processCompletedFiles(_ files: [URL]) async {
        DLOG("Processing \(files.count) completed files")

        // Process files in batches, prioritizing .m3u and .cue files
        let priorityFiles = files.filter { ["m3u", "cue"].contains($0.pathExtension.lowercased()) }
        let otherFiles = files.filter { !["m3u", "cue"].contains($0.pathExtension.lowercased()) }

        DLOG("Found \(priorityFiles.count) priority files and \(otherFiles.count) other files")

        // Process priority files first
        if !priorityFiles.isEmpty {
            DLOG("Starting import for priority files")
            await gameImporter.startImport(forPaths: priorityFiles)
            DLOG("Finished importing priority files")
        }

        // Then process other files
        if !otherFiles.isEmpty {
            DLOG("Starting import for other files")
            await gameImporter.startImport(forPaths: otherFiles)
            DLOG("Finished importing other files")
        }
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

extension PVGameLibraryUpdatesController: ConflictsController {
    public func resolveConflicts(withSolutions solutions: [URL : System]) async {
        await gameImporter.resolveConflicts(withSolutions: solutions)
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

            let sortedFiles = PVEmulatorConfiguration.sortImportURLs(urls: filesInConflictsFolder)

            self.conflicts = sortedFiles.compactMap { file -> (path: URL, candidates: [System])? in
                let candidates = RomDatabase.systemCache.values
                    .filter { $0.supportedExtensions.contains(file.pathExtension.lowercased()) }
                    .map { $0.asDomain() }

                return candidates.isEmpty ? nil : .init((path: file, candidates: candidates))
            }
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
