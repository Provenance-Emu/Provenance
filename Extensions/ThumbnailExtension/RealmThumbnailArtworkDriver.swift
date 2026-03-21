//
//  RealmThumbnailArtworkDriver.swift
//  ThumbnailExtension
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Realm-backed implementation of ThumbnailArtworkDriver.
//  Delegates all lookup and cache resolution to the shared PVQuickLookSupport
//  module so logic is not duplicated between ThumbnailExtension and
//  QuickLookPreview.
//

import Foundation
import PVQuickLookSupport

/// Realm-backed `ThumbnailArtworkDriver`.
///
/// Delegates to `ROMGameLookup` and `ArtworkResolver` from `PVQuickLookSupport`
/// so both extensions share a single implementation of the lookup logic.
final class RealmThumbnailArtworkDriver: ThumbnailArtworkDriver {

    // MARK: - ThumbnailArtworkDriver

    func artworkURLKey(forROMFilename romFilename: String) -> String? {
        ROMGameLookup.lookup(forROMFilename: romFilename)?.artworkURLKey
    }

    func saveStateImageFileURL(forSaveStatePath saveStatePath: String) -> URL? {
        ROMGameLookup.saveStateImageURL(forSaveStatePath: saveStatePath)
    }
}
