//
//  RealmThumbnailArtworkDriver.swift
//  ThumbnailExtension
//
//  Created by Claude on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Realm-backed implementation of ThumbnailArtworkDriver.
//  Reads from the shared App Group Realm database opened via
//  RealmConfiguration.setDefaultRealmConfig() so it accesses the same
//  store as the main Provenance app.
//

import Foundation
import PVLibrary
import RealmSwift

/// Realm-backed `ThumbnailArtworkDriver`.
///
/// All queries are performed synchronously on the calling thread (the QL
/// extension worker thread).  No Realm objects escape this class — only
/// plain `String` / `URL` values are returned.
final class RealmThumbnailArtworkDriver: ThumbnailArtworkDriver {

    // MARK: - ThumbnailArtworkDriver

    func artworkURLKey(forROMFilename romFilename: String) -> String? {
        guard RealmConfiguration.supportsAppGroups else {
            ELOG("App Groups not supported — skipping Realm artwork lookup")
            return nil
        }
        do {
            RealmConfiguration.setDefaultRealmConfig()
            let realm = try Realm()

            // romPath is stored as "{systemID}/{filename}" or just "{filename}".
            // Match the suffix to avoid requiring the full path.
            let bySuffix = realm.objects(PVGame.self)
                .filter("romPath ENDSWITH %@", "/" + romFilename)
            let match = bySuffix.first
                ?? realm.objects(PVGame.self).filter("romPath == %@", romFilename).first

            guard let game = match else {
                DLOG("No game found for ROM filename: \(romFilename)")
                return nil
            }

            let url = game.artworkURL
            return url.isEmpty ? nil : url
        } catch {
            ELOG("Realm lookup failed: \(error.localizedDescription)")
            return nil
        }
    }

    func saveStateImageFileURL(forSaveStatePath saveStatePath: String) -> URL? {
        guard RealmConfiguration.supportsAppGroups else {
            ELOG("App Groups not supported — skipping Realm save state lookup")
            return nil
        }
        do {
            RealmConfiguration.setDefaultRealmConfig()
            let realm = try Realm()

            // Match save states whose file's partialPath ends with the filename.
            let filename = (saveStatePath as NSString).lastPathComponent
            let saveStates = realm.objects(PVSaveState.self)
                .filter("file.partialPath ENDSWITH %@", filename)
            guard let saveState = saveStates.first,
                  let imageFile = saveState.image,
                  let imageURL = imageFile.url,
                  FileManager.default.fileExists(atPath: imageURL.path) else {
                return nil
            }
            return imageURL
        } catch {
            ELOG("Realm save state lookup failed: \(error.localizedDescription)")
            return nil
        }
    }
}
