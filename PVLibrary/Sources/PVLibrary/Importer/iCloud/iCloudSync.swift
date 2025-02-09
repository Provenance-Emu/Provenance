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
    var directory: String { get }
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
    let directory: String
    let fileManager = FileManager.default
    let notificationCenter: NotificationCenter
    
    init(directory: String, notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
        self.directory = directory
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
    
    var iCloudDocumentsDirectory: URL? {
        containerURL?.appendingPathComponent("Documents")
            .appendingPathComponent(directory)
    }
    
    var localDirectory: URL {
        URL.documentsDirectory.appendingPathComponent(directory)
    }
    
    let metadataQuery: NSMetadataQuery = .init()
    
    func insertDownloadingFile(_ file: URL) {
        //no-op
    }
    
    func insertDownloadedFile(_ file: URL) {
        //no-op
    }
    
    func insertUploadedFile(_ file: URL) {
        //no-op
    }
    
    func setNewCloudFilesAvailable() {
        //no-op
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
        guard containerURL != nil
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
        DLOG("directory: \(directory)")
        metadataQuery.predicate = NSPredicate(format: "%K CONTAINS[c] %@", NSMetadataItemPathKey, "/Documents/\(directory)/")
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
        DLOG("directory: \(directory)")
        guard (notification.object as? NSMetadataQuery) == metadataQuery
        else {
            return
        }
        let fileManager = FileManager.default
        var files: Set<URL> = []
        var filesDownloaded: Set<URL> = []
        let queue = DispatchQueue(label: "org.provenance-emu.provenance.newFiles")
        let removedObjects = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey]
        DLOG("\(directory): removedObjects: \(removedObjects)")
        
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
                            DLOG("Download started for: \(file.lastPathComponent)")
                        } catch {
                            DLOG("Failed to start download: \(error)")
                        }
                    case NSMetadataUbiquitousItemDownloadingStatusCurrent:
                        DLOG("item up to date: \(file)")
                        if !fileManager.fileExists(atPath: file.path) {
                            DLOG("file DELETED from iCloud: \(file)")
                            self?.deleteFromDatastore(file)
                        } else {
                            queue.sync {
                                //in the case when we are initially turning on iCloud, we try to import any files already downloaded
                                //TODO: this should only happen one time per turning on the iCloud switch to avoid doing this every time the app opens, comes back to the foreground
                                if !Defaults[.iCloudInitialSetupComplete] {
                                    self?.insertDownloadingFile(file)
                                }
                                filesDownloaded.insert(file)
                                self?.insertDownloadedFile(file)
                            }
                        }
                    default: DLOG("\(file.lastPathComponent): download status: \(downloadStatus)")
                }
            }
        }
        //TODO: for ROMs and saves, perhaps we need to store the downloaded files that need to be process in the case of a crash or the user puts the app in the background.
        setNewCloudFilesAvailable()
        DLOG("\(directory): current iteration: files pending to be downloaded: \(files.count), files downloaded : \(filesDownloaded.count)")
    }
    
    func syncToiCloud() -> SyncResult {
        guard let destination = iCloudDocumentsDirectory
        else {
            return .denied
        }
        return moveFiles(at: localDirectory,
                         containerDestination: destination,
                         existingClosure: { existing in
            try fileManager.removeItem(atPath: existing.path)
        }) { currentSource, currentDestination in
            try fileManager.setUbiquitous(true, itemAt: currentSource, destinationURL: currentDestination)
        }
    }
    
    func removeFromiCloud() -> SyncResult {
        guard let source = iCloudDocumentsDirectory
        else {
            return .denied
        }
        return moveFiles(at: source,
                         containerDestination: localDirectory,
                         existingClosure: { existing in
            try fileManager.evictUbiquitousItem(at: existing)
        }) { currentSource, currentDestination in
            try fileManager.copyItem(at: currentSource, to: currentDestination)
            try fileManager.evictUbiquitousItem(at: currentSource)
        }
    }
    
    func moveFiles(at source: URL,
                   containerDestination: URL,
                   existingClosure: ((URL) throws -> Void),
                   moveClosure: (URL, URL) throws -> Void) -> SyncResult {
        DLOG("source: \(source)")
        guard fileManager.fileExists(atPath: source.path)
        else {
            return .fileNotExist
        }
        do {
            let subdirectories = try fileManager.subpathsOfDirectory(atPath: source.path)
            DLOG("subdirectories of \(source): \(subdirectories)")
            for currentChild in subdirectories {
                let currentItem = source.appendingPathComponent(currentChild)
                
                var isDirectory: ObjCBool = false
                let exists = fileManager.fileExists(atPath: currentItem.path, isDirectory: &isDirectory)
                DLOG("\(currentItem) isDirectory?\(isDirectory) exists?\(exists)")
                let destination = containerDestination.appendingPathComponent(currentChild)
                DLOG("new destination: \(destination)")
                if isDirectory.boolValue && !fileManager.fileExists(atPath: destination.path) {
                    DLOG("\(destination) does NOT exist")
                    try fileManager.createDirectory(atPath: destination.path, withIntermediateDirectories: false)
                }
                if isDirectory.boolValue {
                    continue
                }
                if fileManager.fileExists(atPath: destination.path) {
                    try existingClosure(currentItem)
                    continue
                }
                do {
                    ILOG("Trying to move (\(currentItem.path)) to (\(destination.path))")
                    try moveClosure(currentItem, destination)
                    insertUploadedFile(destination)
                } catch {
                    //this could indicate no more space is left when moving to iCloud
                    ELOG("failed to move: \(error.localizedDescription)")
                }
            }
            return .success
        } catch {
            ELOG("failed to get directory contents: \(error.localizedDescription)")
            return .saveFailure
        }
    }
}

