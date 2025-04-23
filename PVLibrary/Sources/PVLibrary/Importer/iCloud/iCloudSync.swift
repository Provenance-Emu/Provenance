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
import RealmSwift
import RxRealm
import RxSwift
import PVPrimitives
import PVFileSystem
import PVRealm

public enum iCloudConstants {
    public static let defaultProvenanceContainerIdentifier = "iCloud.org.provenance-emu.provenance"
    // Dynamic version based off of bundle Identifier
    public static let containerIdentifier =  (Bundle.main.infoDictionary?["NSUbiquitousContainers"] as? [String: AnyObject])?.keys.first ?? defaultProvenanceContainerIdentifier
}

public enum SyncError: Error {
    case noUbiquityURL
}

public enum SyncResult {
    case denied
    case saveFailure
    case fileNotExist
    case success
    case indeterminate
}

public protocol Container {
    var containerURL: URL? { get }
}

extension Container {
    public var containerURL: URL? { get { return URL.iCloudContainerDirectory }}
    public var documentsURL: URL? { get { return URL.iCloudDocumentsDirectory }}
}

public protocol iCloudTypeSyncer: Container, SyncProvider {
    var metadataQuery: NSMetadataQuery { get }
    var downloadedCount: Int { get async }

    func loadAllFromICloud(iterationComplete: (() async -> Void)?) async -> Completable
    func insertDownloadingFile(_ file: URL) async -> URL?
    func insertDownloadedFile(_ file: URL) async
    func insertUploadedFile(_ file: URL) async
    func deleteFromDatastore(_ file: URL) async
    func setNewCloudFilesAvailable() async
}

public enum iCloudSyncStatus {
    case initialUpload
    case filesAlreadyMoved
}

/// a useless enumeration I created because I just got so angry with the shitty way iCloud Documents deals with hundreds and thousands of files on the initial download. you can virtually hit the icloud API with your choice
enum iCloudHittingTool {
    case wrench
    case hammer
    case sledgeHammer
    case mallet
}

/// used for only purging database entries that no longer exist (files deleted from icloud while the app was shut off)
public enum DatastorePurgeStatus {
    case incomplete
    case complete
}

public enum GameStatus {
    case gameExists
    case gameDoesNotExist
}

#if !os(tvOS)
public class iCloudContainerSyncer: iCloudTypeSyncer {
    public lazy var pendingFilesToDownload: ConcurrentSet<URL> = []
    public lazy var newFiles: ConcurrentSet<URL> = []
    public lazy var uploadedFiles: ConcurrentSet<URL> = []
    public let directories: Set<String>
    public let fileManager: FileManager = .default
    public let notificationCenter: NotificationCenter
    public var status: ConcurrentSingle<iCloudSyncStatus> = .init(.initialUpload)
    public let errorHandler: SyncErrorHandler
    public var initialSyncResult: SyncResult = .indeterminate
    public var fileImportQueueMaxCount = 1000
    public var purgeStatus: DatastorePurgeStatus = .incomplete
    private var querySubscriber: AnyCancellable?
    //used for removing ROMs/Saves that were removed by the user when the application is closed. This is to ensure if this is called several times, only 1 block is used at a time
    let removeDeletionsCriticalSection: CriticalSectionActor = .init()
    public var downloadedCount: Int {
        get async {
            await newFiles.count
        }
    }
    
    public init(directories: Set<String>,
         notificationCenter: NotificationCenter,
         errorHandler: SyncErrorHandler) {
        self.notificationCenter = notificationCenter
        self.directories = directories
        self.errorHandler = errorHandler
        // Register with the syncer store
        SyncerStore.shared.register(syncer: self)
    }
    
    func stopObserving() {
        // Unregister from the syncer store
        SyncerStore.shared.unregister(syncer: self)
        metadataQuery.disableUpdates()
        if metadataQuery.isStarted {
            metadataQuery.stop()
        }
        querySubscriber?.cancel()
    }
    
    var canPurgeDatastore: Bool {
        get async {
            let arePendingFilesToDownloadEmpty = await pendingFilesToDownload.isEmpty
            let areNewFilesEmpty = await downloadedCount == 0
            let isNumberOfErrorEmpty = await errorHandler.isEmpty
            return purgeStatus == .incomplete
                && initialSyncResult == .success
                //if we have errors, it's better to just assume something happened while importing, so instead of creating a bigger mess, just NOT delete any files
                && isNumberOfErrorEmpty
                //we have to ensure that everything has been downloaded/imported before attempting to remove anything
                && arePendingFilesToDownloadEmpty
                && areNewFilesEmpty
        }
    }
    
    var alliCloudDirectories: [URL: URL]!
    var localAndCloudDirectories: [URL: URL] {
        guard alliCloudDirectories == nil
        else {
            return alliCloudDirectories
        }
        alliCloudDirectories = [URL: URL]()
        guard let parentContainer = documentsURL
        else {
            return alliCloudDirectories
        }
        directories.forEach { directory in
            alliCloudDirectories[URL.documentsDirectory.appendingPathComponent(directory)] = parentContainer.appendingPathComponent(directory)
        }
        return alliCloudDirectories
    }
    
    public let metadataQuery: NSMetadataQuery = .init()
    
    public func insertDownloadingFile(_ file: URL) async -> URL? {
        guard await !uploadedFiles.contains(file)
        else {
            return nil
        }
        await pendingFilesToDownload.insert(file)
        return file
    }
    
    public func insertDownloadedFile(_ file: URL) async {
        await pendingFilesToDownload.remove(file)
    }
    
    public func insertUploadedFile(_ file: URL) async {
        await uploadedFiles.insert(file)
    }
    
    public func setNewCloudFilesAvailable() async {
        if await pendingFilesToDownload.isEmpty {
            await status.set(value: .filesAlreadyMoved)
            await uploadedFiles.removeAll()
        }
        let uploadedCount = await uploadedFiles.count
        let statusDescription = await status.description
        DLOG("\(directories): status: \(statusDescription), uploadedFiles: \(uploadedCount)")
    }
    
    public func deleteFromDatastore(_ file: URL) async {
        //no-op
    }
    
