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
    var metadataQuery: NSMetadataQuery { get }
    func syncToiCloud(completionHandler: @escaping (SyncResult) -> Void) // -> Single<SyncResult>
    func queryFile(completionHandler: @escaping (URL?) -> Void) // -> Single<URL>
    func downloadingFile(completionHandler: @escaping (SyncResult) -> Void) // -> Single<SyncResult>
}

public protocol iCloudTypeSyncer: Container {
    var newFiles: Set<URL> { get set }
    var directory: String { get }
    var metadataQuery: NSMetadataQuery { get }

    func loadAllFromICloud() -> Completable
    func removeAllFromICloud() -> Completable
    mutating func clearNewFiles()
    mutating func insertNewFile(_ file: URL)
    mutating func setNewFiles(_ files: Set<URL>)
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

    deinit {//because this was created inline, deinit gets called right away. does this ever need to be removed? shouldn't this be in the lifetime of the application?
        //center.removeObserver(observer, name: name, object: object)
    }
}

extension iCloudTypeSyncer {
    mutating func setNewFiles(_ files: Set<URL>) {
        newFiles = files
    }
    
    mutating func clearNewFiles() {
        newFiles.removeAll()
    }
    
    mutating func insertNewFile(_ file: URL) {
        newFiles.insert(file)
    }
    
    func loadAllFromICloud() -> Completable {
        return Completable.create { completable in
            //body mustn't run in a task, otherwise the NotificationObserver closure won't get called
            guard containerURL != nil
            else {
                completable(.error(SyncError.noUbiquityURL))
                return Disposables.create {}
            }
            self.metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            DLOG("directory: \(directory)")
            metadataQuery.predicate = NSPredicate(format: "%K CONTAINS[c] %@", NSMetadataItemPathKey, "/Documents/\(directory)/")
            
            let _: NotificationObserver = .init(
                forName: .NSMetadataQueryDidFinishGathering,
                object: self.metadataQuery,
                queue: nil) { notification in
                    self.queryFinished(notification: notification)
                    completable(.completed)
                }
            //TODO: listen for updates
            
            self.metadataQuery.start()
            return Disposables.create {}
        }
    }

    public func removeAllFromICloud() -> Completable {
        return Completable.create { completable in
            Task {

                guard self.containerURL != nil else {
                    completable(.error(SyncError.noUbiquityURL))
                    return Disposables.create {}
                }
                return Disposables.create {}
            }
            //        metadataQuery = NSMetadataQuery()
            self.metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
//            self.metadataQuery.predicate = self.metadataQueryPredicate

            let token: NSObjectProtocol? = NotificationCenter.default.addObserver(
                forName: Notification.Name.NSMetadataQueryDidFinishGathering,
                object: self.metadataQuery,
                queue: nil) { notification in
                    self.removeQueryFinished(notification: notification)
//                    if let token = token {
//                        NotificationCenter.default.removeObserver(token)
//                    }
                    completable(.completed)
                }

//            token = NotificationCenter.default.addObserver(
//                forName: Notification.Name.NSMetadataQueryDidUpdate,
//                object: self.metadataQuery,
//                queue: nil) { notification in
//                    self.queryFinished(notification: notification)
//                }
            self.metadataQuery.start()
            return Disposables.create {
                if let token = token {
                    NotificationCenter.default.removeObserver(token)
                }
            }
        }
    }

    func removeQueryFinished(notification: Notification) {
        let mq = notification.object as! NSMetadataQuery
        mq.disableUpdates()
        mq.stop()

        for i in 0..<mq.resultCount {
            let result = mq.result(at: i) as! NSMetadataItem
            let url = result.value(forAttribute: NSMetadataItemURLKey) as! URL

            // Remove all items in icloud
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                ELOG("error: \(error.localizedDescription)")
            }
        }
    }

    func queryFinished(notification: Notification) {
        DLOG("directory: \(directory)")
        guard (notification.object as? NSMetadataQuery) == metadataQuery
        else {
            return
        }
        let fileManager = FileManager.default
        var files: [URL] = []
        //TODO: don't think we need this
//        query.disableUpdates()
//        defer {
//            query.enableUpdates()
//        }
        //accessing results automatically pauses updates and resumes after deallocated
        for item in metadataQuery.results {
            if let fileItem = item as? NSMetadataItem,
               let file = fileItem.value(forAttribute: NSMetadataItemURLKey) as? URL,
               let downloadStatus = fileItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String,
               downloadStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
                DLOG("Found file: \(String(describing: file)), download status: \(downloadStatus)")
                files.append(file)
                
                do {
                    try fileManager.startDownloadingUbiquitousItem(at: file)
                    DLOG("Download started for: \(file.lastPathComponent)")
                } catch {
                    DLOG("Failed to start download: \(error)")
                }
            }
        }
        var downloadedFiles = Set<URL>()
        //we wait for all files to finish downloaded from iCloud
        while downloadedFiles.count != files.count {
            for file in files {
                if fileManager.fileExists(atPath: file.path) {
                    downloadedFiles.insert(file)
                }
            }
        }
        let name = Notification.Name.NewCloudFilesAvailable
        DLOG("downloadedFiles: \(downloadedFiles.count)")
        NotificationCenter.default.post(name: name, object: self, userInfo: [name.rawValue: downloadedFiles])
    }
}

extension SyncFileToiCloud where Self: LocalFileInfoProvider {
    private var destinationURL: URL? { get async {
        await Task {
            guard let containerURL = containerURL else { return nil }
            return containerURL.appendingPathComponent(url.relativePath)
        }.value
    }}

