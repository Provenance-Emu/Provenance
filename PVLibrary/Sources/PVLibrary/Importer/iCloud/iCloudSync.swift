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
    var metadataQuery: NSMetadataQuery { get }
    var metadataQueryPredicate: NSPredicate { get } // ex NSPredicate(format: "%K like 'PHOTO*'", NSMetadataItemFSNameKey)

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

    deinit {
        center.removeObserver(observer, name: name, object: object)
    }
}

extension iCloudTypeSyncer {
    public func loadAllFromICloud() -> Completable {
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
            self.metadataQuery.predicate = self.metadataQueryPredicate

            let _: NotificationObserver = .init(
                forName: Notification.Name.NSMetadataQueryDidFinishGathering,
                object: self.metadataQuery,
                queue: nil) {[self] notification in
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
            self.metadataQuery.predicate = self.metadataQueryPredicate

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
        let mq = notification.object as! NSMetadataQuery
        mq.disableUpdates()
        mq.stop()

        //        for i in 0 ..< mq.resultCount {
        //            let result = mq.result(at: i) as! NSMetadataItem
        //            let name = result.value(forAttribute: NSMetadataItemFSNameKey) as! String
        //            let url = result.value(forAttribute: NSMetadataItemURLKey) as! URL
        // TODO: Some kind of observable rx?
        //            let document: Self.Type! = DocumentPhoto(fileURL: url)
        //            document?.open(completionHandler: {(success) -> Void in
        //
        //                if (success) {
        //                    print("Image loaded with name \(name)")
        //                    self.cells.append(document.image)
        //                    self.collectionView.reloadData()
        //                }
        //            })
        //        }
    }
}

extension SyncFileToiCloud where Self: LocalFileInfoProvider {
    private var destinationURL: URL? { get async {
        await Task {
            guard let containerURL = containerURL, let relativePath = url?.relativePath else { return nil }
            return containerURL.appendingPathComponent(relativePath)
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
            if let url = url, fm.fileExists(atPath: url.path) {
                try! await fm.removeItem(at: url)
            }

            do {
                ILOG("Trying to set Ubiquitious from local (\(url?.path ?? "")) to ICloud (\(destinationURL.path))")
                if let url = url {
                    try fm.setUbiquitous(true, itemAt: url, destinationURL: destinationURL)
                }
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

        let saveStateSyncer = SaveStateSyncer()
        let disposeBag = DisposeBag()
        self.disposeBag = disposeBag
        saveStateSyncer.loadAllFromICloud()
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: {
                importNewSaves()
                self.disposeBag = nil
            }) { error in
                ELOG("\(error.localizedDescription)")
            }.disposed(by: disposeBag)
    }

    public static func importNewSaves() {
        if !RomDatabase.databaseInitialized {
            // Keep trying // TODO: Add a notification for this
            // instead of dumb loop
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.importNewSaves()
            }
            return
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
    public var metadataQuery: NSMetadataQuery = .init()
    public var metadataQueryPredicate: NSPredicate {
        return NSPredicate(format: "%K CONTAINS[c] 'Save States'", NSMetadataItemPathKey)
    }
}
