//
//  BIOSSyncer.swift
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
import CloudKit
import CryptoKit

/// Protocol for BIOS-specific sync operations
public protocol BIOSSyncing: SyncProvider {
    /// Get the local URL for a BIOS file
    /// - Parameter filename: The BIOS filename
    /// - Returns: The local URL for the BIOS file
    func localURL(for filename: String) -> URL?
    
    /// Get the cloud URL for a BIOS file
    /// - Parameter filename: The BIOS filename
    /// - Returns: The cloud URL for the BIOS file
    func cloudURL(for filename: String) -> URL?
    
    /// Upload a BIOS file to the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: Completable that completes when the upload is done
    func uploadBIOS(filename: String) -> Completable
    
    /// Download a BIOS file from the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: Completable that completes when the download is done
    func downloadBIOS(filename: String) -> Completable
    
    /// Check if a BIOS file exists locally
    /// - Parameter filename: The BIOS filename
    /// - Returns: True if the BIOS file exists locally
    func biosExists(filename: String) -> Bool
    
    /// Check if a BIOS file exists in the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: True if the BIOS file exists in the cloud
    func biosExistsInCloud(filename: String) -> Bool
}

// MARK: - iOS/macOS Implementation

#if !os(tvOS)
/// BIOS syncer for iOS/macOS using iCloud Documents
public class BIOSSyncer: iCloudContainerSyncer, BIOSSyncing {
    /// Initialize a new BIOS syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(directories: ["BIOS"], notificationCenter: notificationCenter, errorHandler: errorHandler)
    }
    
    /// Get the local URL for a BIOS file
    /// - Parameter filename: The BIOS filename
    /// - Returns: The local URL for the BIOS file
    public func localURL(for filename: String) -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsURL.appendingPathComponent("BIOS").appendingPathComponent(filename)
    }
    
    /// Get the cloud URL for a BIOS file
    /// - Parameter filename: The BIOS filename
    /// - Returns: The cloud URL for the BIOS file
    public func cloudURL(for filename: String) -> URL? {
        guard let containerURL = documentsURL else {
            return nil
        }
        
        return containerURL.appendingPathComponent("BIOS").appendingPathComponent(filename)
    }
    
    /// Upload a BIOS file to the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: Completable that completes when the upload is done
    public func uploadBIOS(filename: String) -> Completable {
        return Completable.create { [weak self] observer in
            Task {
                guard let self = self,
                      let localURL = self.localURL(for: filename),
                      let cloudURL = self.cloudURL(for: filename) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid BIOS file or URLs"])))
                    return
                }
                
                // Check if file exists locally
                guard FileManager.default.fileExists(atPath: localURL.path) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "BIOS file not found locally"])))
                    return
                }
                
                // Create directory if needed
                let cloudDir = cloudURL.deletingLastPathComponent()
                do {
                    try FileManager.default.createDirectory(at: cloudDir, withIntermediateDirectories: true)
                    
                    // Copy file to iCloud
                    if FileManager.default.fileExists(atPath: cloudURL.path) {
                        try await FileManager.default.removeItem(at: cloudURL)
                    }
                    
                    try FileManager.default.copyItem(at: localURL, to: cloudURL)
                    await self.insertUploadedFile(cloudURL)
                    
                    DLOG("Uploaded BIOS to iCloud: \(filename)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to upload BIOS: \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
    }
    
    /// Download a BIOS file from the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: Completable that completes when the download is done
    public func downloadBIOS(filename: String) -> Completable {
        return Completable.create { [weak self] observer in
            Task {
                guard let self = self,
                      let cloudURL = self.cloudURL(for: filename),
                      let localURL = self.localURL(for: filename) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid BIOS file or URLs"])))
                    return
                }
                
                // Check if file exists in iCloud
                if !FileManager.default.fileExists(atPath: cloudURL.path) {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "BIOS not found in iCloud"])))
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
                                do {
                                    // Create directory if needed
                                    let localDir = localURL.deletingLastPathComponent()
                                    try FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
                                    
                                    // Copy file to local storage
                                    if FileManager.default.fileExists(atPath: localURL.path) {
                                        await try FileManager.default.removeItem(at: localURL)
                                    }
                                    
                                    try FileManager.default.copyItem(at: cloudURL, to: localURL)
                                    await self.insertDownloadedFile(cloudURL)
                                    
                                    DLOG("Downloaded BIOS from iCloud: \(filename)")
                                    observer(.completed)
                                } catch {
                                    ELOG("Failed to copy BIOS to local storage: \(error.localizedDescription)")
                                    observer(.error(error))
                                }
                            }
                        }, onError: { error in
                            ELOG("Failed to download BIOS: \(error.localizedDescription)")
                            observer(.error(error))
                        })
                } catch {
                    ELOG("Failed to start downloading BIOS: \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
    }
    
    /// Check if a BIOS file exists locally
    /// - Parameter filename: The BIOS filename
    /// - Returns: True if the BIOS file exists locally
    public func biosExists(filename: String) -> Bool {
        guard let localURL = localURL(for: filename) else {
            return false
        }
        
        return FileManager.default.fileExists(atPath: localURL.path)
    }
    
    /// Check if a BIOS file exists in the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: True if the BIOS file exists in the cloud
    public func biosExistsInCloud(filename: String) -> Bool {
        guard let cloudURL = cloudURL(for: filename) else {
            return false
        }
        
        return FileManager.default.fileExists(atPath: cloudURL.path)
    }
}
#endif

// MARK: - tvOS Implementation

