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

extension Notification.Name {
    static let cloudDataDownloaded = Notification.Name("kCloudDataDownloaded")
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
    var newFiles: Set<URL> { get }
    var directory: String { get }
    var metadataQuery: NSMetadataQuery { get }

    func loadAllFromICloud() -> Completable
    func removeAllFromICloud() -> Completable
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
    public func loadAllFromICloud() -> Completable {
        return Completable.create { completable in
            //body mustn't run in a task, otherwise the NotificationObserver closure won't get called
            guard containerURL != nil
            else {
                completable(.error(SyncError.noUbiquityURL))
                return Disposables.create {}
            }
            var tmp = newFiles
            tmp.removeAll()
            self.metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            metadataQuery.predicate = NSPredicate(format: "%K CONTAINS[c] %@", NSMetadataItemPathKey, "/Documents/\(directory)/")
            
            let _: NotificationObserver = .init(
                forName: Notification.Name.NSMetadataQueryDidFinishGathering,
                object: self.metadataQuery,
                queue: nil) { notification in
                    self.queryFinished(notification: notification)
                    completable(.completed)
                }
            
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
        //TODO: update so this is generic for all downloads
        guard type(of: self) != SaveStateSyncer.self
        else {
            return
        }
        
        guard let query = notification.object as? NSMetadataQuery
        else {
            return
        }
        let fileManager = FileManager.default
        let isMainThread = Thread.isMainThread
        print("isMainThread:\(isMainThread)")
        var files: [URL] = []
        //accessing results automatically pauses updates and resumes after deallocated
        for item in query.results {
            if let fileItem = item as? NSMetadataItem,
               let file = fileItem.value(forAttribute: NSMetadataItemURLKey) as? URL,
               let downloadStatus = fileItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String,
               downloadStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
                print("Found file: \(String(describing: file)), download status: \(downloadStatus)")
                files.append(file)
                
                do {
                    try fileManager.startDownloadingUbiquitousItem(at: file)
                    //TODO: we have to wait until the files are downloaded, we can just create a queue and then just loop until the queue is empty
                    print("Download started for: \(file.lastPathComponent)")
                } catch {
                    print("Failed to start download: \(error)")
                }
            }
        }
        var downloadedFiles = newFiles
        while downloadedFiles.count != files.count {
            for file in files {
                if fileManager.fileExists(atPath: file.path) {
                    downloadedFiles.insert(file)
                }
            }
        }
        
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
    //TODO: move bags to each class
    static var disposeBagSaveState: DisposeBag?
    static var disposeBagRoms: DisposeBag?
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

        let saveStateSyncer = SaveStateSyncer()
        let currentDisposeBagSaveState = DisposeBag()
        self.disposeBagSaveState = currentDisposeBagSaveState
        saveStateSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: {
                importNewSaves()
            }) { error in
                ELOG(error.localizedDescription)
            }.disposed(by: currentDisposeBagSaveState)
        let romsSyncer = RomsSyncer()
        let currentDisposeBagRoms = DisposeBag()
        disposeBagRoms = currentDisposeBagRoms
        romsSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: {
                romsSyncer.handleNewRomFiles()
            }) { error in
                ELOG(error.localizedDescription)
            }.disposed(by: currentDisposeBagRoms)
    }
    
//TODO: prolly this should be in SaveStateSyncer
    public static func importNewSaves() {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        
        defer {
            disposeBagSaveState = nil
        }

        Task {
            let savesDirectory = Paths.saveSavesPath
            let legacySavesDirectory = Paths.Legacy.saveSavesPath
            let fm = FileManager.default
            guard let subDirs = try? fm.contentsOfDirectory(at: savesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
                ELOG("Failed to read saves path: \(savesDirectory.path)")
                return
            }

            let saveFiles = subDirs.compactMap {
                try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            }.joined()
            let jsonFiles = saveFiles.filter { $0.pathExtension == "json" }
            let jsonDecorder = JSONDecoder()
            jsonDecorder.dataDecodingStrategy = .deferredToData

            let legacySubDirs: [URL]?
            do {
                legacySubDirs = try fm.contentsOfDirectory(at: legacySavesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            } catch {
                ELOG("\(error.localizedDescription)")
                legacySubDirs = nil
            }

            await legacySubDirs?.asyncForEach {
                do {
                    let destinationURL = Paths.saveSavesPath.appendingPathComponent($0.lastPathComponent, isDirectory: true)
                    if !fm.isUbiquitousItem(at: destinationURL) {
                        try fm.setUbiquitous(true,
                                             itemAt: $0,
                                             destinationURL: destinationURL)
                    } else {
                        //                        var resultURL: NSURL?
                        //                        try fm.replaceItem(at: destinationURL, withItemAt: $0, backupItemName: nil, resultingItemURL: &resultURL)
                        //                        try fm.evictUbiquitousItem(at: destinationURL)
                        try fm.startDownloadingUbiquitousItem(at: destinationURL)
                    }
                } catch {
                    ELOG("Error: \(error)")
                }
            }
            //        let saves = realm.objects(PVSaveState.self)
            //        saves.forEach {
            //            fm.setUbiquitous(true, itemAt: $0.file.url, destinationURL: Paths.saveSavesPath.appendingPathComponent($0.game.file.fileNameWithoutExtension, isDirectory: true).app)
            //        }
            Task.detached {
                jsonFiles.forEach { json in
                    do {
                        try FileManager.default.startDownloadingUbiquitousItem(at: json)
                    } catch {
                        ELOG("Download error: " + error.localizedDescription)
                    }
                }
            }

            Task.detached { // @MainActor in
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
            }
        }
    }
}

class SaveStateSyncer: iCloudTypeSyncer {
    var metadataQuery: NSMetadataQuery = .init()
    var newFiles: Set<URL> = []
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(wrapper), name: .cloudDataDownloaded, object: nil)
    }
    deinit {
        print("dying")
    }
    
    @objc
    func wrapper() {
        iCloudSync.importNewSaves()
    }
    
    var directory: String {
        "Save States"
    }
}

class RomsSyncer: iCloudTypeSyncer {
    var metadataQuery: NSMetadataQuery = .init()
    var newFiles: Set<URL> = []
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewRomFiles), name: .cloudDataDownloaded, object: nil)
    }
    deinit {
        print("dying")
    }
    
    var directory: String {
        "ROMs"
    }
    
    /// sends a notification that rom files are ready to e
    @objc
    func handleNewRomFiles() {
        guard !newFiles.isEmpty
        else {
            return
        }
        
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        
        NotificationCenter.default.post(name: .cloudDataDownloaded, object: nil, userInfo: ["kCloudDataDownloaded": newFiles])
        iCloudSync.disposeBagRoms = nil
    }
}