enum iCloudError: Error {
    case dataReadFail
}

public enum iCloudSync {
    static var disposeBag: DisposeBag!
    //syncers
    static var saveStateSyncer: SaveStateSyncer!
    static var biosSyncer: BiosSyncer!
    static var batterySavesSyncer: BatterySavesSyncer!
    static var screenshotsSyncer: ScreenshotsSyncer!
    static var gameImporter = GameImporter.shared
    
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
        Defaults[.iCloudInitialSetupComplete] = false//TODO: when the app first opens, this shouldn't be done, only when the user taps the flag on
        
        let fm = FileManager.default
        if let currentiCloudToken = fm.ubiquityIdentityToken {
            do {
                let newTokenData = try NSKeyedArchiver.archivedData(withRootObject: currentiCloudToken, requiringSecureCoding: false)
                UserDefaults.standard.set(newTokenData, forKey: UbiquityIdentityTokenKey)
            } catch {
                ELOG("\(error.localizedDescription)")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: UbiquityIdentityTokenKey)
        }

        //TODO: should we pause when a game starts so we don't interfere with the game and continue listening when no game is running?
        disposeBag = DisposeBag()
        
        saveStateSyncer = .init(notificationCenter: .default)
        saveStateSyncer.loadAllFromICloud() {
                saveStateSyncer.importNewSaves()
            }.observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing saveStateSyncer")
                saveStateSyncer = nil
            }.disposed(by: disposeBag)
        
        var romsSyncer: RomsSyncer! = .init(notificationCenter: .default)
        romsSyncer.loadAllFromICloud() {
                romsSyncer.importNewRomFiles()
            }.observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing romsSyncer")
                romsSyncer = nil
            }.disposed(by: disposeBag)
        //TODO: set the following to merge onto a single class that just does a query for icloud for all of those directories.
        biosSyncer = .init(notificationCenter: .default)
        biosSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing BiosSyncer")
                biosSyncer = nil
            }.disposed(by: disposeBag)
        batterySavesSyncer = .init(notificationCenter: .default)
        batterySavesSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing BatterySavesSyncer")
                batterySavesSyncer = nil
            }.disposed(by: disposeBag)
        screenshotsSyncer = .init(notificationCenter: .default)
        screenshotsSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing ScreenshotsSyncer")
                screenshotsSyncer = nil
            }.disposed(by: disposeBag)
    }
    
    static func turnOff() {
        DLOG("turning off iCloud")
        disposeBag = nil
        //reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
        //TODO: remove iCloud downloads. do we also copy those files locally?
    }
}

//MARK: - iCloud syncers

//TODO: perhaps 1 generic class since a lot of this code is similar and move the extension onto generic class. we could just add a protocol delegate dependency for ROMs and SaveState classes that does specific code
class SaveStateSyncer: iCloudContainerSyncer {
    var didFinishDownloadingAllFiles = false
    
