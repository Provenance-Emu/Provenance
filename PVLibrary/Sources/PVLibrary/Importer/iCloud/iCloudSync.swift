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

    func loadAllFromICloud(iterationComplete: (() -> Void)?) -> Completable
    func insertDownloadingFile(_ file: URL)
    func insertDownloadedFile(_ file: URL)
    func insertUploadedFile(_ file: URL)
    func deleteFromDatastore(_ file: URL)
    func setNewCloudFilesAvailable()
}

enum iCloudSyncStatus {
    case initialUpload
    case filesAlreadyMoved
}

class iCloudContainerSyncer: iCloudTypeSyncer {
    lazy var pendingFilesToDownload: Set<String> = []
    lazy var newFiles: Set<URL> = []
    lazy var uploadedFiles: Set<URL> = []
    let directories: Set<String>
    let fileManager = FileManager.default
    let notificationCenter: NotificationCenter
    var status: iCloudSyncStatus = .initialUpload
    let errorHandler: ErrorHandler
    var initialSyncResult: SyncResult = .indeterminate
    let queue = DispatchQueue(label: "com.provenance.newFiles")
    //process in batch numbers
    let fileImportQueueMaxCount = 100
    
    init(directories: Set<String>,
         notificationCenter: NotificationCenter,
         errorHandler: ErrorHandler) {
        self.notificationCenter = notificationCenter
        self.directories = directories
        self.errorHandler = errorHandler
    }
    
    deinit {
        metadataQuery.disableUpdates()
        metadataQuery.stop()
        notificationCenter.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
        notificationCenter.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: metadataQuery)
        let removed = removeFromiCloud()
        DLOG("removed: \(removed)")
        DLOG("dying")
    }
    
    var localAndCloudDirectories: [URL: URL] {
        var alliCloudDirectories = [URL: URL]()
        guard let actualContainrUrl = containerURL
        else {
            return alliCloudDirectories
        }
        let parentContainer = actualContainrUrl.appendDocumentsDirectory
        directories.forEach { directory in
            alliCloudDirectories[URL.documentsDirectory.appendingPathComponent(directory)] = parentContainer.appendingPathComponent(directory)
        }
        return alliCloudDirectories
    }
    
    let metadataQuery: NSMetadataQuery = .init()
    
    func insertDownloadingFile(_ file: URL) {
        guard !uploadedFiles.contains(file)
        else {
            return
        }
        pendingFilesToDownload.insert(file.absoluteString)
    }
    
    func insertDownloadedFile(_ file: URL) {
        pendingFilesToDownload.remove(file.absoluteString)
    }
    
    func insertUploadedFile(_ file: URL) {
        uploadedFiles.insert(file)
    }
    
    func setNewCloudFilesAvailable() {
        if pendingFilesToDownload.isEmpty {
            status = .filesAlreadyMoved
            DLOG("set status to \(status) and removing all uploaded files in \(directories)")
            uploadedFiles.removeAll()
        }
    }
    
    func deleteFromDatastore(_ file: URL) {
        //no-op
    }
    
    func prepareNextBatchToProcess() -> any Collection<URL> {
        DLOG("\(directories): newFiles: (\(newFiles.count)):")
        DLOG("\(directories): \(newFiles)")
        let nextFilesToProcess = newFiles.prefix(fileImportQueueMaxCount)
        newFiles.subtract(nextFilesToProcess)
        DLOG("\(directories): newFiles minus processing files: (\(newFiles.count)):")
        DLOG("\(directories): \(newFiles)")
        if newFiles.isEmpty {
            uploadedFiles.removeAll()
        }
        return nextFilesToProcess
    }
    
    func loadAllFromICloud(iterationComplete: (() -> Void)? = nil) -> Completable {
        return Completable.create { [weak self] completable in
            self?.setupObservers(completable: completable, iterationComplete: iterationComplete)
            return Disposables.create()
        }
    }
    
    func setupObservers(completable: PrimitiveSequenceType.CompletableObserver, iterationComplete: (() -> Void)? = nil) {
        guard containerURL != nil,
              directories.count > 0
        else {
            completable(.error(SyncError.noUbiquityURL))
            return
        }
        
        initialSyncResult = syncToiCloud()
        DLOG("syncToiCloud result: \(initialSyncResult)")
        guard initialSyncResult != .saveFailure,
              initialSyncResult != .denied
        else {
            ELOG("error moving files to iCloud container")
            return
        }
        
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
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
        metadataQuery.predicate = NSPredicate(format: predicateFormat, argumentArray: predicateArgs)
        //TODO: update to use Publishers.MergeMany
        notificationCenter.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: nil) { [weak self] notification in
                Task {
                    await self?.queryFinished(notification: notification)
                    iterationComplete?()
                }
            }
        //listen for deletions and new files. what about conflicts?
        notificationCenter.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: metadataQuery,
            queue: nil) { [weak self] notification in
                Task {
                    await self?.queryFinished(notification: notification)
                    iterationComplete?()
                }
            }
        //TODO: unsure if the Task doesn't work with NSMetadataQuery or if there's some other issue.
