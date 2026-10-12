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

    /// Rewrites every `PVFile.partialPath` in `remaps` and the owning `PVGame.romPath`.
    public static func apply(_ remaps: [String: String]) async throws {
        try await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            // Snapshots: the writes below change the very properties these queries filter on.
            let files = Array(realm.objects(PVFile.self).filter("partialPath IN %@", Array(remaps.keys)))
            var count = 0
            try realm.write {
                for file in files {
                    guard let newPath = remaps[file.partialPath] else { continue }
                    let oldRomPath = romPath(forPartialPath: file.partialPath)
                    file.partialPath = newPath
                    for game in Array(realm.objects(PVGame.self).filter("romPath == %@", oldRomPath)) {
                        game.romPath = romPath(forPartialPath: newPath)
                    }
                    count += 1
                }
            }
            ILOG("LibraryMove: remapped \(count) of \(remaps.count) records to shared copies")
        }
    }
}
