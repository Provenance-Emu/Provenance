//
//  CloudKitSaveStatesSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import CloudKit
import RxSwift
import RealmSwift

/// Save states syncer for all OS's using CloudKit
public class CloudKitSaveStatesSyncer: CloudKitSyncer, SaveStatesSyncing {
    
    /// Initialize a new save states syncer
    /// - Parameters:
    ///   - directories: Directories to manage (defaults to ["Saves"])
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public override init(container: CKContainer,directories: Set<String> = ["Saves"], notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(container: container, directories: directories, notificationCenter: notificationCenter, errorHandler: errorHandler)
    }
    
    /// Get all CloudKit records for save states
    /// - Returns: Array of CKRecord objects
    public func getAllRecords() async -> [CKRecord] {
        do {
            // Create a query for all save state records
            let query = CKQuery(recordType: CloudKitSchema.RecordType.saveState.rawValue, predicate: NSPredicate(value: true))
            
            // Execute the query
            let (records, _) = try await privateDatabase.records(matching: query, resultsLimit: 100)
            
            // Convert to array of CKRecord
            let recordsArray = records.compactMap { _, result -> CKRecord? in
                switch result {
                case .success(let record):
                    return record
                case .failure(let error):
                    ELOG("Error fetching save state record: \(error.localizedDescription)")
                    return nil
                }
            }
            
            DLOG("Fetched \(recordsArray.count) save state records from CloudKit")
            return recordsArray
        } catch {
            ELOG("Failed to fetch save state records: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Check if a file is downloaded locally
    /// - Parameters:
    ///   - filename: The filename to check
    ///   - system: The system identifier
    ///   - gameID: The game ID
    /// - Returns: True if the file is downloaded locally
    public func isFileDownloaded(filename: String, inSystem system: String, gameID: String? = nil) async -> Bool {
        // Create local file path
        let documentsURL = URL.documentsPath
        var directoryURL = documentsURL.appendingPathComponent("Saves").appendingPathComponent(system)
        
        if let gameID = gameID {
            directoryURL = directoryURL.appendingPathComponent(gameID)
        }
        
        let fileURL = directoryURL.appendingPathComponent(filename)
        
        // Check if file exists
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// The CloudKit record type for save states
    override public var recordType: String {
        return "SaveState"
    }
    
    /// Initialize a new save states syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(container: CKContainer, notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(container: container, directories: ["Saves"], notificationCenter: notificationCenter, errorHandler: errorHandler)
    }
    
    /// Get the local URL for a save state
    /// - Parameter saveState: The save state to get the URL for
    /// - Returns: The local URL for the save state file
    public func localURL(for saveState: PVSaveState) -> URL? {
        guard let file = saveState.file else {
            return nil
        }
        
        return file.url
    }
    
    /// Get the cloud URL for a save state
    /// - Parameter saveState: The save state to get the URL for
    /// - Returns: The cloud URL for the save state file (this is a virtual path for CloudKit)
    public func cloudURL(for saveState: PVSaveState) -> URL? {
        guard let file = saveState.file,
              let url = file.url else {
            return nil
        }
        
        // For CloudKit, we create a virtual path that represents the record
        let systemPath = (saveState.game.systemIdentifier as NSString)
        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
        
        // Create a URL with a custom scheme to represent CloudKit records
        // This is just for internal tracking, not an actual file URL
        var components = URLComponents()
        components.scheme = "cloudkit"
        components.host = "saves"
        components.path = "/\(systemDir)/\(url.lastPathComponent)"
        
        return components.url
    }
    
    /// Upload a save state to CloudKit
    /// - Parameter saveState: The save state to upload
    /// - Returns: Completable that completes when the upload is done
    public func uploadSaveState(for saveState: PVSaveState) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self,
                  let localURL = self.localURL(for: saveState) else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save state file"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Upload the file to CloudKit
                    let systemPath = (saveState.game.systemIdentifier as NSString)
                    let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
                    
                    // Save the record to CloudKit
                    _ = try await self.uploadFile(localURL, gameID: saveState.game.id, systemID: saveState.game.system?.systemIdentifier)
                    await self.insertUploadedFile(localURL)
                    
                    DLOG("Uploaded save state to CloudKit: \(localURL.lastPathComponent)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to upload save state to CloudKit: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// Download a save state from CloudKit
    /// - Parameter saveState: The save state to download
    /// - Returns: Completable that completes when the download is done
    public func downloadSaveState(for saveState: PVSaveState) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save state syncer"])))
                return Disposables.create()
            }
            
            Task {
                do {
                    // Find the record for this save state
                    let recordID = CKRecord.ID(recordName: "savestate_\(saveState.id)")
                    let privateDatabase = self.container.privateCloudDatabase
                    
                    do {
                        let record = try await privateDatabase.record(for: recordID)
                        
                        guard let asset = record["fileData"] as? CKAsset,
                              let fileURL = asset.fileURL else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "Save state file not found in CloudKit"])
                        }
                        
                        // Get system directory
                        guard let systemDir = record["system"] as? String,
                              let filename = record["filename"] as? String else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid save state record data"])
                        }
                        
                        // Create local file path
                        let documentsURL = URL.documentsPath

                        let directoryURL = documentsURL.appendingPathComponent("Saves").appendingPathComponent(systemDir)
                        let destinationURL = directoryURL.appendingPathComponent(filename)
                        
                        // Create directory if needed
                        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                        
                        // Copy file from asset to local storage
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try await FileManager.default.removeItem(at: destinationURL)
                        }
                        
                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                        await self.insertDownloadedFile(destinationURL)
                        
                        // Update save state's file reference if needed
                        if saveState.file == nil {
                            try await MainActor.run {
                                let realm = try Realm()
                                try realm.write {
                                    let file = PVFile(withURL: destinationURL, relativeRoot: .documents)
                                    saveState.file = file
                                }
                            }
                        }
                        
                        DLOG("Downloaded save state from CloudKit: \(filename)")
                        observer(.completed)
                    } catch {
                        // If record not found by ID, try searching by game ID and filename
                        let systemPath = (saveState.game.systemIdentifier as NSString)
                        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
                        let filename = saveState.file?.fileName ?? "savestate_\(saveState.id)"
                        
                        // Create query
                        let predicate = NSPredicate(format: "directory == %@ AND system == %@ AND gameID == %@ AND filename == %@", 
                                                   "Saves", systemDir, saveState.game.id, filename)
                        let query = CKQuery(recordType: "File", predicate: predicate)
                        
                        // Execute query
                        let (results, _) = try await privateDatabase.records(matching: query)
                        let records = results.compactMap { _, result in
                            try? result.get()
                        }
                        
                        guard let record = records.first,
                              let asset = record["fileData"] as? CKAsset,
                              let fileURL = asset.fileURL else {
                            throw NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "Save state file not found in CloudKit"])
                        }
                        
                        // Create local file path
                        let documentsURL = URL.documentsPath
                        let directoryURL = documentsURL.appendingPathComponent("Saves").appendingPathComponent(systemDir)
                        let destinationURL = directoryURL.appendingPathComponent(filename)
                        
                        // Create directory if needed
                        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                        
                        // Copy file from asset to local storage
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try await FileManager.default.removeItem(at: destinationURL)
                        }
                        
                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                        await self.insertDownloadedFile(destinationURL)
                        
                        // Update save state's file reference if needed
                        if saveState.file == nil {
                            try await MainActor.run {
                                let realm = try Realm()
                                try realm.write {
                                    let file = PVFile(withURL: destinationURL, relativeRoot: .documents)
                                    saveState.file = file
                                }
                            }
                        }
                        
                        DLOG("Downloaded save state from CloudKit: \(filename)")
                        observer(.completed)
                    }
                } catch {
                    ELOG("Failed to download save state from CloudKit: \(error.localizedDescription)")
                    await self.errorHandler.handle(error: error)
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
}
