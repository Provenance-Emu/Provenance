//
//  SyncProvider.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import RxSwift
import PVPrimitives

/// Common protocol for cloud sync providers
/// Allows for different implementations on different platforms
public protocol SyncProvider: AnyObject {
    /// Directories this provider is responsible for syncing
    var directories: Set<String> { get }
    
    /// Files pending download
    var pendingFilesToDownload: ConcurrentSet<URL> { get }
    
    /// New files discovered
    var newFiles: ConcurrentSet<URL> { get }
    
    /// Files that have been uploaded
    var uploadedFiles: ConcurrentSet<URL> { get }
    
    /// Current sync status
    var status: iCloudSyncStatus { get set }
    
    /// Result of initial sync
    var initialSyncResult: SyncResult { get set }
    
    /// Maximum number of files to import in a queue
    var fileImportQueueMaxCount: Int { get set }
    
    /// Status of datastore purge
    var purgeStatus: DatastorePurgeStatus { get set }
    
    /// Load all files from cloud storage
    /// - Parameter iterationComplete: Callback when iteration is complete
    /// - Returns: Completable that completes when all files are loaded
    func loadAllFromCloud(iterationComplete: (() -> Void)?) -> Completable
    
    /// Insert a file that is being downloaded
    /// - Parameter file: URL of the file
    /// - Returns: URL of the file or nil if already being uploaded
    func insertDownloadingFile(_ file: URL) -> URL?
    
    /// Insert a file that has been downloaded
    /// - Parameter file: URL of the file
    func insertDownloadedFile(_ file: URL)
    
    /// Insert a file that has been uploaded
    /// - Parameter file: URL of the file
    func insertUploadedFile(_ file: URL)
    
    /// Delete a file from the datastore
    /// - Parameter file: URL of the file
    func deleteFromDatastore(_ file: URL)
    
    /// Notify that new cloud files are available
    func setNewCloudFilesAvailable()
    
    /// Prepare the next batch of files to process
    /// - Returns: Collection of URLs to process
    func prepareNextBatchToProcess() -> any Collection<URL>
}
