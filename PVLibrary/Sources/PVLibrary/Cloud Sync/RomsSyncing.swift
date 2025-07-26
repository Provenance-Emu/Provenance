//
//  RomsSyncing.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

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
    /// - Parameter md5: The game to upload
    /// - Throws: CloudSyncError on failure
    func uploadGame(_ md5: String) async throws
    
    /// Download a ROM file from the cloud
    /// - Parameter game: The game to download
    /// - Throws: CloudSyncError on failure
    func downloadGame(md5: String) async throws
    
    /// Mark a game as deleted in the cloud storage.
    /// - Parameter md5: The MD5 hash of the game to mark as deleted.
    /// - Throws: CloudSyncError on failure
    func markGameAsDeleted(md5: String) async throws
}
