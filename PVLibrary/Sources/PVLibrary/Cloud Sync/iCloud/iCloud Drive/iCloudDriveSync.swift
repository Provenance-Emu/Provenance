//
//  iCloudSync.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 11/13/18.
//  Copyright 2018 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import Combine
import PVLogging
import PVSupport
import UIKit
import PVHashing
import RealmSwift
import RxRealm
import RxSwift
import PVPrimitives
import PVFileSystem
import PVRealm

/// a useless enumeration I created because I just got so angry with the shitty way iCloud Documents deals with hundreds and thousands of files on the initial download. you can virtually hit the icloud API with your choice
enum iCloudHittingTool {
    case wrench
    case hammer
    case sledgeHammer
    case mallet
}

public enum iCloudDriveSync {
    case initialAppLoad
    case appLoaded
    
    static var disposeBag: DisposeBag!
    static var gameImporter = GameImporter.shared
    static var state: iCloudDriveSync = .initialAppLoad
    static let errorHandler: CloudSyncErrorHandler = CloudSyncErrorHandler.shared
    static var romDatabaseInitialized: AnyCancellable?
    
    // Track whether a file recovery session is currently active
    static var isRecoverySessionActive: Bool = false
    
    // Set of files currently being recovered - used to prevent premature access
    /// Thread-safe set of files currently being recovered from iCloud
    static var filesBeingRecovered = ConcurrentSet<String>()
    
    /// Check if a file is currently being recovered from iCloud
    /// - Parameter path: The file path to check
    /// - Returns: True if the file is currently being recovered
    public static func isFileBeingRecovered(_ path: String) -> Bool {
        // Create a synchronous wrapper for the async actor-isolated method
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        
        Task {
            result = await filesBeingRecovered.contains(path)
            semaphore.signal()
        }
        
        // Wait with a short timeout to prevent deadlocks
        _ = semaphore.wait(timeout: .now() + 0.1)
        return result
    }
    
    /// Handle file recovery status check requests
    /// - Parameter notification: The notification containing the file path to check
    private static func handleFileRecoveryStatusCheck(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let path = userInfo["path"] as? String else {
            return
        }
        
        
        // Respond with the recovery status
        Task { @MainActor in
            let isBeingRecovered = await filesBeingRecovered.contains(path)
            
            NotificationCenter.default.post(
                name: .fileRecoveryStatusResponse,
                object: nil,
                userInfo: [
                    "path": path,
                    "isBeingRecovered": isBeingRecovered
                ]
            )
        }
    }
    
    public static func initICloudDocuments() {
        // Set up observer for file recovery status check requests
        NotificationCenter.default.addObserver(
            forName: .checkFileRecoveryStatus,
            object: nil,
            queue: .main
        ) { notification in
            handleFileRecoveryStatusCheck(notification)
        }
        
        // Check for files stuck in iCloud Drive at startup
        Task {
            await checkForStuckFilesInICloudDrive()
        }
        
        // Monitor iCloudSync setting changes
        Task {
            for await value in Defaults.updates(.iCloudSync) {
                await iCloudSyncChanged(value)
            }
        }
        
        // Monitor iCloudSyncMode setting changes
        Task {
            for await value in Defaults.updates(.iCloudSyncMode) {
                await iCloudSyncModeChanged(value)
            }
        }
    }
    
    static func iCloudSyncChanged(_ newValue: Bool) async {
        ILOG("new iCloudSync value: \(newValue)")
        guard newValue
        else {
            await turnOff()
            return
        }
        await turnOn()
    }
    
    /// iCloud sync disabled notification
    public static let iCloudSyncDisabled = Notification.Name("iCloudSyncDisabled")
    
    /// Notification posted when CloudKit sync starts
    public static let iCloudSyncStarted = Notification.Name("iCloudSyncStarted")
    
    /// Notification posted when CloudKit sync completes
    public static let iCloudSyncCompleted = Notification.Name("iCloudSyncCompleted")
    
    /// Notification posted when CloudKit sync fails
    public static let iCloudSyncFailed = Notification.Name("iCloudSyncFailed")
    
    /// Notification posted when a file is downloaded from iCloud
    public static let iCloudFileDownloaded = Notification.Name("iCloudFileDownloaded")
    
    /// Notification posted when a file is uploaded to iCloud
    public static let iCloudFileUploaded = Notification.Name("iCloudFileUploaded")
    
    /// Notification posted when a file is deleted from iCloud
    public static let iCloudFileDeleted = Notification.Name("iCloudFileDeleted")
    
    /// iCloud file recovery started notification
    public static let iCloudFileRecoveryStarted = Notification.Name("iCloudFileRecoveryStarted")
    
    /// iCloud file recovery progress notification
    public static let iCloudFileRecoveryProgress = Notification.Name("iCloudFileRecoveryProgress")
    
    /// iCloud file recovery completed notification
    public static let iCloudFileRecoveryCompleted = Notification.Name("iCloudFileRecoveryCompleted")
    
    /// iCloud file recovery error notification
    public static let iCloudFileRecoveryError = Notification.Name("iCloudFileRecoveryError")
    
    /// iCloud file pending recovery notification - used to track files that are still being synced
    public static let iCloudFilePendingRecovery = Notification.Name("iCloudFilePendingRecovery")
    
    /// Handle changes to the iCloudSyncMode setting
    /// - Parameter newMode: The new iCloudSyncMode value
    static func iCloudSyncModeChanged(_ newMode: iCloudSyncMode) async {
        ILOG("new iCloudSyncMode value: \(newMode.description)")
        
        // Always check for files in iCloud Drive that might need to be recovered
        if newMode.isCloudKit {
            // If switching to CloudKit, always try to recover files from iCloud Drive
            // regardless of whether sync is enabled
            await checkForStuckFilesInICloudDrive()
        }
        
        // Only process full migration if iCloud sync is enabled
        guard Defaults[.iCloudSync] else {
            DLOG("Skipping full migration because iCloud sync is disabled")
            return
        }
        
        // Handle the mode change based on the new mode
        if newMode.isCloudKit {
            // Moving from iCloud Drive to CloudKit
            await moveFilesFromiCloudDriveToLocalDocuments()
        } else if newMode.isICloudDrive {
            // Moving from CloudKit to iCloud Drive
            await moveFilesFromLocalDocumentsToiCloudDrive()
        }
    }
    
    /// Moves local app container files to the cloud container
    /// - Parameters:
    ///   - directories: directorie names to process
    ///   - parentContainer: cloud container
    /// - Returns: `success` if successful otherwise `saveFailure`
    static func moveLocalFilesToCloudContainer(directories: [String], parentContainer: URL) async {
        var alliCloudDirectories = [URL: URL]()
        directories.forEach { directory in
            alliCloudDirectories[URL.documentsDirectory.appendingPathComponent(directory)] = parentContainer.appendingPathComponent(directory)
        }
        let fileManager: FileManager = .default
        for (localDirectory, iCloudDirectory) in alliCloudDirectories {
            let _ = await iCloudContainerSyncer.moveFiles(at: localDirectory,
                                                          containerDestination: iCloudDirectory,
                                                          logPrefix: "\(directories)",
                                                          existingClosure: { existing in
                do {
                    try fileManager.removeItem(atPath: existing.pathDecoded)
                } catch {
                    await errorHandler.handleError(error, file: existing)
                    ELOG("error deleting existing file \(existing) that already exists in iCloud: \(error)")
                }
            }, moveClosure: { currentSource, currentDestination in
                try fileManager.setUbiquitous(true, itemAt: currentSource, destinationURL: currentDestination)
            })
        }
    }
    
