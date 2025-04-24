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
        super.init(directories: ["ROMs"], notificationCenter: notificationCenter, errorHandler: errorHandler)
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
              let containerURL = documentsURL else {
            return nil
        }
        
        let systemPath = (game.systemIdentifier as NSString)
        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
        return containerURL.appendingPathComponent("ROMs").appendingPathComponent(systemDir).appendingPathComponent(url.lastPathComponent)
    }
    
    /// Upload a ROM file to the cloud
    /// - Parameter game: The game to upload
    /// - Returns: Completable that completes when the upload is done
    public func uploadROM(for game: PVGame) -> Completable {
        return Completable.create { [weak self] observer in
            Task {
                guard let self = self,
                      let localURL = self.localURL(for: game),
                      let cloudURL = self.cloudURL(for: game) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ROM file or URLs"])))
                    return
                }
                
                // Create directory if needed
                let cloudDir = cloudURL.deletingLastPathComponent()
                do {
                    try FileManager.default.createDirectory(at: cloudDir, withIntermediateDirectories: true)
                    
                    // Copy file to iCloud
                    if FileManager.default.fileExists(atPath: cloudURL.path) {
                        await try FileManager.default.removeItem(at: cloudURL)
                    }
                    
                    try FileManager.default.copyItem(at: localURL, to: cloudURL)
                    await self.insertUploadedFile(cloudURL)
                    
                    DLOG("Uploaded ROM file to iCloud: \(cloudURL.lastPathComponent)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to upload ROM file: \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
    }
    
    /// Download a ROM file from the cloud
    /// - Parameter game: The game to download
    /// - Returns: Completable that completes when the download is done
    public func downloadROM(for game: PVGame) -> Completable {
        return Completable.create { [weak self] observer in
            Task {
                guard let self = self,
                      let cloudURL = self.cloudURL(for: game) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ROM file or URLs"])))
                    return
                }
                
                // Check if file exists in iCloud
                if !FileManager.default.fileExists(atPath: cloudURL.path) {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "ROM file not found in iCloud"])))
                    return
                }
                
                // Start downloading
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
                    await self.insertDownloadingFile(cloudURL)
                    
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
                    //TODO: this needs to be refactored, but can't think of a quick way right now to make the async functions to work
                    checkDownload
                        .subscribe(onNext: { _ in
                            Task {
                                await self.insertDownloadedFile(cloudURL)
                                DLOG("Downloaded ROM file from iCloud: \(cloudURL.lastPathComponent)")
                                observer(.completed)
                            }
                        }, onError: { error in
                            ELOG("Failed to download ROM file: \(error.localizedDescription)")
                            observer(.error(error))
                        })
                } catch {
                    ELOG("Failed to start downloading ROM file: \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
    }
}
#endif

// MARK: - tvOS Implementation

/// ROM syncer for tvOS using CloudKit
public class CloudKitRomsSyncer: CloudKitSyncer, RomsSyncing {
    
    /// Get all CloudKit records for ROMs
    /// - Returns: Array of CKRecord objects
    public func getAllRecords() async -> [CKRecord] {
        do {
            // Create a query for all ROM records
            let query = CKQuery(recordType: CloudKitSchema.RecordType.rom, predicate: NSPredicate(value: true))
            
            // Execute the query
            let (records, _) = try await privateDatabase.records(matching: query, resultsLimit: 100)
            
            // Convert to array of CKRecord
            let recordsArray = records.compactMap { _, result -> CKRecord? in
                switch result {
                case .success(let record):
                    return record
                case .failure(let error):
                    ELOG("Error fetching ROM record: \(error.localizedDescription)")
                    return nil
                }
            }
            
            DLOG("Fetched \(recordsArray.count) ROM records from CloudKit")
            return recordsArray
        } catch {
            ELOG("Failed to fetch ROM records: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Check if a file is downloaded locally
    /// - Parameters:
    ///   - filename: The filename to check
    ///   - system: The system identifier
    /// - Returns: True if the file is downloaded locally
    public func isFileDownloaded(filename: String, inSystem system: String) async -> Bool {
        // Create local file path
        let documentsURL = URL.documentsPath
        let directoryURL = documentsURL.appendingPathComponent("ROMs").appendingPathComponent(system)
        let fileURL = directoryURL.appendingPathComponent(filename)
        
        // Check if file exists
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Update a game with its CloudKit record ID
    /// - Parameters:
    ///   - game: The game to update
    ///   - recordID: The CloudKit record ID
    /// - Throws: Error if the update fails
    private func updateGameWithCloudRecordID(_ game: PVGame, recordID: String) async throws {
        // Using MainActor to ensure we're on the main thread for Realm operations
        try await MainActor.run {
            let realm = try Realm()
            try realm.write {
                game.cloudRecordID = recordID
                game.isDownloaded = true
            }
        }
        
        DLOG("Updated game \(game.title) with CloudKit record ID: \(recordID)")
    }
    
    /// Upload a ROM file to the cloud
    /// - Parameter game: The game to upload
    /// - Returns: Completable that completes when the upload is done
    public func uploadROM(for game: PVGame) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "ROM syncer deallocated"])))
                return Disposables.create()
            }
            
            guard let localURL = self.localURL(for: game) else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "ROM file not found"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Get system directory
                    let systemPath = (game.systemIdentifier as NSString)
                    let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
                    
                    // Create a record for the ROM file
                    let recordID = CKRecord.ID(recordName: "rom_\(systemDir)_\(localURL.lastPathComponent)")
                    let record = CKRecord(recordType: "File", recordID: recordID)
                    record["directory"] = "ROMs"
                    record["system"] = systemDir
                    record["filename"] = localURL.lastPathComponent
                    record["fileData"] = CKAsset(fileURL: localURL)
                    
                    // Add metadata
                    record["title"] = game.title
                    record["md5"] = game.md5Hash
                    
                    // Save the record
                    try await self.privateDatabase.save(record)
                    
                    // Update game with cloud record ID
                    try await self.updateGameWithCloudRecordID(game, recordID: recordID.recordName)
                    
                    observer(.completed)
                } catch {
                    ELOG("Failed to upload ROM file: \(error.localizedDescription)")
                    observer(.error(error))
                }
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
                  let recordID = game.cloudRecordID else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid parameters or missing cloud record ID"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Download the file using the existing method
                    let fileURL = try await self.downloadFileOnDemand(recordName: recordID)
                    
                    // Update game with downloaded status
                    // Using MainActor to ensure we're on the main thread for Realm operations
                    try await MainActor.run {
                        let realm = try Realm()
                        try realm.write {
                            game.isDownloaded = true
                        }
                    }
                    
                    DLOG("Downloaded ROM file: \(fileURL.lastPathComponent)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to download ROM file: \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    /// The CloudKit record type for ROMs
    override public var recordType: String {
        return "ROM"
    }
    /// Initialize a new ROM syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(directories: ["ROMs"], notificationCenter: notificationCenter, errorHandler: errorHandler)
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
}
