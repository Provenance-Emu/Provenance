//
//  iCloudSync.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 11/13/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVSupport
import RealmSwift
import RxRealm
import RxSwift
import PVPrimitives
import PVFileSystem
import PVRealm
import Combine

public enum SyncError: Error {
    case noUbiquityURL
}

public enum SyncResult {
    case denied
    case saveFailure
    case fileNotExist
    case success
    case indeterminate
}

public protocol Container {
    var containerURL: URL? { get }
}

extension Container {
    public var containerURL: URL? { get { return URL.iCloudContainerDirectory }}
    var documentsURL: URL? { get { return URL.iCloudDocumentsDirectory }}
}

public protocol iCloudTypeSyncer: Container {
    var directories: Set<String> { get }
    var metadataQuery: NSMetadataQuery { get }
    var downloadedCount: Int { get async }

    func loadAllFromICloud(iterationComplete: (() async -> Void)?) async -> Completable
    func insertDownloadingFile(_ file: URL) async -> URL?
    func insertDownloadedFile(_ file: URL) async
    func insertUploadedFile(_ file: URL) async
    func deleteFromDatastore(_ file: URL) async
    func setNewCloudFilesAvailable() async
}

enum iCloudSyncStatus {
    case initialUpload
    case filesAlreadyMoved
}

class iCloudContainerSyncer: iCloudTypeSyncer {
    lazy var pendingFilesToDownload: ConcurrentSet<URL> = []
    lazy var newFiles: ConcurrentSet<URL> = []
    lazy var uploadedFiles: ConcurrentSet<URL> = []
    let directories: Set<String>
    let fileManager: FileManager = .default
    let notificationCenter: NotificationCenter
    var status: ConcurrentSet<iCloudSyncStatus> = [.initialUpload]
    let errorHandler: ErrorHandler
    var initialSyncResult: SyncResult = .indeterminate
    var fileImportQueueMaxCount = 1000
    var purgeStatus: DatastorePurgeStatus = .incomplete
    private var querySubscriber: AnyCancellable?
    let removeDeletionsActor: RemoveDeletionsActor = .init()
    var downloadedCount: Int {
        get async {
            await newFiles.count
        }
    }
    
    init(directories: Set<String>,
         notificationCenter: NotificationCenter,
         errorHandler: ErrorHandler) {
        self.notificationCenter = notificationCenter
        self.directories = directories
        self.errorHandler = errorHandler
    }
    
    deinit {
        metadataQuery.disableUpdates()
        if metadataQuery.isStarted {
            metadataQuery.stop()
        }
        querySubscriber?.cancel()
    }
    
    var canPurgeDatastore: Bool {
        get async {
            let arePendingFilesToDownloadEmpty = await pendingFilesToDownload.isEmpty
            let areNewFilesEmpty = await downloadedCount == 0
            let isNumberOfErrorEmpty = await errorHandler.isEmpty
            return purgeStatus == .incomplete
                && initialSyncResult == .success
                && initialSyncResult == .success
                //if we have errors, it's better to just assume something happened while importing, so instead of creating a bigger mess, just NOT delete any files
                && isNumberOfErrorEmpty
                //we have to ensure that everything has been downloaded/imported before attempting to remove anything
                && arePendingFilesToDownloadEmpty
                && areNewFilesEmpty
        }
    }
    
    var localAndCloudDirectories: [URL: URL] {
        var alliCloudDirectories = [URL: URL]()
        guard let parentContainer = documentsURL
        else {
            return alliCloudDirectories
        }
        directories.forEach { directory in
            alliCloudDirectories[URL.documentsDirectory.appendingPathComponent(directory)] = parentContainer.appendingPathComponent(directory)
        }
        return alliCloudDirectories
    }
    
    let metadataQuery: NSMetadataQuery = .init()
    
    func insertDownloadingFile(_ file: URL) async -> URL? {
        guard await !uploadedFiles.contains(file)
        else {
            return nil
        }
        await pendingFilesToDownload.insert(file)
        return file
    }
    
    func insertDownloadedFile(_ file: URL) async {
        await pendingFilesToDownload.remove(file)
    }
    
    func insertUploadedFile(_ file: URL) async {
        await uploadedFiles.insert(file)
    }
    
    func setNewCloudFilesAvailable() async {
        if await pendingFilesToDownload.isEmpty {
            status = [.filesAlreadyMoved]
            await uploadedFiles.removeAll()
        }
        let uploadedCount = await uploadedFiles.count
        let statusDescription = await status.description
        DLOG("\(directories): status: \(statusDescription), uploadedFiles: \(uploadedCount)")
    }
    
    func deleteFromDatastore(_ file: URL) async {
        //no-op
    }
    
    func prepareNextBatchToProcess() async -> any Collection<URL> {
        var newFilesCount = await newFiles.count
        DLOG("\(directories): newFiles: (\(newFilesCount)):")
        var newFilesDescription = await newFiles.description
        DLOG("\(directories): \(newFilesDescription)")
        let nextFilesToProcess = await newFiles.prefix(fileImportQueueMaxCount)
        await newFiles.subtract(nextFilesToProcess)
        newFilesCount = await newFiles.count
        DLOG("\(directories): newFiles minus processing files: (\(newFilesCount)):")
        newFilesDescription = await newFiles.description
        DLOG("\(directories): \(newFilesDescription)")
        if await downloadedCount == 0 {
            await uploadedFiles.removeAll()
        }
        return nextFilesToProcess
    }
    
