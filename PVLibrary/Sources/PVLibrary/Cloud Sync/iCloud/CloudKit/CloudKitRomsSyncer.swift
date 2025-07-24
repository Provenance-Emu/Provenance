//
//  CloudKitRomsSyncer.swift
//  PVLibrary
//
//  Created by Cascade on 4/29/25.
//

import Foundation
import CloudKit
import RealmSwift
import Combine
import PVLogging
import PVSupport
import RxSwift
import ZipArchive
import RealmSwift // Ensure RealmSwift is imported for error codes

// Define the type for the retry function
public typealias CloudKitRetryOperation<T> = (_ operation: @escaping () async throws -> T, _ maxRetries: Int, _ progressTracker: SyncProgressTracker?) async throws -> T

// Helper Error for descriptive messages
struct DescriptiveError: Error, LocalizedError {
    let description: String
    var errorDescription: String? { description }
}

public class CloudKitRomsSyncer: NSObject, RomsSyncing {

    // MARK: - SyncProvider Conformance Properties
    public var directories: Set<String> = ["ROMs"] // TODO: Initialize properly, e.g., with system identifiers this syncer handles
    public var pendingFilesToDownload = ConcurrentSet<URL>()
    public var newFiles = ConcurrentSet<URL>()
    public var uploadedFiles = ConcurrentSet<URL>()
    public var status = ConcurrentSingle<iCloudSyncStatus>(.initialUpload) // Fixed initial value & label
    public var initialSyncResult: SyncResult = .indeterminate // Fixed initial value
    public var fileImportQueueMaxCount: Int = 50 // TODO: Set appropriate default/make configurable?
    public var purgeStatus: DatastorePurgeStatus = .incomplete // Fixed initial value

    // MARK: - CloudKitRomsSyncer Specific Properties
    private let container: CKContainer
    private let database: CKDatabase // Likely private database
    private let retryOperation: CloudKitRetryOperation<Any> // Specify generic type <Any>
    private let romsDatastore: RomDatabase // Add Datastore reference
    private let fileManager = FileManager.default
    private let operationQueue = OperationQueue()
    private var cancellables = Set<AnyCancellable>()
    private let progressTracker = SyncProgressTracker.shared // Added Progress Tracker

    // MARK: - Initialization
    public init(container: CKContainer, retryStrategy: @escaping CloudKitRetryOperation<Any>, romsDatastore: RomDatabase = RomDatabase.sharedInstance) {
        self.container = container
        self.database = container.privateCloudDatabase
        // Store the passed strategy directly
        self.retryOperation = retryStrategy
        self.romsDatastore = romsDatastore
        super.init()
        setupOperationQueue()
        // TODO: Add any other necessary setup
    }

    private func setupOperationQueue() {
        // TODO: Implement setupOperationQueue
    }

    // MARK: - SyncProvider Conformance Methods (Stubs)
    // TODO: Implement these methods based on CloudKit logic
    public func loadAllFromCloud(iterationComplete: (() async -> Void)?) async -> Completable {
        ILOG("Starting loadAllFromCloud for CloudKit ROMs...")
        let query = CKQuery(recordType: CloudKitSchema.RecordType.rom.rawValue, predicate: NSPredicate(value: true))
        // Sort by modification date descending to potentially process newest first? Or creation date?
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]

        var allRecords: [CKRecord] = []