/// BIOS syncer for tvOS using CloudKit
public class CloudKitBIOSSyncer: CloudKitSyncer, BIOSSyncing {
    /// The CloudKit record type for BIOS files
    override internal var recordType: String {
        return "BIOS"
    }
    /// Initialize a new BIOS syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(directories: ["BIOS"], notificationCenter: notificationCenter, errorHandler: errorHandler)
    }
    
    /// Get the local URL for a BIOS file
    /// - Parameter filename: The BIOS filename
    /// - Returns: The local URL for the BIOS file
    public func localURL(for filename: String) -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsURL.appendingPathComponent("BIOS").appendingPathComponent(filename)
    }
    
    /// Get the cloud URL for a BIOS file
    /// - Parameter filename: The BIOS filename
    /// - Returns: The cloud URL for the BIOS file (this is a virtual path for CloudKit)
    public func cloudURL(for filename: String) -> URL? {
        // For CloudKit, we create a virtual path that represents the record
        // This is just for internal tracking, not an actual file URL
        var components = URLComponents()
        components.scheme = "cloudkit"
        components.host = "bios"
        components.path = "/\(filename)"
        
        return components.url
    }
    
    /// Upload a BIOS file to CloudKit
    /// - Parameter filename: The BIOS filename
    /// - Returns: Completable that completes when the upload is done
    public func uploadBIOS(filename: String) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self,
                  let localURL = self.localURL(for: filename) else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid BIOS file"])))
                return Disposables.create()
            }
            
            // Check if file exists locally
            guard FileManager.default.fileExists(atPath: localURL.path) else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "BIOS file not found locally"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Upload the file to CloudKit
                    // Create a record for the BIOS file
                    let recordID = CKRecord.ID(recordName: "bios_\(filename)")
                    let record = CKRecord(recordType: "File", recordID: recordID)
                    record["directory"] = "BIOS"
                    record["filename"] = filename
                    record["fileData"] = CKAsset(fileURL: localURL)
                    record["lastModified"] = Date()
                    
                    // Calculate MD5 hash if possible
                    if let data = try? Data(contentsOf: localURL) {
                        // Calculate MD5 hash using CryptoKit
                        let md5 = Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
                        record["md5"] = md5
                    }
                    
                    // Save the record to CloudKit
                    _ = try await self.uploadFile(localURL)
                    await self.insertUploadedFile(localURL)
                    
                    DLOG("Uploaded BIOS to CloudKit: \(filename)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to upload BIOS to CloudKit: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// Download a BIOS file from CloudKit
    /// - Parameter filename: The BIOS filename
    /// - Returns: Completable that completes when the download is done
    public func downloadBIOS(filename: String) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid BIOS syncer"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Find the record for this BIOS file
                    let recordID = CKRecord.ID(recordName: "bios_\(filename)")
                    let privateDatabase = self.container.privateCloudDatabase
                    
                    do {
                        let record = try await privateDatabase.record(for: recordID)
                        
                        guard let asset = record["fileData"] as? CKAsset,
                              let fileURL = asset.fileURL else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "BIOS file not found in CloudKit"])
                        }
                        
                        // Get filename
                        guard let filename = record["filename"] as? String else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid BIOS record data"])
                        }
                        
                        // Create local file path
                        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let directoryURL = documentsURL.appendingPathComponent("BIOS")
                        let destinationURL = directoryURL.appendingPathComponent(filename)
                        
                        // Create directory if needed
                        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                        
                        // Copy file from asset to local storage
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try await FileManager.default.removeItem(at: destinationURL)
                        }
                        
                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                        await self.insertDownloadedFile(destinationURL)
                        
                        DLOG("Downloaded BIOS from CloudKit: \(filename)")
                        observer(.completed)
                    } catch {
                        // If record not found by ID, try searching by filename
                        // Create query
                        let predicate = NSPredicate(format: "directory == %@ AND filename == %@", "BIOS", filename)
                        let query = CKQuery(recordType: "File", predicate: predicate)
                        
                        // Execute query
                        let (results, _) = try await privateDatabase.records(matching: query)
                        let records = results.compactMap { _, result in
                            try? result.get()
                        }
                        
                        guard let record = records.first,
                              let asset = record["fileData"] as? CKAsset,
                              let fileURL = asset.fileURL else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "BIOS file not found in CloudKit"])
                        }
                        
                        // Create local file path
                        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let directoryURL = documentsURL.appendingPathComponent("BIOS")
                        let destinationURL = directoryURL.appendingPathComponent(filename)
                        
                        // Create directory if needed
                        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                        
                        // Copy file from asset to local storage
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try await FileManager.default.removeItem(at: destinationURL)
                        }
                        
                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                        await self.insertDownloadedFile(destinationURL)
                        
                        DLOG("Downloaded BIOS from CloudKit: \(filename)")
                        observer(.completed)
                    }
                } catch {
                    ELOG("Failed to download BIOS from CloudKit: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// Check if a BIOS file exists locally
    /// - Parameter filename: The BIOS filename
    /// - Returns: True if the BIOS file exists locally
    public func biosExists(filename: String) -> Bool {
        guard let localURL = localURL(for: filename) else {
            return false
        }
        
        return FileManager.default.fileExists(atPath: localURL.path)
    }
    
    /// Check if a BIOS file exists in the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: True if the BIOS file exists in the cloud
    public func biosExistsInCloud(filename: String) -> Bool {
        // This requires a CloudKit query, so we can't do it synchronously
        // Instead, we'll just return false and let the sync process handle it
        return false
    }
}
