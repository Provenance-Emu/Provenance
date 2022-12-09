//
//  BackgroundDownloadHandler.swift
//  BackgroundDownloadExtension
//
//  Created by Joseph Mattiello on 11/13/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import BackgroundAssets

@main
struct BackgroundDownloadHandler: BADownloaderExtension
{
    func downloads(for request: BAContentRequest,
                   manifestURL: URL,
                   extensionInfo: BAAppExtensionInfo) -> Set<BADownload>
    {
        // Downloads are being requested by the system.
        // The BAContextRequest argument will contain the reason downloads are requested.
        // The manifestURL will point to a read-only file that was pre-downloaded. You are
        // encouraged to use this file to determine what assets need to be downloaded.
        // The manifest that is downloaded is determined by `BAManifestURL` defined in the
        // application's `Info.plist`.
        let appGroupIdentifier = "group.org.provenance-emu.provenance"
        var downloadsToSchedule: Set<BADownload> = []
        
        // Parse the `manifestURL` to determine what assets are available that might need
        // to be scheduled.
        // Then add downloads to the set to be returned.
        // Note: The identifier should be unique and is what is used to track your download between
        // the extension and app.
        let url = URL(string: "https://example.com/large-asset.bin")!
        let download = BAURLDownload(
            identifier: "Unique-Asset-Identifier",
            request: URLRequest(url: url),
            applicationGroupIdentifier: appGroupIdentifier
        )
        
        downloadsToSchedule.insert(download)
        
        // The downloads that are returned will be downloaded automatically by the system.
        return downloadsToSchedule
    }
    
    func backgroundDownload(_ failedDownload: BADownload, failedWithError error: Error) {
        // Extension was woken because a download failed.
        // A download can be rescheduled with BADownloadManager if necessary.
    }
    
    func backgroundDownload(_ finishedDownload: BADownload, finishedWithFileURL fileURL: URL) {
        // Extension was woken because a download finished.
        // It is strongly advised to keep files in `Library/Caches` so that they may be
        // deleted when the device becomes low on storage.
    }
    
    func extensionWillTerminate()
    {
        // Extension will terminate very shortly, wrap up any remaining work with haste.
        // This is advisory only and is not guaranteed to be called before the
        // extension exits.
    }
}