    func loadAllFromICloud(iterationComplete: (() async -> Void)? = nil) async -> Completable {
        initialSyncResult = await syncToiCloud()
        return Completable.create { [weak self] completable in
            self?.setupObservers(completable: completable, iterationComplete: iterationComplete)
            return Disposables.create()
        }
    }
    
    func setupObservers(completable: PrimitiveSequenceType.CompletableObserver, iterationComplete: (() async -> Void)? = nil) {
        DLOG("\(directories) syncToiCloud result: \(initialSyncResult)")
        guard initialSyncResult != .saveFailure,
              initialSyncResult != .denied
        else {
            ELOG("error moving files to iCloud container")
            return
        }
        DLOG("directories: \(directories)")
        var predicateFormat = ""
        var predicateArgs = [CVarArg]()
        directories.forEach { directory in
            if !predicateFormat.isEmpty {
                predicateFormat += " OR "
            }
            predicateFormat += "%K CONTAINS[c] %@"
            predicateArgs.append(NSMetadataItemPathKey)
            predicateArgs.append("/Documents/\(directory)/")
        }
        
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = NSPredicate(format: predicateFormat, argumentArray: predicateArgs)
        let names: [NSNotification.Name] = [.NSMetadataQueryDidFinishGathering, /*listen for deletions and new files.*/.NSMetadataQueryDidUpdate]
        let publishers = names.map { notificationCenter.publisher(for: $0, object: metadataQuery) }
        querySubscriber = Publishers.MergeMany(publishers)
            .sink { [weak self] notification in
            Task {
                await self?.queryFinished(notification: notification)
                await iterationComplete?()
            }
        }
        Task { @MainActor [weak self] in
            self?.metadataQuery.start()
        }
    }
    
