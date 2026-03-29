//
//  iCloudDriveBIOSSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import RxSwift
import PVPrimitives
import PVSystems
import PVFileSystem
import PVRealm
import RealmSwift
import CloudKit
import CryptoKit

// MARK: - iOS/macOS Implementation

#if !os(tvOS)
/// BIOS syncer for iOS/macOS using iCloud Documents.
///
/// Also implements `SystemFileSyncing` so that per-console `System/<name>/`
/// directories are included in the iCloud metadata query and can be uploaded
/// and downloaded just like BIOS files.  The combined monitoring is achieved
/// by passing both `"BIOS"` and `"System"` to `iCloudContainerSyncer.init`.
///
/// Part of Epic #3577 — System directory infrastructure.
public class iCloudDriveBIOSSyncer: iCloudContainerSyncer, BIOSSyncing, SystemFileSyncing {
    /// Initialize a new BIOS syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(directories: ["BIOS", "System"], notificationCenter: notificationCenter, errorHandler: errorHandler)
    }

    /// Get the local URL for a BIOS file
    /// - Parameter filename: The BIOS filename or relative path (systemID/filename)
    /// - Returns: The local URL for the BIOS file
    public func localURL(for filename: String) -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        // Check if the filename contains a path separator
        if filename.contains("/") {
            // Split the path into components
            let components = filename.components(separatedBy: "/")

            // If we have a valid system ID and filename
            if components.count >= 2 {
                let systemID = components[0]
                let actualFilename = components[1]

                // Return the URL with the system subdirectory
                return documentsURL.appendingPathComponent("BIOS")
                    .appendingPathComponent(systemID)
                    .appendingPathComponent(actualFilename)
            }
        }

        // Fallback to the old behavior for backward compatibility
        return documentsURL.appendingPathComponent("BIOS").appendingPathComponent(filename)
    }

    /// Get the cloud URL for a BIOS file
    /// - Parameter filename: The BIOS filename or relative path (systemID/filename)
    /// - Returns: The cloud URL for the BIOS file
    public func cloudURL(for filename: String) -> URL? {
        guard let containerURL = documentsURL else {
            return nil
        }

        // Check if the filename contains a path separator
        if filename.contains("/") {
            // Split the path into components
            let components = filename.components(separatedBy: "/")

            // If we have a valid system ID and filename
            if components.count >= 2 {
                let systemID = components[0]
                let actualFilename = components[1]

                // Return the URL with the system subdirectory
                return containerURL.appendingPathComponent("BIOS")
                    .appendingPathComponent(systemID)
                    .appendingPathComponent(actualFilename)
            }
        }

        // Fallback to the old behavior for backward compatibility
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
                                        try await FileManager.default.removeItem(at: localURL)
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

    // MARK: - SystemFileSyncing

    /// Returns the on-device URL for a file in `System/<name>/<filename>`.
    public func localSystemURL(forSystem system: SystemIdentifier, filename: String) -> URL? {
        guard let name = system.systemDirectoryName else { return nil }
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL
            .appendingPathComponent("System")
            .appendingPathComponent(name)
            .appendingPathComponent(filename)
    }

    /// Returns the iCloud URL for a file in `System/<name>/<filename>`.
    public func cloudSystemURL(forSystem system: SystemIdentifier, filename: String) -> URL? {
        guard let name = system.systemDirectoryName else { return nil }
        guard let containerURL = documentsURL else { return nil }
        return containerURL
            .appendingPathComponent("System")
            .appendingPathComponent(name)
            .appendingPathComponent(filename)
    }

    /// Upload a file from `System/<name>/<filename>` to iCloud.
    public func uploadSystemFile(system: SystemIdentifier, filename: String) -> Completable {
        return Completable.create { [weak self] observer in
            Task {
                guard let self = self,
                      let localURL = self.localSystemURL(forSystem: system, filename: filename),
                      let cloudURL = self.cloudSystemURL(forSystem: system, filename: filename) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1,
                                           userInfo: [NSLocalizedDescriptionKey: "Invalid system file or URLs"])))
                    return
                }

                guard FileManager.default.fileExists(atPath: localURL.path) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 2,
                                           userInfo: [NSLocalizedDescriptionKey: "System file not found locally: \(filename)"])))
                    return
                }

                do {
                    let cloudDir = cloudURL.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: cloudDir, withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: cloudURL.path) {
                        try await FileManager.default.removeItem(at: cloudURL)
                    }
                    try FileManager.default.copyItem(at: localURL, to: cloudURL)
                    await self.insertUploadedFile(cloudURL)
                    DLOG("Uploaded system file to iCloud: System/\(system.systemDirectoryName ?? "?")/\(filename)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to upload system file \(filename): \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
    }

    /// Download a file from iCloud into `System/<name>/<filename>`.
    public func downloadSystemFile(system: SystemIdentifier, filename: String) -> Completable {
        return Completable.create { [weak self] observer in
            Task {
                guard let self = self,
                      let cloudURL = self.cloudSystemURL(forSystem: system, filename: filename),
                      let localURL = self.localSystemURL(forSystem: system, filename: filename) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1,
                                           userInfo: [NSLocalizedDescriptionKey: "Invalid system file or URLs"])))
                    return
                }

                guard FileManager.default.fileExists(atPath: cloudURL.path) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 2,
                                           userInfo: [NSLocalizedDescriptionKey: "System file not found in iCloud: \(filename)"])))
                    return
                }

                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
                    await self.insertDownloadingFile(cloudURL)

                    // Poll until the ubiquitous item is fully downloaded (timeout: 60 s)
                    var isDownloaded = false
                    for _ in 0..<60 {
                        if let values = try? cloudURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
                           values.ubiquitousItemDownloadingStatus == .current {
                            isDownloaded = true
                            break
                        }
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    guard isDownloaded else {
                        observer(.error(NSError(
                            domain: "com.provenance-emu.provenance", code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "iCloud download timed out for system file: \(filename)"]
                        )))
                        return
                    }

                    let localDir = localURL.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        try await FileManager.default.removeItem(at: localURL)
                    }
                    try FileManager.default.copyItem(at: cloudURL, to: localURL)
                    await self.insertDownloadedFile(cloudURL)
                    DLOG("Downloaded system file from iCloud: System/\(system.systemDirectoryName ?? "?")/\(filename)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to download system file \(filename): \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
    }

    /// Returns `true` when `System/<name>/<filename>` exists on device.
    public func systemFileExists(system: SystemIdentifier, filename: String) -> Bool {
        guard let localURL = localSystemURL(forSystem: system, filename: filename) else { return false }
        return FileManager.default.fileExists(atPath: localURL.path)
    }

    /// Returns `true` when `System/<name>/<filename>` exists in iCloud.
    public func systemFileExistsInCloud(system: SystemIdentifier, filename: String) -> Bool {
        guard let cloudURL = cloudSystemURL(forSystem: system, filename: filename) else { return false }
        return FileManager.default.fileExists(atPath: cloudURL.path)
    }
}
#endif

