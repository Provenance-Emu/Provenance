//
//  SaveStatesSyncing.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import RxSwift

/// Protocol for save state-specific sync operations
public protocol SaveStatesSyncing: SyncProvider {
    /// Get the local URL for a save state
    /// - Parameter saveState: The save state to get the URL for
    /// - Returns: The local URL for the save state file
    func localURL(for saveState: PVSaveState) -> URL?
    
    /// Get the cloud URL for a save state
    /// - Parameter saveState: The save state to get the URL for
    /// - Returns: The cloud URL for the save state file
    func cloudURL(for saveState: PVSaveState) -> URL?
    
    /// Upload a save state to the cloud
    /// - Parameter saveState: The save state to upload
    /// - Returns: Completable that completes when the upload is done
    func uploadSaveState(for saveState: PVSaveState) -> Completable
    
    /// Download a save state from the cloud
    /// - Parameter saveState: The save state to download
    /// - Returns: Completable that completes when the download is done
    func downloadSaveState(for saveState: PVSaveState) -> Completable
}
