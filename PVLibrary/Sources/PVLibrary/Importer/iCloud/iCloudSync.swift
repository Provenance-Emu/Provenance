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
        let parentContainer = actualContainrUrl.appendingPathComponent("Documents")
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
        
        let completion = syncToiCloud()
        DLOG("saveStateUploader syncToiCloud result: \(completion)")
        guard completion != .saveFailure,
              completion != .denied
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
        let queue = DispatchQueue(label: "com.provenance.newFiles")
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
        
        //accessing results automatically pauses updates and resumes after deallocated
        await metadataQuery.results.concurrentForEach { [weak self] item in
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
                            queue.sync {
                                files.insert(file)
                                self?.insertDownloadingFile(file)
                            }
                            DLOG("Download started for: \(file)")
                        } catch {
                            self?.errorHandler.handleError(error, file: file)
                            DLOG("Failed to start download: \(error)")
                        }
                    case NSMetadataUbiquitousItemDownloadingStatusCurrent:
                        DLOG("item up to date: \(file)")
                        if !fileManager.fileExists(atPath: file.pathDecoded) {
                            DLOG("file DELETED from iCloud: \(file)")
                            self?.deleteFromDatastore(file)
                        } else {
                            queue.sync {
                                //in the case when we are initially turning on iCloud or the app is opened and coming into the foreground for the first time, we try to import any files already downloaded
                                if self?.status == .initialUpload {
                                    self?.insertDownloadingFile(file)
                                }
                                filesDownloaded.insert(file)
                                self?.insertDownloadedFile(file)
                            }
                        }
                    default: DLOG("\(file): download status: \(downloadStatus)")
                }
            }
        }
        //TODO: for ROMs and saves, perhaps we need to store the downloaded files that need to be process in the case of a crash or the user puts the app in the background.
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
                    ELOG("error deleting existing file that already exists in iCloud: \(existing), \(error)")
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
            ELOG("failed to get directory contents: \(error)")
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
                    DLOG("error creating directory: \(destination.pathDecoded), \(error)")
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

        guard URL.supportsICloud else {
            DLOG("attempted to turn on iCloud, but iCloud is NOT setup on the device")
            return
        }
        turnOn()
    }
    
    static func turnOn() {
        DLOG("turning on iCloud")
        //reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
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
        disposeBag = nil
        //reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
    }
}

//MARK: - iCloud syncers

