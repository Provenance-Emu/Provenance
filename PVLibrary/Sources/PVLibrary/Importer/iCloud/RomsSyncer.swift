//
//  RomsSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import RxSwift
import PVPrimitives
import PVFileSystem
import PVRealm
import RealmSwift
import CloudKit

/// Protocol for ROM-specific sync operations
public protocol RomsSyncing: SyncProvider {
    /// Get the local URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The local URL for the ROM file
    func localURL(for game: PVGame) -> URL?
    
    /// Get the cloud URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The cloud URL for the ROM file
    func cloudURL(for game: PVGame) -> URL?
    
    /// Upload a ROM file to the cloud
    /// - Parameter game: The game to upload
    /// - Returns: Completable that completes when the upload is done
    func uploadROM(for game: PVGame) -> Completable
    
    /// Download a ROM file from the cloud
    /// - Parameter game: The game to download
    /// - Returns: Completable that completes when the download is done
    func downloadROM(for game: PVGame) -> Completable
}

// MARK: - iOS/macOS Implementation

#if !os(tvOS)
/// ROM syncer for iOS/macOS using iCloud Documents
public class RomsSyncer: iCloudContainerSyncer, RomsSyncing {
    /// Initialize a new ROM syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(directories: ["Roms"], notificationCenter: notificationCenter, errorHandler: errorHandler)
    }
    
    /// Get the local URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The local URL for the ROM file
    public func localURL(for game: PVGame) -> URL? {
        guard let file = game.file else {
            return nil
        }
        
        return file.url
    }
    
    /// Get the cloud URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The cloud URL for the ROM file
    public func cloudURL(for game: PVGame) -> URL? {
        guard let file = game.file,
              let url = file.url,
              let containerURL = containerURL?.appendDocumentsDirectory else {
            return nil
        }
        
        let systemPath = (game.systemIdentifier as NSString)
        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
        return containerURL.appendingPathComponent("Roms").appendingPathComponent(systemDir).appendingPathComponent(url.lastPathComponent)
    }
    
    /// Upload a ROM file to the cloud
    /// - Parameter game: The game to upload
    /// - Returns: Completable that completes when the upload is done
    public func uploadROM(for game: PVGame) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self,
                  let localURL = self.localURL(for: game),
                  let cloudURL = self.cloudURL(for: game) else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ROM file or URLs"])))
                return Disposables.create()
            }
            
            // Create directory if needed
            let cloudDir = cloudURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: cloudDir, withIntermediateDirectories: true)
                
                // Copy file to iCloud
                if FileManager.default.fileExists(atPath: cloudURL.path) {
                    try FileManager.default.removeItem(at: cloudURL)
                }
                
                try FileManager.default.copyItem(at: localURL, to: cloudURL)
                self.insertUploadedFile(cloudURL)
                
                DLOG("Uploaded ROM file to iCloud: \(cloudURL.lastPathComponent)")
                observer(.completed)
            } catch {
                ELOG("Failed to upload ROM file: \(error.localizedDescription)")
                observer(.error(error))
            }
            
            return Disposables.create()
        }
    }
    
    /// Download a ROM file from the cloud
    /// - Parameter game: The game to download
    /// - Returns: Completable that completes when the download is done
    public func downloadROM(for game: PVGame) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self,
                  let cloudURL = self.cloudURL(for: game) else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ROM file or URLs"])))
                return Disposables.create()
            }
            
            // Check if file exists in iCloud
            if !FileManager.default.fileExists(atPath: cloudURL.path) {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "ROM file not found in iCloud"])))
                return Disposables.create()
            }
            
            // Start downloading
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
                self.insertDownloadingFile(cloudURL)
                
                // Wait for download to complete
                let checkDownload = Observable<Int>.interval(.seconds(1), scheduler: MainScheduler.instance)
                    .take(60) // Timeout after 60 seconds
                    .flatMap { _ -> Observable<Bool> in
                        let downloadingStatus = try? cloudURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                        let isDownloaded = downloadingStatus?.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current
                        return Observable.just(isDownloaded)
                    }
                    .filter { $0 }
                    .take(1)
                    .timeout(.seconds(60), scheduler: MainScheduler.instance)
                
                return checkDownload
                    .subscribe(onNext: { _ in
                        self.insertDownloadedFile(cloudURL)
                        DLOG("Downloaded ROM file from iCloud: \(cloudURL.lastPathComponent)")
                        observer(.completed)
                    }, onError: { error in
                        ELOG("Failed to download ROM file: \(error.localizedDescription)")
                        observer(.error(error))
                    })
            } catch {
                ELOG("Failed to start downloading ROM file: \(error.localizedDescription)")
                observer(.error(error))
            }
            
            return Disposables.create()
        }
    }
}
#endif