    public func prepareNextBatchToProcess() async -> any Collection<URL> {
        var newFilesCount = await newFiles.count
        DLOG("\(directories): newFiles: (\(newFilesCount)):")
        var newFilesDescription = await newFiles.description
        DLOG("\(directories): \(newFilesDescription)")
        let nextFilesToProcess = await newFiles.prefix(fileImportQueueMaxCount)
        await newFiles.subtract(nextFilesToProcess)
        newFilesCount = await newFiles.count
        DLOG("\(directories): newFiles minus processing files: (\(newFilesCount)):")
        newFilesDescription = await newFiles.description
        DLOG("\(directories): \(newFilesDescription)")
        if await downloadedCount == 0 {
            await uploadedFiles.removeAll()
        }
        return nextFilesToProcess
    }
    
    public func loadAllFromCloud(iterationComplete: (() async -> Void)?) async -> Completable {
        await loadAllFromICloud(iterationComplete: iterationComplete)
    }
    
    public func loadAllFromICloud(iterationComplete: (() async -> Void)? = nil) async -> Completable {
        initialSyncResult = await syncToiCloud()
        return Completable.create { [weak self] completable in
            self?.setupObservers(completable: completable, iterationComplete: iterationComplete)
            return Disposables.create()
        }
    }
    
    func setupObservers(completable: PrimitiveSequenceType.CompletableObserver, iterationComplete: (() async -> Void)? = nil) {
        DLOG("\(directories) syncToiCloud result: \(initialSyncResult)")
        guard initialSyncResult != .saveFailure,
              initialSyncResult != .denied
        else {
            ELOG("error moving files to iCloud container")
            return
        }
        DLOG("directories: \(directories)")
        var predicateFormat = ""
        var predicateArgs = [CVarArg]()
        directories.forEach { directory in
            if !predicateFormat.isEmpty {
                predicateFormat += " OR "
            }
            predicateFormat += "%K CONTAINS[c] %@"
            predicateArgs.append(NSMetadataItemPathKey)
            predicateArgs.append("/Documents/\(directory)/")
        }
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = NSPredicate(format: predicateFormat, argumentArray: predicateArgs)
        let names: [NSNotification.Name] = [.NSMetadataQueryDidFinishGathering, /*listen for deletions and new files.*/.NSMetadataQueryDidUpdate]
        let publishers = names.map { notificationCenter.publisher(for: $0, object: metadataQuery) }
        querySubscriber = Publishers.MergeMany(publishers)
            .sink { [weak self] notification in
            Task {
                await self?.queryFinished(notification: notification)
                await iterationComplete?()
            }
        }
        //has to be on the main thread, otherwise it won't work
        Task { @MainActor [weak self] in
            self?.metadataQuery.start()
        }
    }
    
