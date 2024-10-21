//
//  MetadataMonitor.swift
//  
//
//  Created by Drew McCormack on 10/06/2022.
//

import Foundation
import os

/// Monitors changes to the metadata, to trigger downloads of new files or updates.
final class MetadataMonitor: @unchecked Sendable {
    
    let rootDirectory: URL
    let fileManager: FileManager = .init()
        
    private var metadataQuery: NSMetadataQuery?
    
    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: metadataQuery)
        
        nonisolated(unsafe) let query = metadataQuery
        Task { @MainActor in
            guard let query else { return }
            query.disableUpdates()
            query.stop()
        }
    }
    
    func startMonitoringMetadata() {
        // Predicate that queries which files are in the cloud, not local, and need to begin downloading
        let predicate: NSPredicate = NSPredicate(format: "%K = %@ AND %K = FALSE AND %K BEGINSWITH %@", NSMetadataUbiquitousItemDownloadingStatusKey, NSMetadataUbiquitousItemDownloadingStatusNotDownloaded, NSMetadataUbiquitousItemIsDownloadingKey, NSMetadataItemPathKey, rootDirectory.path)
        
        metadataQuery = NSMetadataQuery()
        guard let metadataQuery else { fatalError() }
        
        metadataQuery.notificationBatchingInterval = 3.0
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDataScope, NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = predicate
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMetadataNotification(_:)), name: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMetadataNotification(_:)), name: .NSMetadataQueryDidUpdate, object: metadataQuery)

        nonisolated(unsafe) let query = metadataQuery
        Task { @MainActor in
            query.start()
        }
    }
    
    @objc private func handleMetadataNotification(_ notif: Notification) {
        let urls = updatedURLsInMetadataQuery()
        for url in urls {
            do {
                try fileManager.startDownloadingUbiquitousItem(at: url)
            } catch {
                os_log("Failed to start downloading file")
            }
        }
    }
    
    private func updatedURLsInMetadataQuery() -> [URL] {
        guard let metadataQuery = metadataQuery else { fatalError() }
        
        metadataQuery.disableUpdates()
        
        guard let results = metadataQuery.results as? [NSMetadataItem] else { return [] }
        let urls = results.compactMap { item in
            item.value(forAttribute: NSMetadataItemURLKey) as? URL
        }
        
        metadataQuery.enableUpdates()
        
        return urls
    }
    
}
