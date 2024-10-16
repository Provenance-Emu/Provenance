//
//  CommonSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/13/24.
//

import Foundation
import SwiftCloudDrive

public protocol CommonSyncer {
    var relativeRootPath: RootRelativePath { get }
    func sync() async throws
}

public extension CommonSyncer {
    var containerIdentifier: String { "iCloud.org.provenance-emu.provenance" }
    public var storage: CloudDrive.Storage {
        return .iCloudContainer(containerIdentifier: containerIdentifier)
    }
}

public func isICloudFile(_ url: URL) -> Bool {
    do {
        let resourceValues = try url.resourceValues(forKeys: [.isUbiquitousItemKey])
        return resourceValues.isUbiquitousItem ?? false
    } catch {
        print("Error checking if file is in iCloud: \(error)")
        return false
    }
}

public func needsDownload(_ url: URL) -> Bool {
    do {
        let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemIsDownloadingKey, .ubiquitousItemDownloadingStatusKey])
        
        if resourceValues.ubiquitousItemDownloadingStatus == .notDownloaded {
            return true
        }
        
        if resourceValues.ubiquitousItemIsDownloading ?? false {
            return true
        }
        
        return false
    } catch {
        print("Error checking if file needs download: \(error)")
        return true // Assume it needs download if we can't determine
    }
}

public func downloadFileIfNeeded(_ url: URL) async throws {
    guard isICloudFile(url) else {
        return // Not an iCloud file, no need to download
    }
    
    if needsDownload(url) {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                
                // Set up a file coordinator to be notified when the download is complete
                let coordinator = NSFileCoordinator(filePresenter: nil)
                coordinator.coordinate(readingItemAt: url, options: [.withoutChanges], error: nil) { newURL in
                    continuation.resume()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
