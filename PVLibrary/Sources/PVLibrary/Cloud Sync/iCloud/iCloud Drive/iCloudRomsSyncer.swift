//
//  iCloudRomsSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import Combine
import RxSwift
import PVFileSystem

public class iCloudRomsSyncer: iCloudContainerSyncer {
    
    public enum GameStatus {
        case gameExists
        case gameDoesNotExist
    }
    
    let gameImporter = GameImporter.shared
    /// Disc sets (cue, gdi, m3u and their files) arriving one file at a time (`MultiFileSetArrivals`).
    let multiFileSets = MultiFileSetArrivalQueue()
    var romsDatabaseSubscriber: AnyCancellable?
    
    public override var downloadedCount: Int {
        get async {
            let multiFileSetsCount = await multiFileSets.count
            return await newFiles.count + multiFileSetsCount
        }
    }
    
    convenience init(notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        self.init(directories: ["ROMs"],
                  notificationCenter: notificationCenter,
                  errorHandler: errorHandler)
        fileImportQueueMaxCount = 1
        let publishers = [.GameImporterDidFinish, .RomDatabaseInitialized].map { notificationCenter.publisher(for: $0) }
        romsDatabaseSubscriber = Publishers.MergeMany(publishers).sink { [weak self] _ in
            Task {
                await self?.handleImportNewRomFiles()
            }
        }
    }
    
    override func stopObserving() {
        super.stopObserving()
        romsDatabaseSubscriber?.cancel()
    }
    
    public override func loadAllFromICloud(iterationComplete: (() async -> Void)?) async -> Completable {
        //ensure that the games are cached so we do NOT hit the database so much when checking for existence of games
        RomDatabase.reloadGamesCache()
        return await super.loadAllFromICloud(iterationComplete: iterationComplete)
    }
    
    /// The only time that we don't know if files have been deleted by the user is when it happens while the app is closed. so we have to query the db and check
    func removeGamesDeletedWhileApplicationClosed() async {
        await removeDeletionsCriticalSection.performWithLock { [weak self] in
            guard let canPurge = await self?.canPurgeDatastore,
                  canPurge
            else {
                return
            }
            await self?.handleRemoveGamesDeletedWhileApplicationClosed()
        }
    }
    
    func handleRemoveGamesDeletedWhileApplicationClosed() async {
        defer {
            purgeStatus = .complete
        }
        guard let actualDocumentsUrl = documentsURL,
              let romsDirectoryName = directories.first
        else {
            return
        }
        
        let romsPath = actualDocumentsUrl.appendingPathComponent(romsDirectoryName)
        do {
            let romsDatastore = try await RomsDatastore()
            await romsDatastore.deleteGamesDeletedWhileApplicationClosed(romsPath: romsPath)
        } catch {
            CloudSyncManager.syncLog.event(.sync, item: "roms/purge", status: .failed, detail: "error removing game entries that do NOT exist in the cloud container \(romsPath)")
        }
    }
    
    public override func insertDownloadedFile(_ file: URL) async {
        guard let _ = await pendingFilesToDownload.remove(file)
        else {
            return
        }
        
        // A file in a disc set's own folder (`ROMs/<system>/<set>/`) belongs to the system above it;
        // any other folder under a system folder (DOS, MAME, NAOMI GD-ROM) is left alone as before.
        let pending = await pendingFilesToDownload.elements
        let isInSetFolder = MultiFileSetArrivals.isInSetFolder(file, pending: pending)
        let systemDirectory = isInSetFolder ? MultiFileSetFolder.systemFolderName(ofFileAt: file) : file.parentPathComponent
        DLOG("attempting to add file to game import queue: \(file), system directory: \(systemDirectory)")
        //we should only add to the import queue files that are actual ROMs, anything else can be ignored.
        guard systemDirectory.range(of: "com.provenance.",
                                    options: [.caseInsensitive, .anchored]) != nil,
              file.lastPathComponent.removingPercentEncoding != nil
        else {
            return
        }
        guard await getGameStatus(of: file) == .gameDoesNotExist
        else {
            DLOG("\(file) already exists in database. skipping...")
            if MultiFileSetArrivals.isIndex(file) {
                // Its tracks that already arrived are part of that game, not games of their own.
                await multiFileSets.discardMembers(ofIndexAt: file)
            }
            return
        }
        CloudSyncManager.syncLog.event(.download, item: "roms/\(file.lastPathComponent)", status: .inProgress, detail: "\(file) does NOT exist in database, adding to import set")
        let system = SystemIdentifier(rawValue: systemDirectory)
        switch system {
        case .Atari2600, .Atari5200, .Atari7800, .Genesis:
            await newFiles.insert(file)
        // for sega cd ROMs, ignore the .brm file that is used for saves
        case .SegaCD where "brm".caseInsensitiveCompare(file.pathExtension) == .orderedSame:
            break
        default:
            // Re-run set grouping for the file's folder: a set is released as soon as its last file
            // is downloaded, whether that is a track or the index.
            let singles = await multiFileSets.arrived(file, pending: pending, importedIndexes: importedIndexFiles(listing: file))
            for single in singles {
                await newFiles.insert(single)
            }
        }
        await handleImportNewRomFiles()
    }