    func syncToiCloud() async -> SyncResult {
        await Task {
            guard let destinationURL = await self.destinationURL else {
                return SyncResult.denied
            }

            let url = self.url

            self.metadataQuery.disableUpdates()
            defer {
                self.metadataQuery.enableUpdates()
            }

            let fm = FileManager.default
            if fm.fileExists(atPath: url.path) {
                try! await fm.removeItem(at: url)
            }

            do {
                ILOG("Trying to set Ubiquitious from local (\(url.path)) to ICloud (\(destinationURL.path))")
                try fm.setUbiquitous(true, itemAt: url, destinationURL: destinationURL)
                return .success
            } catch {
                ELOG("iCloud failed to set Ubiquitous: \(error.localizedDescription)")
                return .saveFailure
            }
        }.value
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
    static var disposeBag: DisposeBag?
    public static func initICloudDocuments() {
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
        //TODO: there is an issue when all of the icloud files are downloaded and during the importing of ROMs + Save States there's a clash. I think we need to import ROMs first, then BIOS (if necessary) and then save states, everything else doesn't need to be imported onto the db (at least from what I understand)
        //TODO: pause when a game starts so we don't interfere with the game and continue listening when no game is running
        var saveStateSyncer = SaveStateSyncer()
        let disposeBag = DisposeBag()
        self.disposeBag = disposeBag
        saveStateSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: {
//                importNewSaves()
            }) { error in
                ELOG(error.localizedDescription)
            }.disposed(by: disposeBag)
        var romsSyncer = RomsSyncer()
        romsSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: {
                romsSyncer.handleNewRomFiles()
            }) { error in
                ELOG(error.localizedDescription)
            }.disposed(by: disposeBag)
        let biosSyncer = BiosSyncer()
        biosSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: {
                //TODO: anything?
            }) { error in
                ELOG(error.localizedDescription)
            }.disposed(by: disposeBag)
        let batterySaveSyncer = BatterySavesSyncer()
        batterySaveSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: {
                //TODO: anything?
            }) { error in
                ELOG(error.localizedDescription)
            }.disposed(by: disposeBag)
        let screenshotsSyncer = ScreenshotsSyncer()
        screenshotsSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: {
                //TODO: anything?
            }) { error in
                ELOG(error.localizedDescription)
            }.disposed(by: disposeBag)
    }
}
//TODO: perhaps 1 generic class since a lot of this code is similar and move the extension onto generic class. we could just add a protocol delegate dependency for ROMs and SaveState classes that does specific code
class SaveStateSyncer: iCloudTypeSyncer {
    var metadataQuery: NSMetadataQuery = .init()
    var newFiles: Set<URL> = []
    var areRomsDownloaded = false
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(wrapperImportSaves), name: .RomDatabaseInitialized, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(romsFinishedImporting), name: .RomsFinishedImporting, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewFiles(_:)), name: .NewCloudFilesAvailable, object: self)
    }
    deinit {
        DLOG("dying")
    }
    
    @objc
    func romsFinishedImporting() {
        //TODO: this should be reset somehow
        areRomsDownloaded = true
        wrapperImportSaves()
    }
    
    @objc
    func wrapperImportSaves() {
        //TODO: fix logic. we need to know if there are ROMs to download, if no, then we do the importing of saves
        guard areRomsDownloaded
        else {
            return
        }
        //TODO: fix, importing saves is crashing
        importNewSaves()
    }
    
    @objc
    func handleNewFiles(_ notification: Notification) {
        guard let downloadedFiles = notification.userInfo?[notification.name.rawValue] as? Set<URL>
        else {
            return
        }
        newFiles = downloadedFiles
    }
    
    var directory: String {
        "Save States"
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
        Task {
            let jsonFiles = newFiles.filter { $0.pathExtension == "json" }
            let jsonDecorder = JSONDecoder()
            jsonDecorder.dataDecodingStrategy = .deferredToData

            //Task.detached { // @MainActor in//can we re-add this with the change of not adding a task on the PVSave asRealm() function?
                await jsonFiles.concurrentForEach { @MainActor json in
                    let realm = try! await Realm()
                    do {
                        
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
            //}
        }
    }
}

class RomsSyncer: iCloudTypeSyncer {
    var metadataQuery: NSMetadataQuery = .init()
    var newFiles: Set<URL> = []
    let gameImporter = GameImporter.shared
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewRomFiles), name: .RomDatabaseInitialized, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewFiles(_:)), name: .NewCloudFilesAvailable, object: self)
    }
    deinit {
        DLOG("dying")
    }
    
    var directory: String {
        "ROMs"
    }
    
    @objc
    func handleNewFiles(_ notification: Notification) {
        guard let downloadedFiles = notification.userInfo?[notification.name.rawValue] as? Set<URL>
        else {
            return
        }
        newFiles = downloadedFiles
    }
    
    /// sends a notification that rom files are ready to e
    @objc
    func handleNewRomFiles() {
        //TODO: do we wait until the bios has been downloaded?
        guard !newFiles.isEmpty
        else {
            return
        }
        
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        
        var converted = [URL](newFiles)
        newFiles.removeAll()
        gameImporter.addImports(forPaths: converted)
        gameImporter.startProcessing()
    }
}

class BiosSyncer: iCloudTypeSyncer {
    var metadataQuery: NSMetadataQuery = .init()
    var newFiles: Set<URL> = []
    
    var directory: String {
        "BIOS"
    }
}

class BatterySavesSyncer: iCloudTypeSyncer {
    var metadataQuery: NSMetadataQuery = .init()
    var newFiles: Set<URL> = []
    
    var directory: String {
        "Battery Saves"
    }
}

class ScreenshotsSyncer: iCloudTypeSyncer {
    var metadataQuery: NSMetadataQuery = .init()
    var newFiles: Set<URL> = []
    //TODO: I think a base class that accepts the directory in the initializer may be better than this
    var directory: String {
        "Screenshots"
    }
}