//        Task { @MainActor [weak self] in
        DispatchQueue.main.async { [weak self] in
            self?.metadataQuery.start()
        }
    }
    
    func queryFinished(notification: Notification) async {
        DLOG("directories: \(directories)")
        guard (notification.object as? NSMetadataQuery) == metadataQuery
        else {
            return
        }
        let fileManager = FileManager.default
        var files: Set<URL> = []
        var filesDownloaded: Set<URL> = []
        let removedObjects = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey]
        if let actualRemovedObjects = removedObjects as? [NSMetadataItem] {
            DLOG("\(directories): actualRemovedObjects: (\(actualRemovedObjects.count)) \(actualRemovedObjects)")
            await actualRemovedObjects.concurrentForEach { [weak self] item in
                if let file = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                    DLOG("file DELETED from iCloud: \(file)")
                    self?.deleteFromDatastore(file)
                }
            }
        }
        DLOG("\(directories) -> number of items: \(metadataQuery.results.count)")
        //accessing results automatically pauses updates and resumes after deallocated
        /*await*/ metadataQuery.results.forEach/*concurrentForEach*/ { [weak self] item in
            if let fileItem = item as? NSMetadataItem,
               let file = fileItem.value(forAttribute: NSMetadataItemURLKey) as? URL,
               let isDirectory = try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               !isDirectory,//we only
               let downloadStatus = fileItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                DLOG("Found: \(file), download status: \(downloadStatus)")
                switch downloadStatus {
                    case  NSMetadataUbiquitousItemDownloadingStatusNotDownloaded:
                        do {
                            try fileManager.startDownloadingUbiquitousItem(at: file)
                            //self?.queue.async(flags: .barrier) {
                                files.insert(file)
                                self?.insertDownloadingFile(file)
                            //}
                            DLOG("Download started for: \(file)")
                        } catch {
                            self?.errorHandler.handleError(error, file: file)
                            ELOG("Failed to start download on file \(file): \(error)")
                        }
                    case NSMetadataUbiquitousItemDownloadingStatusCurrent:
                        DLOG("item up to date: \(file)")
                        if !fileManager.fileExists(atPath: file.pathDecoded) {
                            DLOG("file DELETED from iCloud: \(file)")
                            self?.deleteFromDatastore(file)
                        } else {
                            //self?.queue.async(flags: .barrier) {
                                //in the case when we are initially turning on iCloud or the app is opened and coming into the foreground for the first time, we try to import any files already downloaded
                                if self?.status == .initialUpload {
                                    self?.insertDownloadingFile(file)
                                }
                                filesDownloaded.insert(file)
                                self?.insertDownloadedFile(file)
                            //}
                        }
                    default: DLOG("\(file): download status: \(downloadStatus)")
                }
            }
        }
        setNewCloudFilesAvailable()
        DLOG("\(directories): current iteration: files pending to be downloaded: \(files.count), files downloaded : \(filesDownloaded.count)")
    }
    
    func syncToiCloud() -> SyncResult {
        let allDirectories = localAndCloudDirectories
        guard allDirectories.count > 0
        else {
            return .denied
        }
        var moveResult: SyncResult? = nil
        allDirectories.forEach { (localDirectory: URL, iCloudDirectory: URL) in
            
            let moved = moveFiles(at: localDirectory,
                                  containerDestination: iCloudDirectory,
                                  existingClosure: { existing in
                do {
                    try fileManager.removeItem(atPath: existing.pathDecoded)
                } catch {
                    errorHandler.handleError(error, file: existing)
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
    
    func removeFromiCloud() -> SyncResult {
        let allDirectories = localAndCloudDirectories
        guard allDirectories.count > 0
        else {
            return .denied
        }
        var moveResult: SyncResult?
        allDirectories.forEach { (localDirectory: URL, iCloudDirectory: URL) in
            let moved = moveFiles(at: iCloudDirectory,
                             containerDestination: localDirectory,
                             existingClosure: { existing in
                do {
                    try fileManager.evictUbiquitousItem(at: existing)
                } catch {//this happens when a file is being presented on the UI (saved states image) and thus we can't remove the icloud download
                    errorHandler.handleError(error, file: existing)
                    ELOG("error evicting iCloud file: \(existing), \(error)")
                }
            }) { currentSource, currentDestination in
                try fileManager.copyItem(at: currentSource, to: currentDestination)
                do {
                    try fileManager.evictUbiquitousItem(at: currentSource)
                } catch {//this happens when a file is being presented on the UI (saved states image) and thus we can't remove the icloud download
                    errorHandler.handleError(error, file: currentSource)
                    ELOG("error evicting iCloud file: \(currentSource), \(error)")
                }
            }
            if moved == .saveFailure {
                moveResult = .saveFailure
            }
        }
        return moveResult ?? .success
    }
    
    func moveFiles(at source: URL,
                   containerDestination: URL,
                   existingClosure: ((URL) -> Void),
                   moveClosure: (URL, URL) throws -> Void) -> SyncResult {
        DLOG("source: \(source)")
        guard fileManager.fileExists(atPath: source.pathDecoded)
        else {
            return .fileNotExist
        }
        let subdirectories: [String]
        do {
            subdirectories = try fileManager.subpathsOfDirectory(atPath: source.pathDecoded)
        } catch {
            errorHandler.handleError(error, file: source)
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
                    errorHandler.handleError(error, file: destination)
                    ELOG("error creating directory: \(destination), \(error)")
                }
            }
            if isDirectory.boolValue {
                continue
            }
            if fileManager.fileExists(atPath: destination.pathDecoded) {
                existingClosure(currentItem)
                continue
            }
            do {
                ILOG("Trying to move \(currentItem.pathDecoded) to \(destination.pathDecoded)")
                try moveClosure(currentItem, destination)
                insertUploadedFile(destination)
            } catch {
                errorHandler.handleError(error, file: currentItem)
                //this could indicate no more space is left when moving to iCloud
                ELOG("failed to move \(currentItem.pathDecoded) to \(destination.pathDecoded): \(error)")
            }
        }
        return .success
    }
}

extension Int64 {
    var toGb: String {
        String(format: "%.2f GBs", Double(self / (1024 * 1024 * 1024)))
    }
}

extension URL {
    /// calls URL.path(percentEncoded: false) which is the same as the upcoming deprecation of URL.path
    var pathDecoded: String {
        path(percentEncoded: false)
    }
    var appendDocumentsDirectory: URL {
        appendingPathComponent("Documents")
    }
}

extension Realm {
    func deleteGame(_ game: PVGame) throws {
        try write {
            game.saveStates.forEach { try? $0.delete() }
            game.cheats.forEach { try? $0.delete() }
            game.recentPlays.forEach { try? $0.delete() }
            game.screenShots.forEach { try? $0.delete() }
            delete(game)
            RomDatabase.reloadGamesCache()
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
    
    public static func initICloudDocuments() {
        NotificationCenter.default.addObserver(forName: .RomDatabaseInitialized, object: nil, queue: nil) { _ in
            Task {
                guard Defaults[.iCloudSync]
                else {
                    return
                }
                turnOn()
            }
        }
        Task {
            for await value in Defaults.updates(.iCloudSync) {
                iCloudSyncChanged(value)
            }
        }
    }
    
    static func iCloudSyncChanged(_ newValue: Bool) {
        DLOG("new iCloudSync value: \(newValue)")
        guard newValue
        else {
            turnOff()
            return
        }
        turnOn()
    }
    
    static func turnOn() {
        guard URL.supportsICloud else {
            DLOG("attempted to turn on iCloud, but iCloud is NOT setup on the device")
            return
        }
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        DLOG("turning on iCloud")
        //reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
        errorHandler.clear()
        let fm = FileManager.default
        if let currentiCloudToken = fm.ubiquityIdentityToken {
            do {
                let newTokenData = try NSKeyedArchiver.archivedData(withRootObject: currentiCloudToken, requiringSecureCoding: false)
                UserDefaults.standard.set(newTokenData, forKey: UbiquityIdentityTokenKey)
            } catch {
                errorHandler.handleError(error, file: nil)
                ELOG("error serializing iCloud token: \(error)")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: UbiquityIdentityTokenKey)
        }

        //TODO: should we pause when a game starts so we don't interfere with the game and continue listening when no game is running?
        disposeBag = DisposeBag()
        var nonDatabaseFileSyncer: iCloudContainerSyncer! = .init(directories: ["BIOS", "Battery States", "Screenshots"],
                                                                  notificationCenter: .default,
                                                                  errorHandler: iCloudErrorHandler.shared)
        nonDatabaseFileSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing nonDatabaseFileSyncer")
                nonDatabaseFileSyncer = nil
            }.disposed(by: disposeBag)
        var saveStateSyncer: SaveStateSyncer! = .init(notificationCenter: .default, errorHandler: iCloudErrorHandler.shared)
        saveStateSyncer.loadAllFromICloud() {
                saveStateSyncer.importNewSaves()
            }.observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing saveStateSyncer")
                saveStateSyncer = nil
            }.disposed(by: disposeBag)
        
        var romsSyncer: RomsSyncer! = .init(notificationCenter: .default, errorHandler: iCloudErrorHandler.shared)
        romsSyncer.loadAllFromICloud() {
                romsSyncer.handleImportNewRomFiles()
            }.observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing romsSyncer")
                romsSyncer = nil
            }.disposed(by: disposeBag)
    }
    
    static func turnOff() {
        DLOG("turning off iCloud")
        errorHandler.clear()
        disposeBag = nil
        //reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
    }
}

//MARK: - iCloud syncers

class SaveStateSyncer: iCloudContainerSyncer {
    let jsonDecorder = JSONDecoder()
    convenience init(notificationCenter: NotificationCenter, errorHandler: ErrorHandler) {
        self.init(directories: ["Save States"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        jsonDecorder.dataDecodingStrategy = .deferredToData
    }
    
    override func insertDownloadedFile(_ file: URL) {
        guard let _ = pendingFilesToDownload.remove(file.absoluteString),
              "json".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        DLOG("downloaded save file: \(file)")
        let newFilesCount: Int = queue.sync { [weak self] in
            self?.newFiles.insert(file)
            return self?.newFiles.count ?? 0
        }
        if newFilesCount >= fileImportQueueMaxCount {
            importNewSaves()
        }
    }
    
    override func deleteFromDatastore(_ file: URL) {
        guard "jpg".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        do {
            let realm = try Realm()
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
            try realm.write {
                realm.delete(save)
            }
        } catch {
            errorHandler.handleError(error, file: file)
            ELOG("error delating \(file) from database: \(error)")
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
        DLOG("Read JSON data at (\(json.absoluteString)")
        return save
    }
    
    func importNewSaves() {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        guard !newFiles.isEmpty
        else {
            return
        }
        queue.async(flags: .barrier) { [weak self] in
            guard let jsonFiles = self?.prepareNextBatchToProcess(),
                  !jsonFiles.isEmpty
            else {
                return
            }
            self?.processJsonFiles(jsonFiles)
        }
    }
    
    func processJsonFiles(_ jsonFiles: any Collection<URL>) {
        //for some reason doing this code in a Task just down't work, it only works with this nesting of Tasks and doing the concurrentForEach.
        Task {
            Task.detached { // @MainActor in
                await jsonFiles.concurrentForEach { @MainActor [weak self] json in
                    do {
                        guard let save = try self?.getSaveFrom(json)
                        else {
                            return
                        }
                        let realm = try await Realm()
                        let existing = realm.object(ofType: PVSaveState.self, forPrimaryKey: save.id)
                        if let existing = existing {
                            // Skip if Save already exists

                            // See if game is missing and set
                            if existing.game == nil || existing.game.system == nil, let game = realm.object(ofType: PVGame.self, forPrimaryKey: save.game.md5) {
                                do {
                                    try realm.write {
                                        existing.game = game
                                    }
                                } catch {
                                    self?.errorHandler.handleError(error, file: json)
                                    ELOG("Failed to update game \(json): \(error)")
                                }
                            }
                            // TODO: Maybe any other missing data updates or update values in general?
                            return
                        }

                        let newSave = await save.asRealm()
                        if !realm.isInWriteTransaction {
                            do {
                                try realm.write {
                                    realm.add(newSave, update: .all)
                                }
                            } catch {
                                self?.errorHandler.handleError(error, file: json)
                                ELOG("error adding new save \(json): \(error)")
                            }
                        } else {
                            realm.add(newSave, update: .all)
                        }
                        ILOG("Added new save \(newSave.debugDescription)")
                    } catch {
                        self?.errorHandler.handleError(error, file: json)
                        ELOG("Decode error on \(json): \(error)")
                        return
                    }
                }
            }
        }
    }
}

enum GamePurgeStatus {
    case incomplete
    case complete
}

enum GameStatus {
    case gameExists
    case gameDoesNotExist
}

class RomsSyncer: iCloudContainerSyncer {
    let gameImporter = GameImporter.shared
    var processingFiles = Set<URL>()
    var purgeStatus: GamePurgeStatus = .incomplete
    
    convenience init(notificationCenter: NotificationCenter, errorHandler: ErrorHandler) {
        self.init(directories: ["ROMs"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        notificationCenter.addObserver(forName: .RomsFinishedImporting, object: nil, queue: nil) { [weak self] _ in
            Task {
                self?.handleImportNewRomFiles()
            }
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    override func loadAllFromICloud(iterationComplete: (() -> Void)?) -> Completable {
        //ensure that the games are cached so we do NOT hit the database so much when checking for existence of games
        RomDatabase.reloadGamesCache()
        return super.loadAllFromICloud(iterationComplete: iterationComplete)
    }
    
    /// The only time that we don't know if files have been deleted by the user is when it happens while the app is closed. so we have to query the db and check
    func removeGamesDeletedWhileApplicationClosed() {
        guard purgeStatus == .incomplete,
              initialSyncResult == .success,
              //if we have errors, it's better to just assume something happened while importing, so instead of creating a bigger mess, just NOT delete any files
              errorHandler.numberOfErrors == 0,
              //we have to ensure that everything has been downloaded/imported before attempting to remove anything
              pendingFilesToDownload.count == 0,
              newFiles.count == 0,
              processingFiles.count == 0
        else {
            return
        }
        
        defer {
            purgeStatus = .complete
        }
        guard let actualContainrUrl = containerURL,
              let romsDirectoryName = directories.first
        else {
            return
        }
        
        let romsPath = actualContainrUrl.appendDocumentsDirectory.appendingPathComponent(romsDirectoryName)
        DLOG("romsPath: \(romsPath)")
        var realm: Realm! = nil
        RomDatabase.gamesCache.forEach { (_, game: PVGame) in
            let gameUrl = romsPath.appendingPathComponent(game.romPath)
            if !fileManager.fileExists(atPath: gameUrl.pathDecoded) {
                do {
                    if realm == nil {
                        do {//lazy load so we only instantiate if there's a match found
                            realm = try Realm()
                        } catch {
                            ELOG("error removing game entries that do NOT exist in the cloud container \(romsPath)")
                            return
                        }
                    }
                    if let gameToDelete = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash) {
                        try realm.deleteGame(gameToDelete)
                    }
                } catch {
                    ELOG("error deleting \(gameUrl), \(error)")
                }
            }
        }
    }
    
    override func insertDownloadedFile(_ file: URL) {
        guard let _ = pendingFilesToDownload.remove(file.absoluteString)
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
        guard getGameStatus(of: file) == .gameDoesNotExist
        else {
            DLOG("\(file) already exists in database. skipping...")
            return
        }
        DLOG("\(file) does NOT exist in database, adding to import set")
        let newFilesCount: Int = queue.sync(flags: .barrier) { [weak self] in
            self?.newFiles.insert(file)
            return self?.newFiles.count ?? 0
        }
        if newFilesCount >= fileImportQueueMaxCount {
            handleImportNewRomFiles()
        }
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
        guard let system = SystemIdentifier(rawValue: parentDirectory),
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
    
    override func deleteFromDatastore(_ file: URL) {
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
            let realm = try Realm()
            let romPath = "\(parentDirectory)/\(fileName)"
            DLOG("attempting to query PVGame by romPath: \(romPath)")
            guard let game: PVGame = realm.object(ofType: PVGame.self, forPrimaryKey: existingGame.md5Hash)
            else {
                return
            }
            
            try realm.deleteGame(game)
        } catch {
            errorHandler.handleError(error, file: file)
            ELOG("error deleting ROM \(file) from database: \(error)")
        }
    }
    
    func handleImportNewRomFiles() {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        clearProcessedFiles()
        removeGamesDeletedWhileApplicationClosed()
        guard !newFiles.isEmpty
        else {
            return
        }
        tryToImportNewRomFiles()
    }
    
    func tryToImportNewRomFiles() {
        //if the importer is currently importing files, we have to wait
        let importState = gameImporter.processingState
        guard importState == .idle,
              importState != .paused
        else {
            return
        }
        //give the UI a moment to finish updating, otherwise we get real bad app hangs non-stop and the user can't even get into a game or navigate through the UI. this is more of a hack, but it works for now when importing large libraries. not perfect, but allows the UI to breathe a little bit which is better than having the UI freeze because the user's reaction would prolly be to just shut down the app and reopen and then the user would go in an endless loop of not being able to use the app at all
        sleep(60)
        queue.async(flags: .barrier) { [weak self] in
            self?.importNewRomFiles()
        }
    
    }
    
    func clearProcessedFiles() {
        gameImporter.removeSuccessfulImports(from: &processingFiles)
    }
    
    func importNewRomFiles() {
        let nextFilesToProcess = prepareNextBatchToProcess()
        DLOG("\(directories): processingFiles: (\(processingFiles.count)):")
        DLOG("\(processingFiles)")
        processingFiles.formUnion(nextFilesToProcess)
        DLOG("\(directories): processingFiles plus new files: (\(processingFiles.count)):")
        DLOG("\(directories): \(processingFiles)")
        let importPaths = [URL](nextFilesToProcess)
        if newFiles.isEmpty {
            uploadedFiles.removeAll()
        }
        gameImporter.addImports(forPaths: importPaths)
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
    var count: Int { get }
    mutating func enqueue(entry: Entry)
    mutating func dequeue() -> Entry?
    func peek() -> Entry?
    mutating func clear()
}

struct iCloudErrorsQueue: Queue {
    var errors = [iCloudSyncError]()
    
    var count: Int {
        errors.count
    }
    
    mutating func enqueue(entry: iCloudSyncError) {
        errors.insert(entry, at: 0)
    }
    
    mutating func dequeue() -> iCloudSyncError? {
        guard !errors.isEmpty
        else {
            return nil
        }
        return errors.removeFirst()
    }
    
    func peek() -> iCloudSyncError? {
        errors.first
    }
    
    mutating func clear() {
        errors.removeAll()
    }
}

protocol ErrorHandler {
    var allErrorSummaries: [String] { get }
    var allFullErrors: [String] { get }
    var allErrors: [iCloudSyncError] { get }
    var numberOfErrors: Int { get }
    func handleError(_ error: Error, file: URL?)
    func clear()
}

class iCloudErrorHandler: ErrorHandler {
    static let shared = iCloudErrorHandler()
    var queue = iCloudErrorsQueue()
    
    var allErrorSummaries: [String] {
        queue.errors.map { $0.summary }
    }
    
    var allFullErrors: [String] {
        queue.errors.map { "\($0.error)" }
    }
    
    var allErrors: [iCloudSyncError] {
        queue.errors
    }
    
    var numberOfErrors: Int {
        queue.count
    }
    
    func handleError(_ error: any Error, file: URL?) {
        let syncError = iCloudSyncError(file: file?.path(percentEncoded: false), error: error)
        queue.enqueue(entry: syncError)
    }
    
    func clear() {
        queue.clear()
    }
}

extension URL {
    var parentPathComponent: String {
        deletingLastPathComponent().lastPathComponent
    }
    
    var fileName: String {
        lastPathComponent.removingPercentEncoding ?? lastPathComponent
    }
}
