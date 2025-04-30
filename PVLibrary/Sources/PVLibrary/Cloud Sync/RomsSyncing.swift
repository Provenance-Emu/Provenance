//
//  RomsSyncing.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import RxSwift

/// Protocol for ROM-specific sync operations
public protocol RomsSyncing: SyncProvider {
    /// Get the local URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The local URL for the ROM file
    func localURL(for game: PVGame) -> URL?
    
    /// Get the cloud URL for a ROM file
    /// - Parameter game: The game to get the URL for
    /// - Returns: The cloud URL for the ROM file
    func cloudURL(for game: PVGame) -> URL?
    
    /// Upload a ROM file to the cloud
    /// - Parameter game: The game to upload
    /// - Returns: Completable that completes when the upload is done
    func uploadROM(for game: PVGame) -> Completable
    
    /// Download a ROM file from the cloud
    /// - Parameter game: The game to download
    /// - Returns: Completable that completes when the download is done
    func downloadROM(for game: PVGame) -> Completable
}