//TODO: perhaps 1 generic class since a lot of this code is similar and move the extension onto generic class. we could just add a protocol delegate dependency for ROMs and SaveState classes that does specific code
class SaveStateSyncer: iCloudContainerSyncer {
    let jsonDecorder = JSONDecoder()
    convenience init(notificationCenter: NotificationCenter, errorHandler: ErrorHandler) {
        self.init(directories: ["Save States"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        jsonDecorder.dataDecodingStrategy = .deferredToData
        notificationCenter.addObserver(forName: .RomDatabaseInitialized, object: nil, queue: nil) { [weak self] _ in
            self?.importNewSaves()
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    override func insertDownloadedFile(_ file: URL) {
        guard let _ = pendingFilesToDownload.remove(file.absoluteString),
              "json".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        DLOG("downloaded save file: \(file)")
        newFiles.insert(file)
    }
    
    override func deleteFromDatastore(_ file: URL) {
        guard "jpg".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        do {
            let realm = try Realm()
            DLOG("attempting to query PVSaveState by file: \(file)")
            let gameDirectory = file.deletingLastPathComponent().lastPathComponent
            let savesDirectory = file.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
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
            ELOG("error delating from database: \(error)")
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
        guard pendingFilesToDownload.isEmpty
        else {
            return
        }
        let jsonFiles = newFiles
        newFiles.removeAll()
        uploadedFiles.removeAll()
        Task {
            Task.detached { // @MainActor in
                await jsonFiles.concurrentForEach { @MainActor [weak self] json in
                    do {
                        let realm = try await Realm()
                        guard let save = try self?.getSaveFrom(json)
                        else {
                            return
                        }
                        
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
                                    ELOG("Failed to update game: \(error)")
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
                                ELOG("error adding new save: \(error)")
                            }
                        } else {
                            realm.add(newSave, update: .all)
                        }
                        ILOG("Added new save \(newSave.debugDescription)")
                    } catch {
                        self?.errorHandler.handleError(error, file: json)
                        ELOG("Decode error: \(error)")
                        return
                    }
                }
            }
        }
    }
}

class RomsSyncer: iCloudContainerSyncer {
    let gameImporter = GameImporter.shared
    var processingFiles = Set<URL>()
    
    convenience init(notificationCenter: NotificationCenter, errorHandler: ErrorHandler) {
        self.init(directories: ["ROMs"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        notificationCenter.addObserver(forName: .RomDatabaseInitialized, object: nil, queue: nil) { [weak self] _ in
            self?.handleImportNewRomFiles()
        }
        notificationCenter.addObserver(forName: .RomsFinishedImporting, object: nil, queue: nil) { [weak self] _ in
            self?.handleImportNewRomFiles()
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    override func insertDownloadedFile(_ file: URL) {
        guard let _ = pendingFilesToDownload.remove(file.absoluteString)
        else {
            return
        }
        
        let parentDirectory = file.deletingLastPathComponent().lastPathComponent
        DLOG("adding file to game import queue: \(file), parent directory: \(parentDirectory)")
        //we should only add to the import queue files that are actual ROMs, anything else can be ignored.
        guard parentDirectory.range(of: "com.provenance.",
                                    options: [.caseInsensitive, .anchored]) != nil,
              let fileName = file.lastPathComponent.removingPercentEncoding
        else {
            return
        }
        
        do {
            let realm = try Realm()
            let romPath = "\(parentDirectory)/\(fileName)"
            DLOG("attempting to query PVGame by romPath: \(romPath)")
            let results = realm.objects(PVGame.self).filter(NSPredicate(format: "\(NSExpression(forKeyPath: \PVGame.romPath.self).keyPath) == %@", romPath))
            guard results.first == nil
            else {
                return
            }
        } catch {
            errorHandler.handleError(error, file: file)
            ELOG("error searching existing ROM: \(error)")
        }
        
        newFiles.insert(file)
    }
    
    override func deleteFromDatastore(_ file: URL) {
        //TODO: remove cloud download, but keep in iCloud. this way the ROM isn't deleted from all devices
        guard let fileName = file.lastPathComponent.removingPercentEncoding,
              let parentDirectory = file.deletingLastPathComponent().lastPathComponent.removingPercentEncoding
        else {
            return
        }
        do {
            let realm = try Realm()
            let romPath = "\(parentDirectory)/\(fileName)"
            DLOG("attempting to query PVGame by romPath: \(romPath)")
            let results = realm.objects(PVGame.self).filter(NSPredicate(format: "\(NSExpression(forKeyPath: \PVGame.romPath.self).keyPath) == %@", romPath))
            guard let game: PVGame = results.first
            else {
                return
            }
            
            try realm.write {
                game.saveStates.forEach { try? $0.delete() }
                game.cheats.forEach { try? $0.delete() }
                game.recentPlays.forEach { try? $0.delete() }
                game.screenShots.forEach { try? $0.delete() }
                realm.delete(game)
                RomDatabase.reloadGamesCache()
            }
        } catch {
            errorHandler.handleError(error, file: file)
            ELOG("error deleting ROM from database: \(error)")
        }
    }
    
    func handleImportNewRomFiles() {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        clearProcessedFiles()
        guard !newFiles.isEmpty
        else {
            return
        }
        guard pendingFilesToDownload.isEmpty
        else {
            return
        }
        Task { @MainActor in
            tryToImportNewRomFiles()
        }
    }
    
    func tryToImportNewRomFiles() {
        //if the importer is currently importing files, we have to wait
        guard gameImporter.processingState == .idle
        else {
            return
        }
        Task {
            importNewRomFiles()
        }
    }
    
    func clearProcessedFiles() {
        gameImporter.removeSuccessfulImports(from: &processingFiles)
    }
    
    func importNewRomFiles() {
        processingFiles = newFiles
        let importPaths = [URL](newFiles)
        newFiles.removeAll()
        uploadedFiles.removeAll()
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
    
    func handleError(_ error: any Error, file: URL?) {
        let syncError = iCloudSyncError(file: file?.path(percentEncoded: false), error: error)
        queue.enqueue(entry: syncError)
    }
    
    func clear() {
        queue.clear()
    }
}
