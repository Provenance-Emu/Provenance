//
//  ThumbnailArtworkDriver.swift
//  ThumbnailExtension
//
//  Created by Claude on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Core Persistence Driver Interface (CPDI) for thumbnail artwork lookup.
//  This abstraction allows the ThumbnailProvider to be backed by any
//  persistence layer — currently Realm, with SwiftData support possible in future.
//

import Foundation

/// CPDI — Core Persistence Driver Interface for thumbnail artwork resolution.
///
/// Implementations may be backed by Realm, SwiftData, or any future store.
/// The ThumbnailProvider holds a reference to this protocol so the backend
/// can be swapped without touching QLThumbnailProvider logic.
protocol ThumbnailArtworkDriver {
    /// Returns the artwork URL key (cache key used by PVMediaCache) for the
    /// game whose ROM path ends with `romFilename`.
    /// Returns `nil` when the database is unavailable or no game matches.
    func artworkURLKey(forROMFilename romFilename: String) -> String?

    /// Returns the local file URL for the screenshot image associated with the
    /// save state file at `saveStatePath`, if one is recorded in the database.
    /// Returns `nil` when the database is unavailable or no match is found.
    func saveStateImageFileURL(forSaveStatePath saveStatePath: String) -> URL?
}
