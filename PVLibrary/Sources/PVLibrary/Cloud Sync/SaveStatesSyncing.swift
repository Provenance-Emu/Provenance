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
    /// - Parameters:
    ///   - saveState: The save state to download
    ///   - isUserInitiated: When `true`, callers signal that the request came from
    ///     a direct user action (save selector, push handler, queued download) and
    ///     must not be silently skipped. Backends that yield to active emulation
    ///     (CloudKit) should bypass the yield when `true`.
    /// - Returns: Completable that completes when the download is done
    func downloadSaveState(for saveState: PVSaveState, isUserInitiated: Bool) -> Completable
}

public extension SaveStatesSyncing {
    /// Default-parameter shim so existing call sites that don't care about
    /// origin (bulk sweeps) keep compiling unchanged.
    func downloadSaveState(for saveState: PVSaveState) -> Completable {
        downloadSaveState(for: saveState, isUserInitiated: false)
    }
}
