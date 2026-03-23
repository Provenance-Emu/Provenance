/// PVGame+DragExport.swift
/// Shared drag-export helper for ROM files across all game-cell views.
#if !os(tvOS) && !os(watchOS)
import Foundation
import PVLibrary

extension PVGame {
    /// Creates an `NSItemProvider` for dragging this ROM file to Files.app / AirDrop.
    ///
    /// - Returns an empty provider when the ROM URL is unavailable.
    /// - Returns an empty provider when the file is iCloud-evicted (detected via a synchronous
    ///   `url.resourceValues(forKeys:)` call on the calling thread); also enqueues a background
    ///   download via `Task.detached` so the next attempt may succeed.
    /// - Relies on `NSItemProvider(contentsOf:)` for the actual file-availability check;
    ///   returns an empty provider when the file cannot be opened.
    func romDragProvider() -> NSItemProvider {
        guard let url = file?.url else {
            return NSItemProvider()
        }

        // Detect iCloud-evicted placeholders and kick off a background restore.
        if let resourceValues = try? url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ]),
           resourceValues.isUbiquitousItem == true,
           resourceValues.ubiquitousItemDownloadingStatus == .notDownloaded {
            // Proactively trigger a re-download so the next drag attempt can succeed.
            Task.detached(priority: .background) {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
            return NSItemProvider()
        }

        // NSItemProvider(contentsOf:) returns nil when the path is inaccessible,
        // avoiding an extra synchronous fileExists check.
        guard let provider = NSItemProvider(contentsOf: url) else {
            return NSItemProvider()
        }
        provider.suggestedName = url.lastPathComponent
        return provider
    }
}
#endif