    func queryFinished(notification: Notification) async {
        DLOG("directories: \(directories)")
        guard (notification.object as? NSMetadataQuery) === metadataQuery,
              metadataQuery.isStarted
        else {
            return
        }
        DLOG("\(notification.name): \(directories) -> number of items: \(metadataQuery.results.count)")
        for item in metadataQuery.results {
            if metadataQuery.isStopped {
                return
            }
            if let fileItem = item as? NSMetadataItem,
               let file = fileItem.value(forAttribute: NSMetadataItemURLKey) as? URL,
               let isDirectory = try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               !isDirectory,//we only
               let downloadStatus = fileItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                let lastModified = fileItem.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
                let isDownloading = fileItem.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool ?? false
                let downloadingError = fileItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey)
                let percentDownloaded = fileItem.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double ?? 0
                let isUploaded = fileItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool
                let isUploading = fileItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool
                let doesFileExist = fileManager.fileExists(atPath: file.pathDecoded)
                DLOG("""
                \(notification.name)
                Found: \(file)
                - Download status: \(downloadStatus)
                - Last modified: \(String(describing: lastModified))
                - Is downloading: \(isDownloading)
                - Download error: \(downloadingError ?? "None")
                - Percent downloaded: \(percentDownloaded)
                - Is uploaded: \(isUploaded ?? false)
                - Is uploading: \(isUploading ?? false)
                - does file exist: \(doesFileExist)
                """)
                switch downloadStatus {
                    case  NSMetadataUbiquitousItemDownloadingStatusNotDownloaded:
                        await handleFileToDownload(file, isDownloading: isDownloading, percentDownload: percentDownloaded)
                    case NSMetadataUbiquitousItemDownloadingStatusCurrent:
                        await handleDownloadedFile(file)
                    default: ILOG("Other: \(file): download status: \(downloadStatus)")
                }
            }
        }
        let removedObjects = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey]
        if let actualRemovedObjects = removedObjects as? [NSMetadataItem] {
            DLOG("\(directories): actualRemovedObjects: (\(actualRemovedObjects.count)) \(actualRemovedObjects)")
            for item in actualRemovedObjects {
                if metadataQuery.isStopped {
                    return
                }
                if let file = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                    ILOG("file DELETED from iCloud: \(file)")
                    await deleteFromDatastore(file)
                }
            }
        }
        await setNewCloudFilesAvailable()
        let pendingFilesToDownloadCount = await pendingFilesToDownload.count
        let totalDownloadedCount = await downloadedCount
        ILOG("\(notification.name): \(directories): current iteration: files pending to be downloaded: \(pendingFilesToDownloadCount), files downloaded pending to process: \(totalDownloadedCount)")
        await hitiCloud(with: .wrench)
    }
    
    /// When there's a large library, thousands of files, but even 500+ files, the innitial download starts, but we do NOT get the events when the download completes. So we have to disable/stop and then start again and that does the trick. We only do this initially, ie the first time the user taps on the icloud switch or when the app opens for the first time and icloud is enabled. after the initial process, we don't do this because small chunks of updates work. this is essentially the equiv of hitting hardware with a wrench when it doesn't work.
    func hitiCloud(with tool: iCloudHittingTool) async {
        guard await status.value == .initialUpload
        else {
            return
        }
        DLOG("hitting iCloud with \(tool)")
        metadataQuery.disableUpdates()
        metadataQuery.stop()
        //has to be on the main thread, otherwise it won't work
        Task { @MainActor [weak self] in
            self?.metadataQuery.start()
        }
    }
    
    func handleFileToDownload(_ file: URL, isDownloading: Bool, percentDownload: Double) async {
        do {//only start download if we haven't already started
            if let fileToDownload = await insertDownloadingFile(file),
               !isDownloading || percentDownload < 100,
               //during the initial run we do NOT do any downloads otherwise we run into issues where the query gets stuck for large libraries.
               await status.value != .initialUpload {
                let secureAccess = fileToDownload.startAccessingSecurityScopedResource()
                defer {
                    if secureAccess {
                        fileToDownload.stopAccessingSecurityScopedResource()
                    }
                }
                try fileManager.startDownloadingUbiquitousItem(at: fileToDownload)
                ILOG("Download started for: \(file.pathDecoded)")
            }
        } catch {
            await errorHandler.handleError(error, file: file)
            ELOG("Failed to start download on file \(file.pathDecoded): \(error)")
        }
    }
    
    func handleDownloadedFile(_ file: URL) async {
        DLOG("item up to date: \(file)")
        if !fileManager.fileExists(atPath: file.pathDecoded) {
            WLOG("file marked as current, but does NOT exist locally. This may be a mistake, processing anyways: \(file)")
        }
        //in the case when we are initially turning on iCloud or the app is opened and coming into the foreground for the first time, we try to import any files already downloaded. this is to ensure that a downloaded file gets imported and we do this just when the icloud switch is turned on and subsequent updates only happen after they are downloaded
        if await status.value == .initialUpload {
            await insertDownloadingFile(file)
        }
        await insertDownloadedFile(file)
    }
    
    func syncToiCloud() async -> SyncResult {
        let allDirectories = localAndCloudDirectories
        guard allDirectories.count > 0
        else {
            return .denied
        }
        return .success
        //TODO: this has to be refactored so it happens initially, but this version we'll just call the move to icloud in the static function initiateDownloadOfiCloudDocumentsContainer
        /*var moveResult: SyncResult? = nil
        for (localDirectory, iCloudDirectory) in allDirectories {
            let moved = await iCloudContainerSyncer.moveFiles(at: localDirectory,
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
            }) { [weak self] destination in
                await self?.insertUploadedFile(destination)
            }
            if moved == .saveFailure {
                moveResult = .saveFailure
            }
        }
        return moveResult ?? .success*/
    }
    
    @discardableResult
    func removeFromiCloud() async -> SyncResult {
        stopObserving()
        var result: SyncResult = .indeterminate
        defer {
            ILOG("\(directories) removed from iCloud result: \(result)")
        }
        let allDirectories = localAndCloudDirectories
        guard allDirectories.count > 0
        else {
            result = .denied
            return result
        }
        var moveResult: SyncResult?
        for (localDirectory, iCloudDirectory) in allDirectories {
            let moved = await iCloudContainerSyncer.moveFiles(at: iCloudDirectory,
                                                              containerDestination: localDirectory,
                                                              logPrefix: "\(directories)",
                                                              existingClosure: { existing in
                do {
                    try fileManager.evictUbiquitousItem(at: existing)
                } catch {
                    /*
                     this usually just happens when a file is being presented on the UI (saved states image) and thus we can't remove the icloud download. In this case the icloud file wouldn't be removed locally, but the file does get copied to the local container properly. Here's a sample Error:
                     
                     Error Domain=NSCocoaErrorDomain Code=255 "The file couldn’t be locked." UserInfo={NSUnderlyingError=0x3046f1740 {Error Domain=NSPOSIXErrorDomain Code=16 "Resource busy" UserInfo={NSURL=file:///some/path/file.extension, NSLocalizedDescription=The file ‘file.extension’ is currently in use by an application.}}}
                     
                     of course there could be a real error when this happens, but this is significant enough to document in case you see it in the log.
                     */
                    await errorHandler.handleError(error, file: existing)
                    ELOG("error evicting iCloud file: \(existing), \(error)")
                }
            }, moveClosure: { currentSource, currentDestination in
                try fileManager.copyItem(at: currentSource, to: currentDestination)
                do {
                    try fileManager.evictUbiquitousItem(at: currentSource)
                } catch {//this happens when a file is being presented on the UI (saved states image) and thus we can't remove the icloud download
                    await errorHandler.handleError(error, file: currentSource)
                    ELOG("error evicting iCloud file: \(currentSource), \(error)")
                }
            })
            if moved == .saveFailure {
                moveResult = .saveFailure
            }
        }
        result = moveResult ?? .success
        return result
    }
    
    //TODO: refactor this so it's not static.
    static func moveFiles(at source: URL,
                          containerDestination: URL,
                          logPrefix: String,
                          existingClosure: ((URL) async -> Void),
                          moveClosure: (URL, URL) async throws -> Void,
                          insertUploadedFileClosure: ((URL) async -> Void)? = nil) async -> SyncResult {
        //TODO: if there a lot of files, this will take some time. we could fire off 2 threads to at least make it execute in half the time at a minimum.
        let fileManager: FileManager = .default
        let errorHandler/*: ErrorHandler*/ = CloudSyncErrorHandler.shared
        ILOG("source: \(source), destination: \(containerDestination)")
        guard fileManager.fileExists(atPath: source.pathDecoded)
        else {
            return .fileNotExist
        }
        let subdirectories: [String]
        do {
            subdirectories = try fileManager.subpathsOfDirectory(atPath: source.pathDecoded)
        } catch {
            await errorHandler.handleError(error, file: source)
            ELOG("failed to get directory contents \(source): \(error)")
            return .saveFailure
        }
        var totalMoved = 0
        DLOG("subdirectories of \(source): \(subdirectories)")
        for currentChild in subdirectories {
            let currentItem = source.appendingPathComponent(currentChild)
            
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: currentItem.pathDecoded, isDirectory: &isDirectory)
            DLOG("\(currentItem) isDirectory?\(isDirectory) exists?\(exists)")
            let destination = containerDestination.appendingPathComponent(currentChild)
            DLOG("new destination: \(destination)")
            if isDirectory.boolValue && !fileManager.fileExists(atPath: destination.pathDecoded) {
                DLOG("\(destination) does NOT exist")
                do {
                    try fileManager.createDirectory(atPath: destination.pathDecoded, withIntermediateDirectories: true)
                } catch {
                    await errorHandler.handleError(error, file: destination)
                    ELOG("error creating directory: \(destination), \(error)")
                }
            }
            if isDirectory.boolValue {
                continue
            }
            if fileManager.fileExists(atPath: destination.pathDecoded) {
                await existingClosure(currentItem)
                continue
            }
            do {
                totalMoved += 1
                DLOG("#\(totalMoved) Trying to move \(currentItem.pathDecoded) to \(destination.pathDecoded)")
                await try moveClosure(currentItem, destination)
                await insertUploadedFileClosure?(destination)
            } catch {
                await errorHandler.handleError(error, file: currentItem)
                //this could indicate no more space is left when moving to iCloud
                ELOG("#\(totalMoved) failed to move \(currentItem.pathDecoded) to \(destination.pathDecoded): \(error)")
            }
        }
        ILOG("\(logPrefix) moved a total of \(totalMoved)")
        return .success
    }
}