    func queryFinished(notification: Notification) async {
        DLOG("directories: \(directories)")
        guard (notification.object as? NSMetadataQuery) === metadataQuery
        else {
            return
        }
        DLOG("\(notification.name): \(directories) -> number of items: \(metadataQuery.results.count)")
        for item in metadataQuery.results {
            if let fileItem = item as? NSMetadataItem,
               let file = fileItem.value(forAttribute: NSMetadataItemURLKey) as? URL,
               let isDirectory = try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               !isDirectory,//we only
               let downloadStatus = fileItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                let lastModified = fileItem.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
                let isDownloading = fileItem.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool ?? false
                let downloadingError = fileItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey)
                let percentDownloaded = fileItem.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double ?? 0
                let isUploaded = fileItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool
                let isUploading = fileItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool
                let doesFileExist = fileManager.fileExists(atPath: file.pathDecoded)
                DLOG("""
                \(notification.name)
                Found: \(file)
                - Download status: \(downloadStatus)
                - Last modified: \(String(describing: lastModified))
                - Is downloading: \(isDownloading)
                - Download error: \(downloadingError ?? "None")
                - Percent downloaded: \(percentDownloaded)
                - Is uploaded: \(isUploaded ?? false)
                - Is uploading: \(isUploading ?? false)
                - does file exist: \(doesFileExist)
                """)
                switch downloadStatus {
                    case  NSMetadataUbiquitousItemDownloadingStatusNotDownloaded:
                        await handleFileToDownload(file, isDownloading: isDownloading, percentDownload: percentDownloaded)
                    case NSMetadataUbiquitousItemDownloadingStatusCurrent:
                        await handleDownloadedFile(file)
                    default: ILOG("Other: \(file): download status: \(downloadStatus)")
                }
            }
        }
        let removedObjects = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey]
        if let actualRemovedObjects = removedObjects as? [NSMetadataItem] {
            DLOG("\(directories): actualRemovedObjects: (\(actualRemovedObjects.count)) \(actualRemovedObjects)")
            for item in actualRemovedObjects {
                if let file = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                    DLOG("file DELETED from iCloud: \(file)")
                    await deleteFromDatastore(file)
                }
            }
        }
        await setNewCloudFilesAvailable()
        let pendingFilesToDownloadCount = await pendingFilesToDownload.count
        let totalDownloadedCount = await downloadedCount
        ILOG("\(notification.name): \(directories): current iteration: files pending to be downloaded: \(pendingFilesToDownloadCount), files downloaded pending to process: \(totalDownloadedCount)")
    }
    
    func handleFileToDownload(_ file: URL, isDownloading: Bool, percentDownload: Double) async {
        do {//only start download if we haven't already started
            if let fileToDownload = await insertDownloadingFile(file),
               !isDownloading || percentDownload < 100 {
                try fileManager.startDownloadingUbiquitousItem(at: fileToDownload)
                ILOG("Download started for: \(file.pathDecoded)")
            }
        } catch {
            await errorHandler.handleError(error, file: file)
            ELOG("Failed to start download on file \(file.pathDecoded): \(error)")
        }
    }
    
    func handleDownloadedFile(_ file: URL) async {
        DLOG("item up to date: \(file)")
        if !fileManager.fileExists(atPath: file.pathDecoded) {
            DLOG("file DELETED from iCloud: \(file)")
            await deleteFromDatastore(file)
            return
        }
        //in the case when we are initially turning on iCloud or the app is opened and coming into the foreground for the first time, we try to import any files already downloaded. this is to ensure that a downloaded file gets imported and we do this just when the icloud switch is turned on and subsequent updates only happen after they are downloaded
        if await status.contains(.initialUpload) {
            await insertDownloadingFile(file)
        }
        await insertDownloadedFile(file)
    }
    
    func syncToiCloud() async -> SyncResult {
        let allDirectories = localAndCloudDirectories
        guard allDirectories.count > 0
        else {
            return .denied
        }
        var moveResult: SyncResult? = nil
        for (localDirectory, iCloudDirectory) in allDirectories {
            let moved = await moveFiles(at: localDirectory,
                                        containerDestination: iCloudDirectory,
                                        existingClosure: { existing in
                do {
                    try fileManager.removeItem(atPath: existing.pathDecoded)
                } catch {
                    await errorHandler.handleError(error, file: existing)
                    ELOG("error deleting existing file \(existing) that already exists in iCloud: \(error)")
                }
            }) { currentSource, currentDestination in
                try fileManager.setUbiquitous(true, itemAt: currentSource, destinationURL: currentDestination)
            }
            if moved == .saveFailure {
                moveResult = .saveFailure
            }
        }
        return moveResult ?? .success
    }
    
    @discardableResult
    func removeFromiCloud() async -> SyncResult {
        var result: SyncResult = .indeterminate
        defer {
            DLOG("removed: \(result)")
        }
        let allDirectories = localAndCloudDirectories
        guard allDirectories.count > 0
        else {
            result = .denied
            return result
        }
        var moveResult: SyncResult?
        for (localDirectory, iCloudDirectory) in allDirectories {
            let moved = await moveFiles(at: iCloudDirectory,
                                        containerDestination: localDirectory,
                                        existingClosure: { existing in
                do {
                    try fileManager.evictUbiquitousItem(at: existing)
                } catch {//this happens when a file is being presented on the UI (saved states image) and thus we can't remove the icloud download
                    await errorHandler.handleError(error, file: existing)
                    ELOG("error evicting iCloud file: \(existing), \(error)")
                }
            }) { currentSource, currentDestination in
                try fileManager.copyItem(at: currentSource, to: currentDestination)
                do {
                    try fileManager.evictUbiquitousItem(at: currentSource)
                } catch {//this happens when a file is being presented on the UI (saved states image) and thus we can't remove the icloud download
                    await errorHandler.handleError(error, file: currentSource)
                    ELOG("error evicting iCloud file: \(currentSource), \(error)")
                }
            }
            if moved == .saveFailure {
                moveResult = .saveFailure
            }
        }
        result = moveResult ?? .success
        return result
    }
    
    func moveFiles(at source: URL,
                   containerDestination: URL,
                   existingClosure: ((URL) async -> Void),
                   moveClosure: (URL, URL) async throws -> Void) async -> SyncResult {
        DLOG("source: \(source)")
        guard fileManager.fileExists(atPath: source.pathDecoded)
        else {
            return .fileNotExist
        }
        let subdirectories: [String]
        do {
            subdirectories = try fileManager.subpathsOfDirectory(atPath: source.pathDecoded)
        } catch {
            await errorHandler.handleError(error, file: source)
            ELOG("failed to get directory contents \(source): \(error)")
            return .saveFailure
        }
        DLOG("subdirectories of \(source): \(subdirectories)")
        for currentChild in subdirectories {
            let currentItem = source.appendingPathComponent(currentChild)
            
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: currentItem.pathDecoded, isDirectory: &isDirectory)
            DLOG("\(currentItem) isDirectory?\(isDirectory) exists?\(exists)")
            let destination = containerDestination.appendingPathComponent(currentChild)
            DLOG("new destination: \(destination)")
            if isDirectory.boolValue && !fileManager.fileExists(atPath: destination.pathDecoded) {
                DLOG("\(destination) does NOT exist")
                do {
                    try fileManager.createDirectory(atPath: destination.pathDecoded, withIntermediateDirectories: true)
                } catch {
                    await errorHandler.handleError(error, file: destination)
                    ELOG("error creating directory: \(destination), \(error)")
                }
            }
            if isDirectory.boolValue {
                continue
            }
            if fileManager.fileExists(atPath: destination.pathDecoded) {
                await existingClosure(currentItem)
                continue
            }
            do {
                ILOG("Trying to move \(currentItem.pathDecoded) to \(destination.pathDecoded)")
                await try moveClosure(currentItem, destination)
                await insertUploadedFile(destination)
            } catch {
                await errorHandler.handleError(error, file: currentItem)
                //this could indicate no more space is left when moving to iCloud
                ELOG("failed to move \(currentItem.pathDecoded) to \(destination.pathDecoded): \(error)")
            }
        }
        return .success
    }
}

extension Realm {
    func deleteGame(_ game: PVGame) async throws {
        try asyncWrite {
            game.saveStates.forEach { try? $0.delete() }
            game.cheats.forEach { try? $0.delete() }
            game.recentPlays.forEach { try? $0.delete() }
            game.screenShots.forEach { try? $0.delete() }
            delete(game)
        }
    }
}

enum iCloudError: Error {
    case dataReadFail
}

public enum iCloudSync {
    case initialAppLoad
    case appLoaded
    
    static var disposeBag: DisposeBag!
    static var gameImporter = GameImporter.shared
    static var state: iCloudSync = .initialAppLoad
    static let errorHandler: ErrorHandler = iCloudErrorHandler.shared
    static var romDatabaseInitialized: AnyCancellable?
    