    /// Index files (cue, gdi, m3u) downloaded in `file`'s folder that list it and whose game is
    /// already in the library. Empty for an index file.
    func importedIndexFiles(listing file: URL) -> Set<URL> {
        guard !MultiFileSetArrivals.isIndex(file) else { return [] }
        return Set(MultiFileSetPlacement.outermostIndexFiles(in: file.deletingLastPathComponent())
            .filter { MultiFileSetArrivals.lists($0, file) && getGameStatus(of: $0) == .gameExists })
    }
    
    /// Checks if game exists in game cache
    /// - Parameter file: file to check against
    /// - Returns: whether or not game exists in game cache
    func getGameStatus(of file: URL) -> GameStatus {
        guard let (existingGame, system) = getGameFromCache(of: file),
              system.rawValue == existingGame.systemIdentifier
        else {
            return .gameDoesNotExist
        }
        return .gameExists
    }
    
    func getGameFromCache(of file: URL) -> (PVGame, SystemIdentifier)? {
        let parentDirectory = file.parentPathComponent
        let isInSetFolder = MultiFileSetArrivals.isInSetFolder(file, pending: [])
        guard let system = SystemIdentifier(rawValue: isInSetFolder ? MultiFileSetFolder.systemFolderName(ofFileAt: file) : parentDirectory),
              let parentUrl = URL(string: parentDirectory)
        else {
            DLOG("error obtaining existence of \(file) in game cache.")
            return nil
        }
        let partialPath = parentUrl.appendingPathComponent(file.fileName)
        DLOG("system: \(system), partialPath: \(partialPath)")
        let similarName = RomDatabase.altName(file, systemIdentifier: system)
        let gamesCache = RomDatabase.gamesCache
        // A game in a set folder is keyed `<system>/<set>/<index>` (its romPath).
        let partialPathAsString = isInSetFolder ? RomDatabase.romPath(for: file, systemIdentifier: system.rawValue) : partialPath.absoluteString
        DLOG("partialPathAsString: \(partialPathAsString), similarName: \(similarName)")
        guard let existingGame = gamesCache[partialPathAsString] ?? gamesCache[similarName]
        else {
            return nil
        }
        return (existingGame, system)
    }
    
    public override func deleteFromDatastore(_ file: URL) async {
        guard let fileName = file.lastPathComponent.removingPercentEncoding,
              let parentDirectory = file.parentPathComponent.removingPercentEncoding
        else {
            return
        }
        do {
            guard let (existingGame, _) = getGameFromCache(of: file)
            else {
                return
            }
            let romPath = "\(parentDirectory)/\(fileName)"
            DLOG("attempting to query PVGame by romPath: \(romPath)")
            let romsDatastore = try await RomsDatastore()
            try await romsDatastore.deleteGame(md5Hash: existingGame.md5Hash)
        } catch {
            await errorHandler.handleError(error, file: file)
            CloudSyncManager.syncLog.event(.delete, item: "roms/\(file.lastPathComponent)", status: .failed, detail: "error deleting ROM \(file) from database: \(error)")
        }
    }
    
    func handleImportNewRomFiles() async {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
#if DEBUG
        await gameImporter.clearCompleted()
#endif
        await removeGamesDeletedWhileApplicationClosed()
        // Nothing left to download: files still held for a set (a set missing a file, a lone .bin
        // game) are imported as they are.
        if await pendingFilesToDownload.isEmpty {
            for single in await multiFileSets.flush() {
                await newFiles.insert(single)
            }
        }
        // we only proceed if there are actual ROMs to import, or a disc set with all of its files
        let hasReadySets = await multiFileSets.hasReadySets
        guard await !newFiles.isEmpty || hasReadySets
        else {
            return
        }
        await tryToImportNewRomFiles()
    }
    
    func tryToImportNewRomFiles() async {
        //if the importer is currently importing files, we have to wait
        let importState = await gameImporter.processingState
        guard importState == .idle,
              importState != .paused
        else {
            return
        }
        await importNewRomFiles()
        
    }
    
    func importNewRomFiles() async {
        var nextFilesToProcess = await prepareNextBatchToProcess()
        if nextFilesToProcess.isEmpty,
           let nextSet = await multiFileSets.nextSet() {
            nextFilesToProcess = nextSet
        }
        let importPaths = [URL](nextFilesToProcess)
        await gameImporter.addImports(forPaths: importPaths)
        let pendingProcessingCount = await downloadedCount
        let pendingFilesToDownloadCount = await pendingFilesToDownload.count
        CloudSyncManager.syncLog.event(.sync, item: "roms/import", status: .inProgress, detail: "ROMs: downloading: \(pendingFilesToDownloadCount), pending to process: \(pendingProcessingCount), processing: \(importPaths.count)")
        if await newFiles.isEmpty {
            await uploadedFiles.removeAll()
        }
        gameImporter.startProcessing()
    }
}
