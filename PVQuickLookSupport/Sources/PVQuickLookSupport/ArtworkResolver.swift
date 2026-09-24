//
//  ArtworkResolver.swift
//  PVQuickLookSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Resolves PVMediaCache-style artwork keys to local artwork files or raw
//  image bytes. Returns Foundation types (URL / Data) so callers remain
//  UIKit-free.
//

import Foundation
import CryptoKit
import PVLibrarySnapshot

/// Resolves an artwork key to a local file URL or raw image data.
///
/// Extensions should use `fileURL(forKey:)` when building `QLThumbnailReply`
/// (which accepts a file URL directly) and `data(forKey:)` when embedding
/// artwork inline (e.g. as a base64 string in an HTML preview card).
///
/// Search order for every lookup:
///  1. `<AppGroupContainer>/Documents/PVCache/<md5(key)>` — used on iOS/macOS with App Groups.
///  2. `<AppGroupContainer>/Caches/PVCache/<md5(key)>` — used on tvOS (documentsPath → Caches).
///  3. `<AppGroupContainer>/Library/Caches/PVCache/<md5(key)>` — used by TopShelf/CloudKit save-state art.
///  4. `<AppGroupContainer>/PVCache/<md5(key)>` — root-level container path used by some widget/TopShelf configs.
public struct ArtworkResolver {

    /// Candidate locations, relative to the group container, in priority order.
    static let candidateDirectories = [
        "Documents/PVCache",          // iOS/macOS with App Groups
        "Caches/PVCache",             // tvOS (documentsPath → Caches)
        "Library/Caches/PVCache",     // Top Shelf / CloudKit save-state art
        "PVCache",                    // root-level container path
    ]

    public static func fileURL(forKey key: String) -> URL? {
        fileURL(forKey: key, containerURL: LibrarySnapshotAppGroup.containerURL)
    }

    static func fileURL(forKey key: String, containerURL: URL?) -> URL? {
        guard !key.isEmpty, let containerURL else { return nil }
        let keyHash = md5Hex(key)
        for dir in candidateDirectories {
            let candidate = containerURL
                .appendingPathComponent(dir, isDirectory: true)
                .appendingPathComponent(keyHash, isDirectory: false)
            if FileManager.default.fileExists(atPath: candidate.path) {
                QuickLookLog.debug("Artwork resolved via \(dir)")
                return candidate
            }
        }
        QuickLookLog.debug("Artwork file not found for key hash: \(keyHash)")
        return nil
    }

    public static func data(forKey key: String) -> Data? {
        guard let url = fileURL(forKey: key) else { return nil }
        if url.isUbiquitousPlaceholder { return nil }
        return try? Data(contentsOf: url)
    }

    /// Lowercase hex MD5, matching `PVMediaCache`'s on-disk key hashing.
    static func md5Hex(_ key: String) -> String {
        Insecure.MD5.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - URL+Ubiquity

private extension URL {
    /// `true` when this URL points to an iCloud placeholder that is not yet downloaded locally.
    ///
    /// A ubiquitous item in the "not downloaded" state is represented on disk as a
    /// zero-byte `.icloud` shadow file next to the evicted content path.  Attempting
    /// `Data(contentsOf:)` on such a URL would either fail or trigger a blocking
    /// network download — both unacceptable in a short-lived extension process.
    var isUbiquitousPlaceholder: Bool {
        guard (try? resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true else {
            return false
        }
        // Downloaded items are fine; only skip placeholders.
        let downloaded = (try? resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus) ?? .notDownloaded
        return downloaded != .current
    }
}
