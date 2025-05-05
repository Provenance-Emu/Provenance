//
//  iCloudRomsSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import Combine
import RxSwift

public class iCloudRomsSyncer: iCloudContainerSyncer {
    
    public enum GameStatus {
        case gameExists
        case gameDoesNotExist
    }
    
    let gameImporter = GameImporter.shared
    let multiFileRoms: ConcurrentDictionary<String, [URL]> = [:]
    var romsDatabaseSubscriber: AnyCancellable?
    
    public override var downloadedCount: Int {
        get async {
            let multiFileRomsCount = await multiFileRoms.count
            return await newFiles.count + multiFileRomsCount
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
            ELOG("error removing game entries that do NOT exist in the cloud container \(romsPath)")
        }
    }
    
    public override func insertDownloadedFile(_ file: URL) async {
        guard let _ = await pendingFilesToDownload.remove(file)
        else {
            return
        }
        
        let parentDirectory = file.parentPathComponent
        DLOG("attempting to add file to game import queue: \(file), parent directory: \(parentDirectory)")
        //we should only add to the import queue files that are actual ROMs, anything else can be ignored.
        guard parentDirectory.range(of: "com.provenance.",
                                    options: [.caseInsensitive, .anchored]) != nil,
              let fileName = file.lastPathComponent.removingPercentEncoding
        else {
            return
        }
        guard await getGameStatus(of: file) == .gameDoesNotExist
        else {
            DLOG("\(file) already exists in database. skipping...")
            return
        }
        ILOG("\(file) does NOT exist in database, adding to import set")
        switch file.system {
        case .Atari2600, .Atari5200, .Atari7800, .Genesis:
            await newFiles.insert(file)
        default:
            if let multiKey = file.multiFileNameKey {
                var files = await multiFileRoms[multiKey] ?? [URL]()
                files.append(file)
                await multiFileRoms.set(files, forKey: multiKey)
                //for sega cd ROMs, ignore the .brm file that is used for saves
            } else if file.system != .SegaCD || "brm".caseInsensitiveCompare(file.pathExtension) != .orderedSame {
                await newFiles.insert(file)
            }
        }
        await handleImportNewRomFiles()
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
        guard let system = file.system,
              let parentUrl = URL(string: parentDirectory)
        else {
            DLOG("error obtaining existence of \(file) in game cache.")
            return nil
        }
        let partialPath = parentUrl.appendingPathComponent(file.fileName)
        DLOG("system: \(system), partialPath: \(partialPath)")
        let similarName = RomDatabase.altName(file, systemIdentifier: system)
        let gamesCache = RomDatabase.gamesCache
        let partialPathAsString = partialPath.absoluteString
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
            ELOG("error deleting ROM \(file) from database: \(error)")
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
        let arePendingFilesToDownloadEmpty = await pendingFilesToDownload.isEmpty
        let areMultiFileRomsEmpty = await multiFileRoms.isEmpty
        //we only proceed if there are actual ROMs to import
        guard await !newFiles.isEmpty//OR there are multi file ROMs to import and there are no more pending files to download. this is to ensure that we have all of the files. an improvement would be to read the cue, ccd or m3u file to know how many files correspond
                || !areMultiFileRomsEmpty && arePendingFilesToDownloadEmpty
        else {
            return
        }
        await tryToImportNewRomFiles()
    }
    
    func tryToImportNewRomFiles() async {
        //if the importer is currently importing files, we have to wait
        let importState = gameImporter.processingState
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
           let nextMultiFile = await multiFileRoms.first {
            nextFilesToProcess = nextMultiFile.value
            await multiFileRoms.set(nil, forKey: nextMultiFile.key)
        }
        let importPaths = [URL](nextFilesToProcess)
        await gameImporter.addImports(forPaths: importPaths)
        let pendingProcessingCount = await downloadedCount
        let pendingFilesToDownloadCount = await pendingFilesToDownload.count
        ILOG("ROMs: downloading: \(pendingFilesToDownloadCount), pending to process: \(pendingProcessingCount), processing: \(importPaths.count)")
        if await newFiles.isEmpty {
            await uploadedFiles.removeAll()
        }
        gameImporter.startProcessing()
    }
}