    public static func initICloudDocuments() {
        Task {
            for await value in Defaults.updates(.iCloudSync) {
                await iCloudSyncChanged(value)
            }
        }
    }
    
    static func iCloudSyncChanged(_ newValue: Bool) async {
        DLOG("new iCloudSync value: \(newValue)")
        guard newValue
        else {
            await turnOff()
            return
        }
        await turnOn()
    }
    
    /// in order to account for large libraries, we go through each directory/file and tell the iCloud API to start downloading. this way it starts and by the time we query, we can get actual events that the downloads complete.
    static func initiateRomsSavesDownload() async {
        guard let documentsDirectory = URL.iCloudDocumentsDirectory
        else {
            ELOG("error obtaining iCloud documents directory")
            return
        }
        let romsDirectory = documentsDirectory.appendingPathComponent("ROMs")
        let savesDirectory = documentsDirectory.appendingPathComponent("Save States")
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await startDownloading(directory: romsDirectory, parentDirectoryPrefix: "com.provenance.")
            }
            group.addTask {
                await startDownloading(directory: savesDirectory)
            }
            await group.waitForAll()
        }
    }
    
    static func startDownloading(directory: URL, parentDirectoryPrefix: String? = nil) async {
        ILOG("attempting to start downloading iCloud directory: \(directory)")
        let fileManager: FileManager = .default
        let children: [String]
        do {
            children = try fileManager.subpathsOfDirectory(atPath: directory.pathDecoded)
            DLOG("found \(children.count) in \(directory)")
        } catch {
            DLOG("error grabbing sub directories of \(directory)")
            await errorHandler.handleError(error, file: directory)
            return
        }
        var childrenUrls: Set<URL> = []
        for child in children {
            let currentUrl = directory.appendingPathComponent(child)
            do {
                var isDirectory: ObjCBool = false
                _ = try fileManager.fileExists(atPath: currentUrl.pathDecoded, isDirectory: &isDirectory)
                guard !isDirectory.boolValue,
                      checkDownloadStatus(of: currentUrl) != .current
                else {
                    return
                }
                 let parentDirectory = currentUrl.parentPathComponent
                 //we should only add to the import queue files that are actual ROMs, anything else can be ignored.
                guard parentDirectoryPrefix == nil
                        || parentDirectory.range(of: parentDirectoryPrefix!,
                                             options: [.caseInsensitive, .anchored]) != nil
                else {
                    return
                }
                DLOG("processing \(currentUrl)")
                do {
                    try fileManager.startDownloadingUbiquitousItem(at: currentUrl)
                } catch {
                    DLOG("error initiating download of \(currentUrl)")
                    await errorHandler.handleError(error, file: currentUrl)
                }
                childrenUrls.insert(currentUrl)
                if childrenUrls.count % 10 == 0 {
                    Thread.sleep(forTimeInterval: 0.5)
                }
            } catch {
                DLOG("error checking if \(currentUrl) is a directory")
            }
        }
    }
    
    static func checkDownloadStatus(of url: URL) -> URLUbiquitousItemDownloadingStatus? {
        do {
            return try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey,
                                                    .ubiquitousItemIsDownloadingKey]).ubiquitousItemDownloadingStatus
        } catch {
            DLOG("Error checking iCloud file status for: \(url), error: \(error)")
            return nil
        }
    }
    
    static func turnOn() async {
        guard URL.supportsICloud else {
            DLOG("attempted to turn on iCloud, but iCloud is NOT setup on the device")
            return
        }
        DLOG("turning on iCloud")
        //reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
        await errorHandler.clear()
        let fm = FileManager.default
        if let currentiCloudToken = fm.ubiquityIdentityToken {
            do {
                let newTokenData = try NSKeyedArchiver.archivedData(withRootObject: currentiCloudToken, requiringSecureCoding: false)
                UserDefaults.standard.set(newTokenData, forKey: UbiquityIdentityTokenKey)
            } catch {
                await errorHandler.handleError(error, file: nil)
                ELOG("error serializing iCloud token: \(error)")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: UbiquityIdentityTokenKey)
        }
        disposeBag = DisposeBag()
        var nonDatabaseFileSyncer: iCloudContainerSyncer! = .init(directories: ["BIOS", "Battery States", "Screenshots"],
                                                                  notificationCenter: .default,
                                                                  errorHandler: iCloudErrorHandler.shared)
        await nonDatabaseFileSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing nonDatabaseFileSyncer")
                Task {
                    await nonDatabaseFileSyncer.removeFromiCloud()
                    nonDatabaseFileSyncer = nil
                }
            }.disposed(by: disposeBag)
        await initiateRomsSavesDownload()
        //wait for the ROMs database to initialize
        romDatabaseInitialized = NotificationCenter.default.publisher(for: .RomDatabaseInitialized).sink { _ in
            romDatabaseInitialized?.cancel()
                Task {
                    await startSavesRomsSyncing()
                }
            }
    }
    
    static func startSavesRomsSyncing() async {
        var saveStateSyncer: SaveStateSyncer! = .init(notificationCenter: .default, errorHandler: iCloudErrorHandler.shared)
        var romsSyncer: RomsSyncer! = .init(notificationCenter: .default, errorHandler: iCloudErrorHandler.shared)
        //ensure user hasn't turned off icloud
        guard disposeBag != nil
        else {//in the case that the user did turn it off, then we can go ahead and just do the normal flow of turning off icloud
            await saveStateSyncer.removeFromiCloud()
            saveStateSyncer = nil
            await romsSyncer.removeFromiCloud()
            romsSyncer = nil
            return
        }
        await saveStateSyncer.loadAllFromICloud() {
                await saveStateSyncer.importNewSaves()
            }.observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing saveStateSyncer")
                Task {
                    await saveStateSyncer.removeFromiCloud()
                    saveStateSyncer = nil
                }
            }.disposed(by: disposeBag)
        await romsSyncer.loadAllFromICloud() {
                await romsSyncer.handleImportNewRomFiles()
            }.observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing romsSyncer")
                Task {
                    await romsSyncer.removeFromiCloud()
                    romsSyncer = nil
                }
            }.disposed(by: disposeBag)
    }
    
    static func turnOff() async {
        DLOG("turning off iCloud")
        romDatabaseInitialized?.cancel()
        await errorHandler.clear()
        disposeBag = nil
        //reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
    }
}

