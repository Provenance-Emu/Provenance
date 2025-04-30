//
//  iCloudDriveSaveStatesSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import RxSwift
import PVPrimitives
import PVFileSystem
import PVRealm
import RealmSwift
import CloudKit

// MARK: - iOS/macOS Implementation

#if !os(tvOS)
/// Save states syncer for iOS/macOS using iCloud Documents
public class iCloudDriveSaveStatesSyncer: iCloudContainerSyncer, SaveStatesSyncing {
    /// Initialize a new save states syncer
    /// - Parameters:
    ///   - notificationCenter: Notification center to use
    ///   - errorHandler: Error handler to use
    public init(notificationCenter: NotificationCenter = .default, errorHandler: CloudSyncErrorHandler) {
        super.init(directories: ["Saves"], notificationCenter: notificationCenter, errorHandler: errorHandler)
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
    /// - Returns: The cloud URL for the save state file
    public func cloudURL(for saveState: PVSaveState) -> URL? {
        guard let file = saveState.file,
              let url = file.url,
              let containerURL = documentsURL else {
            return nil
        }
        
        let systemPath = (saveState.game.systemIdentifier as NSString)
        let systemDir = systemPath.components(separatedBy: "/").last ?? systemPath as String
        return containerURL
            .appendingPathComponent("Saves")
            .appendingPathComponent(systemDir)
            .appendingPathComponent(url.lastPathComponent)
    }
    
    /// Upload a save state to the cloud
    /// - Parameter saveState: The save state to upload
    /// - Returns: Completable that completes when the upload is done
    public func uploadSaveState(for saveState: PVSaveState) -> Completable {
        return Completable.create { [weak self] observer in
            Task {
                guard let self = self,
                      let localURL = self.localURL(for: saveState),
                      let cloudURL = self.cloudURL(for: saveState) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save state file or URLs"])))
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
                    
                    DLOG("Uploaded save state to iCloud: \(cloudURL.lastPathComponent)")
                    observer(.completed)
                } catch {
                    ELOG("Failed to upload save state: \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
    }
    
    /// Download a save state from the cloud
    /// - Parameter saveState: The save state to download
    /// - Returns: Completable that completes when the download is done
    public func downloadSaveState(for saveState: PVSaveState) -> Completable {
        return Completable.create { [weak self] observer in
            Task {
                guard let self = self,
                      let cloudURL = self.cloudURL(for: saveState) else {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid save state file or URLs"])))
                    return
                }
                
                // Check if file exists in iCloud
                if !FileManager.default.fileExists(atPath: cloudURL.path) {
                    observer(.error(NSError(domain: "com.provenance-emu.provenance", code: 2, userInfo: [NSLocalizedDescriptionKey: "Save state not found in iCloud"])))
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
                                await self.insertDownloadedFile(cloudURL)
                                DLOG("Downloaded save state from iCloud: \(cloudURL.lastPathComponent)")
                                observer(.completed)
                            }
                        }, onError: { error in
                            ELOG("Failed to download save state: \(error.localizedDescription)")
                            observer(.error(error))
                        })
                } catch {
                    ELOG("Failed to start downloading save state: \(error.localizedDescription)")
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
    }
}
#endif
