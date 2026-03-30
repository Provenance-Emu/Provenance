//
//  BIOSSyncing.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import RxSwift
import PVPrimitives
import PVSystems

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

/// Protocol for syncing files in `System/<name>/` subdirectories.
///
/// Complements `BIOSSyncing` for non-BIOS system data (fonts, firmware,
/// machine ROMs) that live in the per-console `System/` tree rather than
/// the `BIOS/` tree.  Paths use the `SystemIdentifier.systemDirectoryName`
/// short name (e.g. `"PSP"`, `"NDS"`, `"DC"`) as the first path component.
///
/// Part of Epic #3577 — System directory infrastructure.
public protocol SystemFileSyncing: SyncProvider {
    /// Returns the on-device URL for a file in `System/<name>/<filename>`.
    ///
    /// - Parameters:
    ///   - system:    The console whose system directory should be used.
    ///   - filename:  Filename (or relative sub-path) within that directory.
    /// - Returns: Local URL, or `nil` when the system has no dedicated directory.
    func localSystemURL(forSystem system: SystemIdentifier, filename: String) -> URL?

    /// Returns the iCloud URL for a file in `System/<name>/<filename>`.
    ///
    /// - Parameters:
    ///   - system:    The console whose system directory should be used.
    ///   - filename:  Filename (or relative sub-path) within that directory.
    /// - Returns: Cloud URL, or `nil` when the system has no dedicated directory
    ///            or no iCloud container is available.
    func cloudSystemURL(forSystem system: SystemIdentifier, filename: String) -> URL?

    /// Upload a file from `System/<name>/<filename>` to iCloud.
    func uploadSystemFile(system: SystemIdentifier, filename: String) -> Completable

    /// Download a file from iCloud into `System/<name>/<filename>`.
    func downloadSystemFile(system: SystemIdentifier, filename: String) -> Completable

    /// Returns `true` when `System/<name>/<filename>` exists on device.
    func systemFileExists(system: SystemIdentifier, filename: String) -> Bool

    /// Returns `true` when `System/<name>/<filename>` exists in iCloud.
    func systemFileExistsInCloud(system: SystemIdentifier, filename: String) -> Bool
}
