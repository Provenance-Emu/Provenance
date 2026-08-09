//
//  NSNotification+Library.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import Foundation

// For Obj-C
public extension NSNotification {
    @objc
    static var PVGameImporterFinishedNotification: NSString { "kGameImporterFinishedNotification" }

    // Library Notifications
    @objc
    static var PVRefreshLibraryNotification: NSString {
        return "kRefreshLibraryNotification"
    }
}

public extension Notification.Name {
    static let PVResetLibrary = Notification.Name("kResetLibraryNotification")
    static let PVReimportLibrary = Notification.Name("kReimportLibraryNotification")
    static let PVRefreshLibrary = Notification.Name("kRefreshLibraryNotification")
    static let PVRefreshLibraryFinished = Notification.Name("kRefreshLibraryFinishedNotification") // Added for refresh completion
    static let PVInterfaceDidChangeNotification = Notification.Name("kInterfaceDidChangeNotification")
    
    // Progress notification names
    static let cacheManagementProgress = Notification.Name("CacheManagementProgress")
    static let downloadProgress = Notification.Name("DownloadProgress")
    static let romScanningProgress = Notification.Name("ROMScanningProgress")
    static let romScanningCompleted = Notification.Name("ROMScanningCompleted")
    
    // Web server upload notifications
    static let webServerUploadProgress = Notification.Name("WebServerUploadProgress")
    static let webServerUploadCompleted = Notification.Name("WebServerUploadCompleted")
    static let webServerStatusChanged = Notification.Name("WebServerStatusChanged")
    
    // PVWebServer file upload notifications
    static let webServerFileUploadStarted = Notification.Name("PVWebServerFileUploadStartedNotification")
    static let webServerFileUploadProgress = Notification.Name("PVWebServerFileUploadProgressNotification")
    static let webServerFileUploadCompleted = Notification.Name("PVWebServerFileUploadCompletedNotification")
    static let webServerFileUploadFailed = Notification.Name("PVWebServerFileUploadFailedNotification")
    
    // Archive extraction notifications
    static let archiveExtractionStarted = Notification.Name("ArchiveExtractionStarted")
    static let archiveExtractionProgress = Notification.Name("ArchiveExtractionProgress")
    static let archiveExtractionCompleted = Notification.Name("ArchiveExtractionCompleted")
    static let archiveExtractionFailed = Notification.Name("ArchiveExtractionFailed")

    /// Cross-mode "open Settings" request (Mac ⌘, menu command, deep links, etc.).
    /// NOTE: several pre-existing posters/observers still use the raw string literal
    /// "PVShowSettings" directly (SceneCoordinator, HomeView, PVRootViewController,
    /// NoConsolesView, ConsoleGamesView) — this constant was added alongside the
    /// macOS-desktop-polish work and is only used at the sites that branch touched.
    /// Migrating the pre-existing sites is a separate, out-of-scope cleanup.
    static let pvShowSettings = Notification.Name("PVShowSettings")
}
