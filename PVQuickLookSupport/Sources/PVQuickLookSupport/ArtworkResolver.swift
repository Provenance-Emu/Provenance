//
//  ArtworkResolver.swift
//  PVQuickLookSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Resolves PVMediaCache keys to local artwork files or raw image bytes.
//  Returns Foundation types (URL / Data) so callers remain UIKit-free.
//

import Foundation
import PVLibrary
import PVHashing

/// Resolves a `PVMediaCache` artwork key to a local file URL or raw image data.
///
/// Extensions should use `fileURL(forKey:)` when building `QLThumbnailReply`
/// (which accepts a file URL directly) and `data(forKey:)` when embedding
/// artwork inline (e.g. as a base64 string in an HTML preview card).
///
/// Search order for every lookup:
///  1. `<AppGroupContainer>/Documents/PVCache/<md5(key)>` — used on iOS/macOS with App Groups.
///  2. `<AppGroupContainer>/Caches/PVCache/<md5(key)>` — used on tvOS (documentsPath → Caches).
///  3. `<AppGroupContainer>/Library/Caches/PVCache/<md5(key)>` — used by TopShelf/CloudKit save-state art.
///  4. `PVMediaCache.filePath(forKey:)` — local Documents/Caches fallback.
public struct ArtworkResolver {

    // MARK: - Public API

    /// Returns the local file URL for the cached artwork at `key`, or `nil` when
    /// the file cannot be found in either the App Group container or the local cache.
    public static func fileURL(forKey key: String) -> URL? {
        guard !key.isEmpty else { return nil }
        let keyHash = key.md5Hash

        // 1. App Group container — preferred from extension processes.
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: PVAppGroupId
        ) {
            // 1a. Documents/PVCache — used on iOS/macOS when App Groups are enabled.
            let documentsCandidate = groupURL
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("PVCache", isDirectory: true)
                .appendingPathComponent(keyHash, isDirectory: false)
            if FileManager.default.fileExists(atPath: documentsCandidate.path) {
                DLOG("[PVQuickLookSupport] Artwork resolved via App Group Documents cache")
                return documentsCandidate
            }

            // 1b. Caches/PVCache — used on tvOS where documentsPath resolves to the
            //     Caches directory (see PVMediaCache.cachePath / URL.documentsPath).
            let cachesCandidate = groupURL
                .appendingPathComponent("Caches", isDirectory: true)
                .appendingPathComponent("PVCache", isDirectory: true)
                .appendingPathComponent(keyHash, isDirectory: false)
            if FileManager.default.fileExists(atPath: cachesCandidate.path) {
                DLOG("[PVQuickLookSupport] Artwork resolved via App Group Caches (tvOS path)")
                return cachesCandidate
            }

            // 1c. Library/Caches/PVCache — written by TopShelf and CloudKit save-state
            //     artwork caches on some configurations.
            let libraryCachesCandidate = groupURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Caches", isDirectory: true)
                .appendingPathComponent("PVCache", isDirectory: true)
                .appendingPathComponent(keyHash, isDirectory: false)
            if FileManager.default.fileExists(atPath: libraryCachesCandidate.path) {
                DLOG("[PVQuickLookSupport] Artwork resolved via App Group Library/Caches")
                return libraryCachesCandidate
            }
        }

        // 2. Local Documents fallback via PVMediaCache.
        if let localURL = PVMediaCache.filePath(forKey: key),
           FileManager.default.fileExists(atPath: localURL.path) {
            DLOG("[PVQuickLookSupport] Artwork resolved via local cache")
            return localURL
        }

        DLOG("[PVQuickLookSupport] Artwork file not found for key hash: \(keyHash)")
        return nil
    }

    /// Returns the raw image bytes (JPEG or PNG) for the cached artwork at `key`,
    /// or `nil` when the file cannot be found or cannot be read.
    public static func data(forKey key: String) -> Data? {
        guard let url = fileURL(forKey: key) else { return nil }
        return try? Data(contentsOf: url)
    }
}
