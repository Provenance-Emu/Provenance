//
//  BIOSSyncing.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import RxSwift

/// Protocol for BIOS-specific sync operations
public protocol BIOSSyncing: SyncProvider {
    /// Get the local URL for a BIOS file
    /// - Parameter filename: The BIOS filename
    /// - Returns: The local URL for the BIOS file
    func localURL(for filename: String) -> URL?
    
    /// Get the cloud URL for a BIOS file
    /// - Parameter filename: The BIOS filename
    /// - Returns: The cloud URL for the BIOS file
    func cloudURL(for filename: String) -> URL?
    
    /// Upload a BIOS file to the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: Completable that completes when the upload is done
    func uploadBIOS(filename: String) -> Completable
    
    /// Download a BIOS file from the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: Completable that completes when the download is done
    func downloadBIOS(filename: String) -> Completable
    
    /// Check if a BIOS file exists locally
    /// - Parameter filename: The BIOS filename
    /// - Returns: True if the BIOS file exists locally
    func biosExists(filename: String) -> Bool
    
    /// Check if a BIOS file exists in the cloud
    /// - Parameter filename: The BIOS filename
    /// - Returns: True if the BIOS file exists in the cloud
    func biosExistsInCloud(filename: String) -> Bool
}