// MARK: - CloudKit Implementation

/// BIOS syncer for all OSs  using CloudKit
public class CloudKitBIOSSyncer: CloudKitSyncer, BIOSSyncing {

    /// System subdirectory short names that contain user-placed firmware requiring CloudKit backup.
    ///
    /// Only user-placed firmware is synced — bundle-seeded assets (e.g. PPSSPP flash0 fonts) are
    /// excluded because they are automatically re-seeded from the app bundle on every core launch.
    ///
    /// Directory layout: `System/<name>/…` (e.g. `System/PSP/`, `System/DC/`)
    public static let systemDirectoriesToSync: Set<String> = ["PSP", "DC", "AtariST", "Saturn"]

    /// Initialize a new BIOS syncer
    /// - Parameters:
    ///   - directories: Directories to manage (defaults to ["BIOS", "System"])
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public override init(container: CKContainer, directories: Set<String> = ["BIOS", "System"], notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(container: container, directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
    }

    /// Get all CloudKit records for BIOS files
    /// - Returns: Array of CKRecord objects
    public func getAllRecords() async -> [CKRecord] {
        do {
            // Create a query for all BIOS records
            let query = CKQuery(recordType: CloudKitSchema.RecordType.bios.rawValue, predicate: NSPredicate(value: true))

            // Execute the query
            let (records, _) = try await privateDatabase.records(matching: query, resultsLimit: 100)

            // Convert to array of CKRecord
            let recordsArray = records.compactMap { _, result -> CKRecord? in
                switch result {
                case .success(let record):
                    return record
                case .failure(let error):
                    ELOG("Error fetching BIOS record: \(error.localizedDescription)")
                    return nil
                }
            }

            DLOG("Fetched \(recordsArray.count) BIOS records from CloudKit")
            return recordsArray
        } catch {
            ELOG("Failed to fetch BIOS records: \(error.localizedDescription)")
            return []
        }
    }

    /// Check if a file is downloaded locally
    /// - Parameters:
    ///   - filename: The filename to check
    /// - Returns: True if the file is downloaded locally
    public func isFileDownloaded(filename: String) async -> Bool {
        // Create local file path
        let documentsURL = URL.documentsPath
        let directoryURL = documentsURL.appendingPathComponent("BIOS")
        let fileURL = directoryURL.appendingPathComponent(filename)
        DLOG("Checking file: \(fileURL.path) for filename \(filename)")

        // Check if file exists
        let exists = FileManager.default.fileExists(atPath: fileURL.path)

        if !exists {
            DLOG("File does not exist: \(fileURL.path)")
        }

        return exists
    }
    /// The CloudKit record type for BIOS files
    override public var recordType: String {
        return "BIOS"
    }
    /// Initialize a new BIOS syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(container: CKContainer, notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(container: container, directories: ["BIOS", "System"], notificationCenter: notificationCenter, errorHandler: errorHandler)
    }

