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

public protocol SyncFileToiCloud: Container {
    var fileManager: FileManager { get }
    var metadataQuery: NSMetadataQuery { get }
    func syncToiCloud(completionHandler: @escaping (SyncResult) -> Void) async// -> Single<SyncResult>
    func queryFile(completionHandler: @escaping (URL?) -> Void) // -> Single<URL>
    func downloadingFile(completionHandler: @escaping (SyncResult) -> Void) async // -> Single<SyncResult>
}

public protocol iCloudTypeSyncer: Container {
    var directory: String { get }
    var metadataQuery: NSMetadataQuery { get }

    func loadAllFromICloud(iterationComplete: (() -> Void)?) -> Completable
    func insertDownloadingFile(_ file: URL)
    func insertDownloadedFile(_ file: URL)
    func deleteFromDatastore(_ file: URL)
    func setNewCloudFilesAvailable()
}

final class NotificationObserver {

    var name: Notification.Name
    var observer: NSObjectProtocol
    var center = NotificationCenter.default
    var object: Any?

    init(forName name: Notification.Name, object: Any? = nil, queue: OperationQueue? = nil, block: @escaping (Notification) -> Void) {
        self.name = name
        observer = center.addObserver(forName: name, object: object, queue: queue, using: block)
    }

    deinit {//TODO: because this was created inline, deinit gets called right away. does this ever need to be removed? shouldn't this be in the lifetime of the application?
        //center.removeObserver(observer, name: name, object: object)
    }
}

class iCloudContainerSyncer: iCloudTypeSyncer {
    lazy var pendingFilesToDownload: Set<String> = []
    lazy var newFiles: Set<URL> = []
    let directory: String
    
    init(directory: String) {
        self.directory = directory
    }
    
    deinit {
        metadataQuery.disableUpdates()
        metadataQuery.stop()
        DLOG("dying")
    }
    
    let metadataQuery: NSMetadataQuery = .init()
    
    func insertDownloadingFile(_ file: URL) {
        //no-op
    }
    
