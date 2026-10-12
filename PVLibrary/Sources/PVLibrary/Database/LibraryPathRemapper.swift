//
//  LibraryPathRemapper.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  After joining a shared library, records whose file was found under another name point at that
//  name (D15). Idempotent: a record already renamed matches nothing.
//

import Foundation
import PVFileSystem
import PVLogging
import PVRealm
import RealmSwift

public enum LibraryPathRemapper {
    private static let romsPrefix = "ROMs/"

    /// `PVGame.romPath` is the partial path without its `ROMs/` prefix (`GameImporterDatabaseService`).
    public static func romPath(forPartialPath partialPath: String) -> String {
        partialPath.hasPrefix(romsPrefix) ? String(partialPath.dropFirst(romsPrefix.count)) : partialPath
    }

    /// Rewrites every `PVFile.partialPath` named in `remaps` and the owning `PVGame.romPath`. A record is matched by the
    /// key itself or, for a legacy record stored without its `ROMs/` prefix, by the key minus that prefix; `romPath` is
    /// rewritten in the form it was found in.
    /// - Returns: the keys whose record now follows the shared copy: rewritten here, or already pointing at it (a repeat
    ///   run after the first one rewrote it). A key with no record at either path is not returned.
    public static func apply(_ remaps: [String: String]) async throws -> Set<String> {
        try await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            // Snapshots: the writes below change the very properties these queries filter on.
            var keyByStoredPath: [String: String] = [:]
            for key in remaps.keys {
                keyByStoredPath[key] = key
                let legacy = romPath(forPartialPath: key)
                if legacy != key { keyByStoredPath[legacy] = key }
            }
            let files = Array(realm.objects(PVFile.self).filter("partialPath IN %@", Array(keyByStoredPath.keys)))
            var confirmed = Set<String>()
            var count = 0
            try realm.write {
                for file in files {
                    let storedPath = file.partialPath
                    guard let key = keyByStoredPath[storedPath], let newPath = remaps[key] else { continue }
                    file.partialPath = newPath
                    // A game's `romPath` is stored with or without the `ROMs/` prefix; keep whichever form it has.
                    let strippedOld = romPath(forPartialPath: storedPath)
                    for game in Array(realm.objects(PVGame.self).filter("romPath IN %@", [storedPath, strippedOld])) {
                        game.romPath = (game.romPath == storedPath && storedPath != strippedOld) ? newPath : romPath(forPartialPath: newPath)
                    }
                    confirmed.insert(key)
                    count += 1
                }
            }
            // Already applied by an earlier run: nothing names the source any more, but a record names the shared copy.
            let pending = remaps.filter { !confirmed.contains($0.key) }
            if !pending.isEmpty {
                let alreadyAt = Set(realm.objects(PVFile.self).filter("partialPath IN %@", Array(Set(pending.values))).map(\.partialPath))
                for (key, newPath) in pending where alreadyAt.contains(newPath) {
                    confirmed.insert(key)
                }
            }
            ILOG("LibraryMove: remapped \(count) of \(remaps.count) records to shared copies, \(confirmed.count) confirmed")
            return confirmed
        }
    }
}