    /// Get the local URL for a BIOS file
    /// - Parameter filename: The BIOS filename
    /// - Returns: The local URL for the BIOS file
    public func localURL(for filename: String) -> URL? {
        let documentsURL = URL.documentsPath
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

                    // Extract systemID from parent directory
                    let parentDirectoryName = localURL.deletingLastPathComponent().lastPathComponent
                    let systemID = SystemIdentifier(rawValue: parentDirectoryName)

                    // Save the record to CloudKit
                    _ = try await self.uploadFile(localURL, gameID: nil, systemID: systemID)
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
                        let documentsURL = URL.documentsPath

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
                        let documentsURL = URL.documentsPath

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

    // MARK: - Metadata Sync

    /// Fetch all BIOS records from CloudKit (with pagination and timeout)
    /// - Returns: Array of CKRecord objects
    public func fetchAllBIOSRecords() async -> [CKRecord] {
        ILOG("[SYNC] Fetching all BIOS records from CloudKit...")
        var allRecords: [CKRecord] = []

        // Query both record types since BIOS files may be stored as either:
        // 1. "File" type with directory="BIOS" (from uploadBIOS or legacy code)
        // 2. "BIOS" type (from uploadFile via CloudKitInitialSyncer)
        let recordTypes = ["File", "BIOS"]

        for recordType in recordTypes {
            do {
                let predicate: NSPredicate
                if recordType == "File" {
                    predicate = NSPredicate(format: "directory == %@", "BIOS")
                } else {
                    predicate = NSPredicate(value: true) // All BIOS records
                }
                let query = CKQuery(recordType: recordType, predicate: predicate)

                DLOG("[BIOS FETCH] Starting query for recordType: \(recordType)")

                var cursor: CKQueryOperation.Cursor? = nil
                repeat {
                    // Add timeout to prevent indefinite hanging
                    let fetchTask = Task {
                        if let currentCursor = cursor {
                            return try await privateDatabase.records(continuingMatchFrom: currentCursor)
                        } else {
                            return try await privateDatabase.records(matching: query, resultsLimit: 200)
                        }
                    }

                    let timeoutTask = Task {
                        try await Task.sleep(nanoseconds: 30_000_000_000) // 30 second timeout
                        fetchTask.cancel()
                    }

                    let (results, nextCursor): ([(CKRecord.ID, Result<CKRecord, Error>)], CKQueryOperation.Cursor?)
                    do {
                        (results, nextCursor) = try await fetchTask.value
                        timeoutTask.cancel()
                    } catch is CancellationError {
                        WLOG("[BIOS FETCH] CloudKit query timed out for recordType: \(recordType)")
                        timeoutTask.cancel()
                        break
                    }

                    let records = results.compactMap { id, result -> CKRecord? in
                        switch result {
                        case .success(let record):
                            let filename = record["filename"] as? String ?? "unknown"
                            let hasAsset = record["fileData"] as? CKAsset != nil
                            DLOG("[BIOS FETCH] Found record: \(id.recordName), filename: \(filename), hasAsset: \(hasAsset)")
                            return record
                        case .failure(let error):
                            WLOG("[BIOS FETCH] Failed to fetch record \(id.recordName): \(error.localizedDescription)")
                            return nil
                        }
                    }
                    allRecords.append(contentsOf: records)
                    cursor = nextCursor
                    ILOG("[BIOS FETCH] Fetched batch of \(records.count) \(recordType) records, total: \(allRecords.count)")
                } while cursor != nil
            } catch let error as CKError where error.code == .unknownItem {
                // Record type might not exist yet, that's okay
                DLOG("[SYNC] No \(recordType) records found for BIOS (unknownItem)")
            } catch let error as CKError {
                ELOG("[SYNC] CloudKit error fetching \(recordType) BIOS records: code=\(error.code.rawValue), \(error.localizedDescription)")
            } catch {
                ELOG("[SYNC] Failed to fetch \(recordType) BIOS records: \(error.localizedDescription)")
            }
        }

        ILOG("[SYNC] Fetched \(allRecords.count) total BIOS records from CloudKit")
        return allRecords
    }

    /// Sync BIOS metadata from CloudKit and download missing files
    /// - Returns: Number of BIOS files processed
    @MainActor
    public func syncMetadataOnly() async -> Int {
        ILOG("[SYNC] Starting BIOS metadata sync...")
        DLOG("[SYNC] Container: \(container.containerIdentifier ?? "nil"), database: \(privateDatabase)")

        // Run fetch off main actor to avoid potential deadlocks, with overall timeout
        let fetchTask = Task.detached { [self] () -> [CKRecord] in
            await self.fetchAllBIOSRecords()
        }

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 60_000_000_000) // 60 second overall timeout
            fetchTask.cancel()
            WLOG("[SYNC] BIOS metadata fetch timed out after 60 seconds")
        }

        var records: [CKRecord] = []
        do {
            records = try await fetchTask.value
            timeoutTask.cancel()
        } catch is CancellationError {
            WLOG("[SYNC] BIOS metadata fetch was cancelled (timeout)")
            timeoutTask.cancel()
            // Continue anyway - we'll try direct download by predicted IDs
        } catch {
            ELOG("[SYNC] BIOS metadata fetch failed: \(error.localizedDescription)")
            timeoutTask.cancel()
        }
        guard !records.isEmpty else {
            ILOG("[SYNC] No BIOS records found in CloudKit")
            return 0
        }

        var processedCount = 0
        let realm = RomDatabase.sharedInstance.realm

        ILOG("[BIOS META] Processing \(records.count) cloud records...")

        for record in records {
            guard let filename = record["filename"] as? String else {
                WLOG("[BIOS META] BIOS record missing filename, skipping: recordID=\(record.recordID.recordName)")
                continue
            }

            // Log record details
            let hasAsset = record["fileData"] as? CKAsset != nil
            let recordType = record.recordType
            ILOG("[BIOS META] Processing record: filename=\(filename), recordType=\(recordType), recordID=\(record.recordID.recordName), hasAsset=\(hasAsset)")

            // Extract system identifier from directory path or relativePath
            let relativePath = record["relativePath"] as? String ?? filename
            let systemIdentifier = extractSystemIdentifier(from: relativePath)
            DLOG("[BIOS META] Extracted systemIdentifier: \(systemIdentifier ?? "nil"), relativePath: \(relativePath)")

            // Get MD5 if available
            let md5 = record["md5"] as? String ?? ""

            // Check if we have a matching PVBIOS entry
            let matchingBIOS = findMatchingBIOS(filename: filename, md5: md5, in: realm)

            if let bios = matchingBIOS {
                ILOG("[BIOS META] Found matching PVBIOS for \(filename): expectedFilename=\(bios.expectedFilename), expectedMD5=\(bios.expectedMD5)")

                // Update the PVBIOS with cloud info
                do {
                    try realm.write {
                        bios.cloudRecordID = record.recordID.recordName

                        // Check if file exists locally
                        let localPath = self.localPathForBIOS(filename: filename, systemIdentifier: systemIdentifier)
                        let fileExists = FileManager.default.fileExists(atPath: localPath.path)
                        bios.isDownloaded = fileExists

                        ILOG("[BIOS META] Updated BIOS \(filename): cloudRecordID=\(record.recordID.recordName), localPath=\(localPath.path), fileExists=\(fileExists)")

                        // If file exists and we don't have a PVFile, create one
                        if fileExists && bios.file == nil {
                            let pvFile = PVFile()
                            pvFile.partialPath = relativePath
                            bios.file = pvFile
                            ILOG("[BIOS META] Created PVFile for existing BIOS: \(filename)")
                        }
                    }
                    processedCount += 1
                    DLOG("[SYNC] Updated BIOS entry: \(filename), isDownloaded: \(bios.isDownloaded)")
                } catch {
                    ELOG("[SYNC] Failed to update BIOS \(filename): \(error.localizedDescription)")
                }
            } else {
                DLOG("[SYNC] No matching PVBIOS for cloud record: \(filename)")
            }
        }

