//
//  iCloudContainerSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import RxSwift
import Combine

public class iCloudContainerSyncer: iCloudTypeSyncer {

    public let directories: Set<String>
    public let errorHandler: SyncErrorHandler
    public let fileManager: FileManager = .default
    public let notificationCenter: NotificationCenter

    public var fileImportQueueMaxCount = 5000
    public var initialSyncResult: SyncResult = .indeterminate
    public var purgeStatus: DatastorePurgeStatus = .incomplete
    public var status: ConcurrentSingle<iCloudSyncStatus> = .init(.initialUpload)

    public lazy var newFiles: ConcurrentSet<URL> = []
    public lazy var pendingFilesToDownload: ConcurrentSet<URL> = []
    public lazy var uploadedFiles: ConcurrentSet<URL> = []

    private var querySubscriber: AnyCancellable?

    /// Used for removing ROMs/Saves that were removed by the user when the application is closed.
    /// This is to ensure if this is called several times, only 1 block is used at a time
    let removeDeletionsCriticalSection: CriticalSectionActor = .init()

    public var downloadedCount: Int {
        get async {
            await newFiles.count
        }
    }
    
    public init(directories: Set<String>,
                notificationCenter: NotificationCenter = .default,
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