    init(notificationCenter: NotificationCenter) {
        super.init(directory: "Save States", notificationCenter: notificationCenter)
        notificationCenter.addObserver(forName: .RomDatabaseInitialized, object: nil, queue: nil) { [weak self] _ in
            self?.importNewSaves()
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    override func setNewCloudFilesAvailable() {
        didFinishDownloadingAllFiles = pendingFilesToDownload.isEmpty && !newFiles.isEmpty
    }
    
    override func insertDownloadingFile(_ file: URL) {
        guard !uploadedFiles.contains(file)
        else {
            return
        }
        pendingFilesToDownload.insert(file.absoluteString)
    }
    
    override func insertDownloadedFile(_ file: URL) {
        guard let _ = pendingFilesToDownload.remove(file.absoluteString),
              "json".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        DLOG("downloaded save file: \(file.lastPathComponent)")
        newFiles.insert(file)
    }
    
    override func insertUploadedFile(_ file: URL) {
        uploadedFiles.insert(file)
    }
    
    override func deleteFromDatastore(_ file: URL) {
        guard "jpg'".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        do {
            let realm = try Realm()
            DLOG("attempting to query PVSaveState by file: \(file)")
            let imageField = NSExpression(forKeyPath: \PVSaveState.image.self).keyPath
            let urlField = NSExpression(forKeyPath: \PVImageFile.url.self).keyPath
            let absoluteStringField = NSExpression(forKeyPath: \URL.absoluteString.self).keyPath
            let results = realm.objects(PVSaveState.self).filter(NSPredicate(format: "\(imageField).\(urlField).\(absoluteStringField) == %@", file.absoluteString))
            guard let save: PVSaveState = results.first
            else {
                return
            }
            try realm.write {
                realm.delete(save)
            }
        } catch {
            ELOG(error.localizedDescription)
        }
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
        guard didFinishDownloadingAllFiles
        else {
            return
        }
        //TODO: initially when importing icloud files, we should wait for ROMs to finish importing. when that completes, then we no longer have to wait for that, ie when syncing single changes say 2 devices are open at the same time and 1 save file is added from another device
        didFinishDownloadingAllFiles = false
        let jsonFiles = newFiles
        newFiles.removeAll()
        uploadedFiles.removeAll()
        Task {
            let jsonDecorder = JSONDecoder()
            jsonDecorder.dataDecodingStrategy = .deferredToData

            Task.detached { // @MainActor in
                await jsonFiles.concurrentForEach { @MainActor json in
                    do {
                        let realm = try await Realm()
                        let secureDoc = json.startAccessingSecurityScopedResource()

                        defer {
                            if secureDoc {
                                json.stopAccessingSecurityScopedResource()
                            }
                        }
                        
                        var dataMaybe = FileManager.default.contents(atPath: json.path)
                        if dataMaybe == nil {
                            dataMaybe = try Data(contentsOf: json, options: [.uncached])
                        }
                        guard let data = dataMaybe else {
                            throw iCloudError.dataReadFail
                        }

                        DLOG("Data read \(String(data: data, encoding: .utf8) ?? "Nil")")
                        let save = try jsonDecorder.decode(SaveState.self, from: data)
                        DLOG("Read JSON data at (\(json.absoluteString)")

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
                                    ELOG("Failed to update game: \(error.localizedDescription)")
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
                                ELOG(error.localizedDescription)
                            }
                        } else {
                            realm.add(newSave, update: .all)
                        }
                        ILOG("Added new save \(newSave.debugDescription)")
                    } catch {
                        ELOG("Decode error: " + error.localizedDescription)
                        return
                    }
                }
            }
        }
    }
}

class RomsSyncer: iCloudContainerSyncer {
    let gameImporter = GameImporter.shared
    var didFinishDownloadingAllFiles = false
    init(notificationCenter: NotificationCenter) {
        super.init(directory: "ROMs", notificationCenter: notificationCenter)
        notificationCenter.addObserver(forName: .RomDatabaseInitialized, object: nil, queue: nil) { [weak self] _ in
            self?.importNewRomFiles()
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    override func setNewCloudFilesAvailable() {
        didFinishDownloadingAllFiles = pendingFilesToDownload.isEmpty && !newFiles.isEmpty
    }
    
    override func insertDownloadingFile(_ file: URL) {
        //we ensure we don't re-add any files we just moved over
        guard !uploadedFiles.contains(file)
        else {
            return
        }
        pendingFilesToDownload.insert(file.absoluteString)
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
            ELOG(error.localizedDescription)
        }
        
        newFiles.insert(file)
    }
    
    override func insertUploadedFile(_ file: URL) {
        uploadedFiles.insert(file)
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
            }
        } catch {
            ELOG(error.localizedDescription)
        }
    }
    
    func importNewRomFiles() {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        guard !newFiles.isEmpty
        else {
            return
        }
        guard didFinishDownloadingAllFiles
        else {
            return
        }
        didFinishDownloadingAllFiles = false
        Defaults[.iCloudInitialSetupComplete] = true
        let importPaths = [URL](newFiles)
        newFiles.removeAll()
        uploadedFiles.removeAll()
        gameImporter.addImports(forPaths: importPaths)
        gameImporter.startProcessing()
    }
}

class BiosSyncer: iCloudContainerSyncer {
    convenience init(notificationCenter: NotificationCenter) {
        self.init(directory: "BIOS", notificationCenter: notificationCenter)
    }
}

class BatterySavesSyncer: iCloudContainerSyncer {
    convenience init(notificationCenter: NotificationCenter) {
        self.init(directory: "Battery Saves", notificationCenter: notificationCenter)
    }
}

class ScreenshotsSyncer: iCloudContainerSyncer {
    convenience init(notificationCenter: NotificationCenter) {
        self.init(directory: "Screenshots", notificationCenter: notificationCenter)
    }
}