        ILOG("[SYNC] BIOS metadata sync complete: processed \(processedCount) of \(records.count) records")

        // After metadata sync, trigger download of missing BIOS files
        // Must run on MainActor since downloadMissingBIOSFiles accesses Realm
        Task { @MainActor in
            await self.downloadMissingBIOSFiles()
        }

        // Also sync System/ firmware directories (PSP, DC, AtariST, Saturn).
        // These live in Caches on tvOS and may be purged; CloudKit is their recovery path.
        let systemCount = await syncSystemFiles()
        processedCount += systemCount

        return processedCount
    }

    /// Find a matching PVBIOS entry by filename or MD5
    private func findMatchingBIOS(filename: String, md5: String, in realm: Realm) -> PVBIOS? {
        // First try by exact filename
        if let bios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", filename).first {
            return bios
        }

        // Try by MD5 if available
        if !md5.isEmpty {
            if let bios = realm.objects(PVBIOS.self).filter("expectedMD5 ==[c] %@", md5).first {
                return bios
            }
        }

        // Try by filename without extension (some BIOS might have different extensions)
        let filenameWithoutExt = (filename as NSString).deletingPathExtension
        if let bios = realm.objects(PVBIOS.self).filter("expectedFilename BEGINSWITH %@", filenameWithoutExt).first {
            return bios
        }

        return nil
    }

    /// Extract system identifier from a relative path like "com.provenance.psx/scph1001.bin"
    private func extractSystemIdentifier(from relativePath: String) -> String? {
        let components = relativePath.components(separatedBy: "/")
        if components.count >= 2 {
            return components[0]
        }
        return nil
    }

    /// Get local path for a BIOS file
    private func localPathForBIOS(filename: String, systemIdentifier: String?) -> URL {
        // Use platform-aware BIOS directory (Documents on iOS, Caches on tvOS)
        let biosDir = Paths.biosesPath

        if let sysID = systemIdentifier {
            return biosDir.appendingPathComponent(sysID).appendingPathComponent(filename)
        }
        return biosDir.appendingPathComponent(filename)
    }

    /// Data structure to hold BIOS info extracted from Realm for thread-safe access
    private struct BIOSDownloadInfo {
        let expectedFilename: String
        let expectedMD5: String
        let systemIdentifier: String?
        let cloudRecordID: String?
    }

    /// Download missing BIOS files that have cloud records but no local file
    @MainActor
    public func downloadMissingBIOSFiles() async {
        if CloudSyncManager.shared.isPausedForEmulation {
            ILOG("[BIOS DOWNLOAD] Skipping missing BIOS download scan - paused for emulation")
            return
        }

        ILOG("[BIOS DOWNLOAD] Checking for missing BIOS files to download...")

        // Extract data from Realm into value types for thread-safe access
        let (biosWithCloudRecordsInfo, biosWithoutCloudRecordsInfo) = extractBIOSDownloadInfo()

        ILOG("[BIOS DOWNLOAD] Found \(biosWithCloudRecordsInfo.count) BIOS with cloudRecordID, \(biosWithoutCloudRecordsInfo.count) without")

        // Try to download BIOS files without cloudRecordID by guessing the record ID
        for info in biosWithoutCloudRecordsInfo {
            guard let systemID = info.systemIdentifier else { continue }

            // Try to find the record using predicted ID format: {systemID}_{filename}_{md5prefix}
            let md5Prefix = String(info.expectedMD5.prefix(8)).uppercased()
            let predictedRecordID = "\(systemID)_\(info.expectedFilename)_\(md5Prefix)"
            ILOG("[BIOS DOWNLOAD] Trying predicted recordID for \(info.expectedFilename): \(predictedRecordID)")

            if await tryFetchAndDownloadByInfo(predictedRecordID, info: info) {
                continue // Successfully downloaded
            }

            // Also try without MD5 suffix (simpler format)
            let simpleRecordID = "\(systemID)_\(info.expectedFilename)"
            ILOG("[BIOS DOWNLOAD] Trying simple recordID for \(info.expectedFilename): \(simpleRecordID)")

            if await tryFetchAndDownloadByInfo(simpleRecordID, info: info) {
                continue // Successfully downloaded
            }
        }

        guard !biosWithCloudRecordsInfo.isEmpty else {
            ILOG("[BIOS DOWNLOAD] No missing BIOS files with known cloudRecordID to download")
            return
        }

        ILOG("[BIOS DOWNLOAD] Found \(biosWithCloudRecordsInfo.count) BIOS files with cloudRecordID to download from CloudKit")

        for info in biosWithCloudRecordsInfo {
            guard let recordID = info.cloudRecordID, !recordID.isEmpty else {
                WLOG("[BIOS DOWNLOAD] Skipping BIOS with empty recordID: \(info.expectedFilename)")
                continue
            }

            ILOG("[BIOS DOWNLOAD] Initiating download: filename=\(info.expectedFilename), recordID=\(recordID), systemID=\(info.systemIdentifier ?? "nil")")

            do {
                try await downloadBIOSFromCloudKit(recordID: recordID, filename: info.expectedFilename, systemIdentifier: info.systemIdentifier)
                ILOG("[BIOS DOWNLOAD] Successfully downloaded: \(info.expectedFilename)")
            } catch {
                ELOG("[BIOS DOWNLOAD] Failed to download BIOS \(info.expectedFilename): \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    ELOG("[BIOS DOWNLOAD] CKError code: \(ckError.code.rawValue), description: \(ckError.localizedDescription)")
                }
            }
        }

        ILOG("[BIOS DOWNLOAD] Download phase complete")
    }

    /// Extract BIOS download info from Realm into thread-safe value types
    @MainActor
    private func extractBIOSDownloadInfo() -> (withCloudRecords: [BIOSDownloadInfo], withoutCloudRecords: [BIOSDownloadInfo]) {
        let realm = RomDatabase.sharedInstance.realm

        var withCloudRecords: [BIOSDownloadInfo] = []
        var withoutCloudRecords: [BIOSDownloadInfo] = []

        // BIOS with cloud records but not downloaded
        let biosWithRecords = realm.objects(PVBIOS.self)
            .filter("cloudRecordID != nil AND cloudRecordID != '' AND isDownloaded == false")

        for bios in biosWithRecords {
            let info = BIOSDownloadInfo(
                expectedFilename: bios.expectedFilename,
                expectedMD5: bios.expectedMD5,
                systemIdentifier: bios.system?.identifier,
                cloudRecordID: bios.cloudRecordID
            )
            withCloudRecords.append(info)
        }

        // BIOS without cloud records
        let biosWithoutRecords = realm.objects(PVBIOS.self)
            .filter("(cloudRecordID == nil OR cloudRecordID == '') AND isDownloaded == false")

        for bios in biosWithoutRecords {
            let info = BIOSDownloadInfo(
                expectedFilename: bios.expectedFilename,
                expectedMD5: bios.expectedMD5,
                systemIdentifier: bios.system?.identifier,
                cloudRecordID: nil
            )
            withoutCloudRecords.append(info)
        }

        return (withCloudRecords, withoutCloudRecords)
    }

    /// Try to fetch and download a BIOS by a specific record ID using extracted info
    @MainActor
    private func tryFetchAndDownloadByInfo(_ recordID: String, info: BIOSDownloadInfo) async -> Bool {
        let ckRecordID = CKRecord.ID(recordName: recordID)

        do {
            let fetchTask = Task {
                try await privateDatabase.record(for: ckRecordID)
            }

            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 second timeout
                fetchTask.cancel()
            }

            let record: CKRecord
            do {
                record = try await fetchTask.value
                timeoutTask.cancel()
            } catch is CancellationError {
                timeoutTask.cancel()
                DLOG("[BIOS DOWNLOAD] Fetch timed out for recordID: \(recordID)")
                return false
            }

            guard let asset = record["fileData"] as? CKAsset,
                  let assetURL = asset.fileURL,
                  FileManager.default.fileExists(atPath: assetURL.path) else {
                DLOG("[BIOS DOWNLOAD] Record \(recordID) exists but has no valid asset")
                return false
            }

            ILOG("[BIOS DOWNLOAD] ✓ Found record \(recordID) with valid asset, downloading...")

            let destinationURL = localPathForBIOS(filename: info.expectedFilename, systemIdentifier: info.systemIdentifier)

            let directory = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try await FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: assetURL, to: destinationURL)

            // Update Realm entry by looking up fresh
            let realm = RomDatabase.sharedInstance.realm
            if let bios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", info.expectedFilename).first {
                try realm.write {
                    bios.cloudRecordID = recordID
                    bios.isDownloaded = true

                    if bios.file == nil {
                        let pvFile = PVFile()
                        pvFile.partialPath = info.systemIdentifier != nil ? "BIOS/\(info.systemIdentifier!)/\(info.expectedFilename)" : "BIOS/\(info.expectedFilename)"
                        bios.file = pvFile
                    }
                }
            }

            NotificationCenter.default.post(name: .BIOSFileFound, object: destinationURL)

            ILOG("[BIOS DOWNLOAD] ✓ Successfully downloaded BIOS via predicted recordID: \(info.expectedFilename)")
            return true

        } catch let ckError as CKError where ckError.code == .unknownItem {
            DLOG("[BIOS DOWNLOAD] Record not found for predicted ID: \(recordID)")
            return false
        } catch {
            DLOG("[BIOS DOWNLOAD] Error fetching predicted ID \(recordID): \(error.localizedDescription)")
            return false
        }
    }

    /// Fast targeted BIOS download by record ID (public API for on-demand downloads)
    /// - Parameters:
    ///   - recordID: The CloudKit record ID to try
    ///   - filename: The expected BIOS filename
    ///   - systemIdentifier: The system identifier for subdirectory
    /// - Returns: True if download succeeded
    public func tryDownloadBIOSByRecordID(_ recordID: String, filename: String, systemIdentifier: String) async -> Bool {
        let ckRecordID = CKRecord.ID(recordName: recordID)

        do {
            // Fast fetch with short timeout
            let fetchTask = Task {
                try await privateDatabase.record(for: ckRecordID)
            }

            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
                fetchTask.cancel()
            }

            let record: CKRecord
            do {
                record = try await fetchTask.value
                timeoutTask.cancel()
            } catch is CancellationError {
                timeoutTask.cancel()
                return false
            }

            guard let asset = record["fileData"] as? CKAsset,
                  let assetURL = asset.fileURL,
                  FileManager.default.fileExists(atPath: assetURL.path) else {
                return false
            }

            // Download to local path
            let destinationURL = localPathForBIOS(filename: filename, systemIdentifier: systemIdentifier)
            let directory = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try await FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: assetURL, to: destinationURL)

            // Update Realm
            await MainActor.run {
                let realm = RomDatabase.sharedInstance.realm
                if let bios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", filename).first {
                    try? realm.write {
                        bios.cloudRecordID = recordID
                        bios.isDownloaded = true
                        if bios.file == nil {
                            let pvFile = PVFile()
                            pvFile.partialPath = "BIOS/\(systemIdentifier)/\(filename)"
                            bios.file = pvFile
                        }
                    }
                }
                NotificationCenter.default.post(name: .BIOSFileFound, object: destinationURL)
            }

            return true

        } catch let ckError as CKError where ckError.code == .unknownItem {
            return false
        } catch {
            DLOG("[BIOS FAST] Error downloading by recordID \(recordID): \(error.localizedDescription)")
            return false
        }
    }

    /// Fast targeted BIOS download by filename query
    /// - Parameters:
    ///   - filename: The BIOS filename to search for
    ///   - systemIdentifier: The system identifier for subdirectory
    /// - Returns: True if download succeeded
    public func tryDownloadBIOSByFilename(_ filename: String, systemIdentifier: String) async -> Bool {
        do {
            // Query both record types
            let recordTypes = ["BIOS", "File"]

            for recordType in recordTypes {
                let predicate: NSPredicate
                if recordType == "File" {
                    predicate = NSPredicate(format: "directory == %@ AND filename == %@", "BIOS", filename)
                } else {
                    predicate = NSPredicate(format: "filename == %@", filename)
                }
                let query = CKQuery(recordType: recordType, predicate: predicate)

                // Fast query with timeout
                let fetchTask = Task {
                    try await privateDatabase.records(matching: query, resultsLimit: 1)
                }

                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
                    fetchTask.cancel()
                }

                let results: [(CKRecord.ID, Result<CKRecord, Error>)]
                do {
                    (results, _) = try await fetchTask.value
                    timeoutTask.cancel()
                } catch is CancellationError {
                    timeoutTask.cancel()
                    continue
                }

                guard let firstResult = results.first,
                      case .success(let record) = firstResult.1,
                      let asset = record["fileData"] as? CKAsset,
                      let assetURL = asset.fileURL,
                      FileManager.default.fileExists(atPath: assetURL.path) else {
                    continue
                }

                // Download to local path
                let destinationURL = localPathForBIOS(filename: filename, systemIdentifier: systemIdentifier)
                let directory = destinationURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try await FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.copyItem(at: assetURL, to: destinationURL)

                // Update Realm
                await MainActor.run {
                    let realm = RomDatabase.sharedInstance.realm
                    if let bios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", filename).first {
                        try? realm.write {
                            bios.cloudRecordID = record.recordID.recordName
                            bios.isDownloaded = true
                            if bios.file == nil {
                                let pvFile = PVFile()
                                pvFile.partialPath = "BIOS/\(systemIdentifier)/\(filename)"
                                bios.file = pvFile
                            }
                        }
                    }
                    NotificationCenter.default.post(name: .BIOSFileFound, object: destinationURL)
                }

                ILOG("[BIOS FAST] Downloaded via \(recordType) query: \(filename)")
                return true
            }

            return false

        } catch {
            DLOG("[BIOS FAST] Error downloading by filename \(filename): \(error.localizedDescription)")
            return false
        }
    }

    /// Download a specific BIOS file from CloudKit
    /// - Parameters:
    ///   - recordID: The CloudKit record ID
    ///   - filename: The expected filename
    ///   - systemIdentifier: The system identifier for subdirectory
    private func downloadBIOSFromCloudKit(recordID: String, filename: String, systemIdentifier: String?) async throws {
        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            ILOG("[BIOS DOWNLOAD] Skipping BIOS download (paused for emulation): \(recordID)")
            return
        }

        let ckRecordID = CKRecord.ID(recordName: recordID)

        ILOG("[BIOS DOWNLOAD] Starting download for: filename=\(filename), recordID=\(recordID), systemIdentifier=\(systemIdentifier ?? "nil")")

        do {
            DLOG("[BIOS DOWNLOAD] Fetching record from CloudKit: \(recordID)")
            let record = try await privateDatabase.record(for: ckRecordID)

            DLOG("[BIOS DOWNLOAD] Record fetched successfully, checking for asset...")
            guard let asset = record["fileData"] as? CKAsset else {
                ELOG("[BIOS DOWNLOAD] Record \(recordID) has no fileData asset!")
                throw CloudSyncError.invalidData
            }

            guard let assetURL = asset.fileURL else {
                ELOG("[BIOS DOWNLOAD] Asset exists but fileURL is nil for \(recordID)")
                throw CloudSyncError.invalidData
            }

            ILOG("[BIOS DOWNLOAD] Asset found at cache path: \(assetURL.path)")

            // Verify asset file exists in cache
            guard FileManager.default.fileExists(atPath: assetURL.path) else {
                ELOG("[BIOS DOWNLOAD] Asset file not found at cache path: \(assetURL.path)")
                throw CloudSyncError.invalidData
            }

            // Determine destination path
            let destinationURL = localPathForBIOS(filename: filename, systemIdentifier: systemIdentifier)
            ILOG("[BIOS DOWNLOAD] Destination path: \(destinationURL.path)")

            // Create directory if needed
            let directory = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try await FileManager.default.removeItem(at: destinationURL)
                DLOG("[BIOS DOWNLOAD] Removed existing file at destination")
            }

            // Copy from CloudKit cache to local
            try FileManager.default.copyItem(at: assetURL, to: destinationURL)

            // Verify the copy succeeded
            let copiedFileExists = FileManager.default.fileExists(atPath: destinationURL.path)
            ILOG("[BIOS DOWNLOAD] Download complete: \(filename) -> \(destinationURL.path), verified: \(copiedFileExists)")

            // Update Realm entry
            await MainActor.run {
                let realm = RomDatabase.sharedInstance.realm
                if let bios = realm.objects(PVBIOS.self).filter("expectedFilename == %@", filename).first {
                    try? realm.write {
                        bios.isDownloaded = true

                        // Create or update PVFile
                        if bios.file == nil {
                            let pvFile = PVFile()
                            pvFile.partialPath = systemIdentifier != nil ? "\(systemIdentifier!)/\(filename)" : filename
                            bios.file = pvFile
                        }
                    }
                }

                // Post notification so BIOS cache and UI can be updated
                NotificationCenter.default.post(name: .BIOSFileFound, object: destinationURL)
            }

            await insertDownloadedFile(destinationURL)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            WLOG("[SYNC] BIOS record not found in CloudKit: \(recordID)")
            throw CloudSyncError.recordNotFound
        }
    }

    /// Upload all local BIOS files that have PVFile entries but no cloudRecordID
    @MainActor
    public func uploadMissingBIOSFiles() async -> Int {
        ILOG("[SYNC] Checking for local BIOS files to upload...")

        let realm = RomDatabase.sharedInstance.realm
        let biosToUpload = realm.objects(PVBIOS.self)
            .filter("file != nil AND (cloudRecordID == nil OR cloudRecordID == '')")

        let biosArray = Array(biosToUpload)
        guard !biosArray.isEmpty else {
            ILOG("[SYNC] No local BIOS files need uploading")
            return 0
        }

        ILOG("[SYNC] Found \(biosArray.count) BIOS files to upload")

        var uploadedCount = 0
        for bios in biosArray {
            guard let fileURL = bios.file?.url,
                  FileManager.default.fileExists(atPath: fileURL.path) else {
                continue
            }

            let filename = bios.expectedFilename
            ILOG("[SYNC] Uploading BIOS: \(filename)")

            do {
                // Extract system identifier from path
                let parentDir = fileURL.deletingLastPathComponent().lastPathComponent
                let systemID = SystemIdentifier(rawValue: parentDir)

                let record = try await uploadFile(fileURL, gameID: nil, systemID: systemID)

                // Update Realm with cloudRecordID
                try realm.write {
                    bios.cloudRecordID = record.recordID.recordName
                }

                uploadedCount += 1
                ILOG("[SYNC] Uploaded BIOS: \(filename), recordID: \(record.recordID.recordName)")
            } catch {
                ELOG("[SYNC] Failed to upload BIOS \(filename): \(error.localizedDescription)")
            }
        }

        ILOG("[SYNC] BIOS upload complete: \(uploadedCount) of \(biosArray.count) uploaded")
        return uploadedCount
    }

    // MARK: - System Directory Sync

    /// Sync `System/<name>/` firmware directories to/from CloudKit.
    ///
    /// Covers only the directories listed in ``systemDirectoriesToSync``.  Files that already exist
    /// locally are skipped on download; files already in CloudKit are skipped on upload (date-based
    /// deduplication is handled by the underlying `uploadFile(_:gameID:systemID:)` method).
    ///
    /// This is called automatically at the end of ``syncMetadataOnly()``.
    ///
    /// - Returns: Number of System/ files uploaded or downloaded during this pass.
    public func syncSystemFiles() async -> Int {
        ILOG("[SYSTEM SYNC] Starting System/ directory sync...")

        if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
            ILOG("[SYSTEM SYNC] Skipping — paused for emulation")
            return 0
        }

        var processedCount = 0
        let systemBase = URL.documentsPath.appendingPathComponent("System")

        // Phase 1: Upload local files not yet in CloudKit.
        // `uploadFile()` performs date-based deduplication, so re-uploading an unchanged file
        // is a no-op from CloudKit's perspective.
        for dirName in Self.systemDirectoriesToSync {
            let dirURL = systemBase.appendingPathComponent(dirName)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            guard let enumerator = FileManager.default.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                      !isDir.boolValue else { continue }

                do {
                    _ = try await uploadFile(fileURL, gameID: nil, systemID: nil)
                    await insertUploadedFile(fileURL)
                    processedCount += 1
                    DLOG("[SYSTEM SYNC] Uploaded: \(fileURL.lastPathComponent)")
                } catch {
                    ELOG("[SYSTEM SYNC] Upload failed for \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        // Phase 2: Download System/ records from CloudKit that are missing locally.
        do {
            let predicate = NSPredicate(format: "directory == %@", "System")
            let query = CKQuery(recordType: recordType, predicate: predicate)
            let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: 500)

            let records = results.compactMap { _, result -> CKRecord? in try? result.get() }
            ILOG("[SYSTEM SYNC] Found \(records.count) System/ records in CloudKit")

            for record in records {
                guard let relativePath = record["filename"] as? String,
                      let asset = record["fileData"] as? CKAsset,
                      let assetURL = asset.fileURL,
                      FileManager.default.fileExists(atPath: assetURL.path) else { continue }

                // Only restore files from our known sync-able system directories.
                let topDir = relativePath.components(separatedBy: "/").first ?? ""
                guard Self.systemDirectoriesToSync.contains(topDir) else { continue }

                let destinationURL = systemBase.appendingPathComponent(relativePath)

                // Skip if already present locally — don't overwrite the user's version.
                guard !FileManager.default.fileExists(atPath: destinationURL.path) else { continue }

                do {
                    let parentDir = destinationURL.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: assetURL, to: destinationURL)
                    await insertDownloadedFile(destinationURL)
                    processedCount += 1
                    ILOG("[SYSTEM SYNC] Downloaded: \(relativePath)")
                } catch {
                    ELOG("[SYSTEM SYNC] Download failed for \(relativePath): \(error.localizedDescription)")
                }
            }
        } catch let ckError as CKError where ckError.code == .unknownItem {
            DLOG("[SYSTEM SYNC] No System/ records found in CloudKit yet")
        } catch {
            ELOG("[SYSTEM SYNC] Failed to query System/ records: \(error.localizedDescription)")
        }

        ILOG("[SYSTEM SYNC] Complete: processed \(processedCount) System/ files")
        return processedCount
    }

    // MARK: - Diagnostics

    /// Audit all BIOS CloudKit records to verify they have valid assets
    /// This is useful for diagnosing sync issues
    /// - Returns: Audit results containing valid, invalid, and missing records
    public func auditBIOSCloudRecords() async -> BIOSAuditResult {
        ILOG("[BIOS AUDIT] Starting CloudKit BIOS audit...")

        var result = BIOSAuditResult()

        // Fetch all records from CloudKit
        let cloudRecords = await fetchAllBIOSRecords()
        ILOG("[BIOS AUDIT] Found \(cloudRecords.count) BIOS records in CloudKit")

        // Check each record for valid asset
        for record in cloudRecords {
            let filename = record["filename"] as? String ?? "unknown"
            let recordID = record.recordID.recordName

            if let asset = record["fileData"] as? CKAsset {
                if let fileURL = asset.fileURL {
                    let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
                    if fileExists {
                        result.validRecords.append((recordID: recordID, filename: filename))
                        DLOG("[BIOS AUDIT] ✓ Valid: \(filename) - asset at \(fileURL.path)")
                    } else {
                        result.assetMissingRecords.append((recordID: recordID, filename: filename))
                        WLOG("[BIOS AUDIT] ⚠ Asset file missing: \(filename) - expected at \(fileURL.path)")
                    }
                } else {
                    result.assetMissingRecords.append((recordID: recordID, filename: filename))
                    WLOG("[BIOS AUDIT] ⚠ Asset URL nil: \(filename)")
                }
            } else {
                result.noAssetRecords.append((recordID: recordID, filename: filename))
                ELOG("[BIOS AUDIT] ✗ No asset: \(filename)")
            }
        }

        // Check local BIOS entries against cloud
        await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            let allBIOS = realm.objects(PVBIOS.self)

            for bios in allBIOS {
                if let cloudRecordID = bios.cloudRecordID, !cloudRecordID.isEmpty {
                    // Has cloud record ID - check if it's in our cloud records
                    let found = cloudRecords.contains { $0.recordID.recordName == cloudRecordID }
                    if !found {
                        result.orphanedLocalRecords.append((recordID: cloudRecordID, filename: bios.expectedFilename))
                        WLOG("[BIOS AUDIT] ⚠ Orphaned local record: \(bios.expectedFilename) - cloudRecordID \(cloudRecordID) not found in CloudKit")
                    }
                } else if bios.file?.url != nil && FileManager.default.fileExists(atPath: bios.file!.url!.path) {
                    // Local file exists but no cloud record
                    result.localOnlyFiles.append((filename: bios.expectedFilename, path: bios.file!.url!.path))
                    ILOG("[BIOS AUDIT] Local-only: \(bios.expectedFilename) exists locally but not in CloudKit")
                }
            }
        }

        // Log summary
        ILOG("""
        [BIOS AUDIT] Audit complete:
          - Valid records with assets: \(result.validRecords.count)
          - Records missing assets: \(result.assetMissingRecords.count)
          - Records with no asset field: \(result.noAssetRecords.count)
          - Orphaned local records (cloud record deleted): \(result.orphanedLocalRecords.count)
          - Local-only files (not uploaded): \(result.localOnlyFiles.count)
        """)

        return result
    }

    /// Force re-upload BIOS files that have issues
    /// - Parameter recordIDs: Record IDs to re-upload, or nil to re-upload all with issues
    /// - Returns: Number of BIOS files re-uploaded
    @MainActor
    public func repairBIOSSync(forRecordIDs recordIDs: [String]? = nil) async -> Int {
        ILOG("[BIOS REPAIR] Starting BIOS sync repair...")

        let realm = RomDatabase.sharedInstance.realm

        // If specific record IDs provided, clear them so they'll be re-uploaded
        if let recordIDs = recordIDs {
            for recordID in recordIDs {
                if let bios = realm.objects(PVBIOS.self).filter("cloudRecordID == %@", recordID).first {
                    try? realm.write {
                        bios.cloudRecordID = nil
                    }
                    ILOG("[BIOS REPAIR] Cleared cloudRecordID for \(bios.expectedFilename)")
                }
            }
        } else {
            // Run audit and clear all problematic records
            let auditResult = await auditBIOSCloudRecords()

            // Clear orphaned records
            for (recordID, _) in auditResult.orphanedLocalRecords {
                if let bios = realm.objects(PVBIOS.self).filter("cloudRecordID == %@", recordID).first {
                    try? realm.write {
                        bios.cloudRecordID = nil
                    }
                }
            }

            // Clear records with missing assets
            for (recordID, _) in auditResult.assetMissingRecords + auditResult.noAssetRecords {
                if let bios = realm.objects(PVBIOS.self).filter("cloudRecordID == %@", recordID).first {
                    try? realm.write {
                        bios.cloudRecordID = nil
                    }
                }
            }
        }

        // Now upload missing BIOS files
        let uploadedCount = await uploadMissingBIOSFiles()
        ILOG("[BIOS REPAIR] Repair complete: uploaded \(uploadedCount) BIOS files")

        return uploadedCount
    }
}

/// Results from BIOS audit
public struct BIOSAuditResult {
    /// Records with valid assets
    public var validRecords: [(recordID: String, filename: String)] = []
    /// Records that have an asset field but the file is missing
    public var assetMissingRecords: [(recordID: String, filename: String)] = []
    /// Records that have no asset field at all
    public var noAssetRecords: [(recordID: String, filename: String)] = []
    /// Local BIOS entries with cloudRecordID that doesn't exist in CloudKit
    public var orphanedLocalRecords: [(recordID: String, filename: String)] = []
    /// Local BIOS files that exist but have no cloud record
    public var localOnlyFiles: [(filename: String, path: String)] = []

    /// True if all records are valid
    public var isHealthy: Bool {
        assetMissingRecords.isEmpty && noAssetRecords.isEmpty && orphanedLocalRecords.isEmpty
    }
}