/// used for removing ROMs/Saves that were removed by the user when the application is closed. This is to ensure if this is called several times, only 1 block is used at a time
actor RemoveDeletionsActor {
    /// executes closure
    /// - Parameter criticalSection: critical section code to execute
    func performWithLock(_ criticalSection: @Sendable @escaping () async -> Void) async {
        await criticalSection()
    }
}


/// Actor isolated for accessing db in background thread safely
@globalActor
actor RealmActor: GlobalActor {
    static let shared = RealmActor()
}

/// Datastore for accessing saves and anything related to saves.
actor RomsDatastore {
    private let realm: Realm
    private let fileManager: FileManager
    
    init() async throws {
        realm = await try Realm(actor: RealmActor.shared)
        fileManager = .default
    }
    
    /// queries datastore for save using id
    /// - Parameter id: primary key of save
    /// - Returns: save or nil if one exists
    @RealmActor
    func findSaveState(forPrimaryKey id: String) -> PVSaveState? {
        realm.object(ofType: PVSaveState.self, forPrimaryKey: id)
    }
    
    /// queries datastore for game that corresponds to save
    /// - Parameter save: save to use to query for game
    /// - Returns: game or nil if one exists
    @RealmActor
    func findGame(md5: String, forSave save: PVSaveState) -> PVGame? {
        // See if game is missing and set
        guard save.game?.system == nil
        else {
            return nil
        }
        return realm.object(ofType: PVGame.self, forPrimaryKey: md5)
    }
    
    /// stores game assoicated with save
    /// - Parameters:
    ///   - save: save to associate game with
    ///   - game: game to store
    @RealmActor
    func update(existingSave save: PVSaveState, with game: PVGame) async throws {
        await try realm.asyncWrite {
            save.game = game
        }
    }
    
    /// inserts a new save into datastore
    /// - Parameter save: save to create
    @RealmActor
    func create(newSave save: SaveState) async throws {
        let newSave = realm.buildSaveState(from: save)
        await try realm.asyncWrite {
            realm.add(newSave, update: .all)
        }
        DLOG("Added new save \(newSave.debugDescription)")
    }
    
    /// deletes all saves that do NOT exist in the file system, but exist in the database. this will happen when the user deletes on a different device, or outside of the app and the app is opened. the app won't get a notification in this case, we have to manually do this check
    @RealmActor
    func deleteSaveStatesRemoveWhileApplicationClosed() throws {
        try realm.asyncWrite {
            realm.objects(PVSaveState.self).forEach { save in
                guard let file = save.file,
                      let url = file.url
                else {
                    return
                }
                let saveUrl = url.appendingPathExtension("json").pathDecoded
                if !fileManager.fileExists(atPath: saveUrl) {
                    ILOG("save: \(saveUrl) does NOT exist, removing from datastore")
                    realm.delete(save)
                }
            }
        }
    }
    
    /// tries to delete save state from the database
    /// - Parameter file: file is used to query for the save state in the database attempt to delete
    @RealmActor
    func deleteSaveState(file: URL) throws {
        DLOG("attempting to query PVSaveState by file: \(file)")
        let gameDirectory = file.parentPathComponent
        let savesDirectory = file.deletingLastPathComponent().parentPathComponent
        let partialPath = "\(savesDirectory)/\(gameDirectory)/\(file.lastPathComponent)"
        let imageField = NSExpression(forKeyPath: \PVSaveState.image.self).keyPath
        let partialPathField = NSExpression(forKeyPath: \PVImageFile.partialPath.self).keyPath
        let results = realm.objects(PVSaveState.self).filter(NSPredicate(format: "\(imageField).\(partialPathField) CONTAINS[c] %@", partialPath))
        DLOG("saves found: \(results.count)")
        guard let save: PVSaveState = results.first
        else {
            return
        }
        ILOG("""
        removing save: \(partialPath)
        full file: \(file)
        """)
        try realm.asyncWrite {
            realm.delete(save)
        }
    }
    
    /// deletes all games that do NOT exist in the file system, but exist in the database. this will happen when the user deletes on a different device, or outside of the app and the app is opened. the app won't get a notification in this case, we have to manually do this check
    /// - Parameter romsPath: rull ROMs path
    @RealmActor
    func deleteGamesDeletedWhileApplicationClosed(romsPath: String) {
        var shouldUpdateCache = false
        RomDatabase.gamesCache.forEach { (_, game: PVGame) in
            let gameUrl = romsPath.appendingPathComponent(game.romPath)
            DLOG("""
            rom partial path: \(game.romPath)
            full game URL: \(gameUrl)
            """)
            guard !fileManager.fileExists(atPath: gameUrl.pathDecoded)
            else {
                return
            }
            do {
                if let gameToDelete = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash) {
                    ILOG("\(gameUrl) does NOT exists, removing from datastore")
                    try realm.deleteGame(gameToDelete)
                    shouldUpdateCache = true
                }
            } catch {
                ELOG("error deleting \(gameUrl), \(error)")
            }
        }
        if shouldUpdateCache {
            RomDatabase.reloadGamesCache()
        }
    }
    
    /// tries to delete game from database
    /// - Parameter md5Hash: hash used to query for the game in the database
    @RealmActor
    func deleteGame(md5Hash: String) throws {
        guard let game: PVGame = realm.object(ofType: PVGame.self, forPrimaryKey: existingGame.md5Hash)
        else {
            return
        }
        ILOG("deleting \(game.file.url) from datastore")
        try realm.deleteGame(game)
    }
}

