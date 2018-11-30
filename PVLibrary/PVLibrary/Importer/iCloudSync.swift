//
//  iCloudSync.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 11/13/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift
import RxRealm
import RxSwift

public enum SyncError : Error {
    case noUbiquityURL
}

public enum SyncResult {
    case denied
    case saveFailure
    case fileNotExist
    case success
}

public protocol Container {
    var containerURL : URL? {get}
}

extension Container {
    var containerURL : URL? { return PVEmulatorConfiguration.iCloudContainerDirectory }
    var documentsURL : URL? { return PVEmulatorConfiguration.iCloudDocumentsDirectory }
}

public protocol SyncFileToiCloud : Container {
    var metadataQuery: NSMetadataQuery {get}
    func syncToiCloud(completionHandler: @escaping (SyncResult) -> Void) // -> Single<SyncResult>
    func queryFile(completionHandler: @escaping (URL?) -> Void) // -> Single<URL>
    func downloadingFile(completionHandler: @escaping (SyncResult) -> Void) // -> Single<SyncResult>
}

public protocol iCloudTypeSyncer : Container {
    var metadataQuery: NSMetadataQuery {get set}
    var metadataQueryPredicate : NSPredicate {get} //ex NSPredicate(format: "%K like 'PHOTO*'", NSMetadataItemFSNameKey)

    static func loadAllFromICloud() -> Completable
    static func removeAllFromICloud() -> Completable
}

extension iCloudTypeSyncer {
    func loadAllFromICloud() -> Completable {
        return Completable.create { completable in
            guard self.containerURL != nil else {
                completable(.error(SyncError.noUbiquityURL))
                return Disposables.create { }
            }

            //        metadataQuery = NSMetadataQuery()
            self.metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            self.metadataQuery.predicate = self.metadataQueryPredicate

            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(forName: Notification.Name.NSMetadataQueryDidFinishGathering, object: self.metadataQuery, queue: nil) { (notification) in
                self.queryFinished(notification: notification)

                NotificationCenter.default.removeObserver(token!)
                completable(.completed)
            }

            self.metadataQuery.start()
            return Disposables.create {}
        }
    }

    func removeAllFromICloud() -> Completable {
        return Completable.create { completable in

            guard self.containerURL != nil else {
                completable(.error(SyncError.noUbiquityURL))
                return Disposables.create { }
            }
            //        metadataQuery = NSMetadataQuery()
            self.metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            self.metadataQuery.predicate = self.metadataQueryPredicate
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(forName: Notification.Name.NSMetadataQueryDidFinishGathering, object: self.metadataQuery, queue: nil) { (notification) in
                self.removeQueryFinished(notification: notification)
                NotificationCenter.default.removeObserver(token!)
                completable(.completed)
            }

            self.metadataQuery.start()
            return Disposables.create {}
        }
    }