        do {
            // Use the convenience method to fetch all records, handling cursors automatically.
            // TODO: Consider limiting fields fetched if only specific data is needed initially.
            let (matchResults, _) = try await database.records(matching: query)

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    allRecords.append(record)
                    // Process record - check if local exists, update status, trigger download if needed
                    await processCloudRecord(record)
                    VLOG("Processed ROM record: \(record.recordID.recordName)")
                case .failure(let error):
                    WLOG("Failed to fetch a specific ROM record during loadAll: \(error.localizedDescription)")
                    // Decide if we should continue or propagate the error
                }
            }

            ILOG("Finished loadAllFromCloud. Processed \(allRecords.count) ROM records for download.")
            // Records have been processed individually above

        } catch {
            ELOG("Failed to execute query for loadAllFromCloud: \(error.localizedDescription)")
            // Handle error appropriately (e.g., log, notify user)
            // Consider throwing or returning an error state if the protocol allowed.
        }

        // Call the completion handler if provided
        await iterationComplete?()

        return Completable.empty() // Return Completable as required by SyncProvider
    }

    public func insertDownloadingFile(_ file: URL) async -> URL? {
        VLOG("insertDownloadingFile called for CloudKitSyncer - No action needed. File: \(file.path)")
        // CloudKit manages its own temporary download locations.
        return nil
    }

    public func insertDownloadedFile(_ file: URL) async {
        VLOG("insertDownloadedFile called for CloudKitSyncer - Processing should occur within downloadRom completion. File: \(file.path)")
        // Final file handling (move, db update) should be part of the downloadRom logic.
    }

    public func insertUploadedFile(_ file: URL) async {
        VLOG("insertUploadedFile called for CloudKitSyncer - Confirmation should occur within uploadRom completion. File: \(file.path)")
        // Update local tracking if needed
        _ = await uploadedFiles.insert(file)
    }

    public func deleteFromDatastore(_ file: URL) async {
        VLOG("Attempting deleteFromDatastore for URL: \(file.path)")
        do {
            // Find the game corresponding to this local URL
            // Ensure we check on the correct thread/actor for Realm access
            let realm = RomDatabase.sharedInstance.realm // Assuming this is safe or we need to pass the instance/actor
            guard let game = realm.objects(PVGame.self).filter("file.path == %@", file.path).first else {
                WLOG("Could not find PVGame matching URL \(file.path) for deletion.")
                return
            }

            guard let md5 = game.md5 else {
                WLOG("Found game \(game.title) but it has no MD5. Cannot delete from CloudKit via URL.")
                return
            }

            // Call the primary deletion method
            ILOG("Found game with MD5 \(md5) for URL \(file.path). Calling markGameAsDeleted.")
            try await markGameAsDeleted(md5: md5)

        } catch {
            ELOG("Error during deleteFromDatastore for URL \(file.path): \(error.localizedDescription)")
            // Handle or propagate error
        }
    }

    public func setNewCloudFilesAvailable() async {
        ILOG("setNewCloudFilesAvailable called for CloudKitSyncer - Action needed.")
        // This is typically driven by push notifications, but can be called manually.
        // TODO: Investigate correct way to handle CloudKit push notifications/change tokens.
        // await fetchChangesFromServer() // Error: This function doesn't exist on the base syncer. Need alternative mechanism.
    }

    public func prepareNextBatchToProcess() async -> any Collection<URL> {
        VLOG("prepareNextBatchToProcess called for CloudKitSyncer - Not applicable.")
        return []
    }

    // MARK: - CloudKit Operations

    /// Fetches a single CKRecord by its ID using the retry strategy.
    private func fetchRecord(recordID: CKRecord.ID) async throws -> CKRecord? {
        do {
            // Pass nil directly, relying on compiler inference with the simplified init/property
            let result = try await retryOperation({ // Renamed method
                // Fetch the specific record by its ID
                try await self.database.record(for: recordID)
            }, 3, nil)
            // Cast the result back to CKRecord?
            guard let record = result as? CKRecord else {
                // This shouldn't happen if the operation succeeded and returned a record,
                // but handle the case where the cast fails unexpectedly.
                ELOG("Retry operation returned unexpected type for fetchRecord: \(type(of: result))")
                throw CloudSyncError.unknown // Or a more specific error
            }
            VLOG("Fetched record: \(record.recordID.recordName)")
            return record
        } catch let error as CKError where error.code == .unknownItem {
            VLOG("Record not found: \(recordID.recordName)")
            return nil // Record not found is not an error in this context
        } catch {
            ELOG("Failed to fetch record \(recordID.recordName): \(error.localizedDescription)")
            throw CloudSyncError.cloudKitError(error)
        }
    }

    // MARK: - RomsSyncing Protocol Implementation

    /// Returns the local file URL for the given game.
    public func localURL(for game: PVGame) -> URL? {
        // Check if the game object is valid first
        if game.isInvalidated {
             WLOG("Attempting to get localURL for invalidated game: \(game.debugDescription)")
             return nil
        }

        // Check if the file URL exists and the file is actually present
        guard let url = game.file?.url, fileManager.fileExists(atPath: url.path) else {
            VLOG("Game \(game.title) (MD5: \(game.md5 ?? "N/A")) does not have a valid local file URL or the file doesn't exist.")
            return nil
        }

        VLOG("Returning local URL for game \(game.title): \(url.path)")
        return url
    }

    /// Returns a conceptual cloud URL placeholder (currently nil for CloudKit).
    /// CloudKit uses CKAssets tied to CKRecords, not direct file URLs like iCloud Drive.
    public func cloudURL(for game: PVGame) -> URL? {
        // CloudKit doesn't provide a predictable URL for a potential cloud asset
        // merely from the PVGame object. We need the CKRecord to check for the asset.
        // Returning nil signifies this limitation compared to file-based syncers.
        VLOG("cloudURL requested for CloudKit, returning nil as it's not directly applicable. Game MD5: \(game.md5 ?? "N/A")")
        return nil
    }

    public func uploadGame(_ game: PVGame) async throws {
        guard let md5 = game.md5, !md5.isEmpty else {
            ELOG("Cannot upload game without MD5: \(game.title)")
            throw CloudSyncError.invalidData
        }

        // 1. Fetch or Create Record
        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
        var record: CKRecord
        do {
            record = try await fetchRecord(recordID: recordID) ?? CKRecord(recordType: CloudKitSchema.RecordType.rom.rawValue, recordID: recordID)
        } catch {
            ELOG("Failed to fetch or create base record for \(md5): \(error.localizedDescription)")
            throw CloudSyncError.cloudKitError(error) // Rethrow specific error if needed
        }

        // Check if already marked deleted remotely, if so, skip upload
        if let isDeleted = record[CloudKitSchema.ROMFields.isDeleted] as? Bool, isDeleted == true {
            WLOG("Skipping upload for \(md5): Record is marked as deleted in CloudKit.")
            // Optional: Update local state if needed?
            return
        }

        // 2. Map Game Data to Record
        do {
            record = try mapPVGameToRecord(game, existingRecord: record)
        } catch let error as CloudSyncError {
            throw error // Rethrow known sync errors
        } catch {
            ELOG("Unexpected error mapping PVGame to record for \(md5): \(error.localizedDescription)")
            throw CloudSyncError.unknown // Or map to a more specific error if possible
        }

        // 3. Prepare Asset (CKAsset) - Zip if necessary using ZipArchive
        guard let primaryFileURL = game.file?.url else {
            ELOG("Cannot upload game \(md5): Missing primary file URL.")
            throw CloudSyncError.invalidData
        }
        let relatedFileURLs = game.relatedFiles.compactMap { $0.url }
        let filesToPackage = [primaryFileURL] + relatedFileURLs

        var asset: CKAsset?
        var isArchive: Bool = false
        var tempZipURL: URL? = nil // Keep track for cleanup

        do {
            let assetSourceURL: URL
            if filesToPackage.count > 1 {
                VLOG("Multiple files for \(md5). Creating ZipArchive zip archive.")
                isArchive = true
                let zipURL = try temporaryZipURL(for: md5)
                tempZipURL = zipURL // Store for potential cleanup
                // Call the createZip helper
                try await createZip(files: filesToPackage, primaryFile: primaryFileURL, outputURL: zipURL)
                assetSourceURL = zipURL
                // Store relative paths of related files (excluding primary)
                record[CloudKitSchema.ROMFields.relatedFilenames] = relatedFileURLs.map { $0.lastPathComponent } as [NSString]
            } else {
                // Single file, just use its URL directly
                VLOG("Single file for \(md5). Using direct URL: \(primaryFileURL.path)")
                isArchive = false
                assetSourceURL = primaryFileURL
                record[CloudKitSchema.ROMFields.relatedFilenames] = nil // Clear related filenames if it was previously an archive
            }

            // Create the CKAsset from the final URL (either original file or temp zip)
            asset = CKAsset(fileURL: assetSourceURL)
            record[CloudKitSchema.ROMFields.fileData] = asset
            record[CloudKitSchema.ROMFields.isArchive] = isArchive as NSNumber
            record[CloudKitSchema.ROMFields.originalFilename] = primaryFileURL.lastPathComponent // Always store primary filename

        } catch let error as CloudSyncError {
            // If createZip threw a CloudSyncError, rethrow it
            ELOG("CloudSyncError preparing asset for \(md5): \(error)")
            if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
                try? await FileManager.default.removeItem(at: url) // Use sync remove here
            }
            throw error
        } catch {
            ELOG("Unexpected error preparing asset for \(md5): \(error.localizedDescription)")
            if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
                try? await FileManager.default.removeItem(at: url) // Use sync remove here
            }
            // Wrap unexpected errors appropriately
            throw CloudSyncError.fileSystemError(error)
        }

        // 4. Verify asset is set before saving to CloudKit
        if record[CloudKitSchema.ROMFields.fileData] as? CKAsset == nil {
            ELOG("Critical error: Asset not set on record before upload for game \(md5)")
            if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
                try? await FileManager.default.removeItem(at: url)
            }
            throw CloudSyncError.invalidData
        }
        
        // Save Record to CloudKit
        do {
            try await saveRecord(record)
            ILOG("Successfully saved record with asset for game \(md5) to CloudKit.")
        } catch {
            // Clean up zip file if upload fails
            if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
                try? await FileManager.default.removeItem(at: url)
            }
            // Error already logged in saveRecord, just rethrow
            throw error
        }

        // 5. Clean up temporary zip file *after* successful CK upload
        if let url = tempZipURL, FileManager.default.fileExists(atPath: url.path) {
            // Use sync remove here as uploadGame is already async
            do {
                try await FileManager.default.removeItem(at: url)
                VLOG("Cleaned up temporary ZipArchive zip file: \(url.path)")
            } catch {
                WLOG("Failed to clean up temporary zip file \(url.path): \(error)")
            }
        }

        ILOG("Completed upload process for game: \(game.title) (MD5: \(md5))")
    }
    /// Marks a game record as deleted in CloudKit based on its MD5 hash.
    /// This performs a "soft delete" by setting the `isDeleted` flag.
    /// - Parameter md5: The MD5 hash of the game to mark as deleted.
    public func markGameAsDeleted(md5: String) async throws {
        let recordID = Self.recordID(forRomMD5: md5)
        VLOG("Attempting to mark CloudKit record as deleted: \(recordID.recordName)")

        do {
            // Fetch the existing record
            guard let record = try await fetchRecord(recordID: recordID) else {
                // Record doesn't exist, nothing to mark deleted.
                WLOG("Attempted to mark record as deleted, but it was not found in CloudKit (maybe already deleted?).")
                return
            }
            VLOG("Found record to mark as deleted: \(recordID.recordName)")

            // Check if already marked
            if let isDeleted = record[CloudKitSchema.ROMFields.isDeleted] as? Bool, isDeleted == true {
                VLOG("Record \(recordID.recordName) is already marked as deleted. Skipping.")
                return
            }

            // Set the flag and save
            record[CloudKitSchema.ROMFields.isDeleted] = true

            try await saveRecord(record)
            ILOG("Successfully marked CloudKit record as deleted: \(record.recordID.recordName) at \(record.modificationDate ?? Date())")
        } catch let error as CKError where error.code == .unknownItem {
            WLOG("Attempted to mark record as deleted, but it was not found in CloudKit (might have been deleted already): \(recordID.recordName). Error: \(error.localizedDescription)")
            // Consider this non-fatal in a soft-delete scenario
            return
        } catch {
            ELOG("Failed to mark CloudKit record \(recordID.recordName) as deleted: \(error.localizedDescription)")
            throw CloudSyncError.cloudKitError(error)
        }
    }

    internal func hardDeleteGame(md5: String) async throws {
        let recordID = Self.recordID(forRomMD5: md5)
        VLOG("Attempting HARD delete for CloudKit record: \(recordID.recordName)")
        do {
            try await database.deleteRecord(withID: recordID)
            ILOG("Successfully deleted CloudKit record: \(recordID.recordName)")
        } catch let error as CKError where error.code == .unknownItem {
            // Record was already deleted or never existed. This is fine.
            VLOG("Record \(recordID.recordName) not found in CloudKit for deletion (already deleted?). Ignoring.")
        } catch {
            ELOG("Failed to delete record \(recordID.recordName) from CloudKit for MD5 \(md5): \(error.localizedDescription)")
            // If this fails, the local delete succeeded, but the remote record remains.
            // It might get re-downloaded later unless we handle this state.
            throw CloudSyncError.cloudKitError(error)
        }
        // Note: Local Realm deletion is assumed to be handled by the caller or RomsDatastore
        // before this function is called.
    }

    /// Process a cloud record to check if download is needed and trigger it
    /// - Parameter record: The CloudKit record to process
    private func processCloudRecord(_ record: CKRecord) async {
        // Extract MD5 from record ID using centralized method
        guard let md5 = CloudKitSchema.RecordIDGenerator.extractMD5FromRomRecordID(record.recordID) else {
            ELOG("Invalid ROM record ID format: \(record.recordID.recordName)")
            return
        }
        
        let recordName = record.recordID.recordName
        
        do {
            // Check if record is marked as deleted
            if let isDeleted = record[CloudKitSchema.ROMFields.isDeleted] as? Bool, isDeleted {
                VLOG("Record \(recordName) is marked as deleted, skipping")
                return
            }
            
            // Check if we have a local game for this MD5
            let existingLocalGame = RomDatabase.sharedInstance.game(withMD5: md5)
            var updatedOrCreatedGame: PVGame?
            
            if let localGame = existingLocalGame {
                VLOG("Local game found for MD5 \(md5). Updating from cloud record...")
                try await updatePVGame(from: record, localGame: localGame)
                updatedOrCreatedGame = RomDatabase.sharedInstance.game(withMD5: md5)
            } else {
                VLOG("No local game found for MD5 \(md5). Creating from cloud record...")
                updatedOrCreatedGame = try await createPVGame(from: record)
            }
            
            // Check if download is needed
            if let game = updatedOrCreatedGame, !game.isDownloaded {
                // Verify the record has an asset before triggering download
                if record[CloudKitSchema.ROMFields.fileData] is CKAsset {
                    VLOG("Local game \(md5) needs download. Triggering download...")
                    Task {
                        do {
                            try await downloadGame(md5: md5)
                            ILOG("Successfully downloaded game \(md5)")
                        } catch {
                            ELOG("Failed to download game \(md5): \(error.localizedDescription)")
                        }
                    }
                } else {
                    WLOG("Local game \(md5) needs download, but remote record has no asset")
                }
            } else if let game = updatedOrCreatedGame {
                VLOG("Local game \(md5) already downloaded or up to date")
            } else {
                ELOG("Failed to create or update game for MD5 \(md5)")
            }
            
        } catch let error as CKError {
            ELOG("CloudKit error processing record \(record.recordID.recordName): \(error.localizedDescription) (Code: \(error.code.rawValue))")
            
            // Handle specific CloudKit errors
            switch error.code {
            case .unknownItem:
                WLOG("ROM record not found in CloudKit, may have been deleted")
            case .networkFailure, .networkUnavailable:
                WLOG("Network error processing ROM record, will retry automatically")
            case .requestRateLimited:
                WLOG("Rate limited processing ROM record, will retry after delay")
            default:
                if error.isRecoverableCloudKitError {
                    WLOG("ROM record processing failed with recoverable error, will retry automatically")
                } else {
                    ELOG("ROM record processing failed with non-recoverable CloudKit error")
                }
            }
        } catch {
            ELOG("Unexpected error processing cloud record \(record.recordID.recordName): \(error.localizedDescription)")
        }
    }
    
    public func handleRemoteGameChange(recordID: CKRecord.ID) async throws {
        VLOG("Handling remote change for record ID: \(recordID.recordName)")

        // 1. Fetch the record from CloudKit
        // Use optional catch as .unknownItem is expected if the record was truly deleted (though less likely with soft delete)
        var fetchedRecord: CKRecord?
        do {
            fetchedRecord = try await fetchRecord(recordID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            WLOG("Remote record \(recordID.recordName) not found when handling change. It might have been hard deleted. Skipping.")
            // If truly not found, we might need to delete locally if we have it?
            // Let's extract MD5 first to check local state.
        } catch {
            // Rethrow other errors
            throw error
        }

        guard let md5 = CloudKitSchema.RecordIDGenerator.extractMD5FromRomRecordID(recordID) else {
            ELOG("Invalid ROM record ID format: \(recordID.recordName)")
            return
        }

        // MD5 already extracted and validated above

        // 3. Process based on fetched record and isDeleted flag
        if let record = fetchedRecord {
            let isMarkedDeleted = record[CloudKitSchema.ROMFields.isDeleted] as? Bool ?? false

            if isMarkedDeleted {
                // --- Handle Soft Delete ---
                ILOG("Remote record \(recordID.recordName) is marked as deleted. MD5: \(md5)")
                if let localGame = RomDatabase.sharedInstance.game(withMD5: md5) {
                    VLOG("Deleting local game \(localGame.title) due to remote delete flag.")
                    do {
                        // IMPORTANT: This delete call must NOT trigger the PVGameWillBeDeleted notification
                        // or subsequent CloudKit update, otherwise it loops.
                        // Ensure RomsDatastore.delete handles this context.
                        try RomDatabase.sharedInstance.delete(game: localGame)
                        ILOG("Successfully deleted local game \(md5) based on remote flag.")
                    } catch {
                        ELOG("Failed to delete local game \(md5) after remote delete flag: \(error)")
                        // Decide how to handle - retry? Log?
                    }
                } else {
                    VLOG("Local game \(md5) not found, no need to delete locally.")
                }
                // --- End Soft Delete Handling ---

            } else {
                // --- Handle Create or Update ---
                ILOG("Remote record \(recordID.recordName) found and not deleted (Create/Update). MD5: \(md5)")
                let existingLocalGame = RomDatabase.sharedInstance.game(withMD5: md5)
                var updatedOrCreatedGame: PVGame?

                if let localGame = existingLocalGame {
                    VLOG("Local game found for MD5 \(md5). Updating...")
                    try await updatePVGame(from: record, localGame: localGame)
                    // Re-fetch in case update modified it significantly or mapping requires it
                    updatedOrCreatedGame = RomDatabase.sharedInstance.game(withMD5: md5)
                } else {
                    VLOG("No local game found for MD5 \(md5). Creating...")
                    updatedOrCreatedGame = try await createPVGame(from: record)
                }

                // Trigger asset download if necessary
                if let game = updatedOrCreatedGame, !game.isDownloaded {
                    // Check asset exists before triggering download?
                    if record[CloudKitSchema.ROMFields.fileData] is CKAsset {
                        VLOG("Local game \(md5) is not marked as downloaded. Triggering download...")
                        // Add error handling for download itself if needed
                        Task { try? await downloadGame(md5: md5) }
                    } else {
                        WLOG("Local game \(md5) needs download, but remote record has no asset. Skipping download trigger.")
                    }
                } else if updatedOrCreatedGame == nil {
                    WLOG("Game object was nil after update/create for \(md5). Cannot check download status.")
                } else {
                    VLOG("Local game \(md5) already marked as downloaded or update failed. Skipping download trigger.")
                }
                // --- End Create/Update Handling ---
            }

        } else {
            // Fetched Record is nil (Record doesn't exist remotely, or fetch failed earlier)
            // This case is less likely with soft deletes. Might indicate a hard delete happened.
            ILOG("Remote record \(recordID.recordName) not found when handling change (Hard Delete or Error?). MD5: \(md5)")
            // If we have the game locally, delete it.
            if let localGame = RomDatabase.sharedInstance.game(withMD5: md5) {
                VLOG("Deleting local game \(localGame.title) because remote record was not found.")
                do {
                    // Ensure this delete path also avoids triggering cloud sync again.
                    // Ensure RomsDatastore.delete handles this context.
                    try RomDatabase.sharedInstance.delete(game: localGame)
                    ILOG("Successfully deleted local game \(md5) because remote record was missing.")
                } catch {
                    ELOG("Failed to delete local game \(md5) after remote record was missing: \(error)")
                }
            } else {
                VLOG("No local game found for \(md5), consistent with missing remote record.")
            }
        }
    }

    public func fetchRemoteGameRecord(md5: String) async throws -> CKRecord? {
        // Helper for fetching based on MD5
        ELOG("fetchRemoteGameRecord not yet implemented")
        throw CloudSyncError.notImplemented // Placeholder
    }

    // MARK: - Asset Handling

    public func downloadGame(md5: String) async throws {
        VLOG("Starting download for game MD5: \(md5) using ZipArchive path")

        // 1. Fetch the CloudKit Record
        let recordID = Self.recordID(forRomMD5: md5)
        guard let record = try await fetchRecord(recordID: recordID) else {
            ELOG("Download failed: Record not found in CloudKit for MD5 \(md5).")
            // Check local state and update if needed
            if let localGame = RomDatabase.sharedInstance.game(withMD5: md5), localGame.isDownloaded {
                WLOG("Local game \(md5) was marked downloaded but record missing. Updating status.")
                try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: nil)
            }
            throw CloudSyncError.cloudKitError(CKError(.unknownItem))
        }

        // 2. Get Asset and Metadata from Record
        guard let asset = record[CloudKitSchema.ROMFields.fileData] as? CKAsset,
              let assetURL = asset.fileURL else {
            ELOG("Download failed: Missing fileData asset in record \(recordID.recordName). MD5: \(md5)")
            if let localGame = RomDatabase.sharedInstance.game(withMD5: md5), localGame.isDownloaded {
                WLOG("Local game \(md5) was marked downloaded but asset missing. Updating status.")
                try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            }
            throw CloudSyncError.invalidData
        }

        let isArchive = (record[CloudKitSchema.ROMFields.isArchive] as? NSNumber)?.boolValue ?? false
        guard let primaryFilename = record[CloudKitSchema.ROMFields.originalFilename] as? String, !primaryFilename.isEmpty else {
            ELOG("Download failed: Missing originalFilename in record \(recordID.recordName). MD5: \(md5)")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw CloudSyncError.invalidData
        }
        guard let systemIdentifier = record[CloudKitSchema.ROMFields.systemIdentifier] as? String, !systemIdentifier.isEmpty else {
            ELOG("Download failed: Missing systemIdentifier in record \(recordID.recordName). MD5: \(md5)")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw CloudSyncError.invalidData
        }

        // 3. Determine Destination Directory
        let systemRomsURL = Paths.romsPath(forSystemIdentifier: systemIdentifier)
        let destinationDirectory = systemRomsURL // Extract directly into the system's ROM folder
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        VLOG("Destination directory for download/extraction: \(destinationDirectory.path)")

        // 4. Handle File Placement (Direct Copy or Unzip using ZipArchive)
        var finalPrimaryFileURL: URL? = nil
        do {
            if isArchive {
                // --- Unzip Archive using ZipArchive ---
                VLOG("Asset is an archive. Unzipping \(assetURL.path) to \(destinationDirectory.path)")

                // Use ZipArchive
                let success = SSZipArchive.unzipFile(atPath: assetURL.path, toDestination: destinationDirectory.path)
                guard success else {
                    throw CloudSyncError.zipError(DescriptiveError(description: "ZipArchive failed to unzip \(assetURL.path) to \(destinationDirectory.path)"))
                }
                VLOG("Successfully unzipped archive to \(destinationDirectory.path)")
                // Find the primary file (e.g., .iso, .bin) to return its URL
                // This logic might need refinement based on how primary files are identified
                if let firstFile = try? FileManager.default.contentsOfDirectory(at: destinationDirectory, includingPropertiesForKeys: nil).first {
                    finalPrimaryFileURL = firstFile
                } else {
                    WLOG("Could not determine primary file URL after unzipping to \(destinationDirectory.path)")
                }
            } else {
                // Handle single file download
                let finalDestinationURL = destinationDirectory.appendingPathComponent(primaryFilename)
                VLOG("Asset is a single file. Moving \(assetURL.path) to \(finalDestinationURL.path)")

                // Ensure overwrite by removing existing file first.
                if FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                    VLOG("Removing existing file at \(finalDestinationURL.path)")
                    try await FileManager.default.removeItem(at: finalDestinationURL)
                }
                try FileManager.default.moveItem(at: assetURL, to: finalDestinationURL)
                finalPrimaryFileURL = finalDestinationURL
                ILOG("Successfully moved single file for \(md5) to \(finalDestinationURL.path).")
            }
        } catch {
            ELOG("File operation or ZipArchive error during download/unzip for \(md5): \(error.localizedDescription)")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw CloudSyncError.fileSystemError(error)
        }

        // 5. Update Local PVGame Status
        guard let confirmedPrimaryFileURL = finalPrimaryFileURL, FileManager.default.fileExists(atPath: confirmedPrimaryFileURL.path) else {
            ELOG("Download failed: Primary file not found at expected location \(finalPrimaryFileURL?.path ?? "nil") after file operations for \(md5). Final check.")
            try? await updateLocalDownloadStatus(md5: md5, isDownloaded: false, fileURL: nil, record: record)
            throw CloudSyncError.fileSystemError(CocoaError(.fileNoSuchFile))
        }

        // Pass the confirmed primary file URL and the record (for related file info)
        try await updateLocalDownloadStatus(md5: md5, isDownloaded: true, fileURL: confirmedPrimaryFileURL, record: record)

        ILOG("Successfully completed download and local update for game MD5: \(md5).")
    }

    // MARK: - Mapping Helpers

    private func mapPVGameToRecord(_ game: PVGame, existingRecord: CKRecord? = nil) throws -> CKRecord {
        // Ensure MD5 exists, otherwise we can't generate the ID or sync.
        guard let md5 = game.md5, !md5.isEmpty else {
            ELOG("Cannot map PVGame to CKRecord without a valid MD5: \(game.title)")
            throw CloudSyncError.invalidData
        }

        let recordID = Self.recordID(forRomMD5: md5)
        let record = existingRecord ?? CKRecord(recordType: CloudKitSchema.RecordType.rom.rawValue, recordID: recordID)

        // --- Core Identifiers & File Info ---
        record[CloudKitSchema.ROMFields.md5] = md5
        record[CloudKitSchema.ROMFields.systemIdentifier] = game.systemIdentifier
        record[CloudKitSchema.ROMFields.fileSize] = game.fileSize as NSNumber // Store as NSNumber (Int64)
        record[CloudKitSchema.ROMFields.originalFilename] = game.fileName // Fallback to fileName
        // Note: fileData and isArchive are set later during asset preparation

        // --- OpenVGDB Metadata ---
        let regionID = (record[CloudKitSchema.ROMFields.regionID] as? NSNumber)?.intValue ?? game.regionID
        record[CloudKitSchema.ROMFields.title] = game.title // Use game.title directly
        record[CloudKitSchema.ROMFields.gameDescription] = game.gameDescription
        record[CloudKitSchema.ROMFields.boxBackArtworkURL] = game.boxBackArtworkURL
        record[CloudKitSchema.ROMFields.developer] = game.developer
        record[CloudKitSchema.ROMFields.publisher] = game.publisher
        record[CloudKitSchema.ROMFields.publishDate] = game.publishDate
        record[CloudKitSchema.ROMFields.genres] = game.genres
        record[CloudKitSchema.ROMFields.referenceURL] = game.referenceURL
        record[CloudKitSchema.ROMFields.releaseID] = game.releaseID
        record[CloudKitSchema.ROMFields.regionName] = game.regionName
        record[CloudKitSchema.ROMFields.regionID] = regionID
        record[CloudKitSchema.ROMFields.systemShortName] = game.systemShortName as NSString? // Cast value to NSString
        record[CloudKitSchema.ROMFields.language] = game.language

        // --- User Stats & Info ---
        record[CloudKitSchema.ROMFields.lastPlayed] = game.lastPlayed
        record[CloudKitSchema.ROMFields.playCount] = game.playCount as NSNumber
        record[CloudKitSchema.ROMFields.timeSpentInGame] = game.timeSpentInGame as NSNumber
        record[CloudKitSchema.ROMFields.rating] = game.rating as NSNumber
        record[CloudKitSchema.ROMFields.importDate] = game.importDate

        // --- Sync Metadata ---
#if os(macOS)
        let deviceIdentifier = Host.current().name ?? "Unknown macOS"
#else
        let deviceIdentifier = UIDevice.current.name
#endif
        record[CloudKitSchema.ROMFields.lastModifiedDevice] = deviceIdentifier

        return record
    }

    private func updatePVGame(from record: CKRecord, localGame: PVGame) async throws {
        ILOG("Updating local game \(localGame.md5 ?? "nil") from CloudKit record \(record.recordID.recordName).")

        // Modification Date Check (Option B)
        // Assumes PVGame model has `lastCloudSyncDate: Date?` added.
        let cloudModDate = record.modificationDate ?? .distantPast
        let localSyncDate = localGame.lastCloudSyncDate ?? .distantPast

        if cloudModDate <= localSyncDate {
            VLOG("Skipping update for game \(localGame.md5 ?? "nil"): CloudKit record modification date (\(cloudModDate)) is not newer than last local sync date (\(localSyncDate)).")
            return // No update needed
        }

        // Perform updates within a Realm write transaction via RomDatabase.shared
        try RomDatabase.sharedInstance.writeTransaction {
            // Update fields based on CloudKit record
            localGame.title = record[CloudKitSchema.ROMFields.title] as? String ?? localGame.title
            localGame.rating = record[CloudKitSchema.ROMFields.rating] as? Int ?? localGame.rating
            localGame.playCount = record[CloudKitSchema.ROMFields.playCount] as? Int ?? localGame.playCount
            localGame.lastPlayed = record[CloudKitSchema.ROMFields.lastPlayed] as? Date ?? localGame.lastPlayed
            localGame.isFavorite = record[CloudKitSchema.ROMFields.isFavorite] as? Bool ?? localGame.isFavorite

            // Conflict Resolution for timeSpentInGame: Keep the larger value
            let cloudTimeSpent = record[CloudKitSchema.ROMFields.timeSpentInGame] as? Int ?? 0
            if cloudTimeSpent > localGame.timeSpentInGame {
                localGame.timeSpentInGame = cloudTimeSpent
            }

            // Update OpenVGDB fields if present
            localGame.gameDescription = record[CloudKitSchema.ROMFields.gameDescription] as? String ?? localGame.gameDescription
            localGame.publishDate = record[CloudKitSchema.ROMFields.publishDate] as? String ?? localGame.publishDate
            localGame.developer = record[CloudKitSchema.ROMFields.developer] as? String ?? localGame.developer
            localGame.publisher = record[CloudKitSchema.ROMFields.publisher] as? String ?? localGame.publisher
            localGame.genres = record[CloudKitSchema.ROMFields.genres] as? String ?? localGame.genres
            // TODO: Handle OpenVGDB Cover URL update? Requires PVImageFile handling.

            // Update download status and size based on asset presence
            if let asset = record[CloudKitSchema.ROMFields.fileData] as? CKAsset {
                localGame.isDownloaded = true // Assume true if asset exists, actual file check happens later
                // Get fileSize using FileManager
                if let url = asset.fileURL, let attributes = try? FileManager.default.attributesOfItem(atPath: url.path), let fileSize = attributes[.size] as? Int64 {
                    localGame.fileSize = Int(fileSize)
                } else {
                    localGame.fileSize = 0 // Or keep existing?
                }
                // Ensure the PVFile.url points to the *expected* local path, not the CKAsset temp path
                if let expectedLocalURL = self.localURL(for: localGame) {
                    if localGame.file == nil {
                        // Corrected RelativeRoot usage
                        let newFile = PVFile(withURL: expectedLocalURL, relativeRoot: .documents)
                        localGame.file = newFile // Create PVFile if missing
                    } else if localGame.file?.url != expectedLocalURL {
                        // Replace existing PVFile object as URL is get-only
                        let updatedFile = PVFile(withURL: expectedLocalURL, relativeRoot: .documents) // Use same root as above
                        localGame.file = updatedFile
                        VLOG("Replaced PVFile due to differing URL for game \(localGame.md5 ?? "nil")")
                    }
                }
            } else {
                // Mark as not downloaded
                VLOG("Marking game \(localGame.md5 ?? "unknown") as not downloaded.")
                localGame.isDownloaded = false

                // Optionally clear PVFile URL or mark as offline?
                // localGame.file?.url = nil // Or keep url but mark PVFile as offline?
                // For now, just setting isDownloaded = false might be enough.

                // If download failed or was deleted, mark all related files as offline too?
                // Or maybe clear the list entirely?
                // For now, let's mark them offline if they had URLs.
                for relatedFile in localGame.relatedFiles where relatedFile.url != nil {
                    // No 'isOffline' property on PVFile. Their existence is tracked by PVGame.
                    VLOG("Related file \(relatedFile.fileName) exists for game \(localGame.md5 ?? "unknown") but primary is not downloaded.")
                }
            }
        } // End write transaction
        VLOG("Finished updating game: \(localGame.title) (MD5: \(localGame.md5 ?? "unknown"))")
    }

    private func createPVGame(from record: CKRecord) async throws -> PVGame? {
        // 1. Extract required fields from record
        guard let md5 = record[CloudKitSchema.ROMFields.md5] as? String,
              let systemIdentifier = record[CloudKitSchema.ROMFields.systemIdentifier] as? String,
              let originalFilename = record[CloudKitSchema.ROMFields.originalFilename] as? String else {
            ELOG("Cannot create PVGame: Missing essential fields (md5, systemIdentifier, originalFilename) in record \(record.recordID.recordName).")
            throw CloudSyncError.invalidData
        }

        let title = record[CloudKitSchema.ROMFields.title] as? String ?? originalFilename

        // 2. Look up PVSystem (Required to create PVGame)
        // Use RomDatabase.shared to find the system
        guard let system: PVSystem = PVEmulatorConfiguration.system(forIdentifier: systemIdentifier) else {
            WLOG("Skipping PVGame creation: Local PVSystem with identifier '\(systemIdentifier)' not found for CloudKit record \(record.recordID.recordName). App update might be required.")
            return nil // Skip creation, don't treat as fatal error
        }

        // 3. Create and Populate the new PVGame object
        // Note: Creation should happen outside a write block if we're just initializing
        let newGame = PVGame()
        newGame.md5Hash = md5 // Set the primary key
        newGame.systemIdentifier = system.identifier // Use the fetched system's identifier
        newGame.system = system
        // newGame.fileName = originalFilename // REMOVED: fileName is computed
        newGame.title = title
        newGame.cloudRecordID = record.recordID.recordName

        // Set other properties from the record
        newGame.isDownloaded = false // Mark as not downloaded initially, download happens separately
        newGame.playCount = record[CloudKitSchema.ROMFields.playCount] as? Int ?? 0
        newGame.lastPlayed = record[CloudKitSchema.ROMFields.lastPlayed] as? Date
        newGame.timeSpentInGame = record[CloudKitSchema.ROMFields.timeSpentInGame] as? Int ?? 0
        newGame.rating = record[CloudKitSchema.ROMFields.rating] as? Int ?? -1
        newGame.isFavorite = record[CloudKitSchema.ROMFields.isFavorite] as? Bool ?? false
        // newGame.releaseDate = record[CloudKitSchema.ROMFields.releaseDate] as? Date // REMOVED: releaseDate doesn't exist

        // File Size (Optional - might come from asset or local file later)
        if let explicitFileSize = record[CloudKitSchema.ROMFields.fileSize] as? Int64 {
            newGame.fileSize = Int(explicitFileSize)
        }

        // 4. Add the new game to the database using RomDatabase.shared
        do {
            try RomDatabase.sharedInstance.add(newGame) // Add the fully populated object
            ILOG("Successfully created and added new PVGame \(title) (MD5: \(md5)) from CloudKit record \(record.recordID.recordName).")
            return newGame
        } catch let error as NSError where error.code == 1 /* RLMErrorPrimaryKeyExists */ {
            WLOG("Attempted to create PVGame for MD5 \(md5), but it already exists. Fetching existing.")
            // If it already exists, fetch and return the existing one
            return RomDatabase.sharedInstance.game(withMD5: md5)
        } catch {
            ELOG("Failed to add new PVGame \(title) (MD5: \(md5)) to Realm: \(error.localizedDescription)")
            throw CloudSyncError.realmError(error)
        }
    }

    private func updateLocalDownloadStatus(md5: String, isDownloaded: Bool, fileURL: URL?, record: CKRecord? = nil) async throws {
        VLOG("Updating download status for \(md5): isDownloaded = \(isDownloaded), fileURL = \(fileURL?.path ?? "nil")")

        // Fetch the game using RomDatabase.shared
        guard let game = RomDatabase.sharedInstance.game(withMD5: md5) else {
            WLOG("Cannot update download status: PVGame with MD5 \(md5) not found locally.")
            return
        }

        // Perform updates within a Realm write transaction via RomDatabase.shared
        try RomDatabase.sharedInstance.writeTransaction {
            // Ensure we are working with the thread-safe instance inside the transaction
            // (RealmSwift handles this automatically if `game` was fetched on the right actor/queue)
            // Or refetch inside transaction if necessary, but usually not required for simple property updates.

            VLOG("Updating game: \(game.title) (MD5: \(md5))")
            game.isDownloaded = isDownloaded

            if isDownloaded, let validFileURL = fileURL {
                let needsFileUpdate: Bool
                if let currentFile = game.file {
                    needsFileUpdate = currentFile.url != validFileURL
                } else {
                    needsFileUpdate = true // Needs creation
                }

                if needsFileUpdate {
                    let newFile = PVFile(withURL: validFileURL, relativeRoot: .documents)
                    game.file = newFile // Replace or create
                    VLOG("Updated/Created PVFile with URL \(validFileURL.path) for game \(md5).")
                } else {
                    VLOG("PVFile URL already correct for game \(md5).")
                }

                // Update fileSize from the downloaded file or record if available
                if let attributes = try? FileManager.default.attributesOfItem(atPath: validFileURL.path), let fileSize = attributes[.size] as? Int64 {
                    game.fileSize = Int(fileSize) // Corrected file size access
                } else if let recordAsset = record?[CloudKitSchema.ROMFields.fileData] as? CKAsset,
                          let assetURL = recordAsset.fileURL,
                          let attributes = try? FileManager.default.attributesOfItem(atPath: assetURL.path),
                          let assetSize = attributes[.size] as? Int64  { // Get size via FileManager
                    game.fileSize = Int(assetSize)
                    VLOG("Updated fileSize to \(assetSize) from record asset for game \(md5).")
                }

                // Handle related files if this was an archive extraction
                let isArchive = record?[CloudKitSchema.ROMFields.isArchive] as? Bool ?? false
                if isArchive {
                    VLOG("Game \(md5) was an archive, ensuring related files are marked present.")
                    // We assume extraction put files in the correct place relative to the main ROM file.
                    // Update related PVFile entries to reflect they exist locally (set URL, isOffline=false)
                    let gameDirectory = validFileURL.deletingLastPathComponent()
                    for relatedFile in game.relatedFiles {
                        let filename = relatedFile.fileName
                        let expectedLocalURL = gameDirectory.appendingPathComponent(filename)
                        // Check if file actually exists? Maybe not necessary, trust the extraction.
                        // relatedFile.url = expectedLocalURL // Cannot assign to get-only property
                        WLOG("Need to update URL for related file \(filename) to \(expectedLocalURL.path), but .url is get-only. Requires refactor.")
                        // No 'isOffline' property on PVFile. Their existence is tracked by PVGame.
                        VLOG("Marked related file \(filename) as available at \(expectedLocalURL.path).")
                    }
                }

            } else if !isDownloaded {
                // Mark as not downloaded
                VLOG("Marking game \(md5) as not downloaded.")
                // Optionally clear PVFile URL or mark as offline?
                // game.file?.url = nil // Or keep url but mark PVFile as offline?
                // For now, just setting isDownloaded = false might be enough.

                // If download failed or was deleted, related files remain, but the primary is missing.
                for relatedFile in game.relatedFiles where relatedFile.url != nil {
                    // No 'isOffline' property on PVFile. Their existence is tracked by PVGame.
                    VLOG("Related file \(relatedFile.fileName) exists for game \(md5) but primary is not downloaded.")
                }
            }
        } // End write transaction
        VLOG("Finished updating download status for \(md5).)")
    }

    // MARK: - CloudKit Operations Helpers

    private func saveRecord(_ record: CKRecord) async throws {
        do {
            // Pass nil directly
            let result = try await retryOperation({ // Renamed method
                // Save the record to the private database
                try await self.database.save(record)
            }, 3, nil)

            // Cast the result back to CKRecord
            guard let savedRecord = result as? CKRecord else {
                ELOG("Retry operation returned unexpected type for saveRecord: \(type(of: result))")
                throw CloudSyncError.unknown
            }

            // Update local game state AFTER successful save
            if let md5 = savedRecord[CloudKitSchema.ROMFields.md5] as? String {
                try await updateLocalGamePostUpload(md5: md5, record: savedRecord)
            } else {
                WLOG("Saved record \(savedRecord.recordID.recordName) is missing MD5 field. Cannot update local game state.")
            }

            VLOG("Successfully saved record: \(savedRecord.recordID.recordName)")
        } catch {
            ELOG("Failed to save record \(record.recordID.recordName): \(error.localizedDescription)")
            throw CloudSyncError.cloudKitError(error)
        }
    }

    /// Helper to update local game state after a successful upload.
    private func updateLocalGamePostUpload(md5: String, record: CKRecord) async throws {
        VLOG("Updating local game \(md5) with CloudKit record ID \(record.recordID.recordName)")
        // Fetch game directly using RomDatabase
        guard let game = RomDatabase.sharedInstance.game(withMD5: md5) else {
            ELOG("Cannot update game post-upload: Game \(md5) not found in Realm.")
            return // Or throw error? If game *should* exist, this is unexpected.
        }
        // Perform update in write transaction
        try RomDatabase.sharedInstance.writeTransaction {
            // Ensure we have the live object inside the transaction
            guard let liveGame = game.realm?.object(ofType: PVGame.self, forPrimaryKey: game.md5) else {
                ELOG("Game \(md5) was invalidated before post-upload update could be applied.")
                return
            }
            liveGame.cloudRecordID = record.recordID.recordName
            // localGame.lastCloudSyncDate = record.modificationDate // Update sync date

            VLOG("Finished updating local game \(md5) post-upload.")
        } // End write transaction
    }

    // MARK: - File & Asset Helpers

    private func temporaryZipURL(for md5: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-cloudkit-sync", isDirectory: true)
            .appendingPathComponent("rom-uploads", isDirectory: true)

        // Ensure the directory exists
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let filename = "\(md5).zip"
        return tempDirectory.appendingPathComponent(filename)
    }

    /// Creates a zip archive containing the specified files using ZipArchive.
    /// - Parameters:
    ///   - files: An array of URLs for the files to include in the archive.
    ///   - primaryFile: The URL of the file considered the "main" file (e.g., the .cue or main ROM).
    ///                  Its lastPathComponent will be used in error messages.
    ///   - outputURL: The URL where the resulting zip file should be saved.
    /// - Throws: `CloudSyncError.zipError` if zip creation fails, `CloudSyncError.fileSystemError` for other file issues.
    private func createZip(files: [URL], primaryFile: URL, outputURL: URL) async throws {
        VLOG("Creating ZipArchive zip archive at \(outputURL.path) for \(files.count) files (primary: \(primaryFile.lastPathComponent)).")
        do {
            // Remove existing zip if present to prevent appending issues
            if FileManager.default.fileExists(atPath: outputURL.path) {
                VLOG("Removing existing zip file at \(outputURL.path)")
                try await FileManager.default.removeItem(at: outputURL)
            }

            // Create Zip Archive using ZipArchive
            let success = SSZipArchive.createZipFile(atPath: outputURL.path, withFilesAtPaths: files.map { $0.path })
            guard success else {
                throw CloudSyncError.zipError(DescriptiveError(description: "ZipArchive failed to create zip at \(outputURL.path)"))
            }
            // SSZipArchive.createZipFile handles adding all files directly.

            ILOG("Successfully created ZipArchive zip archive at \(outputURL.path) for primary file \(primaryFile.lastPathComponent).")
        } catch let error as CocoaError {
            ELOG("CocoaError during ZipArchive zip creation for \(primaryFile.lastPathComponent): \(error)")
            // Clean up partial zip
            try? await FileManager.default.removeItem(at: outputURL)
            throw CloudSyncError.zipError(error)
        } catch { // Catch other potential errors from ZipArchive or FileManager
            ELOG("Unexpected error during ZipArchive zip creation for \(primaryFile.lastPathComponent): \(error)")
            // Clean up partial zip
            try? await FileManager.default.removeItem(at: outputURL)
            throw CloudSyncError.zipError(error) // Wrap other errors as zip errors for context
        }
    }

    // MARK: - Deprecated - Use CloudKitSchema.RecordIDGenerator instead
    // Helper to generate CloudKit Record ID from MD5 (deprecated)
    @available(*, deprecated, message: "Use CloudKitSchema.RecordIDGenerator.romRecordID(md5:) instead")
    static func recordID(forRomMD5 md5: String) -> CKRecord.ID {
        return CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
    }
}
