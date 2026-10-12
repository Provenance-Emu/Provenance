//
//  PickedFolderCloudWatcher.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  An iCloud Drive folder picked as the library: iCube or iFly may add files that arrive as cloud-only
//  placeholders. The query starts their download under the shared folders and asks for a rescan when
//  anything changes (D17). Nothing here runs for a local folder or on tvOS.
//

import Foundation
import PVFileSystem
import PVLogging

public final class PickedFolderCloudWatcher: @unchecked Sendable {
    public static let shared = PickedFolderCloudWatcher()

    #if !os(tvOS)
    private var query: NSMetadataQuery?
    private var root: URL?
    private var onChange: (@MainActor () -> Void)?
    #endif

    private init() {}

    /// Only the shared folders: a placeholder under the saves folders belongs to another app's cores.
    static func shouldDownload(relativePath: String) -> Bool {
        LibraryMoveFolders.isShared(partialPath: relativePath)
    }

    #if !os(tvOS)
    /// Items below `rootPath`. The trailing slash keeps `/x/Lib` from matching a sibling like `/x/Library`.
    static func predicate(rootPath: String) -> NSPredicate {
        NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }
    #endif

    /// Starts watching when the library is a picked folder that lives in iCloud Drive. Safe to call more than once.
    @MainActor
    public func startIfNeeded(onChange: @escaping @MainActor () -> Void) {
        #if !os(tvOS)
        guard query == nil, LibraryLocation.current == .pickedFolder, let root = LibraryLocation.pickedFolderAtLaunch.url,
              (try? root.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true else { return }
        self.root = root
        self.onChange = onChange
        let query = NSMetadataQuery()
        query.notificationBatchingInterval = 3
        query.searchScopes = [NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope, NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = Self.predicate(rootPath: root.standardizedFileURL.path)
        NotificationCenter.default.addObserver(self, selector: #selector(handle(_:)), name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(handle(_:)), name: .NSMetadataQueryDidUpdate, object: query)
        self.query = query
        query.start()
        ILOG("PickedFolderCloudWatcher: watching \(root.lastPathComponent)")
        #endif
    }

    #if !os(tvOS)
    @objc private func handle(_ notification: Notification) {
        guard let query, let root else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        var started = 0
        for case let item as NSMetadataItem in query.results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                  let relative = LibraryMovePlanner.relativePath(of: url, under: root), Self.shouldDownload(relativePath: relative),
                  let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String,
                  status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded else { continue }
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                started += 1
            } catch {
                WLOG("PickedFolderCloudWatcher: could not start downloading \(relative): \(error.localizedDescription)")
            }
        }
        if started > 0 { ILOG("PickedFolderCloudWatcher: started \(started) downloads") }
        let change = onChange
        Task { @MainActor in change?() }
    }
    #endif
}