//MARK: - iCloud syncers

class SaveStateSyncer: iCloudContainerSyncer {
    let jsonDecorder = JSONDecoder()
    let processed = ConcurrentQueue<Int>(arrayLiteral: 0)
    let processingState: ConcurrentQueue<ProcessingState> = .init(arrayLiteral: .idle)
    var savesDatabaseSubscriber: AnyCancellable?
    
    convenience init(notificationCenter: NotificationCenter, errorHandler: ErrorHandler) {
        self.init(directories: ["Save States"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        fileImportQueueMaxCount = 1
        jsonDecorder.dataDecodingStrategy = .deferredToData
        
        let publishers = [.SavesFinishedImporting, .RomDatabaseInitialized].map { notificationCenter.publisher(for: $0) }
        savesDatabaseSubscriber = Publishers.MergeMany(publishers).sink { [weak self] _ in
            Task {
                await self?.importNewSaves()
            }
        }
    }
    
    deinit {
        savesDatabaseSubscriber?.cancel()
    }
    
    func removeSavesDeletedWhileApplicationClosed() async {
        await removeDeletionsActor.performWithLock { [weak self] in
            guard let canPurge = await self?.canPurgeDatastore,
                  canPurge
            else {
                return
            }
            defer {
                purgeStatus = .complete
            }
            do {
                let romsDatastore: RomsDatastore = await try .init()
                await try romsDatastore.deleteSaveStatesRemoveWhileApplicationClosed()
            } catch {
                ELOG("error clearing saves deleted while application was closed")
            }
        }
    }
    
    override func insertDownloadedFile(_ file: URL) async {
        guard let _ = await pendingFilesToDownload.remove(file),
              "json".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        ILOG("downloaded save file: \(file)")
        await newFiles.insert(file)
        await importNewSaves()
    }
    
    override func deleteFromDatastore(_ file: URL) async {
        guard "jpg".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        do {
            let romsDatastore: RomsDatastore = await try .init()
            await romsDatastore.deleteSaveState(file: file)
        } catch {
            await errorHandler.handleError(error, file: file)
            ELOG("error deleting \(file) from database: \(error)")
        }
    }
    
    func getSaveFrom(_ json: URL) throws -> SaveState? {
        guard fileManager.fileExists(atPath: json.pathDecoded)
        else {
            return nil
        }
        let secureDoc = json.startAccessingSecurityScopedResource()

        defer {
            if secureDoc {
                json.stopAccessingSecurityScopedResource()
            }
        }
        
        var dataMaybe = fileManager.contents(atPath: json.pathDecoded)
        if dataMaybe == nil {
            dataMaybe = try Data(contentsOf: json, options: [.uncached])
        }
        guard let data = dataMaybe else {
            throw iCloudError.dataReadFail
        }

        DLOG("Data read \(String(data: data, encoding: .utf8) ?? "Nil")")
        let save = try jsonDecorder.decode(SaveState.self, from: data)
        DLOG("Read JSON data at (\(json.pathDecoded)")
        return save
    }
    
    func importNewSaves() async {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        await removeSavesDeletedWhileApplicationClosed()
        guard await !newFiles.isEmpty,
              await processingState.peek() == .idle
        else {
            return
        }
        let jsonFiles = await prepareNextBatchToProcess()
        guard !jsonFiles.isEmpty
        else {
            return
        }
        //process save files batch
        await processJsonFiles(jsonFiles)
    }
    
    func processJsonFiles(_ jsonFiles: any Collection<URL>) async {
        //setup processed count
        await processingState.dequeue()
        await processingState.enqueue(entry: .processing)
        var processedCount = await processed.dequeue() ?? 0
        let pendingFilesToDownloadCount = await pendingFilesToDownload.count
        ILOG("Saves: downloading: \(pendingFilesToDownloadCount), processing: \(jsonFiles.count), total processed: \(processedCount)")
        for json in jsonFiles {
            do {
                processedCount += 1
                guard let save: SaveState = try getSaveFrom(json)
                else {
                    continue
                }
                let romsDatastore = await try romsDatastore()
                guard let existing: PVSaveState = await romsDatastore.findSaveState(forPrimaryKey: save.id)
                else {
                    ILOG("Saves: processing: save #(\(processedCount)) \(json)")
                    await storeNewSave(save, romsDatastore, json)
                    continue
                }
                await updateExistingSave(existing, romsDatastore, save, json)
                
            } catch {
                await errorHandler.handleError(error, file: json)
                ELOG("Decode error on \(json): \(error)")
            }
        }
        //update processed count
        await processed.enqueue(entry: processedCount)
        await processingState.dequeue()
        await processingState.enqueue(entry: .idle)
        await removeSavesDeletedWhileApplicationClosed()
        notificationCenter.post(Notification(name: .SavesFinishedImporting))
    }
    
    func updateExistingSave(_ existing: PVSaveState, _ romsDatastore: RomsDatastore, _ save: SaveState, _ json: URL) async {
        guard let game = await romsDatastore.findGame(md5: save.game.md5, forSave: existing)
        else {
            return
        }
        ILOG("Saves: updating \(json)")
        do {
            await try romsDatastore.update(existingSave: existing, with: game)
        } catch {
            await errorHandler.handleError(error, file: json)
            ELOG("Failed to update game \(json): \(error)")
        }
    }
    
    func storeNewSave(_ save: SaveState, _ romsDatastore: RomsDatastore, _ json: URL) async {
        do {
            await try romsDatastore.create(newSave: save)
        } catch {
            await errorHandler.handleError(error, file: json)
            ELOG("error adding new save \(json): \(error)")
        }
        ILOG("Added new save \(json)")
    }
}

/// used for only purging database entries that no longer exist (files deleted from icloud while the app was shut off)
enum DatastorePurgeStatus {
    case incomplete
    case complete
}

enum GameStatus {
    case gameExists
    case gameDoesNotExist
}

class RomsSyncer: iCloudContainerSyncer {
    let gameImporter = GameImporter.shared
    let multiFileRoms: ConcurrentDictionary<String, [URL]> = [:]
    var romsDatabaseSubscriber: AnyCancellable?
    
    override var downloadedCount: Int {
        get async {
            let multiFileRomsCount = await multiFileRoms.count
            return await newFiles.count + multiFileRomsCount
        }
    }
    
    convenience init(notificationCenter: NotificationCenter, errorHandler: ErrorHandler) {
        self.init(directories: ["ROMs"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        fileImportQueueMaxCount = 1
        let publishers = [.RomsFinishedImporting, .RomDatabaseInitialized].map { notificationCenter.publisher(for: $0) }
        romsDatabaseSubscriber = Publishers.MergeMany(publishers).sink { [weak self] _ in
            Task {
                await self?.handleImportNewRomFiles()
            }
        }
    }
    
    deinit {
        romsDatabaseSubscriber?.cancel()
    }
    
    override func loadAllFromICloud(iterationComplete: (() async -> Void)?) async -> Completable {
         //ensure that the games are cached so we do NOT hit the database so much when checking for existence of games
         RomDatabase.reloadGamesCache()
         return await super.loadAllFromICloud(iterationComplete: iterationComplete)
     }
    
    /// The only time that we don't know if files have been deleted by the user is when it happens while the app is closed. so we have to query the db and check
    func removeGamesDeletedWhileApplicationClosed() async {
        await removeDeletionsActor.performWithLock { [weak self] in
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
            let romsDatastore = try RomsDatastore()
            await romsDatastore.deleteGamesDeletedWhileApplicationClosed(romsPath: romsPath)
        } catch {
            ELOG("error removing game entries that do NOT exist in the cloud container \(romsPath)")
        }
    }
    
    override func insertDownloadedFile(_ file: URL) async {
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
                } else {
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
    
    override func deleteFromDatastore(_ file: URL) async {
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
            let romsDatastore = await try RomsDatastore()
            await try romsDatastore.deleteGame(md5Hash: existingGame.md5Hash)
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
        gameImporter.clearCompleted()
        await removeGamesDeletedWhileApplicationClosed()
        guard await !newFiles.isEmpty
        else {
            return
        }
        let arePendingFilesToDownloadEmpty = await pendingFilesToDownload.isEmpty
        guard await !multiFileRoms.isEmpty && arePendingFilesToDownloadEmpty
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
        gameImporter.addImports(forPaths: importPaths)
        let pendingProcessingCount = await downloadedCount
        let pendingFilesToDownloadCount = await pendingFilesToDownload.count
        ILOG("ROMs: downloading: \(pendingFilesToDownloadCount), pending to process: \(pendingProcessingCount), processing: \(importPaths.count)")
        if await newFiles.isEmpty {
            await uploadedFiles.removeAll()
        }
        gameImporter.startProcessing()
    }
}

struct iCloudSyncError {
    let file: String?
    var summary: String {
        error.localizedDescription
    }
    let error: Error
}

protocol Queue {
    associatedtype Entry
    var count: Int { get async }
    func enqueue(entry: Entry) async
    func dequeue() async -> Entry?
    func peek()  async-> Entry?
    func clear() async
    var allElements: [Entry] { get async }
    var isEmpty: Bool { get async }
}

actor ConcurrentQueue<Element>: Queue, ExpressibleByArrayLiteral {
    private var collection = [Element]()
    
    init(arrayLiteral elements: Element...) {
        collection = Array(elements)
    }
    
    @inlinable
    var count: Int {
        collection.count
    }
    
    @inlinable
    func enqueue(entry: Element) {
        collection.insert(entry, at: 0)
    }
    
    @inlinable
    @discardableResult
    func dequeue() -> Element? {
        guard !collection.isEmpty
        else {
            return nil
        }
        return collection.removeFirst()
    }
    
    @inlinable
    func peek() -> Element? {
        collection.first
    }
    
    @inlinable
    func clear() {
        collection.removeAll()
    }
    
    @inlinable
    public var description: String {
        collection.description
    }
    
    @inlinable
    func map<T>(_ transform: (Element) throws -> T) throws -> [T] {
        try collection.map(transform)
    }
    
    @inlinable
    var allElements: [Element] {
        collection
    }
    
    @inlinable
    var isEmpty: Bool {
        collection.isEmpty
    }
}

protocol ErrorHandler {
    var allErrorSummaries: [String] { get async throws }
    var allFullErrors: [String] { get async throws }
    var allErrors: [iCloudSyncError] { get async }
    var isEmpty: Bool { get async }
    var numberOfErrors: Int { get async }
    func handleError(_ error: Error, file: URL?) async
    func clear() async
}

actor iCloudErrorHandler: ErrorHandler {
    static let shared = iCloudErrorHandler()
    private let queue = ConcurrentQueue<iCloudSyncError>()
    
    @inlinable
    var allErrorSummaries: [String] {
        get async throws {
            await try queue.map { $0.summary }
        }
    }
    
    @inlinable
    var allFullErrors: [String] {
        get async throws {
            await try queue.map { "\($0.error)" }
        }
    }
    
    @inlinable
    var allErrors: [iCloudSyncError] {
        get async {
            await queue.allElements
        }
    }
    
    @inlinable
    var isEmpty: Bool {
        get async {
            await queue.isEmpty
        }
    }
    
    @inlinable
    var numberOfErrors: Int {
        get async {
            await queue.count
        }
    }
    
    func handleError(_ error: any Error, file: URL?) async {
        let syncError = iCloudSyncError(file: file?.path(percentEncoded: false), error: error)
        await queue.enqueue(entry: syncError)
    }
    
    @inlinable
    func clear() async {
        await queue.clear()
    }
}

extension URL {
    var system : SystemIdentifier? {
        return SystemIdentifier(rawValue: parentPathComponent)
    }
    var parentPathComponent: String {
        deletingLastPathComponent().lastPathComponent
    }
    
    var fileName: String {
        lastPathComponent.removingPercentEncoding ?? lastPathComponent
    }
    
    var multiFileNameKey: String? {
        guard "cue".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "bin".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "ccd".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "img".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "sub".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "m3u".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "mds".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "mdf".caseInsensitiveCompare(pathExtension) == .orderedSame
        else {
            return nil
        }
        let key = PVEmulatorConfiguration.stripDiscNames(fromFilename: deletingPathExtension().pathDecoded)
        DLOG("key: \(key)")
        return key
    }
}

actor ConcurrentDictionary<Key: Hashable, Value>: ExpressibleByDictionaryLiteral,
                                                  @preconcurrency
                                                  CustomStringConvertible {
    private var dictionary: [Key: Value] = [:]
    
    init(dictionaryLiteral elements: (Key, Value)...) {
        dictionary = Dictionary(uniqueKeysWithValues: elements)
    }
    
    @inlinable
    subscript(key: Key) -> Value? {
        get {
            dictionary[key]
        }
        set {
            dictionary[key] = newValue
        }
    }
    
    @inlinable
    func set(_ value: Value?, forKey key: Key) {
        dictionary[key] = value
    }
    
    @inlinable
    var first: (key: Key, value: Value)? {
        dictionary.first
    }
    
    @inlinable
    var isEmpty: Bool {
        dictionary.isEmpty
    }
    
    @inlinable
    var count: Int {
        dictionary.count
    }
    
    var description: String {
        dictionary.description
    }
}

enum ConcurrentCopyOptions {
    case removeCopiedItems
    case retainCopiedItems
}

public actor ConcurrentSet<T: Hashable>: ExpressibleByArrayLiteral,
                                         @preconcurrency
                                         CustomStringConvertible {
    private var set: Set<T>
    
    public init(arrayLiteral elements: T...) {
        set = Set(elements)
    }
    
    convenience init(fromSet set: Set<T>) async {
        self.init()
        await self.set.formUnion(set)
    }
    
    func insert(_ element: T) {
        set.insert(element)
    }
    
    func remove(_ element: T) -> T? {
        set.remove(element)
    }
    
    func contains(_ element: T) -> Bool {
        set.contains(element)
    }
    
    func removeAll() {
        set.removeAll()
    }
    
    func forEach(_ body: (T) throws -> Void) rethrows {
        try set.forEach(body)
    }
    
    func prefix(_ maxLength: Int) -> Slice<Set<T>> {
        set.prefix(maxLength)
    }
    
    func subtract<S>(_ other: S) where T == S.Element, S : Sequence {
        set.subtract(other)
    }
    
    func copy(options: ConcurrentCopyOptions) -> Set<T> {
        var copiedSet: Set<T> = .init(set)
        if options == .removeCopiedItems {
            set.removeAll()
        }
        return copiedSet
    }
    
    func formUnion<S>(_ other: S) where T == S.Element, S : Sequence {
        set.formUnion(other)
    }
    
    var isEmpty: Bool {
        return set.isEmpty
    }
    
    var first: T? {
        return set.first
    }
    
    var count: Int {
        return set.count
    }
                                             
    func enumerated() -> EnumeratedSequence<Set<T>> {
        set.enumerated()
    }
                                             
    public func makeIterator() async -> Set<T>.Iterator {
        set.makeIterator()
    }
    
    public var description: String {
        return set.description
    }
}