#endif

enum iCloudError: Error {
    case dataReadFail
}

#if !os(tvOS)
public enum iCloudSync {
    case initialAppLoad
    case appLoaded
    
    static var disposeBag: DisposeBag!
    static var gameImporter = GameImporter.shared
    static var state: iCloudSync = .initialAppLoad
    static let errorHandler: CloudSyncErrorHandler = CloudSyncErrorHandler.shared
    static var romDatabaseInitialized: AnyCancellable?
    
    public static func initICloudDocuments() {
        Task {
            for await value in Defaults.updates(.iCloudSync) {
                await iCloudSyncChanged(value)
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
        guard URL.supportsICloud else {
            ELOG("attempted to turn on iCloud, but iCloud is NOT setup on the device")
            return
        }
        ILOG("turning on iCloud")
        //reset ROMs path
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
        await initiateDownloadOfiCloudDocumentsContainer()
        disposeBag = DisposeBag()
        var nonDatabaseFileSyncer: iCloudContainerSyncer! = .init(directories: ["BIOS", "Battery States", "Screenshots", "RetroArch", "DeltaSkins"],
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
        romDatabaseInitialized?.cancel()
        await errorHandler.clear()
        disposeBag = nil
        //reset ROMs path
        gameImporter.gameImporterDatabaseService.setRomsPath(url: gameImporter.romsPath)
    }
}
#endif

/// single value DS that is thread safe
public actor ConcurrentSingle<T> {
    private var _value: T
    
    /// initially set value
    /// - Parameter value: value to set initially
    init(_ value: T) {
        self._value = value
    }
    
    /// gets current value
    var value: T {
        get {
            _value
        }
    }
    
    /// sets new value
    /// - Parameter value: value to set
    func set(value: T) {
        _value = value
    }
    
    var description: String {
        String(describing: _value)
    }
    
}

/// actor for adding locks on closures
actor CriticalSectionActor {
    /// executes closure
    /// - Parameter criticalSection: critical section code to execute
    func performWithLock(_ criticalSection: @Sendable @escaping () async -> Void) async {
        await criticalSection()
    }
}


/// Actor isolated for accessing db in background thread safely
@globalActor
actor RealmActor: GlobalActor {
    static let shared = RealmActor()
}

/// Datastore for accessing saves and anything related to saves.
actor RomsDatastore {
    private let realm: Realm
    private let fileManager: FileManager
    
    init() async throws {
        realm = await try Realm(actor: RealmActor.shared)
        fileManager = .default
    }
    
    /// queries datastore for save using id
    /// - Parameter id: primary key of save
    /// - Returns: save or nil if one exists
    @RealmActor
    func findSaveState(forPrimaryKey id: String) -> PVSaveState? {
        realm.object(ofType: PVSaveState.self, forPrimaryKey: id)
    }
    
    /// queries datastore for game that corresponds to save
    /// - Parameter save: save to use to query for game
    /// - Returns: game or nil if one exists
    @RealmActor
    func findGame(md5: String, forSave save: PVSaveState) -> PVGame? {
        // See if game is missing and set
        guard save.game?.system == nil
        else {
            return nil
        }
        return realm.object(ofType: PVGame.self, forPrimaryKey: md5)
    }
    
    /// stores game assoicated with save
    /// - Parameters:
    ///   - save: save to associate game with
    ///   - game: game to store
    @RealmActor
    func update(existingSave save: PVSaveState, with game: PVGame) async throws {
        await try realm.asyncWrite {
            save.game = game
        }
    }
    
    /// inserts a new save into datastore
    /// - Parameter save: save to create
    @RealmActor
    func create(newSave save: SaveState) async throws {
        let newSave = realm.buildSaveState(from: save)
        await try realm.asyncWrite {
            realm.add(newSave, update: .all)
        }
        DLOG("Added new save \(newSave.debugDescription)")
    }
    
    /// deletes all saves that do NOT exist in the file system, but exist in the database. this will happen when the user deletes on a different device, or outside of the app and the app is opened. the app won't get a notification in this case, we have to manually do this check
    @RealmActor
    func deleteSaveStatesRemoveWhileApplicationClosed() async throws {
        await try realm.asyncWrite {
            realm.objects(PVSaveState.self).forEach { save in
                guard let file = save.file,
                      let url = file.url
                else {
                    return
                }
                let saveUrl = url.appendingPathExtension("json").pathDecoded
                if !fileManager.fileExists(atPath: saveUrl) {
                    ILOG("save: \(saveUrl) does NOT exist, removing from datastore")
                    realm.delete(save)
                }
            }
        }
    }
    
    /// tries to delete save state from the database
    /// - Parameter file: file is used to query for the save state in the database attempt to delete
    @RealmActor
    func deleteSaveState(file: URL) async throws {
        DLOG("attempting to query PVSaveState by file: \(file)")
        let gameDirectory = file.parentPathComponent
        let savesDirectory = file.deletingLastPathComponent().parentPathComponent
        let partialPath = "\(savesDirectory)/\(gameDirectory)/\(file.lastPathComponent)"
        let imageField = NSExpression(forKeyPath: \PVSaveState.image.self).keyPath
        let partialPathField = NSExpression(forKeyPath: \PVImageFile.partialPath.self).keyPath
        let results = realm.objects(PVSaveState.self).filter(NSPredicate(format: "\(imageField).\(partialPathField) CONTAINS[c] %@", partialPath))
        DLOG("saves found: \(results.count)")
        guard let save: PVSaveState = results.first
        else {
            return
        }
        ILOG("""
        removing save: \(partialPath)
        full file: \(file)
        """)
        await try realm.asyncWrite {
            realm.delete(save)
        }
    }
    
    /// deletes all games that do NOT exist in the file system, but exist in the database. this will happen when the user deletes on a different device, or outside of the app and the app is opened. the app won't get a notification in this case, we have to manually do this check
    /// - Parameter romsPath: rull ROMs path
    @RealmActor
    func deleteGamesDeletedWhileApplicationClosed(romsPath: URL) async {
        for (_, game) in RomDatabase.gamesCache {
            let gameUrl = romsPath.appendingPathComponent(game.romPath)
            DLOG("""
            rom partial path: \(game.romPath)
            full game URL: \(gameUrl)
            """)
            guard !fileManager.fileExists(atPath: gameUrl.pathDecoded)
            else {
                continue
            }
            do {
                if let gameToDelete = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash) {
                    ILOG("\(gameUrl) does NOT exists, removing from datastore")
                    await try deleteGame(gameToDelete)
                }
            } catch {
                ELOG("error deleting \(gameUrl), \(error)")
            }
        }
    }
    
    /// tries to delete game from database
    /// - Parameter md5Hash: hash used to query for the game in the database
    @RealmActor
    func deleteGame(md5Hash: String) async throws {
        guard let game: PVGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash)
        else {
            return
        }
        ILOG("deleting \(game.file?.url) from datastore")
        try await deleteGame(game)
    }
    
    /// helper to delete saves/cheats/recentPlays/screenShots related to the game
    /// - Parameter game: game entity to delete related entities
    @RealmActor
    private func deleteGame(_ game: PVGame) async throws {
        // Make a frozen copy of the game before deletion to use for cache removal
        let frozenGame = game.freeze()
        
        await try realm.asyncWrite {
            guard !game.isInvalidated else { return }
            // Delete related objects if they exist
            if !game.saveStates.isInvalidated {
                game.saveStates.forEach { save in
                    if !save.isInvalidated {
                        realm.delete(save)
                    }
                }
            }
            if !game.cheats.isInvalidated {
                game.cheats.forEach { cheat in
                    if !cheat.isInvalidated {
                        realm.delete(cheat)
                    }
                }
            }
            if !game.recentPlays.isInvalidated {
                game.recentPlays.forEach { play in
                    if !play.isInvalidated {
                        realm.delete(play)
                    }
                }
            }
            if !game.screenShots.isInvalidated {
                game.screenShots.forEach { screenshot in
                    if !screenshot.isInvalidated {
                        realm.delete(screenshot)
                    }
                }
            }
            realm.delete(game)
            
            // Use the more efficient cache removal instead of reloading the entire cache
            RomDatabase.removeGameFromCache(frozenGame)
        }
    }
}

enum SaveStateUpdateError: Error {
    case failedToConvertToString
    case missingOpeningCurlyBrace
    case missingCoreKey
    case errorConvertingStringToBinary
}

//MARK: - iCloud syncers

#if !os(tvOS)
class iCloudSaveStateSyncer: iCloudContainerSyncer {
    let jsonDecorder = JSONDecoder()
    let processed = ConcurrentSingle<Int>(0)
    let processingState: ConcurrentSingle<ProcessingState> = .init(.idle)
    var savesDatabaseSubscriber: AnyCancellable?
    //initially when downloading, we need to keep a local cache of what has been processed. for large libraries we are pausing/stopping/starting query after an event processed. so when this happens, the saves are inserted several times and 2000 files, from the test where this happened, turned into 10k files and the app got a lot of app hangs.
    lazy var initiallyProcessedFiles: ConcurrentSet<URL> = []
    