    static func moveAllLocalFilesToCloudContainer(_ documentsDirectory: URL) async {
        ILOG("Initial Download: moving all local files to cloud container: \(documentsDirectory)")
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await moveLocalFilesToCloudContainer(directories: ["BIOS", "Battery States", "Screenshots", "RetroArch", "DeltaSkins"], parentContainer: documentsDirectory)
            }
            group.addTask {
                await moveLocalFilesToCloudContainer(directories: ["Save States"], parentContainer: documentsDirectory)
            }
            group.addTask {
                await moveLocalFilesToCloudContainer(directories: ["ROMs"], parentContainer: documentsDirectory)
            }
            await group.waitForAll()
            ILOG("Initial Download: finished moving all local files to cloud container: \(documentsDirectory)")
        }
    }
    
    /// in order to account for large libraries, we go through each directory/file and tell the iCloud API to start downloading. this way it starts and by the time we query, we can get actual events that the downloads complete. If the files are already downloaded, then a query to get the latest version will be done.
    static func initiateDownloadOfiCloudDocumentsContainer() async {
        guard let documentsDirectory = URL.iCloudDocumentsDirectory
        else {
            ELOG("Initial Download: error obtaining iCloud documents directory")
            return
        }
        await moveAllLocalFilesToCloudContainer(documentsDirectory)
        ILOG("Initial Download: initiate downloading all files...")
        let romsDirectory = documentsDirectory.appendingPathComponent("ROMs")
        let saveStatesDirectory = documentsDirectory.appendingPathComponent("Save States")
        let biosDirectory = documentsDirectory.appendingPathComponent("BIOS")
        let batteryStatesDirectory = documentsDirectory.appendingPathComponent("Battery States")
        let screenshotsDirectory = documentsDirectory.appendingPathComponent("Screenshots")
        let retroArchDirectory = documentsDirectory.appendingPathComponent("RetroArch")
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await startDownloading(directory: romsDirectory)
            }
            group.addTask {
                await startDownloading(directory: saveStatesDirectory)
            }
            group.addTask {
                await startDownloading(directory: batteryStatesDirectory)
            }
            group.addTask {
                await startDownloading(directory: biosDirectory)
            }
            group.addTask {
                await startDownloading(directory: screenshotsDirectory)
            }
            group.addTask {
                await startDownloading(directory: retroArchDirectory)
            }
            await group.waitForAll()
            ILOG("Initial Download: completed initiating downloading of all files...")
        }
    }
    
    static func startDownloading(directory: URL) async {
        ILOG("Initial Download: attempting to start downloading iCloud directory: \(directory)")
        let fileManager: FileManager = .default
        let children: [String]
        do {
            children = try fileManager.subpathsOfDirectory(atPath: directory.pathDecoded)
            ILOG("Initial Download: found \(children.count) in \(directory)")
        } catch {
            ELOG("Initial Download: error grabbing sub-directories of \(directory)")
            await errorHandler.handleError(error, file: directory)
            return
        }
        defer {
            sleep(5)
        }
        var count = 0
        for child in children {
            let currentUrl = directory.appendingPathComponent(child)
            do {
                var isDirectory: ObjCBool = false
                let doesUrlExist = try fileManager.fileExists(atPath: currentUrl.pathDecoded, isDirectory: &isDirectory)
                let downloadStatus = checkDownloadStatus(of: currentUrl)
                DLOG("""
                Initial Download:
                    doesUrlExist: \(doesUrlExist)
                    isDirectory: \(isDirectory.boolValue)
                    downloadStatus: \(downloadStatus)
                    url: \(currentUrl)
                """)
                guard !isDirectory.boolValue,
                      downloadStatus != .current
                else {
                    continue
                }
                count += 1
                let parentDirectory = currentUrl.parentPathComponent
                do {
                    try fileManager.startDownloadingUbiquitousItem(at: currentUrl)
                    DLOG("Initial Download: #\(count) downloading \(currentUrl)")
                    if count % 10 == 0 {
                        sleep(1)
                    }
                } catch {
                    ELOG("Initial Download: #\(count) error initiating download of \(currentUrl)")
                    await errorHandler.handleError(error, file: currentUrl)
                }
            } catch {
                ELOG("Initial Download: #\(count) error checking if \(currentUrl) is a directory")
            }
        }
    }
    
    static func checkDownloadStatus(of url: URL) -> URLUbiquitousItemDownloadingStatus? {
        do {
            return try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey,
                                                    .ubiquitousItemIsDownloadingKey]).ubiquitousItemDownloadingStatus
        } catch {
            ELOG("Initial Download: Error checking iCloud file status for: \(url), error: \(error)")
            return nil
        }
    }
    
    static func turnOn() async {
        guard URL.supportsICloudDrive else {
            ELOG("attempted to turn on iCloud, but iCloud is NOT setup on the device")
            
            /// Log the error to CloudSyncLogManager
            CloudSyncLogManager.shared.logSyncOperation(
                "Failed to enable iCloud sync: iCloud Drive not available on device",
                level: .error,
                operation: .initialization,
                provider: .iCloudDrive
            )
            return
        }
        ILOG("turning on iCloud")
        /// Reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
        await errorHandler.clear()
        let fm = FileManager.default
        if let currentiCloudToken = fm.ubiquityIdentityToken {
            do {
                let newTokenData = try NSKeyedArchiver.archivedData(withRootObject: currentiCloudToken, requiringSecureCoding: false)
                UserDefaults.standard.set(newTokenData, forKey: UbiquityIdentityTokenKey)
            } catch {
                await errorHandler.handleError(error, file: nil)
                ELOG("error serializing iCloud token: \(error)")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: UbiquityIdentityTokenKey)
        }
        
        // Handle file movement based on the current sync mode
        let syncMode = Defaults[.iCloudSyncMode]
        disposeBag = DisposeBag()
        
        if syncMode.isICloudDrive {
            // For iCloud Drive mode, move files to iCloud container
            await initiateDownloadOfiCloudDocumentsContainer()
            
            var nonDatabaseFileSyncer: iCloudContainerSyncer! =
                .init(directories: ["BIOS", "Battery States", "Screenshots", "RetroArch", "DeltaSkins"],
                      notificationCenter: .default,
                      errorHandler: CloudSyncErrorHandler.shared)
            
            await nonDatabaseFileSyncer.loadAllFromICloud() {
                // Refresh BIOS cache after each iteration
                DLOG("Refreshing BIOS cache after iCloud sync iteration")
                RomDatabase.reloadBIOSCache()
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing nonDatabaseFileSyncer")
                Task {
                    await nonDatabaseFileSyncer.removeFromiCloud()
                    nonDatabaseFileSyncer = nil
                }
            }.disposed(by: disposeBag)
            //wait for the ROMs database to initialize
            guard !RomDatabase.databaseInitialized
            else {
                await startSavesRomsSyncing()
                return
            }
            romDatabaseInitialized = NotificationCenter.default.publisher(for: .RomDatabaseInitialized).sink { _ in
                romDatabaseInitialized?.cancel()
                Task {
                    await startSavesRomsSyncing()
                }
            }
        }
    }
    static func startSavesRomsSyncing() async {
        var saveStateSyncer: iCloudSaveStateSyncer! = .init(notificationCenter: .default, errorHandler: CloudSyncErrorHandler.shared)
        var romsSyncer: iCloudRomsSyncer! = .init(notificationCenter: .default, errorHandler: CloudSyncErrorHandler.shared)
        //ensure user hasn't turned off icloud
        guard disposeBag != nil
        else {//in the case that the user did turn it off, then we can go ahead and just do the normal flow of turning off icloud
            await saveStateSyncer.removeFromiCloud()
            saveStateSyncer = nil
            await romsSyncer.removeFromiCloud()
            romsSyncer = nil
            return
        }
        await saveStateSyncer.loadAllFromICloud() {
            await saveStateSyncer.importNewSaves()
        }.observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing saveStateSyncer")
                Task {
                    await saveStateSyncer.removeFromiCloud()
                    saveStateSyncer = nil
                }
            }.disposed(by: disposeBag)
        await romsSyncer.loadAllFromICloud() {
            await romsSyncer.handleImportNewRomFiles()
        }.observe(on: MainScheduler.instance)
            .subscribe(onError: { error in
                ELOG(error.localizedDescription)
            }) {
                DLOG("disposing romsSyncer")
                Task {
                    await romsSyncer.removeFromiCloud()
                    romsSyncer = nil
                }
            }.disposed(by: disposeBag)
    }
    
    static func turnOff() async {
        ILOG("turning off iCloud")
        
        // Log to CloudSyncLogManager
        CloudSyncLogManager.shared.logSyncOperation(
            "Turning off iCloud sync",
            level: .info,
            operation: .initialization,
            provider: .iCloudDrive
        )
        
        romDatabaseInitialized?.cancel()
        await errorHandler.clear()
        disposeBag = nil
        
        // If we were using iCloud Drive mode, move files back to local documents
        let syncMode = Defaults[.iCloudSyncMode]
        if syncMode.isICloudDrive {
            await moveFilesFromiCloudDriveToLocalDocuments()
        }
        
        //reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
    }
    
    /// Move files from iCloud Drive to local Documents directory
    /// Used when switching from iCloud Drive mode to CloudKit mode
    // Progress tracking variables
    private static var filesProcessed = 0
    private static var totalFilesToMove = 0
    private static var totalBytesProcessed: UInt64 = 0
    private static var progressLock = NSLock()
    
    // Retry queue for files that fail with timeout errors
    private static var retryQueue: [(sourceFile: URL, destFile: URL)] = []
    private static var maxRetryAttempts = 5 // Increased from 3 to 5
    private static var currentRetryAttempt = 0
    
    // File operation queue to limit concurrent operations
    private static let fileOperationQueue = iCloudDriveFileOperationQueue(maxConcurrentOperations: 3)
    
    /// Reset progress tracking
    private static func resetProgress() {
        progressLock.lock()
        defer { progressLock.unlock() }
        filesProcessed = 0
        totalFilesToMove = 0
        totalBytesProcessed = 0
        retryQueue = []
        currentRetryAttempt = 0
    }
    
    /// Add a file to the retry queue for later processing with exponential backoff
    private static func addFileToRetryQueue(sourceFile: URL, destFile: URL, retryCount: Int = 0) {
        Task { @MainActor in
            // Only add if not already in the queue
            if !retryQueue.contains(where: { $0.sourceFile.path == sourceFile.path }) {
                retryQueue.append((sourceFile: sourceFile, destFile: destFile))
                
                DLOG("Added file to retry queue: \(sourceFile.lastPathComponent) (Queue size: \(retryQueue.count))")
                
                // Post notification about the retry queue
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: iCloudFileRecoveryProgress,
                        object: nil,
                        userInfo: [
                            "current": filesProcessed,
                            "total": totalFilesToMove,
                            "message": "\(retryQueue.count) files in retry queue",
                            "timestamp": Date()
                        ]
                    )
                }
                
                // Schedule retry with exponential backoff if this is a specific file retry
                if retryCount > 0 && retryCount < maxRetryAttempts {
                    let delay = pow(2.0, Double(retryCount))
                    DLOG("Scheduling retry for file: \(sourceFile.lastPathComponent) in \(delay) seconds (attempt \(retryCount) of \(maxRetryAttempts))")
                    
                    // Schedule the retry after the delay
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        await retryFileOperation(sourceFile: sourceFile, destFile: destFile, retryCount: retryCount)
                    }
                }
            }
        }
    }
    
    /// Retry a specific file operation with the current retry count
    private static func retryFileOperation(sourceFile: URL, destFile: URL, retryCount: Int) async {
        DLOG("Retrying file operation: \(sourceFile.lastPathComponent) (attempt \(retryCount) of \(maxRetryAttempts))")
        
        // Remove from the retry queue if it's there
        Task { @MainActor in
            retryQueue.removeAll(where: { $0.sourceFile.path == sourceFile.path })
        }
        
        // Try the operation again with a higher priority
        let success = await moveFileWithRetry(from: sourceFile, to: destFile, retryCount: retryCount)
        
        if !success && retryCount < maxRetryAttempts {
            // Add back to retry queue with incremented count if failed
            addFileToRetryQueue(sourceFile: sourceFile, destFile: destFile, retryCount: retryCount + 1)
        }
    }
    
    /// Move a file with retry logic using exponential backoff
    @discardableResult
    private static func moveFileWithRetry(from sourceFile: URL, to destFile: URL, retryCount: Int = 0) async -> Bool {
        DLOG("Moving file with retry: \(sourceFile.lastPathComponent) (attempt \(retryCount + 1) of \(maxRetryAttempts + 1))")
        
        // Ensure the file is downloaded before attempting to move it
        guard await ensureFileDownloaded(at: sourceFile) else {
            ELOG("❌ Failed to download file from iCloud: \(sourceFile.lastPathComponent)")
            return false
        }
        
        // Try to move the file
        return await moveFile(from: sourceFile, to: destFile)
    }
    
    /// Ensure a file is fully downloaded from iCloud before attempting to move it
    private static func ensureFileDownloaded(at url: URL) async -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                switch status {
                case .current, .downloaded:
                    return true
                    
                case .notDownloaded:
                    DLOG("Starting download for file: \(url.lastPathComponent)")
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    
                    // Wait for download to complete with timeout
                    return await waitForDownload(url: url, timeout: 60) // 60 second timeout
                    
                default:
                    return false
                }
            }
        } catch {
            ELOG("Error checking download status: \(error)")
        }
        
        return false
    }
    
    /// Wait for a file to be downloaded from iCloud
    private static func waitForDownload(url: URL, timeout: TimeInterval) async -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey])
                
                // If not downloading anymore or status is current/downloaded, we're done
                if let isDownloading = resourceValues.ubiquitousItemIsDownloading, !isDownloading {
                    return true
                }
                
                if let status = resourceValues.ubiquitousItemDownloadingStatus,
                   (status == .current || status == .downloaded) {
                    return true
                }
            } catch {
                // Continue waiting
            }
            
            // Wait a bit before checking again
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        ELOG("Timeout waiting for download: \(url.lastPathComponent)")
        return false
    }
    
    /// Copy a large file in chunks to avoid timeouts
    private static func copyLargeFileInChunks(from sourceFile: URL, to destFile: URL) async throws -> Bool {
        let fileManager = FileManager.default
        let chunkSize = 1024 * 1024 // 1MB chunks
        
        // Get file size
        guard let fileSize = try? fileManager.attributesOfItem(atPath: sourceFile.path)[.size] as? UInt64 else {
            throw FileOperationError.sourceFileNotFound
        }
        
        // Create destination directory if needed
        let destDir = destFile.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destDir.path) {
            do {
                try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw FileOperationError.destinationDirectoryCreationFailed
            }
        }
        
        // Create empty destination file
        if !fileManager.createFile(atPath: destFile.path, contents: nil) {
            throw FileOperationError.invalidFileHandle
        }
        
        // Open file handles
        guard let inputStream = InputStream(url: sourceFile),
              let outputStream = OutputStream(url: destFile, append: false) else {
            throw FileOperationError.invalidFileHandle
        }
        
        inputStream.open()
        outputStream.open()
        
        defer {
            inputStream.close()
            outputStream.close()
        }
        
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var totalBytesRead: UInt64 = 0
        var lastProgressUpdate = Date()
        
        while totalBytesRead < fileSize {
            let bytesRead = inputStream.read(&buffer, maxLength: chunkSize)
            
            if bytesRead <= 0 {
                if inputStream.streamError != nil {
                    throw inputStream.streamError!
                }
                break
            }
            
            let bytesWritten = outputStream.write(buffer, maxLength: bytesRead)
            if bytesWritten <= 0 {
                if outputStream.streamError != nil {
                    throw outputStream.streamError!
                }
                throw FileOperationError.chunkTransferFailed
            }
            
            totalBytesRead += UInt64(bytesRead)
            
            // Update progress every second
            if Date().timeIntervalSince(lastProgressUpdate) >= 1.0 {
                let progress = Double(totalBytesRead) / Double(fileSize)
                DLOG("Chunked file transfer progress: \(Int(progress * 100))% (\(ByteCountFormatter.string(fromByteCount: Int64(totalBytesRead), countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)))")
                lastProgressUpdate = Date()
                
                // Post progress notification
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: iCloudFileRecoveryProgress,
                        object: nil,
                        userInfo: [
                            "current": filesProcessed,
                            "total": totalFilesToMove,
                            "message": "Copying \(sourceFile.lastPathComponent): \(Int(progress * 100))%",
                            "timestamp": Date()
                        ]
                    )
                }
            }
            
            // Check for cancellation
            if Task.isCancelled {
                throw CancellationError()
            }
        }
        
        DLOG("✅ Successfully copied file in chunks: \(sourceFile.lastPathComponent)")
        return true
    }
    
    /// Process the retry queue with files that failed due to timeout
    private static func processRetryQueue() async {
        guard !retryQueue.isEmpty else { return }
        
        ILOG("Processing retry queue: \(retryQueue.count) files, attempt \(currentRetryAttempt) of \(maxRetryAttempts)")
        
        // Create a local copy of the queue to process
        let filesToRetry = retryQueue
        retryQueue = []
        
        var successCount = 0
        
        // Process each file in the retry queue
        for (sourceFile, destFile) in filesToRetry {
            DLOG("Retrying file: \(sourceFile.lastPathComponent)")
            
            // Use a more aggressive approach for retries - direct copy with longer timeout
            do {
                // Use a longer timeout for retries
                let copyTask = Task {
                    try FileManager.default.copyItem(at: sourceFile, to: destFile)
                }
                
                // Wait with an even longer timeout for retries
                let retryTimeout: UInt64 = 300_000_000_000 // 5 minutes
                try await withTimeout(timeout: retryTimeout) {
                    try await copyTask.value
                }
                
                DLOG("✅ Successfully copied file on retry: \(sourceFile.lastPathComponent)")
                successCount += 1
            } catch {
                ELOG("❌ Failed to copy file on retry: \(sourceFile.lastPathComponent) - \(error)")
                // Add back to retry queue if we haven't exceeded max attempts
                Task { @MainActor in
                    if currentRetryAttempt < maxRetryAttempts {
                        retryQueue.append((sourceFile: sourceFile, destFile: destFile))
                    }
                }
            }
        }
        
        ILOG("Retry queue processing complete: \(successCount)/\(filesToRetry.count) files succeeded")
    }
    
    /// Increment the number of files processed
    private static func incrementFilesProcessed() {
        progressLock.lock()
        defer { progressLock.unlock() }
        filesProcessed += 1
        
        // Log progress every 10 files or when it's a multiple of 5%
        if filesProcessed % 10 == 0 || (totalFilesToMove > 0 && filesProcessed * 20 % totalFilesToMove == 0) {
            let percentage = totalFilesToMove > 0 ? Double(filesProcessed) / Double(totalFilesToMove) * 100.0 : 0
            ILOG("File recovery progress: \(filesProcessed)/\(totalFilesToMove) (\(Int(percentage))%)")
            
            // Post notification for progress updates
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: iCloudFileRecoveryProgress,
                    object: nil,
                    userInfo: ["current": filesProcessed, "total": totalFilesToMove]
                )
            }
        }
    }
    
    /// Add to the total number of files to move
    private static func addToTotalFiles(_ count: Int) {
        progressLock.lock()
        defer { progressLock.unlock() }
        totalFilesToMove += count
        ILOG("Total files to move: \(totalFilesToMove)")
        
        // Post notification for initial progress
        Task { @MainActor in
            NotificationCenter.default.post(
                name: iCloudFileRecoveryProgress,
                object: nil,
                userInfo: ["current": filesProcessed, "total": totalFilesToMove]
            )
        }
    }
    
    /// Public method to manually trigger file recovery from iCloud Drive
    /// This is useful for testing and for users who want to manually trigger recovery
    public static func manuallyTriggerFileRecovery() async {
        ILOG("Manually triggering file recovery from iCloud Drive")
        // Reset the session flag first to ensure we can start a new session
        isRecoverySessionActive = false
        await moveFilesFromiCloudDriveToLocalDocuments()
    }
    
    static func moveFilesFromiCloudDriveToLocalDocuments() async {
        ILOG("Moving files from iCloud Drive to local Documents directory")
        
        // Reset progress tracking
        resetProgress()
        // Clear retry queue
        retryQueue = []
        currentRetryAttempt = 0
        
        // Only post notification if we're not already in an active recovery session
        if !iCloudDriveSync.isRecoverySessionActive {
            iCloudDriveSync.isRecoverySessionActive = true
            DLOG("Starting new file recovery session")
            
            Task { @MainActor in
                // Post notification with additional information for RetroStatusControlView
                NotificationCenter.default.post(
                    name: iCloudDriveSync.iCloudFileRecoveryStarted,
                    object: nil,
                    userInfo: [
                        "timestamp": Date(),
                        "sessionId": UUID().uuidString
                    ]
                )
            }
        } else {
            DLOG("File recovery session already active, skipping duplicate notification")
        }
        
        guard let iCloudContainer = URL.iCloudContainerDirectory else {
            ELOG("Cannot access iCloud container directory")
            return
        }
        
        // Get the Documents directory within the iCloud container
        let iCloudDocuments = iCloudContainer.appendingPathComponent("Documents")
        
        // Check if the Documents directory exists
        if !FileManager.default.fileExists(atPath: iCloudDocuments.path) {
            ELOG("iCloud Documents directory doesn't exist")
            return
        }
        
        ILOG("Using iCloud Documents path: \(iCloudDocuments.path)")
        
        let directories = ["BIOS", "Battery States", "Screenshots", "RetroArch", "DeltaSkins", "Save States", "ROMs"]
        
        // First count all files to get a total
        await countAllFiles(in: directories, iCloudContainer: iCloudDocuments)
        
        // Now move the files with progress tracking
        await withTaskGroup(of: Void.self) { group in
            for directory in directories {
                group.addTask {
                    await moveFilesFromiCloudToLocal(directory: directory, iCloudContainer: iCloudDocuments)
                }
            }
            await group.waitForAll()
        }
        
        ILOG("Completed moving files from iCloud Drive to local Documents directory (\(filesProcessed)/\(totalFilesToMove) files processed)")
        
        // Post final notification with complete progress
        NotificationCenter.default.post(
            name: iCloudFileRecoveryProgress,
            object: nil,
            userInfo: ["current": filesProcessed, "total": totalFilesToMove]
        )
        
        // Process retry queue if there are files to retry
        if !retryQueue.isEmpty && currentRetryAttempt < maxRetryAttempts {
            currentRetryAttempt += 1
            
            ILOG("Processing retry queue: \(retryQueue.count) files, attempt \(currentRetryAttempt) of \(maxRetryAttempts)")
            
            // Post notification about retry attempt
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: iCloudFileRecoveryProgress,
                    object: nil,
                    userInfo: [
                        "current": filesProcessed,
                        "total": totalFilesToMove,
                        "message": "Retrying \(retryQueue.count) failed files (attempt \(currentRetryAttempt))",
                        "timestamp": Date()
                    ]
                )
            }
            
            // Process the retry queue
            await processRetryQueue()
        }
        
        // Post notification that file recovery has completed
        // Post completion notification with additional information for RetroStatusControlView
        Task { @MainActor in
            NotificationCenter.default.post(
                name: iCloudFileRecoveryCompleted,
                object: nil,
                userInfo: [
                    "timestamp": Date(),
                    "filesProcessed": filesProcessed,
                    "totalFiles": totalFilesToMove,
                    "bytesProcessed": totalBytesProcessed,
                    "failedFiles": retryQueue.count,
                    "retryAttempts": currentRetryAttempt
                ]
            )
        }
        
        // Reset the session flag to allow future recovery sessions
        iCloudDriveSync.isRecoverySessionActive = false
    }
    
    /// Count all files in the directories to get a total for progress tracking
    private static func countAllFiles(in directories: [String], iCloudContainer: URL) async {
        ILOG("Starting to count files in \(directories.count) directories")
        
        // Track files that need to be synced vs. total files
        var totalFilesInCloud = 0
        var filesToSync = 0
        
        for directory in directories {
            let iCloudDirectory = iCloudContainer.appendingPathComponent(directory)
            DLOG("Checking directory: \(directory) at path: \(iCloudDirectory.path)")
            
            // Skip if directory doesn't exist
            if !FileManager.default.fileExists(atPath: iCloudDirectory.path) {
                DLOG("Directory doesn't exist, skipping: \(directory)")
                continue
            }
            
            // Check if directory is accessible
            do {
                let dirAttributes = try FileManager.default.attributesOfItem(atPath: iCloudDirectory.path)
                DLOG("Directory attributes for \(directory): \(dirAttributes)")
            } catch {
                ELOG("❌ Cannot access directory attributes for \(directory): \(error)")
                // Post notification with error
                NotificationCenter.default.post(
                    name: iCloudDriveSync.iCloudFileRecoveryError,
                    object: nil,
                    userInfo: ["error": "Cannot access directory attributes for \(directory): \(error)"]
                )
                continue
            }
            
            // Count files recursively
            do {
                DLOG("Starting file enumeration in \(directory)")
                if let enumerator = FileManager.default.enumerator(at: iCloudDirectory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    var count = 0
                    var needsSync = 0
                    var processedItems = 0
                    
                    for case let fileURL as URL in enumerator {
                        processedItems += 1
                        
                        if processedItems % 100 == 0 {
                            DLOG("Processed \(processedItems) items in \(directory) so far, found \(count) files (\(needsSync) need sync)")
                        }
                        
                        do {
                            var isDirectory: ObjCBool = false
                            if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                                count += 1
                                
                                // Check if file already exists locally with same attributes
                                let localPath = URL.documentsDirectory.appendingPathComponent(directory).appendingPathComponent(fileURL.lastPathComponent)
                                var needsToSync = true
                                
                                if FileManager.default.fileExists(atPath: localPath.path) {
                                    do {
                                        // Compare file sizes and modification dates
                                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                                        let destAttrs = try FileManager.default.attributesOfItem(atPath: localPath.path)
                                        
                                        let sourceSize = sourceAttrs[.size] as? Int64 ?? 0
                                        
                                        let destSize = destAttrs[.size] as? Int64 ?? 0
                                        
                                        let sourceModDate = sourceAttrs[.modificationDate] as? Date
                                        let destModDate = destAttrs[.modificationDate] as? Date
                                        
                                        // If sizes match and source isn't newer, skip the file
                                        if sourceSize == destSize &&
                                            (sourceModDate == nil || destModDate == nil ||
                                             !(sourceModDate!.timeIntervalSince(destModDate!) > 60)) { // Allow 1 minute difference
                                            needsToSync = false
                                        }
                                    } catch {
                                        // If we can't compare, assume we need to sync
                                        needsToSync = true
                                    }
                                }
                                
                                if needsToSync {
                                    needsSync += 1
                                }
                                
                                // Log every 50th file for debugging
                                if count % 50 == 0 {
                                    DLOG("Found \(count) files so far in \(directory) (\(needsSync) need sync), latest: \(fileURL.lastPathComponent)")
                                }
                            }
                        } catch {
                            ELOG("Error checking file at \(fileURL.path): \(error)")
                        }
                    }
                    
                    if count > 0 {
                        totalFilesInCloud += count
                        addToTotalFiles(needsSync) // Only count files that need syncing
                        ILOG("✅ Found \(count) files in directory: \(directory), \(needsSync) need to be synced")
                    } else {
                        DLOG("No files found in directory: \(directory)")
                    }
                } else {
                    ELOG("Could not create enumerator for directory: \(directory)")
                }
            } catch {
                ELOG("❌ Error counting files in directory \(directory): \(error)")
                // Post notification with error
                NotificationCenter.default.post(
                    name: iCloudDriveSync.iCloudFileRecoveryError,
                    object: nil,
                    userInfo: ["error": "Error counting files in \(directory): \(error)"]
                )
            }
        }
        
        ILOG("Completed counting files. Total files in iCloud: \(totalFilesInCloud), files to sync: \(totalFilesToMove)")
    }
    
    /// Move files from local Documents directory to iCloud Drive
    /// Used when switching from CloudKit mode to iCloud Drive mode
    static func moveFilesFromLocalDocumentsToiCloudDrive() async {
        ILOG("Moving files from local Documents directory to iCloud Drive")
        
        guard let iCloudContainer = URL.iCloudContainerDirectory else {
            ELOG("Cannot access iCloud container directory")
            return
        }
        
        await moveAllLocalFilesToCloudContainer(iCloudContainer)
        
        ILOG("Completed moving files from local Documents directory to iCloud Drive")
    }
    
    /// Move files from iCloud Drive to local Documents for a specific directory
    /// - Parameters:
    ///   - directory: Directory name to process
    ///   - iCloudContainer: iCloud container URL
    static func moveFilesFromiCloudToLocal(directory: String, iCloudContainer: URL) async {
        let localDirectory = URL.documentsDirectory.appendingPathComponent(directory)
        let iCloudDirectory = iCloudContainer.appendingPathComponent(directory)
        
        ILOG("Moving files from \(iCloudDirectory.path) to \(localDirectory.path)")
        
        // Reset the file operation queue for this directory
        await fileOperationQueue.clearQueue()
        
        let fileManager = FileManager.default
        
        // Check if iCloud container is accessible
        do {
            let containerAttributes = try fileManager.attributesOfItem(atPath: iCloudContainer.path)
            DLOG("iCloud container attributes: \(containerAttributes)")
        } catch {
            ELOG("❌ Cannot access iCloud container: \(error)")
            // Post notification with error
            NotificationCenter.default.post(
                name: iCloudDriveSync.iCloudFileRecoveryError,
                object: nil,
                userInfo: ["error": "Cannot access iCloud container: \(error)"]
            )
        }
        
        // Skip if iCloud directory doesn't exist
        if !fileManager.fileExists(atPath: iCloudDirectory.path) {
            DLOG("iCloud directory doesn't exist: \(iCloudDirectory.path)")
            return
        }
        
        // Check if directory is accessible
        do {
            let dirAttributes = try fileManager.attributesOfItem(atPath: iCloudDirectory.path)
            DLOG("Directory attributes for \(directory): \(dirAttributes)")
            
            // Try to list contents to verify access
            let contents = try fileManager.contentsOfDirectory(at: iCloudDirectory, includingPropertiesForKeys: nil)
            DLOG("Successfully listed \(contents.count) items in \(directory)")
        } catch {
            ELOG("❌ Cannot access directory \(directory): \(error)")
            // Post notification with error
            NotificationCenter.default.post(
                name: iCloudDriveSync.iCloudFileRecoveryError,
                object: nil,
                userInfo: ["error": "Cannot access directory \(directory): \(error)"]
            )
            return
        }
        
        // Create local directory if it doesn't exist
        if !fileManager.fileExists(atPath: localDirectory.path) {
            do {
                try fileManager.createDirectory(at: localDirectory, withIntermediateDirectories: true)
                DLOG("Created local directory: \(localDirectory.path)")
            } catch {
                ELOG("Error creating local directory \(localDirectory.path): \(error)")
                // Post notification with error
                NotificationCenter.default.post(
                    name: iCloudDriveSync.iCloudFileRecoveryError,
                    object: nil,
                    userInfo: ["error": "Error creating local directory: \(error)"]
                )
                return
            }
        }
        
        // Process all directories recursively
        await moveDirectoryContentsRecursively(from: iCloudDirectory, to: localDirectory)
    }
    
    /// Move directory contents recursively
    /// - Parameters:
    ///   - sourceDir: Source directory (iCloud)
    ///   - destDir: Destination directory (local)
    private static func moveDirectoryContentsRecursively(from sourceDir: URL, to destDir: URL) async {
        let fileManager = FileManager.default
        
        // Log the directory we're processing
        DLOG("📁 Processing directory: \(sourceDir.lastPathComponent)")
        
        // Skip if source directory doesn't exist
        guard fileManager.fileExists(atPath: sourceDir.path) else {
            ELOG("❌ Source directory doesn't exist: \(sourceDir.path)")
            // Post notification with error
            NotificationCenter.default.post(
                name: iCloudDriveSync.iCloudFileRecoveryError,
                object: nil,
                userInfo: ["error": "Source directory doesn't exist: \(sourceDir.path)"]
            )
            return
        }
        
        // Check if source directory is accessible
        do {
            let attributes = try fileManager.attributesOfItem(atPath: sourceDir.path)
            DLOG("Source directory attributes: \(attributes[.type] ?? "unknown")")
        } catch {
            ELOG("❌ Cannot access source directory attributes: \(error)")
            // Post notification with error
            NotificationCenter.default.post(
                name: iCloudDriveSync.iCloudFileRecoveryError,
                object: nil,
                userInfo: ["error": "Cannot access source directory attributes: \(error)"]
            )
            return
        }
        
        // Create destination directory if needed
        if !fileManager.fileExists(atPath: destDir.path) {
            do {
                try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
                DLOG("Created destination directory: \(destDir.path)")
            } catch {
                ELOG("❌ Error creating destination directory \(destDir.path): \(error)")
                
                // Post notification with error
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: iCloudDriveSync.iCloudFileRecoveryError,
                        object: nil,
                        userInfo: [
                            "error": "Error creating directory: \(error.localizedDescription)",
                            "path": destDir.path,
                            "timestamp": Date()
                        ]
                    )
                }
                return
            }
        }
        
        do {
            // Get all items in the directory
            DLOG("Listing contents of directory: \(sourceDir.lastPathComponent)")
            let items = try fileManager.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: [.isDirectoryKey])
            DLOG("Found \(items.count) items in directory: \(sourceDir.lastPathComponent)")
            
            // If no items, log and return
            if items.isEmpty {
                DLOG("Directory is empty: \(sourceDir.lastPathComponent)")
                return
            }
            
            // Track successful moves to avoid removing source directory if any file fails
            var allItemsProcessedSuccessfully = true
            var processedCount = 0
            
            for item in items {
                processedCount += 1
                
                // Log progress for large directories
                if items.count > 10 && (processedCount == 1 || processedCount % 10 == 0 || processedCount == items.count) {
                    DLOG("Processing item \(processedCount)/\(items.count) in \(sourceDir.lastPathComponent)")
                }
                
                do {
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                        let itemName = item.lastPathComponent
                        let destItem = destDir.appendingPathComponent(itemName)
                        
                        if isDirectory.boolValue {
                            // Handle subdirectory
                            DLOG("Processing subdirectory: \(itemName)")
                            
                            // Process subdirectory recursively
                            await moveDirectoryContentsRecursively(from: item, to: destItem)
                            
                            // Check if directory is empty before removing
                            do {
                                let remainingItems = try fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)
                                if remainingItems.isEmpty {
                                    // Remove the source directory after all contents have been moved
                                    try await fileManager.removeItem(at: item)
                                    DLOG("Removed empty source subdirectory: \(item.path)")
                                } else {
                                    DLOG("Source subdirectory not empty (\(remainingItems.count) items remain), skipping removal: \(item.path)")
                                    // Log the first few remaining items
                                    if remainingItems.count <= 5 {
                                        DLOG("Remaining items: \(remainingItems.map { $0.lastPathComponent })")
                                    } else {
                                        DLOG("First 5 remaining items: \(remainingItems.prefix(5).map { $0.lastPathComponent })")
                                    }
                                    allItemsProcessedSuccessfully = false
                                }
                            } catch {
                                ELOG("❌ Error checking or removing source subdirectory \(item.path): \(error)")
                                allItemsProcessedSuccessfully = false
                            }
                        } else {
                            // Check if file already exists locally with same attributes
                            if fileManager.fileExists(atPath: destItem.path) {
                                do {
                                    // Compare file sizes and modification dates
                                    let sourceAttrs = try fileManager.attributesOfItem(atPath: item.path)
                                    let destAttrs = try fileManager.attributesOfItem(atPath: destItem.path)
                                    
                                    let sourceSize = sourceAttrs[.size] as? Int64 ?? 0
                                    let destSize = destAttrs[.size] as? Int64 ?? 0
                                    
                                    let sourceModDate = sourceAttrs[.modificationDate] as? Date
                                    let destModDate = destAttrs[.modificationDate] as? Date
                                    
                                    // If sizes match and source isn't newer, skip the file
                                    if sourceSize == destSize &&
                                        (sourceModDate == nil || destModDate == nil ||
                                         !(sourceModDate!.timeIntervalSince(destModDate!) > 60)) { // Allow 1 minute difference
                                        
                                        DLOG("⏩ Skipping file that already exists with same attributes: \(item.lastPathComponent)")
                                        incrementFilesProcessed() // Count as processed
                                        continue
                                    } else {
                                        DLOG("📝 File exists but attributes differ, will replace: \(item.lastPathComponent)")
                                        if sourceSize != destSize {
                                            DLOG("   Size difference: iCloud=\(ByteCountFormatter.string(fromByteCount: sourceSize, countStyle: .file)), Local=\(ByteCountFormatter.string(fromByteCount: destSize, countStyle: .file))")
                                        }
                                        if let sDate = sourceModDate, let dDate = destModDate {
                                            DLOG("   Date difference: iCloud=\(sDate), Local=\(dDate)")
                                        }
                                    }
                                } catch {
                                    DLOG("⚠️ Error comparing file attributes, will process anyway: \(error)")
                                }
                            }
                            
                            // Handle file
                            let success = await moveFile(from: item, to: destItem)
                            if !success {
                                allItemsProcessedSuccessfully = false
                            }
                        }
                    } else {
                        ELOG("❌ Item no longer exists: \(item.path)")
                        allItemsProcessedSuccessfully = false
                    }
                } catch {
                    ELOG("❌ Error processing item \(item.path): \(error)")
                    allItemsProcessedSuccessfully = false
                }
            }
            
            if allItemsProcessedSuccessfully {
                DLOG("✅ Successfully processed all \(items.count) items in directory: \(sourceDir.lastPathComponent)")
            } else {
                DLOG("⚠️ Some items in directory \(sourceDir.lastPathComponent) could not be processed")
            }
        } catch {
            ELOG("❌ Error processing directory \(sourceDir.lastPathComponent): \(error)")
            // Post notification with error
            NotificationCenter.default.post(
                name: iCloudDriveSync.iCloudFileRecoveryError,
                object: nil,
                userInfo: ["error": "Error processing directory \(sourceDir.lastPathComponent): \(error)"]
            )
        }
    }
    
    /// Move a single file from iCloud to local
    /// - Parameters:
    ///   - sourceFile: Source file URL (iCloud)
    ///   - destFile: Destination file URL (local)
    /// - Returns: Whether the move was successful
    /// This method logs all file operations to CloudSyncLogManager
    @discardableResult
    static func moveFile(from sourceFile: URL, to destFile: URL) async -> Bool {
        // Track progress
        defer { incrementFilesProcessed() }
        let fileManager = FileManager.default
        
        // Log the file we're processing
        CloudSyncLogManager.shared.logSyncOperation(
            "Moving file from iCloud: \(sourceFile.lastPathComponent)",
            level: .info,
            operation: .download,
            filePath: sourceFile.path,
            provider: .iCloudDrive
        )
        DLOG("📄 Processing file: \(sourceFile.lastPathComponent)")
        
        // Check if file is in iCloud and needs to be downloaded
        do {
            let resourceValues = try sourceFile.resourceValues(forKeys: [.ubiquitousItemIsDownloadingKey, .ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsUploadedKey])
            
            let isDownloading = resourceValues.ubiquitousItemIsDownloading ?? false
            let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus
            let isUploaded = resourceValues.ubiquitousItemIsUploaded ?? true
            
            if isDownloading {
                DLOG("⏳ File is currently downloading from iCloud: \(sourceFile.lastPathComponent), status: \(downloadStatus?.rawValue ?? "unknown")")
                
                // Start download if needed
                if downloadStatus == .notDownloaded || downloadStatus == .current {
                    DLOG("Starting download for file: \(sourceFile.lastPathComponent)")
                    try fileManager.startDownloadingUbiquitousItem(at: sourceFile)
                    
                    // Wait for download to complete (with timeout)
                    let startTime = Date()
                    let timeout = 30.0 // 30 seconds timeout
                    
                    while Date().timeIntervalSince(startTime) < timeout {
                        // Check download status
                        let currentValues = try sourceFile.resourceValues(forKeys: [.ubiquitousItemIsDownloadingKey])
                        if !(currentValues.ubiquitousItemIsDownloading ?? false) {
                            DLOG("✅ File download completed: \(sourceFile.lastPathComponent)")
                            break
                        }
                        
                        // Wait a bit before checking again
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    }
                    
                    if Date().timeIntervalSince(startTime) >= timeout {
                        ELOG("⛔ Timeout waiting for file download: \(sourceFile.lastPathComponent)")
                        // Post notification with error
                        NotificationCenter.default.post(
                            name: iCloudDriveSync.iCloudFileRecoveryError,
                            object: nil,
                            userInfo: ["error": "Timeout waiting for file download: \(sourceFile.lastPathComponent)"]
                        )
                    }
                }
            } else if !isUploaded {
                ELOG("⚠️ File is not fully uploaded to iCloud yet: \(sourceFile.lastPathComponent)")
            }
        } catch {
            DLOG("Could not get iCloud status for file: \(error)")
        }
        
        // Get file size and other attributes for logging
        var fileSize: Int64 = 0
        var fileType: String = "unknown"
        var fileCreationDate: Date? = nil
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: sourceFile.path)
            fileSize = attributes[.size] as? Int64 ?? 0
            fileType = attributes[.type] as? String ?? "unknown"
            fileCreationDate = attributes[.creationDate] as? Date
            
            DLOG("File details: \(sourceFile.lastPathComponent)")
            DLOG("  - Size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            DLOG("  - Type: \(fileType)")
            if let creationDate = fileCreationDate {
                DLOG("  - Created: \(creationDate)")
            }
        } catch {
            ELOG("❌ Error getting file attributes for \(sourceFile.path): \(error)")
            // Post notification with error
            NotificationCenter.default.post(
                name: iCloudDriveSync.iCloudFileRecoveryError,
                object: nil,
                userInfo: ["error": "Error getting file attributes: \(error)"]
            )
            fileSize = 0
        }
        
        // Skip if source file doesn't exist
        guard fileManager.fileExists(atPath: sourceFile.path) else {
            ELOG("❌ Source file doesn't exist: \(sourceFile.path)")
            // Post notification with error
            NotificationCenter.default.post(
                name: iCloudDriveSync.iCloudFileRecoveryError,
                object: nil,
                userInfo: ["error": "Source file doesn't exist: \(sourceFile.path)"]
            )
            return false
        }
        
        // Add file to the recovery tracking set (thread-safe)
        Task.detached(priority: .high) {
            await filesBeingRecovered.insert(sourceFile.path)
        }
        
        // Post notification that file is being recovered
        Task { @MainActor in
            NotificationCenter.default.post(
                name: iCloudFilePendingRecovery,
                object: nil,
                userInfo: [
                    "path": sourceFile.path,
                    "filename": sourceFile.lastPathComponent,
                    "timestamp": Date()
                ]
            )
        }
        
        // Create parent directory if needed
        let destParentDir = destFile.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destParentDir.path) {
            do {
                try fileManager.createDirectory(at: destParentDir, withIntermediateDirectories: true)
                DLOG("Created parent directory: \(destParentDir.path)")
            } catch {
                ELOG("❌ Error creating parent directory \(destParentDir.path): \(error)")
                
                // Post notification with error
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: iCloudDriveSync.iCloudFileRecoveryError,
                        object: nil,
                        userInfo: [
                            "error": "Error creating directory: \(error.localizedDescription)",
                            "path": destParentDir.path,
                            "timestamp": Date()
                        ]
                    )
                }
                return false
            }
        }
        
        // Check if destination file already exists
        if fileManager.fileExists(atPath: destFile.path) {
            do {
                try await fileManager.removeItem(at: destFile)
                DLOG("Removed existing local file: \(destFile.path)")
            } catch {
                ELOG("❌ Error removing existing local file \(destFile.path): \(error)")
                // Post notification with error
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: iCloudDriveSync.iCloudFileRecoveryError,
                        object: nil,
                        userInfo: ["error": "Error removing existing local file: \(error)"]
                    )
                }
                return false
            }
        }
        
        DLOG("⏳ Starting move of file: \(sourceFile.lastPathComponent) to \(destFile.path)")
        
        // Move file from iCloud to local
        do {
            // For very small files (< 1MB), use setUbiquitous method
            // For medium files (1-10MB), use regular copy
            // For large files (> 10MB), use chunked copy
            if fileSize < 1_000_000 { // Less than 1 MB
                // Use a timeout for the move operation (only for smaller files)
                let moveTask = Task {
                    try fileManager.setUbiquitous(false, itemAt: sourceFile, destinationURL: destFile)
                }
                
                // Wait for the move with a timeout
                let timeout: UInt64 = 60_000_000_000 // 60 seconds for small files
                do {
                    try await withTimeout(timeout: timeout) {
                        try await moveTask.value
                    }
                    DLOG("✅ Successfully moved file from iCloud to local: \(sourceFile.lastPathComponent)")
                    
                    // Remove file from recovery tracking set (thread-safe)
                    Task.detached(priority: .high) {
                        await filesBeingRecovered.remove(sourceFile.path)
                    }
                    
                    // Log success to CloudSyncLogManager
                    CloudSyncLogManager.shared.logSyncOperation(
                        "Successfully moved file from iCloud: \(sourceFile.lastPathComponent)",
                        level: .info,
                        operation: .download,
                        filePath: destFile.path,
                        provider: .iCloudDrive
                    )
                    
                    return true
                } catch is TimeoutError {
                    ELOG("⛔ Timeout moving file: \(sourceFile.lastPathComponent)")
                    // Cancel the task
                    moveTask.cancel()
                    
                    // Post notification with timeout error
                    Task { @MainActor in
                        NotificationCenter.default.post(
                            name: iCloudDriveSync.iCloudFileRecoveryProgress,
                            object: nil,
                            userInfo: [
                                "current": filesProcessed,
                                "total": totalFilesToMove,
                                "message": "Timeout moving file, trying copy method: \(sourceFile.lastPathComponent)",
                                "timestamp": Date()
                            ]
                        )
                    }
                    // Fall through to try copying instead
                } catch {
                    ELOG("❌ Error moving file from iCloud to local \(sourceFile.lastPathComponent): \(error)")
                    
                    // Post notification with error
                    Task { @MainActor in
                        NotificationCenter.default.post(
                            name: iCloudDriveSync.iCloudFileRecoveryError,
                            object: nil,
                            userInfo: [
                                "error": "Error moving file: \(error.localizedDescription)",
                                "path": sourceFile.path,
                                "timestamp": Date()
                            ]
                        )
                    }
                    // Fall through to try copying instead
                }
            } else if fileSize > 10_000_000 { // Greater than 10 MB - use chunked copy
                DLOG("Large file detected (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))), using chunked file transfer")
                do {
                    // Use chunked file transfer for large files
                    let success = try await copyLargeFileInChunks(from: sourceFile, to: destFile)
                    
                    if success {
                        DLOG("✅ Successfully copied large file in chunks: \(sourceFile.lastPathComponent)")
                        
                        // Remove the source file after successful copy
                        do {
                            try await fileManager.removeItem(at: sourceFile)
                            DLOG("Removed source file after chunked copying: \(sourceFile.path)")
                        } catch {
                            ELOG("Error removing source file after chunked copying \(sourceFile.path): \(error)")
                            // Still return true since the file was copied successfully
                        }
                        
                        // Remove file from recovery tracking set (thread-safe)
                        Task.detached(priority: .high) {
                            await filesBeingRecovered.remove(sourceFile.path)
                        }
                        
                        // Log success to CloudSyncLogManager
                        CloudSyncLogManager.shared.logSyncOperation(
                            "Successfully copied large file from iCloud: \(sourceFile.lastPathComponent)",
                            level: .info,
                            operation: .download,
                            filePath: destFile.path,
                            provider: .iCloudDrive
                        )
                        
                        return true
                    }
                } catch {
                    ELOG("❌ Error during chunked file transfer for \(sourceFile.lastPathComponent): \(error)")
                    
                    // Post notification with error
                    Task { @MainActor in
                        NotificationCenter.default.post(
                            name: iCloudDriveSync.iCloudFileRecoveryError,
                            object: nil,
                            userInfo: [
                                "error": "Error during chunked file transfer: \(error.localizedDescription)",
                                "path": sourceFile.path,
                                "timestamp": Date()
                            ]
                        )
                    }
                    
                    // Fall through to try regular copy as a last resort
                }
            } else {
                // Medium-sized files (1-10MB) - use regular copy directly
                DLOG("Medium-sized file detected (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))), using regular copy method")
                // Fall through to regular copy method below
            }
            
            // Try regular copying as fallback or for medium-sized files
            do {
                DLOG("Attempting to copy file: \(sourceFile.lastPathComponent)")
                
                // Use a timeout for the copy operation
                let copyTask = Task {
                    try fileManager.copyItem(at: sourceFile, to: destFile)
                }
                
                // Wait for the copy with a timeout - adjust based on file size
                let copyTimeout: UInt64 = min(UInt64(fileSize / 50000) + 30_000_000_000, 180_000_000_000) // 30-180 seconds based on file size
                do {
                    try await withTimeout(timeout: copyTimeout) {
                        try await copyTask.value
                    }
                    DLOG("✅ Successfully copied file from iCloud to local: \(sourceFile.lastPathComponent)")
                    
                    // Remove file from recovery tracking set (thread-safe)
                    Task.detached(priority: .high) {
                        await filesBeingRecovered.remove(sourceFile.path)
                    }
                    
                    // Log success to CloudSyncLogManager
                    CloudSyncLogManager.shared.logSyncOperation(
                        "Successfully copied file from iCloud: \(sourceFile.lastPathComponent)",
                        level: .info,
                        operation: .download,
                        filePath: destFile.path,
                        provider: .iCloudDrive
                    )
                    
                    // Post notification that file was recovered
                    NotificationCenter.default.post(
                        name: iCloudDriveSync.iCloudFileDownloaded,
                        object: nil,
                        userInfo: ["fileURL": destFile]
                    )
                    
                    // Remove the iCloud file after successful copy
                    do {
                        try await fileManager.removeItem(at: sourceFile)
                        DLOG("Removed source file after copying: \(sourceFile.path)")
                        return true
                    } catch {
                        ELOG("Error removing source file after copying \(sourceFile.path): \(error)")
                        // Still return true since the file was copied successfully
                        return true
                    }
                } catch is TimeoutError {
                    ELOG("⛔ Timeout copying file: \(sourceFile.lastPathComponent)")
                    // Cancel the task
                    copyTask.cancel()
                    
                    // Post notification with timeout error
                    Task { @MainActor in
                        NotificationCenter.default.post(
                            name: iCloudDriveSync.iCloudFileRecoveryError,
                            object: nil,
                            userInfo: [
                                "error": "Timeout copying file",
                                "path": sourceFile.path,
                                "filename": sourceFile.lastPathComponent,
                                "timestamp": Date()
                            ]
                        )
                    }
                    
                    // Add to retry queue with exponential backoff
                    addFileToRetryQueue(sourceFile: sourceFile, destFile: destFile, retryCount: 1)
                    return false
                } catch {
                    ELOG("❌ Error copying file from iCloud to local \(sourceFile.lastPathComponent): \(error)")
                    
                    // Log the error to CloudSyncLogManager
                    CloudSyncLogManager.shared.logSyncOperation(
                        "Failed to copy file from iCloud: \(sourceFile.lastPathComponent) - Error: \(error.localizedDescription)",
                        level: .error,
                        operation: .error,
                        filePath: sourceFile.path,
                        provider: .iCloudDrive
                    )
                    
                    // Check if the error is a directory not found error
                    var nsError = error as NSError
                    if nsError.domain == NSCocoaErrorDomain && nsError.code == 4 {
                        // Try to create the directory and retry
                        let destDir = destFile.deletingLastPathComponent()
                        DLOG("Attempting to create missing directory: \(destDir.path)")
                        
                        do {
                            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
                            DLOG("Created directory, retrying copy operation")
                            
                            // Retry the copy operation
                            try fileManager.copyItem(at: sourceFile, to: destFile)
                            DLOG("✅ Successfully copied file after creating directory: \(sourceFile.lastPathComponent)")
                            return true
                        } catch {
                            ELOG("❌ Failed to create directory or retry copy: \(error)")
                        }
                    }
                    
                    // Post notification with error
                    Task { @MainActor in
                        NotificationCenter.default.post(
                            name: iCloudDriveSync.iCloudFileRecoveryError,
                            object: nil,
                            userInfo: [
                                "error": "Error copying file: \(error.localizedDescription)",
                                "path": sourceFile.path,
                                "filename": sourceFile.lastPathComponent,
                                "timestamp": Date()
                            ]
                        )
                    }
                    
                    // Add to retry queue with appropriate retry strategy based on error type
                    let nsErrorForAnalysis = error as NSError
                    
                    // For timeout errors (POSIX error 60), add the file to a retry queue with exponential backoff
                    if nsErrorForAnalysis.domain == NSPOSIXErrorDomain && nsErrorForAnalysis.code == 60 {
                        DLOG("Adding file to retry queue due to timeout: \(sourceFile.lastPathComponent)")
                        addFileToRetryQueue(sourceFile: sourceFile, destFile: destFile, retryCount: 1)
                    }
                    // For permission errors, try again with a delay
                    else if nsErrorForAnalysis.domain == NSCocoaErrorDomain &&
                                (nsErrorForAnalysis.code == 513 || nsErrorForAnalysis.code == 257) {
                        DLOG("Adding file to retry queue due to permission error: \(sourceFile.lastPathComponent)")
                        addFileToRetryQueue(sourceFile: sourceFile, destFile: destFile, retryCount: 1)
                    }
                    // For other errors, add to retry queue without specific retry count
                    else {
                        addFileToRetryQueue(sourceFile: sourceFile, destFile: destFile)
                    }
                    
                    return false
                }
            } catch {
                ELOG("❌ Unexpected error handling file \(sourceFile.lastPathComponent): \(error)")
                // Post notification with error
                NotificationCenter.default.post(
                    name: iCloudDriveSync.iCloudFileRecoveryError,
                    object: nil,
                    userInfo: ["error": "Unexpected error: \(error)"]
                )
                return false
            }
        }
    }
    
    /// Check for files stuck in iCloud Drive and recover them if needed
    /// This helps users recover files even if sync is disabled
    public static func checkForStuckFilesInICloudDrive() async {
        ILOG("Checking for files stuck in iCloud Drive that need recovery")
        
        // Only proceed if we're not using iCloud Drive mode
        let syncMode = Defaults[.iCloudSyncMode]
        guard syncMode.isCloudKit else {
            DLOG("Not checking for stuck files because we're in iCloud Drive mode")
            return
        }
        
        // Check if iCloud Drive is accessible
        guard let iCloudContainer = URL.iCloudContainerDirectory else {
            ELOG("Cannot access iCloud container directory to check for stuck files")
            return
        }
        
        // Get the Documents directory within the iCloud container
        let iCloudDocuments = iCloudContainer.appendingPathComponent("Documents")
        
        DLOG("Checking iCloud container path: \(iCloudContainer.path)")
        DLOG("Checking iCloud Documents path: \(iCloudDocuments.path)")
        
        // Check if the Documents directory exists
        if !FileManager.default.fileExists(atPath: iCloudDocuments.path) {
            DLOG("iCloud Documents directory doesn't exist")
            return
        }
        
        // Check if there are any files in the iCloud Drive directories
        let directories = ["BIOS", "Battery States", "Screenshots", "RetroArch", "DeltaSkins", "Save States", "ROMs"]
        var hasStuckFiles = false
        var stuckFilesCount = 0
        
        for directory in directories {
            let iCloudDirectory = iCloudDocuments.appendingPathComponent(directory)
            DLOG("Checking directory: \(iCloudDirectory.path)")
            
            // Skip if directory doesn't exist
            if !FileManager.default.fileExists(atPath: iCloudDirectory.path) {
                DLOG("Directory doesn't exist: \(iCloudDirectory.path)")
                continue
            }
            
            // Check directory recursively for all directories
            do {
                // Use recursive enumeration to get all files
                if let enumerator = FileManager.default.enumerator(at: iCloudDirectory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    var filesInDir = 0
                    for case let fileURL as URL in enumerator {
                        var isDirectory: ObjCBool = false
                        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                            // Log the file path for debugging
                            DLOG("Found file in iCloud Drive: \(fileURL.path)")
                            filesInDir += 1
                            stuckFilesCount += 1
                            hasStuckFiles = true
                        }
                    }
                    if filesInDir > 0 {
                        DLOG("Found \(filesInDir) files in directory: \(directory)")
                    }
                }
            } catch {
                ELOG("Error recursively checking directory \(directory): \(error)")
            }
        }
        
        // If we found stuck files, offer to recover them
        if hasStuckFiles {
            ILOG("Found \(stuckFilesCount) files stuck in iCloud Drive. Attempting recovery...")
            
            // Move files from iCloud Drive to local Documents
            // This will handle the start notification internally
            await moveFilesFromiCloudDriveToLocalDocuments()
            
            // Notify the user that recovery is complete
            // Post completion notification with additional information for RetroStatusControlView
            NotificationCenter.default.post(
                name: iCloudDriveSync.iCloudFileRecoveryCompleted,
                object: nil,
                userInfo: [
                    "timestamp": Date(),
                    "filesProcessed": filesProcessed,
                    "totalFiles": totalFilesToMove,
                    "bytesProcessed": totalBytesProcessed
                ]
            )
            
            // Reset the session flag to allow future recovery sessions
            iCloudDriveSync.isRecoverySessionActive = false
            
            // Reset the session flag
            iCloudDriveSync.isRecoverySessionActive = false
            
            ILOG("File recovery from iCloud Drive completed")
        } else {
            DLOG("No stuck files found in iCloud Drive")
        }
    }
}