    func removeQueryFinished(notification: Notification) {
        let mq = notification.object as! NSMetadataQuery
        mq.disableUpdates()
        mq.stop()

        for i in 0 ..< mq.resultCount {
            let result = mq.result(at: i) as! NSMetadataItem
            let url = result.value(forAttribute: NSMetadataItemURLKey) as! URL

            // Remove all items in icloud
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("error: \(error.localizedDescription)")
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

extension SyncFileToiCloud where Self:LocalFileInfoProvider {
    private var destinationURL : URL? {
        guard let containerURL = containerURL else { return nil }
        return containerURL.appendingPathComponent(self.url.relativePath)
    }

    func syncToiCloud(completionHandler: @escaping (SyncResult) -> Void) {
        DispatchQueue.global(qos: .background).async {
            guard let destinationURL = self.destinationURL else {
                completionHandler(.denied)
                return
            }

            let url = self.url

            self.metadataQuery.disableUpdates()
            defer {
                self.metadataQuery.enableUpdates()
            }

            let fm = FileManager.default
            if fm.fileExists(atPath: url.path) {
                try! fm.removeItem(at: url)
            }

            do {
                ILOG("Trying to set Ubiquitious from local (\(url.path)) to ICloud (\(destinationURL.path))")
                try fm.setUbiquitous(true, itemAt: url, destinationURL: destinationURL)
                completionHandler(.success)
            } catch {
                ELOG("iCloud failed to set Ubiquitous: \(error.localizedDescription)")
                completionHandler(.saveFailure)
            }
        }
    }

    /// - Parameter completionHandler: Non-main
    func queryFile(completionHandler: @escaping (URL?) -> Void) {
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        let center = NotificationCenter.default

        center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: nil) { notification in
            //            guard let `self` = self else {return}

            self.metadataQuery.disableUpdates()
            defer {
                self.metadataQuery.enableUpdates()
            }

            guard self.metadataQuery.resultCount >= 1,
                let item = self.metadataQuery.results.first as? NSMetadataItem,
                let fileURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
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
    func downloadingFile(completionHandler: @escaping (SyncResult) -> Void) {

        guard let destinationURL = self.destinationURL else {
            completionHandler(.denied)
            return
        }

        DispatchQueue.global(qos: .background).async {

            if (!FileManager.default.isUbiquitousItem(at: destinationURL)) {
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

public final class iCloudSync {
    static let UbiquityIdentityTokenKey = "com.provenance-emu.provenenace.UbiquityIdentityToken"

    public static func initICloudDocuments() {
        let fm = FileManager.default
        if let currentiCloudToken = fm.ubiquityIdentityToken {
            let newTokenData = NSKeyedArchiver.archivedData(withRootObject: currentiCloudToken)
            UserDefaults.standard.set(newTokenData, forKey: UbiquityIdentityTokenKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UbiquityIdentityTokenKey)
        }
    }

    public static func importNewSaves() {
        let savesDirectory = PVEmulatorConfiguration.Paths.saveSavesPath
        let legacySavesDirectory = PVEmulatorConfiguration.Paths.Legacy.saveSavesPath
        let fm = FileManager.default
        guard let subDirs = try? fm.contentsOfDirectory(at: savesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            ELOG("Failed to read saves path: \(savesDirectory.path)")
            return
        }

        let saveFiles = subDirs.compactMap {
            return try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            }.joined()
        let jsonFiles = saveFiles.filter { $0.pathExtension == "json" }
        let jsonDecorder = JSONDecoder.init()

        let legacySubDirs = try? fm.contentsOfDirectory(at: legacySavesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

        legacySubDirs?.forEach {
            try? fm.setUbiquitous(true, itemAt: $0, destinationURL: PVEmulatorConfiguration.Paths.saveSavesPath.appendingPathComponent($0.lastPathComponent, isDirectory: true))
        }
        //        let saves = realm.objects(PVSaveState.self)
        //        saves.forEach {
        //            fm.setUbiquitous(true, itemAt: $0.file.url, destinationURL: PVEmulatorConfiguration.Paths.saveSavesPath.appendingPathComponent($0.game.file.fileNameWithoutExtension, isDirectory: true).app)
        //        }

        let realm = try! Realm()
        jsonFiles.forEach { json in

            if let data = try? Data(contentsOf: json), let save = try? jsonDecorder.decode(SaveState.self, from: data) {
                DLOG("Read JSON data at (\(json.absoluteString)")

                let existing = realm.object(ofType: PVSaveState.self, forPrimaryKey: save.id)
                if let existing = existing {
                    // Skip if Save already exists

                    // See if game is missing and set
                    if existing.game == nil, let game = realm.object(ofType: PVGame.self, forPrimaryKey: save.game.md5) {
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

                let newSave = save.asRealm()
                if !realm.isInWriteTransaction {
                    do {
                        try realm.write {
                            realm.add(newSave, update: true)
                        }
                    } catch {
                        ELOG(error.localizedDescription)
                    }
                } else {
                    realm.add(newSave, update: true)
                }
                ILOG("Added new save \(newSave.debugDescription)")
            }
        }
    }
}
