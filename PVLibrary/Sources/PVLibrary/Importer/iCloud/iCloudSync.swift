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

    func loadAllFromICloud(iterationComplete: (() -> Void)?) -> Completable
    func insertDownloadingFile(_ file: URL) -> URL?
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
    lazy var pendingFilesToDownload: ConcurrentSet<URL> = []
    lazy var newFiles: ConcurrentSet<URL> = []
    lazy var uploadedFiles: ConcurrentSet<URL> = []
    let directories: Set<String>
    let fileManager: FileManager = .default
    let notificationCenter: NotificationCenter
    var status: iCloudSyncStatus = .initialUpload
    let errorHandler: ErrorHandler
    var initialSyncResult: SyncResult = .indeterminate
    var fileImportQueueMaxCount = 1000
    var purgeStatus: DatastorePurgeStatus = .incomplete
    private var querySubscriber: AnyCancellable?
    
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
        let removed = removeFromiCloud()
        DLOG("removed: \(removed)")
    }
    
    var canPurgeDatastore: Bool {
        purgeStatus == .incomplete
            && initialSyncResult == .success
            //if we have errors, it's better to just assume something happened while importing, so instead of creating a bigger mess, just NOT delete any files
            && errorHandler.numberOfErrors == 0
            //we have to ensure that everything has been downloaded/imported before attempting to remove anything
            && pendingFilesToDownload.isEmpty
            && newFiles.isEmpty
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
    
    func insertDownloadingFile(_ file: URL) -> URL? {
        guard !uploadedFiles.contains(file)
        else {
            return nil
        }
        pendingFilesToDownload.insert(file)
        return file
    }
    
    func insertDownloadedFile(_ file: URL) {
        pendingFilesToDownload.remove(file)
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
        DLOG("directories: \(directories)")//TODO: remove guard since it's now part of the filter
        guard (notification.object as? NSMetadataQuery) === metadataQuery
        else {
            return
        }
        //accessing metadataQuery.results implicitly calls disable/enable, but for some reason with large libraries, the signals don't get fired at all that files finished downloading. by enabling this, we get the signals, although it erroneously shows as not downloaded, but we are able to check the metrics to know the real state of the file
        metadataQuery.disableUpdates()
        defer {
            metadataQuery.enableUpdates()
        }
        DLOG("\(notification.name): \(directories) -> number of items: \(metadataQuery.results.count)")
        metadataQuery.results.forEach { item in
            if let fileItem = item as? NSMetadataItem,
               let file = fileItem.value(forAttribute: NSMetadataItemURLKey) as? URL,
               let isDirectory = try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               !isDirectory,//we only
               let downloadStatus = fileItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                let lastModified = fileItem.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
                let isDownloading = fileItem.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool
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
                - Is downloading: \(isDownloading ?? false)
                - Download error: \(downloadingError ?? "None")
                - Percent downloaded: \(percentDownloaded)
                - Is uploaded: \(isUploaded ?? false)
                - Is uploading: \(isUploading ?? false)
                - does file exist: \(doesFileExist)
                """)
                switch downloadStatus {
                    case  NSMetadataUbiquitousItemDownloadingStatusNotDownloaded:
                        //if the download percentage is 100 and the file exists, we can process the file. for large libraries the event is incorrect. it could be because the number of files are so large
                        if percentDownloaded == 100 && doesFileExist {
                            handleDownloadedFile(file)
                        } else {
                            handleFileToDownload(file)
                        }
                    case NSMetadataUbiquitousItemDownloadingStatusCurrent:
                        handleDownloadedFile(file)
                    default: ILOG("Other: \(file): download status: \(downloadStatus)")
                }
            }
        }
        let removedObjects = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey]
        if let actualRemovedObjects = removedObjects as? [NSMetadataItem] {
            DLOG("\(directories): actualRemovedObjects: (\(actualRemovedObjects.count)) \(actualRemovedObjects)")
            actualRemovedObjects.forEach { item in
                if let file = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                    DLOG("file DELETED from iCloud: \(file)")
                    deleteFromDatastore(file)
                }
            }
        }
        setNewCloudFilesAvailable()
        //TODO: this count is missing the multi file ones for ROMs
        ILOG("\(notification.name): \(directories): current iteration: files pending to be downloaded: \(pendingFilesToDownload.count), files downloaded : \(newFiles.count)")
    }
    
    func handleFileToDownload(_ file: URL) {
        do {//only start download if we haven't already started
            if let fileToDownload = insertDownloadingFile(file) {
                try fileManager.startDownloadingUbiquitousItem(at: fileToDownload)
            }
            ILOG("Download started for: \(file.pathDecoded)")
        } catch {
            errorHandler.handleError(error, file: file)
            ELOG("Failed to start download on file \(file.pathDecoded): \(error)")
        }
    }
    
    func handleDownloadedFile(_ file: URL) {
        DLOG("item up to date: \(file)")
        if !fileManager.fileExists(atPath: file.pathDecoded) {
            DLOG("file DELETED from iCloud: \(file)")
            deleteFromDatastore(file)
        } else {
            //in the case when we are initially turning on iCloud or the app is opened and coming into the foreground for the first time, we try to import any files already downloaded
            if status == .initialUpload {
                insertDownloadingFile(file)
            }
            insertDownloadedFile(file)
        }
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

extension URL {
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
    static var romDatabaseInitializedSubscriber: AnyCancellable?
    public static func initICloudDocuments() {
        romDatabaseInitializedSubscriber = NotificationCenter.default.publisher(for: .RomDatabaseInitialized).sink { _ in
            romDatabaseInitializedSubscriber?.cancel()
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
        var nonDatabaseFileSyncer: iCloudContainerSyncer! = .init(directories: ["BIOS", "Battery States", "Screenshots", "DeltaSkins"],
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
    let processed = ConcurrentQueue<Int>(arrayLiteral: 0)
    let processingState: ConcurrentQueue<ProcessingState> = .init(arrayLiteral: .idle)
    var savesFinishedImportingSubscriber: AnyCancellable?
    
    convenience init(notificationCenter: NotificationCenter, errorHandler: ErrorHandler) {
        self.init(directories: ["Save States"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        fileImportQueueMaxCount = 10
        jsonDecorder.dataDecodingStrategy = .deferredToData
        savesFinishedImportingSubscriber = notificationCenter.publisher(for: .SavesFinishedImporting).sink { [weak self] _ in
            Task {
                self?.importNewSaves()
            }
        }
    }
    
    deinit {
        savesFinishedImportingSubscriber?.cancel()
    }
    
    func removeSavesDeletedWhileApplicationClosed() {
        guard canPurgeDatastore
        else {
            return
        }
        defer {
            purgeStatus = .complete
        }
        guard let actualContainrUrl = containerURL
        else {
            return
        }
        let realm: Realm
        do {
            realm = try Realm()
        } catch {
            ELOG("error clearing saves deleted while application was closed")
            return
        }
        let saveIds = realm.objects(PVSaveState.self).map { $0.id }
        saveIds.forEach { saveId in
            guard let save = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveId)
            else {
                return
            }
            guard let image = save.image
            else {
                return
            }
            let saveUrl = actualContainrUrl.appendingPathComponent(image.partialPath)
            if !fileManager.fileExists(atPath: saveUrl.pathDecoded) {
                do {
                    try realm.write {
                        realm.delete(save)
                    }
                } catch {
                    ELOG("error deleting \(saveUrl), \(error)")
                }
            }
        }
    }
    
    override func insertDownloadedFile(_ file: URL) {
        guard let _ = pendingFilesToDownload.remove(file),
              "json".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        ILOG("downloaded save file: \(file)")
        newFiles.insert(file)
        importNewSaves()
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
        DLOG("Read JSON data at (\(json.pathDecoded)")
        return save
    }
    
    func importNewSaves() {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        removeSavesDeletedWhileApplicationClosed()
        guard !newFiles.isEmpty,
              processingState.peek() == .idle
        else {
            return
        }
        let jsonFiles = prepareNextBatchToProcess()
        guard !jsonFiles.isEmpty
        else {
            return
        }
        processJsonFiles(jsonFiles)
    }
    
    func processJsonFiles(_ jsonFiles: any Collection<URL>) {
        processingState.dequeue()
        processingState.enqueue(entry: .processing)
        var processedCount = processed.dequeue() ?? 0
        ILOG("Saves: downloading: \(pendingFilesToDownload.count), processing: \(jsonFiles.count), total processed: \(processedCount)")
        for json in jsonFiles {
            do {
                processedCount += 1
                guard let save: SaveState = try getSaveFrom(json)
                else {
                    continue
                }
                let realm = try Realm()
                guard let existing: PVSaveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: save.id)
                else {
                    ILOG("Saves: processing: save #(\(processedCount)) \(json)")
                    storeNewSave(save, realm, json)
                    continue
                }
                updateExistingSave(existing, realm, save, json)
                
            } catch {
                errorHandler.handleError(error, file: json)
                ELOG("Decode error on \(json): \(error)")
            }
        }
        processed.enqueue(entry: processedCount)
        processingState.dequeue()
        processingState.enqueue(entry: .idle)
        removeSavesDeletedWhileApplicationClosed()
        notificationCenter.post(Notification(name: .SavesFinishedImporting))
    }
    
    func updateExistingSave(_ existing: PVSaveState, _ realm: Realm, _ save: SaveState, _ json: URL) {
        // See if game is missing and set
       guard existing.game == nil || existing.game.system == nil,
             let game = realm.object(ofType: PVGame.self, forPrimaryKey: save.game.md5)
        else {
           return
       }
        do {
            ILOG("Saves: updating \(json)")
            try realm.write {
                existing.game = game
            }
        } catch {
            errorHandler.handleError(error, file: json)
            ELOG("Failed to update game \(json): \(error)")
        }
    }
    
    func storeNewSave(_ save: SaveState, _ realm: Realm, _ json: URL) {
        let newSave = save.asRealm()
        do {
            try realm.write {
                realm.add(newSave, update: .all)
            }
        } catch {
            errorHandler.handleError(error, file: json)
            ELOG("error adding new save \(json): \(error)")
        }
        ILOG("Added new save \(json)")
        DLOG("Added new save \(newSave.debugDescription)")
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
    let processingFiles = ConcurrentQueue(arrayLiteral: 0)
    let multiFileRoms: ConcurrentDictionary<String, [URL]> = [:]
    var romsFinishedImportingSubscriber: AnyCancellable?
    
    convenience init(notificationCenter: NotificationCenter, errorHandler: ErrorHandler) {
        self.init(directories:  ["ROMs", "Save States", "BIOS", "DeltaSkins"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        romsFinishedImportingSubscriber = notificationCenter.publisher(for: .RomsFinishedImporting).sink { [weak self] _ in
            Task {
                self?.handleImportNewRomFiles()
            }
        }
    }
    
    deinit {
        romsFinishedImportingSubscriber?.cancel()
    }
    
    override func loadAllFromICloud(iterationComplete: (() -> Void)?) -> Completable {
        //ensure that the games are cached so we do NOT hit the database so much when checking for existence of games
        RomDatabase.reloadGamesCache()
        return super.loadAllFromICloud(iterationComplete: iterationComplete)
    }
    
    /// The only time that we don't know if files have been deleted by the user is when it happens while the app is closed. so we have to query the db and check
    func removeGamesDeletedWhileApplicationClosed() {
        guard canPurgeDatastore
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
        let realm: Realm
        do {
            realm = try Realm()
        } catch {
            ELOG("error removing game entries that do NOT exist in the cloud container \(romsPath)")
            return
        }
        RomDatabase.gamesCache.forEach { (_, game: PVGame) in
            let gameUrl = romsPath.appendingPathComponent(game.romPath)
            guard fileManager.fileExists(atPath: gameUrl.pathDecoded)
            else {
                return
            }
            do {
                if let gameToDelete = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash) {
                    try realm.deleteGame(gameToDelete)
                }
            } catch {
                ELOG("error deleting \(gameUrl), \(error)")
            }
        }
    }
    
    override func insertDownloadedFile(_ file: URL) {
        guard let _ = pendingFilesToDownload.remove(file)
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
        ILOG("\(file) does NOT exist in database, adding to import set")
        if let multiKey = file.multiFileNameKey {
            var files = multiFileRoms[multiKey] ?? [URL]()
            files.append(file)
            multiFileRoms[multiKey] = files
        } else {
            newFiles.insert(file)
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
        removeGamesDeletedWhileApplicationClosed()
        guard !newFiles.isEmpty
                || (!multiFileRoms.isEmpty && pendingFilesToDownload.isEmpty)
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
        importNewRomFiles()
    
    }
    
    func importNewRomFiles() {
        var nextFilesToProcess = prepareNextBatchToProcess()
        if nextFilesToProcess.isEmpty,
           let nextMultiFile = multiFileRoms.first {
            nextFilesToProcess = nextMultiFile.value
            multiFileRoms[nextMultiFile.key] = nil
        }
        let currentProcessingCount = processingFiles.dequeue() ?? 0
        DLOG("\(directories): processingFiles: (\(currentProcessingCount)):")
        let newProcessingCount = nextFilesToProcess.count + currentProcessingCount
        processingFiles.enqueue(entry: newProcessingCount)
        DLOG("\(directories): processingFiles plus new files: (\(newProcessingCount)):")
        let importPaths = [URL](nextFilesToProcess)
        if newFiles.isEmpty {
            uploadedFiles.removeAll()
        }
        Task {
            await gameImporter.addImports(forPaths: importPaths)
            ILOG("ROMs: downloading: \(pendingFilesToDownload.count), pending to process: \(newFiles.count), processing: \(newProcessingCount)")
            //to ensure we do NOT go on an endless loop
            gameImporter.startProcessing()
        }
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
    func enqueue(entry: Entry)
    func dequeue() -> Entry?
    func peek() -> Entry?
    func clear()
    var allElements: [Entry] { get }
}

class ConcurrentQueue<Element>: Queue, ExpressibleByArrayLiteral {
    private var collection = [Element]()
    private let queue = DispatchQueue(label: "com.provenance.concurrent.queue")
    
    required init(arrayLiteral elements: Element...) {
        collection = Array(elements)
    }
    
    @inlinable
    var count: Int {
        queue.sync {
            collection.count
        }
    }
    
    @inlinable
    func enqueue(entry: Element) {
        queue.async { [weak self] in
            self?.collection.insert(entry, at: 0)
        }
    }
    
    @inlinable
    @discardableResult
    func dequeue() -> Element? {
        queue.sync {
            guard !collection.isEmpty
            else {
                return nil
            }
            return collection.removeFirst()
        }
    }
    
    @inlinable
    func peek() -> Element? {
        queue.sync {
            collection.first
        }
    }
    
    @inlinable
    func clear() {
        queue.async { [weak self] in
            self?.collection.removeAll()
        }
    }
    
    @inlinable
    public var description: String {
        queue.sync {
            collection.description
        }
    }
    
    @inlinable
    func map<T>(_ transform: (Element) throws -> T) throws -> [T] {
        try queue.sync {
            try collection.map(transform)
        }
    }
    
    @inlinable
    var allElements: [Element] {
        queue.sync {
            collection
        }
    }
}

protocol ErrorHandler {
    var allErrorSummaries: [String] { get throws }
    var allFullErrors: [String] { get throws }
    var allErrors: [iCloudSyncError] { get }
    var numberOfErrors: Int { get }
    func handleError(_ error: Error, file: URL?)
    func clear()
}

class iCloudErrorHandler: ErrorHandler {
    static let shared = iCloudErrorHandler()
    private let queue = ConcurrentQueue<iCloudSyncError>()
    
    @inlinable
    var allErrorSummaries: [String] {
        get throws {
            try queue.map { $0.summary }
        }
    }
    
    @inlinable
    var allFullErrors: [String] {
        get throws {
            try queue.map { "\($0.error)" }
        }
    }
    
    @inlinable
    var allErrors: [iCloudSyncError] {
        queue.allElements
    }
    
    @inlinable
    var numberOfErrors: Int {
        queue.count
    }
    
    func handleError(_ error: any Error, file: URL?) {
        let syncError = iCloudSyncError(file: file?.path(percentEncoded: false), error: error)
        queue.enqueue(entry: syncError)
    }
    
    @inlinable
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
    
    //TODO: needs to be updated to not include .bin files for non multi-file ROMs
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

class ConcurrentDictionary<Key: Hashable, Value>: ExpressibleByDictionaryLiteral, CustomStringConvertible {
    private var dictionary: [Key: Value] = [:]
    private let queue = DispatchQueue(label: "com.provenance.concurrent.dictionary")
    
    public required init(dictionaryLiteral elements: (Key, Value)...) {
        dictionary = Dictionary(uniqueKeysWithValues: elements)
    }
    
    @inlinable
    subscript(key: Key) -> Value? {
        get {
            queue.sync {
                dictionary[key]
            }
        }
        set {
            queue.async { [weak self] in
                self?.dictionary[key] = newValue
            }
        }
    }
    
    @inlinable
    var first: (key: Key, value: Value)? {
        queue.sync {
            dictionary.first
        }
    }
    
    @inlinable
    var isEmpty: Bool {
        queue.sync {
            dictionary.isEmpty
        }
    }
    
    @inlinable
    var count: Int {
        queue.sync {
            dictionary.count
        }
    }
    
    public var description: String {
        queue.sync {
            dictionary.description
        }
    }
}

enum ConcurrentCopyOptions {
    case removeCopiedItems
    case retainCopiedItems
}

public class ConcurrentSet<T: Hashable>: ExpressibleByArrayLiteral, CustomStringConvertible, ObservableObject {
    // MARK: - Combine Support
    
    /// Subject for publishing set changes
    private let changeSubject = PassthroughSubject<Set<T>, Never>()
    
    /// Subject for publishing count changes
    private let countSubject = CurrentValueSubject<Int, Never>(0)
    
    /// Publisher for set changes
    public var publisher: AnyPublisher<Set<T>, Never> {
        changeSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for count changes
    public var countPublisher: AnyPublisher<Int, Never> {
        countSubject.eraseToAnyPublisher()
    }
    private var set: Set<T>
    private let queue = DispatchQueue(label: "com.provenance.concurrent.set")
    
    public required init(arrayLiteral elements: T...) {
        set = Set(elements)
        countSubject.send(set.count)
    }
    
    convenience init(fromSet set: Set<T>) {
        self.init()
        self.set.formUnion(set)
    }
    
    func insert(_ element: T) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.set.insert(element)
            self.notifyChanges()
        }
    }
    
    func remove(_ element: T) -> T? {
        queue.sync {
            let removed = set.remove(element)
            notifyChanges()
            return removed
        }
    }
    
    func contains(_ element: T) -> Bool {
        queue.sync {
            set.contains(element)
        }
    }
    
    func removeAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.set.removeAll()
            self.notifyChanges()
        }
    }
    
    func forEach(_ body: (T) throws -> Void) rethrows {
        try queue.sync {
            try set.forEach(body)
        }
    }
    
    func prefix(_ maxLength: Int) -> Slice<Set<T>> {
        queue.sync {
            set.prefix(maxLength)
        }
    }
    
    func subtract<S>(_ other: S) where T == S.Element, S : Sequence {
        queue.sync {
            set.subtract(other)
            notifyChanges()
        }
    }
    
    func copy(options: ConcurrentCopyOptions) -> Set<T> {
        queue.sync {
            var copiedSet: Set<T> = .init(set)
            if options == .removeCopiedItems {
                set.removeAll()
            }
            return copiedSet
        }
    }
    
    func formUnion<S>(_ other: S) where T == S.Element, S : Sequence {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.set.formUnion(other)
            self.notifyChanges()
        }
    }
    
    var isEmpty: Bool {
        queue.sync {
            set.isEmpty
        }
    }
    
    var first: T? {
        queue.sync {
            set.first
        }
    }
    
    var count: Int {
        queue.sync { set.count }
    }
    
    /// Current elements in the set as a Set
    var elements: Set<T> {
        queue.sync { set }
    }
    
    /// Current elements in the set as an Array
    var asArray: [T] {
        queue.sync { Array(set) }
    }
    
    public var description: String {
        queue.sync {
            set.description
        }
    }
    
    /// Notify subscribers of changes to the set
    private func notifyChanges() {
        let currentSet = set
        let currentCount = currentSet.count
        DispatchQueue.main.async { [weak self] in
            self?.changeSubject.send(currentSet)
            self?.countSubject.send(currentCount)
        }
    }
}