    func insertDownloadedFile(_ file: URL) {
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
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        DLOG("directory: \(directory)")
        metadataQuery.predicate = NSPredicate(format: "%K CONTAINS[c] %@", NSMetadataItemPathKey, "/Documents/\(directory)/")
        //TODO: update to use Publishers.MergeMany
        let _: NotificationObserver = .init(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: nil) { [weak self] notification in
                Task {
                    await self?.queryFinished(notification: notification)
                    iterationComplete?()
                }
            }
        //listen for deletions and new files. what about conflicts?
        let _: NotificationObserver = .init(
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
}

extension SyncFileToiCloud where Self: LocalFileInfoProvider {
    private var destinationURL: URL? { get async {
        await Task {
            guard let containerURL = containerURL else { return nil }
            return containerURL.appendingPathComponent(url.relativePath)
        }.value
    }}
    
    //TODO: refactor this on the syncer
    func syncToiCloud(completionHandler: @escaping (SyncResult) -> Void) async {
        await Task {

            DLOG("url: \(url)")
            guard fileManager.fileExists(atPath: url.path),
                  let actualContainerUrl = containerURL
            else {
                completionHandler(.fileNotExist)
                return
            }
//            guard let destinationURL = await self.destinationURL else {
//                return completionHandler(.denied)
//            }
//            let url = self.url
//
//            self.metadataQuery.disableUpdates()
//            defer {
//                self.metadataQuery.enableUpdates()
//            }

            completionHandler(await moveFiles(at: url, container: actualContainerUrl.appendingPathComponent("Documents").appendingPathComponent(url.lastPathComponent)))
        }.value
    }
    
    func moveFiles(at current: URL, container: URL) async -> SyncResult {
        do {
            let subdirectories = try fileManager.subpathsOfDirectory(atPath: current.path)
            DLOG("subdirectories of \(current): \(subdirectories)")
            for currentChild in subdirectories {
                let currentItem = current.appendingPathComponent(currentChild)
                
                var isDirectory: ObjCBool = false
                let exists = fileManager.fileExists(atPath: currentItem.path, isDirectory: &isDirectory)
                DLOG("\(currentItem) isDirectory?\(isDirectory) exists?\(exists)")
                let iCloudDestination = container.appendingPathComponent(currentChild)
                DLOG("new iCloud directory: \(iCloudDestination)")
                if isDirectory.boolValue && !fileManager.fileExists(atPath: iCloudDestination.path) {
                    DLOG("\(iCloudDestination) does NOT exist")
                    try fileManager.createDirectory(atPath: iCloudDestination.path, withIntermediateDirectories: false)
                }
                if isDirectory.boolValue {
                    continue
                }
                if fileManager.fileExists(atPath: iCloudDestination.path) {
                    try fileManager.removeItem(atPath: currentItem.path)
                    continue
                }
                do {
                    ILOG("Trying to set Ubiquitious from local (\(currentItem.path)) to ICloud (\(iCloudDestination.path))")
                    try fileManager.setUbiquitous(true, itemAt: currentItem, destinationURL: iCloudDestination)
                } catch {
                    //this could indicate no more space is left
                    ELOG("iCloud failed to set Ubiquitous: \(error.localizedDescription)")
                }
            }
            return .success
        } catch {
            ELOG("failed to get directory contents: \(error.localizedDescription)")
            return .saveFailure
        }
    }

    /// - Parameter completionHandler: Non-main
    func queryFile(completionHandler: @escaping (URL?) -> Void) {
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        let center = NotificationCenter.default

        center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: nil) { _ in
            //            guard let `self` = self else {return}

            self.metadataQuery.disableUpdates()
            defer {
                self.metadataQuery.enableUpdates()
            }

            guard self.metadataQuery.resultCount >= 1,
                  let item = self.metadataQuery.results.first as? NSMetadataItem,
                  let fileURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL
            else {
                self.metadataQuery.enableUpdates()
                return completionHandler(nil)
            }

            completionHandler(fileURL)
            self.metadataQuery.enableUpdates()
        }

        metadataQuery.start()
    }

    /// - Parameters:
    ///   - completionHandler: Non-main
    func downloadingFile(completionHandler: @escaping (SyncResult) -> Void) async {
        guard let destinationURL = await destinationURL else {
            completionHandler(.denied)
            return
        }

        DispatchQueue.global(qos: .utility).async {
            if !FileManager.default.isUbiquitousItem(at: destinationURL) {
                completionHandler(.fileNotExist)
                return
            }

            self.metadataQuery.disableUpdates()
            defer {
                self.metadataQuery.enableUpdates()
            }

            let fm = FileManager.default

            do {
                // TODO: Should really wait and listen for it to finish downloading, this call is async
                try fm.startDownloadingUbiquitousItem(at: destinationURL)
                completionHandler(.success)
            } catch {
                ELOG("iCloud Download error: \(error.localizedDescription)")
                completionHandler(.saveFailure)
                return
            }
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
    //initial uploaders
    static var saveStateUploader = SaveStateUploader()
    static var romsUploader = RomsUploader()
    
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
        //TODO: move files from local to cloud container
        Task {
            await saveStateUploader.syncToiCloud { completion in
                DLOG("saveStateUploader syncToiCloud result: \(completion)")
            }
            await romsUploader.syncToiCloud { completion in
                DLOG("romsUploader syncToiCloud result: \(completion)")
            }
        }
        //TODO: first we upload anything pending, then we download anything that already exists and import those. we will have to update the locations of existing saves and ROMs in the db
#if DEBUG
        if 1==1 {
            return
        }
#endif
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
        biosSyncer = .init()
        biosSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing BiosSyncer")
                biosSyncer = nil
            }.disposed(by: disposeBag)
        batterySavesSyncer = .init()
        batterySavesSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing BatterySavesSyncer")
                batterySavesSyncer = nil
            }.disposed(by: disposeBag)
        screenshotsSyncer = .init()
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
    let notificationCenter: NotificationCenter
    
    init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
        super.init(directory: "Save States")
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
    
    override func deleteFromDatastore(_ file: URL) {
//        PVSaveState
        //TODO: delete from database
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
    let notificationCenter: NotificationCenter
    init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
        super.init(directory: "ROMs")
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
                                    options: [.caseInsensitive, .anchored]) != nil
        else {
            return
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
        let importPaths = [URL](newFiles)
        newFiles.removeAll()
        gameImporter.addImports(forPaths: importPaths)
        gameImporter.startProcessing()
    }
}

class BiosSyncer: iCloudContainerSyncer {
    convenience init() {
        self.init(directory: "BIOS")
    }
}

class BatterySavesSyncer: iCloudContainerSyncer {
    convenience init() {
        self.init(directory: "Battery Saves")
    }
}

class ScreenshotsSyncer: iCloudContainerSyncer {
    convenience init() {
        self.init(directory: "Screenshots")
    }
}

//MARK: - iCloud initial container uploaders

class SaveStateUploader: SyncFileToiCloud, LocalFileInfoProvider {
    let fileManager = FileManager.default
    let metadataQuery: NSMetadataQuery = .init()
    let url: URL = URL.documentsDirectory.appendingPathComponent("Save States")
}

class RomsUploader: SyncFileToiCloud, LocalFileInfoProvider {
    let fileManager = FileManager.default
    let metadataQuery: NSMetadataQuery = .init()
    let url: URL = URL.documentsDirectory.appendingPathComponent("ROMs")
}