    convenience init(notificationCenter: NotificationCenter, errorHandler: SyncErrorHandler) {
        self.init(directories: ["Save States"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        fileImportQueueMaxCount = 1
        jsonDecorder.dataDecodingStrategy = .deferredToData
        
        let publishers = [.SavesFinishedImporting, .RomDatabaseInitialized].map { notificationCenter.publisher(for: $0) }
        savesDatabaseSubscriber = Publishers.MergeMany(publishers).sink { [weak self] _ in
            Task {
                await self?.importNewSaves()
            }
        }
    }
    
    override func stopObserving() {
        super.stopObserving()
        savesDatabaseSubscriber?.cancel()
    }
    
    override func setNewCloudFilesAvailable() async {
        await super.setNewCloudFilesAvailable()
        guard await status.value == .filesAlreadyMoved
        else {
            return
        }
        await initiallyProcessedFiles.removeAll()
    }
    
    func removeSavesDeletedWhileApplicationClosed() async {
        await removeDeletionsCriticalSection.performWithLock { [weak self] in
            guard let canPurge = await self?.canPurgeDatastore,
                  canPurge
            else {
                return
            }
            defer {
                self?.purgeStatus = .complete
            }
            do {
                let romsDatastore: RomsDatastore = await try .init()
                await try romsDatastore.deleteSaveStatesRemoveWhileApplicationClosed()
            } catch {
                ELOG("error clearing saves deleted while application was closed")
            }
        }
    }
    
    override func insertDownloadedFile(_ file: URL) async {
        guard let _ = await pendingFilesToDownload.remove(file),
              await !initiallyProcessedFiles.contains(file),
              "json".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        ILOG("downloaded save file: \(file)")
        await newFiles.insert(file)
        await importNewSaves()
    }
    
    override func deleteFromDatastore(_ file: URL) async {
        guard "jpg".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        do {
            let romsDatastore: RomsDatastore = await try .init()
            await try romsDatastore.deleteSaveState(file: file)
        } catch {
            await errorHandler.handleError(error, file: file)
            ELOG("error deleting \(file) from database: \(error)")
        }
    }
    
    func getSaveFrom(_ json: URL) throws -> SaveState? {
        guard fileManager.fileExists(atPath: json.pathDecoded)
        else {
            return nil
        }
        let secureDoc = json.startAccessingSecurityScopedResource()

        defer {
            if secureDoc {
                json.stopAccessingSecurityScopedResource()
            }
        }
        
        var dataMaybe = fileManager.contents(atPath: json.pathDecoded)
        if dataMaybe == nil {
            dataMaybe = try Data(contentsOf: json, options: [.uncached])
        }
        guard let data = dataMaybe else {
            throw iCloudError.dataReadFail
        }

        DLOG("Data read \(String(describing: String(data: data, encoding: .utf8)))")
        let save: SaveState
        do {
            save = try jsonDecorder.decode(SaveState.self, from: data)
        } catch {
            save = try jsonDecorder.decode(SaveState.self, from: try getUpdatedSaveState2(from: data, json: json))
        }
        DLOG("Read JSON data at (\(json.pathDecoded)")
        return save
    }
    
    /// Attempts to fix/migrate a SaveState from 2.x to 3.x
    /// - Parameters:
    ///   - fileContents: binary of json save state
    ///   - json: URL of save state
    /// - Returns: new binary if succeeds or nil if there is any error
    func getUpdatedSaveState2(from fileContents: Data, json: URL) throws -> Data {
        guard var stringContents = String(data: fileContents, encoding: .utf8)
        else {
            ELOG("error converting \(json) to a string")
            throw SaveStateUpdateError.failedToConvertToString
        }
        if let firstCurlyBrace = stringContents.range(of: "{") {
            stringContents.insert(contentsOf: "\"isPinned\":false,\"isFavorite\":false,", at: firstCurlyBrace.upperBound)
        } else {
            ELOG("error \(json) does NOT contain an opening curly brace {")
            throw SaveStateUpdateError.missingOpeningCurlyBrace
        }
        if let range = stringContents.range(of: "\"core\":{") {
            stringContents.insert(contentsOf: "\"systems\":[],", at: range.upperBound)
        } else {
            ELOG("error \(json) does NOT contain a 'core' field")
            throw SaveStateUpdateError.missingCoreKey
        }
        guard let updated = stringContents.data(using: .utf8)
        else {
            throw SaveStateUpdateError.errorConvertingStringToBinary
        }
        return updated
    }
    
    func importNewSaves() async {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        await removeSavesDeletedWhileApplicationClosed()
        guard await !newFiles.isEmpty,
              await processingState.value == .idle
        else {
            return
        }
        let jsonFiles = await prepareNextBatchToProcess()
        guard !jsonFiles.isEmpty
        else {
            return
        }
        //process save files batch
        await processJsonFiles(jsonFiles)
    }
    
    func processJsonFiles(_ jsonFiles: any Collection<URL>) async {
        //setup processed count
        await processingState.set(value: .processing)
        var processedCount = await processed.value
        let pendingFilesToDownloadCount = await pendingFilesToDownload.count
        ILOG("Saves: downloading: \(pendingFilesToDownloadCount), processing: \(jsonFiles.count), total processed: \(processedCount)")
        for json in jsonFiles {
            do {
                await processed.set(value: await processed.value + 1)
                processedCount = await processed.value
                guard let save: SaveState = try getSaveFrom(json)
                else {
                    continue
                }
                let romsDatastore = await try RomsDatastore()
                guard let existing: PVSaveState = await romsDatastore.findSaveState(forPrimaryKey: save.id)
                else {
                    ILOG("Saves: processing: save #(\(processedCount)) \(json)")
                    await storeNewSave(save, romsDatastore, json)
                    continue
                }
                await updateExistingSave(existing, romsDatastore, save, json, processedCount)
                
            } catch {
                await errorHandler.handleError(error, file: json)
                ELOG("Decode error on \(json): \(error)")
            }
        }
        //update processed count
        await processingState.set(value: .idle)
        await removeSavesDeletedWhileApplicationClosed()
        notificationCenter.post(Notification(name: .SavesFinishedImporting))
    }
    
    func updateExistingSave(_ existing: PVSaveState, _ romsDatastore: RomsDatastore, _ save: SaveState, _ json: URL, _ processedCount: Int) async {
        guard let game = await romsDatastore.findGame(md5: save.game.md5, forSave: existing)
        else {
            return
        }
        ILOG("Saves: updating: save #(\(processedCount)) \(json)")
        do {
            await try romsDatastore.update(existingSave: existing, with: game)
        } catch {
            await errorHandler.handleError(error, file: json)
            ELOG("Failed to update game \(json): \(error)")
        }
    }
    
    func storeNewSave(_ save: SaveState, _ romsDatastore: RomsDatastore, _ json: URL) async {
        do {
            await try romsDatastore.create(newSave: save)
            if await status.value == .initialUpload {
                await initiallyProcessedFiles.insert(json)
            }
        } catch {
            await errorHandler.handleError(error, file: json)
            ELOG("error adding new save \(json): \(error)")
        }
        ILOG("Added new save \(json)")
    }
}

public class iCloudRomsSyncer: iCloudContainerSyncer {
    let gameImporter = GameImporter.shared
    let multiFileRoms: ConcurrentDictionary<String, [URL]> = [:]
    var romsDatabaseSubscriber: AnyCancellable?
    
    public override var downloadedCount: Int {
        get async {
            let multiFileRomsCount = await multiFileRoms.count
            return await newFiles.count + multiFileRomsCount
        }
    }
    
    convenience init(notificationCenter: NotificationCenter, errorHandler: CloudSyncErrorHandler) {
        self.init(directories: ["ROMs"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        fileImportQueueMaxCount = 1
        let publishers = [.RomsFinishedImporting, .RomDatabaseInitialized].map { notificationCenter.publisher(for: $0) }
        romsDatabaseSubscriber = Publishers.MergeMany(publishers).sink { [weak self] _ in
            Task {
                await self?.handleImportNewRomFiles()
            }
        }
    }
    
    override func stopObserving() {
        super.stopObserving()
        romsDatabaseSubscriber?.cancel()
    }
    
    public override func loadAllFromICloud(iterationComplete: (() async -> Void)?) async -> Completable {
         //ensure that the games are cached so we do NOT hit the database so much when checking for existence of games
         RomDatabase.reloadGamesCache()
         return await super.loadAllFromICloud(iterationComplete: iterationComplete)
     }
    
    /// The only time that we don't know if files have been deleted by the user is when it happens while the app is closed. so we have to query the db and check
    func removeGamesDeletedWhileApplicationClosed() async {
        await removeDeletionsCriticalSection.performWithLock { [weak self] in
            guard let canPurge = await self?.canPurgeDatastore,
                  canPurge
            else {
                return
            }
            await self?.handleRemoveGamesDeletedWhileApplicationClosed()
        }
    }
    
    func handleRemoveGamesDeletedWhileApplicationClosed() async {
        defer {
            purgeStatus = .complete
        }
        guard let actualDocumentsUrl = documentsURL,
              let romsDirectoryName = directories.first
        else {
            return
        }
        
        let romsPath = actualDocumentsUrl.appendingPathComponent(romsDirectoryName)
        do {
            let romsDatastore = await try RomsDatastore()
            await romsDatastore.deleteGamesDeletedWhileApplicationClosed(romsPath: romsPath)
        } catch {
            ELOG("error removing game entries that do NOT exist in the cloud container \(romsPath)")
        }
    }
    
    public override func insertDownloadedFile(_ file: URL) async {
        guard let _ = await pendingFilesToDownload.remove(file)
        else {
            return
        }
        
        let parentDirectory = file.parentPathComponent
        DLOG("attempting to add file to game import queue: \(file), parent directory: \(parentDirectory)")
        //we should only add to the import queue files that are actual ROMs, anything else can be ignored.
        guard parentDirectory.range(of: "com.provenance.",
                                    options: [.caseInsensitive, .anchored]) != nil,
              let fileName = file.lastPathComponent.removingPercentEncoding
        else {
            return
        }
        guard await getGameStatus(of: file) == .gameDoesNotExist
        else {
            DLOG("\(file) already exists in database. skipping...")
            return
        }
        ILOG("\(file) does NOT exist in database, adding to import set")
        switch file.system {
            case .Atari2600, .Atari5200, .Atari7800, .Genesis:
                await newFiles.insert(file)
            default:
                if let multiKey = file.multiFileNameKey {
                    var files = await multiFileRoms[multiKey] ?? [URL]()
                    files.append(file)
                    await multiFileRoms.set(files, forKey: multiKey)
                    //for sega cd ROMs, ignore the .brm file that is used for saves
                } else if file.system != .SegaCD || "brm".caseInsensitiveCompare(file.pathExtension) != .orderedSame {
                    await newFiles.insert(file)
                }
            }
        await handleImportNewRomFiles()
    }
    
    /// Checks if game exists in game cache
    /// - Parameter file: file to check against
    /// - Returns: whether or not game exists in game cache
    func getGameStatus(of file: URL) -> GameStatus {
        guard let (existingGame, system) = getGameFromCache(of: file),
           system.rawValue == existingGame.systemIdentifier
        else {
            return .gameDoesNotExist
        }
        return .gameExists
    }
    
    func getGameFromCache(of file: URL) -> (PVGame, SystemIdentifier)? {
        let parentDirectory = file.parentPathComponent
        guard let system = file.system,
              let parentUrl = URL(string: parentDirectory)
        else {
            DLOG("error obtaining existence of \(file) in game cache.")
            return nil
        }
        let partialPath = parentUrl.appendingPathComponent(file.fileName)
        DLOG("system: \(system), partialPath: \(partialPath)")
        let similarName = RomDatabase.altName(file, systemIdentifier: system)
        let gamesCache = RomDatabase.gamesCache
        let partialPathAsString = partialPath.absoluteString
        DLOG("partialPathAsString: \(partialPathAsString), similarName: \(similarName)")
        guard let existingGame = gamesCache[partialPathAsString] ?? gamesCache[similarName]
        else {
            return nil
        }
        return (existingGame, system)
    }
    
    public override func deleteFromDatastore(_ file: URL) async {
        guard let fileName = file.lastPathComponent.removingPercentEncoding,
              let parentDirectory = file.parentPathComponent.removingPercentEncoding
        else {
            return
        }
        do {
            guard let (existingGame, _) = getGameFromCache(of: file)
            else {
                return
            }
            let romPath = "\(parentDirectory)/\(fileName)"
            DLOG("attempting to query PVGame by romPath: \(romPath)")
            let romsDatastore = await try RomsDatastore()
            await try romsDatastore.deleteGame(md5Hash: existingGame.md5Hash)
        } catch {
            await errorHandler.handleError(error, file: file)
            ELOG("error deleting ROM \(file) from database: \(error)")
        }
    }
    
    func handleImportNewRomFiles() async {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
#if DEBUG
        await gameImporter.clearCompleted()
#endif
        await removeGamesDeletedWhileApplicationClosed()
        let arePendingFilesToDownloadEmpty = await pendingFilesToDownload.isEmpty
        let areMultiFileRomsEmpty = await multiFileRoms.isEmpty
        //we only proceed if there are actual ROMs to import
        guard await !newFiles.isEmpty//OR there are multi file ROMs to import and there are no more pending files to download. this is to ensure that we have all of the files. an improvement would be to read the cue, ccd or m3u file to know how many files correspond
                || !areMultiFileRomsEmpty && arePendingFilesToDownloadEmpty
        else {
            return
        }
        await tryToImportNewRomFiles()
    }
    
    func tryToImportNewRomFiles() async {
        //if the importer is currently importing files, we have to wait
        let importState = gameImporter.processingState
        guard importState == .idle,
              importState != .paused
        else {
            return
        }
        await importNewRomFiles()
    
    }
    
    func importNewRomFiles() async {
        var nextFilesToProcess = await prepareNextBatchToProcess()
        if nextFilesToProcess.isEmpty,
           let nextMultiFile = await multiFileRoms.first {
            nextFilesToProcess = nextMultiFile.value
            await multiFileRoms.set(nil, forKey: nextMultiFile.key)
        }
        let importPaths = [URL](nextFilesToProcess)
        await gameImporter.addImports(forPaths: importPaths)
        let pendingProcessingCount = await downloadedCount
        let pendingFilesToDownloadCount = await pendingFilesToDownload.count
        ILOG("ROMs: downloading: \(pendingFilesToDownloadCount), pending to process: \(pendingProcessingCount), processing: \(importPaths.count)")
        if await newFiles.isEmpty {
            await uploadedFiles.removeAll()
        }
        gameImporter.startProcessing()
    }
}
#endif // !os(tvOS)

// iCloudSyncError moved to SyncErrorHandler.swift

protocol Queue {
    associatedtype Entry
    var count: Int { get async }
    func enqueue(entry: Entry) async
    func dequeue() async -> Entry?
    func peek()  async-> Entry?
    func clear() async
    var allElements: [Entry] { get async }
    var isEmpty: Bool { get async }
}

public actor ConcurrentQueue<Element>: Queue, ExpressibleByArrayLiteral {
    private var collection = [Element]()
    
    public init(arrayLiteral elements: Element...) {
        collection = Array(elements)
    }
    
    public var count: Int {
        collection.count
    }
    
    public func enqueue(entry: Element) {
        collection.insert(entry, at: 0)
    }
    
    @discardableResult
    public func dequeue() -> Element? {
        guard !collection.isEmpty
        else {
            return nil
        }
        return collection.removeFirst()
    }
    
    public func peek() -> Element? {
        collection.first
    }
    
    public func clear() {
        collection.removeAll()
    }
    
    public var description: String {
        collection.description
    }
    
    public func map<T>(_ transform: (Element) throws -> T) throws -> [T] {
        try collection.map(transform)
    }
    
    public var allElements: [Element] {
        collection
    }
    
    public var isEmpty: Bool {
        collection.isEmpty
    }
}

public protocol ErrorHandler {
    var allErrorSummaries: [String] { get async throws }
    var allFullErrors: [String] { get async throws }
    var allErrors: [iCloudSyncError] { get async }
    var isEmpty: Bool { get async }
    var numberOfErrors: Int { get async }
    func handleError(_ error: Error, file: URL?) async
    func clear() async
}

extension URL {
    var system : SystemIdentifier? {
        return SystemIdentifier(rawValue: parentPathComponent)
    }
    var parentPathComponent: String {
        deletingLastPathComponent().lastPathComponent
    }
    
    var fileName: String {
        lastPathComponent.removingPercentEncoding ?? lastPathComponent
    }
    
    var multiFileNameKey: String? {
        guard "cue".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "bin".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "ccd".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "img".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "sub".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "m3u".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "mds".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "mdf".caseInsensitiveCompare(pathExtension) == .orderedSame
        else {
            return nil
        }
        let key = PVEmulatorConfiguration.stripDiscNames(fromFilename: deletingPathExtension().pathDecoded)
        DLOG("key: \(key)")
        return key
    }
}

public actor ConcurrentDictionary<Key: Hashable, Value>: ExpressibleByDictionaryLiteral,
                                                  @preconcurrency
                                                  CustomStringConvertible {
    private var dictionary: [Key: Value] = [:]
    
    public init(dictionaryLiteral elements: (Key, Value)...) {
        dictionary = Dictionary(uniqueKeysWithValues: elements)
    }
    
    public subscript(key: Key) -> Value? {
        get {
            dictionary[key]
        }
        set {
            dictionary[key] = newValue
        }
    }
    
    public func set(_ value: Value?, forKey key: Key) {
        dictionary[key] = value
    }
    
    public var first: (key: Key, value: Value)? {
        dictionary.first
    }
    
    public var isEmpty: Bool {
        dictionary.isEmpty
    }
    
    public var count: Int {
        dictionary.count
    }
    
    public var description: String {
        dictionary.description
    }
}

public actor ConcurrentSet<T: Hashable>: ExpressibleByArrayLiteral,
                                         @preconcurrency
                                         CustomStringConvertible,
                                         ObservableObject {
    public enum ConcurrentCopyOptions {
        case removeCopiedItems
        case retainCopiedItems
    }
    // MARK: - Combine Support
    
    /// Subject for publishing set changes
    private let changeSubject = PassthroughSubject<Set<T>, Never>()
    
    /// Subject for publishing count changes
    private let countSubject = CurrentValueSubject<Int, Never>(0)
    
    /// Publisher for set changes
    public var publisher: AnyPublisher<Set<T>, Never> {
        changeSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for count changes
    public var countPublisher: AnyPublisher<Int, Never> {
        countSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Properties
    private var set: Set<T>
    
    public init(arrayLiteral elements: T...) {
        set = Set(elements)
        countSubject.send(set.count)
    }
    
    public convenience init(fromSet set: Set<T>) async {
        self.init()
        await self.set.formUnion(set)
        countSubject.send(set.count)
    }
    
    func insert(_ element: T) {
        set.insert(element)
        notifyChanges()
    }
    
    func remove(_ element: T) -> T? {
        let removed = set.remove(element)
        notifyChanges()
        return removed
    }
    
    func contains(_ element: T) -> Bool {
        set.contains(element)
    }
    
    func removeAll() {
        set.removeAll()
        notifyChanges()
    }
    
    func forEach(_ body: (T) throws -> Void) rethrows {
        try set.forEach(body)
    }
    
    func prefix(_ maxLength: Int) -> Slice<Set<T>> {
        set.prefix(maxLength)
    }
    
    func subtract<S>(_ other: S) where T == S.Element, S : Sequence {
        set.subtract(other)
        notifyChanges()
    }
    
    func copy(options: ConcurrentCopyOptions) -> Set<T> {
        guard options == .removeCopiedItems
        else {
            return set
        }
        let copiedSet: Set<T> = .init(set)
        set.removeAll()
        notifyChanges()
        return copiedSet
    }
    
    func formUnion<S>(_ other: S) where T == S.Element, S : Sequence {
        set.formUnion(other)
        notifyChanges()
    }
    
    var isEmpty: Bool {
        return set.isEmpty
    }
    
    var first: T? {
        return set.first
    }
    
    var count: Int {
        return set.count
    }
    
    /// Current elements in the set as a Set
    var elements: Set<T> {
        return set
    }
    
    /// Current elements in the set as an Array
    var asArray: [T] {
        Array(set)
    }
                                             
    func enumerated() -> EnumeratedSequence<Set<T>> {
        set.enumerated()
    }
                                             
    public func makeIterator() async -> Set<T>.Iterator {
        set.makeIterator()
    }
    
    public var description: String {
        return set.description
    }

    /// Notify subscribers of changes to the set
    private func notifyChanges() {
        let currentSet = set
        let currentCount = currentSet.count
        DispatchQueue.main.async { [weak self] in
            self?.changeSubject.send(currentSet)
            self?.countSubject.send(currentCount)
        }
    }
}
