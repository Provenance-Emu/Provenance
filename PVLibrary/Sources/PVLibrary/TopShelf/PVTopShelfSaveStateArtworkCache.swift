//
//  PVTopShelfSaveStateArtworkCache.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 1/3/26.
//

import Foundation
import PVFileSystem
import PVHashing
import PVLogging

public enum PVTopShelfSaveStateArtworkCache: Sendable {
    public static func cacheKey(forSaveStateID id: String) -> String {
        "topshelf_savestate_\(id)"
    }

    public static func storeJPEGForTopShelf(from sourceURL: URL, saveStateID: String) {
        let fileManager = FileManager.default
        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) else {
            ELOG("TopShelf cache: app group container unavailable for id \(PVAppGroupId)")
            return
        }

        let keyHash = cacheKey(forSaveStateID: saveStateID).md5Hash
        let destinations: [URL] = [
            groupURL.appendingPathComponent("Documents/PVCache/\(keyHash)"),
            groupURL.appendingPathComponent("Caches/PVCache/\(keyHash)"),
            groupURL.appendingPathComponent("Library/Caches/PVCache/\(keyHash)")
        ]

        for destinationURL in destinations {
            do {
                try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }

                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            } catch {
                ELOG("TopShelf cache: failed writing save-state artwork to \(destinationURL.path): \(error.localizedDescription)")
            }
        }
    }
}
