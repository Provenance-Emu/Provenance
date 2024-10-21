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
import DirectoryWatcher
import Combine
import Observation

//@Observable
public final class PVGameLibraryUpdatesController {

    @Published
    public var hudState: HudState = .hidden

    @Published
    public var conflicts: [ConflictsController.ConflictItem] = []

    private let gameImporter: GameImporter
    private let directoryWatcher: DirectoryWatcher
    private let conflictsWatcher: ConflictsWatcher

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

        setupObservers()
        handleFileImports(importPath: importPath)
    }

    private func setupObservers() {
        gameImporter.importStartedHandler = { [weak self] path in
            self?.hudState = .title("Checking Import: \(URL(fileURLWithPath: path).lastPathComponent)")
        }

        gameImporter.finishedImportHandler = { [weak self] _, _ in
            self?.hudState = .title("Import Successful")
        }

        gameImporter.completionHandler = { [weak self] encounteredConflicts in
            if encounteredConflicts {
                Task { @MainActor in
                    await self?.updateConflicts()
                }
            } else {
                self?.hudState = .hidden
            }
        }

        Task {
            for await status in directoryWatcherStatusStream() {
                await MainActor.run {
                    self.hudState = Self.handleExtractionStatus(status)
                }
            }
        }

        Task {
            for await status in directoryWatcherStatusStream() {
                await MainActor.run {
                    self.hudState = Self.handleExtractionStatus(status)
                }
            }
        }

        Task {
            for await completedFiles in directoryWatcher.completedFilesSequence {
                await processCompletedFiles(completedFiles)
            }
        }
    }

    private func directoryWatcherStatusStream() -> AsyncStream<ExtractionStatus> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    let status = withObservationTracking {
                        directoryWatcher.extractionStatus
                    } onChange: {
                        continuation.yield(self.directoryWatcher.extractionStatus)
                    }

                    continuation.yield(status)

                    try? await Task.sleep(for: .seconds(0.1))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func handleFileImports(importPath: URL) {
        Task {
            let initialScan = await scanInitialFiles(at: importPath)
            if !initialScan.isEmpty {
                gameImporter.startImport(forPaths: initialScan)
            }

            for await extractedFiles in directoryWatcher.extractedFilesStream(at: importPath) {
                gameImporter.startImport(forPaths: extractedFiles)
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
        RomDatabase.sharedInstance.reloadCache()
        RomDatabase.sharedInstance.reloadFileSystemROMCache()
        let dbGames: [AnyHashable: PVGame] = await RomDatabase.sharedInstance.getGamesCache()
        let dbSystems: [AnyHashable: PVSystem] = await RomDatabase.sharedInstance.getSystemCache()

        for system in dbSystems.values {
            ILOG("PVGameLibrary: Importing \(system.identifier)")
            let files = await RomDatabase.sharedInstance.getFileSystemROMCache(for: system)
            let newGames = files.keys.filter {
                dbGames.index(forKey: (system.identifier as NSString).appendingPathComponent($0.lastPathComponent)) == nil
            }
            if !newGames.isEmpty {
                ILOG("PVGameLibraryUpdatesController: Importing \(newGames)")
                gameImporter.getRomInfoForFiles(atPaths: newGames, userChosenSystem: system.asDomain())
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
        // Process files in batches, prioritizing .m3u and .cue files
        let priorityFiles = files.filter { ["m3u", "cue"].contains($0.pathExtension.lowercased()) }
        let otherFiles = files.filter { !["m3u", "cue"].contains($0.pathExtension.lowercased()) }

        // Process priority files first
        if !priorityFiles.isEmpty {
            gameImporter.startImport(forPaths: priorityFiles)
        }

        // Then process other files
        if !otherFiles.isEmpty {
            gameImporter.startImport(forPaths: otherFiles)
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
                let candidates = RomDatabase.sharedInstance.getSystemCacheSync().values
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