// MARK: - tvOS Implementation

#if os(tvOS)
/// ROM syncer for tvOS using CloudKit
public class CloudKitRomsSyncer: CloudKitSyncer, RomsSyncing {
    /// Initialize a new ROM syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(directories: ["Roms"], notificationCenter: notificationCenter, errorHandler: errorHandler)
    }
    
    /// Get the local URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The local URL for the ROM file
    public func localURL(for game: PVGame) -> URL? {
        guard let file = game.file else {
            return nil
        }
        
        return file.url
    }
    
    /// Get the cloud URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The cloud URL for the ROM file (this is a virtual path for CloudKit)
    public func cloudURL(for game: PVGame) -> URL? {
        guard let file = game.file,
              let url = file.url else {
            return nil
        }
        
        // For CloudKit, we create a virtual path that represents the record
        let systemPath = (game.systemIdentifier as NSString)
        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
        
        // Create a URL with a custom scheme to represent CloudKit records
        // This is just for internal tracking, not an actual file URL
        var components = URLComponents()
        components.scheme = "cloudkit"
        components.host = "roms"
        components.path = "/\(systemDir)/\(url.lastPathComponent)"
        
        return components.url
    }
    
    /// Upload a ROM file to CloudKit
    /// - Parameter game: The game to upload
    /// - Returns: Completable that completes when the upload is done
    public func uploadROM(for game: PVGame) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self,
                  let localURL = self.localURL(for: game) else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ROM file"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Upload the file to CloudKit
                    let systemPath = (game.systemIdentifier as NSString)
                    let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
                    
                    // Create a record for the ROM file
                    let recordID = CKRecord.ID(recordName: "rom_\(systemDir)_\(localURL.lastPathComponent)")
                    let record = CKRecord(recordType: "File", recordID: recordID)
                    record["directory"] = "Roms"
                    record["system"] = systemDir
                    record["filename"] = localURL.lastPathComponent
                    record["fileData"] = CKAsset(fileURL: localURL)
                    record["lastModified"] = Date()
                    record["md5"] = game.md5Hash
                    
                    // Save the record to CloudKit
                    _ = try await self.uploadFile(localURL)
                    self.insertUploadedFile(localURL)
                    
                    DLOG("Uploaded ROM file to CloudKit: \(localURL.lastPathComponent)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to upload ROM file to CloudKit: \(error.localizedDescription)")
                    self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// Download a ROM file from CloudKit
    /// - Parameter game: The game to download
    /// - Returns: Completable that completes when the download is done
    public func downloadROM(for game: PVGame) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ROM syncer"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Find the record for this ROM
                    let systemPath = (game.systemIdentifier as NSString)
                    let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
                    let filename = game.file?.fileName ?? game.title
                    
                    // Create query
                    let predicate = NSPredicate(format: "directory == %@ AND system == %@ AND filename == %@", "Roms", systemDir, filename)
                    let query = CKQuery(recordType: "File", predicate: predicate)
                    
                    // Execute query
                    let privateDatabase = self.container.privateCloudDatabase
                    let (results, _) = try await privateDatabase.records(matching: query)
                    let records = results.compactMap { _, result in
                        try? result.get()
                    }
                    
                    guard let record = records.first,
                          let asset = record["fileData"] as? CKAsset,
                          let fileURL = asset.fileURL else {
                        throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "ROM file not found in CloudKit"])
                    }
                    
                    // Create local file path
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let directoryURL = documentsURL.appendingPathComponent("Roms").appendingPathComponent(systemDir)
                    let destinationURL = directoryURL.appendingPathComponent(filename)
                    
                    // Create directory if needed
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                    
                    // Copy file from asset to local storage
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try await FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                    self.insertDownloadedFile(destinationURL)
                    
                    // Update game's file reference if needed
                    if game.file == nil {
                        try await MainActor.run {
                            let realm = try Realm()
                            try realm.write {
                                let file = PVFile(withURL: destinationURL, relativeRoot: .documents)
                                game.file = file
                            }
                        }
                    }
                    
                    DLOG("Downloaded ROM file from CloudKit: \(filename)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to download ROM file from CloudKit: \(error.localizedDescription)")
                    self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
}
#endif
